#!/usr/bin/env bash
# =============================================================================
# firstboot.sh — idempotent first-boot provisioning for an Orion DNS node.
#
# Called by cloud-init (see provisioning/cloud-init/*.yaml), or by hand:
#   sudo provisioning/firstboot.sh --env /etc/orion-dns/node.env
#
# It clones (or fast-forwards) the repo, installs the per-node secrets as .env,
# runs the existing bootstrap.sh non-interactively, and installs the systemd
# units. Re-running it (or reflashing the Pi) converges to the same state.
#
# Secrets live ONLY in the per-node env file delivered by cloud-init — never in
# the repo or the image.
# =============================================================================
set -euo pipefail

REPO_URL="${ORION_REPO_URL:-https://github.com/orionsentinel/Orion-DNS_Stack.git}"
REPO_DIR="${ORION_REPO_DIR:-/opt/orion-dns-ha}"
ENV_SRC="/etc/orion-dns/node.env"
ROLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)  ENV_SRC="$2"; shift 2;;
    --repo) REPO_URL="$2"; shift 2;;
    --dir)  REPO_DIR="$2"; shift 2;;
    --role) ROLE="$2"; shift 2;;
    *) echo "firstboot: unknown argument: $1" >&2; exit 2;;
  esac
done

log() { printf '[orion-firstboot] %s\n' "$*"; }

# Set (or append) KEY=VALUE in a file, value passed literally via the environment.
set_kv() {
  local key="$1" val="$2" file="$3" tmp
  tmp="$(mktemp)"
  ORION_KV_VAL="$val" awk -v key="$key" '
    $0 ~ "^" key "=" { print key "=" ENVIRON["ORION_KV_VAL"]; done=1; next }
    { print }
    END { if (!done) print key "=" ENVIRON["ORION_KV_VAL"] }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

[[ -f "$ENV_SRC" ]] || { echo "firstboot: per-node env file not found: $ENV_SRC" >&2; exit 1; }

# Derive role from NODE_ROLE in the secrets file if not given explicitly.
if [[ -z "$ROLE" ]]; then
  case "$(grep -E '^NODE_ROLE=' "$ENV_SRC" | head -1 | cut -d= -f2- | tr -d '\r')" in
    MASTER) ROLE=primary;;
    BACKUP) ROLE=secondary;;
    *)      ROLE=single;;
  esac
fi
log "role=$ROLE repo=$REPO_DIR"

# 1. clone or fast-forward the repo (idempotent)
if [[ -d "$REPO_DIR/.git" ]]; then
  log "repo present — fast-forwarding"
  git -C "$REPO_DIR" pull --ff-only || log "git pull skipped (offline or diverged)"
else
  log "cloning $REPO_URL"
  git clone "$REPO_URL" "$REPO_DIR"
fi

# 2. seed .env from the FULL role template (keeps all stack defaults), then
#    overlay the per-node values from node.env on top.
case "$ROLE" in
  primary)   TEMPLATE="env/primary.env.example";;
  secondary) TEMPLATE="env/secondary.env.example";;
  single)    TEMPLATE=".env.example";;
esac
if [[ ! -f "$REPO_DIR/.env" ]]; then
  install -m600 "$REPO_DIR/$TEMPLATE" "$REPO_DIR/.env"
  log "seeded .env from $TEMPLATE"
fi
# overlay every KEY=VALUE from the per-node secrets file
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  set_kv "${line%%=*}" "${line#*=}" "$REPO_DIR/.env"
done < "$ENV_SRC"
chmod 600 "$REPO_DIR/.env"
log "applied per-node values from $ENV_SRC"

# 3. bootstrap the stack non-interactively
cd "$REPO_DIR"
./bootstrap.sh --role "$ROLE" --yes

# 4. install systemd units (boot persistence + timers)
case "$ROLE" in
  primary)   make install-systemd-primary;;
  secondary) make install-systemd-secondary;;
  single)    log "single node — no HA systemd units to install";;
esac

# 5. best-effort verification
if [[ "$ROLE" != "single" && -x "$REPO_DIR/scripts/verify-ha.sh" ]]; then
  "$REPO_DIR/scripts/verify-ha.sh" || true
fi

log "done — node '$ROLE' provisioned"
