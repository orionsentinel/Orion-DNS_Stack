# Migration Guide - Legacy to Production-Ready Structure

This guide helps you migrate from the old `deployments/` structure to the new production-ready root-level setup.

## Overview

**What's changing:**
- Single `compose.yml` at root instead of multiple in `deployments/`
- Simplified `.env` configuration
- Profile-based deployment instead of separate compose files
- Centralized `config/` directory for all configuration
- `Makefile` for easy operations

**What's NOT changing:**
- Your data (Pi-hole databases, Unbound cache)
- Your blocklists and custom DNS settings
- Network configuration and IPs

## Pre-Migration Checklist

Before migrating, complete these steps:

### 1. Backup Your Current Setup

```bash
# Backup all configuration and data
cd /opt/rpi-ha-dns-stack  # or wherever your current install is
bash scripts/backup-config.sh

# The backup will be in backups/ directory
ls -lh backups/dns-ha-backup-*.tar.gz
```

### 2. Document Your Current Configuration

Make note of:
- VIP address
- Node IPs (Pi1 and Pi2)
- Pi-hole password
- VRRP password
- Network interface name
- Any custom Unbound settings
- Blocklist configuration

### 3. Test Current Setup

Ensure everything is working:
```bash
docker ps                        # All containers running
dig @<VIP_ADDRESS> google.com   # DNS resolving
# Test failover by stopping one node
```

## Migration Methods

### Method 1: Clean Install (Recommended)

This method gives you the cleanest setup with minimal risk.

#### On Each Pi:

1. **Stop current services:**
   ```bash
   cd /path/to/old/deployment
   docker compose down
   ```

2. **Backup data volumes:**
   ```bash
   # Pi-hole data
   docker run --rm -v pihole_config:/source -v $(pwd)/backup:/dest alpine \
     tar czf /dest/pihole_data.tar.gz -C /source .
   
   # Unbound data
   docker run --rm -v unbound_data:/source -v $(pwd)/backup:/dest alpine \
     tar czf /dest/unbound_data.tar.gz -C /source .
   ```

3. **Clone/update repository:**
   ```bash
   cd /opt
   # If you have an existing clone
   cd orion-dns-ha
   git fetch origin
   git checkout main
   git pull
   
   # Or fresh clone
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git orion-dns-ha
   cd orion-dns-ha
   ```

4. **Configure environment:**
   ```bash
   # Copy production template
   cp .env.production.example .env
   
   # For Pi1
   nano .env
   # Set from env/pi1.env.example:
   #   HOST_IP=192.168.8.250
   #   NODE_ROLE=MASTER
   #   KEEPALIVED_PRIORITY=200
   #   PEER_IP=192.168.8.251
   
   # For Pi2
   nano .env
   # Set from env/pi2.env.example:
   #   HOST_IP=192.168.8.251
   #   NODE_ROLE=BACKUP
   #   KEEPALIVED_PRIORITY=150
   #   PEER_IP=192.168.8.250
   
   # On BOTH Pis, set the same:
   #   VIP_ADDRESS=<your VIP>
   #   PIHOLE_PASSWORD=<your password>
   #   VRRP_PASSWORD=<your password>
   #   NETWORK_INTERFACE=<your interface>
   ```

5. **Restore data:**
   ```bash
   # Create volumes first
   docker volume create pihole_config
   docker volume create unbound_data
   
   # Restore Pi-hole data
   docker run --rm -v pihole_config:/dest -v $(pwd)/backup:/source alpine \
     tar xzf /source/pihole_data.tar.gz -C /dest
   
   # Restore Unbound data
   docker run --rm -v unbound_data:/dest -v $(pwd)/backup:/source alpine \
     tar xzf /source/unbound_data.tar.gz -C /dest
   ```

6. **Deploy new stack:**
   ```bash
   make validate-env
   make up-core
   ```

7. **Verify:**
   ```bash
   make health-check
   docker ps
   dig @<VIP_ADDRESS> google.com
   ```

### Method 2: In-Place Migration

This updates your existing installation without reinstalling.

#### On Each Pi:

1. **Backup current setup:**
   ```bash
   bash scripts/backup-config.sh
   ```

2. **Update repository:**
   ```bash
   git fetch origin
   git checkout main
   git pull
   ```

3. **Migrate environment configuration:**
   ```bash
   # Save old .env
   cp .env .env.old
   
   # Start with new template
   cp .env.production.example .env
   
   # Copy values from .env.old to .env
   # You can do this manually or with this helper:
   bash scripts/migrate-env.sh .env.old .env  # (if script exists)
   ```

4. **Update docker-compose reference:**
   ```bash
   # The new main file is compose.yml at root
   # Old: docker compose -f deployments/Production_2Pi_HA/node1/docker-compose.yml
   # New: docker compose --profile dns-core (from repo root)
   ```

5. **Stop old stack:**
   ```bash
   cd deployments/Production_2Pi_HA/node1  # or node2
   docker compose down
   ```

6. **Start new stack:**
   ```bash
   cd /opt/orion-dns-ha  # repo root
   make up-core
   ```

7. **Verify:**
   ```bash
   make health-check
   ```

## Environment Variable Mapping

### Old → New Variable Names

Most variables remain the same, but here are key mappings:

| Old Variable | New Variable | Notes |
|--------------|--------------|-------|
| `PRIMARY_DNS_IP` | `HOST_IP` (on Pi1) | More generic name |
| `SECONDARY_DNS_IP` | `HOST_IP` (on Pi2) | More generic name |
| `PIHOLE_DNS_PRIMARY` | `PIHOLE_DNS1` | Simplified |
| `PIHOLE_DNS_SECONDARY` | `PIHOLE_DNS2` | Simplified |
| `KEEPALIVED_PRIORITY_PI1` | `KEEPALIVED_PRIORITY` (200 on Pi1) | Per-node config |
| `KEEPALIVED_PRIORITY_PI2` | `KEEPALIVED_PRIORITY` (150 on Pi2) | Per-node config |

### Deprecated Variables

These are no longer needed:
- `PIHOLE_PRIMARY_IP` - Use `HOST_IP` instead
- `PIHOLE_SECONDARY_IP` - Use `HOST_IP` instead
- `UNBOUND_PRIMARY_IP` - Containers use service names now
- `UNBOUND_SECONDARY_IP` - Containers use service names now

## File Path Changes

### Configuration Files

| Old Location | New Location |
|--------------|--------------|
| `deployments/Production_2Pi_HA/node1/keepalived/` | `config/keepalived/` |
| `deployments/Production_2Pi_HA/node1/unbound/` | `config/unbound/` |
| `stacks/dns/unbound/` | `config/unbound/` |

### Scripts

| Old Location | New Location |
|--------------|--------------|
| `deployments/Production_2Pi_HA/node1/keepalived/check_dns.sh` | `scripts/check-dns.sh` |
| `deployments/Production_2Pi_HA/node1/keepalived/notify_*.sh` | `scripts/notify-*.sh` |

### Docker Compose

| Old | New |
|-----|-----|
| `deployments/Production_2Pi_HA/node1/docker-compose.yml` | `compose.yml` (root) with `--profile dns-core` |
| `deployments/HighAvail_2Pi1P1U/node1/docker-compose.yml` | `compose.yml` (root) with `--profile dns-core` |

## Volume Migration

If you have data in old volumes with different names:

```bash
# List existing volumes
docker volume ls

# Migrate to new volume names if needed
docker run --rm -v old_pihole_config:/source -v pihole_config:/dest alpine \
  sh -c "cd /source && cp -a . /dest"
```

## Network Configuration Changes

### Old (macvlan network)

```yaml
networks:
  dns_net:
    driver: macvlan
    driver_opts:
      parent: eth0
```

### New (bridge network)

```yaml
networks:
  dns_net:
    driver: bridge
```

**Migration note:** The new setup uses bridge networking with host ports. This is simpler and works on more systems. Your external IPs and VIP configuration remain the same.

## Post-Migration Validation

After migration, verify everything works:

### 1. Container Health

```bash
docker ps
# All containers should be "Up" and "healthy"
```

### 2. DNS Resolution

```bash
# From the Pi
dig @127.0.0.1 google.com
dig @<VIP_ADDRESS> google.com

# From another device on your network
dig @<VIP_ADDRESS> google.com
```

### 3. Pi-hole Web Interface

```bash
# Access Pi-hole admin
http://<HOST_IP>/admin

# Login with PIHOLE_PASSWORD
# Check that all your settings are preserved:
# - Blocklists
# - Whitelist/blacklist
# - Query log
# - Statistics
```

### 4. HA Failover

```bash
# On MASTER node
make down

# VIP should move to BACKUP within seconds
# On BACKUP node:
ip addr show | grep <VIP_ADDRESS>

# Verify DNS still works
dig @<VIP_ADDRESS> google.com

# Bring MASTER back up
make up-core

# VIP should return to MASTER
```

### 5. Monitoring (if enabled)

```bash
# Check exporters
curl http://<HOST_IP>:9100/metrics  # Node exporter
curl http://<HOST_IP>:9617/metrics  # Pi-hole exporter
curl http://<HOST_IP>:9167/metrics  # Unbound exporter
```

## Rollback Plan

If migration fails, you can rollback:

1. **Stop new stack:**
   ```bash
   cd /opt/orion-dns-ha
   make down
   ```

2. **Restore backup:**
   ```bash
   bash scripts/restore-config.sh backups/dns-ha-backup-*.tar.gz
   ```

3. **Start old deployment:**
   ```bash
   cd deployments/Production_2Pi_HA/node1  # or your old location
   docker compose up -d
   ```

## Common Issues

### Issue: Services won't start

**Solution:**
```bash
# Check logs
make logs

# Validate environment
make validate-env

# Check for port conflicts
netstat -tulpn | grep -E ':(53|80|5335)'
```

### Issue: VIP not assigned

**Solution:**
```bash
# Check keepalived logs
docker logs keepalived

# Verify VRRP password matches on both nodes
grep VRRP_PASSWORD .env

# Check network interface name
ip addr show
```

### Issue: Pi-hole data missing

**Solution:**
```bash
# Check if volumes exist
docker volume ls | grep pihole

# Restore from backup
bash scripts/restore-config.sh backups/dns-ha-backup-*.tar.gz
```

## Getting Help

- **Documentation:** See main README.production.md
- **Troubleshooting:** See TROUBLESHOOTING.md
- **Issues:** https://github.com/orionsentinel/Orion-DNS_Stack/issues
- **Backup:** You saved a backup, right? 😅

## Migration Checklist

- [ ] Backup current configuration and data
- [ ] Document current settings
- [ ] Test current setup works
- [ ] Update repository
- [ ] Create new .env from template
- [ ] Transfer settings to new .env
- [ ] Stop old stack
- [ ] Migrate data volumes if needed
- [ ] Deploy new stack
- [ ] Verify DNS resolution
- [ ] Test failover
- [ ] Check Pi-hole web interface
- [ ] Verify monitoring (if enabled)
- [ ] Update documentation/notes
- [ ] Delete old deployment files (optional)

---

**Migration Complete!** 🎉

Your HA DNS stack is now running on the new production-ready structure. Enjoy the simplified configuration and easy maintenance!
