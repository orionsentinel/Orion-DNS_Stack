# Single Raspberry Pi Installation Guide

**Orion Sentinel DNS HA - Single-Node Setup**

This guide walks you through installing Orion DNS HA on a single Raspberry Pi.

---

## Overview

A single-Pi deployment provides:
- ✅ Network-wide ad blocking with Pi-hole
- ✅ Privacy-focused recursive DNS with Unbound
- ✅ Container-level redundancy (dual instances)
- ✅ Monitoring and dashboards
- ✅ DNS security profiles

**Best for:** Home networks, testing, learning

---

## Quick Start

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and select **Single-Node** mode in the wizard.

---

## Prerequisites

### Hardware
- Raspberry Pi 4/5 (4GB+ RAM recommended)
- 32GB+ SD card or SSD
- Ethernet connection
- 3A+ power supply

### Network
- Static IP for your Pi
- Know your subnet and gateway

---

## Installation Methods

### Method 1: Web Wizard (Recommended)

1. Clone and run installer:
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   bash install.sh
   ```

2. Open `http://<your-pi-ip>:5555`

3. Select **Single-Node** mode and follow the wizard

---

### Method 2: Manual Configuration

1. Clone repository:
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   nano .env
   ```

   Key settings:
   ```bash
   HOST_IP=192.168.1.100       # Your Pi's IP
   DNS_VIP=192.168.1.100       # Same as HOST_IP for single-node
   NODE_ROLE=MASTER
   NETWORK_INTERFACE=eth0
   PIHOLE_PASSWORD=<strong-password>
   ```

3. Deploy:
   ```bash
   cd stacks/dns
   docker compose --profile single-pi-ha up -d
   ```

---

## Post-Installation

### 1. Verify Services
```bash
docker ps  # All containers should be running
```

### 2. Configure Router DNS
Set your router's DNS to your Pi's IP address.

### 3. Apply Security Profile
```bash
python3 scripts/apply-profile.py --profile standard
```

### 4. Access Pi-hole
Open `http://<your-pi-ip>/admin`

---

## Architecture

```
┌─────────────────────────────────────┐
│   Raspberry Pi (192.168.1.100)      │
│                                      │
│  ┌───────────┐    ┌───────────┐     │
│  │ Pi-hole 1 │    │ Pi-hole 2 │     │
│  └─────┬─────┘    └─────┬─────┘     │
│        │                │           │
│  ┌─────▼─────┐    ┌─────▼─────┐     │
│  │ Unbound 1 │    │ Unbound 2 │     │
│  └───────────┘    └───────────┘     │
│                                      │
│        Keepalived VIP               │
└─────────────────────────────────────┘
```

---

## Upgrading to Two-Pi HA

To add hardware redundancy later:
1. Get a second Raspberry Pi
2. Follow [docs/install-two-pi-ha.md](install-two-pi-ha.md)

---

## Next Steps

- **[USER_GUIDE.md](../USER_GUIDE.md)** — Daily operations
- **[TROUBLESHOOTING.md](../TROUBLESHOOTING.md)** — Common issues
- **[docs/profiles.md](profiles.md)** — Security profiles
