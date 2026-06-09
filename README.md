# Orion Sentinel DNS HA

**High-availability DNS with Pi-hole + Unbound + Keepalived**

Two-node VRRP failover for ad-blocking, privacy-focused DNS on Raspberry Pi.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Client Devices (DNS queries)                │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
            VIP: 192.168.8.243/24 (eth0)
                  Managed by VRRP
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│   Node A (Pri)   │            │   Node B (Sec)   │
│  192.168.8.244   │◄──────────►│  192.168.8.245   │
│                  │   Unicast  │                  │
│  Priority: 200   │   VRRP     │  Priority: 150   │
│  Role: MASTER    │            │  Role: BACKUP    │
└──────────────────┘            └──────────────────┘
        │                                 │
        ▼                                 ▼
  ┌─────────────┐                  ┌─────────────┐
  │  Pi-hole +  │                  │  Pi-hole +  │
  │  Unbound    │                  │  Unbound    │
  └─────────────┘                  └─────────────┘
```

**Key Components:**

- **Pi-hole + Unbound**: Single container from `ghcr.io/mpgirro/docker-pihole-unbound`
  - Pi-hole for ad/tracker blocking
  - Unbound for local recursive DNS (DNSSEC-validated, privacy-first)
- **Keepalived**: VRRP daemon for automatic VIP failover
- **VIP**: `192.168.8.243/24` floats between nodes on `eth0`
- **Health Checks**: DNS resolution monitored every 5 seconds

---

## Quick Start

> **⚠️ IMPORTANT: Always run `docker compose` from the repository root directory**
>
> Docker Compose looks for `compose.yml` in the current directory. If you see an error like:
> ```
> no configuration file provided: not found
> ```
> You are running the command from the wrong directory. Navigate to the repository root:
> ```bash
> cd /opt/orion-dns-ha  # or wherever you cloned the repo
> pwd  # Should show the repo directory with compose.yml
> ls compose.yml  # Should exist
> ```

### Fastest path — one-command bootstrap

On a fresh Raspberry Pi OS (64-bit), clone and run `bootstrap.sh`. It installs
Docker, scaffolds data dirs, seeds `.env` from the role template, brings up the
stack, and verifies it:

```bash
sudo apt update
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha

# Node A (primary). It stops so you can set secrets in .env, then re-run.
sudo ./bootstrap.sh --role primary
# Node B (secondary):   sudo ./bootstrap.sh --role secondary
# Single node (no HA):  sudo ./bootstrap.sh --role single
# Pin a USB-C/2.5-10G NIC at the same time: add --configure-nic  (see docs/networking.md)
```

The manual steps below are the same flow, broken out, if you prefer to do it by
hand or need to troubleshoot.

### Single-Node Setup

Perfect for testing or simple home use:

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack

# 2. Configure environment
cp .env.example .env
nano .env  # Set WEBPASSWORD and adjust network settings

# 3. Start services
docker compose --profile single-node up -d

# 4. Test DNS
dig @localhost github.com

# 5. Access Pi-hole admin
# Open http://<your-ip>/admin
```

### Two-Node HA Setup

For production high-availability:

#### Step 1: Clone on Both Nodes

On **both** Pi nodes, clone the repository to `/opt/orion-dns-ha`:

```bash
sudo mkdir -p /opt
sudo chown $USER:$USER /opt
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha
```

#### Step 2: Bootstrap Directories

On **both** nodes, run the bootstrap script to create required directories:

```bash
./scripts/bootstrap_dirs.sh
```

This creates:
- `pihole/var-log/` - Directory for Pi-hole logs
- `pihole/var-log/pihole.log` - Log file (as file, not directory)
- `pihole/etc-pihole/` - Pi-hole configuration
- `pihole/etc-dnsmasq.d/` - Dnsmasq configuration

#### Step 3: Configure Node A (Primary)

```bash
cd /opt/orion-dns-ha

# Copy primary template
cp .env.primary.example .env

# Edit configuration
nano .env
```

Set the following in `.env`:
```bash
NODE_NAME=pi1-dns
NODE_IP=192.168.8.244
NODE_ROLE=MASTER
KEEPALIVED_PRIORITY=200
VIP_ADDRESS=192.168.8.243
NETWORK_INTERFACE=eth0
PEER_IP=192.168.8.245
UNICAST_SRC_IP=192.168.8.244
WEBPASSWORD=<your-secure-password>
# CRITICAL: VRRP_PASSWORD must be EXACTLY 8 characters (VRRP PASS auth limitation)
VRRP_PASSWORD=oriondns
LOKI_URL=http://<loki-server>:3100/loki/api/v1/push
```

> **⚠️ IMPORTANT: VRRP_PASSWORD Requirements**
> - Must be **exactly 8 characters** (VRRP PASS authentication limitation)
> - Must be identical on both primary and secondary nodes
> - Container will refuse to start if password is not exactly 8 characters
> - Example valid passwords: `oriondns`, `ha123456`, `secure88`

#### Step 4: Configure Node B (Secondary)

```bash
cd /opt/orion-dns-ha

# Copy secondary template
cp .env.secondary.example .env

# Edit configuration
nano .env
```

Set the following in `.env`:
```bash
NODE_NAME=pi2-dns
NODE_IP=192.168.8.245
NODE_ROLE=BACKUP
KEEPALIVED_PRIORITY=150
VIP_ADDRESS=192.168.8.243
NETWORK_INTERFACE=eth0
PEER_IP=192.168.8.244
UNICAST_SRC_IP=192.168.8.245
WEBPASSWORD=<your-secure-password>
# CRITICAL: Must match primary node password - exactly 8 characters!
VRRP_PASSWORD=oriondns
LOKI_URL=http://<loki-server>:3100/loki/api/v1/push
```

> **📝 Note:** Alternatively, use the new simplified templates:
> - Primary: `cp env/primary.env.example .env`
> - Secondary: `cp env/secondary.env.example .env`
> 
> These templates have the correct IPs pre-configured for a standard setup.
> You only need to change WEBPASSWORD and optionally VRRP_PASSWORD.

#### Step 5: Validate Configuration

On **both** nodes, run the self-check:

```bash
./scripts/selfcheck.sh
```

#### Step 6: Start the Stack

**IMPORTANT:** Always run Docker Compose from `/opt/orion-dns-ha`

On **Node A (Primary)**:

```bash
cd /opt/orion-dns-ha
docker compose --profile two-node-ha-primary up -d

# If using Promtail for logging:
docker compose --profile two-node-ha-primary --profile exporters up -d
```

On **Node B (Secondary)**:

```bash
cd /opt/orion-dns-ha
docker compose --profile two-node-ha-backup up -d

# If using Promtail for logging:
docker compose --profile two-node-ha-backup --profile exporters up -d
```

#### Step 7: Verify HA Configuration

Run the verification script on **both** nodes:

```bash
cd /opt/orion-dns-ha
./scripts/verify-ha.sh
```

This will check:
- ✓ Which node currently holds the VIP
- ✓ Keepalived container status and logs
- ✓ Unicast peer configuration (PEER_IP and UNICAST_SRC_IP)
- ✓ DNS resolution via VIP
- ✓ DNS resolution via node IP

**Expected results:**
- **Primary (MASTER):** Has VIP, state MASTER, DNS works on both VIP and Node IP
- **Secondary (BACKUP):** No VIP, state BACKUP, DNS works on Node IP only

#### Step 8: Verify DNS Resolution

```bash
# Test local DNS
dig github.com @127.0.0.1 +short

# Test via VIP (from any machine on the network)
dig github.com @192.168.8.243 +short
```

#### Step 9: Test Failover

```bash
# From any client:
dig @192.168.8.243 github.com  # Should work

# Stop primary node's containers
# On Node A:
docker stop pihole_unbound keepalived

# Wait ~15 seconds for VIP failover
# On Node B, check VIP was acquired:
ip addr show eth0 | grep 192.168.8.243

# DNS should still work via VIP:
dig @192.168.8.243 github.com  # Still resolves!

# Restart primary:
# On Node A:
docker start pihole_unbound keepalived
```

---

## Troubleshooting HA Issues

### Secondary Node Becomes MASTER When Primary is Healthy

If the secondary node promotes itself to MASTER even when the primary is healthy, this indicates VRRP packets aren't flowing. Follow these steps:

#### 1. Check Unicast Peer Configuration

On **both** nodes, verify unicast peer configuration:

```bash
docker exec -it keepalived sh -c '
echo "=== unicast_peer block ===";
awk "/unicast_peer/{p=1} p{print} p && /}/{exit}" /etc/keepalived/keepalived.conf;
echo;
echo "=== unicast_src_ip ===";
grep unicast_src_ip /etc/keepalived/keepalived.conf
'
```

**Expected:**
- **Primary:** `unicast_src_ip 192.168.8.243` and `unicast_peer { 192.168.8.245 }`
- **Secondary:** `unicast_src_ip 192.168.8.245` and `unicast_peer { 192.168.8.243 }`

If peer IPs are missing or wrong, fix your `.env` file and recreate:
```bash
cd /opt/orion-dns-ha
docker compose --profile two-node-ha-primary up -d --build --force-recreate keepalived
```

#### 2. Verify VRRP Packets Are Flowing

Install tcpdump in the container and check for VRRP packets (protocol 112):

On **primary:**
```bash
docker exec -it keepalived sh -c '
apk add --no-cache tcpdump >/dev/null 2>&1 || true
tcpdump -ni eth0 proto 112 -c 10
'
```

Run the same on **secondary**.

**What to look for:**
- If primary shows packets but secondary shows none → filtering/rp_filter/NIC issue
- If neither shows packets → keepalived isn't sending (wrong peer IP or permissions issue)

#### 3. Fix Script Permission Issues

If you see `Unsafe permissions found for script ... disabling` in logs:

```bash
docker exec -it keepalived sh -c '
ls -l /etc/keepalived/*.sh
chown root:root /etc/keepalived/*.sh 2>/dev/null || true
chmod 700 /etc/keepalived/*.sh 2>/dev/null || true
ls -l /etc/keepalived/*.sh
'
docker restart keepalived
```

**Note:** The updated entrypoint.sh now fixes this automatically on every container start.

#### 4. Check for NIC Flapping (eth0 up/down events)

If you see logs like `Netlink reports eth0 down` or `Interface eth0 deleted`:

```bash
dmesg -T | egrep -i 'eth0|link up|link down|usb|rtl|tg3|r8152|reset' | tail -200
ip link show eth0
```

This indicates NIC driver issues (common with USB 2.5G adapters). Solutions:
- Disable EEE (Energy Efficient Ethernet)
- Disable USB power management
- Check cable and switch quality

#### 5. Validate VRRP_PASSWORD Length

The container now enforces VRRP_PASSWORD to be exactly 8 characters. Check logs:

```bash
docker logs keepalived 2>&1 | grep -A5 "Validating environment"
```

If you see password length errors, update `.env` and recreate:
```bash
VRRP_PASSWORD=oriondns  # Exactly 8 chars
docker compose --profile two-node-ha-primary up -d --force-recreate keepalived
```

---

## Operations

### Using Make Commands

```bash
# Show all available commands
make help

# Start core services (auto-detects single/two-node mode from .env)
make up-core

# Start with monitoring exporters
make up-all

# Stop all services
make down

# View logs
make logs

# Run health check
make health-check

# Create backup
make backup

# Sync Pi-hole config from primary to secondary
make sync  # Run on primary node

# Show deployment info
make info
```

### Pi-hole Configuration Sync (Optional)

Keepalived only manages VIP failover. To synchronize Pi-hole configuration between nodes, use the optional sync script.

**Enable Pi-hole Sync:**

Add to your `.env` file on the **secondary** node:
```bash
PIHOLE_SYNC_ENABLED=true
PRIMARY_NODE_IP=192.168.8.243
SECONDARY_NODE_IP=192.168.8.245
SYNC_GRAVITY_DB=true  # Set to false to skip gravity database
```

**Set up SSH key authentication** (run on secondary node):
```bash
# Generate SSH key if not present
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy to primary node
ssh-copy-id root@192.168.8.243
```

**Manual sync** (run on secondary node):
```bash
cd /opt/orion-dns-ha
./scripts/pihole-sync.sh

# Dry run to see what would be synced
./scripts/pihole-sync.sh --dry-run

# Skip gravity database (faster, only config files)
./scripts/pihole-sync.sh --no-gravity
```

**Automated sync with systemd timer** (run on secondary node):
```bash
# Install systemd service and timer
sudo cp systemd/pihole-sync.service /etc/systemd/system/
sudo cp systemd/pihole-sync.timer /etc/systemd/system/

# Enable and start timer (runs every 6 hours)
sudo systemctl daemon-reload
sudo systemctl enable --now pihole-sync.timer

# Check timer status
sudo systemctl status pihole-sync.timer
sudo systemctl list-timers pihole-sync.timer
```

**What gets synced:**
- Adlists, whitelist, blacklist
- Regex filters
- Custom DNS records
- DHCP configuration (if enabled)
- Gravity database (blocklists, domains)

**Note:** This is a one-way sync from primary → secondary. Changes made on the secondary will be overwritten.

### Backups

Automated daily backups with 7-day retention:

```bash
# Manual backup
./ops/orion-dns-backup.sh

# Or via Make
make backup

# List backups
ls -lh backups/

# Restore from backup
./ops/orion-dns-restore.sh backups/dns-ha-backup-<hostname>-<timestamp>.tgz
```

**What gets backed up:**
- `compose.yml` and `.env` files
- `pihole/etc-pihole/` (gravity, settings)
- `pihole/etc-dnsmasq.d/` (dnsmasq configs)
- `keepalived/config/` (keepalived.conf, scripts)

### Health Monitoring

Automatic health checks with container restart on failures:

```bash
# Manual health check
./ops/orion-dns-health.sh

# Install systemd timer for automated checks (every minute)
make install-systemd-primary  # On primary node
make install-systemd-secondary  # On secondary node

sudo systemctl enable --now orion-dns-ha-health.timer
```

---

## DNS Configuration

### Fully Local DNS (Default)

By default, Unbound performs **fully local recursive DNS resolution**:

- Queries go directly to authoritative DNS servers (root hints)
- No third-party DNS providers involved
- Maximum privacy and control
- DNSSEC validation enabled

### NextDNS for DNS over TLS (Optional)

If you want encrypted DNS forwarding to NextDNS:

1. Edit `unbound/nextdns-forward.conf`
2. Uncomment the `forward-zone` block
3. Replace `<your-id>` with your NextDNS configuration ID
4. Restart: `docker compose restart pihole_unbound`

**Example:**
```conf
server:
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 45.90.28.0@853#abc123.dns.nextdns.io
    forward-addr: 45.90.30.0@853#abc123.dns.nextdns.io
```

To disable and return to local recursion, comment out the `forward-zone` block.

---

## Monitoring Integration

### Exporters Profile

Enable Prometheus exporters and log shipping to Loki/Grafana:

```bash
# Start with exporters
docker compose --profile two-node-ha-primary --profile exporters up -d

# Or via Make
make up-all
```

**Exporters:**
- **Node Exporter** (`:9100`) - System metrics (CPU, memory, disk, network)
- **Pi-hole Exporter** (`:9617`) - DNS query metrics, blocking stats
- **Promtail** (`:9080`) - Ships logs to Loki

**Configuration:**
Set `LOKI_URL` in `.env` to point to your Loki instance (default: `http://192.168.8.245:3100`).

### Prometheus Pushgateway (Optional)

Keepalived state transitions can push metrics to Prometheus Pushgateway:

```bash
# In .env file
PROM_PUSHGATEWAY_URL=http://pushgateway.example.com:9091
PROM_JOB_NAME=orion_dns_ha
PROM_INSTANCE_LABEL=node-primary
```

**Metric:** `keepalived_vrrp_state`
- `1` = MASTER
- `0` = BACKUP
- `-1` = FAULT

---

## Systemd Integration

### Autostart on Boot

**Primary Node:**
```bash
sudo make install-systemd-primary

# Enable services
sudo systemctl enable --now orion-dns-ha-primary.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer
sudo systemctl enable --now orion-dns-ha-sync.timer
```

**Secondary Node:**
```bash
sudo make install-systemd-secondary

# Enable services
sudo systemctl enable --now orion-dns-ha-backup-node.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer
```

### Timers

- **Health Timer**: Runs every minute, auto-restarts containers on DNS failures
- **Backup Timer**: Daily backups at 3 AM with 7-day retention (14 days default)
- **Sync Timer**: Hourly Pi-hole config sync from primary to secondary

---

## Testing and Troubleshooting

### Verify DNS Resolution

```bash
# Test against VIP
dig @192.168.8.243 github.com

# Test against specific node
dig @192.168.8.244 github.com  # Primary
dig @192.168.8.245 github.com  # Secondary
```

### Check VRRP Status

```bash
# View keepalived logs
docker logs keepalived

# Check VIP assignment
ip addr show eth0 | grep 192.168.8.243

# View VRRP state transitions
tail -f /var/log/keepalived-notify.log  # Inside keepalived container
docker exec keepalived tail -f /var/log/keepalived-notify.log
```

### Common Issues

#### No DNS response on VIP

**Symptoms:** `dig @192.168.8.243` times out

**Fixes:**
1. Verify VIP is assigned: `ip addr show eth0`
2. Check `network_mode: host` is set in `compose.yml`
3. Ensure `DNSMASQ_LISTENING=all` in `.env`
4. Verify firewall allows port 53 (UDP/TCP)

#### VIP not assigned

**Symptoms:** VIP doesn't appear on either node

**Fixes:**
1. Verify `NETWORK_INTERFACE=eth0` matches your interface name
2. Check `USE_UNICAST_VRRP=true` is set
3. Verify `PEER_IP` is set on both nodes
4. Ensure `VRRP_PASSWORD` matches on both nodes
5. Check keepalived logs: `docker logs keepalived`

#### Keepalived restart loop

**Symptoms:** keepalived container keeps restarting

**Fixes:**
1. Check keepalived.conf syntax: `docker exec keepalived cat /etc/keepalived/keepalived.conf`
2. Verify no raw `${VAR}` or `\n` literals in config (should be resolved by entrypoint.sh)
3. Check logs: `docker logs keepalived`

#### Failover not working

**Symptoms:** VIP stays on failed primary

**Fixes:**
1. Verify health check script works: `docker exec keepalived /etc/keepalived/check_dns.sh`
2. Check `CHECK_DNS_TARGET=127.0.0.1` is set
3. Verify `CHECK_DNS_FQDN` resolves: `docker exec keepalived dig @127.0.0.1 github.com`
4. Review keepalived logs for health check failures

#### dnsmasq: cannot open log - Is a directory

**Symptoms:** Pi-hole container fails to start with:
```
dnsmasq: cannot open log /var/log/pihole/pihole.log: Is a directory
```

**Cause:** The `pihole.log` was accidentally created as a directory instead of a file.

**Fix:**
```bash
# Remove the directory and recreate as file
rm -rf ./pihole/var-log/pihole.log
touch ./pihole/var-log/pihole.log

# Or run the bootstrap script:
./scripts/bootstrap_dirs.sh

# Restart the container
docker compose restart pihole_unbound
```

**Prevention:** Always run `./scripts/bootstrap_dirs.sh` before first deployment.

#### Promtail "unsupported protocol scheme" error

**Symptoms:** Promtail logs show:
```
level=error msg="error sending batch" error="Post \"\": unsupported protocol scheme \"\""
```

**Cause:** `LOKI_URL` is empty or doesn't include the full path.

**Fix:**
1. Check your `.env` file has `LOKI_URL` set correctly:
   ```bash
   # Correct format (include full path):
   LOKI_URL=http://192.168.8.245:3100/loki/api/v1/push
   
   # Wrong (missing path):
   # LOKI_URL=http://192.168.8.245:3100
   ```

2. Restart promtail:
   ```bash
   docker compose restart promtail
   ```

3. Verify logs are being sent:
   ```bash
   docker logs promtail --tail 50
   ```

---

## Documentation

Canonical docs (single source of truth):

- **[docs/architecture.md](docs/architecture.md)** - Components, profiles, data flow
- **[docs/networking.md](docs/networking.md)** - The one canonical IP/VRRP scheme
- **[docs/troubleshooting.md](docs/troubleshooting.md)** - Common failures + fixes
- **[docs/disaster-recovery.md](docs/disaster-recovery.md)** - Backup/restore, <1h rebuild
- **[docs/upgrade-guide.md](docs/upgrade-guide.md)** - Rolling, zero-downtime upgrades
- **[docs/AUDIT.md](docs/AUDIT.md)** - Architecture audit (A–J) and target design

Operational references:

- **[ops/README.md](ops/README.md)** - Operational scripts
- **[systemd/README.md](systemd/README.md)** - Systemd integration

---

## Requirements

**Hardware:**
- Raspberry Pi 4/5 (4GB+ RAM recommended)
- 32GB+ SD card or USB SSD
- Ethernet connection (recommended for VRRP)

**Software:**
- Docker 20.10+
- Docker Compose V2 (plugin format)
- Linux kernel with VRRP support

**Network:**
- Two available IPs for nodes (e.g., 192.168.8.244, 192.168.8.245)
- One VIP for DNS service (e.g., 192.168.8.243)
- Multicast or unicast VRRP capability (unicast recommended)

---

## License

This project is open source. See the repository for license details.

---

## Contributing

Contributions welcome! Please open an issue or pull request.

**Project Goals:**
- Simplicity and reliability over complexity
- Privacy-first DNS (local recursion by default)
- Production-ready high availability
- Easy to deploy and maintain

---

**Ready to start?** See [INSTALL.md](INSTALL.md) for detailed installation instructions.
