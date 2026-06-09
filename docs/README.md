# Documentation

Single source of truth for Orion Sentinel DNS HA. Start at the repo
[README](../README.md) for the quick start; come here for depth.

## Setup

| Doc | What it covers |
|---|---|
| [two-pi-quickstart.md](two-pi-quickstart.md) | Full two-Pi setup end-to-end (prerequisites → verified HA) |
| [client-network-setup.md](client-network-setup.md) | Point your LAN at the VIP; stop device/IPv6/DoH bypass |

## Core

| Doc | What it covers |
|---|---|
| [architecture.md](architecture.md) | Components, compose profiles, data flow |
| [networking.md](networking.md) | The canonical IP/VRRP scheme + the dedicated USB-C NIC |
| [troubleshooting.md](troubleshooting.md) | Common failures and fixes |
| [disaster-recovery.md](disaster-recovery.md) | Backup/restore, <1h rebuild |
| [upgrade-guide.md](upgrade-guide.md) | Rolling, zero-downtime upgrades |
| [branching-strategy.md](branching-strategy.md) | Branches, CI gate, releases |

## Topic guides

| Doc | What it covers |
|---|---|
| [profiles.md](profiles.md) | Blocklist profiles (standard / family / paranoid) |
| [OPTIMAL_BLOCKLISTS.md](OPTIMAL_BLOCKLISTS.md) | Recommended blocklists |
| [PIHOLE_CONFIGURATION.md](PIHOLE_CONFIGURATION.md) | Pi-hole configuration details |
| [hardening.md](hardening.md) | Security hardening (see also [../SECURITY.md](../SECURITY.md)) |
| [netsec-node.md](netsec-node.md) | Optional NSM / Suricata node |

## Reference

| Doc | What it covers |
|---|---|
| [AUDIT.md](AUDIT.md) | Architecture audit (A–J) and target design |
| [REVIEW.md](REVIEW.md) | Architect + DevSecOps maturity review |

## Operations

- Monitoring & alerting: [../stacks/monitoring/README.md](../stacks/monitoring/README.md)
- Operational scripts: [../ops/README.md](../ops/README.md)
- Systemd integration: [../systemd/README.md](../systemd/README.md)

> Retired guides (legacy install/upgrade/multi-node duplicates) were removed in
> favour of the above; their history remains in git.
