# Operations & Maintenance Guide

**Orion Sentinel DNS HA - Day-to-Day Operations**

This guide covers routine operations, maintenance procedures, and best practices for managing your DNS HA stack.

---

## Table of Contents

- [Configuration Backups](#configuration-backups)
- [Upgrading the Stack](#upgrading-the-stack)
- [Restore from Backup](#restore-from-backup)
- [Routine Maintenance](#routine-maintenance)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)

---

## Configuration Backups

### Creating a Backup

**Always create a backup before making major changes** such as:
- Upgrading the stack
- Modifying configuration files
- Changing network settings
- Updating Pi-hole blocklists

**Quick Backup:**
```bash
cd /path/to/Orion-DNS_Stack
bash scripts/backup-config.sh
```

**What Gets Backed Up:**
- ✅ Environment configuration (`.env` files)
- ✅ Docker Compose files
- ✅ Pi-hole configuration and databases
- ✅ Unbound configuration
- ✅ Keepalived configuration
- ✅ DNS security profiles
- ✅ Prometheus configuration
- ✅ Grafana dashboards

**Backup Location:**
- Backups are stored in `backups/` directory
- Format: `dns-ha-backup-YYYYMMDD_HHMMSS.tar.gz`
- SHA256 checksum file is created for integrity verification
- By default, the last 10 backups are kept (configurable via `KEEP_BACKUPS` environment variable)

**Scheduled Backups:**

Add to crontab for automatic weekly backups:
```bash
# Edit crontab
crontab -e

# Add this line for weekly backups (Sundays at 2 AM)
0 2 * * 0 /path/to/Orion-DNS_Stack/scripts/backup-config.sh >> /var/log/dns-backup.log 2>&1
```

**Custom Backup Location:**
```bash
# Specify custom backup directory
BACKUP_DIR=/mnt/external/backups bash scripts/backup-config.sh
```

---

## Upgrading the Stack

### Recommended Upgrade Flow

The `upgrade.sh` script provides a safe, automated upgrade process:

```bash
cd /path/to/Orion-DNS_Stack
bash scripts/upgrade.sh
```

**What the Upgrade Script Does:**

1. **Creates Backup**: Automatically backs up current configuration
2. **Git Pull**: Pulls latest changes from the repository
3. **Docker Pull**: Downloads latest Docker images
4. **Restarts Stack**: Applies updates by restarting containers

**Upgrade Steps (Automated):**
```
Step 1/4: Creating configuration backup...
Step 2/4: Pulling latest changes from git...
Step 3/4: Pulling latest Docker images...
Step 4/4: Restarting DNS stack with updated images...
```

### Pre-Upgrade Checklist

Before upgrading, verify:
- [ ] System has adequate disk space (`df -h`)
- [ ] No active DNS issues or incidents
- [ ] Backup was created successfully
- [ ] You have terminal access to the system
- [ ] Consider upgrade during low-traffic period

### Post-Upgrade Verification

After upgrade completes:

1. **Check Container Status:**
   ```bash
   docker ps
   # All containers should show "Up" status
   ```

2. **Test DNS Resolution:**
   ```bash
   dig @192.168.8.255 google.com
   # Should return valid response
   ```

3. **Verify Pi-hole Admin Panel:**
   - Visit: http://192.168.8.251/admin
   - Check query statistics
   - Verify blocklists are loaded

4. **Monitor Logs for Errors:**
   ```bash
   cd stacks/dns
   docker compose logs -f
   # Watch for any errors or warnings
   ```

### Rollback Procedure

If the upgrade causes issues:

1. **Identify the Backup:**
   ```bash
   ls -lt backups/
   # Find the most recent backup before upgrade
   ```

2. **Restore from Backup:**
   ```bash
   bash scripts/restore-config.sh backups/dns-ha-backup-YYYYMMDD_HHMMSS.tar.gz
   ```

3. **Verify Services:**
   ```bash
   docker ps
   dig @192.168.8.255 google.com
   ```

---

## Restore from Backup

### When to Restore

Restore from backup when:
- Recovering from configuration errors
- Migrating to new hardware
- Recovering from system failure
- Testing disaster recovery procedures

### Restore Procedure

**Basic Restore:**
```bash
cd /path/to/Orion-DNS_Stack
bash scripts/restore-config.sh backups/dns-ha-backup-YYYYMMDD_HHMMSS.tar.gz
```

**The restore script will:**
1. Verify backup integrity (checksum validation)
2. Display backup information
3. **Ask for confirmation** before making changes
4. Stop the DNS stack
5. Restore all configuration files
6. Start the DNS stack with restored configuration

**Dry-Run (Preview Changes):**
```bash
bash scripts/restore-config.sh backups/backup.tar.gz --dry-run
# Shows what would be restored without making changes
```

**Selective Restore:**
```bash
# Skip Pi-hole data restoration
bash scripts/restore-config.sh backups/backup.tar.gz --skip-pihole

# Skip docker-compose files
bash scripts/restore-config.sh backups/backup.tar.gz --skip-compose
```

### Migration to New Hardware

When migrating to a new Pi:

1. **On Old System:**
   ```bash
   bash scripts/backup-config.sh
   # Copy the backup file to external storage
   ```

2. **On New System:**
   ```bash
   # Clone repository
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   
   # Copy backup file to backups/ directory
   # Then restore
   bash scripts/restore-config.sh backups/dns-ha-backup-YYYYMMDD_HHMMSS.tar.gz
   ```

3. **Update Network Configuration:**
   - Edit `.env` file to update IP addresses for new hardware
   - Restart stack: `cd stacks/dns && docker compose down && docker compose up -d`

---

## Routine Maintenance

### Weekly Tasks

**Automated (Recommended):**
```bash
# Setup automated weekly maintenance
sudo bash scripts/setup-cron.sh
```

**Manual Weekly Tasks:**
1. **Review Logs:**
   ```bash
   # Check for errors or warnings
   cd stacks/dns
   docker compose logs --tail=100
   ```

2. **Monitor Disk Space:**
   ```bash
   df -h
   # Ensure adequate space for logs and backups
   ```

3. **Review Pi-hole Statistics:**
   - Check query volume
   - Verify blocking effectiveness
   - Review top blocked domains

4. **Check for Updates:**
   ```bash
   bash scripts/check-updates.sh
   ```

### Monthly Tasks

1. **Review Blocklists:**
   - Update Pi-hole blocklists
   - Remove or add lists as needed
   - Whitelist false positives

2. **Review Backup Strategy:**
   - Verify backups are completing
   - Test restore procedure (dry-run)
   - Ensure off-site backup copy exists

3. **Security Review:**
   - Check for available security updates
   - Review access logs
   - Verify VIP failover is working (if HA configured)

### Quarterly Tasks

1. **Full System Upgrade:**
   ```bash
   # OS updates
   sudo apt update && sudo apt upgrade -y
   
   # Stack upgrade
   bash scripts/upgrade.sh
   ```

2. **Disaster Recovery Test:**
   - Perform full restore from backup
   - Document recovery time
   - Update procedures if needed

---

## Health Checks

### Quick Health Check

```bash
# Automated health check
bash scripts/health-check.sh
```

**Manual Health Checks:**

1. **Container Status:**
   ```bash
   docker ps
   # Check all containers are "Up"
   ```

2. **DNS Resolution:**
   ```bash
   # Test primary Pi-hole
   dig @192.168.8.251 google.com
   
   # Test secondary Pi-hole
   dig @192.168.8.252 google.com
   
   # Test VIP
   dig @192.168.8.255 google.com
   ```

3. **Unbound Status:**
   ```bash
   # Check Unbound logs
   docker logs unbound_primary
   docker logs unbound_secondary
   ```

4. **Keepalived VIP:**
   ```bash
   # Check which node is MASTER
   docker logs keepalived
   # Look for "Entering MASTER STATE" or "Entering BACKUP STATE"
   ```

### Health Monitoring Dashboard

Access Grafana for visual health monitoring:
- URL: http://192.168.8.250:3000
- Dashboard: DNS HA Overview
- Metrics include:
  - Query rates
  - DNS latency
  - Container health
  - System resources

---

## Troubleshooting

### DNS Not Resolving

**Symptoms:** Clients cannot resolve DNS queries

**Diagnosis:**
```bash
# Check DNS containers are running
docker ps | grep pihole

# Test DNS directly
dig @192.168.8.251 google.com
dig @192.168.8.252 google.com

# Check logs
cd stacks/dns
docker compose logs pihole_primary
docker compose logs pihole_secondary
```

**Solutions:**
1. Restart DNS stack: `cd stacks/dns && docker compose restart`
2. Check network configuration: `bash scripts/validate-network.sh`
3. Verify Unbound is responding: `docker logs unbound_primary`

### VIP Not Responding

**Symptoms:** Virtual IP (192.168.8.255) not responding

**Diagnosis:**
```bash
# Check Keepalived status
docker logs keepalived

# Verify VIP assignment
ip addr show | grep 192.168.8.255
```

**Solutions:**
1. Check both nodes can communicate
2. Verify VRRP traffic is not blocked by firewall
3. Ensure only one node is MASTER
4. Restart Keepalived: `docker restart keepalived`

### High Memory Usage

**Symptoms:** System running slow, containers OOM killed

**Diagnosis:**
```bash
# Check system memory
free -h

# Check container memory usage
docker stats

# Check Pi-hole database size
du -h stacks/dns/pihole*/etc-pihole/
```

**Solutions:**
1. Increase Pi-hole query retention limit
2. Rotate/clean old logs
3. Restart containers to free memory
4. Consider upgrading RAM if consistently high

### For More Help

See comprehensive troubleshooting guide:
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- [DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md)
- GitHub Issues: https://github.com/orionsentinel/Orion-DNS_Stack/issues

---

## Quick Reference

### Essential Commands

```bash
# Backup configuration
bash scripts/backup-config.sh

# Upgrade stack
bash scripts/upgrade.sh

# Restore from backup
bash scripts/restore-config.sh backups/backup.tar.gz

# Health check
bash scripts/health-check.sh

# Restart DNS stack
cd stacks/dns && docker compose restart

# View logs
cd stacks/dns && docker compose logs -f

# Check container status
docker ps
```

### Important Files

- Configuration: `.env`
- DNS Stack: `stacks/dns/docker-compose.yml`
- Backups: `backups/`
- Logs: View with `docker compose logs`

### Important URLs

- Pi-hole Primary: http://192.168.8.251/admin
- Pi-hole Secondary: http://192.168.8.252/admin
- Grafana: http://192.168.8.250:3000
- Prometheus: http://192.168.8.250:9090

---

**Last Updated:** 2024-11-20
