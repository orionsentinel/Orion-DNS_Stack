#!/usr/bin/env bash
# =============================================================================
# setup-iot-containment.sh — create a Pi-hole "IoT" group, put your cameras/IoT
# devices in it, and apply telemetry-deny regex to that group only.
#
# SAFE BY DEFAULT: dry-run (prints the SQL it WOULD run). Use --apply to execute.
# It backs up gravity.db first and uses INSERT OR IGNORE (idempotent, re-runnable).
# Run on the PRIMARY Pi-hole; let scripts/pihole-sync.sh replicate to the peer.
#
#   ./scripts/setup-iot-containment.sh                 # dry-run (review the SQL)
#   ./scripts/setup-iot-containment.sh --apply         # apply on the primary node
#   ./scripts/setup-iot-containment.sh --remove --apply # tear the group down
#
# Device list + regex mirror profiles/iot.yml — edit there and here together, or
# override IOT_IPS / IOT_REGEX in the environment. See docs/iot-containment.md.
# =============================================================================
set -euo pipefail

c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_b=$'\033[0;34m'; c_n=$'\033[0m'
log(){ printf '%s[✓]%s %s\n' "$c_g" "$c_n" "$*"; }
warn(){ printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }
info(){ printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }

CONTAINER="${PIHOLE_CONTAINER:-pihole_unbound}"
GROUP="${IOT_GROUP:-IoT}"
GDB=/etc/pihole/gravity.db
APPLY=0; REMOVE=0

# Defaults mirror profiles/iot.yml (ip|comment)
IOT_DEVICES=(
  "192.168.8.100|Tapo C220 hallway"
  "192.168.8.107|Tapo D210"
  "192.168.8.137|Tapo C400"
  "192.168.8.142|Tapo C410"
  "192.168.8.109|unknown Tapo"
  "192.168.8.209|unknown device"
  "192.168.8.101|unknown device"
)
IOT_REGEX=(
  '(^|\.)telemetry\.'
  '(^|\.)metrics\.'
  '(^|\.)analytics\.'
  '(^|\.)tracking\.'
  '(^|\.)data-?collect(ion)?\.'
  '(^|\.)tplinkra\.com$'
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --remove) REMOVE=1; shift;;
    --container) CONTAINER="$2"; shift 2;;
    --group) GROUP="$2"; shift 2;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) warn "unknown arg: $1"; exit 2;;
  esac
done

sql_escape(){ printf "%s" "$1" | sed "s/'/''/g"; }

build_sql() {
  echo "BEGIN;"
  if [[ "$REMOVE" -eq 1 ]]; then
    echo "DELETE FROM domainlist_by_group WHERE group_id=(SELECT id FROM \"group\" WHERE name='$(sql_escape "$GROUP")');"
    echo "DELETE FROM domainlist WHERE comment='orion-iot';"
    echo "DELETE FROM client_by_group WHERE group_id=(SELECT id FROM \"group\" WHERE name='$(sql_escape "$GROUP")');"
    echo "DELETE FROM \"group\" WHERE name='$(sql_escape "$GROUP")';"
    echo "COMMIT;"
    return
  fi
  echo "INSERT OR IGNORE INTO \"group\" (enabled,name,description) VALUES (1,'$(sql_escape "$GROUP")','Orion IoT containment');"
  local d ip comment
  for d in "${IOT_DEVICES[@]}"; do
    ip="${d%%|*}"; comment="$(sql_escape "${d#*|}") [orion-iot]"
    echo "INSERT OR IGNORE INTO client (ip,comment) VALUES ('$ip','$comment');"
    # member of the IoT group AND the default group (0) so base blocking still applies
    echo "INSERT OR IGNORE INTO client_by_group (client_id,group_id) VALUES ((SELECT id FROM client WHERE ip='$ip'),(SELECT id FROM \"group\" WHERE name='$(sql_escape "$GROUP")'));"
    echo "INSERT OR IGNORE INTO client_by_group (client_id,group_id) VALUES ((SELECT id FROM client WHERE ip='$ip'),0);"
  done
  local r
  for r in "${IOT_REGEX[@]}"; do
    echo "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'$(sql_escape "$r")',1,'orion-iot');"
    echo "INSERT OR IGNORE INTO domainlist_by_group (domainlist_id,group_id) VALUES ((SELECT id FROM domainlist WHERE type=3 AND domain='$(sql_escape "$r")'),(SELECT id FROM \"group\" WHERE name='$(sql_escape "$GROUP")'));"
  done
  echo "COMMIT;"
}

SQL="$(build_sql)"

if [[ "$APPLY" -eq 0 ]]; then
  info "DRY-RUN — SQL that would run against $CONTAINER:$GDB (use --apply to execute):"
  echo "$SQL"
  warn "Review carefully, then re-run with --apply. After applying, TEST your devices"
  warn "(e.g. Tapo app remote view) and check the query log / Grafana for over-blocking."
  exit 0
fi

command -v docker >/dev/null || { warn "docker not found"; exit 1; }
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" || { warn "container '$CONTAINER' not running"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
info "Backing up gravity.db → /etc/pihole/gravity.db.$ts.bak (inside container)"
docker exec "$CONTAINER" sh -c "cp $GDB $GDB.$ts.bak"

info "Applying group changes..."
printf '%s\n' "$SQL" | docker exec -i "$CONTAINER" sqlite3 "$GDB"
docker exec "$CONTAINER" pihole reloaddns >/dev/null 2>&1 || docker exec "$CONTAINER" pihole restartdns >/dev/null 2>&1 || true

if [[ "$REMOVE" -eq 1 ]]; then
  log "IoT containment group '$GROUP' removed. Backup: gravity.db.$ts.bak"
else
  log "IoT group '$GROUP' applied with ${#IOT_DEVICES[@]} devices + ${#IOT_REGEX[@]} regex rules."
  info "Now: test devices, watch Grafana/query log, then add the specific telemetry"
  info "hostnames you observe. Revert anytime: $0 --remove --apply"
  info "Replicate to the peer: ./scripts/pihole-sync.sh"
fi
