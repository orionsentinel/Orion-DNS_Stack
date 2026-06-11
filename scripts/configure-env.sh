#!/usr/bin/env bash
# =============================================================================
# configure-env.sh — guided, role-aware first-time configuration of .env.
#
# Invoked by bootstrap.sh on an interactive terminal, or run directly:
#   ./scripts/configure-env.sh --role primary --env .env
#
# It prompts for the handful of values that actually matter (IPs, interface,
# timezone, web password, and — for HA — the VRRP password), validates them,
# and writes them back into .env in place. Everything else in the template is
# left untouched.
#
# It is a deliberate NO-OP when stdin/stdout is not a TTY, or when ASSUME_YES=1
# is set, so the zero-touch (cloud-init / --yes) path is never blocked.
# =============================================================================
set -euo pipefail

c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_r=$'\033[0;31m'; c_b=$'\033[0;34m'; c_bd=$'\033[1m'; c_n=$'\033[0m'
log()  { printf '%s[✓]%s %s\n' "$c_g" "$c_n" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$c_r" "$c_n" "$*" >&2; }
info() { printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }

ROLE=""; ENV_FILE=".env"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2;;
    --env)  ENV_FILE="$2"; shift 2;;
    -h|--help) sed -n '2,16p' "$0"; exit 0;;
    *) err "unknown argument: $1"; exit 2;;
  esac
done

# --- guards: only run when we can actually prompt a human ------------------
if [[ "${ASSUME_YES:-0}" == "1" ]]; then
  info "ASSUME_YES set — skipping interactive configuration."
  exit 0
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  info "Non-interactive shell — skipping interactive configuration."
  exit 0
fi
[[ -f "$ENV_FILE" ]] || { err "env file not found: $ENV_FILE"; exit 1; }
case "$ROLE" in primary|secondary|single) ;; *) err "invalid --role '$ROLE'"; exit 2;; esac

HA=0; [[ "$ROLE" == "primary" || "$ROLE" == "secondary" ]] && HA=1

# --- helpers ---------------------------------------------------------------
# Read a key's current value (everything after the first '='); empty if unset.
get_kv() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

# Set (or append) KEY=VALUE in $ENV_FILE. Value is passed via the environment
# so awk treats it literally — passwords may contain /, &, \ etc.
set_kv() {
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  ORION_KV_VAL="$val" awk -v key="$key" '
    $0 ~ "^" key "=" { print key "=" ENVIRON["ORION_KV_VAL"]; done=1; next }
    { print }
    END { if (!done) print key "=" ENVIRON["ORION_KV_VAL"] }
  ' "$ENV_FILE" > "$tmp" && mv "$tmp" "$ENV_FILE"
}

is_placeholder() { [[ "$1" == CHANGE_ME* || "$1" == "CHANGE_8c" || -z "$1" ]]; }

valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -ra _o <<< "$ip"
  for o in "${_o[@]}"; do ((o <= 255)) || return 1; done
  return 0
}

# prompt_value LABEL DEFAULT VALIDATOR(optional) -> sets global REPLY_VALUE
# (returns via a global, not stdout, so prompts/echoes can't pollute the value)
prompt_value() {
  local label="$1" default="$2" validator="${3:-}" input
  while true; do
    read -r -p "  ${label} [${default}]: " input
    input="${input:-$default}"
    if [[ -n "$validator" ]] && ! "$validator" "$input"; then
      warn "  '$input' is not valid — try again."; continue
    fi
    REPLY_VALUE="$input"; return 0
  done
}

# prompt_secret LABEL VALIDATOR(optional) -> sets global REPLY_VALUE
prompt_secret() {
  local label="$1" validator="${2:-}" a b
  while true; do
    read -r -s -p "  ${label}: " a; echo
    read -r -s -p "  confirm: " b; echo
    if [[ "$a" != "$b" ]]; then warn "  values did not match — try again."; continue; fi
    if [[ -n "$validator" ]] && ! "$validator" "$a"; then continue; fi
    REPLY_VALUE="$a"; return 0
  done
}

valid_webpw() { [[ ${#1} -ge 8 ]] || { warn "  password too short (min 8 chars)"; return 1; }; return 0; }
valid_vrrp()  { [[ ${#1} -eq 8 ]] || { warn "  VRRP password must be EXACTLY 8 characters (got ${#1})"; return 1; }; return 0; }

# --- intro -----------------------------------------------------------------
echo
printf '%s═══ Guided setup (%s node) ═══%s\n' "$c_bd" "$ROLE" "$c_n"
echo "Press Enter to accept the [default]. Edit $ENV_FILE later to change anything."
echo

if [[ "$ROLE" == "secondary" ]]; then
  warn "Node B (secondary): WEBPASSWORD and VRRP_PASSWORD MUST be identical to Node A."
  warn "Paste the exact same values you set on the primary."
  echo
fi

# --- network ---------------------------------------------------------------
prompt_value 'Node IP address'        "$(get_kv NODE_IP)"          valid_ipv4
NODE_IP="$REPLY_VALUE"; set_kv NODE_IP "$NODE_IP"

prompt_value 'Network interface'      "$(get_kv NETWORK_INTERFACE)"
set_kv NETWORK_INTERFACE "$REPLY_VALUE"

prompt_value 'Timezone'               "$(get_kv TZ)"
set_kv TZ "$REPLY_VALUE"

if [[ "$HA" -eq 1 ]]; then
  prompt_value 'Floating VIP address' "$(get_kv VIP_ADDRESS)"      valid_ipv4
  set_kv VIP_ADDRESS "$REPLY_VALUE"

  prompt_value 'Peer node IP (the OTHER node)' "$(get_kv PEER_IP)" valid_ipv4
  set_kv PEER_IP "$REPLY_VALUE"

  # unicast source is this node's own IP; default to what we just set
  USRC_DEFAULT="$(get_kv UNICAST_SRC_IP)"; [[ -n "$USRC_DEFAULT" ]] || USRC_DEFAULT="$NODE_IP"
  prompt_value 'Unicast source IP (this node)' "$USRC_DEFAULT"     valid_ipv4
  set_kv UNICAST_SRC_IP "$REPLY_VALUE"
fi

# --- secrets ---------------------------------------------------------------
echo
CUR_WEB="$(get_kv WEBPASSWORD)"
if is_placeholder "$CUR_WEB"; then
  prompt_secret 'Pi-hole web admin password (min 8 chars)' valid_webpw
  set_kv WEBPASSWORD "$REPLY_VALUE"
else
  info "WEBPASSWORD already set — leave blank to keep it."
  read -r -s -p "  new web admin password (blank = keep): " WEB; echo
  if [[ -n "$WEB" ]]; then
    while ! valid_webpw "$WEB"; do read -r -s -p "  new web admin password: " WEB; echo; done
    set_kv WEBPASSWORD "$WEB"
  fi
fi

if [[ "$HA" -eq 1 ]]; then
  CUR_VRRP="$(get_kv VRRP_PASSWORD)"
  if is_placeholder "$CUR_VRRP"; then
    prompt_secret 'VRRP password (EXACTLY 8 chars, same on both nodes)' valid_vrrp
    set_kv VRRP_PASSWORD "$REPLY_VALUE"
  else
    info "VRRP_PASSWORD already set — leave blank to keep it."
    read -r -s -p "  new VRRP password (blank = keep): " VRRP; echo
    if [[ -n "$VRRP" ]]; then
      while ! valid_vrrp "$VRRP"; do read -r -s -p "  new VRRP password (8 chars): " VRRP; echo; done
      set_kv VRRP_PASSWORD "$VRRP"
    fi
  fi
fi

# --- summary ---------------------------------------------------------------
echo
log "Saved configuration to $ENV_FILE:"
echo "    NODE_IP            = $(get_kv NODE_IP)"
echo "    NETWORK_INTERFACE  = $(get_kv NETWORK_INTERFACE)"
echo "    TZ                 = $(get_kv TZ)"
if [[ "$HA" -eq 1 ]]; then
  echo "    VIP_ADDRESS        = $(get_kv VIP_ADDRESS)"
  echo "    PEER_IP            = $(get_kv PEER_IP)"
  echo "    UNICAST_SRC_IP     = $(get_kv UNICAST_SRC_IP)"
  echo "    VRRP_PASSWORD      = (set, 8 chars)"
fi
echo "    WEBPASSWORD        = (set)"
echo
if [[ "$ROLE" == "primary" ]]; then
  warn "Remember: configure Node B with the SAME WEBPASSWORD and VRRP_PASSWORD."
fi
