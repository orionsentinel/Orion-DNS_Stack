# Two Raspberry Pi High Availability Installation Guide

**Orion Sentinel DNS HA - Dual-Pi Setup with Automatic Failover**

This guide walks you through installing Orion DNS HA on two Raspberry Pis with full hardware redundancy.

---

## Overview

A two-Pi HA deployment provides:
- ✅ Hardware redundancy — DNS continues if one Pi fails
- ✅ Automatic failover — VIP moves within seconds
- ✅ Zero-downtime updates — Update one Pi at a time
- ✅ Production-grade reliability

**Best for:** Production environments, mission-critical networks

---

## Quick Start

```bash
# On BOTH Pis:
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack

# Copy two-pi-ha template
cp env/.env.two-pi-ha.example .env

# Edit .env (set PI1_IP, PI2_IP, VIP_ADDRESS, HOST_IP, KEEPALIVED_PRIORITY)
nano .env

# On Pi1 (MASTER):
cd stacks/dns && docker compose --profile two-pi-ha-pi1 up -d

# On Pi2 (BACKUP):
cd stacks/dns && docker compose --profile two-pi-ha-pi2 up -d
```

---

## Prerequisites

### Hardware
- 2× Raspberry Pi 4/5 (4GB+ RAM each)
- 2× 32GB+ SD cards or SSDs
- 2× Ethernet cables
- 2× 3A+ power supplies
- Network switch

### Network Planning
- **Pi1 IP**: e.g., 192.168.8.250
- **Pi2 IP**: e.g., 192.168.8.251
- **VIP**: e.g., 192.168.8.249 (unused IP outside DHCP range)

---

## Installation

### Pi1 (MASTER) Setup

1. Clone repository:
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   ```

2. Configure environment:
   ```bash
   cp env/.env.two-pi-ha.example .env
   nano .env
   ```

   Set these values:
   ```bash
   PI1_IP=192.168.8.250
   PI2_IP=192.168.8.251
   VIP_ADDRESS=192.168.8.249
   HOST_IP=192.168.8.250         # This Pi's IP
   KEEPALIVED_PRIORITY=100       # Higher = MASTER
   PIHOLE_PASSWORD=<secure-password>
   VRRP_PASSWORD=<secure-password>
   ```

3. Deploy:
   ```bash
   cd stacks/dns
   docker compose --profile two-pi-ha-pi1 up -d
   ```

### Pi2 (BACKUP) Setup

1. Clone repository:
   ```bash
   git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
   cd Orion-DNS_Stack
   ```

2. Copy .env from Pi1 and modify:
   ```bash
   scp pi@192.168.8.250:~/Orion-DNS_Stack/.env .env
   nano .env
   ```

   Change ONLY these values:
   ```bash
   HOST_IP=192.168.8.251         # Pi2's IP
   KEEPALIVED_PRIORITY=90        # Lower = BACKUP
   ```

3. Deploy:
   ```bash
   cd stacks/dns
   docker compose --profile two-pi-ha-pi2 up -d
   ```

---

## Verification

### Check VIP Location

On Pi1 (should have VIP):
```bash
ip addr show eth0 | grep 192.168.8.249
```

On Pi2 (should NOT have VIP):
```bash
ip addr show eth0 | grep 192.168.8.249
```

### Test DNS

```bash
dig +short example.com @192.168.8.249  # Via VIP
dig +short example.com @192.168.8.250  # Via Pi1
dig +short example.com @192.168.8.251  # Via Pi2
```

### Test Failover

```bash
# Stop keepalived on Pi1
docker stop keepalived

# VIP should move to Pi2 within seconds
# Restart keepalived on Pi1
docker start keepalived
```

---

## Router Configuration

Set your router's DNS to the **VIP address**:
- **Primary DNS**: 192.168.8.249
- **Secondary DNS**: 192.168.8.249 (same VIP)

The VIP automatically points to whichever Pi is active.

---

## Architecture

```
┌─────────────────────────┐    ┌─────────────────────────┐
│  Pi1 (MASTER)           │    │  Pi2 (BACKUP)           │
│  192.168.8.250          │    │  192.168.8.251          │
│                          │    │                          │
│  ┌────────────────────┐ │    │  ┌────────────────────┐ │
│  │   Keepalived       │◄├────┼──┤   Keepalived       │ │
│  │   Priority: 100    │ │    │  │   Priority: 90     │ │
│  └────────────────────┘ │    │  └────────────────────┘ │
│                          │    │                          │
│  Pi-hole + Unbound      │    │  Pi-hole + Unbound      │
└────────────┬─────────────┘    └────────────┬─────────────┘
             │                               │
             └───────────┬───────────────────┘
                         │
               ┌─────────▼─────────┐
               │ VIP: 192.168.8.249│
               └───────────────────┘
```

**DNS Flow:** `Clients → VIP (192.168.8.249) → Pi-hole → Unbound → Root DNS Servers`

**Failover process:**
1. Keepalived on both Pis exchanges VRRP heartbeats (unicast)
2. If Pi #1 (MASTER) fails, Pi #2 detects missing heartbeats
3. Pi #2 (BACKUP) promotes itself to MASTER
4. VIP moves from Pi #1 to Pi #2 (gratuitous ARP)
5. DNS queries automatically route to Pi #2
6. When Pi #1 recovers, it reclaims the VIP (higher priority)

**Typical failover time:** 2-5 seconds

---

## Maintenance

### Update One Pi at a Time

```bash
# On Pi2 (BACKUP) first:
bash scripts/smart-upgrade.sh -i

# Verify Pi2 is healthy, then on Pi1:
bash scripts/smart-upgrade.sh -i
```

### Sync Pi-hole Configuration

Use Pi-hole Teleporter:
1. Export from Pi1: Pi-hole Admin → Settings → Teleporter → Export
2. Import on Pi2: Pi-hole Admin → Settings → Teleporter → Import

---

## Troubleshooting

### VIP Not Appearing

```bash
# Check keepalived logs
docker logs keepalived

# Verify VRRP_PASSWORD matches on both Pis
grep VRRP_PASSWORD .env
```

### DNS Not Working

```bash
# Check Pi-hole container
docker logs pihole_primary

# Test DNS directly
dig @127.0.0.1 example.com
```

See **[TROUBLESHOOTING.md](../TROUBLESHOOTING.md)** for more solutions.

---

## Next Steps

- **[USER_GUIDE.md](../USER_GUIDE.md)** — Daily operations
- **[DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md)** — Recovery procedures
- **[docs/profiles.md](profiles.md)** — Security profiles
