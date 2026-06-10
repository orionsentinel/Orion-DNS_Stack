# Orion Sentinel DNS HA

**Network-wide ad/tracker/telemetry blocking with high-availability DNS — for a Raspberry Pi.**
Pi-hole + Unbound (local recursive, DNSSEC) behind a floating VIP managed by Keepalived.
Three containers. ARM64. No dashboards. Boring on purpose.

[![CI](https://github.com/orionsentinel/Orion-DNS_Stack/actions/workflows/ci.yml/badge.svg)](https://github.com/orionsentinel/Orion-DNS_Stack/actions/workflows/ci.yml)
&nbsp;License: [MIT](LICENSE)

---

## What it is

```
        Clients (router DHCP hands out the VIP as their DNS)
                              │
                  VIP 192.168.8.243  (Keepalived / VRRP)
              ┌───────────────┴───────────────┐
              ▼                                ▼
   Node A  192.168.8.244  MASTER     Node B  192.168.8.245  BACKUP
   ┌─────────────────────┐           ┌─────────────────────┐
   │ Pi-hole + Unbound   │           │ Pi-hole + Unbound   │   + autoheal
   └─────────────────────┘           └─────────────────────┘
              └────────► root DNS servers (DNSSEC) ◄────────┘
```

- **Pi-hole + Unbound** — one ARM64 image (`ghcr.io/mpgirro/docker-pihole-unbound`). Ad/tracker blocking in front of a privacy-first **local recursive** resolver. No third party sees all your DNS.
- **Keepalived** — floats one VIP between the two Pis. Clients use a single DNS IP that survives a node dying.
- **autoheal** — restarts a wedged container. Layered self-healing; see [docs/architecture.md](docs/architecture.md).

CI **boots the stack and proves** DNS resolution, DNSSEC validation, ad-blocking, and container health (on push to `main` + nightly).

## Quick start

One command per Pi (Raspberry Pi OS 64-bit, NVMe):

```bash
sudo apt update
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha
sudo ./bootstrap.sh --role primary       # Node A (.244).  --role secondary on Node B (.245)
#   It stops so you can set secrets in .env, then re-run.
#   Single Pi, no HA:  sudo ./bootstrap.sh --role single
```

Then point your router's DHCP **DNS server at the VIP `192.168.8.243`**.
Full walkthrough: **[docs/two-pi-quickstart.md](docs/two-pi-quickstart.md)**.

## Still seeing ads? Do this, in order

**[docs/privacy-setup.md](docs/privacy-setup.md)** — the fix order. Highlights:

```bash
make block-private-relay && make sync     # #1 fix for iPhones (stops Private Relay bypass)
make setup-blocklists    && make sync     # Hagezi Multi PRO + TIF
```
…then **router enforcement** (DHCP=VIP only, redirect outbound `:53`, block DoT/DoH, IPv6) — see [docs/client-network-setup.md](docs/client-network-setup.md).

> **Honest limit:** DNS blocks *third-party* trackers/telemetry/malware — not *first-party* in-app ads (YouTube/Instagram/Facebook serve those from their content domains). No DNS setup can.

## Common commands

```bash
make up-core           # start the stack (auto-detects role from .env)
./scripts/verify-ha.sh # VIP owner, keepalived state, DNS via VIP
make test-failover     # prove failover works (disruptive, auto-recovers)
make backup            # snapshot config
git pull && make update# upgrade (roll out BACKUP-first; see docs/upgrade-guide.md)
make help              # everything
```

## Documentation

Everything lives in **[docs/](docs/)** — start with the index. Key pages:
[architecture](docs/architecture.md) · [networking](docs/networking.md) · [privacy-setup](docs/privacy-setup.md) · [two-pi-quickstart](docs/two-pi-quickstart.md) · [disaster-recovery](docs/disaster-recovery.md) · [troubleshooting](docs/troubleshooting.md) · [REVIEW](docs/REVIEW.md).

## Requirements

- 1–2× Raspberry Pi 4/5 (4 GB+), **64-bit**, NVMe SSD (HAT) recommended, wired Ethernet.
- Docker + compose plugin (`bootstrap.sh` installs them).
- Three reserved IPs: nodes `.244`/`.245` + VIP `.243` (see [docs/networking.md](docs/networking.md)).

## Contributing & security

`main` is protected; small PRs, green CI. See [docs/branching-strategy.md](docs/branching-strategy.md) and [SECURITY.md](SECURITY.md). Released under the [MIT License](LICENSE).
