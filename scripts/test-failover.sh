#!/usr/bin/env bash
# =============================================================================
# test-failover.sh — integration test for VRRP DNS failover.
#
# Verifies that when this node's DNS goes down, the VIP floats to the peer and
# clients keep resolving — then that this node recovers. Run on the node that
# currently holds the VIP (usually the primary). It briefly stops DNS on THIS
# node, so expect a few seconds of disruption for queries pinned to this node.
#
#   ./scripts/test-failover.sh            # interactive (asks to confirm)
#   ./scripts/test-failover.sh --yes      # non-interactive
#   ./scripts/test-failover.sh --probe cloudflare.com --timeout 25
#
# Exit code 0 = failover + recovery verified; non-zero = a check failed.
# Reads VIP_ADDRESS / NODE_IP from .env. Requires: docker, dig.
# =============================================================================
set -euo pipefail

c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_r=$'\033[0;31m'; c_b=$'\033[0;34m'; c_n=$'\033[0m'
pass() { printf '%s[PASS]%s %s\n' "$c_g" "$c_n" "$*"; }
fail() { printf '%s[FAIL]%s %s\n' "$c_r" "$c_n" "$*"; }
info() { printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$REPO_DIR/.env" ]] && { set -a; . "$REPO_DIR/.env"; set +a; }

VIP="${VIP_ADDRESS:-192.168.8.243}"
NODE_IP="${NODE_IP:-127.0.0.1}"
IFACE="${NETWORK_INTERFACE:-eth0}"
PROBE="github.com"
TIMEOUT=20
ASSUME_YES=0
CONTAINERS=(pihole_unbound keepalived)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe) PROBE="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --vip) VIP="$2"; shift 2;;
    --yes|-y) ASSUME_YES=1; shift;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) fail "unknown arg: $1"; exit 2;;
  esac
done

command -v dig >/dev/null    || { fail "dig not found (install dnsutils/bind-tools)"; exit 1; }
command -v docker >/dev/null || { fail "docker not found"; exit 1; }

dns_ok()  { dig +short +tries=1 +time=2 "@$1" "$PROBE" 2>/dev/null | grep -qE '^[0-9a-fA-F:.]+$'; }
vip_here() { ip -o addr show "$IFACE" 2>/dev/null | grep -qw "$VIP"; }

FAILED=0

# ---- restore-on-exit safety net -------------------------------------------
RESTARTED=0
restore() {
  [[ "$RESTARTED" -eq 1 ]] && return
  RESTARTED=1
  info "Restoring DNS on this node..."
  docker start "${RUNNING[@]}" >/dev/null 2>&1 || \
    docker compose -f "$REPO_DIR/compose.yml" start "${RUNNING[@]}" >/dev/null 2>&1 || true
}
trap restore EXIT INT TERM

# ---- 0. preconditions ------------------------------------------------------
info "VIP=$VIP  node=$NODE_IP  iface=$IFACE  probe=$PROBE  timeout=${TIMEOUT}s"
if ! dns_ok "$VIP"; then fail "baseline: VIP $VIP not resolving — fix DNS before testing"; exit 1; fi
pass "baseline: VIP $VIP resolves $PROBE"
vip_here && info "this node currently holds the VIP" || warn "this node does NOT hold the VIP — test still valid but less meaningful (run on the MASTER)"

# which of our containers are actually running (restore exactly these)
RUNNING=()
for c in "${CONTAINERS[@]}"; do
  docker ps --format '{{.Names}}' | grep -qx "$c" && RUNNING+=("$c")
done
[[ ${#RUNNING[@]} -gt 0 ]] || { fail "no DNS containers running on this node (${CONTAINERS[*]})"; exit 1; }

if [[ "$ASSUME_YES" -eq 0 ]]; then
  warn "About to stop ${RUNNING[*]} on THIS node to force a failover. Continue? [y/N]"
  read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || { info "aborted"; exit 0; }
fi

# ---- 1. induce failure -----------------------------------------------------
info "Stopping ${RUNNING[*]} ..."
docker stop "${RUNNING[@]}" >/dev/null

# ---- 2. assert failover (VIP still resolves via the peer) -------------------
info "Waiting up to ${TIMEOUT}s for failover..."
ok=0
for ((i=0; i<TIMEOUT; i++)); do
  if dns_ok "$VIP"; then ok=1; break; fi
  sleep 1
done
if [[ "$ok" -eq 1 ]]; then pass "failover: VIP $VIP still resolves after ${i}s (peer took over)"; else fail "failover: VIP $VIP did NOT recover within ${TIMEOUT}s"; FAILED=1; fi

# VIP should have left this node
if vip_here; then fail "VIP $VIP is still on this node — it did not float to the peer"; FAILED=1; else pass "VIP left this node (floated to peer)"; fi

# ---- 3. recover this node --------------------------------------------------
restore
info "Waiting up to ${TIMEOUT}s for this node to recover..."
ok=0
for ((i=0; i<TIMEOUT; i++)); do
  if dns_ok "127.0.0.1"; then ok=1; break; fi
  sleep 1
done
[[ "$ok" -eq 1 ]] && pass "recovery: local DNS answering again after ${i}s" || { fail "recovery: local DNS not answering within ${TIMEOUT}s"; FAILED=1; }

echo
if [[ "$FAILED" -eq 0 ]]; then pass "FAILOVER TEST PASSED"; else fail "FAILOVER TEST FAILED — see docs/troubleshooting.md"; fi
exit "$FAILED"
