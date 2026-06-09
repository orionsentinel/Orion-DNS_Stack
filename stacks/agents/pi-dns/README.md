# Pi DNS Agent - Log Shipping to Dell CoreSrv (SPoG Mode)

This directory contains the configuration for the **Pi DNS Agent**, a Promtail-based log shipper that sends DNS logs from your Pi DNS node to the centralized observability stack on Dell CoreSrv.

## 🎯 Purpose

This agent is part of the **Single Pane of Glass (SPoG)** architecture:

```
┌──────────────────┐         ┌─────────────────────────────┐
│   Pi DNS Node    │         │     Dell CoreSrv (SPoG)     │
│                  │         │                             │
│  ┌────────────┐  │  Logs   │  ┌───────────────────────┐  │
│  │ Pi-hole    │──┼────────►│  │ Loki (Log Storage)    │  │
│  │ Unbound    │  │ :3100   │  │                       │  │
│  │ Keepalived │  │         │  └───────┬───────────────┘  │
│  └────────────┘  │         │          │                  │
│                  │         │  ┌───────▼───────────────┐  │
│  ┌────────────┐  │         │  │ Grafana (Dashboards)  │  │
│  │ Promtail   │  │         │  │                       │  │
│  │ (This)     │  │         │  │ - DNS metrics         │  │
│  └────────────┘  │         │  │ - Query logs          │  │
│                  │         │  │ - HA status           │  │
└──────────────────┘         │  └───────────────────────┘  │
                             │                             │
                             │  ┌───────────────────────┐  │
                             │  │ Traefik (Reverse Proxy│  │
                             │  │ Authelia (SSO/2FA)    │  │
                             │  └───────────────────────┘  │
                             └─────────────────────────────┘
```

## 📋 Prerequisites

### On Dell CoreSrv

1. **Loki** must be running and accessible on port 3100
2. **Firewall rules** allowing traffic from Pi DNS to Dell port 3100:
   ```bash
   sudo ufw allow from 192.168.8.0/24 to any port 3100 proto tcp
   ```
3. **Traefik** (optional) for secure access to Grafana

### On Pi DNS Node

1. **DNS stack** deployed and running (Pi-hole, Unbound, Keepalived)
2. **Docker** and **Docker Compose** installed
3. **Network connectivity** to Dell CoreSrv
4. **dns_net** Docker network exists (created by DNS stack deployment)

## 🚀 Quick Start

### Option A: Automated Deployment (Recommended)

Use the provided deployment script for easy setup:

```bash
cd /path/to/Orion-DNS_Stack
./scripts/deploy-spog-agent.sh pi-dns 192.168.8.100
```

Replace `192.168.8.100` with your Dell CoreSrv IP address.

The script will:
- Create `promtail-config.yml` from the example
- Update the Loki URL automatically
- Create the DNS network if needed
- Deploy the Promtail agent
- Verify the deployment

### Option B: Manual Deployment

If you prefer manual configuration:

#### 1. Configure Promtail

Copy the example configuration and update the Dell CoreSrv IP:

```bash
cd /path/to/Orion-DNS_Stack/stacks/agents/pi-dns
cp promtail-config.example.yml promtail-config.yml
```

Edit `promtail-config.yml` and update the Loki URL:

```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push  # UPDATE THIS IP!
```

Replace `192.168.8.100` with your Dell CoreSrv IP address.

#### 2. Set Environment Variables (Optional)

You can override the Loki URL via environment variable:

```bash
export LOKI_URL=http://192.168.8.100:3100
```

Or add it to your `.env` file in the repository root:

```bash
echo "LOKI_URL=http://192.168.8.100:3100" >> /path/to/Orion-DNS_Stack/.env
```

#### 3. Deploy the Agent

```bash
docker compose up -d
```

#### 4. Verify Logs are Shipping

Check Promtail status:

```bash
docker logs pi-dns-agent
```

Check Promtail metrics endpoint:

```bash
curl http://localhost:9080/metrics
```

#### 5. View Logs in Grafana

On Dell CoreSrv, access Grafana and query Loki:

1. Navigate to **Explore** → **Loki**
2. Try these queries:
   - `{host="pi-dns"}` - All logs from Pi DNS
   - `{job="pihole"}` - Pi-hole query logs
   - `{job="unbound"}` - Unbound resolver logs
   - `{job="keepalived"}` - HA manager logs
   - `{component="dns-blocker"}` - DNS blocking activity

## 📊 What Logs Are Shipped?

This agent collects and ships the following logs to Dell CoreSrv:

| Log Source | Job Name | Labels | Description |
|------------|----------|--------|-------------|
| Pi-hole queries | `pihole-queries` | `host=pi-dns`, `stack=dns-ha`, `component=dns-blocker` | DNS queries, blocks, allows |
| Pi-hole FTL | `pihole-ftl` | `host=pi-dns`, `stack=dns-ha`, `component=dns-blocker` | FTL daemon logs |
| Unbound | `unbound` | `host=pi-dns`, `stack=dns-ha`, `component=dns-resolver` | Recursive DNS resolver logs |
| Keepalived | `keepalived` | `host=pi-dns`, `stack=dns-ha`, `component=ha-manager` | HA failover events |
| Docker containers | `docker-containers` | `host=pi-dns`, `stack=dns-ha` | Container logs from DNS stack |
| System logs | `system` | `host=pi-dns`, `stack=dns-ha`, `component=os` | OS-level logs for correlation |

## 🔧 Configuration Details

### Promtail Configuration

The `promtail-config.yml` file defines:

- **Server**: HTTP endpoint on port 9080 for metrics
- **Clients**: Dell CoreSrv Loki endpoint with retry logic
- **Scrape configs**: Log sources and parsing pipelines
- **Limits**: Resource constraints for Raspberry Pi

### Log Parsing Pipelines

Each log source has a tailored pipeline:

1. **Regex extraction**: Parse log format into structured fields
2. **Timestamp parsing**: Extract and format timestamps
3. **Label extraction**: Add searchable labels (severity, action, etc.)
4. **Filtering**: Drop noisy logs (optional)

### Resource Limits

Configured for Raspberry Pi hardware:

- **CPU**: 0.1 - 0.5 cores
- **Memory**: 128MB - 256MB
- **Read rate**: 10,000 lines/sec burst

## 🔍 Troubleshooting

### Agent Won't Start

Check logs:
```bash
docker logs pi-dns-agent
```

Common issues:
- **DNS network missing**: Create with `docker network create dns_net`
- **Config file missing**: Copy `promtail-config.example.yml` to `promtail-config.yml`
- **Permission denied**: Ensure Docker has access to `/var/log`

### Logs Not Appearing in Grafana

1. **Check Promtail connectivity**:
   ```bash
   docker exec pi-dns-agent wget -O- http://192.168.8.100:3100/ready
   ```

2. **Check firewall on Dell**:
   ```bash
   # On Dell CoreSrv
   sudo ufw status | grep 3100
   ```

3. **Check Loki on Dell**:
   ```bash
   # On Dell CoreSrv
   docker logs orion-loki
   curl http://localhost:3100/ready
   ```

4. **Check Promtail metrics**:
   ```bash
   curl http://localhost:9080/metrics | grep promtail_sent_entries_total
   ```

### High Resource Usage

If Promtail is using too much CPU/memory:

1. **Reduce log volume**: Edit `promtail-config.yml` and add filters
2. **Increase batch wait**: Change `batchwait` from 1s to 5s
3. **Lower resource limits**: Adjust in `docker-compose.yml`

## 🔐 Security Considerations

### Network Security

- **Firewall**: Only allow Pi DNS to Dell port 3100
- **Encryption**: Use VPN or Tailscale for log shipping over untrusted networks
- **Authentication**: Enable Loki authentication if exposing externally

### Log Privacy

- **Sensitive data**: Pi-hole logs contain DNS queries (potentially sensitive)
- **Retention**: Configure log retention policy in Loki
- **Access control**: Use Authelia/Traefik for Grafana access control

### Example: Secure Setup with Tailscale

1. Install Tailscale on both Pi DNS and Dell
2. Update Loki URL to use Tailscale IP:
   ```yaml
   clients:
     - url: http://100.x.x.x:3100/loki/api/v1/push
   ```
3. Firewall rules only allow Tailscale interface

## 🔄 Integration with NetSec Pi

If you also have the NetSec Pi (Orion Sentinel NSM AI), both Pis can ship logs to the same Dell CoreSrv:

```
┌──────────────────┐         ┌─────────────────────────────┐
│   Pi DNS Node    │  Logs   │     Dell CoreSrv (SPoG)     │
│   (This Agent)   ├────────►│                             │
└──────────────────┘  :3100  │  ┌───────────────────────┐  │
                              │  │ Loki (Log Storage)    │  │
┌──────────────────┐  Logs   │  │                       │  │
│  NetSec Pi Node  ├────────►│  │ - DNS logs (pi-dns)   │  │
│  (Separate Agent)│  :3100  │  │ - IDS logs (pi-netsec)│  │
└──────────────────┘         │  │ - AI logs (pi-netsec) │  │
                              │  └───────────────────────┘  │
                              └─────────────────────────────┘
```

Query logs from both Pis in Grafana:
- `{host="pi-dns"}` - DNS node logs
- `{host="pi-netsec"}` - Security node logs
- `{host=~"pi-.*"}` - All Pi logs

## 📚 Additional Resources

- [SPOG Integration Guide](../../../docs/SPOG_INTEGRATION_GUIDE.md) - Complete SPoG setup
- [Orion Sentinel Architecture](../../../docs/ORION_SENTINEL_ARCHITECTURE.md) - Platform overview
- [Loki Documentation](https://grafana.com/docs/loki/latest/) - Official Loki docs
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/) - Official Promtail docs

## 🆘 Support

If you encounter issues:

1. Check logs: `docker logs pi-dns-agent`
2. Verify connectivity: `docker exec pi-dns-agent ping <dell-ip>`
3. Test Loki endpoint: `curl http://<dell-ip>:3100/ready`
4. Review [TROUBLESHOOTING.md](../../../TROUBLESHOOTING.md)

## 📝 Example Grafana Dashboards

Once logs are flowing, create dashboards to visualize:

- **DNS Query Rate**: Queries per second over time
- **Top Blocked Domains**: Most frequently blocked domains
- **Top Clients**: Devices making the most queries
- **HA Status**: Keepalived state changes and failovers
- **Unbound Performance**: Query response times
- **System Health**: CPU, memory, disk usage

Example LogQL queries:

```logql
# DNS query rate
rate({job="pihole"}[5m])

# Count of blocked queries
sum(rate({job="pihole",action="blocked"}[5m]))

# Top 10 blocked domains
topk(10, sum by (domain) (count_over_time({job="pihole",action="blocked"}[1h])))

# HA state changes
{job="keepalived"} |~ "Entering (MASTER|BACKUP)"

# Container restarts
{job="docker"} |~ "(started|stopped|restarted)"
```
