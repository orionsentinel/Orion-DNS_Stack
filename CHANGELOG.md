# Changelog

All notable changes to the RPi HA DNS Stack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Unified observability + Signal alerting 📈

- **One monitoring stack** (`stacks/monitoring/`): Prometheus + Alertmanager +
  Grafana + Loki + Blackbox + Signal paging, consolidated from the former
  overlapping `observability/` and `monitoring/` stacks (removed
  `stacks/observability/`).
- **Degraded-state alerts** for THIS stack: VIP not resolving (critical), all
  nodes down (critical), single node down, DNS latency, exporter-down, and host
  CPU/mem/disk — routed to **Signal** via the existing webhook bridge.
- **Provisioned Grafana** (Prometheus + Loki datasources, dashboards auto-loaded)
  and a canonical-IP Prometheus scrape config (nodes .244/.245, VIP .243).
- `stacks/nsm/` (Suricata IDS) stays separate; its logs can ship into this
  stack's Loki (follow-up).

### Changed - Repository consolidation 🧹

- **Single canonical deployment.** Removed the `deployments/` tree (7
  near-duplicate variants that still shipped the broken ARM32 `mvance/unbound-rpi`
  image). The profile-based root `compose.yml` is now the one supported path for
  the 2-node HA topology (`docs/architecture.md`).
- **One installer.** Added `bootstrap.sh` (`clone → ./bootstrap.sh → working
  node`) and removed ~20 overlapping install/deploy/test scripts it supersedes.
  See the README "Fastest path — one-command bootstrap".
- **Migration:** existing nodes keep running. To adopt the canonical path, see
  `docs/disaster-recovery.md` (rebuild) or just
  `docker compose --profile two-node-ha-primary up -d` from the repo root.

### Added - v2.5.0 HA Reliability Improvements (2024-12-19) 🔒

- **Strict Keepalived Validation** - Prevent split-brain scenarios
  - Enforces VRRP_PASSWORD to be exactly 8 characters (VRRP PASS auth limitation)
  - Validates PEER_IP and UNICAST_SRC_IP when unicast mode is enabled
  - IPv4 address format validation with octet range checking
  - Clear error messages on validation failures with examples
  - Automatic script permission fixing on every container start (root:root, 700)
- **Enhanced Environment Templates** (`env/primary.env`, `env/secondary.env`)
  - Pre-configured templates with correct IPs for standard two-node setup
  - Primary: MASTER, priority 200, IPs 192.168.8.250→251
  - Secondary: BACKUP, priority 150, IPs 192.168.8.251→250
  - VIP_NETMASK default changed from /24 to /32 for cleaner host-only assignment
- **HA Verification Script** (`scripts/verify-ha.sh`)
  - Check which node currently holds the VIP
  - Display keepalived state (MASTER/BACKUP) from logs
  - Verify unicast peer configuration (PEER_IP, UNICAST_SRC_IP)
  - Test DNS resolution via VIP and node IPs
  - Color-coded output for easy status interpretation
- **Optional Pi-hole Configuration Sync** - Gravity Sync style replication
  - `scripts/pihole-sync.sh` - SSH-based primary→secondary sync
  - Syncs adlists, whitelist, blacklist, regex filters, custom DNS records
  - Optional gravity database sync
  - Dry-run mode for preview
  - systemd timer for automated sync every 6 hours
- **Comprehensive Troubleshooting Documentation**
  - How to diagnose secondary becoming MASTER when primary is healthy
  - VRRP packet verification with tcpdump
  - Unicast peer configuration verification commands
  - NIC flapping troubleshooting guidance
  - Script permission fix procedures

### Changed

- **Keepalived Container** - Added NET_RAW capability for VRRP protocol 112
- **Default VIP Netmask** - Changed from /24 to /32 for host-only VIP assignment
- **Documentation** - VRRP_PASSWORD requirements now prominently documented in README and MULTI_NODE_QUICKSTART

### Fixed

- **Split-brain prevention** - Secondary no longer becomes MASTER when primary is healthy
  - Root cause: Empty PEER_IP or wrong unicast configuration
  - Fix: Strict validation prevents container start with invalid config
- **Script permission warnings** - "Unsafe permissions ... disabling" errors
  - Root cause: /etc/keepalived is a bind mount, permissions not preserved
  - Fix: Scripts copied and secured on every container start
- **Configuration clarity** - unicast_peer block now always included when USE_UNICAST_VRRP=true

### Security

- Added note about SSH root user in pihole-sync.sh (consider dedicated service account)
- Improved trap handling in sync scripts for proper cleanup

### Impact on Users

- **Deterministic HA Behavior**: Secondary stays BACKUP when primary is healthy
- **Easier Troubleshooting**: verify-ha.sh provides instant status overview
- **Safer Configuration**: Invalid settings caught at container start, not runtime
- **Optional Config Sync**: Pi-hole settings can be kept in sync automatically

### Migration Steps

Existing deployments continue to work, but to benefit from improvements:

1. **Update VRRP_PASSWORD to exactly 8 characters** (if not already):
   ```bash
   # In your .env file
   VRRP_PASSWORD=oriondns  # Exactly 8 chars
   ```

2. **Verify and set unicast peer IPs** (if using unicast mode):
   ```bash
   # Primary .env
   UNICAST_SRC_IP=192.168.8.250
   PEER_IP=192.168.8.251
   
   # Secondary .env
   UNICAST_SRC_IP=192.168.8.251
   PEER_IP=192.168.8.250
   ```

3. **Recreate keepalived containers**:
   ```bash
   cd /opt/orion-dns-ha/Orion-DNS_Stack
   docker compose --profile two-node-ha-primary up -d --build --force-recreate keepalived
   ```

4. **Verify HA is working correctly**:
   ```bash
   ./scripts/verify-ha.sh
   ```

Alternatively, use the new simplified templates:
```bash
# Primary node
cp env/primary.env .env
# Edit WEBPASSWORD and other settings

# Secondary node  
cp env/secondary.env .env
# Edit WEBPASSWORD and other settings
```

### Added - v2.4.0 Smart Upgrade System (2024-11-19) 🚀
- **Smart Upgrade System** (`scripts/smart-upgrade.sh`) - Intelligent upgrade management
  - Interactive menu interface for upgrade operations
  - Pre-upgrade health checks (disk space, Docker status, network connectivity)
  - Automatic backup creation before any upgrade
  - Selective stack upgrades (upgrade all or individual stacks)
  - Post-upgrade verification (container health, DNS resolution tests)
  - Comprehensive logging to `upgrade.log`
  - Rollback capability via backup restore
  - 8 command-line options for flexibility
- **Automated Update Checker** (`scripts/check-updates.sh`) - Docker image monitoring
  - Scans 24+ Docker images for available updates
  - Compares current vs. latest image digests
  - Generates detailed `update-report.md` with status indicators
  - Integrates with Docker Hub API for version information
  - Provides specific upgrade recommendations
  - Can be scheduled via cron for daily checks
- **Security-Enhanced Upgrade** (`scripts/secure-upgrade.sh`) - Security-first upgrades
  - Pre-upgrade vulnerability scanning with Trivy
  - Docker Content Trust verification support
  - CVE checks for running containers
  - Security report generation
  - Post-upgrade security validation
- **Comprehensive Documentation**
  - `SMART_UPGRADE_GUIDE.md` - Complete 500+ line usage guide with examples
  - Enhanced `VERSIONS.md` with v2.4.0 release notes
  - Updated `README.md` with smart upgrade section
  - Updated `scripts/README.md` with new script documentation
- **Version Tracking System**
  - Template for `.versions.yml` for version management
  - Tracks all service images and their versions
  - Auto-update flags per service
  - Stack version tracking and upgrade notes

### Changed
- **Upgrade Process** - Enhanced from manual to automated with safety checks
  - Before: Manual `git pull && docker compose pull && up -d`
  - After: Automated `smart-upgrade.sh -u` with comprehensive validation
- **Update Notifications** - Now automated with daily check capability
  - Before: No notification of available updates
  - After: Optional automated daily update reports

### Security
- Added pre-upgrade security vulnerability scanning
- Added image signature verification support (Docker Content Trust)
- Added CVE checking for running containers
- Added security report generation for upgrade auditing

### Impact on Users
- **Safer Upgrades**: Pre/post validation reduces risk of failed upgrades
- **Easier Maintenance**: One command for checking and applying updates
- **Better Visibility**: Know exactly what versions are running and what's available
- **Quick Recovery**: One-click rollback via integrated backup system
- **Peace of Mind**: Comprehensive health checks before and after upgrades

### Migration Steps
No migration required - this is a backward-compatible feature addition.

To start using the new system:
```bash
# Make scripts executable
chmod +x scripts/smart-upgrade.sh scripts/check-updates.sh scripts/secure-upgrade.sh

# Try interactive mode
bash scripts/smart-upgrade.sh -i

# Or check for updates
bash scripts/smart-upgrade.sh -c
```

Existing upgrade methods (`scripts/update.sh`) continue to work as before.

---

## [Previous Unreleased]

### Added
- Operational excellence scripts (`health-check.sh`, `weekly-maintenance.sh`)
- Operational runbook for common issues and procedures
- Disaster recovery plan with detailed recovery procedures
- Automated health checks and maintenance procedures

### Removed
- Intrusion detection stack (determined to be overhead for home use case)
- Complexity in favor of operational maturity

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release with HA DNS stack
- Dual Pi-hole setup with Unbound
- Keepalived for high availability
- Prometheus + Grafana monitoring
- SSO with Authelia
- Multi-node deployment options

---

## How to Use This Changelog

### For Maintainers

When making changes:
1. Add entry under `[Unreleased]` section
2. Use appropriate category:
   - `Added` for new features
   - `Changed` for changes in existing functionality
   - `Deprecated` for soon-to-be removed features
   - `Removed` for now removed features
   - `Fixed` for any bug fixes
   - `Security` for security updates

3. Include:
   - What changed
   - Why it changed
   - Impact on users
   - Migration steps (if needed)

Example entry:
```markdown
### Changed
- Updated Pi-hole to version 6.0
  - **Why**: Security patches and new features
  - **Impact**: Requires manual update of custom blocklists
  - **Migration**: Run `docker exec pihole_primary pihole -up`
```

### For Users

- Check `[Unreleased]` for upcoming changes
- Review version sections for changes in your deployment
- Follow migration guides for breaking changes

---

## Change Template

```markdown
## [Version] - YYYY-MM-DD

### Added
- Feature 1 - Description and reason
- Feature 2 - Description and reason

### Changed
- Component X - What changed and why
  - **Impact**: Description
  - **Migration**: Steps if needed

### Fixed
- Bug fix description
- Root cause and resolution

### Removed
- Feature/service removed
  - **Reason**: Why it was removed
  - **Alternative**: What to use instead
```

---

**Maintenance**: Update this file with every significant change. Review quarterly for accuracy.
