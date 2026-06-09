# Pi NetSec Agent - Log Shipping to Dell CoreSrv (SPoG Mode)

This directory contains the configuration for the **Pi NetSec Agent**, a Promtail-based log shipper that sends security logs (Suricata IDS, AI, NSM) from your NetSec Pi to the centralized observability stack on Dell CoreSrv.

## 🎯 Purpose

This agent is part of the **Single Pane of Glass (SPoG)** architecture:

```
┌──────────────────┐         ┌─────────────────────────────┐
│  NetSec Pi Node  │         │     Dell CoreSrv (SPoG)     │
│                  │         │                             │
│  ┌────────────┐  │  Logs   │  ┌───────────────────────┐  │
│  │ Suricata   │──┼────────►│  │ Loki (Log Storage)    │  │
│  │ AI Service │  │ :3100   │  │                       │  │
│  │ Threat Intel│  │         │  └───────┬───────────────┘  │
│  └────────────┘  │         │          │                  │
│                  │         │  ┌───────▼───────────────┐  │
│  ┌────────────┐  │         │  │ Grafana (Dashboards)  │  │
│  │ Promtail   │  │         │  │                       │  │
│  │ (This)     │  │         │  │ - IDS alerts          │  │
│  └────────────┘  │         │  │ - AI anomalies        │  │
│                  │         │  │ - Threat intel        │  │
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
2. **Firewall rules** allowing traffic from NetSec Pi to Dell port 3100:
   ```bash
   sudo ufw allow from 192.168.8.0/24 to any port 3100 proto tcp
   ```
3. **Traefik** (optional) for secure access to Grafana

### On NetSec Pi

1. **NSM/AI stack** deployed and running (Suricata, AI service, threat intel)
2. **Docker** and **Docker Compose** installed
3. **Network connectivity** to Dell CoreSrv
4. **nsm_net** Docker network exists (created by NSM stack deployment)

## 🚀 Quick Start

### Option A: Automated Deployment (Recommended)

Use the provided deployment script for easy setup:

```bash
cd /path/to/Orion-DNS_Stack
./scripts/deploy-spog-agent.sh pi-netsec 192.168.8.100
```

Replace `192.168.8.100` with your Dell CoreSrv IP address.

The script will:
- Create `promtail-config.yml` from the example
- Update the Loki URL automatically
- Create the NSM network if needed
- Deploy the Promtail agent
- Verify the deployment

### Option B: Manual Deployment

If you prefer manual configuration:

#### 1. Configure Promtail

Copy the example configuration and update the Dell CoreSrv IP:

```bash
cd /path/to/agents/pi-netsec
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

#### 3. Deploy the Agent

```bash
docker compose up -d
```

#### 4. Verify Logs are Shipping

Check Promtail status:

```bash
docker logs pi-netsec-agent
```

Check Promtail metrics endpoint:

```bash
curl http://localhost:9080/metrics
```

#### 5. View Logs in Grafana

On Dell CoreSrv, access Grafana and query Loki:

1. Navigate to **Explore** → **Loki**
2. Try these queries:
   - `{host="pi-netsec"}` - All logs from NetSec Pi
   - `{job="suricata"}` - Suricata IDS alerts
   - `{job="ai-anomaly"}` - AI device anomaly detection
   - `{job="ai-risk"}` - AI domain risk scoring
   - `{job="threat-intel"}` - Threat intelligence IOCs
   - `{component="ids"}` - All IDS activity

## 📊 What Logs Are Shipped?

This agent collects and ships the following logs to Dell CoreSrv:

| Log Source | Job Name | Labels | Description |
|------------|----------|--------|-------------|
| Suricata EVE | `suricata` | `host=pi-netsec`, `stack=netsec-ai`, `component=ids` | IDS alerts, flows, stats (JSON) |
| Suricata Fast | `suricata-fast` | `host=pi-netsec`, `stack=netsec-ai`, `component=ids` | Alert summary (text) |
| AI Device Anomaly | `ai-device-anomaly` | `host=pi-netsec`, `stack=netsec-ai`, `component=ai` | Device behavior anomalies |
| AI Domain Risk | `ai-domain-risk` | `host=pi-netsec`, `stack=netsec-ai`, `component=ai` | Domain risk scores |
| Threat Intel IOCs | `threat-intel-iocs` | `host=pi-netsec`, `stack=netsec-ai`, `component=threat-intel` | Indicators of Compromise |
| Threat Intel Matches | `threat-intel-matches` | `host=pi-netsec`, `stack=netsec-ai`, `component=threat-intel` | IOC matches in environment |
| Community Intel | `community-intel-digest` | `host=pi-netsec`, `stack=netsec-ai`, `component=threat-intel` | Threat intel summaries |
| Docker containers | `docker-containers` | `host=pi-netsec`, `stack=netsec-ai` | Container logs from NSM/AI stack |
| System logs | `system` | `host=pi-netsec`, `stack=netsec-ai`, `component=os` | OS-level logs for correlation |

## 🔧 Configuration Details

### Promtail Configuration

The `promtail-config.yml` file defines:

- **Server**: HTTP endpoint on port 9080 for metrics
- **Clients**: Dell CoreSrv Loki endpoint with retry logic
- **Scrape configs**: Log sources and parsing pipelines
- **Limits**: Resource constraints for Raspberry Pi

### Log Parsing Pipelines

Each log source has a tailored pipeline:

1. **JSON parsing**: Extract structured fields from JSON logs (Suricata, AI)
2. **Regex extraction**: Parse text-based logs into structured fields
3. **Timestamp parsing**: Extract and format timestamps
4. **Label extraction**: Add searchable labels (severity, type, etc.)
5. **Filtering**: Drop low-value or noisy logs (optional)

### Resource Limits

Configured for Raspberry Pi 5 hardware:

- **CPU**: 0.1 - 0.5 cores
- **Memory**: 128MB - 256MB
- **Read rate**: 10,000 lines/sec burst

## 🔍 Troubleshooting

### Agent Won't Start

Check logs:
```bash
docker logs pi-netsec-agent
```

Common issues:
- **NSM network missing**: Create with `docker network create nsm_net`
- **Config file missing**: Copy `promtail-config.example.yml` to `promtail-config.yml`
- **Permission denied**: Ensure Docker has access to `/var/log`
- **Suricata logs not found**: Verify Suricata log path matches config

### Logs Not Appearing in Grafana

1. **Check Promtail connectivity**:
   ```bash
   docker exec pi-netsec-agent wget -O- http://192.168.8.100:3100/ready
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

### No Suricata Logs

Verify Suricata is logging:

```bash
# Check Suricata is running
docker ps | grep suricata

# Check Suricata logs exist
ls -lh /var/log/suricata/eve.json

# Test Suricata logging
tail -f /var/log/suricata/eve.json
```

### High Resource Usage

If Promtail is using too much CPU/memory:

1. **Reduce log volume**: Edit `promtail-config.yml` and:
   - Uncomment the drop stage for Suricata flow/stats events
   - Add drop stage for low-score AI anomalies
2. **Increase batch wait**: Change `batchwait` from 1s to 5s
3. **Lower resource limits**: Adjust in `docker-compose.yml`

## 🔐 Security Considerations

### Network Security

- **Firewall**: Only allow NetSec Pi to Dell port 3100
- **Encryption**: Use VPN or Tailscale for log shipping over untrusted networks
- **Authentication**: Enable Loki authentication if exposing externally

### Log Privacy

- **Sensitive data**: Suricata logs contain network traffic metadata (potentially sensitive)
- **IDS alerts**: May contain internal IP addresses and network topology
- **Retention**: Configure log retention policy in Loki
- **Access control**: Use Authelia/Traefik for Grafana access control

### Example: Secure Setup with Tailscale

1. Install Tailscale on both NetSec Pi and Dell
2. Update Loki URL to use Tailscale IP:
   ```yaml
   clients:
     - url: http://100.x.x.x:3100/loki/api/v1/push
   ```
3. Firewall rules only allow Tailscale interface

## 🔄 Integration with DNS Pi

Both DNS Pi and NetSec Pi can ship logs to the same Dell CoreSrv:

```
┌──────────────────┐         ┌─────────────────────────────┐
│   DNS Pi Node    │  Logs   │     Dell CoreSrv (SPoG)     │
│                  ├────────►│                             │
└──────────────────┘  :3100  │  ┌───────────────────────┐  │
                              │  │ Loki (Log Storage)    │  │
┌──────────────────┐  Logs   │  │                       │  │
│  NetSec Pi Node  ├────────►│  │ - DNS logs (pi-dns)   │  │
│  (This Agent)    │  :3100  │  │ - IDS logs (pi-netsec)│  │
└──────────────────┘         │  │ - AI logs (pi-netsec) │  │
                              │  └───────────────────────┘  │
                              └─────────────────────────────┘
```

Query logs from both Pis in Grafana:
- `{host="pi-dns"}` - DNS node logs
- `{host="pi-netsec"}` - Security node logs (this)
- `{host=~"pi-.*"}` - All Pi logs
- `{stack="dns-ha"}` - DNS stack logs
- `{stack="netsec-ai"}` - NSM/AI stack logs

## 📚 Additional Resources

- [SPOG Integration Guide](../../../docs/SPOG_INTEGRATION_GUIDE.md) - Complete SPoG setup
- [Orion Sentinel Architecture](../../../docs/ORION_SENTINEL_ARCHITECTURE.md) - Platform overview
- [Loki Documentation](https://grafana.com/docs/loki/latest/) - Official Loki docs
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/) - Official Promtail docs
- [Suricata EVE JSON Format](https://suricata.readthedocs.io/en/latest/output/eve/eve-json-output.html) - Suricata log format

## 🆘 Support

If you encounter issues:

1. Check logs: `docker logs pi-netsec-agent`
2. Verify connectivity: `docker exec pi-netsec-agent ping <dell-ip>`
3. Test Loki endpoint: `curl http://<dell-ip>:3100/ready`
4. Verify Suricata logging: `tail -f /var/log/suricata/eve.json`

## 📝 Example Grafana Dashboards

Once logs are flowing, create dashboards to visualize:

- **IDS Alert Rate**: Alerts per second over time
- **Top Alert Signatures**: Most common IDS signatures
- **Top Attackers**: Source IPs with most alerts
- **AI Anomalies**: Device behavior anomalies over time
- **High-Risk Domains**: Domains with high AI risk scores
- **Threat Intel Matches**: IOC matches in environment
- **NSM Health**: Service status and performance

Example LogQL queries:

```logql
# IDS alert rate
rate({job="suricata",event_type="alert"}[5m])

# Count of alerts by severity
sum by (alert_severity) (count_over_time({job="suricata",event_type="alert"}[1h]))

# Top 10 alert signatures
topk(10, sum by (alert_signature) (count_over_time({job="suricata",event_type="alert"}[1h])))

# AI anomalies above threshold
{job="ai-anomaly"} | json | anomaly_score > 0.7

# High-risk domains
{job="ai-risk"} | json | risk_score > 0.8

# Threat intel matches
{job="threat-intel-match"} | json

# All security events (combined)
{host="pi-netsec",component=~"ids|ai|threat-intel"}
```

## 🎯 SPoG Mode vs Local Mode

This configuration is for **SPoG mode** where logs are shipped to Dell CoreSrv.

For **local mode** (Loki/Grafana on NetSec Pi itself):
- Use the configuration in `stacks/nsm/promtail/`
- Set Loki URL to `http://loki:3100` (local container)
- Don't ship logs externally

Choose the mode that fits your architecture:
- **SPoG mode**: Centralized observability on Dell, easier management
- **Local mode**: Self-contained on NetSec Pi, no external dependencies
