# SPoG Quick Reference Card

**Single Pane of Glass (SPoG) - Quick Setup Guide**

---

## 🎯 Overview

Centralize observability for Orion Sentinel on Dell CoreSrv.

**Architecture**: Dell CoreSrv (Loki, Grafana, Traefik) ← Pi DNS + NetSec Pi (logs via Promtail)

---

## 📋 Prerequisites Checklist

### Dell CoreSrv
- [ ] Ubuntu/Debian Linux installed
- [ ] Docker & Docker Compose installed
- [ ] Static IP configured (e.g., 192.168.8.100)
- [ ] Firewall rules configured (ports 443, 3100, 9100)

### Pi Nodes
- [ ] DNS stack or NSM/AI stack deployed
- [ ] Network connectivity to Dell
- [ ] Docker & Docker Compose installed

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Dell CoreSrv Setup

```bash
# Clone CoreSrv repo
git clone https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# Configure environment
cp env/.env.core.example env/.env.core
cp env/.env.monitoring.example env/.env.monitoring
nano env/.env.core  # Set AUTHELIA_* secrets, HOST_IP

# Start services
./orionctl.sh up-core          # Traefik + Authelia
./orionctl.sh up-observability # Loki + Prometheus + Grafana

# Configure firewall
sudo ufw allow from 192.168.8.0/24 to any port 3100 proto tcp
sudo ufw allow from 192.168.8.0/24 to any port 443 proto tcp
```

### Step 2: Deploy Pi DNS Agent

```bash
# On Pi DNS node
cd /path/to/Orion-DNS_Stack
./scripts/deploy-spog-agent.sh pi-dns 192.168.8.100
```

### Step 3: Deploy NetSec Agent

```bash
# On NetSec Pi
cd /path/to/Orion-DNS_Stack
./scripts/deploy-spog-agent.sh pi-netsec 192.168.8.100
```

---

## ✅ Verification

### Test Services
- [ ] `https://auth.local` → Authelia login
- [ ] `https://grafana.local` → Grafana dashboard
- [ ] `https://traefik.local` → Traefik dashboard

### Check Logs in Grafana
```logql
{host="pi-dns"}      # DNS logs
{host="pi-netsec"}   # Security logs
{job="pihole"}       # Pi-hole queries
{job="suricata"}     # IDS alerts
```

### Verify Agent Status
```bash
# On Pi DNS
docker logs pi-dns-agent
curl http://localhost:9080/metrics

# On NetSec Pi
docker logs pi-netsec-agent
curl http://localhost:9080/metrics
```

---

## 🛠️ Common Commands

### Dell CoreSrv

```bash
# Start/stop services
./orionctl.sh up-core
./orionctl.sh down-core
./orionctl.sh up-observability
./orionctl.sh down-observability

# View logs
docker logs orion-loki
docker logs orion-grafana
docker logs orion-traefik
docker logs orion-authelia

# Check status
docker ps | grep orion
```

### Pi Agents

```bash
# Start/stop agent
docker compose up -d
docker compose down

# View logs
docker logs pi-dns-agent
docker logs pi-netsec-agent

# Restart agent
docker compose restart

# Check metrics
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
```

---

## 🔧 Troubleshooting

### Logs Not Appearing in Grafana?

1. **Check Promtail on Pi**:
   ```bash
   docker logs pi-dns-agent | grep -i error
   ```

2. **Check connectivity to Dell**:
   ```bash
   docker exec pi-dns-agent wget -O- http://192.168.8.100:3100/ready
   ```

3. **Check Loki on Dell**:
   ```bash
   docker logs orion-loki | grep -i error
   curl http://localhost:3100/ready
   ```

4. **Check firewall**:
   ```bash
   sudo ufw status | grep 3100
   ```

### Traefik Not Routing?

1. **Check Traefik logs**:
   ```bash
   docker logs orion-traefik | grep -i error
   ```

2. **Verify DNS resolution**:
   ```bash
   nslookup grafana.local
   ```

3. **Test routing**:
   ```bash
   curl -H "Host: grafana.local" http://192.168.8.100:443 -k
   ```

### Authelia Login Issues?

1. **Reset password**:
   ```bash
   docker exec -it orion-authelia authelia crypto hash generate pbkdf2 --password "newpassword"
   # Update users.yml with new hash
   ```

2. **Check logs**:
   ```bash
   docker logs orion-authelia | grep -i error
   ```

---

## 📊 Useful Grafana Queries

### DNS Activity
```logql
# DNS query rate
sum(rate({job="pihole"}[5m]))

# Top blocked domains
topk(10, sum by (domain) (count_over_time({job="pihole",action="blocked"}[1h])))

# DNS errors
{job="unbound"} |~ "error|failed"
```

### Security Events
```logql
# IDS alert rate
sum(rate({job="suricata",event_type="alert"}[5m]))

# High-severity alerts
{job="suricata",alert_severity=~"1|2"}

# AI anomalies
{job="ai-anomaly"} | json | anomaly_score > 0.7
```

### System Health
```promql
# CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage
100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)
```

---

## 🔐 Security Best Practices

- ✅ Use strong passwords for Authelia, Grafana
- ✅ Enable 2FA in Authelia (TOTP or WebAuthn)
- ✅ Configure firewall rules to restrict access
- ✅ Use Tailscale/VPN for remote access
- ✅ Set log retention policy in Loki (30 days recommended)
- ✅ Regular backups of Grafana dashboards

---

## 📚 Full Documentation

For complete setup instructions, see:
- **[SPOG Integration Guide](./SPOG_INTEGRATION_GUIDE.md)** - Complete setup
- **[Pi DNS Agent](../stacks/agents/pi-dns/README.md)** - DNS agent details
- **[Pi NetSec Agent](../stacks/agents/pi-netsec/README.md)** - NetSec agent details
- **[Orion Sentinel Architecture](./ORION_SENTINEL_ARCHITECTURE.md)** - Platform overview

---

## 🆘 Support

If you encounter issues:
1. Check logs on affected component
2. Verify network connectivity
3. Check firewall rules
4. Consult full documentation
5. Review [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

---

## 🎯 Service URLs Reference

| Service | URL | Description |
|---------|-----|-------------|
| Authelia | `https://auth.local` | SSO login |
| Traefik | `https://traefik.local` | Reverse proxy |
| Grafana | `https://grafana.local` | Dashboards |
| Prometheus | `https://prometheus.local` | Metrics |
| Pi DNS | `https://dns.local` | Pi-hole UI |
| NetSec | `https://security.local` | NetSec UI |

---

**Quick Tips:**
- 💡 Use `docker compose logs -f` for real-time log viewing
- 💡 Add `--tail 50` to limit log output
- 💡 Use `docker stats` to monitor resource usage
- 💡 Export Grafana dashboards regularly for backup
- 💡 Test failover by stopping Dell services (Pis should continue working independently)

---

*For the complete setup guide, see [SPOG_INTEGRATION_GUIDE.md](./SPOG_INTEGRATION_GUIDE.md)*
