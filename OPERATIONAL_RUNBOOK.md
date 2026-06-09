# RPi HA DNS Stack - Operational Runbook

**Quick Reference for Common Operations**

## Emergency Contacts
- Primary Admin: [Your contact]
- Backup Admin: [Backup contact]
- Network Team: [Network contact]

## Critical Information
- **VIP Address**: 192.168.8.255
- **Primary Pi-hole**: 192.168.8.251
- **Secondary Pi-hole**: 192.168.8.252
- **Prometheus**: http://192.168.8.250:9090
- **Grafana**: http://192.168.8.250:3000

---

## Common Issues & Solutions

### Issue 1: DNS Not Resolving

**Symptoms**: Devices can't resolve domain names

**Quick Check**:
```bash
dig @192.168.8.255 google.com
```

**Solution**:
1. Check VIP status: `ip addr show | grep 192.168.8.255`
2. Check containers: `docker ps | grep pihole`
3. Restart Pi-hole: `docker restart pihole_primary pihole_secondary`
4. Check logs: `docker logs pihole_primary --tail 50`

**Escalation**: If still broken after 15 minutes, failover to secondary node

---

### Issue 2: High Memory Usage

**Symptoms**: System sluggish, OOM warnings

**Quick Check**:
```bash
free -h
docker stats --no-stream
```

**Solution**:
1. Identify memory hog: `docker stats --no-stream | sort -k 4 -r`
2. Restart heaviest container: `docker restart <container_name>`
3. Clear Docker cache: `docker system prune -f`
4. Check for log bloat: `du -sh /var/log/pihole/*`

**Prevention**: Run weekly maintenance script

---

### Issue 3: HA Failover Not Working

**Symptoms**: VIP not moving to backup node during failure

**Quick Check**:
```bash
docker logs keepalived --tail 100
```

**Solution**:
1. Verify Keepalived on both nodes: `docker ps | grep keepalived`
2. Check VRRP priority: `docker exec keepalived cat /etc/keepalived/keepalived.conf`
3. Test network connectivity between nodes: `ping <other_node_ip>`
4. Restart Keepalived: `docker restart keepalived`

**Manual Failover**: 
- Stop Keepalived on current master: `docker stop keepalived`
- VIP will move to backup automatically

---

### Issue 4: Grafana Not Loading

**Symptoms**: Can't access Grafana dashboard

**Quick Check**:
```bash
curl http://localhost:3000
docker logs grafana --tail 50
```

**Solution**:
1. Restart Grafana: `docker restart grafana`
2. Check Prometheus: `curl http://localhost:9090/-/healthy`
3. Verify network: `docker network inspect observability_net`
4. Check disk space: `df -h`

---

### Issue 5: Pi-hole Out of Sync

**Symptoms**: Different blocklists on primary and secondary

**Quick Check**:
```bash
docker exec pihole_primary pihole -g
docker exec pihole_secondary pihole -g
```

**Solution**:
1. Check Gravity Sync: `docker logs gravity-sync`
2. Manual sync: `docker exec pihole_primary pihole -g`
3. Force update on secondary: `docker exec pihole_secondary pihole -g`
4. Compare: `docker exec pihole_primary pihole -q <domain>`

---

## Routine Maintenance

### Weekly Tasks
```bash
# Run health check
/opt/rpi-ha-dns-stack/scripts/health-check.sh

# Run maintenance
/opt/rpi-ha-dns-stack/scripts/weekly-maintenance.sh

# Review logs
docker logs pihole_primary --since 7d | grep ERROR
docker logs prometheus --since 7d | grep ERROR
```

### Monthly Tasks
- Review Grafana dashboards for trends
- Update container images (maintenance script)
- Test backup restoration
- Review and tune Prometheus alerts
- Clean up old backups (>90 days)

### Quarterly Tasks
- Test HA failover manually
- Review and update documentation
- Capacity planning review
- Security updates check

---

## Disaster Recovery

### Backup Locations
- Configuration: `/opt/rpi-dns-backups/env-backups/`
- Compose files: `/opt/rpi-dns-backups/compose-backups/`
- Pi-hole settings: Backed up via Gravity Sync
- Grafana dashboards: Provisioned from code

### Recovery Procedure

**Scenario: Primary Node Failure**
1. Secondary takes over automatically (VIP moves)
2. Monitor secondary node for 24 hours
3. Schedule primary node repair/replacement
4. Restore configuration from backup
5. Verify sync with secondary
6. Return to normal operations

**Scenario: Complete Stack Failure**
1. Deploy fresh Raspberry Pi OS
2. Clone repository: `git clone <repo_url>`
3. Restore `.env` files from backup
4. Run setup: `bash scripts/setup.sh`
5. Restore Pi-hole configuration
6. Verify DNS resolution
7. Monitor for 24 hours

**Recovery Time Objective (RTO)**: 4 hours  
**Recovery Point Objective (RPO)**: 24 hours

---

## Monitoring & Alerts

### Critical Alerts
- DNS resolution failure
- Node down >5 minutes  
- Disk usage >90%
- Memory usage >95%

### Warning Alerts
- Container unhealthy
- High query latency
- Disk usage >80%
- Memory usage >85%

### Alert Channels
- Signal notifications (configured)
- Grafana dashboards
- Prometheus Alertmanager

---

## Contacts & Resources

### Documentation
- Full Setup: `/opt/rpi-ha-dns-stack/INSTALLATION_GUIDE.md`
- Troubleshooting: `/opt/rpi-ha-dns-stack/TROUBLESHOOTING.md`
- Architecture: `/opt/rpi-ha-dns-stack/MULTI_NODE_HA_DESIGN.md`

### External Resources
- Pi-hole Docs: https://docs.pi-hole.net/
- Unbound Docs: https://nlnetlabs.nl/documentation/unbound/
- Docker Docs: https://docs.docker.com/

### Support
- GitHub Issues: https://github.com/orionsentinel/Orion-DNS_Stack/issues
- Community: [Your community link]

---

## Change Log

Document all changes here:

| Date | Change | Reason | By |
|------|--------|--------|-----|
| [Date] | [What changed] | [Why] | [Who] |

---

**Last Updated**: [Date]  
**Version**: 1.0  
**Owner**: [Your name]
