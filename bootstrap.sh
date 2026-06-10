#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — single-command provisioning for an Orion DNS HA node.
#
#   sudo apt update
#   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
#   cd /opt/orion-dns-ha
#   ./bootstrap.sh                      # interactive: pick role, then it does the rest
#
# Non-interactive:
#   sudo ./bootstrap.sh --role primary --yes
#   sudo ./bootstrap.sh --role secondary --configure-nic --yes
#   sudo ./bootstrap.sh --role single
#
# What it does (idempotent):
#   1. checks OS/arch (warns if not arm64)         5. (optional) pins the fast NIC
#   2. installs Docker + compose plugin if missing 6. brings the stack up (role profile)
#   3. scaffolds Pi-hole data dirs                 7. verifies DNS + VIP
#   4. seeds .env from the role template
#
# Roles → compose profile / env template:
#   primary   → two-node-ha-primary  / env/primary.env.example
#   secondary → two-node-ha-backup   / env/secondary.env.example
#   single    → single-node          / .env.example
# Canonical addressing lives in docs/networking.md.
# =============================================================================
set -euo pipefail

c_g=$'\033[0;32m'; c_y=$'\033[1;33m'; c_r=$'\033[0;31m'; c_b=$'\033[0;34m'; c_bd=$'\033[1m'; c_n=$'\033[0m'
log()  { printf '%s[✓]%s %s\n' "$c_g" "$c_n" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_y" "$c_n" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$c_r" "$c_n" "$*" >&2; }
info() { printf '%s[i]%s %s\n' "$c_b" "$c_n" "$*"; }
step() { printf '\n%s═══ %s ═══%s\n' "$c_bd" "$*" "$c_n"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

ROLE=""; ASSUME_YES=0; DO_NIC=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2;;
    --yes|-y) ASSUME_YES=1; shift;;
    --configure-nic) DO_NIC=1; shift;;
    -h|--help) sed -n '2,30p' "$0"; exit 0;;
    *) err "unknown argument: $1"; exit 2;;
  esac
done

SUDO=""; [[ "$(id -u)" -ne 0 ]] && SUDO="sudo"
INTERACTIVE=0; [[ -t 0 && -t 1 ]] && INTERACTIVE=1

# --- role ------------------------------------------------------------------
if [[ -z "$ROLE" ]]; then
  echo "Select node role:"
  select r in "primary (Node A, MASTER)" "secondary (Node B, BACKUP)" "single (no HA)"; do
    case "$REPLY" in 1) ROLE=primary;; 2) ROLE=secondary;; 3) ROLE=single;; *) continue;; esac
    break
  done
fi
case "$ROLE" in
  primary)   PROFILE="two-node-ha-primary"; TEMPLATE="env/primary.env.example";;
  secondary) PROFILE="two-node-ha-backup";  TEMPLATE="env/secondary.env.example";;
  single)    PROFILE="single-node";         TEMPLATE=".env.example";;
  *) err "invalid --role '$ROLE' (use primary|secondary|single)"; exit 2;;
esac
info "Role: $ROLE  →  profile '$PROFILE', template '$TEMPLATE'"

# --- 1. OS / arch ----------------------------------------------------------
step "Checking system"
[[ "$(uname -s)" == "Linux" ]] || { err "Linux only"; exit 1; }
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64) log "arch $ARCH (ARM64) ✓";;
  x86_64) warn "arch $ARCH — fine for testing, but this stack targets ARM64 Raspberry Pi";;
  *) warn "unrecognised arch $ARCH — proceeding";;
esac

# --- 2. Docker -------------------------------------------------------------
step "Ensuring Docker + compose"
if ! command -v docker >/dev/null 2>&1; then
  info "installing Docker via get.docker.com"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO usermod -aG docker "${SUDO_USER:-$USER}" || true
  warn "added you to the 'docker' group — log out/in for it to take effect"
fi
if ! docker compose version >/dev/null 2>&1; then
  info "installing docker compose plugin"
  $SUDO apt-get update -qq && $SUDO apt-get install -y docker-compose-plugin
fi
docker --version; docker compose version

# --- 3. data dirs ----------------------------------------------------------
step "Scaffolding data directories"
bash "$REPO_DIR/scripts/bootstrap_dirs.sh"

# --- 4. .env ---------------------------------------------------------------
step "Configuring environment (.env)"
if [[ ! -f .env ]]; then
  [[ -f "$TEMPLATE" ]] || { err "template $TEMPLATE missing"; exit 1; }
  cp "$TEMPLATE" .env
  log "seeded .env from $TEMPLATE"
fi
# If secrets are still placeholders, guide the user through filling them in
# (interactive only). The zero-touch path (--yes / no TTY) skips the wizard.
if grep -qE '^(WEBPASSWORD=CHANGE_ME|VRRP_PASSWORD=CHANGE_8c)' .env; then
  if [[ "$INTERACTIVE" -eq 1 && "$ASSUME_YES" -eq 0 ]]; then
    bash "$REPO_DIR/scripts/configure-env.sh" --role "$ROLE" --env .env \
      || warn "configuration wizard exited early — falling back to manual edit"
  fi
fi
# Final safety net: refuse to start with placeholder secrets unless overridden.
if grep -qE '^(WEBPASSWORD=CHANGE_ME|VRRP_PASSWORD=CHANGE_8c)' .env; then
  warn "Edit .env and set real secrets before starting:"
  warn "    sudo nano $REPO_DIR/.env"
  warn "  - WEBPASSWORD (strong, unique)"
  warn "  - VRRP_PASSWORD (EXACTLY 8 chars, identical on both nodes)"
  warn "  - confirm NODE_IP / VIP_ADDRESS / NETWORK_INTERFACE (see docs/networking.md)"
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    err "stopping so you can edit secrets; re-run bootstrap.sh when done."
    exit 1
  fi
  warn "--yes given: continuing with placeholder secrets (NOT for production)"
fi

# --- 5. optional fast NIC --------------------------------------------------
if [[ "$DO_NIC" -eq 1 ]]; then
  step "Configuring dedicated NIC"
  $SUDO bash "$REPO_DIR/scripts/configure-nic.sh" || warn "NIC config skipped/failed — see docs/networking.md"
fi

# --- 6. preflight + bring up -----------------------------------------------
step "Preflight checks"
if ! bash "$REPO_DIR/scripts/validate-env.sh" .env; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    warn "--yes given: continuing despite preflight errors (NOT for production)"
  else
    err "preflight failed — fix the above in .env and re-run bootstrap.sh"
    exit 1
  fi
fi

step "Starting the stack (profile: $PROFILE)"
docker compose --profile "$PROFILE" config -q || { err "compose config invalid"; exit 1; }
docker compose --profile "$PROFILE" up -d

# --- 7. verify -------------------------------------------------------------
step "Verifying"
sleep 5
if [[ "$ROLE" == "single" ]]; then
  if docker compose --profile "$PROFILE" exec -T pihole_unbound dig @127.0.0.1 github.com +short >/dev/null 2>&1; then
    log "DNS resolving locally ✓"
  else
    warn "local DNS check inconclusive — give it a minute, then: dig @127.0.0.1 github.com"
  fi
else
  if [[ -x "$REPO_DIR/scripts/verify-ha.sh" ]]; then
    bash "$REPO_DIR/scripts/verify-ha.sh" || warn "verify-ha reported issues — see docs/troubleshooting.md"
  fi
fi

step "Done"
log "Node '$ROLE' is up."
info "Next:"
info "  • Point your router's DHCP DNS at the VIP (see docs/networking.md)."
[[ "$ROLE" == "primary" ]]   && info "  • Now bootstrap Node B:  sudo ./bootstrap.sh --role secondary"
info "  • Health/HA:  ./scripts/verify-ha.sh    Backups:  make backup"
info "  • Pi-hole admin:  http://<node-ip>/admin"
