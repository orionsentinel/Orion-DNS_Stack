# Architecture

Two-node, high-availability recursive DNS for the home LAN. Ad/tracker blocking
(Pi-hole) in front of a privacy-first local resolver (Unbound), with a floating
VIP (Keepalived/VRRP) so DNS survives a node failure or reboot.

```
                 Clients (router DHCP hands out the VIP as DNS)
                                  │
                          VIP 192.168.8.243  (VRRP)
                                  │
            ┌─────────────────────┴─────────────────────┐
            ▼                                            ▼
   Node A  pi-dns-1 192.168.8.244            Node B  pi-dns-2 192.168.8.245
   keepalived  priority 200  MASTER  ◄── unicast VRRP ──►  priority 150  BACKUP
            │                                            │
   ┌────────┴────────┐                          ┌────────┴────────┐
   │ pihole_unbound  │                          │ pihole_unbound  │
   │  Pi-hole :53    │                          │  Pi-hole :53    │
   │  Unbound :5335  │                          │  Unbound :5335  │
   └─────────────────┘                          └─────────────────┘
            │                                            │
            └──────────► root DNS servers (DNSSEC) ◄─────┘
```

## Components

- **`pihole_unbound`** — one unified container,
  `ghcr.io/mpgirro/docker-pihole-unbound:2026.05.0` (ARM64-safe, replaces the old
  `mvance/unbound-rpi` that failed on 64-bit Pi OS). Pi-hole listens on `:53` and
  forwards to Unbound on `127.0.0.1#5335` for full local recursive resolution
  with DNSSEC. `network_mode: host`, `restart: unless-stopped`.
- **`keepalived`** — custom build in `./keepalived`. Runs VRRP, owns the VIP, and
  health-checks DNS every 5s (`check_dns.sh`); demotes to BACKUP on failure so the
  peer takes the VIP. Validates its config strictly at start (8-char VRRP_PASSWORD,
  peer IPs) to prevent split-brain.
That's the entire stack — three containers. No metrics/observability stack by
design: Pi-hole's own admin page is the dashboard, and keepalived handles
failover. (Optionally run a single Uptime-Kuma container elsewhere if you want
an external "is DNS up?" check — not part of this repo.)

## Compose profiles

| Profile | Brings up | Run on |
|---|---|---|
| `single-node` | pihole_unbound only | a single Pi (no HA) |
| `two-node-ha-primary` | pihole_unbound + keepalived (MASTER) | Node A |
| `two-node-ha-backup` | pihole_unbound + keepalived (BACKUP) | Node B |

```bash
# Node A
docker compose --profile two-node-ha-primary up -d
# Node B
docker compose --profile two-node-ha-backup up -d
```

## Data & persistence

Bind-mounted under the repo so a backup of the repo dir + `pihole/` captures all
state:

- `pihole/etc-pihole/` — gravity DB, blocklists, settings, custom DNS
- `pihole/etc-dnsmasq.d/` — dnsmasq config
- `pihole/var-log/` — query logs
- `keepalived/config/` — generated keepalived.conf + notify scripts (runtime)

See `docs/disaster-recovery.md` for backup/restore and the <1h rebuild target.

## Self-healing

Recovery is layered — each layer covers a different failure mode, so there is no
bespoke "self-healing service" to maintain:

| Layer | Mechanism | Heals |
|---|---|---|
| 1. Crash | `restart: unless-stopped` on every service | a container that exits/crashes |
| 2. Wedged | Docker **healthcheck** + **`autoheal`** sidecar | a container that's running but stopped answering (`pihole_unbound` is `autoheal`-labelled; its probe is `dig @127.0.0.1 pi.hole`) |
| 3. DNS broken | **keepalived** `check_dns.sh` → VIP failover | recursion/DNS failure on a node → VIP floats to the healthy peer |
| 4. Reboot / host | **systemd** units + timer (`ops/orion-dns-health.sh`, hourly/min) | survives reboot; host-level watchdog restart |

Notes:
- `autoheal` only restarts containers labelled `autoheal=true`. **keepalived is
  deliberately not labelled** — restarting it would flap the VIP; it self-heals by
  releasing the VIP instead.
- Tunables (in `.env`): `AUTOHEAL_INTERVAL`, `AUTOHEAL_START_PERIOD`. The probe is
  forgiving (`retries: 5`, `start_period: 90s`) so transient blips don't trigger
  restarts.
- No alerting stack by design (kept simple). If you want an external heads-up,
  point a single Uptime-Kuma instance (or healthchecks.io) at the VIP — the four
  layers above handle recovery; that just tells you if everything failed at once.

## Design choices (trade-offs)

- **Unified Pi-hole+Unbound image** over separate containers: fewer moving parts
  and it fixed the ARM64 failure; you give up independent Unbound control, which is
  an acceptable trade for a 2-node home setup (robustness > flexibility).
- **VRRP/Keepalived** over app-level failover: kernel-level, fast, no extra daemon
  logic to debug; the floating VIP is transparent to clients.
- **Local recursion** (Unbound to root) over a public upstream: privacy by default;
  optional NextDNS DoT forwarding is available in `unbound/nextdns-forward.conf`.
