# Changelog

All notable changes to the RPi HA DNS Stack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - GitOps convergence + off-box backups 🔁🔐

- **`ops/converge.sh`** (`make converge`) + `orion-dns-ha-converge.{service,timer}`:
  a node fetches `CONVERGE_REF`, fast-forwards, re-applies the stack, and **rolls
  back automatically if DNS breaks**. Run on the timer, the fleet self-heals to the
  repo's declared state (pin `CONVERGE_REF` to a release tag for production).
- **Encrypted off-box backups:** `ops/orion-dns-backup.sh` now also pushes the
  snapshot via **restic** when `RESTIC_REPOSITORY` is set (SFTP/S3/B2/rclone),
  encrypted + deduplicated + retention. Opt-in; local-only by default.
- New `.env` keys (`CONVERGE_REF`, `RESTIC_*`) and `docs/gitops-backups.md`.

### Added - Prove-it-works CI + legible README 🧪📖

- **CI integration test** (`integration-test` job): boots the single-node stack on
  the runner and asserts **DNS recursion (Unbound→root), DNSSEC enforcement,
  ad-blocking, and container health** — CI now proves the stack works, not just that
  the YAML is valid.
- **README slimmed 744 → ~90 lines** — pitch, diagram, quick start, the ad-fix
  pointer, and links to `docs/`. The detailed manual steps live in
  `docs/two-pi-quickstart.md`.
- **`docs/provisioning-plan.md`** — a solid plan for one-flash provisioning
  (cloud-init first-boot → pre-baked image), with starter templates.

### Removed - Second-layer cleanup 🧽

Removed the dead config and tool duplication that outlived the big simplification
(found in the follow-up review; `docs/REVIEW.md` refreshed to current state).

- **Dead monitoring config:** stripped Prometheus pushgateway env (`PROM_*`) from
  `compose.yml` + env templates, and `LOKI_URL` from all templates.
- **Backups:** removed `stacks/backup/` and `backup/` (duplicates of `ops/orion-dns-backup.sh`).
- **Sync:** removed the duplicate `ops/pihole-sync.sh` and the broken
  `systemd/pihole-sync.*` units (wrong path); consolidated on `scripts/pihole-sync.sh`.
- **Orphans:** removed `config/unbound/` (nothing builds it) + its Dependabot entry;
  removed `scripts/apply-profile.py` + `profiles/{family,standard,paranoid}.yml` +
  `profiles/keepalived/` (use `scripts/setup-blocklists.sh`).
- **Stale docs:** rewrote the kitchen-sink root `.env.example` to a clean single-node
  template; retired `docs/hardening.md` (old IP scheme/removed stacks; SECURITY.md
  covers it); cleared exporter/promtail residue from networking/troubleshooting.

Repo: 97 → 74 files. Core unchanged: 3 containers, 2-Pi VRRP HA.

### Added - Fix the ad problem (privacy hardening) 🛡️

- `scripts/block-private-relay.sh` (`make block-private-relay`): blocks iCloud
  Private Relay ingress domains so iPhones stop routing DNS around Pi-hole — the
  #1 fix for "ads still showing on iPhone". Idempotent, backs up gravity.db, `--remove`.
- `scripts/setup-blocklists.sh`: default (balanced) is now **Hagezi Multi PRO + TIF**
  (hosts-format, Pi-hole-correct); fixed the container default (`pihole_unbound`).
- `docs/privacy-setup.md`: the final recommendation + fix order, copy-paste ready.
  Private Relay block added to `client-network-setup.md`.
- Docs now assume **NVMe SSD (HAT)** boot, not SD cards.

### Removed - Radical simplification (minimum viable privacy stack) 🪓

Trimmed the repo to exactly what serves the core goal — block ads/trackers/telemetry
with the least complexity. **159 files removed.**

- **Removed non-core stacks:** `stacks/{nsm,vpn,sso,remote-access,management,dashboard,dns,monitoring}`,
  `wizard/`, `grafana_dashboards/`, `promtail/`, `health/`, `config/suricata/`.
  None contributed to DNS ad/tracker blocking; several were added attack surface.
- **`compose.yml` → 3 services:** `pihole_unbound` + `keepalived` + `autoheal`.
  Dropped the `exporters` and `netsec` (Suricata/cAdvisor/EveBox) profiles — no
  Prometheus/Grafana/Loki by design. Pi-hole's admin page is the dashboard.
- **`scripts/` 49 → 14:** kept bootstrap/verify-ha/selfcheck/validate-env/doctor/
  configure-nic/pihole-sync/test-failover/backup-lists/whitelist/iot/health; removed
  ~35 orphaned/duplicate scripts. Rewrote `selfcheck.sh` to a minimal validator.
- **Env templates 11 → 3** (`.env.example` + `env/{primary,secondary}.env.example`).
- Pruned Makefile exporter targets, the `wizard` Dependabot entry, and the
  monitoring/exporter sections from the README and docs.

Architecture unchanged where it matters: 2-Pi Pi-hole+Unbound (recursive, ARM64)
with keepalived VRRP. See `docs/architecture.md`.

### Changed - Pi-hole + Unbound update ⬆️

- Bump the canonical DNS image `ghcr.io/mpgirro/docker-pihole-unbound`
  **2025.03.0 → 2026.05.0** (Pi-hole v6, latest; Unbound bundled). Same major
  version — no breaking config change. CI gates it (ARM64 manifest + compose).
- **Roll out BACKUP-node-first** with a backup; see `docs/upgrade-guide.md`.

### Added - IoT containment 📷

- `profiles/iot.yml` + `scripts/setup-iot-containment.sh` + `docs/iot-containment.md`:
  put cameras/IoT devices in a dedicated Pi-hole group, **see** their phone-home
  traffic (Grafana/Loki + query log), and block telemetry with a conservative,
  opt-in, dry-run-by-default, reversible regex set. Tailored to the known Tapo /
  unknown devices on the LAN.

### Added - Setup & network docs 📘

- `docs/two-pi-quickstart.md` — full two-Pi setup on one page, with a
  prerequisites checklist (hardware/OS/network/accounts).
- `docs/client-network-setup.md` — pointing the LAN at the VIP, plus the device /
  **IPv6** / DoH bypass fixes. Indexed in `docs/README.md`.

### Changed - Cleanup & hardening pass 🧹

- Removed `config/keepalived/` (duplicate of the canonical `/keepalived`) and
  `stacks/setup-ui/` (web installer superseded by `bootstrap.sh`); dropped its
  Dependabot entry.
- **Memory limits** on the core services (`pihole_unbound` 1g, `keepalived` /
  `autoheal` 64m) so a leak can't take down the Pi.
- **Keepalived anti-flap:** default health check now probes the local resolver
  (`pi.hole`) instead of an external name, so an ISP/internet blip can't demote
  MASTER and drop the VIP. Override `CHECK_DNS_FQDN` for full-chain checks.
- Deferred (own follow-up): removing `stacks/dns/` + the second `scripts/` dedup
  (entangled — needs a careful pass).

### Added - Dependabot auto-merge 🤖

- `.github/workflows/dependabot-automerge.yml`: enables GitHub native auto-merge on
  Dependabot PRs so they merge themselves once CI passes. Requires the repo
  "Allow auto-merge" setting + branch protection with required checks (one-time).

### Added - License + failover test 🧪

- **MIT `LICENSE`** added; README license section updated.
- **`scripts/test-failover.sh`** (`make test-failover`): integration test that
  forces a VRRP failover (stops DNS on the MASTER), asserts the VIP floats to the
  peer and keeps resolving, then verifies the node recovers. Restores containers
  on exit/interrupt.
- Fixed a stale default VIP (`.249` → `.243`) in `scripts/verify-ha.sh`.

### Added - Layered self-healing 🩹

- **Docker healthchecks** on `pihole_unbound` (DNS liveness) and `keepalived`
  (process liveness).
- **`autoheal` sidecar** (`willfarrell/autoheal`, profiled with the core stack)
  restarts `autoheal`-labelled containers that go unhealthy. keepalived is
  intentionally unlabelled (it self-heals by releasing the VIP).
- Documented the four-layer recovery model in `docs/architecture.md`
  (restart → autoheal → keepalived failover → systemd).

### Removed - Stub "AI" stacks 🧹

- Removed `stacks/{ai-watchdog,self-healing,traffic-analytics,agents}` — stub-grade,
  not wired into the canonical stack; the self-healing intent is now met properly by
  the layers above, and the NSM/AI mandate lives in `Orion-sentinel-netsec-ai`.
- Dropped the corresponding Dependabot entry.

### Security - Supply-chain hardening 🔐

- **GitHub Actions pinned to commit SHAs** in CI (`actions/checkout`,
  `docker/setup-buildx-action`, `docker/setup-qemu-action`) with `# vN` comments
  so Dependabot can still bump them — a moved tag can no longer inject CI code.
- Removed `:latest` base images from the buildable Dockerfiles
  (`config/keepalived`, `stacks/dns/keepalived` → `alpine:3.20`;
  `stacks/dns/unbound` → `klutchell/unbound:1.19.0`).
- `SECURITY.md` documents the image/action pinning posture.

### Removed - Legacy documentation retired 📚

- Retired 52 superseded/contradictory docs (duplicate install/upgrade/multi-node/
  disaster-recovery/testing guides, SPOG/integration notes, and `VPN_EDITION_*`
  docs that referenced the removed `deployments/`). History remains in git.
- The canonical set is now `README.md`, `SECURITY.md`, `CHANGELOG.md`, and
  `docs/` (architecture, networking, troubleshooting, disaster-recovery,
  upgrade-guide, branching-strategy, AUDIT, REVIEW) plus topic guides
  (profiles, blocklists, pihole config, hardening, netsec). Added `docs/README.md`
  as the index.

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
