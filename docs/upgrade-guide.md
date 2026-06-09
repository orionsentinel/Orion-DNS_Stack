# Upgrade Guide

Upgrades are deliberately boring: pull the repo, pull images, recreate. Do **one
node at a time** so DNS never drops — the peer holds the VIP while you work.

## Routine upgrade (rolling, zero-downtime)

Do Node B (BACKUP) first, verify, then Node A.

```bash
cd /opt/orion-dns-ha
./ops/orion-dns-backup.sh                 # snapshot first
git pull
docker compose pull                       # pull updated images
docker compose --profile two-node-ha-backup up -d   # recreate (backup profile on B)
./scripts/verify-ha.sh
dig @192.168.8.245 github.com +short
```

When Node B is healthy, repeat on Node A with `--profile two-node-ha-primary`.
Trigger a failover test afterwards (`docker stop pihole_unbound keepalived` on A,
confirm the VIP moves to B, restart A).

## Pinning image versions

The canonical DNS image is pinned (`...docker-pihole-unbound:2025.03.0`). To move
to a newer tag, bump it in `compose.yml`, commit on a `feature/*` branch, let CI
validate (compose-config + ARM64 manifest check), then roll it out per above.
Avoid `:latest` in production — pin and upgrade intentionally.

## Dependency updates

Dependabot opens PRs for the Python helper apps (`wizard/`, `stacks/setup-ui/`).
Merge security updates promptly after CI passes.

## Rollback

```bash
cd /opt/orion-dns-ha
git checkout <previous-good-tag-or-sha>
docker compose pull
docker compose --profile two-node-ha-primary up -d   # or backup profile
# If state is bad, restore the pre-upgrade backup:
./ops/orion-dns-restore.sh backups/dns-ha-backup-<host>-<timestamp>.tgz
```

## OS / Docker upgrades

`sudo apt update && sudo apt full-upgrade` one node at a time; reboot the BACKUP
first. The stack is `restart: unless-stopped`, so containers return on boot.
