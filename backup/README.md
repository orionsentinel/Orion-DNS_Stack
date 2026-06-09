# Backup & Restore Scripts

This directory contains scripts for backing up and restoring critical Docker volumes and configurations for the Orion Sentinel DNS HA stack.

## Overview

The backup system provides automated volume-level backups of:
- **Pi-hole**: Configuration files, blocklists, whitelist, DNS records
- **Unbound**: Resolver configuration, cache settings
- **Keepalived**: High-availability configuration

## Quick Start

### Create a Backup

```bash
# Backup all volumes (requires root)
sudo ./backup/backup-volumes.sh

# Backup to custom location
sudo ./backup/backup-volumes.sh /path/to/backup/location
```

Default backup location: `/srv/backups/orion/YYYY-MM-DD/`

### Restore from Backup

```bash
# Restore all volumes
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz

# Restore only Pi-hole
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz pihole_primary

# Restore only Unbound
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz unbound_primary
```

After restoration, restart the services:
```bash
make restart
# or
docker compose --profile dns-core restart
```

## Critical Volumes

The following volumes are backed up:

| Service | Volume | Description |
|---------|--------|-------------|
| `pihole_primary` | `pihole-etc` | Pi-hole configuration (`/etc/pihole`) |
| `pihole_primary` | `pihole-dnsmasq` | DNS configuration (`/etc/dnsmasq.d`) |
| `unbound_primary` | `unbound-conf` | Unbound configuration (`/opt/unbound/etc/unbound`) |
| `keepalived` | `keepalived-conf` | Keepalived HA configuration (`/etc/keepalived`) |

## Automated Backups

### Weekly Backups (Recommended)

Add to root's crontab:
```bash
sudo crontab -e
```

Add this line for weekly backups every Sunday at 2 AM:
```
0 2 * * 0 /path/to/Orion-DNS_Stack/backup/backup-volumes.sh /srv/backups/orion
```

### Daily Backups

For daily backups at 2 AM:
```
0 2 * * * /path/to/Orion-DNS_Stack/backup/backup-volumes.sh /srv/backups/orion
```

## Backup Retention

By default, `backup-volumes.sh` keeps the last 7 days of backups and automatically deletes older ones to save space.

## Backup Contents

Each backup archive contains:

1. **Configuration files**:
   - `.env` file (contains passwords - store securely!)
   - `compose.yml`
   - Custom configuration from `config/` directory

2. **Docker volumes**:
   - Individual tar.gz archives for each service's volumes

3. **Metadata**:
   - `backup-metadata.txt` with backup information and timestamp

## Important Notes

### Security
- **Backup files contain passwords and sensitive data**
- Store backups in a secure location
- Consider encrypting backups for off-site storage
- The `.env` file contains Pi-hole admin password and other secrets

### Permissions
- Both scripts require root privileges (use `sudo`)
- Backup scripts can read Docker volumes even if containers are stopped

### Restoration Process
1. Stop affected services before restoration (script does this automatically)
2. Restore volumes from backup
3. Restart services to apply restored configuration
4. Verify services are working correctly

## Disaster Recovery Scenarios

### Scenario 1: Pi-hole Configuration Lost

```bash
# Stop Pi-hole
docker compose stop pihole_primary

# Restore Pi-hole volumes
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz pihole_primary

# Restart Pi-hole
docker compose start pihole_primary

# Verify
make health
```

### Scenario 2: Complete System Rebuild

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack

# 2. Restore configuration
sudo ./backup/restore-volume.sh /path/to/backup.tar.gz

# 3. Start services
make up-core

# 4. Verify
make health
```

### Scenario 3: Migrate to New Hardware

```bash
# On old system - create backup
sudo ./backup/backup-volumes.sh /mnt/usb/backups

# On new system - after cloning repo
sudo ./backup/restore-volume.sh /mnt/usb/backups/latest-volumes-backup.tar.gz
make up-core
```

## Troubleshooting

### "Permission denied" errors
- Ensure you're using `sudo` to run the scripts
- Check that Docker is running: `docker ps`

### "Volume not found" warnings during restore
- The script will create volumes automatically if they don't exist
- Ensure Docker compose has been run at least once: `docker compose pull`

### Services not starting after restore
- Check Docker logs: `docker compose logs`
- Verify .env file is properly configured
- Ensure VIP_ADDRESS is not in use by another device

## See Also

- [DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md) - Complete disaster recovery procedures
- [OPERATIONAL_RUNBOOK.md](../OPERATIONAL_RUNBOOK.md) - Day-to-day operations
- [docs/operations.md](../docs/operations.md) - Backup, restore, and upgrade procedures
