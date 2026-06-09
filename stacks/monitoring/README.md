# Monitoring & Alerting Stack

The **single** observability stack for Orion Sentinel DNS HA — Prometheus +
Alertmanager + Grafana + Loki + Blackbox + Signal paging. (Consolidated from the
former `observability/` and `monitoring/` stacks.)

It runs on **one host** (e.g. Node B / `192.168.8.245`), scrapes the exporters
the DNS nodes publish, probes the VIP, and pages you on Signal when DNS degrades.
It is **optional** — the DNS service runs fine without it.

## What's inside

| Service | Purpose | Port |
|---|---|---|
| `prometheus` | metrics + alert evaluation | 9090 |
| `alertmanager` | routes alerts → Signal | 9093 |
| `grafana` | dashboards (provisioned) | 3000 |
| `loki` | log store (nodes ship via promtail) | 3100 |
| `blackbox-exporter` | DNS reachability probes of VIP + nodes | — |
| `signal-cli-rest-api` + `signal-webhook-bridge` | Signal paging | 8081 |

Targets, probes, and alerts use the canonical addresses (`docs/networking.md`):
Node A `.244`, Node B `.245`, VIP `.243`.

## Prerequisites

On **each DNS node**, enable the exporters so this stack can scrape them:

```bash
docker compose --profile two-node-ha-primary --profile exporters up -d   # backup profile on Node B
```

Point each node's `LOKI_URL` at this host (`http://192.168.8.245:3100/loki/api/v1/push`).

## Start

```bash
cd stacks/monitoring
cp .env.example .env
sudo nano .env            # GRAFANA_ADMIN_PASSWORD + (optional) Signal settings
docker compose up -d
```

- Grafana: `http://<host>:3000` (admin / your password) — dashboards auto-load
  under the "Orion Sentinel DNS HA" folder; Prometheus + Loki datasources are
  provisioned.
- Prometheus targets: `http://<host>:9090/targets`
- Alerts: `http://<host>:9090/alerts` → Alertmanager `:9093`

## Alerts (degraded-state paging)

Defined in `prometheus/alerts/dns-alerts.yml`, routed to Signal:

- **VIPDnsDown** (critical) — the VIP stopped resolving DNS (client-facing outage)
- **AllDnsNodesDown** (critical) — both nodes down
- **NodeDnsDown** (warning) — one node down (HA still serving)
- **DnsLatencyHigh**, **Node/Pihole exporter down**, **High CPU/Mem**, **Low disk**

## Signal paging

1. Register the sender number once against `signal-cli-rest-api`
   (see `signal-cli-config/README.md`).
2. Set `SIGNAL_NUMBER` + `SIGNAL_RECIPIENTS` in `.env`, then
   `docker compose up -d signal-webhook-bridge`.
   Alertmanager → `signal-webhook-bridge:8080/v1/send` → signal-cli → your phone.

Leave the Signal vars blank to run metrics/dashboards without paging.

## Scope note

`stacks/nsm/` (Suricata IDS + threat-intel) remains a **separate, optional
security stack** — a different concern from DNS metrics, and its AI components are
earmarked to move to the `Orion-sentinel-netsec-ai` repo. To unify logging,
point its promtail at this stack's Loki (`http://<host>:3100`) and use this
Grafana; that fold-in is tracked as a follow-up.
