#!/usr/bin/env bash
# selfcheck.sh — quick pre-deploy validation for Orion Sentinel HA DNS.
# Validates: compose parses, env template present, data dirs scaffolded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[1;33m'; N=$'\033[0m'
err=0; warn=0

cd "$REPO_DIR"
echo "Orion Sentinel HA DNS — self-check"
echo

# 1. compose parses (the real validation)
printf 'compose.yml parses... '
if [ -f .env ]; then ENVF=.env; else ENVF=env/primary.env.example; fi
if docker compose --env-file "$ENVF" --profile two-node-ha-primary config -q 2>/dev/null; then
  echo "${G}✓${N}"
else
  echo "${R}✗ (run: docker compose --env-file $ENVF --profile two-node-ha-primary config)${N}"; err=$((err+1))
fi

# 2. env template present
printf 'env templates present... '
if [ -f env/primary.env.example ] && [ -f env/secondary.env.example ]; then echo "${G}✓${N}"; else echo "${R}✗${N}"; err=$((err+1)); fi

# 3. data dirs scaffolded
for d in pihole/etc-pihole pihole/etc-dnsmasq.d pihole/var-log keepalived/config; do
  printf 'dir %s... ' "$d"
  if [ -d "$d" ]; then echo "${G}✓${N}"; else echo "${Y}⚠ missing (run ./scripts/bootstrap_dirs.sh)${N}"; warn=$((warn+1)); fi
done

# 4. pihole.log must be a file, not a dir
printf 'pihole/var-log/pihole.log not a dir... '
if [ -d pihole/var-log/pihole.log ]; then
  echo "${R}✗ is a directory — rm -rf it and touch the file${N}"; err=$((err+1))
else echo "${G}✓${N}"; fi

echo
if [ "$err" -eq 0 ]; then echo "${G}OK${N} ($warn warning(s))"; exit 0; else echo "${R}$err error(s), $warn warning(s)${N}"; exit 1; fi
