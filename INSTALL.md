# Orion Sentinel DNS HA - Installation Guide

This guide provides comprehensive, step-by-step instructions to install the Orion Sentinel DNS HA stack with Pi-hole, Unbound, and Keepalived.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Overview](#installation-overview)
- [Single-Node Installation](#single-node-installation)
- [Two-Node HA Installation](#two-node-ha-installation)
- [Post-Installation](#post-installation)
- [Systemd Integration](#systemd-integration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

**Minimum (Single Node):**
- Raspberry Pi 4, 4GB RAM
- 32GB SD card (Class 10)
- 3A+ power supply

**Recommended (Two-Node HA):**
- 2× Raspberry Pi 4/5, 4GB+ RAM
- 2× 64GB+ USB SSD drives
- 2× 3A+ power supplies
- Ethernet connection (required for VRRP)

### Software Requirements

- **Operating System**: Raspberry Pi OS (64-bit), Ubuntu Server, or Debian
- **Docker**: 20.10 or later
- **Docker Compose**: V2 (plugin format: `docker compose` not `docker-compose`)

### Network Requirements

**Single Node:**
- One static IP address (e.g., `192.168.8.249`)

**Two-Node HA:**
- Two static IPs for nodes:
  - Node A (Primary): `192.168.8.249`
  - Node B (Secondary): `192.168.8.243`
- One VIP (Virtual IP): `192.168.8.250`
- Network interface name (typically `eth0` or `eth1`)
- Gateway and subnet information

**VRRP Requirements:**
- Either multicast support OR unicast mode (unicast recommended)
- No firewall blocking VRRP protocol (IP protocol 112) if using multicast
- Nodes must be on the same L2 subnet

### Knowledge Requirements

- Basic Linux command-line skills
- SSH access to your Raspberry Pi(s)
- Understanding of basic networking concepts
- Familiarity with environment variables

---

## Installation Overview

The installation process follows these steps:

1. **Prepare Raspberry Pi(s)**: Install OS, configure network, install Docker
2. **Clone Repository**: Get the latest code
3. **Configure Environment**: Set up `.env` file with your network settings
4. **Deploy Services**: Start Docker containers
5. **Verify Operation**: Test DNS resolution and failover (HA mode)
6. **Set Up Systemd**: Enable autostart and operational timers
7. **Configure Clients**: Point devices to new DNS server

**Time Required:**
- Single Node: ~30 minutes
- Two-Node HA: ~60 minutes

---

## Single-Node Installation

Perfect for testing, home labs, or single Pi setups.

### Step 1: Prepare Raspberry Pi

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Exit SSH session and log back in for group changes to take effect
exit
```

### Step 2: Clone Repository

```bash
# Clone to recommended location
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-DNS_Stack.git orion-dns-ha
sudo chown -R $USER:$USER orion-dns-ha
cd orion-dns-ha
```

### Step 3: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit configuration
nano .env
```

**Required Changes in `.env`:**

```bash
# Set your Pi's IP address
NODE_IP=192.168.8.249  # Change to your Pi's IP

# Set Pi-hole admin password (REQUIRED)
WEBPASSWORD=your-strong-password-here  # Generate with: openssl rand -base64 32

# Adjust network settings if needed
NETWORK_INTERFACE=eth0  # Your network interface (check with: ip addr)
SUBNET=192.168.8.0/24   # Your subnet
GATEWAY=192.168.8.1     # Your gateway
TZ=America/New_York     # Your timezone
```

**Optional Settings:**

```bash
# DNS over TLS via NextDNS (disabled by default for local recursion)
# See unbound/nextdns-forward.conf to enable

# Monitoring (if you have Prometheus/Loki)
LOKI_URL=http://your-loki:3100
```

### Step 4: Deploy Services

```bash
# Start Pi-hole + Unbound
docker compose --profile single-node up -d

# Verify containers are running
docker ps
```

Expected output:
```
CONTAINER ID   IMAGE                                    STATUS
abc123def456   ghcr.io/mpgirro/docker-pihole-unbound   Up 10 seconds
```

### Step 5: Verify Operation

```bash
# Test DNS resolution
dig @localhost github.com

# Should return an answer section with IP addresses
```

### Step 6: Access Pi-hole Admin

Open in your browser:
```
http://<your-pi-ip>/admin
```

Login with the password you set in `WEBPASSWORD`.

---

## Two-Node HA Installation

For production deployments with automatic failover.

### Architecture

```
Node A (Primary)        Node B (Secondary)
192.168.8.249          192.168.8.243
Priority: 200          Priority: 150
                ↓
        VIP: 192.168.8.250
        (Floats between nodes)
```

### Prerequisites

1. **SSH Key Setup** (for Pi-hole sync):

```bash
# On Node A (Primary)
ssh-keygen -t ed25519 -C "orion-dns-sync"
ssh-copy-id pi@192.168.8.243

# Test connection
ssh pi@192.168.8.243 "echo Connection successful"
```

2. **Static IP Assignment**:
   - Configure both Pis with static IPs via DHCP reservation or `/etc/dhcpcd.conf`

3. **Time Synchronization**:
```bash
# On both nodes
sudo timedatectl set-ntp true
```

### Node A (Primary) Setup

#### Step 1: Prepare Node A

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install rsync (for Pi-hole sync)
sudo apt-get install -y rsync

# Log out and back in
exit
```

#### Step 2: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-DNS_Stack.git orion-dns-ha
sudo chown -R $USER:$USER orion-dns-ha
cd orion-dns-ha
```

#### Step 3: Configure as Primary

```bash
# Use primary example
cp .env.primary.example .env

# Edit configuration
nano .env
```

**Key Settings for Primary:**

```bash
# Node Identity
HOSTNAME=orion-dns-primary
NODE_IP=192.168.8.249      # Primary node IP
NODE_ROLE=MASTER

# VIP Configuration
VIP_ADDRESS=192.168.8.250
VIP_NETMASK=24
NETWORK_INTERFACE=eth1      # Interface for VIP (usually eth0 or eth1)

# Network Settings
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1
TZ=America/New_York

# Keepalived
KEEPALIVED_PRIORITY=200     # Higher = preferred MASTER
VRRP_PASSWORD=your-shared-secret  # MUST match on both nodes!

# VRRP Peer
USE_UNICAST_VRRP=true
PEER_IP=192.168.8.243       # Secondary node IP
UNICAST_SRC_IP=192.168.8.249

# Pi-hole
WEBPASSWORD=your-strong-password  # Generate: openssl rand -base64 32

# Monitoring (optional)
PROM_INSTANCE_LABEL=node-primary
LOKI_URL=http://192.168.8.100:3100
```

#### Step 4: Deploy on Primary

```bash
# Start services
docker compose --profile two-node-ha-primary up -d

# Or use Make
make up-core

# Verify VIP is assigned
ip addr show eth1 | grep 192.168.8.250
```

Expected: You should see `192.168.8.250/24` listed under `eth1`.

#### Step 5: Verify Primary

```bash
# Check containers
docker ps

# Test DNS on VIP
dig @192.168.8.250 github.com

# Check keepalived logs
docker logs keepalived

# Should see: "Entering MASTER STATE"
```

### Node B (Secondary) Setup

#### Step 1: Prepare Node B

Same as Node A:

```bash
sudo apt-get update && sudo apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo apt-get install -y rsync
exit  # Log out and back in
```

#### Step 2: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-DNS_Stack.git orion-dns-ha
sudo chown -R $USER:$USER orion-dns-ha
cd orion-dns-ha
```

#### Step 3: Configure as Secondary

```bash
# Use secondary example
cp .env.secondary.example .env

# Edit configuration
nano .env
```

**Key Settings for Secondary:**

```bash
# Node Identity
HOSTNAME=orion-dns-secondary
NODE_IP=192.168.8.243       # Secondary node IP
NODE_ROLE=BACKUP

# VIP Configuration (same as primary)
VIP_ADDRESS=192.168.8.250
VIP_NETMASK=24
NETWORK_INTERFACE=eth1

# Network Settings (same as primary)
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1
TZ=America/New_York

# Keepalived
KEEPALIVED_PRIORITY=150     # Lower than primary!
VRRP_PASSWORD=your-shared-secret  # MUST match primary!

# VRRP Peer
USE_UNICAST_VRRP=true
PEER_IP=192.168.8.249       # Primary node IP
UNICAST_SRC_IP=192.168.8.243

# Pi-hole
WEBPASSWORD=your-strong-password  # Should match primary

# Monitoring (optional)
PROM_INSTANCE_LABEL=node-secondary
LOKI_URL=http://192.168.8.100:3100
```

#### Step 4: Deploy on Secondary

```bash
# Start services
docker compose --profile two-node-ha-backup up -d

# Or use Make
make up-core

# Verify VIP is NOT assigned (should be on primary)
ip addr show eth1 | grep 192.168.8.250
```

Expected: VIP should NOT appear (it's on the primary).

#### Step 5: Verify Secondary

```bash
# Check containers
docker ps

# Test DNS on local IP (not VIP)
dig @192.168.8.243 github.com

# Check keepalived logs
docker logs keepalived

# Should see: "Entering BACKUP STATE"
```

### Step 6: Test Failover

```bash
# On Node A (Primary), stop Pi-hole
docker stop pihole_unbound

# Wait 15-20 seconds, then on Node B check VIP
ip addr show eth1 | grep 192.168.8.250

# VIP should now be on Node B!

# Test DNS still works
dig @192.168.8.250 github.com

# Restart Pi-hole on Node A
docker start pihole_unbound

# VIP should return to Node A within 15-20 seconds
```

---

## Post-Installation

### Configure Pi-hole Sync (Two-Node HA Only)

Synchronize Pi-hole configuration from primary to secondary:

```bash
# On Node A (Primary), run manual sync
make sync

# Or directly
PEER_IP=192.168.8.243 ./ops/pihole-sync.sh
```

### Enable Monitoring Exporters (Optional)

```bash
# On both nodes
docker compose --profile exporters up -d

# Or restart with exporters
make down
make up-all
```

Exporters available:
- **Node Exporter**: `http://<node-ip>:9100/metrics`
- **Pi-hole Exporter**: `http://<node-ip>:9617/metrics`
- **Promtail**: Logs → Loki

### Configure Automatic Updates (Optional)

```bash
# Add to crontab for weekly gravity updates
crontab -e

# Add this line:
0 3 * * 0 docker exec pihole_unbound pihole updateGravity
```

---

## Systemd Integration

Enable autostart, health checks, backups, and sync on boot.

### Primary Node

```bash
# Install systemd units
sudo make install-systemd-primary

# Enable and start services
sudo systemctl enable --now orion-dns-ha-primary.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer
sudo systemctl enable --now orion-dns-ha-sync.timer

# Verify status
sudo systemctl status orion-dns-ha-primary.service
sudo systemctl list-timers
```

### Secondary Node

```bash
# Install systemd units
sudo make install-systemd-secondary

# Enable and start services
sudo systemctl enable --now orion-dns-ha-backup-node.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer

# Verify status
sudo systemctl status orion-dns-ha-backup-node.service
sudo systemctl list-timers
```

### What the Timers Do

- **Health Timer** (`orion-dns-ha-health.timer`):
  - Runs every minute
  - Executes DNS health check via `ops/orion-dns-health.sh`
  - Auto-restarts containers on repeated failures
  
- **Backup Timer** (`orion-dns-ha-backup.timer`):
  - Runs daily at 3 AM
  - Creates compressed backup via `ops/orion-dns-backup.sh`
  - Retains backups for 7 days (configurable via `BACKUP_RETENTION_DAYS`)
  
- **Sync Timer** (`orion-dns-ha-sync.timer`, primary only):
  - Runs hourly
  - Syncs Pi-hole config from primary to secondary
  - Requires SSH key authentication

---

## Verification

### DNS Resolution Tests

```bash
# Test VIP (HA setup)
dig @192.168.8.250 github.com
dig @192.168.8.250 google.com

# Test specific node
dig @192.168.8.249 github.com  # Primary
dig @192.168.8.243 github.com  # Secondary

# Test DNSSEC validation
dig @192.168.8.250 dnssec-failed.org  # Should fail (SERVFAIL)
dig @192.168.8.250 dnssec.works       # Should succeed
```

### VRRP Status Check

```bash
# Check which node has VIP
# On Node A:
ip addr show eth1 | grep 192.168.8.250

# On Node B:
ip addr show eth1 | grep 192.168.8.250

# Only one should show the VIP

# Check VRRP communication
docker logs keepalived | tail -20
```

### Pi-hole Admin Access

```bash
# Single node
http://<node-ip>/admin

# Two-node HA
http://192.168.8.250/admin  # Always works (VIP)
http://192.168.8.249/admin  # Primary direct
http://192.168.8.243/admin  # Secondary direct
```

### Container Health

```bash
# Check all containers
docker ps

# View Pi-hole logs
docker logs pihole_unbound

# View Keepalived logs
docker logs keepalived

# Check health check script
docker exec keepalived /etc/keepalived/check_dns.sh
echo $?  # 0 = healthy, 1 = failed
```

---

## Troubleshooting

### Issue: DNS Not Resolving

**Symptoms:** `dig @192.168.8.250` times out or returns SERVFAIL

**Solutions:**

1. **Check container is running:**
   ```bash
   docker ps | grep pihole_unbound
   ```

2. **Verify network mode is host:**
   ```bash
   docker inspect pihole_unbound | grep NetworkMode
   # Should show "host"
   ```

3. **Check DNSMASQ_LISTENING:**
   ```bash
   grep DNSMASQ_LISTENING .env
   # Should be "all"
   ```

4. **Check Pi-hole logs:**
   ```bash
   docker logs pihole_unbound | tail -50
   ```

5. **Test Unbound directly:**
   ```bash
   docker exec pihole_unbound dig @127.0.0.1 -p 5335 github.com
   ```

### Issue: VIP Not Assigned

**Symptoms:** `ip addr show` doesn't show VIP on either node

**Solutions:**

1. **Check network interface name:**
   ```bash
   ip addr show
   # Find your interface (eth0, eth1, etc.)
   # Update NETWORK_INTERFACE in .env
   ```

2. **Verify VRRP password matches:**
   ```bash
   # On both nodes
   grep VRRP_PASSWORD .env
   # Must be identical!
   ```

3. **Check unicast configuration:**
   ```bash
   # Both nodes should have:
   USE_UNICAST_VRRP=true
   PEER_IP=<other-node-ip>
   UNICAST_SRC_IP=<this-node-ip>
   ```

4. **Review keepalived config:**
   ```bash
   docker exec keepalived cat /etc/keepalived/keepalived.conf
   # Check for syntax errors
   ```

5. **Check keepalived logs:**
   ```bash
   docker logs keepalived
   # Look for errors
   ```

### Issue: Failover Not Working

**Symptoms:** VIP stays on failed primary

**Solutions:**

1. **Test health check manually:**
   ```bash
   docker exec keepalived /etc/keepalived/check_dns.sh
   echo $?  # Should return 0 when healthy
   ```

2. **Verify health check settings:**
   ```bash
   grep CHECK_ .env
   # CHECK_DNS_TARGET should be 127.0.0.1
   # CHECK_DNS_FQDN should be resolvable
   ```

3. **Check weight settings:**
   ```bash
   # CHECK_WEIGHT should be negative (e.g., -20)
   # This decreases priority on failures
   ```

4. **Monitor VRRP transitions:**
   ```bash
   docker exec keepalived tail -f /var/log/keepalived-notify.log
   # Stop primary Pi-hole and watch transitions
   ```

### Issue: Pi-hole Sync Fails

**Symptoms:** `make sync` or `ops/pihole-sync.sh` fails

**Solutions:**

1. **Test SSH connectivity:**
   ```bash
   ssh pi@192.168.8.243 "echo SSH works"
   # Should succeed without password prompt
   ```

2. **Set up SSH keys:**
   ```bash
   ssh-keygen -t ed25519
   ssh-copy-id pi@192.168.8.243
   ```

3. **Verify rsync installed:**
   ```bash
   # On both nodes
   which rsync
   # Install if missing: sudo apt-get install rsync
   ```

4. **Check PEER_IP:**
   ```bash
   grep PEER_IP .env
   # Should point to secondary node
   ```

### Issue: Containers Keep Restarting

**Symptoms:** `docker ps` shows containers repeatedly restarting

**Solutions:**

1. **Check logs for errors:**
   ```bash
   docker logs pihole_unbound
   docker logs keepalived
   ```

2. **Verify environment variables:**
   ```bash
   docker compose config
   # Check for unresolved ${VARS}
   ```

3. **Check for port conflicts:**
   ```bash
   sudo netstat -tulpn | grep :53
   # Port 53 should be free or used by pihole_unbound
   ```

4. **Review compose.yml syntax:**
   ```bash
   docker compose config > /dev/null
   # Should complete without errors
   ```

---

## Next Steps

After successful installation:

1. **Configure Client Devices**: Point to `192.168.8.250` (or single node IP) as DNS server
2. **Set Up Router DHCP**: Configure DHCP to advertise your new DNS server
3. **Customize Pi-hole**: Add whitelist/blacklist entries, configure blocklists
4. **Set Up Monitoring**: Connect exporters to Prometheus/Grafana
5. **Review Logs**: Check `docker logs` regularly for the first week
6. **Test Failover**: Periodically test HA failover (if two-node setup)

---

## Additional Resources

- **GitHub Repository**: https://github.com/orionsentinel/Orion-DNS_Stack
- **Pi-hole Documentation**: https://docs.pi-hole.net/
- **Unbound Documentation**: https://www.nlnetlabs.nl/documentation/unbound/
- **Keepalived Documentation**: https://keepalived.readthedocs.io/

---

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [README.md](README.md) troubleshooting section
2. Review GitHub Issues: https://github.com/orionsentinel/Orion-DNS_Stack/issues
3. Open a new issue with:
   - Your setup (single/two-node)
   - Output of `docker ps`, `docker logs`, and relevant config files
   - Steps to reproduce the problem

---

**Installation complete!** Your high-availability DNS infrastructure is now operational. 🎉
