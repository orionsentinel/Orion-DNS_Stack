# Orion Sentinel HA DNS - Production-Ready Setup

**High-availability DNS stack for Raspberry Pi with ad-blocking, privacy protection, and automatic failover.**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-Latest-96060C.svg)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNSSEC-green.svg)](https://nlnetlabs.nl/projects/unbound/)

---

## 🎯 Quick Start

**New to this project? Start here:**

### One-Command Installation

```bash
# Clone the repository
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack

# Copy environment template
cp .env.production.example .env

# Edit configuration (set passwords, IPs, etc.)
nano .env

# Validate environment
make validate-env

# Deploy core DNS services
make up-core
```

**That's it!** Your HA DNS stack is now running.

- **Pi-hole Admin:** http://`<HOST_IP>`/admin
- **DNS Server:** `<VIP_ADDRESS>` (point your devices here)

---

## 📖 Table of Contents

- [Architecture](#-architecture)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
  - [Single-Pi Setup](#single-pi-setup)
  - [Two-Pi HA Setup](#two-pi-ha-setup)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)

---

## 🏗️ Architecture

```
                        Your Network Devices
                                │
                                │ DNS Queries (port 53)
                                ▼
                    ┌─────────────────────────┐
                    │   Virtual IP (VIP)      │
                    │   Managed by Keepalived │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
        ┌───────────────┐               ┌───────────────┐
        │   Pi #1       │               │   Pi #2       │
        │   (MASTER)    │               │   (BACKUP)    │
        ├───────────────┤               ├───────────────┤
        │   Pi-hole     │               │   Pi-hole     │
        │   + Unbound   │               │   + Unbound   │
        │   + Keepalived│               │   + Keepalived│
        └───────────────┘               └───────────────┘
                │                               │
                └───────────────┬───────────────┘
                                │
                        Automatic Failover
```

**How It Works:**

1. **VIP (Virtual IP):** A single IP address that floats between Pi #1 and Pi #2
2. **Clients:** Configure DNS to point to the VIP only
3. **Keepalived:** Monitors health and manages VIP assignment
4. **Automatic Failover:** If the MASTER node fails, BACKUP takes over the VIP instantly
5. **Privacy:** All DNS queries go through local Unbound (no third-party DNS providers)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🛡️ **Ad Blocking** | Network-wide ad/tracker blocking via Pi-hole |
| 🔒 **Privacy** | Recursive DNS with DNSSEC via Unbound (no third-party DNS) |
| ⚡ **High Availability** | Automatic failover with Keepalived VIP |
| 📊 **Monitoring** | Built-in exporters for Prometheus/Grafana |
| 🔧 **Easy Management** | Makefile-based commands for all operations |
| 💾 **Automated Backups** | Configuration backup and restore scripts |
| 🎛️ **Profile-Based** | Deploy only what you need via Docker Compose profiles |
| 📝 **Production-Ready** | Health checks, resource limits, logging configured |

---

## 📋 Prerequisites

### Hardware

- **Raspberry Pi 4 or 5** (4GB+ RAM recommended)
- **32GB+ SD card or SSD** (SSD highly recommended for reliability)
- **Ethernet connection** (WiFi works but wired is better)
- **3A+ USB-C power supply**

### Software

- **Raspberry Pi OS** (64-bit, latest) or **Ubuntu 22.04+**
- **Docker 20.10+** (auto-installed by bootstrap script)
- **Docker Compose v2** (auto-installed by bootstrap script)

### Network

- **Static IP addresses** for each Pi (configure in your router)
- **Available IP for VIP** (must not conflict with DHCP range)
- **Network access** for initial setup and package downloads

---

## 🚀 Installation

### Single-Pi Setup

For testing or when you only have one Raspberry Pi:

```bash
# 1. Bootstrap the node
sudo ./scripts/bootstrap-node.sh --node=pi1 --ip=192.168.8.250

# 2. Edit .env configuration
cd /opt/orion-dns-ha
nano .env

# Set these REQUIRED variables:
#   - PIHOLE_PASSWORD (generate: openssl rand -base64 32)
#   - VRRP_PASSWORD (generate: openssl rand -base64 20)
#   - VIP_ADDRESS=192.168.8.249
#   - HOST_IP=192.168.8.250
#   - DEPLOYMENT_MODE=single-pi-ha

# 3. Validate and deploy
make validate-env
make up-core

# 4. Check status
make health-check
docker ps
```

### Two-Pi HA Setup

For production high-availability:

#### On Pi #1 (Primary/MASTER):

```bash
# 1. Bootstrap Pi1
sudo ./scripts/bootstrap-node.sh --node=pi1 --ip=192.168.8.250

# 2. Configure environment
cd /opt/orion-dns-ha
cp .env.production.example .env
nano .env

# Apply Pi1-specific settings from env/pi1.env.example:
#   HOST_IP=192.168.8.250
#   NODE_ROLE=MASTER
#   KEEPALIVED_PRIORITY=200
#   PEER_IP=192.168.8.251
#   VIP_ADDRESS=192.168.8.249

# Set REQUIRED passwords (use the SAME passwords on both Pis):
#   PIHOLE_PASSWORD=<generate with: openssl rand -base64 32>
#   VRRP_PASSWORD=<generate with: openssl rand -base64 20>

# 3. Deploy
make validate-env
make up-core
```

#### On Pi #2 (Secondary/BACKUP):

```bash
# 1. Bootstrap Pi2
sudo ./scripts/bootstrap-node.sh --node=pi2 --ip=192.168.8.251

# 2. Configure environment
cd /opt/orion-dns-ha
cp .env.production.example .env
nano .env

# Apply Pi2-specific settings from env/pi2.env.example:
#   HOST_IP=192.168.8.251
#   NODE_ROLE=BACKUP
#   KEEPALIVED_PRIORITY=150
#   PEER_IP=192.168.8.250
#   VIP_ADDRESS=192.168.8.249

# Set REQUIRED passwords (MUST MATCH Pi1):
#   PIHOLE_PASSWORD=<same as Pi1>
#   VRRP_PASSWORD=<same as Pi1>

# 3. Deploy
make validate-env
make up-core
```

#### Verify HA Setup:

```bash
# Check which Pi has the VIP
ip addr show | grep <VIP_ADDRESS>

# Test DNS resolution via VIP
dig @<VIP_ADDRESS> google.com

# Simulate failover (on MASTER node)
make down

# VIP should move to BACKUP node within seconds
# Verify from BACKUP node:
ip addr show | grep <VIP_ADDRESS>

# Bring MASTER back online
make up-core

# VIP should failback to MASTER
```

---

## ⚙️ Configuration

### Required Environment Variables

The following **MUST** be set in `.env`:

```bash
# Network Configuration
HOST_IP=192.168.8.250              # IP of this Pi
VIP_ADDRESS=192.168.8.249          # Floating DNS IP
NETWORK_INTERFACE=eth0             # Network interface
SUBNET=192.168.8.0/24              # Your network subnet
GATEWAY=192.168.8.1                # Your router IP

# Keepalived (for two-pi-ha)
NODE_ROLE=MASTER                   # MASTER or BACKUP
KEEPALIVED_PRIORITY=200            # Higher = preferred MASTER
VRRP_PASSWORD=<CHANGE_ME>          # Must be same on both Pis
PEER_IP=192.168.8.251              # IP of other Pi

# Pi-hole
PIHOLE_PASSWORD=<CHANGE_ME>        # Strong password required

# Timezone
TZ=Europe/London                   # Your timezone
```

### Optional Environment Variables

```bash
# Monitoring
DEPLOY_MONITORING=true             # Enable exporters

# Notifications
NOTIFY_ON_FAILOVER=true            # Alert on failover events
ALERT_WEBHOOK=https://...          # Webhook URL for alerts

# Smart DNS
UNBOUND_SMART_PREFETCH=0           # 1 to enable prefetching

# Backup
BACKUP_INTERVAL=86400              # Backup frequency (seconds)
RETENTION_DAYS=30                  # Backup retention
```

See `.env.production.example` for all available options.

---

## 🎮 Usage

### Makefile Commands

All common operations are available via `make`:

```bash
# Core operations
make up-core          # Start core DNS services
make up-exporters     # Start monitoring exporters
make up-all           # Start everything
make down             # Stop all services
make restart          # Restart services

# Monitoring
make logs             # View logs (last 100 lines)
make logs-follow      # Follow logs in real-time
make ps               # Show running containers
make stats            # Show resource usage
make health-check     # Run health checks

# Maintenance
make backup           # Create configuration backup
make restore          # Restore from latest backup
make pull             # Pull latest container images
make update           # Update images and restart

# Information
make info             # Show deployment info
make version          # Show component versions
make help             # Show all commands
```

### Manual Failover Testing

Test high-availability failover:

```bash
# 1. Verify MASTER has VIP
# On MASTER:
ip addr show | grep <VIP_ADDRESS>

# 2. Stop services on MASTER
make down

# 3. Verify VIP moved to BACKUP
# On BACKUP:
ip addr show | grep <VIP_ADDRESS>

# 4. Test DNS still works
dig @<VIP_ADDRESS> google.com

# 5. Bring MASTER back online
make up-core

# 6. Verify VIP returns to MASTER (may take up to 30 seconds)
ip addr show | grep <VIP_ADDRESS>
```

### Health Checks

Run comprehensive health checks:

```bash
# Quick check
make health-check

# Detailed check with verbose output
./scripts/check-dns.sh --verbose

# Check individual services
docker ps                           # Container status
docker logs pihole_primary          # Pi-hole logs
docker logs unbound_primary         # Unbound logs
docker logs keepalived              # Keepalived logs
```

---

## 📊 Monitoring

### Enable Exporters

Deploy Prometheus exporters for monitoring:

```bash
# Enable in .env
DEPLOY_MONITORING=true

# Deploy exporters
make up-exporters

# Metrics endpoints:
# - Node Exporter: http://<HOST_IP>:9100/metrics
# - Pi-hole Exporter: http://<HOST_IP>:9617/metrics
# - Unbound Exporter: http://<HOST_IP>:9167/metrics
```

### Grafana Dashboards

Pre-built dashboards are available in `grafana_dashboards/`:

1. Import dashboards into your Grafana instance
2. Configure Prometheus data source pointing to your Pi
3. View DNS metrics, query rates, blocking effectiveness

---

## 🔧 Troubleshooting

### Common Issues

#### DNS not resolving

```bash
# Check if services are running
docker ps

# Check health
make health-check

# Check Pi-hole logs
docker logs pihole_primary

# Check Unbound logs
docker logs unbound_primary

# Test DNS manually
dig @127.0.0.1 google.com
```

#### VIP not assigned

```bash
# Check keepalived status
docker logs keepalived

# Verify keepalived is running
docker ps | grep keepalived

# Check network interface
ip addr show <NETWORK_INTERFACE>

# Verify VRRP password matches on both Pis
grep VRRP_PASSWORD .env
```

#### Services won't start

```bash
# Check Docker
docker ps
systemctl status docker

# Check environment
make validate-env

# Check for port conflicts
netstat -tulpn | grep -E ':(53|80|5335|9100|9617|9167)'

# Check logs
docker compose logs
```

### Getting Help

- **Documentation:** See [docs/](docs/) folder
- **Logs:** `make logs` or `docker compose logs`
- **Health Check:** `make health-check`
- **Issues:** [GitHub Issues](https://github.com/orionsentinel/Orion-DNS_Stack/issues)

---

## 📚 Documentation

### Core Documentation

- **[.env.production.example](.env.production.example)** - Environment configuration reference
- **[env/pi1.env.example](env/pi1.env.example)** - Pi1-specific settings
- **[env/pi2.env.example](env/pi2.env.example)** - Pi2-specific settings
- **[Makefile](Makefile)** - All available make commands

### Detailed Guides

- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Comprehensive installation
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md)** - Day-to-day operations
- **[DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)** - Backup and recovery

### Advanced Topics

- **[ADVANCED_FEATURES.md](ADVANCED_FEATURES.md)** - VPN, SSO, DoH/DoT
- **[SECURITY_GUIDE.md](SECURITY_GUIDE.md)** - Security hardening
- **[docs/profiles.md](docs/profiles.md)** - DNS filtering profiles
- **[docs/observability.md](docs/observability.md)** - Monitoring and metrics

---

## 🔐 Privacy Policy

**This project ONLY supports Unbound (local recursive resolver) as the upstream DNS provider.**

✅ **What we use:**
- Unbound - Full recursive DNS resolver
- Queries go directly to authoritative servers
- No third-party can log your DNS queries

❌ **What we DON'T use:**
- Google DNS (8.8.8.8)
- Cloudflare DNS (1.1.1.1)
- OpenDNS, Quad9, or any public DNS provider

**Why?** Using Unbound means maximum privacy. Your DNS queries are resolved directly from root servers without any third-party intermediary that could log, track, or monetize your browsing history.

See [docs/PIHOLE_CONFIGURATION.md](docs/PIHOLE_CONFIGURATION.md) for full rationale.

---

## 🛠️ Technology Stack

- **[Pi-hole](https://pi-hole.net/)** - Network-wide ad blocking
- **[Unbound](https://nlnetlabs.nl/projects/unbound/)** - Recursive DNS with DNSSEC
- **[Keepalived](https://www.keepalived.org/)** - VRRP for VIP management
- **[Docker](https://www.docker.com/)** - Container platform
- **[Prometheus](https://prometheus.io/)** - Metrics collection (optional)
- **[Grafana](https://grafana.com/)** - Visualization (optional)

---

## 📜 License

This project is open source. See the repository for license details.

---

## 🙏 Credits

- **Pi-hole Team** - For the amazing ad-blocking platform
- **Unbound/NLnet Labs** - For the secure recursive DNS resolver
- **Keepalived Team** - For VRRP implementation
- **Community Contributors** - For testing, feedback, and improvements

---

## 🚀 Ready to Start?

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack

# 2. Run bootstrap (on each Pi)
sudo ./scripts/bootstrap-node.sh --node=pi1 --ip=192.168.8.250

# 3. Configure .env
nano .env

# 4. Deploy
make up-core

# 5. Enjoy ad-free, private DNS with automatic failover! 🎉
```

---

**Questions? Issues? Suggestions?**

Open an [issue](https://github.com/orionsentinel/Orion-DNS_Stack/issues) or check the [documentation](docs/).

**Happy DNS filtering!** 🛡️
