# Multi-Node High Availability DNS Setup - Design Document

## Executive Summary

This document explores how to implement a true High Availability (HA) DNS solution using **two physical Raspberry Pi nodes** instead of the current single-node setup with redundant containers. The goal is to provide resilience against hardware failures, not just container failures.

## Current vs. Proposed Architecture

### Current Architecture (Single Node HA)
```
┌─────────────────────────────────────────────────────────────┐
│  Raspberry Pi #1 (192.168.8.250)                            │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ Pi-hole      │  │ Pi-hole      │                         │
│  │ Primary      │  │ Secondary    │                         │
│  │ .251         │  │ .252         │                         │
│  └──────┬───────┘  └──────┬───────┘                         │
│         │                  │                                 │
│  ┌──────▼───────┐  ┌──────▼───────┐                         │
│  │ Unbound      │  │ Unbound      │                         │
│  │ Primary      │  │ Secondary    │                         │
│  │ .253         │  │ .254         │                         │
│  └──────────────┘  └──────────────┘                         │
│         │                  │                                 │
│  ┌──────▼──────────────────▼───────┐                        │
│  │   Keepalived (Local Only)       │                        │
│  │   VIP: 192.168.8.255            │                        │
│  └─────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘

❌ Problem: Single point of failure at hardware level
   (If Pi #1 fails, entire DNS infrastructure is down)
```

### Proposed Architecture (Multi-Node HA)

#### Option A: Simplified Design (RECOMMENDED)
```
┌───────────────────────────────────┐  ┌───────────────────────────────────┐
│  Raspberry Pi #1 (Primary Node)   │  │  Raspberry Pi #2 (Secondary Node) │
│  Host IP: 192.168.8.11             │  │  Host IP: 192.168.8.12            │
│                                    │  │                                   │
│  ┌──────────────┐                  │  │  ┌──────────────┐                 │
│  │ Pi-hole      │                  │  │  │ Pi-hole      │                 │
│  │ Primary      │◄─────Gravity─────┼──┼──┤ Secondary    │                 │
│  │ .251         │      Sync        │  │  │ .252         │                 │
│  └──────┬───────┘                  │  │  └──────┬───────┘                 │
│         │                           │  │         │                        │
│  ┌──────▼───────┐                  │  │  ┌──────▼───────┐                 │
│  │ Unbound      │                  │  │  │ Unbound      │                 │
│  │ Primary      │◄────Rsync/Git────┼──┼──┤ Secondary    │                 │
│  │ .253         │     (config)     │  │  │ .254         │                 │
│  └──────────────┘                  │  │  └──────────────┘                 │
│                                    │  │                                   │
│  ┌──────────────┐                  │  │  ┌──────────────┐                 │
│  │ Keepalived   │◄─────VRRP────────┼──┼──┤ Keepalived   │                 │
│  │ MASTER       │   (Priority 100) │  │  │ BACKUP       │                 │
│  │              │                  │  │  │ (Priority 90)│                 │
│  └──────┬───────┘                  │  │  └──────┬───────┘                 │
│         │                           │  │         │                        │
│         └───────────────────────────┼──┼─────────┘                        │
│                   ▼                 │  │                                  │
│        VIP: 192.168.8.255           │  │   (Floats between nodes)         │
└───────────────────────────────────┘  └───────────────────────────────────┘

✅ Benefit: Hardware-level redundancy
   (If Pi #1 fails, Pi #2 takes over the VIP automatically)
```

#### Option B: Full Redundancy Design (Advanced)
```
┌───────────────────────────────────┐  ┌───────────────────────────────────┐
│  Raspberry Pi #1 (Primary Node)   │  │  Raspberry Pi #2 (Secondary Node) │
│  Host IP: 192.168.8.11             │  │  Host IP: 192.168.8.12            │
│                                    │  │                                   │
│  ┌──────────┐  ┌──────────┐        │  │  ┌──────────┐  ┌──────────┐      │
│  │ Pi-hole  │  │ Pi-hole  │        │  │  │ Pi-hole  │  │ Pi-hole  │      │
│  │ P-A      │  │ P-B      │◄───────┼──┼──┤ S-A      │  │ S-B      │      │
│  │ .251     │  │ .252     │  Sync  │  │  │ .253     │  │ .254     │      │
│  └────┬─────┘  └────┬─────┘        │  │  └────┬─────┘  └────┬─────┘      │
│       │             │               │  │       │             │            │
│  ┌────▼─────┐  ┌────▼─────┐        │  │  ┌────▼─────┐  ┌────▼─────┐      │
│  │ Unbound  │  │ Unbound  │        │  │  │ Unbound  │  │ Unbound  │      │
│  │ P-A      │  │ P-B      │        │  │  │ S-A      │  │ S-B      │      │
│  └──────────┘  └──────────┘        │  │  └──────────┘  └──────────┘      │
│                                    │  │                                   │
│  ┌──────────────┐                  │  │  ┌──────────────┐                 │
│  │ Keepalived   │◄─────VRRP────────┼──┼──┤ Keepalived   │                 │
│  │ MASTER       │                  │  │  │ BACKUP       │                 │
│  └──────┬───────┘                  │  │  └──────┬───────┘                 │
│         │                           │  │         │                        │
│         └───────────────────────────┼──┼─────────┘                        │
│                   ▼                 │  │                                  │
│        VIP: 192.168.8.255           │  │                                  │
└───────────────────────────────────┘  └───────────────────────────────────┘

⚠️  More complex but provides container-level redundancy on each node
```

## Architecture Comparison

| Feature | Current (Single Node) | Option A (Simplified) | Option B (Full) |
|---------|----------------------|----------------------|-----------------|
| **Hardware Resilience** | ❌ None | ✅ Full | ✅ Full |
| **Container Resilience** | ✅ Yes (2 per type) | ⚠️  Partial (1 per node) | ✅ Full (2 per node) |
| **Complexity** | Low | Medium | High |
| **Resource Usage** | 1 Pi | 2 Pis | 2 Pis (heavy) |
| **Failover Time** | <5 seconds | <10 seconds | <10 seconds |
| **Configuration Sync** | Local only | Network-based | Complex |
| **Management** | Simple | Moderate | Complex |
| **Recommended For** | Lab/Home | Production | Mission Critical |

## Detailed Design: Option A (Recommended)

### Network Configuration

#### IP Address Allocation
```
Network: 192.168.8.0/24
Gateway: 192.168.8.1

Physical Nodes:
├── Pi #1 (Primary):   192.168.8.11  (eth0)
└── Pi #2 (Secondary): 192.168.8.12  (eth0)

DNS Services:
├── Pi-hole Primary:   192.168.8.251 (on Pi #1)
├── Pi-hole Secondary: 192.168.8.252 (on Pi #2)
├── Unbound Primary:   192.168.8.253 (on Pi #1)
├── Unbound Secondary: 192.168.8.254 (on Pi #2)
└── Virtual IP (VIP):  192.168.8.255 (floats between Pi #1 and Pi #2)

Observability (Optional):
└── Grafana/Prometheus: On Pi #1 (192.168.8.11:3000, 9090)
```

#### Why This Works Better

**Current Setup Problem:**
- All IPs (.251-.255) are on ONE physical host
- If that host dies, all services are gone
- Keepalived only provides local container failover

**Multi-Node Solution:**
- Each Pi hosts different services
- VIP floats between physical nodes via VRRP
- If Pi #1 fails, Pi #2 takes over the VIP
- Clients always use VIP (192.168.8.255) - seamless failover

### Keepalived Configuration

#### On Pi #1 (Primary Node - MASTER)
```bash
# /opt/rpi-ha-dns-stack/stacks/dns/keepalived/keepalived.conf
global_defs {
    router_id DNS_HA_PRIMARY
    enable_script_security
    script_user root
    vrrp_garp_master_refresh 60
    vrrp_garp_master_repeat 3
}

# Health check script for local Pi-hole
vrrp_script check_pihole {
    script "/usr/local/bin/check_dns.sh"
    interval 5
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_DNS {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100              # Higher priority = MASTER
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }
    
    virtual_ipaddress {
        192.168.8.255/24 dev eth0
    }
    
    # Optional: Use unicast for more reliable VRRP
    unicast_src_ip 192.168.8.11
    unicast_peer {
        192.168.8.12
    }
    
    track_script {
        check_pihole
    }
    
    # Notify scripts (optional)
    notify_master "/usr/local/bin/notify_master.sh"
    notify_backup "/usr/local/bin/notify_backup.sh"
    notify_fault  "/usr/local/bin/notify_fault.sh"
}
```

#### On Pi #2 (Secondary Node - BACKUP)
```bash
# /opt/rpi-ha-dns-stack/stacks/dns/keepalived/keepalived.conf
global_defs {
    router_id DNS_HA_SECONDARY
    enable_script_security
    script_user root
    vrrp_garp_master_refresh 60
    vrrp_garp_master_repeat 3
}

vrrp_script check_pihole {
    script "/usr/local/bin/check_dns.sh"
    interval 5
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_DNS {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90               # Lower priority = BACKUP
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }
    
    virtual_ipaddress {
        192.168.8.255/24 dev eth0
    }
    
    unicast_src_ip 192.168.8.12
    unicast_peer {
        192.168.8.11
    }
    
    track_script {
        check_pihole
    }
    
    notify_master "/usr/local/bin/notify_master.sh"
    notify_backup "/usr/local/bin/notify_backup.sh"
    notify_fault  "/usr/local/bin/notify_fault.sh"
}
```

### Health Check Script
```bash
#!/bin/bash
# /usr/local/bin/check_dns.sh
# Check if local Pi-hole is responding

LOCAL_PIHOLE="127.0.0.1"
TEST_DOMAIN="google.com"

# Test DNS resolution
if dig @${LOCAL_PIHOLE} ${TEST_DOMAIN} +time=2 +tries=1 > /dev/null 2>&1; then
    exit 0  # Success - Pi-hole is healthy
else
    exit 1  # Failure - trigger failover
fi
```

### Data Synchronization

#### Option 1: Gravity Sync (Recommended for Pi-hole)
Gravity Sync is the official tool for synchronizing Pi-hole configurations between instances.

**Setup on Primary (Pi #1):**
```bash
# Install Gravity Sync
curl -sSL https://raw.githubusercontent.com/vmstan/gravity-sync/master/gs-install.sh | bash

# Configure for push mode
sudo gravity-sync config
# Set:
# - Remote host: 192.168.8.12
# - Remote user: pi (or your SSH user)
# - SSH key authentication

# Run initial sync
sudo gravity-sync push

# Set up automated sync (cron)
sudo gravity-sync auto
```

**What Gravity Sync Handles:**
- ✅ Gravity database (blocklists)
- ✅ Custom DNS records
- ✅ Adlists
- ✅ Whitelists/Blacklists
- ✅ Regex filters
- ✅ Group management
- ✅ Client groups

#### Option 2: Custom Sync Script (Alternative)
```bash
#!/bin/bash
# /usr/local/bin/sync-pihole-to-secondary.sh

PRIMARY_IP="192.168.8.11"
SECONDARY_IP="192.168.8.12"
SSH_USER="pi"

# Sync Pi-hole configuration
ssh ${SSH_USER}@${SECONDARY_IP} "docker exec pihole_secondary pihole -g"

# Sync gravity database
docker exec pihole_primary cat /etc/pihole/gravity.db | \
  ssh ${SSH_USER}@${SECONDARY_IP} "docker exec -i pihole_secondary cat > /etc/pihole/gravity.db"

# Reload secondary
ssh ${SSH_USER}@${SECONDARY_IP} "docker exec pihole_secondary pihole restartdns reload-lists"
```

#### Unbound Configuration Sync
```bash
#!/bin/bash
# /usr/local/bin/sync-unbound-to-secondary.sh

PRIMARY_IP="192.168.8.11"
SECONDARY_IP="192.168.8.12"
SSH_USER="pi"

# Sync unbound config
rsync -avz --delete \
  /opt/rpi-ha-dns-stack/stacks/dns/unbound1/ \
  ${SSH_USER}@${SECONDARY_IP}:/opt/rpi-ha-dns-stack/stacks/dns/unbound2/

# Restart unbound on secondary
ssh ${SSH_USER}@${SECONDARY_IP} "docker exec unbound_secondary kill -HUP 1"
```

### Docker Compose Configuration

#### Pi #1 (Primary Node) - docker-compose.yml
```yaml
services:
  pihole_primary:
    image: pihole/pihole:latest
    container_name: pihole_primary
    hostname: pihole-primary
    environment:
      - TZ=${TZ:-Europe/London}
      - WEBPASSWORD=${PIHOLE_PASSWORD}
      - PIHOLE_DNS_=192.168.8.253#5335
    networks:
      dns_net:
        ipv4_address: 192.168.8.251
    restart: unless-stopped
    volumes:
      - ./pihole1/etc-pihole:/etc/pihole
      - ./pihole1/etc-dnsmasq.d:/etc/dnsmasq.d

  unbound_primary:
    image: mvance/unbound-rpi:latest
    container_name: unbound_primary
    hostname: unbound-primary
    networks:
      dns_net:
        ipv4_address: 192.168.8.253
    restart: unless-stopped
    volumes:
      - ./unbound1:/opt/unbound/etc/unbound

  keepalived:
    build: ./keepalived
    container_name: keepalived
    hostname: keepalived-primary
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_BROADCAST
      - NET_RAW
    volumes:
      - ./keepalived:/etc/keepalived:ro
    environment:
      - NODE_ROLE=MASTER
      - NODE_PRIORITY=100
      - PEER_IP=192.168.8.12
    restart: unless-stopped

networks:
  dns_net:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.8.0/24
          gateway: 192.168.8.1
```

#### Pi #2 (Secondary Node) - docker-compose.yml
```yaml
services:
  pihole_secondary:
    image: pihole/pihole:latest
    container_name: pihole_secondary
    hostname: pihole-secondary
    environment:
      - TZ=${TZ:-Europe/London}
      - WEBPASSWORD=${PIHOLE_PASSWORD}
      - PIHOLE_DNS_=192.168.8.254#5335
    networks:
      dns_net:
        ipv4_address: 192.168.8.252
    restart: unless-stopped
    volumes:
      - ./pihole2/etc-pihole:/etc/pihole
      - ./pihole2/etc-dnsmasq.d:/etc/dnsmasq.d

  unbound_secondary:
    image: mvance/unbound-rpi:latest
    container_name: unbound_secondary
    hostname: unbound-secondary
    networks:
      dns_net:
        ipv4_address: 192.168.8.254
    restart: unless-stopped
    volumes:
      - ./unbound2:/opt/unbound/etc/unbound

  keepalived:
    build: ./keepalived
    container_name: keepalived
    hostname: keepalived-secondary
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_BROADCAST
      - NET_RAW
    volumes:
      - ./keepalived:/etc/keepalived:ro
    environment:
      - NODE_ROLE=BACKUP
      - NODE_PRIORITY=90
      - PEER_IP=192.168.8.11
    restart: unless-stopped

networks:
  dns_net:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.8.0/24
          gateway: 192.168.8.1
```

## Deployment Strategy

### Prerequisites

1. **Both Raspberry Pis must:**
   - Have static IP addresses (192.168.8.11 and 192.168.8.12)
   - Have Docker and Docker Compose installed
   - Be on the same network segment
   - Have SSH access between them (for sync)

2. **Network Requirements:**
   - VRRP multicast (IP protocol 112) must be allowed
   - Or use unicast VRRP (recommended for managed switches)
   - No IP conflicts in the .250-.255 range

### Step-by-Step Deployment

#### Step 1: Prepare Both Nodes
```bash
# On both Pi #1 and Pi #2:

# Set static IP (edit /etc/dhcpcd.conf)
# Pi #1: 192.168.8.11
# Pi #2: 192.168.8.12

# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git rsync

# Clone repository
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd rpi-ha-dns-stack
```

#### Step 2: Configure SSH Keys (for sync)
```bash
# On Pi #1, generate SSH key and copy to Pi #2
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id pi@192.168.8.12

# Test connection
ssh pi@192.168.8.12 "echo 'SSH works'"
```

#### Step 3: Configure Environment
```bash
# On Pi #1:
cp .env.example .env
nano .env

# Set:
# NODE_ROLE=primary
# NODE_IP=192.168.8.11
# PEER_IP=192.168.8.12
# VIP_ADDRESS=192.168.8.255

# On Pi #2:
cp .env.example .env
nano .env

# Set:
# NODE_ROLE=secondary
# NODE_IP=192.168.8.12
# PEER_IP=192.168.8.11
# VIP_ADDRESS=192.168.8.255
```

#### Step 4: Create Networks
```bash
# On both Pi #1 and Pi #2:
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net
```

#### Step 5: Deploy Services
```bash
# On Pi #1:
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d pihole_primary unbound_primary keepalived

# Wait 30 seconds for initialization

# On Pi #2:
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d pihole_secondary unbound_secondary keepalived
```

#### Step 6: Verify Automatic Sync

This deployment uses Pi-hole v6's built-in sync capabilities instead of Gravity Sync (which doesn't support v6).

Synchronization happens automatically via the pihole-sync.sh containers that are deployed as part of the stack. The sync configuration is handled automatically:

```bash
# On Pi #1, check sync container status
docker ps | grep pihole-sync

# View sync logs
docker logs pihole-sync

# The sync container automatically:
# - Monitors Pi-hole configuration changes
# - Syncs gravity database, custom lists, and settings
# - Maintains consistency between primary and secondary nodes
```

**Testing Sync:**
```bash
# On Pi #1:
# 1. Add a domain to the blocklist via Pi-hole web interface
# 2. Wait a few moments for automatic sync
# 3. Check Pi #2's web interface to verify the domain appears

# You can also manually trigger sync by restarting the sync container:
docker restart pihole-sync
```

### Verification

#### Check VIP Assignment
```bash
# On Pi #1 (should show VIP on eth0)
ip addr show eth0 | grep 192.168.8.255

# On Pi #2 (should NOT show VIP)
ip addr show eth0 | grep 192.168.8.255
```

#### Check Keepalived Status
```bash
# On both nodes:
docker logs keepalived | tail -20

# Should show:
# Pi #1: "Entering MASTER STATE"
# Pi #2: "Entering BACKUP STATE"
```

#### Test DNS Resolution
```bash
# From another device on your network:
dig google.com @192.168.8.255
dig google.com @192.168.8.251
dig google.com @192.168.8.252

# All should resolve successfully
```

#### Test Failover
```bash
# On Pi #1, stop keepalived:
docker stop keepalived

# Wait 5-10 seconds

# Check VIP on Pi #2 (should now have the VIP)
ssh pi@192.168.8.12 "ip addr show eth0 | grep 192.168.8.255"

# Test DNS still works:
dig google.com @192.168.8.255

# Restart keepalived on Pi #1:
docker start keepalived

# VIP should failback to Pi #1 after ~10 seconds
```

## Monitoring and Alerting

### Keepalived State Changes
```bash
# Notify script: /usr/local/bin/notify_master.sh
#!/bin/bash
TYPE=$1
NAME=$2
STATE=$3

MESSAGE="Keepalived: ${NAME} entered ${STATE} state on $(hostname)"

# Send to Signal/Telegram/Email
curl -X POST http://192.168.8.11:8080/alert \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"${MESSAGE}\"}"
```

### Prometheus Metrics
```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'keepalived'
    static_configs:
      - targets:
        - '192.168.8.11:9650'
        - '192.168.8.12:9650'
    labels:
      cluster: 'dns-ha'
```

## Troubleshooting

### Common Issues

#### 1. VIP Not Appearing
**Symptoms:** VIP doesn't show on any node
**Causes:**
- VRRP traffic blocked by firewall
- Network doesn't support multicast
- Configuration mismatch

**Solutions:**
```bash
# Check if VRRP packets are being sent
tcpdump -i eth0 -nn vrrp

# Use unicast instead of multicast (edit keepalived.conf)
# Add unicast_src_ip and unicast_peer sections

# Check firewall
sudo iptables -L -n | grep 112
```

#### 2. Split Brain (Both Nodes Claim MASTER)
**Symptoms:** VIP appears on both nodes
**Causes:**
- Network partition
- VRRP packets not reaching peer

**Solutions:**
```bash
# Check network connectivity
ping 192.168.8.12  # From Pi #1
ping 192.168.8.11  # From Pi #2

# Verify VRRP traffic
tcpdump -i eth0 -nn vrrp

# Check keepalived logs
docker logs keepalived
```

#### 3. Sync Failing
**Symptoms:** Changes on primary don't appear on secondary
**Causes:**
- SSH authentication failure
- Gravity Sync misconfigured
- Network connectivity

**Solutions:**
```bash
# Test SSH
ssh pi@192.168.8.12

# Run manual sync
sudo gravity-sync push -f

# Check sync logs
sudo gravity-sync log
```

## Performance Considerations

### Resource Usage per Node
- **CPU:** 10-20% average (Pi 4/5)
- **RAM:** 1-1.5GB per node
- **Disk:** 5-10GB per node
- **Network:** Minimal (<1Mbps for VRRP + sync)

### Tuning Tips
1. **Sync Frequency:** Adjust based on change rate (default: 1 hour)
2. **Health Check Interval:** Balance between fast detection and overhead
3. **VRRP Timers:** Decrease for faster failover, increase for stability

## Security Considerations

1. **VRRP Authentication:** Always use a strong password
2. **SSH Keys:** Use SSH keys for sync, disable password auth
3. **Firewall Rules:** Only allow VRRP between the two nodes
4. **Network Isolation:** Consider VLAN for DNS infrastructure

## Conclusion

### Recommendation: Option A (Simplified)

**Why?**
- ✅ True hardware redundancy
- ✅ Moderate complexity
- ✅ Good resource usage
- ✅ Easy to manage
- ✅ Proven design pattern

**When to Use Option B (Full):**
- Mission-critical environments
- Very high query volumes
- When you need container-level redundancy per node
- Have resources to spare (2x the hardware)

### Next Steps

1. Review this design document
2. Decide on Option A or B
3. Prepare both Raspberry Pi nodes
4. Follow deployment steps
5. Test failover scenarios
6. Monitor and tune

### Questions to Consider

1. **Which option fits your needs?** A (simpler) or B (more resilient)?
2. **What's your acceptable failover time?** (5-10 seconds typical)
3. **How often do you change Pi-hole configs?** (affects sync frequency)
4. **Do you need observability on both nodes?** (or just primary?)
5. **What's your network setup?** (managed switch, VLAN, firewall rules?)

---

**Document Status:** Draft for Review  
**Last Updated:** 2024  
**Feedback:** Please provide feedback on this design before implementation
