# Documentation

Single source of truth for Orion Sentinel DNS HA. Start at the repo
[README](../README.md) for the quick start; come here for depth.

## Setup

| Doc | What it covers |
|---|---|
| [two-pi-quickstart.md](two-pi-quickstart.md) | Full two-Pi setup end-to-end (prerequisites → verified HA) |
| [privacy-setup.md](privacy-setup.md) | **Fix the ads, in order** — Private Relay, router enforcement, Hagezi lists, IoT |
| [client-network-setup.md](client-network-setup.md) | Point your LAN at the VIP; stop device/IPv6/DoH bypass |
| [provisioning-plan.md](provisioning-plan.md) | One-flash provisioning (cloud-init → working node) — plan |

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
| [OPTIMAL_BLOCKLISTS.md](OPTIMAL_BLOCKLISTS.md) | Recommended blocklists |
| [PIHOLE_CONFIGURATION.md](PIHOLE_CONFIGURATION.md) | Pi-hole configuration details |
| [iot-containment.md](iot-containment.md) | Contain cameras/IoT: see + block telemetry (opt-in) |

## Reference

| Doc | What it covers |
|---|---|
| [AUDIT.md](AUDIT.md) | Architecture audit (A–J) and target design |
| [REVIEW.md](REVIEW.md) | Architect + DevSecOps maturity review |

## Operations

- Operational scripts: [../ops/README.md](../ops/README.md)
- Systemd integration: [../systemd/README.md](../systemd/README.md)

> Retired guides (legacy install/upgrade/multi-node duplicates) were removed in
> favour of the above; their history remains in git.
