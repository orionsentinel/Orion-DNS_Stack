# Scripts Reference

Helper scripts for the Orion Sentinel HA DNS stack. Most are invoked for you by
`bootstrap.sh` or the `Makefile` — you rarely need to call them directly.

> Installation is **one command**: `./bootstrap.sh` (guided) or `./bootstrap.sh --role <role> --yes`
> (non-interactive). There is no web UI, GUI installer, or multi-stack installer — just the
> single-file `.env` and `docker compose`. See the repo [README](../README.md) and
> [docs/two-pi-quickstart.md](../docs/two-pi-quickstart.md).

## Setup & configuration

| Script | Purpose |
|--------|---------|
| `configure-env.sh` | Guided, role-aware first-time configuration of `.env` (IPs, interface, timezone, web + 8-char VRRP passwords). Run by `bootstrap.sh` on an interactive terminal; also `make configure`. No-op when non-interactive. |
| `configure-nic.sh` | Bring a Pi's USB-C / 2.5–10G NIC up on a fixed static IP that survives reboots. `make configure-nic` / `make list-nics`. |
| `bootstrap_dirs.sh` | Create the host data directories and log files the stack expects (avoids "Is a directory" bind-mount errors) before first `up`. |

## Validation & health

| Script | Purpose |
|--------|---------|
| `validate-env.sh` | Preflight check of a node's `.env` — required keys, placeholder detection, exactly-8-char VRRP, IPv4 validity, peer reachability, interface existence. Run by `bootstrap.sh` and `make up-core` before bringing the stack up. |
| `selfcheck.sh` | Quick pre-deploy validation: compose parses, env template present, data dirs scaffolded. `make selfcheck`. |
| `health-check.sh` | Container + DNS health check; run weekly via cron. `make health-check`. |

## High availability

| Script | Purpose |
|--------|---------|
| `verify-ha.sh` | Report HA state — which node holds the VIP, keepalived status/config, DNS resolution via VIP and node IP. |
| `test-failover.sh` | Integration test for VRRP failover: takes this node's DNS down and verifies the VIP floats to the peer and back. `make test-failover`. |
| `pihole-sync.sh` | SSH-based one-way sync of Pi-hole config from primary to secondary (run on a systemd timer / cron on the primary). |

## Blocklists & privacy

| Script | Purpose |
|--------|---------|
| `setup-blocklists.sh` | Install the curated blocklist set into Pi-hole v6. `make setup-blocklists`. |
| `setup-whitelist.sh` | Apply the essential allowlist so common services don't break from over-blocking. |
| `block-private-relay.sh` | Block iCloud Private Relay so iPhones can't route DNS around Pi-hole. `make block-private-relay`. |
| `setup-iot-containment.sh` | Create a Pi-hole "IoT" group and apply telemetry-deny regex to cameras/IoT devices only. |
| `pihole-auto-update.sh` | Update Pi-hole gravity/blocklists on a schedule. |

## Conventions

- All scripts are `bash`, pass `shellcheck --severity=error`, and read configuration from the
  repo-root `.env`.
- Prefer the `Makefile` targets where one exists (`make help` lists them) — they wire in the
  right script with the right environment.
