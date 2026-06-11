#!/usr/bin/env bash
# =============================================================================
# validate-env.sh — preflight check for an Orion DNS node's .env.
#
# Run before bringing the stack up (bootstrap.sh and `make up-core` both call
# it). It fails fast with a clear message instead of letting a misconfigured
# node crash a container later. Run directly any time:  make preflight
#
# Schema is the canonical single-file .env (see env/*.example, docs/networking.md):
#   NODE_IP NODE_ROLE VIP_ADDRESS PEER_IP UNICAST_SRC_IP NETWORK_INTERFACE
#   VRRP_PASSWORD WEBPASSWORD KEEPALIVED_PRIORITY TZ
#
# Exit 0 = ready (warnings allowed); non-zero = hard errors that must be fixed.
# =============================================================================
set -o pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))"
ENV_FILE="${1:-$REPO_ROOT/.env}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

ERRORS=0; WARNINGS=0

if [[ ! -f "$ENV_FILE" ]]; then
  err ".env not found at $ENV_FILE"
  err "Seed one with ./bootstrap.sh, or copy a template:"
  err "  cp env/primary.env.example .env   # or secondary.env.example / .env.example"
  exit 1
fi

# Read a key's literal value (everything after the first '='); empty if unset.
kv() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -ra _o <<< "$ip"
  for o in "${_o[@]}"; do ((o <= 255)) || return 1; done
  return 0
}
# /24-style network compare (first three octets)
same_subnet24() { [[ "${1%.*}" == "${2%.*}" ]]; }
is_placeholder() { [[ "$1" == CHANGE_ME* || "$1" == "CHANGE_8c" || -z "$1" ]]; }
# check_ipv4 NAME VALUE — logs/validates; counts an error on bad IPv4 (skips empty)
check_ipv4() {
  local name="$1" val="$2"
  [[ -z "$val" ]] && return 0
  if valid_ipv4 "$val"; then log "$name $val is a valid IPv4"; else err "$name has invalid IPv4: $val"; ((ERRORS++)); fi
}

NODE_ROLE="$(kv NODE_ROLE)"
HA=0
case "$NODE_ROLE" in MASTER|BACKUP) HA=1;; esac

echo "Preflight: $ENV_FILE"
echo "Mode: $([[ $HA -eq 1 ]] && echo "HA ($NODE_ROLE)" || echo "single-node")"
echo

# --- required variables ----------------------------------------------------
REQUIRED=(NODE_IP NETWORK_INTERFACE TZ WEBPASSWORD)
[[ $HA -eq 1 ]] && REQUIRED+=(VIP_ADDRESS PEER_IP UNICAST_SRC_IP VRRP_PASSWORD KEEPALIVED_PRIORITY)

echo "Required variables..."
for v in "${REQUIRED[@]}"; do
  if [[ -z "$(kv "$v")" ]]; then err "$v is not set"; ((ERRORS++)); else log "$v is set"; fi
done

# --- secrets ---------------------------------------------------------------
echo; echo "Secrets..."
WEBPASSWORD="$(kv WEBPASSWORD)"
if is_placeholder "$WEBPASSWORD"; then
  err "WEBPASSWORD is still a placeholder — set a strong, unique value"; ((ERRORS++))
elif [[ ${#WEBPASSWORD} -lt 8 ]]; then
  err "WEBPASSWORD is too short (min 8 characters)"; ((ERRORS++))
else
  log "WEBPASSWORD looks set"
fi

if [[ $HA -eq 1 ]]; then
  VRRP_PASSWORD="$(kv VRRP_PASSWORD)"
  if is_placeholder "$VRRP_PASSWORD"; then
    err "VRRP_PASSWORD is still a placeholder — set it (and match the peer)"; ((ERRORS++))
  elif [[ ${#VRRP_PASSWORD} -ne 8 ]]; then
    err "VRRP_PASSWORD must be EXACTLY 8 characters (got ${#VRRP_PASSWORD}) — VRRP auth truncates otherwise"; ((ERRORS++))
  else
    log "VRRP_PASSWORD is exactly 8 characters"
  fi
fi

# --- IP addresses ----------------------------------------------------------
echo; echo "Addresses..."
NODE_IP="$(kv NODE_IP)"
check_ipv4 NODE_IP "$NODE_IP"

if [[ $HA -eq 1 ]]; then
  VIP_ADDRESS="$(kv VIP_ADDRESS)"; PEER_IP="$(kv PEER_IP)"; UNICAST_SRC_IP="$(kv UNICAST_SRC_IP)"
  check_ipv4 VIP_ADDRESS "$VIP_ADDRESS"
  check_ipv4 PEER_IP "$PEER_IP"
  check_ipv4 UNICAST_SRC_IP "$UNICAST_SRC_IP"

  # KEEPALIVED_PRIORITY range
  PRI="$(kv KEEPALIVED_PRIORITY)"
  if [[ -n "$PRI" ]]; then
    if [[ "$PRI" =~ ^[0-9]+$ ]] && ((PRI >= 1 && PRI <= 255)); then
      log "KEEPALIVED_PRIORITY $PRI in range"
    else
      err "KEEPALIVED_PRIORITY must be 1-255 (got '$PRI')"; ((ERRORS++))
    fi
  fi

  # UNICAST_SRC_IP should be THIS node, PEER_IP the other — they must differ
  if [[ -n "$UNICAST_SRC_IP" && "$UNICAST_SRC_IP" == "$PEER_IP" ]]; then
    err "UNICAST_SRC_IP and PEER_IP are identical ($PEER_IP) — they must be the two different node IPs"; ((ERRORS++))
  fi
  if [[ -n "$NODE_IP" && -n "$UNICAST_SRC_IP" && "$NODE_IP" != "$UNICAST_SRC_IP" ]]; then
    warn "UNICAST_SRC_IP ($UNICAST_SRC_IP) != NODE_IP ($NODE_IP) — usually they should match"; ((WARNINGS++))
  fi

  # same /24 sanity (warn only — exotic topologies exist)
  for other in "$VIP_ADDRESS" "$PEER_IP"; do
    if [[ -n "$NODE_IP" && -n "$other" ]] && valid_ipv4 "$NODE_IP" && valid_ipv4 "$other" \
       && ! same_subnet24 "$NODE_IP" "$other"; then
      warn "$other is not in the same /24 as NODE_IP ($NODE_IP) — confirm this is intended"; ((WARNINGS++))
    fi
  done
fi

# --- host-environment warnings (non-fatal) ---------------------------------
echo; echo "Host environment..."
IFACE="$(kv NETWORK_INTERFACE)"
if [[ -n "$IFACE" ]]; then
  if command -v ip >/dev/null 2>&1; then
    if ip link show "$IFACE" >/dev/null 2>&1; then
      log "interface $IFACE exists"
    else
      warn "interface $IFACE not found on this host (ok if configuring before the NIC is up)"; ((WARNINGS++))
    fi
  fi
fi
if [[ $HA -eq 1 && -n "${PEER_IP:-}" ]] && valid_ipv4 "${PEER_IP:-}"; then
  if command -v ping >/dev/null 2>&1; then
    if ping -c1 -W1 "$PEER_IP" >/dev/null 2>&1; then
      log "peer $PEER_IP is reachable"
    else
      warn "peer $PEER_IP not reachable yet (normal if the other node isn't up)"; ((WARNINGS++))
    fi
  fi
fi

# --- file format -----------------------------------------------------------
echo; echo "File format..."
fmt_errors=0; n=0
while IFS= read -r line; do
  ((n++))
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
    err "line $n: not KEY=VALUE: $line"; ((ERRORS++)); ((fmt_errors++))
  fi
done < "$ENV_FILE"
[[ $fmt_errors -eq 0 ]] && log ".env format is valid"

# --- verdict ---------------------------------------------------------------
echo
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
  if [[ $WARNINGS -gt 0 ]]; then warn "Preflight PASSED with $WARNINGS warning(s)"; else log "Preflight PASSED — ready to start"; fi
  exit 0
else
  err "Preflight FAILED with $ERRORS error(s) — fix the above before starting"
  exit 1
fi
