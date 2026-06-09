# Orion Sentinel NSM/AI Integration Guide

**How to Connect the DNS HA Stack with Network Security Monitoring & AI**

---

## Overview

This guide explains how to integrate **Orion Sentinel DNS HA** (this repository) with **Orion Sentinel NSM AI** (separate repository) to create a complete home lab security platform.

### What This Integration Provides

```
┌────────────────────────────────────────────────────────────┐
│                  Integration Benefits                      │
├────────────────────────────────────────────────────────────┤
│  📊 DNS query visibility in security dashboards            │
│  🤖 AI-powered detection of malicious domains              │
│  🛡️ Automated blocking of high-risk domains                │
│  🔍 Correlation of DNS and network traffic                 │
│  📈 Unified observability across both systems              │
└────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### On DNS Pi (Pi #1 - This Repo)

✅ **Orion Sentinel DNS HA** deployed and running  
✅ Pi-hole accessible on static IP (e.g., 192.168.8.251)  
✅ Unbound logs enabled (if needed)  
✅ Network connectivity to Security Pi  
✅ Free disk space for log shipping agent  

### On Security Pi (Pi #2 - NSM/AI Repo)

✅ **Orion Sentinel NSM AI** deployed and running  
✅ Loki listening on HTTP port 3100  
✅ Suricata IDS operational  
✅ AI service ready to process logs  
✅ Network connectivity to DNS Pi  

### Network Requirements

✅ Both Pis on same LAN or connected via VPN  
✅ Port 3100/TCP accessible from Pi #1 to Pi #2 (Loki)  
✅ Port 80/TCP accessible from Pi #2 to Pi #1 (Pi-hole API)  
✅ Port mirroring configured on switch (for Suricata)  

---

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Data Flow Overview                          │
└─────────────────────────────────────────────────────────────────┘

Pi #1 (DNS HA - THIS REPO)          Pi #2 (NSM/AI - Other Repo)
┌────────────────────────┐          ┌────────────────────────────┐
│                        │          │                            │
│  ┌──────────────┐      │  Logs   │  ┌──────────────────────┐  │
│  │ Pi-hole      │──────┼─────────►│  │ Loki                 │  │
│  │              │      │  (3100) │  │ (Log Storage)        │  │
│  │ Query Logs   │      │          │  └──────────┬───────────┘  │
│  │ - Timestamp  │      │          │             │              │
│  │ - Client IP  │      │          │             │              │
│  │ - Domain     │      │          │  ┌──────────▼───────────┐  │
│  │ - Type       │      │          │  │ AI Service           │  │
│  │ - Action     │      │          │  │ - Feature extraction │  │
│  └──────▲───────┘      │          │  │ - ML inference       │  │
│         │              │          │  │ - Risk scoring       │  │
│         │              │   API    │  └──────────┬───────────┘  │
│         │ Block        │ ◄────────┼─────────────┘              │
│         │ Domain       │  (80)    │      │                     │
│  ┌──────┴───────┐      │          │      │ High Risk?          │
│  │ Pi-hole API  │◄─────┼──────────┼──────┘                     │
│  │              │      │          │                            │
│  │ Add to       │      │          │  ┌──────────────────────┐  │
│  │ Blocklist    │      │          │  │ Grafana              │  │
│  └──────────────┘      │          │  │ (Dashboards)         │  │
│                        │          │  └──────────────────────┘  │
└────────────────────────┘          └────────────────────────────┘
```

---

## Step 1: Expose DNS Logs for Shipping

### Understanding Pi-hole Logs

Pi-hole stores query logs in two locations:

1. **FTL Database** (`/etc/pihole/pihole-FTL.db`)
   - SQLite database with query history
   - Compact, structured format
   - Preferred for log shipping

2. **Query Log File** (`/var/log/pihole/pihole.log`)
   - Plain text log file
   - Real-time updates
   - Easier to tail with Promtail

### Method 1: Deploy Promtail on DNS Pi (Recommended)

Add Promtail service to your DNS stack to ship logs to Loki on Pi #2.

#### 1.1 Create Promtail Configuration

Create `stacks/dns/promtail-config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push
    # Replace with your Pi #2 IP address

scrape_configs:
  # Pi-hole FTL logs
  - job_name: pihole-ftl
    static_configs:
      - targets:
          - localhost
        labels:
          job: pihole-ftl
          pi: pi1-dns
          service: pihole
          __path__: /var/log/pihole/*.log
    pipeline_stages:
      - match:
          selector: '{job="pihole-ftl"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(?P<message>.*)$'
            - timestamp:
                source: timestamp
                format: 'Jan _2 15:04:05'
            - labels:
                timestamp:

  # Unbound logs (if enabled)
  - job_name: unbound
    static_configs:
      - targets:
          - localhost
        labels:
          job: unbound
          pi: pi1-dns
          service: unbound
          __path__: /var/log/unbound/*.log
```

#### 1.2 Add Promtail to docker-compose.yml

Edit `stacks/dns/docker-compose.yml` and add:

```yaml
services:
  # ... existing services ...

  promtail:
    image: grafana/promtail:latest
    container_name: promtail_dns_logs
    restart: unless-stopped
    volumes:
      # Mount Pi-hole logs (read-only)
      - ./pihole1/var-log:/var/log/pihole:ro
      # Mount Unbound logs if available
      # - ./unbound/logs:/var/log/unbound:ro
      # Promtail config
      - ./promtail-config.yml:/etc/promtail/config.yml:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - dns_net
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
        reservations:
          cpus: '0.1'
          memory: 64M
```

#### 1.3 Start Promtail

```bash
cd ~/orion-sentinel-dns-ha/stacks/dns
docker compose up -d promtail
docker logs -f promtail_dns_logs
```

**Expected Output:**
```
level=info ts=... msg="Starting Promtail" version=...
level=info ts=... msg="Successfully connected to Loki"
```

### Method 2: Direct API Integration (Alternative)

If you prefer not to run Promtail, the NSM/AI stack can query Pi-hole's API directly:

```python
# On Pi #2 AI service
import requests
import sqlite3

def fetch_pihole_queries(pihole_ip: str, limit: int = 100):
    """Fetch recent queries from Pi-hole FTL database"""
    # Note: Requires network file share or API endpoint
    # Pi-hole v6 has improved API support
    api_url = f"http://{pihole_ip}/admin/api.php"
    params = {"getAllQueries": limit}
    response = requests.get(api_url, params=params)
    return response.json()
```

---

## Step 2: Configure Pi-hole API Access

The Security Pi needs API access to add/remove domains from blocklists.

### 2.1 Get Pi-hole API Token

On Pi #1:

1. Access Pi-hole Web UI: `http://192.168.8.251/admin`
2. Log in with your password
3. Go to **Settings** → **API**
4. Click **Show API token**
5. Copy the token (long alphanumeric string)

### 2.2 Test API Access from Pi #2

From Security Pi:

```bash
# Test basic API connectivity
curl "http://192.168.8.251/admin/api.php?summary"

# Test with authentication (replace YOUR_TOKEN)
curl "http://192.168.8.251/admin/api.php?summary&auth=YOUR_TOKEN"

# Expected response: JSON with Pi-hole statistics
```

### 2.3 Store API Credentials Securely

On Pi #2, add to NSM/AI stack environment file:

```bash
# .env file for orion-sentinel-nsm-ai
PIHOLE_API_URL=http://192.168.8.251/admin/api.php
PIHOLE_API_TOKEN=your_actual_token_here
```

---

## Step 3: Configure AI Service Integration

### 3.1 Python Client for Pi-hole API

In the NSM/AI repository, the AI service uses this client:

```python
# File: orion-sentinel-nsm-ai/stacks/ai/src/orion_ai/pihole_client.py

import requests
import logging
from typing import Optional

logger = logging.getLogger(__name__)

class PiHoleClient:
    """Client for Pi-hole HTTP API"""
    
    def __init__(self, base_url: str, api_token: str, timeout: int = 5):
        self.base_url = base_url.rstrip('/')
        self.api_token = api_token
        self.timeout = timeout
    
    def add_domain_to_blocklist(self, domain: str, comment: str = "") -> bool:
        """Add a domain to Pi-hole's blacklist"""
        try:
            params = {
                "list": "black",
                "add": domain,
                "auth": self.api_token
            }
            if comment:
                params["comment"] = comment
            
            response = requests.post(
                self.base_url,
                params=params,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("success"):
                    logger.info(f"Successfully blocked domain: {domain}")
                    return True
                else:
                    logger.error(f"Failed to block {domain}: {result}")
                    return False
            else:
                logger.error(f"HTTP {response.status_code} blocking {domain}")
                return False
                
        except Exception as e:
            logger.error(f"Error blocking domain {domain}: {e}")
            return False
    
    def remove_domain_from_blocklist(self, domain: str) -> bool:
        """Remove a domain from Pi-hole's blacklist"""
        try:
            params = {
                "list": "black",
                "sub": domain,
                "auth": self.api_token
            }
            
            response = requests.post(
                self.base_url,
                params=params,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully unblocked domain: {domain}")
                return True
            else:
                logger.error(f"HTTP {response.status_code} unblocking {domain}")
                return False
                
        except Exception as e:
            logger.error(f"Error unblocking domain {domain}: {e}")
            return False
```

### 3.2 Domain Risk Scoring Pipeline

The AI service processes logs and decides whether to block:

```python
# Simplified example from NSM/AI repo

def domain_risk_pipeline(loki_url: str, pihole_client: PiHoleClient):
    """Analyze domains and block high-risk ones"""
    
    # 1. Fetch DNS logs from Loki
    logs = fetch_dns_logs_from_loki(loki_url, time_window="5m")
    
    # 2. Extract domains and features
    for log_entry in logs:
        domain = log_entry.get("domain")
        features = extract_domain_features(domain)
        
        # 3. Run ML model to get risk score
        risk_score = ml_model.predict(features)
        
        # 4. Apply blocking policy
        if risk_score >= 0.8:  # High risk threshold
            pihole_client.add_domain_to_blocklist(
                domain=domain,
                comment=f"AI-detected risk score: {risk_score:.2f}"
            )
            logger.warning(f"Blocked high-risk domain: {domain} (score: {risk_score})")
        
        elif risk_score >= 0.6:  # Medium risk
            logger.info(f"Monitoring domain: {domain} (score: {risk_score})")
        
        # 5. Log all actions to Loki
        write_action_to_loki({
            "domain": domain,
            "risk_score": risk_score,
            "action": "BLOCK" if risk_score >= 0.8 else "MONITOR",
            "timestamp": time.time()
        })
```

---

## Step 4: Verify Integration

### 4.1 Check Log Flow

On Pi #2, query Loki to see if DNS logs are arriving:

```bash
# Test Loki API
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="pihole-ftl"}' \
  | jq .

# Expected: Recent log entries from Pi-hole
```

### 4.2 Test Domain Blocking

On Pi #2, manually trigger a block:

```python
# Python test script
from pihole_client import PiHoleClient

client = PiHoleClient(
    base_url="http://192.168.8.251/admin/api.php",
    api_token="YOUR_API_TOKEN"
)

# Block a test domain
result = client.add_domain_to_blocklist("test-malicious.com", comment="Integration test")
print(f"Block result: {result}")
```

On Pi #1, verify in Pi-hole UI:
1. Go to **Blacklist** page
2. Look for `test-malicious.com`
3. Should show comment: "Integration test"

### 4.3 End-to-End Test

1. **Generate test traffic** on a client device:
   ```bash
   dig @192.168.8.255 test-domain.com
   ```

2. **Check logs appear in Loki** (on Pi #2):
   ```bash
   curl -G "http://localhost:3100/loki/api/v1/query" \
     --data-urlencode 'query={service="pihole"} |= "test-domain.com"'
   ```

3. **Verify AI service processes logs**:
   ```bash
   docker logs orion-ai | grep "test-domain.com"
   ```

4. **Confirm blocking (if high risk)**:
   Check Pi-hole blocklist for the domain

---

## Step 5: Grafana Dashboards

### 5.1 Unified Dashboard on Pi #2

Create a dashboard showing both DNS and security metrics:

**Dashboard Panels:**

1. **DNS Query Volume** (from Loki - Pi-hole logs)
   ```promql
   sum(rate({service="pihole"}[5m]))
   ```

2. **Blocked Queries** (from Loki - Pi-hole logs)
   ```promql
   sum(rate({service="pihole"} |= "blocked"[5m]))
   ```

3. **Suricata Alerts** (from Loki - Suricata logs)
   ```promql
   sum(rate({service="suricata"}[5m]))
   ```

4. **AI Risk Scores** (from Loki - AI service logs)
   ```promql
   avg_over_time({service="ai-domain-risk"} | json | risk_score [5m])
   ```

5. **Auto-Blocked Domains** (from Loki - AI service logs)
   ```promql
   sum(rate({service="ai-domain-risk"} |= "BLOCK"[5m]))
   ```

### 5.2 Import Pre-built Dashboard

The NSM/AI repository includes a pre-built Grafana dashboard:

```bash
# On Pi #2
cd ~/orion-sentinel-nsm-ai
cp dashboards/orion-sentinel-combined.json /path/to/grafana/provisioning/dashboards/
```

Access Grafana at `http://192.168.8.100:3000` and view the dashboard.

---

## Troubleshooting

### Issue: Logs Not Appearing in Loki

**Symptom:** No Pi-hole logs visible in Grafana/Loki

**Solutions:**
1. Check Promtail is running on Pi #1:
   ```bash
   docker ps | grep promtail
   docker logs promtail_dns_logs
   ```

2. Verify network connectivity:
   ```bash
   # From Pi #1
   curl http://192.168.8.100:3100/ready
   # Should return: ready
   ```

3. Check Loki is accepting logs:
   ```bash
   # On Pi #2
   docker logs loki | grep "POST /loki/api/v1/push"
   ```

4. Verify log file paths in Promtail config:
   ```bash
   # On Pi #1
   ls -la ./pihole1/var-log/
   # Files should exist
   ```

### Issue: API Blocking Not Working

**Symptom:** Domains not being added to Pi-hole blocklist

**Solutions:**
1. Verify API token is correct:
   ```bash
   # From Pi #2
   curl "http://192.168.8.251/admin/api.php?summary&auth=YOUR_TOKEN"
   # Should return JSON, not error
   ```

2. Check Pi-hole version supports API:
   ```bash
   # Pi-hole v5.0+ required
   docker exec pihole_primary pihole -v
   ```

3. Test manual API call:
   ```bash
   curl -X POST "http://192.168.8.251/admin/api.php?list=black&add=test.com&auth=YOUR_TOKEN"
   ```

4. Check AI service logs for errors:
   ```bash
   docker logs orion-ai | grep -i "error\|fail"
   ```

### Issue: High Network Traffic Between Pis

**Symptom:** Excessive bandwidth usage on LAN

**Solutions:**
1. Reduce log shipping frequency in Promtail
2. Implement log filtering (only ship errors/blocks)
3. Use compression in Loki client config
4. Increase batch send interval

---

## Best Practices

### Security

1. **Use HTTPS** for API calls if possible
2. **Rotate API tokens** monthly
3. **Limit network access** via firewall rules
4. **Encrypt logs in transit** (TLS for Loki)
5. **Monitor unauthorized access** attempts

### Performance

1. **Batch API calls** - don't block domains one-by-one
2. **Rate limit blocking** - max 10 domains/minute
3. **Cache DNS queries** - avoid duplicate processing
4. **Use log sampling** - not every query needs ML analysis
5. **Optimize Loki retention** - delete old logs

### Reliability

1. **Monitor integration health** - create alerts
2. **Test failover** - ensure DNS works if Pi #2 is down
3. **Backup regularly** - both Pis independently
4. **Document changes** - keep integration notes
5. **Version control configs** - Git for all YAML files

---

## Advanced: Bi-directional Integration

### Pi #2 → Pi #1: Enhanced Metrics

Export additional metrics from NSM/AI back to DNS Pi:

```yaml
# On Pi #2: Add Prometheus exporter
services:
  prometheus-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
```

```yaml
# On Pi #1: Scrape Pi #2 metrics
# prometheus.yml
scrape_configs:
  - job_name: 'security-pi'
    static_configs:
      - targets: ['192.168.8.100:9100']
```

### Shared Alertmanager

Centralize alerts from both Pis:

```yaml
# On Pi #2: Accept alerts from Pi #1
# alertmanager.yml
route:
  receiver: 'signal-notifications'
  group_by: ['alertname', 'pi']
  routes:
    - match:
        pi: 'pi1-dns'
      continue: true
    - match:
        pi: 'pi2-security'
      continue: true
```

---

## Summary

You have successfully integrated Orion Sentinel DNS HA with NSM/AI:

✅ **DNS logs** shipped from Pi #1 to Loki on Pi #2  
✅ **Pi-hole API** accessible from AI service on Pi #2  
✅ **Automated blocking** of high-risk domains enabled  
✅ **Unified dashboards** showing DNS + security metrics  
✅ **End-to-end testing** verified  

**Next Steps:**
1. Monitor the integration for 24 hours
2. Tune AI risk score thresholds
3. Create custom Grafana dashboards
4. Set up alerting for blocked domains
5. Document your specific configuration

---

## Security Considerations

**Critical Security Guidance for Orion Sentinel Integration**

When integrating DNS Pi (#1) with Security Pi (#2), security is paramount. Follow these guidelines to maintain a secure architecture.

### Threat Model & Risk Assessment

**Key Security Risks:**

1. **Pi-hole API Token Compromise**
   - **Risk:** If an attacker obtains the API token, they can manipulate DNS blocklists
   - **Impact:** Could whitelist malicious domains or block legitimate ones
   - **Likelihood:** Medium (if token is exposed in logs, scripts, or unsecured storage)

2. **Log Data Exposure**
   - **Risk:** DNS query logs contain information about network activity
   - **Impact:** Reveals which services and websites are being accessed
   - **Likelihood:** Low to Medium (depends on log transmission and storage security)

3. **Unauthorized API Access**
   - **Risk:** Unprotected Pi-hole API accessible from untrusted networks
   - **Impact:** External manipulation of DNS configuration
   - **Likelihood:** Medium (if firewall rules are misconfigured)

### Mitigation Strategies

#### 1. Secure API Token Storage

**Store API Token in .env File:**

```bash
# On DNS Pi (Pi #1)
cd /path/to/Orion-DNS_Stack

# Add to .env file
echo "PIHOLE_API_TOKEN=<your-api-token-here>" >> .env

# Set restrictive permissions (CRITICAL)
chmod 600 .env
chown $USER:$USER .env
```

**Verify Permissions:**
```bash
ls -la .env
# Should show: -rw------- (600) - only owner can read/write
```

**Never Commit .env to Git:**
```bash
# Ensure .env is in .gitignore
grep "^\.env$" .gitignore || echo ".env" >> .gitignore

# Verify .env is not tracked
git status .env
# Should show: "Untracked" or not listed
```

**Rotate API Token Regularly:**
```bash
# Generate new token every 90 days or after suspected compromise
# 1. Access Pi-hole web UI: http://192.168.8.251/admin
# 2. Go to: Settings → API
# 3. Click: "Show API Token" → "Generate New Token"
# 4. Update .env file with new token
# 5. Restart services that use the token
```

#### 2. Restrict API Access

**Only Security Pi Should Access API:**

Configure firewall on DNS Pi to restrict API access:

```bash
# On DNS Pi (Pi #1)
# Allow Pi-hole API only from Security Pi
sudo ufw allow from 192.168.8.100 to any port 80 comment "Pi-hole API from Security Pi"

# Block API access from all other IPs
sudo ufw deny 80/tcp

# Verify rules
sudo ufw status numbered
```

**Alternative: Use iptables:**
```bash
# Allow API access only from Security Pi
sudo iptables -A INPUT -p tcp --dport 80 -s 192.168.8.100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j DROP

# Save rules
sudo netfilter-persistent save
```

**Monitor API Access:**
```bash
# Check Pi-hole API access logs
docker exec pihole_primary tail -f /var/log/lighttpd/access.log | grep "api.php"

# Look for unexpected source IPs
```

#### 3. Secure Log Transmission

**Logs Shipped to Security Pi Should Not Contain:**

❌ **Avoid Logging Sensitive Information:**
- Passwords or authentication tokens
- Personal identifiable information (PII)
- Private/internal DNS names (if highly sensitive)
- Full query strings with parameters

✅ **Safe to Log:**
- Domain names queried
- Query timestamp
- Client IP (internal only)
- Query type (A, AAAA, PTR, etc.)
- Block/allow action
- Response time

**Sanitize Logs Before Shipping (If Needed):**

```bash
# Example: Filter out sensitive domains before shipping
# In Promtail configuration (stacks/agents/dns-log-agent/)

pipeline_stages:
  - match:
      selector: '{job="pihole"}'
      stages:
        - regex:
            expression: '.*(?P<domain>sensitive-internal\.local).*'
        - drop:
            expression: '.*sensitive-internal\.local.*'
            drop_counter_reason: 'sensitive_domain'
```

**Encrypt Log Transmission:**

Use TLS/HTTPS for Loki communication:

```bash
# On Security Pi (Pi #2)
# Configure Loki with TLS
# See Loki docs: https://grafana.com/docs/loki/latest/configuration/

# Update Promtail on DNS Pi to use HTTPS
# In dns-log-agent/promtail-config.yml
clients:
  - url: https://192.168.8.100:3100/loki/api/v1/push
    tls_config:
      ca_file: /path/to/ca.crt
      cert_file: /path/to/client.crt
      key_file: /path/to/client.key
```

#### 4. Network Segmentation

**Isolate Integration Traffic:**

```
┌─────────────────────────────────────────────────────────┐
│              Secure Network Architecture                 │
└─────────────────────────────────────────────────────────┘

[DNS Pi #1]                       [Security Pi #2]
192.168.8.250                     192.168.8.100
     │                                  │
     ├─ Pi-hole API (Port 80) ─────────┤ (Allowed)
     │                                  │
     ├─ Promtail ──► Loki (Port 3100)──┤ (Allowed)
     │                                  │
     └─ Management SSH (Port 22) ──────┘ (Allowed from Admin)
     
[Internet] ◄──X──► [DNS Pi #1]  (BLOCKED)
            ◄──X──► [Security Pi #2] (BLOCKED)
```

**Firewall Rules Summary:**

```bash
# On DNS Pi (Pi #1)
# Allow only Security Pi to access Pi-hole API
sudo ufw allow from 192.168.8.100 to any port 80

# Allow SSH only from admin workstation
sudo ufw allow from 192.168.8.10 to any port 22

# Deny all other inbound
sudo ufw default deny incoming
sudo ufw enable

# On Security Pi (Pi #2)
# Allow Promtail from DNS Pi
sudo ufw allow from 192.168.8.250 to any port 3100

# Allow SSH only from admin workstation
sudo ufw allow from 192.168.8.10 to any port 22

# Deny all other inbound
sudo ufw default deny incoming
sudo ufw enable
```

#### 5. Least Privilege Access

**Only Security Pi Should Have API Token:**

- **DNS Pi:** Should NOT have its own API token exposed
- **Security Pi:** Stores API token securely for automated blocking
- **Admin Users:** Should NOT need API token for normal operations
- **Other Services:** Should NOT have API access

**Access Control Matrix:**

| Component | Pi-hole Admin UI | Pi-hole API | Loki | Grafana |
|-----------|-----------------|-------------|------|---------|
| Admin (Human) | ✅ Read/Write | ❌ No Access | ✅ Read | ✅ Read/Write |
| Security Pi AI | ❌ No Access | ✅ Block Domains | ✅ Write Logs | ✅ Read |
| DNS Pi | ✅ Local Only | ❌ No Access | ✅ Send Logs | ❌ No Access |
| Other Devices | ❌ No Access | ❌ No Access | ❌ No Access | ❌ No Access |

#### 6. Audit and Monitoring

**Monitor for Suspicious Activity:**

```bash
# On DNS Pi: Monitor API access
docker exec pihole_primary tail -f /var/log/lighttpd/access.log | grep "api.php"

# Look for:
# - Unexpected source IPs
# - High request rates (potential abuse)
# - Failed authentication attempts
```

**Set Up Alerts:**

```yaml
# In Prometheus AlertManager
groups:
  - name: security
    rules:
      - alert: UnauthorizedAPIAccess
        expr: rate(pihole_api_requests{source_ip!="192.168.8.100"}[5m]) > 0
        annotations:
          summary: "Unauthorized Pi-hole API access detected"
          description: "API requests from {{ $labels.source_ip }}"
```

**Log Retention:**

- Keep security logs for at least 90 days
- Archive critical logs for 1 year
- Implement log rotation to prevent disk fill

#### 7. Incident Response

**If API Token is Compromised:**

1. **Immediately Rotate Token:**
   ```bash
   # Generate new token in Pi-hole UI
   # Update .env on Security Pi
   # Restart AI service
   ```

2. **Review Recent API Activity:**
   ```bash
   # Check what domains were blocked/unblocked
   docker exec pihole_primary sqlite3 /etc/pihole/gravity.db \
     "SELECT * FROM domainlist ORDER BY date_modified DESC LIMIT 100;"
   ```

3. **Audit Blocklist Changes:**
   ```bash
   # Compare current blocklist with backup
   # Look for suspicious additions/removals
   ```

4. **Notify Stakeholders:**
   - Document the incident
   - Review how token was compromised
   - Implement additional controls

### Best Practices Summary

**Configuration Security:**
- ✅ Store API token in `.env` with 600 permissions
- ✅ Never commit `.env` to version control
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Rotate API token every 90 days

**Network Security:**
- ✅ Restrict API access to Security Pi only
- ✅ Use firewall rules to enforce access control
- ✅ Consider TLS/HTTPS for log transmission
- ✅ Monitor network traffic for anomalies

**Operational Security:**
- ✅ Principle of least privilege
- ✅ Regular security audits
- ✅ Monitor API access logs
- ✅ Set up alerts for suspicious activity
- ✅ Maintain incident response procedures

**Data Security:**
- ✅ Sanitize logs before shipping (if needed)
- ✅ Ensure logs don't contain PII or secrets
- ✅ Implement log retention policies
- ✅ Secure log storage on Security Pi

### Additional Resources

- **Hardening Guide:** [docs/hardening.md](hardening.md)
- **Operations Guide:** [docs/operations.md](operations.md)
- **Security Guide:** [SECURITY_GUIDE.md](../SECURITY_GUIDE.md)
- **Pi-hole Security:** https://docs.pi-hole.net/main/security/

---

## Resources

- **This Repo:** [Orion Sentinel DNS HA](https://github.com/orionsentinel/Orion-DNS_Stack)
- **NSM/AI Repo:** Create `orion-sentinel-nsm-ai` repository
- **Pi-hole API Docs:** https://docs.pi-hole.net/
- **Loki Docs:** https://grafana.com/docs/loki/
- **Architecture Diagram:** [ORION_SENTINEL_ARCHITECTURE.md](ORION_SENTINEL_ARCHITECTURE.md)

---

**Questions or issues?** Open an issue in the respective repository.
