# Getting Started with Orion Sentinel DNS HA

A quick guide to get your high-availability DNS stack up and running.

---

## Quick Start (5 Minutes)

```bash
# Clone and install
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
bash install.sh
```

Then open `http://<your-pi-ip>:5555` in your browser and follow the wizard.

**That's it!** The wizard will guide you through everything.

---

## Prerequisites

### Hardware
- Raspberry Pi 4/5 (4GB+ RAM recommended)
- 32GB+ SD card or SSD
- Ethernet connection
- Stable 3A+ power supply

### Software  
- Raspberry Pi OS (64-bit) or Ubuntu
- Docker 20.10+ (auto-installed by installer)

---

## Installation Options

### Option 1: Web Wizard (Recommended)

**Best for:** Everyone, especially first-time users

```bash
bash install.sh
# Open http://<your-pi-ip>:5555
```

The web wizard provides:
- ✅ Guided step-by-step setup
- ✅ Automatic configuration
- ✅ One-click deployment
- ✅ Visual feedback

---

### Option 2: Interactive CLI

**Best for:** Terminal users

```bash
bash scripts/cli-install.sh
```

Or non-interactive:
```bash
bash scripts/cli-install.sh --mode single-pi-ha --host-ip 192.168.1.100 --non-interactive
```

---

### Option 3: Manual Setup

**Best for:** Advanced users

1. Configure environment:
   ```bash
   cp .env.example .env
   nano .env  # Edit settings
   ```

2. Deploy:
   ```bash
   cd stacks/dns
   docker compose --profile single-pi-ha up -d
   ```

See [INSTALL.md](INSTALL.md) for detailed manual instructions.

---

## Choose Your Deployment Mode

| Mode | Setup | Use Case |
|------|-------|----------|
| **Single-Pi HA** | 1 Raspberry Pi | Home labs, testing |
| **Two-Pi HA** | 2 Raspberry Pis | Production, full redundancy |

**Recommendation:** Start with Single-Pi HA. You can add a second Pi later.

---

## After Installation

### 1. Access Services

| Service | URL |
|---------|-----|
| Pi-hole Admin | `http://<your-ip>/admin` |
| Grafana | `http://<your-ip>:3000` |

### 2. Configure Your Router

Set your router's DNS to your Pi's IP address (or VIP for HA mode).

### 3. Apply Security Profile

```bash
python3 scripts/apply-profile.py --profile standard
```

Profiles:
- **Standard** - Balanced ad/tracker blocking
- **Family** - Adds adult content filtering
- **Paranoid** - Maximum privacy

---

## Verify Installation

```bash
# Check services
docker ps

# Test DNS
dig @<your-ip> google.com
```

---

## Next Steps

- 📖 [User Guide](USER_GUIDE.md) - Daily operations
- 🔧 [Troubleshooting](TROUBLESHOOTING.md) - Common issues  
- 🔒 [Security Guide](SECURITY_GUIDE.md) - Hardening tips
- 🚀 [Advanced Features](ADVANCED_FEATURES.md) - VPN, SSO, and more

---

## Get Help

- 📚 [Full documentation](README.md)
- 🐛 [GitHub Issues](https://github.com/orionsentinel/Orion-DNS_Stack/issues)

---

**Ready to start?** Run `bash install.sh` and follow the wizard!
