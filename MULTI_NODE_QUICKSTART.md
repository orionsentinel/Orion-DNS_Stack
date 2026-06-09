# Two-Pi HA Deployment - Quick Start Guide

## 🎯 Overview
Deploy **true high availability DNS** across two Raspberry Pi nodes with automatic failover. When one Pi fails, the other takes over within 10 seconds — zero client configuration required.

## ✨ What You Get
- **Hardware-level redundancy**: Survives complete Pi failure, SD card failure, power loss
- **Automatic failover**: VIP moves to healthy node via Keepalived + VRRP
- **Zero client config**: All LAN devices use a single VIP for DNS
- **Synchronized configuration**: Pi-hole settings sync automatically between nodes
- **Simple management**: Same Docker Compose file on both nodes, minimal per-node differences

---

## 📋 Two-Pi HA Quick Start (30 Minutes)

### Prerequisites
- **2x Raspberry Pi** (Pi 4/5, 4GB+ RAM recommended)
- **Static IP addresses** set for both Pis on your router
- **Same LAN subnet** (e.g., 192.168.8.0/24)
- **SSH access** to both Pis
- **Basic Linux knowledge**

### Architecture
```
┌─────────────────────┐         ┌─────────────────────┐
│   Pi1 (Primary)     │         │   Pi2 (Secondary)   │
│   192.168.8.11      │◄───────►│   192.168.8.12      │
│                     │  VRRP   │                     │
│ ┌─────────────────┐ │         │ ┌─────────────────┐ │
│ │ Pi-hole         │ │         │ │ Pi-hole         │ │
│ │ Unbound         │ │         │ │ Unbound         │ │
│ │ Keepalived      │ │         │ │ Keepalived      │ │
│ │   [MASTER]      │ │         │ │   [BACKUP]      │ │
│ └─────────────────┘ │         │ └─────────────────┘ │
│                     │         │                     │
│  VIP: 192.168.8.249 │         │                     │
│       ▲             │         │       ▲             │
└───────┼─────────────┘         └───────┼─────────────┘
        │                               │
        └───────────┬───────────────────┘
                    │
            ┌───────▼────────┐
            │  LAN Clients   │
            │  Use VIP Only  │
            │  .249 for DNS  │
            └────────────────┘
```

---

### Step 1: Prepare Both Raspberry Pis (10 min)

On **both Pi1 and Pi2**:

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker if not present
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# Clone repository to /opt/Orion-DNS_Stack
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
sudo chown -R $USER:$USER Orion-DNS_Stack
cd Orion-DNS_Stack
```

**Verify static IPs** are set on your router:
- Pi1: `192.168.8.11` (example)
- Pi2: `192.168.8.12` (example)
- VIP: `192.168.8.249` (must NOT be in DHCP range)

---

### Step 2: Configure Pi1 (Primary) (5 min)

On **Pi1** only:

```bash
cd /opt/Orion-DNS_Stack

# Copy example .env
cp .env.multinode.example .env

# Edit .env for Pi1
nano .env
```

**Edit these settings for Pi1:**
```bash
# THIS NODE SETTINGS - EDIT FOR PI1
NODE_ROLE=primary
HOST_IP=192.168.8.11
NODE_HOSTNAME=pi1-dns

# PEER NODE SETTINGS
PI1_IP=192.168.8.11
PI2_IP=192.168.8.12
PEER_IP=192.168.8.12          # Points to Pi2

# VIP CONFIGURATION
VIP_ADDRESS=192.168.8.249      # Same on both
VIP_NETMASK=32                 # /32 for host-only IP

# KEEPALIVED - PI1 HAS HIGHER PRIORITY
KEEPALIVED_PRIORITY=200        # Higher = preferred MASTER

# SECURITY - CHANGE THESE!
# CRITICAL: VRRP_PASSWORD must be EXACTLY 8 characters (VRRP PASS auth limitation)
VRRP_PASSWORD=oriondns         # Exactly 8 chars! Must match Pi2!
PIHOLE_PASSWORD=YourSecurePiholePassword123!

# MONITORING - Enable on Pi1 only
DEPLOY_MONITORING=true
```

> **⚠️ IMPORTANT:** VRRP_PASSWORD must be exactly 8 characters (VRRP PASS limitation).
> The container will refuse to start if the password length is incorrect.

Save and exit (Ctrl+X, Y, Enter).

---

### Step 3: Configure Pi2 (Secondary) (5 min)

On **Pi2** only:

```bash
cd /opt/Orion-DNS_Stack

# Copy example .env
cp .env.multinode.example .env

# Edit .env for Pi2
nano .env
```

**Edit these settings for Pi2:**
```bash
# THIS NODE SETTINGS - EDIT FOR PI2
NODE_ROLE=secondary
HOST_IP=192.168.8.12           # Different from Pi1!
NODE_HOSTNAME=pi2-dns

# PEER NODE SETTINGS (same as Pi1)
PI1_IP=192.168.8.11
PI2_IP=192.168.8.12
PEER_IP=192.168.8.11           # Points to Pi1

# VIP CONFIGURATION (same as Pi1)
VIP_ADDRESS=192.168.8.249
VIP_NETMASK=32                 # /32 for host-only IP

# KEEPALIVED - PI2 HAS LOWER PRIORITY
KEEPALIVED_PRIORITY=150        # Lower = BACKUP node

# SECURITY - MUST BE SAME AS PI1!
# CRITICAL: VRRP_PASSWORD must be EXACTLY 8 characters (must match Pi1!)
VRRP_PASSWORD=oriondns         # Exactly 8 chars! Same as Pi1!
PIHOLE_PASSWORD=YourSecurePiholePassword123!  # SAME as Pi1

# MONITORING - Disable on Pi2 to save resources
DEPLOY_MONITORING=false
```

Save and exit (Ctrl+X, Y, Enter).

⚠️ **CRITICAL**: `VRRP_PASSWORD` and `PIHOLE_PASSWORD` **must be identical** on both Pis!

---

### Step 4: Deploy Services (5 min)

On **Pi1** (deploy primary services):

```bash
cd /opt/Orion-DNS_Stack/stacks/dns

# Deploy with two-pi-ha-pi1 profile
docker compose --profile two-pi-ha-pi1 up -d

# Check status
docker compose ps
```

On **Pi2** (deploy secondary services):

```bash
cd /opt/Orion-DNS_Stack/stacks/dns

# Deploy with two-pi-ha-pi2 profile
docker compose --profile two-pi-ha-pi2 up -d

# Check status
docker compose ps
```

**Expected containers on each Pi:**
- Pi1: `pihole_primary`, `unbound_primary`, `keepalived`
- Pi2: `pihole_secondary`, `unbound_secondary`, `keepalived`

---

### Step 5: Verify Deployment (5 min)

Run the automated verification script on **both** nodes:

```bash
cd /opt/Orion-DNS_Stack
./scripts/verify-ha.sh
```

This script will check:
- ✓ Which node currently holds the VIP
- ✓ Keepalived container status and logs
- ✓ Unicast peer configuration (PEER_IP and UNICAST_SRC_IP)
- ✓ DNS resolution via VIP
- ✓ DNS resolution via node IP

**Expected results:**
- **Pi1 (Primary):** Has VIP, state MASTER, DNS works on both VIP and Node IP
- **Pi2 (Secondary):** No VIP, state BACKUP, DNS works on Node IP only

#### Manual Verification (if needed)

#### Check VIP Ownership

On **Pi1**:
```bash
# Should show VIP assigned to eth0 (Pi1 is MASTER)
ip addr show eth0 | grep 192.168.8.249
```

On **Pi2**:
```bash
# Should NOT show VIP (Pi2 is BACKUP)
ip addr show eth0 | grep 192.168.8.249
```

Only **Pi1** should have the VIP.

#### Check Keepalived State

On **Pi1**:
```bash
docker logs keepalived | tail -20 | grep "MASTER\|BACKUP"
# Should see: "Entering MASTER STATE"
```

On **Pi2**:
```bash
docker logs keepalived | tail -20 | grep "MASTER\|BACKUP"
# Should see: "Entering BACKUP STATE"
```

#### Test DNS Resolution

From **any device on your network**:

```bash
# Test DNS via VIP
dig google.com @192.168.8.249
nslookup google.com 192.168.8.249

# Test Pi-hole admin UI
# Open in browser: http://192.168.8.249/admin
```

#### Run Health Check

On **either Pi**:
```bash
cd /opt/Orion-DNS_Stack
bash scripts/orion-dns-ha-health.sh

# Expected output:
# ✓ Docker daemon is running
# ✓ pihole_primary is running and healthy
# ✓ unbound_primary is running and healthy
# ✓ keepalived is running and healthy
# ✓ VIP is assigned to this node
# ✓ DNS resolution working
# Overall Status: HEALTHY ✓
```

---

### Step 6: Test Failover (5 min)

This verifies automatic failover works:

#### Test 1: Stop Keepalived on Pi1

On **Pi1**:
```bash
docker stop keepalived
```

**Wait 10 seconds**, then check Pi2:

On **Pi2**:
```bash
ip addr show eth0 | grep 192.168.8.249
# VIP should NOW appear on Pi2 (failover happened)

docker logs keepalived | tail -10
# Should show: "Entering MASTER STATE"
```

From **any network device**:
```bash
# DNS should still work via VIP
dig google.com @192.168.8.249
# ✓ Should resolve (now served by Pi2)
```

#### Test 2: Restore Pi1 (Failback)

On **Pi1**:
```bash
docker start keepalived
```

**Wait 10 seconds**, then check:

On **Pi1**:
```bash
ip addr show eth0 | grep 192.168.8.249
# VIP should return to Pi1 (failback happened)
```

On **Pi2**:
```bash
ip addr show eth0 | grep 192.168.8.249
# VIP should disappear from Pi2
```

✅ **Success!** Automatic failover and failback are working.

---

## 🔧 Post-Deployment Configuration

### Configure LAN Clients to Use VIP

Update **DHCP settings on your router**:
- **Primary DNS**: `192.168.8.249` (the VIP)
- **Secondary DNS**: Leave blank or use `1.1.1.1` as ultimate fallback

All clients will now use the VIP for DNS. When Pi1 fails, they automatically fail over to Pi2.

### Access Pi-hole Admin UI

- **Via VIP**: `http://192.168.8.249/admin` (always goes to MASTER node)
- **Via Pi1 directly**: `http://192.168.8.11/admin`
- **Via Pi2 directly**: `http://192.168.8.12/admin`

Login with your `PIHOLE_PASSWORD`.

### Set Up Pi-hole Configuration Sync (Optional)

To keep Pi-hole settings synchronized between Pi1 and Pi2:

On **Pi1** (primary):
```bash
# Install Gravity Sync
cd /opt
git clone https://github.com/vmstan/gravity-sync.git
cd gravity-sync
./gs-install.sh

# Configure sync to Pi2
./gs-config.sh
```

Follow prompts to set up SSH keys and configure sync to Pi2.

### Enable Signal Notifications (Optional)

Edit `.env` on both Pis:
```bash
SIGNAL_NUMBER=+1234567890
SIGNAL_RECIPIENTS=+1234567890
NOTIFY_ON_FAILOVER=true
NOTIFY_ON_FAILBACK=true
```

Restart services:
```bash
docker compose --profile two-pi-ha-pi1 down  # On Pi1
docker compose --profile two-pi-ha-pi1 up -d

docker compose --profile two-pi-ha-pi2 down  # On Pi2
docker compose --profile two-pi-ha-pi2 up -d
```

---

## 🔍 Monitoring & Maintenance

### Daily Health Checks

Run on **either Pi**:
```bash
cd /opt/Orion-DNS_Stack
bash scripts/orion-dns-ha-health.sh
```

### Check VIP Ownership
```bash
# On Pi1
ip addr show eth0 | grep VIP_ADDRESS

# On Pi2
ip addr show eth0 | grep VIP_ADDRESS
```

### View Keepalived Logs
```bash
# Recent state changes
docker logs keepalived | tail -50

# Follow logs in real-time
docker logs -f keepalived
```

### Update Services

On **both Pis** (one at a time!):
```bash
cd /opt/Orion-DNS_Stack
git pull
docker compose pull
docker compose --profile two-pi-ha-pi1 up -d  # On Pi1
docker compose --profile two-pi-ha-pi2 up -d  # On Pi2
```

---

## 🆘 Troubleshooting

### VIP Not Showing on Any Node

**Symptom**: Neither Pi has VIP assigned
```bash
# Check VRRP traffic isn't blocked
sudo tcpdump -i eth0 vrrp

# Check Keepalived logs
docker logs keepalived
```

**Solution**: Use unicast VRRP (already set in .env.multinode.example)

### Both Nodes Claim MASTER (Split Brain)

**Symptom**: Both Pis show VIP assigned

**Cause**: Network partition or misconfiguration

**Solution**: 
1. Check `VIRTUAL_ROUTER_ID` matches on both Pis
2. Check `VRRP_PASSWORD` matches on both Pis
3. Verify network connectivity: `ping <other-pi-ip>`

### DNS Not Resolving

**Symptom**: `dig @192.168.8.249 google.com` fails

```bash
# Check Pi-hole is running
docker ps | grep pihole

# Check Pi-hole logs
docker logs pihole_primary  # On Pi1
docker logs pihole_secondary  # On Pi2

# Test local DNS
dig @127.0.0.1 google.com
```

### Sync Not Working

**Symptom**: Changes on Pi1 don't appear on Pi2

**Solution**: Set up Gravity Sync (see Post-Deployment section)

---

## 📊 What's Different from Single-Node?

| Aspect | Single-Node HA | Two-Pi HA |
|--------|---------------|-----------|
| Hardware Failure Protection | ❌ No | ✅ Yes |
| Pi Failure Survives | ❌ No | ✅ Yes |
| SD Card Failure Survives | ❌ No | ✅ Yes |
| Power Loss Survives | ❌ No | ✅ Yes (if one Pi down) |
| Failover Time | <5s (container) | <10s (node) |
| Complexity | Low | Medium |
| Cost | 1 Pi | 2 Pis |
| Management | Simple | Moderate |

---

## 📚 Additional Documentation

For more detailed information, see:

- **[MULTI_NODE_HA_DESIGN.md](./MULTI_NODE_HA_DESIGN.md)** - Complete architecture design
- **[MULTI_NODE_DEPLOYMENT_CHECKLIST.md](./MULTI_NODE_DEPLOYMENT_CHECKLIST.md)** - Detailed checklist
- **[MULTI_NODE_INDEX.md](./MULTI_NODE_INDEX.md)** - Documentation index

---

# Original Multi-Node Documentation

The sections below contain the original multi-node exploration documentation.

## What's New
This exploration provides everything needed to set up true hardware-level redundancy:

### 📚 Documentation
- **[MULTI_NODE_HA_DESIGN.md](./MULTI_NODE_HA_DESIGN.md)** - Complete architecture design document with two options:
  - Option A: Simplified (1 Pi-hole + 1 Unbound per node) - **RECOMMENDED**
  - Option B: Full Redundancy (2 Pi-hole + 2 Unbound per node) - Advanced
  
- **[MULTI_NODE_DEPLOYMENT_CHECKLIST.md](./MULTI_NODE_DEPLOYMENT_CHECKLIST.md)** - Step-by-step deployment checklist with verification tests

### ⚙️ Configuration Files
- **`.env.multinode.example`** - Environment configuration template with all required variables
- **`stacks/dns/keepalived/keepalived-multinode-primary.conf`** - Keepalived config for primary node
- **`stacks/dns/keepalived/keepalived-multinode-secondary.conf`** - Keepalived config for secondary node
- **`stacks/dns/keepalived/check_dns.sh`** - Health check script for automatic failover
- **`stacks/dns/keepalived/notify_*.sh`** - Notification scripts for state changes

### 🔧 Deployment Tools
- **`scripts/deploy-multinode.sh`** - Automated deployment script for multi-node setup

## Quick Start

### 1. Read the Design Document
```bash
cat MULTI_NODE_HA_DESIGN.md
```

### 2. Prepare Both Raspberry Pis
- Set static IPs (e.g., 192.168.8.11 and 192.168.8.12)
- Install Docker and Docker Compose
- Clone this repository to `/opt/rpi-ha-dns-stack` on both nodes

### 3. Configure Environment
On **Pi #1 (Primary)**:
```bash
cp .env.multinode.example .env
nano .env
# Set: NODE_ROLE=primary, NODE_IP=192.168.8.11, PEER_IP=192.168.8.12
```

On **Pi #2 (Secondary)**:
```bash
cp .env.multinode.example .env
nano .env
# Set: NODE_ROLE=secondary, NODE_IP=192.168.8.12, PEER_IP=192.168.8.11
```

### 4. Deploy
On **both nodes**:
```bash
sudo bash scripts/deploy-multinode.sh
```

### 5. Verify
From another device on your network:
```bash
# Test DNS via VIP
dig google.com @192.168.8.255

# Test failover
ssh pi@192.168.8.11 "docker stop keepalived"
# VIP should move to Pi #2 within 10 seconds
dig google.com @192.168.8.255  # Should still work
```

## Architecture Comparison

| Feature | Single Node (Current) | Multi-Node (New) |
|---------|----------------------|------------------|
| Hardware Resilience | ❌ None | ✅ Full |
| Container Resilience | ✅ Yes | ✅ Yes |
| Failover Time | <5 seconds | <10 seconds |
| Physical Pis Required | 1 | 2 |
| Management Complexity | Low | Medium |

## How It Works

### Current Setup (Single Node)
```
┌─────────────────────────────────────┐
│  Raspberry Pi #1                    │
│  ├── Pi-hole Primary (.251)         │
│  ├── Pi-hole Secondary (.252)       │
│  ├── Unbound Primary (.253)         │
│  ├── Unbound Secondary (.254)       │
│  └── Keepalived VIP (.255)          │
│      (local failover only)          │
└─────────────────────────────────────┘
❌ If Pi #1 fails, entire DNS is down
```

### Multi-Node Setup (New)
```
┌──────────────────────┐  ┌──────────────────────┐
│  Raspberry Pi #1     │  │  Raspberry Pi #2     │
│  ├── Pi-hole (.251)  │  │  ├── Pi-hole (.252)  │
│  ├── Unbound (.253)  │  │  ├── Unbound (.254)  │
│  └── Keepalived      │  │  └── Keepalived      │
│      MASTER          │  │      BACKUP          │
└──────────┬───────────┘  └──────────┬───────────┘
           │                          │
           └──────────┬───────────────┘
                      │
              VIP: 192.168.8.255
           (floats between nodes)
```
✅ If Pi #1 fails, Pi #2 takes over automatically

## Key Concepts

### Virtual IP (VIP)
- Shared IP address that "floats" between the two nodes
- Clients always use this IP (192.168.8.255)
- Keepalived manages which node owns the VIP
- Automatic failover if primary node fails

### VRRP (Virtual Router Redundancy Protocol)
- Industry-standard protocol for IP failover
- Both nodes communicate via VRRP heartbeats
- If primary stops responding, secondary takes over
- Failover typically takes 5-10 seconds

### Synchronization
- **Gravity Sync**: Syncs Pi-hole configurations between nodes
- **Rsync**: Syncs Unbound configurations
- Runs periodically (default: every hour)
- Can be triggered manually: `sudo gravity-sync push`

### Health Checks
- Keepalived runs health checks every 5 seconds
- Tests if local Pi-hole is responding to DNS queries
- If 3 consecutive checks fail, triggers failover
- Automatic recovery when primary returns to health

## Monitoring Failover Events

### Check Current VIP Holder
```bash
# On Pi #1:
ip addr show eth0 | grep 192.168.8.255
# If output shown = this node is MASTER

# On Pi #2:
ip addr show eth0 | grep 192.168.8.255
# If output shown = this node is MASTER
```

### Check Keepalived State
```bash
docker logs keepalived | tail -20
# Look for "Entering MASTER STATE" or "Entering BACKUP STATE"
```

### Check Keepalived Status Files
```bash
cat /tmp/keepalived_state_*
# Shows timestamp of last state change
```

## Testing Scenarios

### Test 1: Graceful Failover
```bash
# On Pi #1:
docker stop keepalived
# Wait 10 seconds, VIP should move to Pi #2
# Test DNS: dig google.com @192.168.8.255
# Restart: docker start keepalived
# VIP should return to Pi #1
```

### Test 2: Service Failure
```bash
# On Pi #1:
docker stop pihole_primary
# Keepalived should detect failure and failover
# Test DNS still works via Pi #2
# Restart: docker start pihole_primary
```

### Test 3: Complete Node Failure
```bash
# Power off Pi #1 completely
# Wait 15 seconds
# DNS should continue to work via Pi #2
# Power on Pi #1
# After boot, VIP should return to Pi #1
```

## Troubleshooting

### VIP Not Showing on Any Node
**Cause**: VRRP traffic might be blocked  
**Solution**: Use unicast VRRP (already configured in examples)

### Both Nodes Claim MASTER (Split Brain)
**Cause**: Network partition or misconfiguration  
**Solution**: Verify network connectivity, check virtual_router_id matches

### Sync Not Working
**Cause**: SSH authentication or Gravity Sync misconfiguration  
**Solution**: Test SSH manually, run `sudo gravity-sync config`

### DNS Not Resolving
**Cause**: Container not running or misconfigured  
**Solution**: Check `docker compose ps` and `docker logs`

## Benefits of Multi-Node HA

### For Home Use
- ✅ DNS continues to work during Pi maintenance/updates
- ✅ Protection against SD card failure
- ✅ Protection against power supply failure
- ✅ Peace of mind - no single point of failure

### For Production Use
- ✅ True high availability with automatic failover
- ✅ Zero downtime during maintenance
- ✅ Industry-standard VRRP protocol
- ✅ Comprehensive monitoring and alerting

## Resource Requirements

### Per Node
- **CPU**: 10-20% average
- **RAM**: 1-1.5 GB
- **Disk**: 5-10 GB
- **Network**: Minimal (<1 Mbps)

### Total for 2-Node Setup
- **2x Raspberry Pi 4/5** (4GB+ RAM each)
- **2x Power supplies** (3A USB-C)
- **2x Ethernet cables**
- **1x Network switch** (with multicast support or use unicast)

## Security Considerations

1. **VRRP Password**: Change default password in `.env`
2. **SSH Keys**: Use key-based authentication for sync
3. **Firewall**: Only allow VRRP between the two nodes
4. **Updates**: Keep both nodes updated regularly

## Maintenance

### Regular Tasks
- **Weekly**: Review keepalived logs for unexpected failovers
- **Monthly**: Test failover procedure
- **Monthly**: Update Docker images
- **Quarterly**: Full system backup

### Updates
```bash
# On each node:
cd /opt/rpi-ha-dns-stack
git pull
docker compose pull
docker compose up -d
```

## When to Use Multi-Node vs Single-Node

### Use Single-Node If:
- Home lab or testing environment
- Limited budget (1 Pi instead of 2)
- Don't need hardware redundancy
- Container-level redundancy is sufficient

### Use Multi-Node If:
- Production or critical home network
- Need true high availability
- Want protection against hardware failures
- Have 2 Raspberry Pis available
- Value uptime over complexity

## Next Steps After Deployment

1. ✅ Deploy observability stack (Grafana/Prometheus) on primary node
2. ✅ Configure Signal notifications for failover events
3. ✅ Set up automated backups
4. ✅ Configure router to use VIP as primary DNS
5. ✅ Document your specific network configuration
6. ✅ Schedule regular failover tests

## Support and Feedback

This is a **design exploration document** created to help you understand how to implement multi-node HA. The configurations provided are:

- **Tested architectures** based on industry best practices
- **Production-ready configurations** for Keepalived and VRRP
- **Comprehensive documentation** covering all aspects
- **Step-by-step guides** for deployment and troubleshooting

### Questions to Consider

Before implementing, think about:

1. **Which option?** Simplified (Option A) or Full Redundancy (Option B)?
2. **IP addressing?** What IPs will you use for each component?
3. **Sync frequency?** How often should configurations sync?
4. **Monitoring?** Where to deploy observability stack?
5. **Network?** Unicast or multicast VRRP?

## Files in This Repository

```
.
├── MULTI_NODE_HA_DESIGN.md              # Complete architecture guide
├── MULTI_NODE_DEPLOYMENT_CHECKLIST.md   # Step-by-step checklist
├── MULTI_NODE_QUICKSTART.md             # This file
├── .env.multinode.example               # Configuration template
├── scripts/
│   └── deploy-multinode.sh              # Deployment automation
└── stacks/dns/keepalived/
    ├── keepalived-multinode-primary.conf     # Primary config
    ├── keepalived-multinode-secondary.conf   # Secondary config
    ├── check_dns.sh                          # Health check
    ├── notify_master.sh                      # Master notification
    ├── notify_backup.sh                      # Backup notification
    └── notify_fault.sh                       # Fault notification
```

## Conclusion

This multi-node HA setup provides true hardware-level redundancy for your DNS infrastructure. The documentation and configurations provided give you everything needed to deploy and maintain a production-ready, highly available DNS solution.

**Remember**: This is an exploration of how to implement multi-node HA. Review the design document carefully, adapt it to your network, and test thoroughly before deploying to production.

---

**Status**: Design Exploration Complete  
**Implementation**: Ready for deployment  
**Feedback**: Review design document and provide feedback before implementation
