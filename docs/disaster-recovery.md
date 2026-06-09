# Disaster Recovery

Goal: **rebuild a fully operational node in under one hour** from a fresh
Raspberry Pi using `git clone` + the latest backup.

## What is backed up

`ops/orion-dns-backup.sh` (daily via systemd timer, 7-day retention) captures
everything needed to reconstruct state:

- `compose.yml` and `.env` files
- `pihole/etc-pihole/` — gravity DB, adlists, whitelist/blacklist, regex, custom
  DNS records, settings
- `pihole/etc-dnsmasq.d/` — dnsmasq config
- `keepalived/config/` — keepalived.conf + notify scripts

Backups land in `backups/dns-ha-backup-<hostname>-<timestamp>.tgz`. **Copy them
off-box** (the SD card is the thing most likely to die) — e.g. to the peer node,
a NAS, or object storage.

```bash
./ops/orion-dns-backup.sh         # manual backup (or: make backup)
ls -lh backups/
```

## Full rebuild (target: < 1 hour)

On a fresh Pi with Raspberry Pi OS (64-bit):

```bash
# 1. Base packages + Docker
sudo apt update
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha

# 2. Restore config + Pi-hole state from the latest backup
./scripts/bootstrap_dirs.sh
./ops/orion-dns-restore.sh backups/dns-ha-backup-<host>-<timestamp>.tgz

# 3. Set the node role (.244/MASTER on A, .245/BACKUP on B)
cp env/primary.env.example .env     # or env/secondary.env.example on Node B
sudo nano .env                      # set secrets + confirm IPs

# 4. Start the stack
docker compose --profile two-node-ha-primary up -d    # backup profile on Node B

# 5. Verify
./scripts/verify-ha.sh
dig @192.168.8.243 github.com +short
```

## Single-node failure (the common case)

No rebuild needed — the surviving node already holds the VIP and is serving DNS.
Replace/repair the dead node, restore as above, bring it up with its role
profile; it rejoins as BACKUP (or reclaims MASTER by priority).

## Restore drill

Test recovery quarterly so the <1h target stays real:

```bash
# On a spare Pi or VM: clone, restore the latest backup, bring up single-node,
# confirm gravity/adlists and custom DNS are present, then tear down. Time it.
docker compose --profile single-node up -d
dig @127.0.0.1 doubleclick.net +short   # expect blocked (0.0.0.0)
```

## Secrets after a rebuild

`.env` files are **not** in backups by default if they were git-ignored — keep
`VRRP_PASSWORD`, `WEBPASSWORD`, and the Pi-hole API password in your password
manager so a rebuild can repopulate them.
