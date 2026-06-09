# Disaster Recovery Plan

## Overview
This document outlines the disaster recovery procedures for the RPi HA DNS Stack to ensure business continuity and minimal downtime.

## Recovery Objectives
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 24 hours
- **Maximum Tolerable Downtime**: 8 hours

## Backup Strategy

### What's Backed Up
1. **Configuration Files**
   - All `.env` files
   - All `docker-compose.yml` files
   - Pi-hole custom lists
   - Grafana dashboards (provisioned)
   - Keepalived configuration

2. **Backup Schedule**
   - **Weekly**: Automated via `weekly-maintenance.sh`
   - **Before Changes**: Manual backup before any configuration change
   - **Monthly**: Full system image (optional)

3. **Backup Locations**
   - **Primary**: `/opt/rpi-dns-backups/` (local)
   - **Secondary**: External USB drive (recommended)
   - **Tertiary**: Off-site backup (highly recommended)

### Backup Commands
```bash
# Manual configuration backup
mkdir -p /opt/rpi-dns-backups/manual/$(date +%Y%m%d)
cp -r /opt/rpi-ha-dns-stack/stacks/*/.env /opt/rpi-dns-backups/manual/$(date +%Y%m%d)/
cp -r /opt/rpi-ha-dns-stack/stacks/*/docker-compose.yml /opt/rpi-dns-backups/manual/$(date +%Y%m%d)/

# Pi-hole configuration backup
docker exec pihole_primary pihole -a -t

# Full system backup (SD card image)
# From another machine:
# ssh pi@192.168.8.250 "sudo dd if=/dev/mmcblk0 bs=4M" | gzip > rpi-backup-$(date +%Y%m%d).img.gz
```

## Disaster Scenarios & Recovery

### Scenario 1: Single Container Failure

**Detection**: Container health check fails, monitoring alerts

**Impact**: Partial service degradation, HA maintains service

**Recovery Steps**:
1. Identify failed container: `docker ps -a | grep -v Up`
2. Check logs: `docker logs <container_name> --tail 100`
3. Restart container: `docker restart <container_name>`
4. If restart fails, recreate: `docker compose up -d --force-recreate <container_name>`
5. Verify service restored: Run health check script
6. Document in change log

**Expected Recovery Time**: 5-15 minutes

---

### Scenario 2: Node Failure (Hardware/OS)

**Detection**: Node unreachable, HA failover triggered

**Impact**: Service continues on secondary node via VIP

**Recovery Steps**:

**Phase 1: Immediate (0-15 minutes)**
1. Verify secondary node took over VIP
2. Check DNS resolution: `dig @192.168.8.255 google.com`
3. Monitor secondary node load
4. Alert team of node failure

**Phase 2: Temporary (1-4 hours)**
1. If primary recoverable, attempt restart
2. If not recoverable, prepare replacement hardware
3. Document failure and maintain monitoring

**Phase 3: Restoration (4-24 hours)**
1. Set up replacement Raspberry Pi
2. Install Raspberry Pi OS (64-bit)
3. Clone repository
4. Restore configuration from backup
5. Run setup wizard
6. Verify synchronization with secondary
7. Test failover in both directions
8. Document recovery in change log

**Expected Recovery Time**: 4-6 hours

---

### Scenario 3: Complete Stack Failure (Both Nodes)

**Detection**: DNS resolution fails, all nodes unreachable

**Impact**: Total DNS service outage

**Recovery Steps**:

**Phase 1: Emergency Response (0-30 minutes)**
1. Verify power supply to both nodes
2. Check network connectivity
3. Attempt to access via console/keyboard
4. If unrecoverable, begin full restoration

**Phase 2: Restoration Preparation (30-60 minutes)**
1. Obtain replacement hardware (if needed)
2. Locate latest backups
3. Download Raspberry Pi OS image
4. Prepare SD cards

**Phase 3: Primary Node Recovery (1-3 hours)**
1. Flash Raspberry Pi OS to SD card
2. Boot and configure basic network
3. Clone repository:
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd rpi-ha-dns-stack
   ```
4. Restore `.env` files from backup:
   ```bash
   cp /backup/location/.env stacks/dns/
   cp /backup/location/.env stacks/observability/
   # etc.
   ```
5. Run setup:
   ```bash
   bash scripts/setup.sh
   ```
6. Verify services: `bash scripts/health-check.sh`
7. Test DNS: `dig @192.168.8.251 google.com`

**Phase 4: Secondary Node Recovery (3-4 hours)**
1. Repeat steps for secondary node
2. Ensure different node role in configuration
3. Verify Keepalived VRRP communication
4. Test HA failover

**Phase 5: Validation (4-6 hours)**
1. Run full health check
2. Verify all services operational
3. Test failover scenarios
4. Monitor for 24 hours
5. Document incident and lessons learned

**Expected Recovery Time**: 6-8 hours

---

### Scenario 4: Configuration Corruption

**Detection**: Services behaving unexpectedly, misconfigurations

**Impact**: Service degradation or failure

**Recovery Steps**:
1. Identify corrupted configuration
2. Stop affected services
3. Restore from backup:
   ```bash
   LATEST_BACKUP=$(ls -t /opt/rpi-dns-backups/env-backups/ | head -1)
   cp /opt/rpi-dns-backups/env-backups/$LATEST_BACKUP/path/to/.env ./
   ```
4. Restart services: `docker compose up -d`
5. Verify functionality
6. Document what caused corruption

**Expected Recovery Time**: 30 minutes - 1 hour

---

### Scenario 5: Data Center/Site Failure

**Detection**: Complete site offline

**Impact**: Total service outage

**Recovery Steps** (assuming off-site backup):
1. Obtain hardware at alternate location
2. Download backups from off-site storage
3. Follow complete stack failure procedure
4. Reconfigure network for new location
5. Update DNS forwarders if applicable
6. Test and validate

**Expected Recovery Time**: 8-24 hours

---

## Testing & Validation

### Monthly DR Tests
- Test container restart procedures
- Verify backup restoration (sample files)
- Validate monitoring and alerting

### Quarterly DR Tests
- Simulate node failure
- Practice complete restoration from backup
- Test off-site backup retrieval
- Update DR procedures based on findings

### Annual DR Tests
- Full disaster recovery drill
- Complete stack rebuild
- Document and time all procedures
- Update RTO/RPO based on results

---

## Backup Verification

### Weekly Verification
```bash
# Verify backups exist
ls -lh /opt/rpi-dns-backups/env-backups/ | tail -5

# Check backup size (should be consistent)
du -sh /opt/rpi-dns-backups/

# Verify backup integrity (sample)
LATEST=$(ls -t /opt/rpi-dns-backups/env-backups/ | head -1)
cat /opt/rpi-dns-backups/env-backups/$LATEST/stacks/dns/.env
```

### Monthly Verification
```bash
# Test restore to temporary location
mkdir -p /tmp/dr-test
LATEST=$(ls -t /opt/rpi-dns-backups/env-backups/ | head -1)
cp -r /opt/rpi-dns-backups/env-backups/$LATEST/* /tmp/dr-test/
# Verify files are readable and valid
docker compose -f /tmp/dr-test/stacks/dns/docker-compose.yml config
```

---

## Post-Recovery Checklist

After any recovery:
- [ ] All services running and healthy
- [ ] DNS resolution working
- [ ] HA failover tested
- [ ] Monitoring and alerts functional
- [ ] Backups running correctly
- [ ] Incident documented in change log
- [ ] Lessons learned documented
- [ ] Team debriefing conducted
- [ ] DR plan updated if needed

---

## Contact Information

### Emergency Contacts
- **Primary Admin**: [Name, Phone, Email]
- **Secondary Admin**: [Name, Phone, Email]
- **Network Team**: [Contact info]
- **Hardware Vendor**: [Support contact]

### Escalation Path
1. Primary Admin (0-30 min)
2. Secondary Admin (30-60 min)
3. Network Team (1-2 hours)
4. Management (2+ hours)

---

## Related Documents
- [OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md) - Day-to-day operations
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) - Setup procedures

---

**Last Updated**: 2024-11-19  
**Version**: 1.0  
**Owner**: Stack Administrator  
**Review Frequency**: Quarterly
