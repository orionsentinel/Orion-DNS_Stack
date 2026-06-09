#!/usr/bin/env bash
# =============================================================================
# configure-nic.sh — bring up a Raspberry Pi's USB-C / USB 2.5–10G NIC on a
# fixed (static) IP that survives reboots.
#
# Why: the high-availability DNS node should serve DNS (and float the VRRP VIP)
# over a fast, predictable interface. USB NICs get unstable kernel names
# (eth1, enxAABBCC...) and ship with EEE / Wake-on-LAN quirks that cause the
# "NIC flapping" failures documented in docs/troubleshooting.md. This script
# pins the interface to a static IP, persists it, and disables those quirks.
#
# Works on Raspberry Pi OS Bookworm (NetworkManager, default) and falls back to
# systemd-networkd. Idempotent: re-running updates the existing connection.
#
# Usage:
#   sudo ./scripts/configure-nic.sh                # read settings from .env
#   sudo ./scripts/configure-nic.sh --iface eth1 --ip 192.168.8.244/24 \
#        --gateway 192.168.8.1 --dns 127.0.0.1 --mtu 9000
#   sudo ./scripts/configure-nic.sh --mac AA:BB:CC:DD:EE:FF --ip 192.168.8.244/24
#   sudo ./scripts/configure-nic.sh --list         # list candidate interfaces
#   sudo ./scripts/configure-nic.sh --verify       # show current link state
#
# .env keys (see env/primary.env.example):
#   NETWORK_INTERFACE   target interface name (e.g. eth1) — used if --iface absent
#   NODE_IP             host IP (e.g. 192.168.8.244)      — used if --ip absent
#   LINK_CIDR           prefix length for NODE_IP (default 24)
#   LINK_GATEWAY        default gateway (default 192.168.8.1)
#   LINK_DNS            resolver for the host (default 127.0.0.1)
#   LINK_MAC            bind the connection to this MAC (optional, robust naming)
#   LINK_MTU            MTU; set 9000 for jumbo frames on a 2.5–10G link (default 1500)
#   LINK_NM_NAME        NetworkManager connection name (default orion-fastlan)
# =============================================================================
set -euo pipefail

# ---- pretty output ---------------------------------------------------------
c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_r=$'\033[0;31m'; c_b=$'\033[0;34m'; c_n=$'\033[0m'
log()  { printf '%s[✓]%s %s\n' "$c_g" "$c_n" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$c_r" "$c_n" "$*" >&2; }
info() { printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- load .env (if present) ------------------------------------------------
if [[ -f "$REPO_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; . "$REPO_DIR/.env"; set +a
fi

# ---- defaults / args -------------------------------------------------------
IFACE="${NETWORK_INTERFACE:-}"
IPADDR=""
CIDR="${LINK_CIDR:-24}"
GATEWAY="${LINK_GATEWAY:-192.168.8.1}"
DNS="${LINK_DNS:-127.0.0.1}"
MAC="${LINK_MAC:-}"
MTU="${LINK_MTU:-1500}"
NM_NAME="${LINK_NM_NAME:-orion-fastlan}"
ACTION="apply"

# Seed IP from NODE_IP/LINK_CIDR if available
if [[ -n "${NODE_IP:-}" ]]; then IPADDR="${NODE_IP}/${CIDR}"; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface)   IFACE="$2"; shift 2;;
    --ip)      IPADDR="$2"; shift 2;;            # accepts IP or IP/CIDR
    --gateway) GATEWAY="$2"; shift 2;;
    --dns)     DNS="$2"; shift 2;;
    --mac)     MAC="$2"; shift 2;;
    --mtu)     MTU="$2"; shift 2;;
    --name)    NM_NAME="$2"; shift 2;;
    --list)    ACTION="list"; shift;;
    --verify)  ACTION="verify"; shift;;
    -h|--help) sed -n '2,40p' "$0"; exit 0;;
    *) err "unknown argument: $1"; exit 2;;
  esac
done

# Normalise IP to IP/CIDR
if [[ -n "$IPADDR" && "$IPADDR" != */* ]]; then IPADDR="${IPADDR}/${CIDR}"; fi

list_ifaces() {
  info "Candidate Ethernet interfaces (name / MAC / state / speed):"
  for d in /sys/class/net/*; do
    n="$(basename "$d")"
    [[ "$n" == "lo" ]] && continue
    [[ -e "$d/wireless" ]] && continue
    mac="$(cat "$d/address" 2>/dev/null || echo '?')"
    state="$(cat "$d/operstate" 2>/dev/null || echo '?')"
    speed="$(cat "$d/speed" 2>/dev/null || echo '?')"
    printf '  %-12s %s  state=%-6s speed=%sMb\n' "$n" "$mac" "$state" "$speed"
  done
}

# Resolve interface from MAC if only MAC was given
resolve_iface_from_mac() {
  local want="${1,,}" d n mac
  for d in /sys/class/net/*; do
    n="$(basename "$d")"
    mac="$(cat "$d/address" 2>/dev/null || true)"
    if [[ "${mac,,}" == "$want" ]]; then echo "$n"; return 0; fi
  done
  return 1
}

verify_link() {
  local i="${IFACE:-}"
  [[ -z "$i" ]] && { err "no interface to verify (set --iface or NETWORK_INTERFACE)"; exit 1; }
  info "Link state for $i:"
  ip -br addr show "$i" || true
  ip -br link show "$i" || true
  command -v ethtool >/dev/null 2>&1 && ethtool "$i" 2>/dev/null | grep -E 'Speed|Link detected' || true
}

require_root() { [[ "$(id -u)" -eq 0 ]] || { err "run with sudo"; exit 1; }; }

# Disable EEE and Wake-on-LAN, set MTU — mitigates USB-NIC flapping.
tune_link() {
  local i="$1"
  command -v ethtool >/dev/null 2>&1 || { warn "ethtool not installed; skipping EEE/WoL tuning (apt-get install ethtool)"; return 0; }
  ethtool --set-eee "$i" eee off >/dev/null 2>&1 && log "EEE disabled on $i" || warn "could not disable EEE on $i (may be unsupported)"
  ethtool -s "$i" wol d >/dev/null 2>&1 && log "Wake-on-LAN disabled on $i" || true
}

apply_networkmanager() {
  local i="$1"
  info "Configuring via NetworkManager (connection: $NM_NAME)"
  # Remove a stale connection of the same name, then (re)create it.
  nmcli -t -f NAME con show | grep -Fxq "$NM_NAME" && nmcli con delete "$NM_NAME" >/dev/null 2>&1 || true
  local add=(con add type ethernet con-name "$NM_NAME" ifname "$i"
    ipv4.method manual ipv4.addresses "$IPADDR" ipv4.gateway "$GATEWAY"
    ipv4.dns "$DNS" ipv6.method ignore connection.autoconnect yes
    802-3-ethernet.mtu "$MTU")
  [[ -n "$MAC" ]] && add+=(802-3-ethernet.mac-address "$MAC")
  nmcli "${add[@]}" >/dev/null
  nmcli con up "$NM_NAME" >/dev/null
  log "NetworkManager connection '$NM_NAME' active on $i ($IPADDR, mtu $MTU)"
}

apply_systemd_networkd() {
  local i="$1"
  info "Configuring via systemd-networkd"
  local f="/etc/systemd/network/10-${NM_NAME}.network"
  {
    echo "[Match]"
    if [[ -n "$MAC" ]]; then echo "MACAddress=$MAC"; else echo "Name=$i"; fi
    echo
    echo "[Link]"
    echo "MTUBytes=$MTU"
    echo
    echo "[Network]"
    echo "Address=$IPADDR"
    echo "Gateway=$GATEWAY"
    echo "DNS=$DNS"
  } > "$f"
  log "wrote $f"
  systemctl enable systemd-networkd >/dev/null 2>&1 || true
  systemctl restart systemd-networkd
  log "systemd-networkd reloaded ($i → $IPADDR, mtu $MTU)"
}

# ---- main ------------------------------------------------------------------
case "$ACTION" in
  list)   list_ifaces; exit 0;;
  verify) verify_link; exit 0;;
esac

require_root

# Resolve interface if only a MAC was provided
if [[ -z "$IFACE" && -n "$MAC" ]]; then
  IFACE="$(resolve_iface_from_mac "$MAC" || true)"
  [[ -n "$IFACE" ]] && info "MAC $MAC → interface $IFACE"
fi

# Validate inputs
[[ -n "$IFACE" ]]  || { err "no interface — pass --iface, --mac, or set NETWORK_INTERFACE"; list_ifaces; exit 1; }
[[ -e "/sys/class/net/$IFACE" ]] || { err "interface '$IFACE' not present"; list_ifaces; exit 1; }
[[ -n "$IPADDR" ]] || { err "no IP — pass --ip or set NODE_IP in .env"; exit 1; }
[[ "$IPADDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || { err "invalid IP/CIDR: $IPADDR"; exit 1; }

info "Target: iface=$IFACE ip=$IPADDR gw=$GATEWAY dns=$DNS mtu=$MTU mac=${MAC:-<none>}"

ip link set "$IFACE" up || true
tune_link "$IFACE"

if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then
  apply_networkmanager "$IFACE"
elif systemctl is-active --quiet systemd-networkd 2>/dev/null || [[ -d /etc/systemd/network ]]; then
  apply_systemd_networkd "$IFACE"
else
  err "neither NetworkManager nor systemd-networkd is available; cannot persist config"
  exit 1
fi

echo
verify_link
echo
log "Done. '$IFACE' is fixed at $IPADDR and will persist across reboots."
info "If this is the DNS path, set NETWORK_INTERFACE=$IFACE and NODE_IP=${IPADDR%/*} in .env,"
info "then: docker compose --profile two-node-ha-primary up -d   (backup profile on Node B)"
