# Single Pane of Glass (SPoG) Integration Guide

**Centralized Observability for Orion Sentinel on Dell CoreSrv**

---

## 📖 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Dell CoreSrv Setup](#dell-coresrv-setup)
- [Pi DNS Node Setup](#pi-dns-node-setup)
- [NetSec Pi Node Setup](#netsec-pi-node-setup)
- [Traefik Reverse Proxy Configuration](#traefik-reverse-proxy-configuration)
- [Verification & Testing](#verification--testing)
- [Grafana Dashboards](#grafana-dashboards)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Overview

The **Single Pane of Glass (SPoG)** architecture centralizes all observability, monitoring, and management for your Orion Sentinel deployment on a Dell server (CoreSrv). This provides:

✅ **Unified observability** - All logs and metrics in one place  
✅ **Centralized SSO** - Single sign-on with Authelia and 2FA  
✅ **Reverse proxy** - Traefik routes all services through `*.local` domains  
✅ **Simplified management** - One Grafana instance for everything  
✅ **Better performance** - Offload monitoring from Raspberry Pis  

### What Gets Centralized

```
┌─────────────────────────────────────────────────────────────┐
│                    Dell CoreSrv (SPoG)                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Core Services                      │  │
│  │                                                       │  │
│  │  • Traefik        - Reverse proxy & routing          │  │
│  │  • Authelia       - SSO, 2FA, session management     │  │
│  │  • Homepage       - Service dashboard                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Observability Stack                     │  │
│  │                                                       │  │
│  │  • Loki           - Log aggregation & storage        │  │
│  │  • Promtail       - Log collector (Dell only)        │  │
│  │  • Prometheus     - Metrics collection              │  │
│  │  • Grafana        - Dashboards & visualization       │  │
│  │  • Uptime Kuma    - Service monitoring               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                Remote Agents                         │  │
│  │                                                       │  │
│  │  Receives logs from:                                 │  │
│  │  • Pi DNS (Promtail) → Port 3100                     │  │
│  │  • NetSec Pi (Promtail) → Port 3100                  │  │
│  │  • Prometheus Node Exporters → Port 9100             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

       ▲                                    ▲
       │ Logs (:3100)                       │ Logs (:3100)
       │ Metrics (:9100)                    │ Metrics (:9100)
       │                                    │
┌──────┴──────────┐              ┌─────────┴────────────┐
│  Pi DNS Node    │              │  NetSec Pi Node      │
│                 │              │                      │
│  • Promtail     │              │  • Promtail          │
│  • Node Exp.    │              │  • Node Exp.         │
│  • Pi-hole      │              │  • Suricata          │
│  • Unbound      │              │  • AI Service        │
│  • Keepalived   │              │  • Threat Intel      │
└─────────────────┘              └──────────────────────┘
```

---

## Architecture

### Network Flow

```
User Device
    │
    │ HTTPS (443)
    ▼
https://grafana.local ──┐
https://dns.local       │
https://security.local  ├──► Dell Traefik (:443)
https://auth.local      │         │
    ...               ──┘         │
                                  ▼
                           Authelia (SSO/2FA)
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
               Grafana       Pi DNS UI    NetSec UI
            (Dell local)  (Proxy to Pi)  (Proxy to Pi)
                    │
                    ▼
                  Loki (:3100)
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
  Pi DNS Logs            NetSec Logs
  (via Promtail)        (via Promtail)
```

### Service URLs

After setup, access all services via `*.local` domains:

| Service | URL | Description |
|---------|-----|-------------|
| Authelia | `https://auth.local` | SSO login page |
| Traefik | `https://traefik.local` | Reverse proxy dashboard |
| Grafana | `https://grafana.local` | Unified observability dashboards |
| Prometheus | `https://prometheus.local` | Metrics explorer |
| Uptime Kuma | `https://uptime.local` | Service monitoring |
| Homepage | `https://home.local` | Service dashboard |
| Pi DNS | `https://dns.local` | Pi-hole admin UI (proxied) |
| NetSec | `https://security.local` | NetSec web UI (proxied) |

---

## Prerequisites

### Dell CoreSrv Requirements

- **OS**: Ubuntu/Debian Linux (20.04+ recommended)
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 100GB+ for logs and metrics storage
- **Docker**: 20.10+ with Docker Compose
- **Network**: Static IP on same LAN as Pis (e.g., 192.168.8.100)

### Pi Requirements

Both Pi DNS and NetSec Pi need:

- **Connectivity**: Same LAN as Dell or VPN/Tailscale
- **Docker**: 20.10+ with Docker Compose
- **Firewall**: Allow outbound to Dell port 3100 (Loki)

### Network Requirements

- **DNS**: Router/Pi-hole configured with `*.local` A-records pointing to Dell IP
- **Firewall**: 
  - Allow Pis → Dell port 3100 (Loki)
  - Allow LAN → Dell port 443 (Traefik HTTPS)
  - Allow LAN → Dell port 9100 (Prometheus Node Exporter on Pis)

---

## Dell CoreSrv Setup

### Step 1: Clone CoreSrv Repository

```bash
# Clone the Orion-Sentinel-CoreSrv repository
git clone https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

### Step 2: Configure Environment

```bash
# Copy example environment files
cp env/.env.core.example env/.env.core
cp env/.env.monitoring.example env/.env.monitoring
cp env/.env.media.example env/.env.media  # Optional

# Edit environment files
nano env/.env.core
```

Required settings in `env/.env.core`:

```bash
# Dell CoreSrv IP
HOST_IP=192.168.8.100

# Authelia secrets (generate with: openssl rand -base64 32)
AUTHELIA_JWT_SECRET=<generate-random-32-bytes>
AUTHELIA_SESSION_SECRET=<generate-random-32-bytes>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generate-random-32-bytes>

# User credentials
AUTHELIA_DEFAULT_USER=admin
AUTHELIA_DEFAULT_PASSWORD=<strong-password>
```

Required settings in `env/.env.monitoring`:

```bash
# Monitoring root directory
MONITORING_ROOT=/opt/monitoring

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<strong-password>

# Prometheus retention
PROMETHEUS_RETENTION=30d

# Pi DNS node IP for scraping
PI_DNS_IP=192.168.8.251

# NetSec Pi node IP for scraping
PI_NETSEC_IP=192.168.8.252
```

### Step 3: Start Core Services

```bash
# Start Traefik and Authelia first
./orionctl.sh up-core

# Verify
docker ps | grep -E 'traefik|authelia'
```

Test:
- `https://auth.local` → Authelia login page
- `https://traefik.local` → Traefik dashboard (behind Authelia)

### Step 4: Start Observability Stack

```bash
# Start Loki, Prometheus, Grafana
./orionctl.sh up-observability

# Verify
docker ps | grep -E 'loki|prometheus|grafana'
```

Test:
- `https://grafana.local` → Grafana login
- `https://prometheus.local` → Prometheus UI

### Step 5: Configure Loki Port for Remote Agents

Edit `monitoring/loki/docker-compose.yml` to expose port 3100:

```yaml
services:
  loki:
    ports:
      - "3100:3100"  # Expose for remote Promtail agents
```

Restart Loki:

```bash
docker compose -f monitoring/loki/docker-compose.yml up -d
```

### Step 6: Configure Firewall

```bash
# Allow Loki port from Pi network
sudo ufw allow from 192.168.8.0/24 to any port 3100 proto tcp

# Allow HTTPS from LAN
sudo ufw allow from 192.168.8.0/24 to any port 443 proto tcp

# Allow Prometheus Node Exporter scraping from Dell
# (This is for Dell to scrape Pis, not Pis to Dell)
# Configure on Pis: sudo ufw allow from 192.168.8.100 to any port 9100 proto tcp

# Verify
sudo ufw status
```

---

## Pi DNS Node Setup

### Step 1: Deploy Promtail Agent

```bash
cd /path/to/Orion-DNS_Stack/stacks/agents/pi-dns

# Copy example config
cp promtail-config.example.yml promtail-config.yml

# Edit config - update Dell IP
nano promtail-config.yml
```

Update Loki URL in `promtail-config.yml`:

```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push  # Dell CoreSrv IP
```

Deploy:

```bash
# Set environment variable (optional)
export LOKI_URL=http://192.168.8.100:3100

# Start agent
docker compose up -d

# Verify
docker logs pi-dns-agent
```

### Step 2: Deploy Node Exporter (for metrics)

```bash
cd /path/to/Orion-DNS_Stack/stacks/monitoring

# If not already running, start Node Exporter
docker compose -f docker-compose.exporters.yml up -d node-exporter

# Verify
curl http://localhost:9100/metrics
```

Configure firewall to allow Dell to scrape:

```bash
# Allow Dell to scrape metrics
sudo ufw allow from 192.168.8.100 to any port 9100 proto tcp
```

### Step 3: Verify Logs are Shipping

Check Promtail metrics:

```bash
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
```

Should show entries > 0.

On Dell, query Loki:

```bash
# On Dell CoreSrv
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={host="pi-dns"}' | jq
```

Should return log entries from Pi DNS.

---

## NetSec Pi Node Setup

**Note**: The NetSec Pi configuration assumes you have the `Orion-sentinel-netsec-ai` repository deployed.

### Step 1: Deploy Promtail Agent

```bash
# On NetSec Pi
cd /path/to/Orion-sentinel-netsec-ai/agents/pi-netsec
# OR if using configs from DNS repo:
cd /path/to/Orion-DNS_Stack/stacks/agents/pi-netsec

# Copy example config
cp promtail-config.example.yml promtail-config.yml

# Edit config - update Dell IP
nano promtail-config.yml
```

Update Loki URL:

```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push  # Dell CoreSrv IP
```

Deploy:

```bash
export LOKI_URL=http://192.168.8.100:3100
docker compose up -d

# Verify
docker logs pi-netsec-agent
```

### Step 2: Deploy Node Exporter

```bash
# If not already running
docker run -d --name node-exporter \
  --restart=unless-stopped \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host

# Verify
curl http://localhost:9100/metrics
```

Configure firewall:

```bash
sudo ufw allow from 192.168.8.100 to any port 9100 proto tcp
```

### Step 3: Disable Local Observability (Optional)

If NetSec Pi was running its own Loki/Grafana, you can disable it:

```bash
cd /path/to/Orion-sentinel-netsec-ai

# Edit .env
nano .env
```

Set:

```bash
LOCAL_OBSERVABILITY=false
LOKI_URL=http://192.168.8.100:3100
```

Stop local observability stack:

```bash
./scripts/netsecctl.sh down-observability
# OR manually:
cd stacks/nsm
docker compose -f docker-compose.local-observability.yml down
```

---

## Traefik Reverse Proxy Configuration

### Configure DNS & Security Service Proxies

On Dell CoreSrv, create a dynamic Traefik configuration to proxy Pi UIs:

```bash
cd /path/to/Orion-Sentinel-CoreSrv/core/traefik/dynamic

# Create orion-remotes.yml
nano orion-remotes.yml
```

Add:

```yaml
http:
  routers:
    # Pi DNS / Pi-hole UI
    dns:
      rule: "Host(`dns.local`)"
      entryPoints:
        - websecure
      tls: true
      middlewares:
        - secure-chain@file
        - authelia@file  # Require Authelia login
      service: dns-svc

    # NetSec Web UI
    security:
      rule: "Host(`security.local`)"
      entryPoints:
        - websecure
      tls: true
      middlewares:
        - secure-chain@file
        - authelia@file  # Require Authelia login
      service: security-svc

  services:
    # Pi DNS service
    dns-svc:
      loadBalancer:
        servers:
          - url: "http://192.168.8.251"  # Pi DNS IP (adjust port if needed: :8080/admin)

    # NetSec service
    security-svc:
      loadBalancer:
        servers:
          - url: "http://192.168.8.252:8080"  # NetSec UI IP & port (adjust as needed)
```

Restart Traefik:

```bash
docker compose -f core/traefik/docker-compose.yml restart
```

### Configure DNS Records

In your router or Pi-hole, add A-records:

```
dns.local        → 192.168.8.100  (Dell CoreSrv)
security.local   → 192.168.8.100  (Dell CoreSrv)
grafana.local    → 192.168.8.100  (Dell CoreSrv)
auth.local       → 192.168.8.100  (Dell CoreSrv)
traefik.local    → 192.168.8.100  (Dell CoreSrv)
prometheus.local → 192.168.8.100  (Dell CoreSrv)
```

**Important**: Even though Pi DNS and NetSec have their own IPs, the `*.local` domains point to Dell because Traefik will proxy to them.

---

## Verification & Testing

### Test Service Access

From any device on your LAN:

1. **Authelia**: `https://auth.local`
   - Should show login page
   - Login with configured credentials
   - Setup 2FA (TOTP)

2. **Traefik**: `https://traefik.local`
   - Should redirect to Authelia
   - After login, shows Traefik dashboard

3. **Grafana**: `https://grafana.local`
   - Should redirect to Authelia (if configured)
   - Shows Grafana dashboard

4. **Pi DNS**: `https://dns.local`
   - Should redirect to Authelia
   - Proxies to Pi-hole admin UI

5. **NetSec**: `https://security.local`
   - Should redirect to Authelia
   - Proxies to NetSec web UI

### Test Log Collection

In Grafana (`https://grafana.local`):

1. Navigate to **Explore** → Select **Loki** data source

2. Try these queries:

```logql
# All logs
{host=~"pi-.*"}

# Pi DNS logs
{host="pi-dns"}

# NetSec logs
{host="pi-netsec"}

# Pi-hole queries
{job="pihole"}

# Suricata alerts
{job="suricata",event_type="alert"}

# All IDS alerts
{component="ids"}

# All AI detections
{component="ai"}
```

3. Should see logs flowing from both Pis

### Test Metrics Collection

In Prometheus (`https://prometheus.local`):

1. Navigate to **Targets** page
2. Should see:
   - `node-exporter-pi-dns` (Pi DNS metrics)
   - `node-exporter-pi-netsec` (NetSec metrics)
   - `node-exporter-dell` (Dell metrics)

3. Try these queries:

```promql
# CPU usage across all nodes
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage
100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)
```

---

## Grafana Dashboards

### Import Pre-built Dashboards

Grafana provides many community dashboards:

1. Go to **Dashboards** → **Import**

2. Import by ID:
   - **1860**: Node Exporter Full (system metrics)
   - **13639**: Loki & Promtail (log metrics)
   - **12019**: Traefik Dashboard
   - **14055**: Suricata Dashboard

### Create Custom Dashboards

#### Example: Orion Sentinel Overview

Create panels for:

1. **DNS Query Rate** (from Loki):
   ```logql
   sum(rate({job="pihole"}[5m]))
   ```

2. **IDS Alert Rate** (from Loki):
   ```logql
   sum(rate({job="suricata",event_type="alert"}[5m]))
   ```

3. **Top Blocked Domains** (from Loki):
   ```logql
   topk(10, sum by (domain) (count_over_time({job="pihole",action="blocked"}[1h])))
   ```

4. **System Health** (from Prometheus):
   ```promql
   avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
   ```

5. **Service Status** (from Prometheus):
   ```promql
   up{job=~"node-exporter-.*"}
   ```

Save as "Orion Sentinel - Overview Dashboard"

---

## Troubleshooting

### Logs Not Appearing in Loki

1. **Check Promtail on Pi**:
   ```bash
   docker logs pi-dns-agent
   # Look for connection errors
   ```

2. **Check Loki on Dell**:
   ```bash
   docker logs orion-loki
   # Look for ingestion errors
   ```

3. **Test connectivity**:
   ```bash
   # From Pi
   docker exec pi-dns-agent wget -O- http://192.168.8.100:3100/ready
   ```

4. **Check firewall**:
   ```bash
   # On Dell
   sudo ufw status | grep 3100
   ```

5. **Check Promtail metrics**:
   ```bash
   # From Pi
   curl http://localhost:9080/metrics | grep promtail_sent_entries_total
   ```

### Traefik Not Routing

1. **Check Traefik logs**:
   ```bash
   docker logs orion-traefik
   ```

2. **Verify DNS**:
   ```bash
   nslookup grafana.local
   # Should resolve to Dell IP
   ```

3. **Check dynamic config**:
   ```bash
   # On Dell
   cat core/traefik/dynamic/orion-remotes.yml
   # Verify syntax
   ```

4. **Test routing**:
   ```bash
   curl -H "Host: grafana.local" http://192.168.8.100:443 -k
   ```

### Authelia SSO Issues

1. **Check Authelia logs**:
   ```bash
   docker logs orion-authelia
   ```

2. **Verify secrets**:
   ```bash
   # Check env/.env.core
   grep AUTHELIA env/.env.core
   ```

3. **Reset user password**:
   ```bash
   docker exec -it orion-authelia authelia crypto hash generate pbkdf2 --password "newpassword"
   # Update users.yml with new hash
   ```

### Prometheus Not Scraping

1. **Check targets**:
   - `https://prometheus.local/targets`
   - Look for errors

2. **Check Node Exporter on Pi**:
   ```bash
   curl http://localhost:9100/metrics
   ```

3. **Check firewall on Pi**:
   ```bash
   sudo ufw status | grep 9100
   ```

4. **Check Prometheus config**:
   ```bash
   # On Dell
   cat monitoring/prometheus/prometheus.yml
   # Verify Pi targets are listed
   ```

---

## Security Best Practices

### Network Security

1. **Use VPN or Tailscale** for log shipping over internet
2. **Firewall rules** to only allow specific IPs/ports
3. **TLS encryption** for all HTTPS endpoints
4. **Separate networks** for management vs production traffic

### Authentication & Authorization

1. **Enable Authelia** for all services
2. **Use 2FA** (TOTP or WebAuthn)
3. **Strong passwords** for all accounts
4. **Session management** with appropriate timeouts
5. **Regular audits** of Authelia access logs

### Log & Data Security

1. **Retention policies** in Loki (e.g., 30 days)
2. **Sensitive data filtering** in Promtail pipelines
3. **Access control** for Grafana dashboards
4. **Encryption at rest** for Loki storage
5. **Regular backups** of Grafana dashboards and Prometheus data

### System Hardening

1. **Keep Docker updated** on all systems
2. **Regular security updates** for OS
3. **Minimal exposed ports** via firewall
4. **Resource limits** for containers
5. **Health checks** and monitoring

---

## Next Steps

After SPoG is operational:

1. **Create dashboards** for your use cases
2. **Set up alerts** in Grafana for critical events
3. **Configure backups** with `scripts/backup.sh`
4. **Review runbooks** in `OPERATIONAL_RUNBOOK.md`
5. **Document customizations** specific to your environment

---

## Additional Resources

- [Orion Sentinel Architecture](./ORION_SENTINEL_ARCHITECTURE.md)
- [Operational Runbook](../OPERATIONAL_RUNBOOK.md)
- [Disaster Recovery](../DISASTER_RECOVERY.md)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## Support

If you encounter issues:

1. Check troubleshooting section above
2. Review logs on affected components
3. Verify network connectivity
4. Check firewall rules
5. Consult [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

**Remember**: The SPoG architecture provides centralized observability, but each Pi should still function independently if the Dell CoreSrv goes down.
