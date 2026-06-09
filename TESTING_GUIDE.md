# Testing Guide for Orion Sentinel DNS HA Installation

This document provides a test plan for validating the Level 1 and Level 2 installation features.

## Pre-Testing Setup

### Environment Requirements

- Raspberry Pi 4 (4GB RAM recommended)
- Raspberry Pi OS (64-bit)
- Network connection (ethernet recommended)
- Static IP assigned or reserved in router DHCP

### Before Testing

1. **Fresh Clone:**
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   ```

2. **No existing .env:**
   ```bash
   # Ensure clean state
   rm -f .env stacks/dns/.env
   ```

---

## Test Plan 1: Level 1 - Interactive CLI Install (Single-Node)

### Objective
Validate that the interactive CLI installation works for single-node deployment.

### Steps

1. **Run install script:**
   ```bash
   bash scripts/install.sh
   ```

2. **Respond to prompts:**
   - Configuration method: `1` (Interactive)
   - Deployment mode: `1` (Single-Node)
   - Pi IP: Press ENTER (accept detected)
   - Interface: Press ENTER (accept detected)
   - Pi-hole password: Enter strong password
   - Confirm password: Re-enter same password

3. **Verify configuration was created:**
   ```bash
   cat .env | grep -E "HOST_IP|DNS_VIP|NODE_ROLE|PIHOLE_PASSWORD"
   ```

4. **Expected results:**
   - `.env` file created
   - `DNS_VIP` = `HOST_IP` (single-node)
   - `NODE_ROLE=MASTER`
   - `PIHOLE_PASSWORD` set to entered value
   - No errors during installation

5. **Verify services started:**
   ```bash
   docker ps
   # Should see: pihole_primary, pihole_secondary, unbound_primary, unbound_secondary, keepalived, dns-wizard
   ```

### Success Criteria

- [✓] Interactive prompts appeared
- [✓] Configuration saved correctly
- [✓] Docker containers started
- [✓] No errors in console output
- [✓] Web wizard accessible at `http://<pi-ip>:8080`

---

## Test Plan 2: Level 1 - Interactive CLI Install (HA Mode)

### Objective
Validate interactive CLI for HA deployment on first Pi (MASTER).

### Steps

1. **Run install script:**
   ```bash
   bash scripts/install.sh
   ```

2. **Respond to prompts:**
   - Configuration method: `1` (Interactive)
   - Deployment mode: `2` (HA)
   - Pi IP: `192.168.1.100` (example)
   - Interface: `eth0`
   - VIP: `192.168.1.200` (unused IP)
   - Node role: `MASTER`
   - Pi-hole password: Enter strong password

3. **Verify configuration:**
   ```bash
   cat .env | grep -E "HOST_IP|DNS_VIP|NODE_ROLE|VRRP_PRIORITY"
   ```

4. **Expected results:**
   - `HOST_IP=192.168.1.100`
   - `DNS_VIP=192.168.1.200`
   - `NODE_ROLE=MASTER`
   - `VRRP_PRIORITY=100`

5. **Verify VIP appears:**
   ```bash
   ip addr show eth0 | grep 192.168.1.200
   # Should show VIP on interface
   ```

### Success Criteria

- [✓] HA configuration prompts appeared
- [✓] VIP configured correctly
- [✓] MASTER role set with priority 100
- [✓] VIP appears on network interface
- [✓] Services running

---

## Test Plan 3: Level 2 - Web Wizard (Single-Node)

### Objective
Validate the web wizard provides a working setup for single-node deployment.

### Steps

1. **Start wizard (if not already running):**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml up -d dns-wizard
   ```

2. **Access wizard:**
   - Open browser: `http://<pi-ip>:8080`

3. **Step 1 - Welcome Page:**
   - Verify page loads with Orion branding
   - Click "Get Started"

4. **Step 2 - Network Configuration:**
   - Verify Pi IP is pre-filled
   - Verify interface is pre-filled
   - Select "Single-Node" mode
   - Enter Pi-hole password (min 8 chars)
   - Click "Next: Choose Profile"

5. **Step 3 - Profile Selection:**
   - Verify all 3 profiles shown (Standard, Family, Paranoid)
   - Select "Standard" (recommended)
   - Click "Complete Setup"

6. **Step 4 - Completion:**
   - Verify shows VIP = Pi IP
   - Verify shows next steps
   - Verify links to Pi-hole admin

7. **Verify configuration saved:**
   ```bash
   cat stacks/dns/.env | grep -E "DNS_VIP|DNS_PROFILE"
   ```

### Success Criteria

- [✓] All 4 wizard pages load correctly
- [✓] Form validation works (passwords, IPs)
- [✓] Configuration saved to `.env`
- [✓] `.setup_done` file created
- [✓] Revisiting wizard shows completion page
- [✓] UI is responsive and styled correctly

---

## Test Plan 4: Level 2 - Web Wizard (HA Mode)

### Objective
Validate web wizard for HA deployment.

### Steps

1. **Remove previous setup:**
   ```bash
   rm -f wizard/.setup_done .env stacks/dns/.env
   docker compose -f stacks/dns/docker-compose.yml restart dns-wizard
   ```

2. **Access wizard:** `http://<pi-ip>:8080`

3. **Complete wizard:**
   - Welcome: Click "Get Started"
   - Network Config:
     - Select "High Availability (HA)"
     - Pi IP: `192.168.1.100`
     - Interface: `eth0`
     - VIP: `192.168.1.200`
     - Node Role: `MASTER`
     - Pi-hole password: Enter password
   - Profile: Select "Family"
   - Completion: Review

4. **Verify HA configuration:**
   ```bash
   cat .env | grep -E "NODE_ROLE|DNS_VIP|VRRP"
   ```

### Success Criteria

- [✓] HA fields appear when HA mode selected
- [✓] VIP field validates for unused IP
- [✓] Node role dropdown works
- [✓] HA configuration saved correctly
- [✓] VRRP settings configured

---

## Test Plan 5: DNS Profile Application

### Objective
Validate DNS profile application works.

### Steps

1. **Apply standard profile:**
   ```bash
   python3 scripts/apply-profile.py --profile standard --dry-run
   ```

2. **Expected output:**
   - Shows profile information
   - Lists blocklists to be applied
   - No errors

3. **Apply for real:**
   ```bash
   python3 scripts/apply-profile.py --profile standard
   ```

4. **Verify in Pi-hole:**
   - Access `http://<vip>/admin`
   - Login with Pi-hole password
   - Go to Group Management → Adlists
   - Verify adlists added

### Success Criteria

- [✓] Profile YAML loads successfully
- [✓] Dry-run shows expected changes
- [✓] Profile applies without errors
- [✓] Adlists appear in Pi-hole

---

## Test Plan 6: Backup and Restore

### Objective
Validate backup and restore scripts work.

### Steps

1. **Create backup:**
   ```bash
   bash scripts/backup-config.sh
   ```

2. **Verify backup created:**
   ```bash
   ls -lh backups/
   # Should see dns-ha-backup-*.tar.gz
   ```

3. **Modify configuration:**
   ```bash
   # Change something in .env
   sed -i 's/PIHOLE_PASSWORD=.*/PIHOLE_PASSWORD="modified"/' .env
   ```

4. **Restore backup:**
   ```bash
   BACKUP_FILE=$(ls -t backups/dns-ha-backup-*.tar.gz | head -1)
   bash scripts/restore-config.sh "$BACKUP_FILE"
   ```

5. **Verify restoration:**
   ```bash
   cat .env | grep PIHOLE_PASSWORD
   # Should show original password, not "modified"
   ```

### Success Criteria

- [✓] Backup creates tar.gz file
- [✓] Backup includes .env, configs, Pi-hole data
- [✓] Restore prompts for confirmation
- [✓] Restore successfully reverts changes

---

## Test Plan 7: Upgrade

### Objective
Validate upgrade script works.

### Steps

1. **Run upgrade:**
   ```bash
   bash scripts/upgrade.sh
   ```

2. **Expected behavior:**
   - Creates backup first
   - Runs `git pull`
   - Updates Docker images
   - Restarts services

3. **Verify:**
   ```bash
   # Check new backup created
   ls -lh backups/
   
   # Check services restarted
   docker ps
   ```

### Success Criteria

- [✓] Backup created before upgrade
- [✓] Git pull succeeds
- [✓] Docker images updated
- [✓] Services restart successfully
- [✓] No data loss

---

## Test Plan 8: Two-Pi HA Failover

### Objective
Validate HA failover between two Pis.

### Prerequisites
- 2 Raspberry Pis on same network
- Both configured with same VIP
- Pi #1 as MASTER, Pi #2 as BACKUP

### Steps

1. **Verify MASTER has VIP:**
   ```bash
   # On Pi #1 (MASTER)
   ip addr show eth0 | grep <VIP>
   # Should show VIP
   ```

2. **Start continuous ping:**
   ```bash
   # From another device
   ping -t <VIP>
   ```

3. **Stop Keepalived on MASTER:**
   ```bash
   # On Pi #1
   docker stop keepalived
   ```

4. **Observe failover:**
   - Ping should continue (maybe 1-2 packets lost)
   - VIP should appear on Pi #2

5. **Verify BACKUP has VIP:**
   ```bash
   # On Pi #2 (BACKUP)
   ip addr show eth0 | grep <VIP>
   # Should now show VIP
   ```

6. **Restart MASTER:**
   ```bash
   # On Pi #1
   docker start keepalived
   ```

7. **Observe fail-back:**
   - VIP should return to Pi #1 (higher priority)

### Success Criteria

- [✓] VIP initially on MASTER
- [✓] Failover occurs within 5 seconds
- [✓] BACKUP takes over VIP
- [✓] DNS continues working during failover
- [✓] Fail-back occurs when MASTER returns

---

## Regression Tests

### Quick Deployment Validation (NEW)

Before deploying, run the comprehensive deployment dry-run test:

```bash
# Full deployment dry-run validation
bash scripts/test-deployment-dry-run.sh --verbose

# Run all test suites
bash scripts/test-installation.sh
bash scripts/test-suite.sh
bash scripts/pre-flight-check.sh --quick
```

These scripts validate:
- Docker Compose configuration syntax
- Build contexts and Dockerfiles
- Environment variable completeness
- Network configuration
- Volume mounts and file dependencies
- Script syntax and permissions

### Test existing functionality still works

1. **Verify existing stacks still deploy:**
   ```bash
   docker compose -f stacks/observability/docker-compose.yml up -d
   docker compose -f stacks/ai-watchdog/docker-compose.yml up -d
   ```

2. **Verify existing scripts work:**
   ```bash
   bash scripts/health-check.sh
   bash scripts/validate-env.sh
   ```

3. **Verify profiles still load:**
   ```bash
   ls -lh profiles/
   cat profiles/standard.yml | head -20
   ```

---

## Final Validation Checklist

After all tests pass:

- [ ] Documentation is accurate (no broken links)
- [ ] README.md reflects new features
- [ ] All scripts have proper shebangs and permissions
- [ ] Docker Compose files are valid YAML
- [ ] No secrets committed to git
- [ ] Code is commented where complex
- [ ] Error messages are helpful and actionable

---

## Known Limitations

1. **Wizard requires browser** - No headless/CLI-only mode for Level 2
2. **Single language** - UI is English only
3. **No profile customization** - Profiles are pre-defined, not customizable via wizard
4. **No validation for VIP conflicts** - User must ensure VIP is unused

---

## Reporting Issues

When reporting test failures, include:
- Test plan number and name
- Steps to reproduce
- Expected vs actual behavior
- Logs (sanitize passwords!)
- Environment details (Pi model, OS version, network config)

---

## Success Metrics

The implementation is successful if:
- **90%+ of tests pass** on first run
- **Zero critical bugs** (data loss, security issues)
- **Installation takes < 10 minutes** for average user
- **Documentation is clear** and followed by testers
- **Failover works** reliably in HA mode
