# Production-Ready 2-Pi DNS HA Architecture

## 🎯 Overview

This deployment provides a **production-ready, hardware-redundant DNS infrastructure** using two Raspberry Pis with automatic VIP failover. It implements best practices for high availability DNS with:

- **Pi #1 (Primary)**: Pi-hole + Unbound + Keepalived (MASTER)
- **Pi #2 (Secondary)**: Pi-hole + Unbound + Keepalived (BACKUP)
- **Virtual IP (VIP)**: Floats automatically between nodes

```
┌─────────────────────────────────────┐    ┌─────────────────────────────────────┐
│  Raspberry Pi #1 (PRIMARY)          │    │  Raspberry Pi #2 (SECONDARY)        │
│  IP: 192.168.8.11                   │    │  IP: 192.168.8.12                   │
│  ┌───────────────────────────────┐  │    │  ┌───────────────────────────────┐  │
│  │         Docker Host           │  │    │  │         Docker Host           │  │
│  │  ┌─────────────────────────┐  │  │    │  │  ┌─────────────────────────┐  │  │
│  │  │      Pi-hole Primary    │  │  │    │  │  │    Pi-hole Secondary    │  │  │
│  │  │      192.168.8.251      │  │  │    │  │  │      192.168.8.252      │  │  │
│  │  └───────────┬─────────────┘  │  │    │  │  └───────────┬─────────────┘  │  │
│  │              │                 │  │    │  │              │                 │  │
│  │  ┌───────────▼─────────────┐  │  │    │  │  ┌───────────▼─────────────┐  │  │
│  │  │    Unbound Primary      │  │  │    │  │  │   Unbound Secondary     │  │  │
│  │  │    192.168.8.253        │  │  │    │  │  │    192.168.8.254        │  │  │
│  │  │    (DNSSEC enabled)     │  │  │    │  │  │    (DNSSEC enabled)     │  │  │
│  │  └─────────────────────────┘  │  │    │  │  └─────────────────────────┘  │  │
│  │                                │  │    │  │                                │  │
│  │  ┌─────────────────────────┐  │  │    │  │  ┌─────────────────────────┐  │  │
│  │  │     Keepalived          │  │  │    │  │  │     Keepalived          │  │  │
│  │  │     State: MASTER       │◄─┼──┼────┼──┼─►│     State: BACKUP       │  │  │
│  │  │     Priority: 100       │  │  │    │  │  │     Priority: 90        │  │  │
│  │  └─────────────────────────┘  │  │    │  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │    │  └───────────────────────────────┘  │
└──────────────────┬──────────────────┘    └──────────────────┬──────────────────┘
                   │                                          │
                   └──────────────────┬───────────────────────┘
                                      │
                            ┌─────────▼─────────┐
                            │   VIP (Floating)  │
                            │  192.168.8.255    │
                            │                   │
                            │  Moves to healthy │
                            │  node on failover │
                            └───────────────────┘
```

## ✅ Features

### High Availability
- **Hardware-level redundancy**: Survives complete node failure
- **Automatic VIP failover**: < 5 seconds failover time
- **Health-based failover**: DNS health checks trigger failover
- **Preemption control**: Configurable failback behavior

### DNS Features
- **Pi-hole**: Network-wide ad blocking
- **Unbound**: Recursive DNS with DNSSEC validation
- **Privacy**: No third-party DNS forwarding
- **Performance**: Aggressive caching and prefetching

### Production-Ready
- **Self-healing**: Automatic container restart on failure
- **Automated backups**: Daily configuration backups
- **Pi-hole sync**: Configuration synchronization between nodes
- **Alerting**: Webhook and Signal notifications
- **Prometheus integration**: Metrics for monitoring

## 📋 Prerequisites

### Hardware
- **2x Raspberry Pi 4/5** (4GB+ RAM recommended)
- **2x MicroSD cards** (32GB+ Class 10)
- **2x Ethernet cables** (Wi-Fi not recommended for HA)
- **2x Quality power supplies** (official RPi PSU recommended)
- **Network switch** with available ports

### Software
- **Raspberry Pi OS** (64-bit, Lite or Full)
- **Docker** 24.0+
- **Docker Compose** v2.20+

### Network
- **2 static IP addresses** for the Pis
- **1 unused IP address** for the VIP
- All IPs on the same subnet
- VIP should be outside DHCP range

### Example Network Configuration
| Device | IP Address | Role |
|--------|------------|------|
| Pi #1 | 192.168.8.11 | Primary (MASTER) |
| Pi #2 | 192.168.8.12 | Secondary (BACKUP) |
| VIP | 192.168.8.255 | Floating DNS IP |
| Pi-hole Primary | 192.168.8.251 | Service IP |
| Pi-hole Secondary | 192.168.8.252 | Service IP |
| Unbound Primary | 192.168.8.253 | Service IP |
| Unbound Secondary | 192.168.8.254 | Service IP |

## 🚀 Deployment

### Step 1: Prepare Both Nodes

On **both Pi #1 and Pi #2**:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Clone repository
cd /opt
sudo git clone https://github.com/your-org/Orion-DNS_Stack.git
sudo chown -R $USER:$USER Orion-DNS_Stack
cd Orion-DNS_Stack/deployments/Production_2Pi_HA

# Logout and login for Docker group to take effect
```

### Step 2: Configure SSH Keys (for Pi-hole sync)

On **Pi #1**:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy to Pi #2
ssh-copy-id pi@192.168.8.12

# Test connection
ssh pi@192.168.8.12 "echo 'SSH connection successful'"
```

### Step 3: Configure Environment

#### On Pi #1 (Primary):

```bash
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node1
cp .env.example .env

# Generate secure passwords
PIHOLE_PASS=$(openssl rand -base64 32)
VRRP_PASS=$(openssl rand -base64 20)

echo "Pi-hole Password: $PIHOLE_PASS"
echo "VRRP Password: $VRRP_PASS"

# Edit .env with your values
nano .env
```

Key settings for Pi #1:
```bash
NODE_ROLE=primary
NODE_IP=192.168.8.11
PEER_IP=192.168.8.12
KEEPALIVED_PRIORITY=100
PIHOLE_PASSWORD=<your-secure-password>
VRRP_PASSWORD=<your-vrrp-password>
```

#### On Pi #2 (Secondary):

```bash
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node2
cp .env.example .env
nano .env
```

Key settings for Pi #2 (**must match Pi #1 for passwords**):
```bash
NODE_ROLE=secondary
NODE_IP=192.168.8.12
PEER_IP=192.168.8.11
KEEPALIVED_PRIORITY=90
PIHOLE_PASSWORD=<same-as-pi1>
VRRP_PASSWORD=<same-as-pi1>
```

### Step 4: Deploy Services

#### On Pi #1 (deploy first):

```bash
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node1
docker compose up -d

# Watch logs
docker compose logs -f
```

#### On Pi #2 (deploy second):

```bash
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node2
docker compose up -d

# Watch logs
docker compose logs -f
```

### Step 5: Verify Deployment

#### Check VIP Assignment

On **Pi #1**:
```bash
ip addr show eth0 | grep 192.168.8.255
# Should show: inet 192.168.8.255/24 scope global secondary eth0:vip
```

On **Pi #2**:
```bash
ip addr show eth0 | grep 192.168.8.255
# Should NOT show VIP (Pi #1 has it)
```

#### Check Keepalived Status

```bash
# On Pi #1
docker logs keepalived 2>&1 | grep -i state
# Should show: Entering MASTER STATE

# On Pi #2
docker logs keepalived 2>&1 | grep -i state
# Should show: Entering BACKUP STATE
```

#### Test DNS Resolution

From any device on your network:
```bash
# Test via VIP (production endpoint)
dig google.com @192.168.8.255

# Test each Pi-hole directly
dig google.com @192.168.8.251  # Primary
dig google.com @192.168.8.252  # Secondary
```

### Step 6: Configure Router DNS

1. Log into your router's admin interface
2. Find DNS/DHCP settings
3. Set **Primary DNS**: `192.168.8.255` (the VIP)
4. Set **Secondary DNS**: `192.168.8.255` (same VIP - failover is automatic)
5. Save and reboot router

## 🔄 Failover Testing

### Test 1: Manual Failover

```bash
# On Pi #1, stop keepalived
docker stop keepalived

# Wait 5 seconds, check Pi #2
ssh pi@192.168.8.12 "ip addr show eth0 | grep 192.168.8.255"
# VIP should now be on Pi #2

# Verify DNS still works
dig google.com @192.168.8.255

# Restart keepalived on Pi #1
docker start keepalived
# VIP returns to Pi #1 after ~30 seconds (preempt_delay)
```

### Test 2: Full Node Failure

```bash
# Simulate Pi #1 failure by stopping all containers
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node1
docker compose down

# VIP should move to Pi #2 within 5 seconds
# DNS continues via VIP

# Recover Pi #1
docker compose up -d
```

## 📊 Monitoring

### Access Points

| Service | URL | Description |
|---------|-----|-------------|
| Pi-hole Primary | http://192.168.8.251/admin | Primary Pi-hole dashboard |
| Pi-hole Secondary | http://192.168.8.252/admin | Secondary Pi-hole dashboard |
| Pi-hole via VIP | http://192.168.8.255/admin | Auto-routes to active node |

### Health Check Files

Each node creates status files:
```bash
cat /tmp/keepalived/state
# Shows current state, VIP, timestamps
```

### Log Locations

```bash
# Keepalived logs
docker logs keepalived

# Pi-hole logs
docker logs pihole_primary  # or pihole_secondary

# Self-healing logs
docker logs self-healing
```

## 🔧 Maintenance

### Rolling Updates (Zero Downtime)

```bash
# Update Pi #2 first (BACKUP)
ssh pi@192.168.8.12
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node2
docker compose pull
docker compose up -d
# Wait for services to stabilize (2 minutes)

# Update Pi #1 (MASTER)
# VIP will briefly move to Pi #2 during restart
cd /opt/Orion-DNS_Stack/deployments/Production_2Pi_HA/node1
docker compose pull
docker compose up -d
# VIP returns after ~30 seconds
```

### Backup Locations

```bash
# Backups are stored in:
./backups/
# Automatic daily backups with 30-day retention
```

### Manual Sync

```bash
# Force sync from primary to secondary
docker exec pihole-sync /sync.sh
```

## 🐛 Troubleshooting

### VIP Not Appearing

```bash
# Check VRRP traffic
sudo tcpdump -i eth0 -nn vrrp

# Verify keepalived config
docker exec keepalived cat /etc/keepalived/keepalived.conf

# Check for split-brain
# On both nodes, only ONE should have VIP
ip addr show eth0 | grep 192.168.8.255
```

### Both Nodes Show MASTER (Split Brain)

1. Check network connectivity: `ping 192.168.8.12`
2. Verify VRRP password matches on both nodes
3. Check virtual_router_id matches
4. Ensure unicast peer IPs are correct

### DNS Not Resolving

```bash
# Check Pi-hole container
docker logs pihole_primary

# Check Unbound container
docker logs unbound_primary

# Test DNS directly
docker exec pihole_primary dig google.com @127.0.0.1
```

### Health Check Failing

```bash
# Run health check manually
docker exec keepalived /etc/keepalived/check_dns.sh
echo $?  # 0 = healthy, 1 = unhealthy

# Check what's failing
docker exec keepalived cat /tmp/keepalived_health_status
```

## 📁 File Structure

```
Production_2Pi_HA/
├── README.md                    # This file
├── node1/                       # Primary node configuration
│   ├── docker-compose.yml       # Service definitions
│   ├── .env.example             # Environment template
│   ├── keepalived/              # Keepalived configuration
│   │   ├── Dockerfile           # Keepalived container
│   │   ├── keepalived.conf      # VRRP configuration
│   │   ├── check_dns.sh         # Health check script
│   │   ├── notify_master.sh     # MASTER notification
│   │   ├── notify_backup.sh     # BACKUP notification
│   │   └── notify_fault.sh      # FAULT notification
│   └── unbound/                 # Unbound configuration
│       └── unbound.conf         # Recursive DNS settings
└── node2/                       # Secondary node configuration
    ├── docker-compose.yml
    ├── .env.example
    ├── keepalived/
    │   └── ... (same structure as node1)
    └── unbound/
        └── unbound.conf
```

## 🔒 Security Considerations

1. **Use strong passwords**: Generate with `openssl rand -base64 32`
2. **Keep VRRP password secret**: Same password needed on both nodes
3. **Restrict VIP access**: Only allow trusted networks
4. **Regular updates**: Keep Docker images and host OS updated
5. **Backup encryption**: Consider encrypting backup files
6. **SSH key authentication**: Disable password SSH

## 📚 Additional Resources

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Keepalived Documentation](https://www.keepalived.org/manpage.html)
- [Main Repository Documentation](../../README.md)

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs: `docker compose logs`
3. Open an issue on GitHub
4. Consult the main repository documentation
