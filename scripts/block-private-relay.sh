#!/usr/bin/env bash
# =============================================================================
# block-private-relay.sh — stop iCloud Private Relay from routing your iPhones'
# DNS around Pi-hole (the #1 reason "ads still show on iPhone").
#
# Adds Apple's Private Relay ingress domains to Pi-hole's exact deny list. With
# these blocked, iOS shows "Private Relay unavailable on this network" and Safari
# falls back to YOUR DNS (Pi-hole) — so your blocklists apply again.
#
#   ./scripts/block-private-relay.sh            # apply (backs up gravity.db first)
#   ./scripts/block-private-relay.sh --dry-run  # show the SQL, change nothing
#   ./scripts/block-private-relay.sh --remove   # undo
#
# Run on the PRIMARY node; replicate with ./scripts/pihole-sync.sh.
# =============================================================================
set -euo pipefail

c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_b=$'\033[0;34m'; c_r=$'\033[0;31m'; c_n=$'\033[0m'
log(){ printf '%s[✓]%s %s\n' "$c_g" "$c_n" "$*"; }
info(){ printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }
warn(){ printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }
err(){ printf '%s[✗]%s %s\n' "$c_r" "$c_n" "$*" >&2; }

CONTAINER="${PIHOLE_CONTAINER:-pihole_unbound}"
GDB=/etc/pihole/gravity.db
APPLY=1; REMOVE=0

# Apple's documented Private Relay ingress hostnames.
DOMAINS=(mask.icloud.com mask-h2.icloud.com mask-api.icloud.com)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) APPLY=0; shift;;
    --remove) REMOVE=1; shift;;
    --container) CONTAINER="$2"; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) err "unknown arg: $1"; exit 2;;
  esac
done

build_sql() {
  echo "BEGIN;"
  if [[ "$REMOVE" -eq 1 ]]; then
    for d in "${DOMAINS[@]}"; do
      echo "DELETE FROM domainlist_by_group WHERE domainlist_id=(SELECT id FROM domainlist WHERE type=1 AND domain='$d');"
      echo "DELETE FROM domainlist WHERE type=1 AND domain='$d';"
    done
    echo "COMMIT;"; return
  fi
  for d in "${DOMAINS[@]}"; do
    # type 1 = exact deny; link to the default group (0) so it applies to all clients
    echo "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (1,'$d',1,'orion-private-relay');"
    echo "INSERT OR IGNORE INTO domainlist_by_group (domainlist_id,group_id) VALUES ((SELECT id FROM domainlist WHERE type=1 AND domain='$d'),0);"
  done
  echo "COMMIT;"
}

SQL="$(build_sql)"

if [[ "$APPLY" -eq 0 ]]; then
  info "DRY-RUN — SQL for $CONTAINER:$GDB:"; echo "$SQL"; exit 0
fi

command -v docker >/dev/null || { err "docker not found"; exit 1; }
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" || { err "container '$CONTAINER' not running"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
docker exec "$CONTAINER" sh -c "cp $GDB $GDB.$ts.bak"
printf '%s\n' "$SQL" | docker exec -i "$CONTAINER" sqlite3 "$GDB"
docker exec "$CONTAINER" pihole reloaddns >/dev/null 2>&1 || docker exec "$CONTAINER" pihole restartdns >/dev/null 2>&1 || true

if [[ "$REMOVE" -eq 1 ]]; then
  log "Private Relay block removed (${#DOMAINS[@]} domains). Backup: gravity.db.$ts.bak"
else
  log "iCloud Private Relay blocked: ${DOMAINS[*]}"
  info "On each iPhone: Settings → your name → iCloud → Private Relay shows 'unavailable on this network' (expected)."
  info "Also turn OFF per-network 'Limit IP Address Tracking' (Wi-Fi → (i)). Replicate: ./scripts/pihole-sync.sh"
fi
