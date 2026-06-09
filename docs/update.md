# Update Guide

This guide covers how to update the Orion Sentinel DNS HA stack, including container images, configuration, and the repository itself.

## Table of Contents

1. [Update Philosophy](#update-philosophy)
2. [Before Updating](#before-updating)
3. [Updating Container Images](#updating-container-images)
4. [Updating Configuration](#updating-configuration)
5. [Updating the Repository](#updating-the-repository)
6. [Version Pinning Strategy](#version-pinning-strategy)
7. [Rollback Procedures](#rollback-procedures)
8. [Automated Update Monitoring](#automated-update-monitoring)

## Update Philosophy

**Production-Ready Approach:**
- All images are pinned to specific versions (not `latest`)
- Updates are tested before deployment
- Backups are created before major updates
- Updates can be rolled back if issues occur

**Update Frequency:**
- **Security updates**: Apply within 24-48 hours
- **Minor updates**: Monthly maintenance window
- **Major updates**: Quarterly, with testing

## Before Updating

### 1. Create a Backup

**Always backup before updating:**

```bash
# Create volume backup
sudo ./backup/backup-volumes.sh

# Verify backup was created
ls -lh /srv/backups/orion/
```

### 2. Review Release Notes

Check release notes for breaking changes:
- [Pi-hole Releases](https://github.com/pi-hole/pi-hole/releases)
- [Unbound Docker Releases](https://github.com/MatthewVance/unbound-docker/releases)
- [Keepalived](https://github.com/acassen/keepalived/releases)

### 3. Check Current Versions

```bash
# Show current versions
make version

# Or manually check
docker compose images
```

## Updating Container Images

### Method 1: Using Makefile (Recommended)

```bash
# Pull latest images and restart services
make update

# This is equivalent to:
# make pull
# make restart
```

### Method 2: Manual Update

```bash
# Pull updated images
docker compose pull

# Restart services with new images
docker compose --profile dns-core down
docker compose --profile dns-core up -d

# Verify services are healthy
make health
```

### Method 3: Update Specific Service

```bash
# Pull and update only Pi-hole
docker compose pull pihole_primary
docker compose up -d pihole_primary

# Pull and update only Unbound
docker compose pull unbound_primary
docker compose up -d unbound_primary
```

## Updating Configuration

### Update Environment Variables

1. **Check for new variables:**
   ```bash
   # Compare with example
   diff .env .env.production.example
   ```

2. **Update .env file:**
   ```bash
   nano .env
   # Add any new required variables
   ```

3. **Validate configuration:**
   ```bash
   make validate-env
   ```

4. **Apply changes:**
   ```bash
   make restart
   ```

### Update Compose Configuration

If `compose.yml` has been updated in the repository:

```bash
# Backup current compose file
cp compose.yml compose.yml.backup

# Pull latest changes
git pull origin main

# Review changes
diff compose.yml.backup compose.yml

# Apply changes
docker compose --profile dns-core up -d
```

## Updating the Repository

### Standard Update Process

```bash
# Navigate to repository
cd /path/to/Orion-DNS_Stack

# Backup current state
sudo ./backup/backup-volumes.sh

# Pull latest changes
git pull origin main

# Review changelog
cat CHANGELOG.md

# Update dependencies if needed
docker compose pull

# Restart with new configuration
make restart

# Verify everything is working
make health
```

### Update with Stash (if you have local changes)

```bash
# Stash local changes
git stash

# Pull updates
git pull origin main

# Re-apply local changes
git stash pop

# Resolve any conflicts manually
# Then restart
make restart
```

## Version Pinning Strategy

### Current Approach

Images in `compose.yml` should specify exact versions:

```yaml
services:
  pihole_primary:
    image: pihole/pihole:2024.07.0  # Pinned version
    # NOT: pihole/pihole:latest      # Avoid this
```

### How to Pin Versions

1. **Find the current image digest:**
   ```bash
   docker inspect pihole/pihole:2024.07.0 | grep -A 1 RepoDigests
   ```

2. **Update compose.yml with version:**
   ```yaml
   image: pihole/pihole:2024.07.0
   # Or with digest for extra security:
   # image: pihole/pihole@sha256:abc123...
   ```

3. **Test the update:**
   ```bash
   docker compose --profile dns-core up -d
   make health
   ```

### Recommended Image Versions (as of Dec 2025)

Update `compose.yml` with specific versions:

```yaml
# Example version pinning in compose.yml
pihole/pihole:2024.07.0           # Pi-hole
prom/node-exporter:v1.8.2         # Node Exporter
ekofr/pihole-exporter:v0.4.0      # Pi-hole Exporter
svaloumas/unbound_exporter:v0.4.6 # Unbound Exporter
```

For Unbound (which uses a custom Dockerfile), update `config/unbound/Dockerfile`:
```dockerfile
# Pin the base image version
FROM ghcr.io/klutchell/unbound:1.19.0
# Instead of: FROM ghcr.io/klutchell/unbound:latest
```

## Rollback Procedures

### Rollback to Previous Images

```bash
# Stop current services
docker compose --profile dns-core down

# Pull specific older version
docker pull pihole/pihole:2024.06.0

# Update compose.yml to use older version
sed -i 's/pihole:2024.07.0/pihole:2024.06.0/' compose.yml

# Start with old version
docker compose --profile dns-core up -d

# Verify
make health
```

### Rollback from Backup

```bash
# Stop all services
make down

# Restore from backup
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz

# Restart services
make up-core

# Verify
make health
```

### Emergency Rollback

If services are failing:

```bash
# Complete reset to last known good state
git checkout HEAD~1  # Go back one commit
make down
docker system prune -af
make up-core
```

## Automated Update Monitoring

### Option 1: Manual Monthly Check (Recommended)

Add reminder to crontab:
```bash
sudo crontab -e
```

Add this line to get notified monthly:
```bash
# Monthly reminder to check for updates (1st of month, 9 AM)
0 9 1 * * echo "Reminder: Check Orion DNS HA for updates - run 'make update'" | mail -s "DNS HA Update Check" your-email@example.com
```

### Option 2: Using Diun (Docker Image Update Notifier)

**Note:** This would require additional setup. For now, manual checks are recommended.

If you want to add Diun:
1. Add to `compose.yml`:
   ```yaml
   diun:
     image: crazymax/diun:latest
     command: serve
     volumes:
       - "./config/diun:/data"
       - "/var/run/docker.sock:/var/run/docker.sock"
     environment:
       - TZ=${TZ}
       - LOG_LEVEL=info
     restart: unless-stopped
   ```

2. Configure notification settings in `config/diun/diun.yml`

### Option 3: No Auto-Updates (Current Recommendation)

**Why no auto-updates:**
- DNS is critical infrastructure
- Manual testing ensures stability
- Controlled maintenance windows
- Better oversight of changes

**Best Practice:**
- Schedule monthly maintenance window
- Review and test updates
- Apply updates manually with backup
- Document any issues

## Update Checklist

Use this checklist for updates:

```
[ ] Review CHANGELOG.md and release notes
[ ] Create backup: sudo ./backup/backup-volumes.sh
[ ] Pull repository updates: git pull
[ ] Pull container images: make pull
[ ] Review configuration changes: diff .env .env.production.example
[ ] Apply updates: make restart
[ ] Wait 2-3 minutes for services to stabilize
[ ] Run health check: make health
[ ] Test DNS resolution: dig @192.168.8.249 google.com
[ ] Check Pi-hole admin interface
[ ] Monitor logs: make logs
[ ] Document any issues or changes
```

## Security Updates

### Critical Security Patches

For **urgent security updates**:

```bash
# 1. Create emergency backup
sudo ./backup/backup-volumes.sh /srv/backups/orion/emergency

# 2. Pull and apply immediately
make update

# 3. Monitor for 30 minutes
watch -n 10 'docker compose ps && echo "---" && make health'

# 4. Document in CHANGELOG.md
```

### CVE Monitoring

Stay informed about security issues:
- Subscribe to [Pi-hole Security Advisories](https://github.com/pi-hole/pi-hole/security/advisories)
- Monitor Docker Hub for base image updates
- Check Unbound security announcements

## Troubleshooting Updates

### Services Won't Start After Update

```bash
# Check logs
make logs

# Check specific service
docker compose logs pihole_primary

# Try rebuilding
docker compose build --no-cache
docker compose --profile dns-core up -d
```

### Configuration Errors

```bash
# Validate compose file
docker compose config

# Validate environment
make validate-env

# Check for syntax errors
docker compose --profile dns-core up -d --dry-run
```

### Volume Permission Issues

```bash
# Fix permissions
sudo chown -R 999:999 /var/lib/docker/volumes/

# Or restore from backup
sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz
```

## See Also

- [backup/README.md](../backup/README.md) - Backup and restore procedures
- [OPERATIONAL_RUNBOOK.md](../OPERATIONAL_RUNBOOK.md) - Day-to-day operations
- [DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md) - Disaster recovery procedures
- [CHANGELOG.md](../CHANGELOG.md) - Version history and changes
