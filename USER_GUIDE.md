# User Guide 📖

## Table of Contents
1. [Getting Started](#getting-started)
2. [Daily Operations](#daily-operations)
3. [Dashboard Overview](#dashboard-overview)
4. [Managing DNS](#managing-dns)
5. [Monitoring & Alerts](#monitoring--alerts)
6. [Backup & Restore](#backup--restore)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Usage](#advanced-usage)
9. [FAQ](#faq)

---

## Getting Started

### What You Have

Your DNS stack provides:
- **Ad Blocking**: Blocks ads, trackers, and malware across all devices
- **Privacy**: DNS queries encrypted, no ISP snooping
- **Reliability**: Automatic failover if any service fails
- **Security**: DNSSEC validation prevents DNS spoofing
- **Monitoring**: Real-time statistics and alerts
- **Self-Healing**: Automatic recovery from failures

### Quick Access Links

| Service | URL | Purpose |
|---------|-----|---------|
| **Main Dashboard** | http://192.168.8.250/dashboard.html | Overview of all services |
| **Pi-hole Admin** | http://192.168.8.251/admin | DNS settings, blocklists |
| **Grafana Dashboards** | http://192.168.8.250:3000 | Detailed metrics & graphs |
| **Traffic Analytics** | http://192.168.8.250:3001 | DNS query analysis |

### First-Time Setup Checklist

- [ ] Change default passwords (Pi-hole, Grafana)
- [ ] Configure router to use DNS servers (192.168.8.255)
- [ ] Add custom blocklists (optional)
- [ ] Whitelist important domains (optional)
- [ ] Set up Signal notifications (optional)
- [ ] Test DNS resolution from devices
- [ ] Bookmark dashboard URLs

---

## Daily Operations

### Checking System Health

#### Quick Health Check (30 seconds)
1. Open **Main Dashboard**: http://192.168.8.250/dashboard.html
2. Check "Overview" tab:
   - ✅ All services should show "Healthy" (green)
   - ✅ DNS queries counter should be increasing
   - ✅ Block percentage should be 15-30% (typical)

#### Detailed Health Check (5 minutes)
```bash
# SSH into Raspberry Pi
ssh user@192.168.8.226

# Run automated health check
cd /opt/rpi-ha-dns-stack
bash scripts/health-check.sh
```

### What to Monitor Daily

| Metric | Normal Range | Action if Outside Range |
|--------|--------------|-------------------------|
| **Block Rate** | 15-35% | <10% = Update blocklists, >50% = Check for issues |
| **Query Volume** | Varies by network | Sudden drop = Check connectivity |
| **Container Health** | All "healthy" | Any unhealthy = Check logs |
| **Disk Space** | <80% used | >80% = Clean up logs/backups |

### Common Tasks

#### Add Domain to Whitelist
1. Go to http://192.168.8.251/admin
2. Login with Pi-hole password
3. Navigate to: **Whitelist** → **Exact Whitelist**
4. Enter domain (e.g., `example.com`)
5. Click **Add to Whitelist**
6. Wait 5 minutes for sync to secondary

#### Add Domain to Blacklist
1. Go to http://192.168.8.251/admin
2. Login
3. Navigate to: **Blacklist** → **Exact Blacklist**
4. Enter domain
5. Click **Add to Blacklist**
6. Automatically syncs to secondary

#### Add Blocklist
1. Go to http://192.168.8.251/admin
2. Login
3. Navigate to: **Adlists**
4. Paste blocklist URL
5. Click **Add**
6. Go to **Tools** → **Update Gravity**
7. Click **Update**

**Popular Blocklists**:
- Hagezi Pro++ (already installed): https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt
- OISD Big (already installed): https://big.oisd.nl/domainswild
- Hagezi Threat Intelligence (already installed): https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/threat-intelligence.txt
- StevenBlack (optional): https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

#### View Query Log
1. Go to http://192.168.8.251/admin
2. Navigate to: **Query Log**
3. See real-time DNS queries
4. Filter by:
   - Client
   - Domain
   - Query type
   - Status (allowed/blocked)

#### Flush DNS Cache
```bash
# From Raspberry Pi
docker restart pihole_primary pihole_secondary

# Or from Pi-hole web UI
# Tools → Clear Logs → Clear DNS Cache
```

---

## Blocklist Profiles & Customization

### Pre-configured Blocklist Profiles

Orion Sentinel DNS HA comes with three curated blocklist profiles that can be selected during setup:

| Profile | Use Case | Domains | Memory | Trade-off |
|---------|----------|---------|--------|-----------|
| **Standard** | General home/office | ~4-5M | ~200MB | Best balance of blocking vs compatibility |
| **Family** | Families with children | ~5-6M | ~250MB | More filtering, occasional false positives |
| **Paranoid** | Privacy-focused users | ~7-8M | ~350MB | Maximum blocking, may break some sites |

### Default Blocklists (Standard Profile)

These high-quality, well-maintained lists are installed by default:

| List | Purpose | Domains |
|------|---------|---------|
| **Hagezi Pro++** | Ads, tracking, malware, phishing | ~3M |
| **OISD Big** | Balanced blocking, low false positives | ~1.9M |
| **Hagezi Threat Intelligence** | Malware, C&C servers, threat intel | ~500K |

### Family Profile Additions

Adds to standard profile:
- **Hagezi Multi**: Additional family-safe filtering (~1M domains)

### Paranoid Profile Additions

Adds to family profile:
- **Hagezi Ultimate**: Maximum coverage blocking (~2M domains)

### Setting Your Profile

**During initial setup:**
```bash
# Standard (default)
bash stacks/dns/setup-pihole.sh

# Family
PIHOLE_BLOCKLIST_PROFILE=family bash stacks/dns/setup-pihole.sh

# Paranoid
PIHOLE_BLOCKLIST_PROFILE=paranoid bash stacks/dns/setup-pihole.sh
```

**Via environment variable:**
Add to your `.env` file:
```bash
PIHOLE_BLOCKLIST_PROFILE=standard  # or family, paranoid
```

### Pre-configured Whitelist

To prevent common streaming service issues, these domains are automatically whitelisted:

**Disney+**: `disneyplus.com`, `disney-plus.net`, `disneystreaming.com`, `bamgrid.com`, `dssott.com`

**Netflix**: `netflix.com`, `nflxvideo.net`, `nflximg.net`, `nflxext.com`

**Amazon Prime**: `amazon.com`, `amazonvideo.com`, `aiv-cdn.net`

**Others**: Hulu, HBO Max, Apple TV+, Spotify, YouTube (basic)

### Adding Custom Whitelists

If a service isn't working, check the Pi-hole query log and whitelist the blocked domain:

```bash
# Whitelist a domain
docker exec pihole_primary pihole -w example.com

# Whitelist multiple domains
docker exec pihole_primary pihole -w plex.tv plex.direct
```

### Verification Steps

After setup, verify your blocklist configuration:

```bash
# 1. Check Pi-hole status
docker exec pihole_primary pihole status

# 2. Verify domain count (look for "Domains being blocked")
docker exec pihole_primary pihole -c -e

# 3. Test DNS resolution (should return an IP)
dig @192.168.8.251 google.com +short

# 4. Test ad blocking (should return 0.0.0.0 or NXDOMAIN)
dig @192.168.8.251 ads.google.com +short

# 5. Test streaming (should return valid IPs)
dig @192.168.8.251 disneyplus.com +short
dig @192.168.8.251 netflix.com +short
```

### Performance Considerations

| Metric | Standard | Family | Paranoid |
|--------|----------|--------|----------|
| Query response | < 50ms | < 50ms | < 50ms |
| Gravity update | ~2 min | ~3 min | ~4 min |
| Memory per instance | ~200MB | ~250MB | ~350MB |
| CPU usage | < 5% | < 5% | < 5% |

**Notes:**
- Gravity updates run automatically daily at 3 AM
- Larger blocklists require more memory but don't affect query performance
- The paranoid profile may require more whitelisting for daily use

---

## Dashboard Overview

### Main Dashboard (http://192.168.8.250/dashboard.html)

#### Overview Tab
- **System Health**: Status of all DNS services
- **Container Status**: Real-time container health
- **DNS Metrics**: 24h queries, blocks, percentage
- **Network Info**: IP addresses, network configuration
- **Sync Status**: Primary/secondary sync status

#### Services Tab
Quick links to:
- Pi-hole Primary & Secondary
- Grafana, Prometheus, Alertmanager
- Loki (log aggregation)
- Signal services
- AI Watchdog

#### Monitoring Tab
- **Query Statistics**: Detailed query breakdown
- **Performance Metrics**: Response times, cache hits
- **Links to Grafana**: Pre-configured dashboards

#### Configuration Tab
- **Active Blocklists**: Lists and domain counts
- **Whitelisted Domains**: Disney+, streaming services
- **DNS Resolution Flow**: How queries are processed
- **Config Locations**: Where files are stored
- **Quick Commands**: Common maintenance tasks

#### Testing Tab
- **DNS Leak Test**: https://dnsleaktest.com
- **IP Leak Test**: https://ipleak.net
- **Privacy Test**: https://www.deviceinfo.me
- **Browser Check**: https://browserleaks.com/dns

---

## Managing DNS

### Understanding DNS Flow

```
Device → Router → Keepalived VIP (192.168.8.255)
                      ↓
                 Pi-hole Primary (192.168.8.251)
                      ↓
                 Check Blocklist
                      ↓
              Blocked? → Return 0.0.0.0
              Allowed? ↓
                 Unbound (192.168.8.253)
                      ↓
                 DNSSEC Validation
                      ↓
              Valid? → Forward via DoH (encrypted)
              Invalid? → Return SERVFAIL
                      ↓
                 Return IP to Device
```

### DNS Configuration Locations

| Component | Config Location |
|-----------|----------------|
| **Pi-hole Primary** | `/opt/rpi-ha-dns-stack/stacks/dns/pihole1/` |
| **Pi-hole Secondary** | `/opt/rpi-ha-dns-stack/stacks/dns/pihole2/` |
| **Unbound Primary** | `/opt/rpi-ha-dns-stack/stacks/dns/unbound1/unbound.conf` |
| **Unbound Secondary** | `/opt/rpi-ha-dns-stack/stacks/dns/unbound2/unbound.conf` |
| **Keepalived** | `/opt/rpi-ha-dns-stack/stacks/dns/keepalived/` |

### Custom DNS Records

#### Add Local DNS Entry
1. Go to http://192.168.8.251/admin
2. Navigate to: **Local DNS** → **DNS Records**
3. Enter:
   - **Domain**: `myserver.local`
   - **IP Address**: `192.168.8.100`
4. Click **Add**
5. Now `myserver.local` resolves to `192.168.8.100`

#### Add CNAME Record
1. Same location as DNS Records
2. Navigate to: **CNAME Records**
3. Enter:
   - **Domain**: `www.myserver.local`
   - **Target**: `myserver.local`
4. Click **Add**

### Performance Tuning

#### Optimize Cache Settings
Edit `/opt/rpi-ha-dns-stack/stacks/dns/unbound1/unbound.conf`:

```yaml
# Increase cache sizes (if you have enough RAM)
msg-cache-size: 100m  # Default: 50m
rrset-cache-size: 200m  # Default: 100m

# Adjust TTL
cache-min-ttl: 7200  # Minimum cache time (seconds)
cache-max-ttl: 86400  # Maximum cache time
```

Restart unbound:
```bash
docker restart unbound_primary unbound_secondary
```

#### Add More Threads (if CPU allows)
```yaml
# In unbound.conf
num-threads: 4  # Default: 2 (use CPU core count)
```

---

## Monitoring & Alerts

### Grafana Dashboards

#### Access Grafana
1. Go to http://192.168.8.250:3000
2. Login: `admin` / (your password from .env)
3. Navigate to: **Dashboards** → **Browse**

#### Pre-Configured Dashboards
1. **DNS Performance**: Query latency, cache hits, response times
2. **Self-Healing**: Container restarts, network recreations
3. **System Health**: CPU, memory, disk usage per container
4. **Traffic Analytics**: Query patterns, top domains, clients

#### Create Custom Dashboard
1. Click **+** → **Dashboard**
2. Add **Panel**
3. Choose **Data Source**: Prometheus
4. Enter query (e.g., `rate(pihole_queries_total[5m])`)
5. Click **Apply**

### Prometheus Queries (Useful)

```promql
# DNS queries per second
rate(pihole_queries_total[5m])

# Block percentage
(pihole_blocked_total / pihole_queries_total) * 100

# Container restarts
self_healing_container_restarts_total

# DNS response time (95th percentile)
histogram_quantile(0.95, dns_response_seconds_bucket)

# Failed DNSSEC validations
increase(unbound_dnssec_failures_total[1h])
```

### Setting Up Alerts

#### Alertmanager Configuration
Edit `/opt/rpi-ha-dns-stack/stacks/observability/alertmanager/config.yml`:

```yaml
route:
  receiver: 'signal-notifications'
  
receivers:
  - name: 'signal-notifications'
    webhook_configs:
      - url: 'http://signal-webhook:8080/alert'
```

#### Create Alert Rules
Edit `/opt/rpi-ha-dns-stack/stacks/observability/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: dns_alerts
    rules:
      - alert: HighBlockRate
        expr: (pihole_blocked_total / pihole_queries_total) > 0.5
        for: 10m
        annotations:
          summary: "DNS block rate unusually high"
          
      - alert: DNSServerDown
        expr: up{job="pihole"} == 0
        for: 5m
        annotations:
          summary: "Pi-hole server is down"
```

Reload Prometheus:
```bash
curl -X POST http://192.168.8.250:9090/-/reload
```

---

## Backup & Restore

### Automated Backups

Backups run automatically every day at 2 AM. They include:
- Pi-hole configuration and databases
- Prometheus metrics data
- Grafana dashboards and settings

#### Check Backup Status
```bash
# View backup logs
docker logs backup

# List backups
ls -lh /opt/rpi-ha-dns-stack/stacks/backup/backups/

# Check disk space
df -h | grep backups
```

### Manual Backup

#### Backup Pi-hole
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker exec pihole_primary pihole -a -t
# Saves to /opt/rpi-ha-dns-stack/stacks/dns/pihole1/pihole-backup.tar.gz
```

#### Backup All Services
```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
docker compose run --rm backup bash -c "cd /app && python backup.py"
```

### Restore from Backup

#### Restore Pi-hole
```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
bash restore-backup.sh

# Follow prompts to select:
# 1. Service to restore (pihole/prometheus/grafana)
# 2. Backup date
# 3. Confirm restoration
```

#### Manual Restore
```bash
# Stop Pi-hole
docker stop pihole_primary

# Restore backup
tar -xzf pihole-backup-2025-11-15.tar.gz -C /opt/rpi-ha-dns-stack/stacks/dns/pihole1/

# Restart Pi-hole
docker start pihole_primary
```

### Backup to External Storage (Recommended)

#### Set Up Remote Backup
Edit `/opt/rpi-ha-dns-stack/stacks/backup/.env`:

```bash
# Add remote backup location
BACKUP_REMOTE_PATH=/mnt/nas/dns-backups
```

Or use `rsync`:
```bash
# Add to crontab
crontab -e

# Sync backups daily
0 3 * * * rsync -avz /opt/rpi-ha-dns-stack/stacks/backup/backups/ user@nas:/backups/dns/
```

---

## Troubleshooting

### DNS Not Working

#### Step 1: Check Service Status
```bash
cd /opt/rpi-ha-dns-stack
bash scripts/health-check.sh
```

#### Step 2: Test Each Component
```bash
# Test Pi-hole
dig @192.168.8.251 google.com

# Test Unbound
dig @192.168.8.253 google.com

# Test VIP
dig @192.168.8.255 google.com
```

#### Step 3: Check Logs
```bash
# Pi-hole logs
docker logs pihole_primary --tail 50

# Unbound logs
docker logs unbound_primary --tail 50

# Keepalived logs
docker logs keepalived --tail 50
```

#### Step 4: Restart Services
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose restart
```

### Slow DNS Queries

#### Diagnose Performance
```bash
# Time a query
time dig @192.168.8.255 google.com

# Should be < 100ms
```

#### Solutions
1. **Clear DNS cache**:
   ```bash
   docker restart pihole_primary pihole_secondary
   ```

2. **Check upstream**:
   ```bash
   # Test unbound directly
   dig @192.168.8.253 google.com
   ```

3. **Optimize unbound** (see Performance Tuning section)

4. **Check network**:
   ```bash
   ping -c 10 192.168.8.251
   # Should have <5ms latency, 0% packet loss
   ```

### Container Keeps Restarting

#### Check Logs
```bash
docker logs <container_name> --tail 100
```

#### Common Causes
1. **Out of Memory**: Check `docker stats`
2. **Port Conflict**: Check if port is already in use
3. **Configuration Error**: Validate config files
4. **Missing Dependencies**: Rebuild image

#### Solution
```bash
# Rebuild and restart
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose down
docker compose build
docker compose up -d
```

### High CPU/Memory Usage

#### Check Resource Usage
```bash
# Overall system
htop

# Per container
docker stats

# Disk usage
df -h
du -sh /opt/rpi-ha-dns-stack/*
```

#### Solutions
1. **Reduce analytics retention**:
   ```bash
   # Edit .env
   RETENTION_DAYS=30  # Reduce from 90
   ```

2. **Disable unused features**:
   ```bash
   # Stop analytics if not needed
   cd /opt/rpi-ha-dns-stack/stacks/traffic-analytics
   docker compose down
   ```

3. **Clean up Docker**:
   ```bash
   docker system prune -a
   docker volume prune
   ```

---

## Advanced Usage

### Custom Blocklist Categories

#### Create Category-Based Blocking
1. Create custom lists in Pi-hole:
   - **Social Media**: Facebook, Twitter, Instagram domains
   - **Streaming**: Netflix, YouTube (use cautiously)
   - **Gaming**: Game update servers (breaks games!)
   - **Adult Content**: Adult websites

2. Use **Group Management** in Pi-hole:
   - Assign devices to groups
   - Apply different blocklists per group
   - Example: Kids' devices get stricter blocking

### Integration with Home Assistant

#### Expose DNS Metrics
Pi-hole API is available at:
```
http://192.168.8.251/admin/api.php?summary
```

#### Home Assistant Configuration
```yaml
sensor:
  - platform: rest
    resource: http://192.168.8.251/admin/api.php?summary
    name: DNS Queries Today
    value_template: '{{ value_json.dns_queries_today }}'
    
  - platform: rest
    resource: http://192.168.8.251/admin/api.php?summary
    name: Ads Blocked Today
    value_template: '{{ value_json.ads_blocked_today }}'
```

### VPN Integration

#### Use DNS Stack with VPN
If running VPN on Raspberry Pi:
1. Configure VPN to use local DNS: `192.168.8.255`
2. Add DNS leak protection in VPN config
3. Test with https://dnsleaktest.com

### API Access

#### Pi-hole API
```bash
# Get statistics
curl http://192.168.8.251/admin/api.php?summary

# Top domains
curl http://192.168.8.251/admin/api.php?topItems=10

# Query log
curl http://192.168.8.251/admin/api.php?getAllQueries
```

#### Prometheus API
```bash
# Query metrics
curl 'http://192.168.8.250:9090/api/v1/query?query=pihole_queries_total'

# Query range
curl 'http://192.168.8.250:9090/api/v1/query_range?query=rate(pihole_queries_total[5m])&start=2025-11-15T00:00:00Z&end=2025-11-15T23:59:59Z&step=15m'
```

---

## FAQ

### General Questions

**Q: Can I access Pi-hole from the Raspberry Pi host?**
A: No, this is a limitation of macvlan networks. Access from another device on your network.

**Q: Will this work with Wi-Fi?**
A: Ethernet is recommended. Wi-Fi can work but may have stability issues.

**Q: How many devices can this handle?**
A: Raspberry Pi 5 with 8GB RAM can handle 50-100 devices easily. Query volume matters more than device count.

**Q: Does this slow down my internet?**
A: No, DNS resolution adds <50ms typically. Blocking ads actually speeds up page loads.

**Q: Can I use this as my only DNS server?**
A: Yes, with failover to cloud DNS (8.8.8.8) as backup. Configure in multi-region failover.

### Blocking Questions

**Q: Why isn't a domain being blocked?**
A: Check:
1. Is it in your blocklists?
2. Is it whitelisted?
3. Did you update gravity recently?
4. Try exact match instead of wildcard

**Q: I blocked a domain but it still loads**
A: Some sites use multiple domains. Use Pi-hole query log to find all domains and block them.

**Q: Can I block YouTube ads?**
A: Mostly no. YouTube serves ads from same domains as videos. Use browser extensions instead.

### Technical Questions

**Q: What's the difference between Pi-hole and Unbound?**
A: Pi-hole blocks ads/trackers. Unbound is recursive DNS for privacy (doesn't forward to ISP).

**Q: Do I need DNSSEC?**
A: Yes (already enabled). Prevents DNS spoofing/poisoning attacks.

**Q: Should I use DoH or unbound?**
A: Use both! Unbound for recursion, DoH for encryption. Self-hosted DoH is best for privacy.

**Q: How often are blocklists updated?**
A: Daily at 3 AM automatically (configurable in Pi-hole settings).

### Maintenance Questions

**Q: How much disk space do I need?**
A: 10-20GB for logs/analytics. More with longer retention periods.

**Q: Do I need to update manually?**
A: No, containers auto-update on restart. Manually: `docker compose pull && docker compose up -d`

**Q: How do I backup my configuration?**
A: Automatic daily backups at 2 AM. Manual: see Backup section.

**Q: Can I run this 24/7?**
A: Yes, designed for 24/7 operation. Self-healing handles failures automatically.

---

## Getting Help

### Documentation
- **Installation Guide**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Advanced Features**: [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md)
- **Security Guide**: [SECURITY_GUIDE.md](SECURITY_GUIDE.md)
- **Getting Started**: [GETTING_STARTED.md](GETTING_STARTED.md)

### Support Channels
- **GitHub Issues**: https://github.com/orionsentinel/Orion-DNS_Stack/issues
- **Pi-hole Forum**: https://discourse.pi-hole.net/
- **Docker Forums**: https://forums.docker.com/

### Useful Commands Reference

```bash
# Health check
bash /opt/rpi-ha-dns-stack/scripts/health-check.sh

# View logs
docker logs <container_name> --tail 100 -f

# Restart all services
cd /opt/rpi-ha-dns-stack/stacks/dns && docker compose restart

# Update containers
docker compose pull && docker compose up -d

# Check disk space
df -h

# Check memory
free -h

# Clean Docker
docker system prune -a

# Backup manually
cd /opt/rpi-ha-dns-stack/stacks/backup && docker compose run backup

# Test DNS
dig @192.168.8.255 google.com
```

---

## Quick Reference Card

Print this for easy reference:

```
╔════════════════════════════════════════════════════════════╗
║          RPi HA DNS Stack - Quick Reference                ║
╠════════════════════════════════════════════════════════════╣
║ Dashboard:     http://192.168.8.250/dashboard.html        ║
║ Pi-hole:       http://192.168.8.251/admin                 ║
║ Grafana:       http://192.168.8.250:3000                  ║
║                                                            ║
║ DNS Servers:   192.168.8.255 (VIP - use this)            ║
║                192.168.8.251 (Primary)                    ║
║                192.168.8.252 (Secondary)                  ║
║                                                            ║
║ SSH:           ssh user@192.168.8.226                     ║
║                                                            ║
║ Health Check:  bash scripts/health-check.sh               ║
║ View Logs:     docker logs pihole_primary                 ║
║ Restart:       docker compose restart                     ║
║                                                            ║
║ Support:       github.com/orionsentinel/Orion-DNS_Stack║
╚════════════════════════════════════════════════════════════╝
```

---

**Enjoy your ad-free, privacy-focused internet! 🎉**
