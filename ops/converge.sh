#!/usr/bin/env bash
# =============================================================================
# converge.sh — GitOps: pull the declared repo state and re-apply it.
#
# Makes the repo the literal source of truth: a node fetches the configured ref,
# fast-forwards, re-applies the stack, and **rolls back automatically** if DNS
# stops answering. Run from a systemd timer (orion-dns-ha-converge.timer) so the
# fleet self-heals to the declared state — drift becomes impossible.
#
# SAFE BY DESIGN:
#   - aborts if the working tree is dirty (won't clobber local edits)
#   - fast-forward only (no surprise merges/rewrites)
#   - validates compose before applying
#   - verifies DNS after applying; on failure, resets to the previous commit and
#     brings the known-good stack back up
#
# Pin CONVERGE_REF to a release TAG in .env for production safety (operator
# promotes a tag); default 'main' tracks latest.
#
#   ./ops/converge.sh            # converge now (or: make converge)
# =============================================================================
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/orion-dns-ha}"
cd "$REPO_DIR"
# shellcheck disable=SC1091
[ -f .env ] && { set -a; . ./.env; set +a; }

REF="${CONVERGE_REF:-main}"
PIHOLE="${PIHOLE_CONTAINER:-pihole_unbound}"
case "${NODE_ROLE:-}" in
  MASTER) PROFILE=two-node-ha-primary;;
  BACKUP) PROFILE=two-node-ha-backup;;
  *)      PROFILE=single-node;;
esac
log() { echo "[$(date -Iseconds)] [converge] $*" >&2; }

dns_ok() { docker exec "$PIHOLE" dig +tries=1 +time=2 @127.0.0.1 pi.hole >/dev/null 2>&1; }

apply() { docker compose --profile "$PROFILE" up -d; }

# 0. preconditions
command -v git >/dev/null    || { log "git not found"; exit 1; }
command -v docker >/dev/null || { log "docker not found"; exit 1; }
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "working tree is dirty — aborting (commit or stash local changes first)"; exit 1
fi

# 1. fetch the target ref
git fetch --quiet origin "$REF" || { log "git fetch origin $REF failed"; exit 1; }
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse FETCH_HEAD)"
if [ "$LOCAL" = "$REMOTE" ]; then
  log "already at $REF (${LOCAL:0:8}) — nothing to converge"; exit 0
fi
log "converging ${LOCAL:0:8} → ${REMOTE:0:8} (ref: $REF)"

# 2. fast-forward only
if ! git merge --ff-only "$REMOTE" 2>/dev/null; then
  log "remote is not a fast-forward of local — aborting (manual reconcile needed)"; exit 1
fi

# 3. validate before applying
if ! docker compose --profile "$PROFILE" config -q; then
  log "compose invalid after pull — rolling back to ${LOCAL:0:8}"
  git reset --hard "$LOCAL" >/dev/null; exit 1
fi

# 4. apply
docker compose --profile "$PROFILE" pull -q || true
apply

# 5. verify DNS, roll back on failure
ok=0
for _ in $(seq 1 20); do dns_ok && { ok=1; break; }; sleep 3; done
if [ "$ok" != 1 ]; then
  log "DNS not answering after converge — ROLLING BACK to ${LOCAL:0:8}"
  git reset --hard "$LOCAL" >/dev/null
  docker compose --profile "$PROFILE" pull -q || true
  apply
  log "rolled back."; exit 1
fi

log "converged to ${REMOTE:0:8}; DNS healthy."
