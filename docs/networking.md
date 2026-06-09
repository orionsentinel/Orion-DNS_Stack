# Networking

The single source of truth for addressing in this stack. Every compose default,
env template, and doc uses this scheme. Change it in one place — your `.env`
files — not in the code.

## Canonical address plan

| Role | Hostname | IP | Notes |
|---|---|---|---|
| LAN / subnet | — | `192.168.8.0/24` | Home LAN |
| Router / gateway | — | `192.168.8.1` | Upstream + `REV_SERVER_TARGET` |
| **Node A (MASTER)** | `pi-dns-1` | `192.168.8.244` | Pi-hole + Unbound, keepalived priority 200 |
| **Node B (BACKUP)** | `pi-dns-2` | `192.168.8.245` | Pi-hole + Unbound, keepalived priority 150 |
| **Floating VIP** | — | `192.168.8.243` | VRRP-managed; **clients point here** |

> Point your router's DHCP "DNS server" option at the **VIP `192.168.8.243`**, not
> at a node IP. The VIP always lives on whichever node is currently MASTER.

## VRRP

- Unicast VRRP (`USE_UNICAST_VRRP=true`) — recommended on a LAN where multicast is
  unreliable. Each node lists the other as `PEER_IP`.
- `VIRTUAL_ROUTER_ID=51` must match on both nodes and be unique on the LAN.
- `VRRP_PASSWORD` must be **exactly 8 characters** and identical on both nodes
  (a hard VRRP PASS-auth limit; the container refuses to start otherwise).
- `NETWORK_INTERFACE=eth0` — the Pi's onboard NIC. If you use a USB NIC for a
  dedicated VRRP link, set it to that interface (e.g. `eth1`) in both `.env` files.

## Ports

| Port | Service | Where |
|---|---|---|
| 53/tcp+udp | DNS (Pi-hole) | both nodes + VIP |
| 80/tcp | Pi-hole admin UI | each node IP |
| 5335/udp | Unbound (local recursive) | localhost only |
| 9100 / 9617 / 9080 | node / pihole / promtail exporters | `exporters` profile |

## Verifying clients actually use the VIP

A known failure mode is a device (notably iPhones) bypassing your DNS via its own
DoH/DoT. To verify and enforce:

```bash
# From a client, confirm resolution goes through the VIP:
dig @192.168.8.243 github.com +short

# On the router, force all LAN DNS to the VIP by redirecting outbound :53
# (exact syntax is router-specific) and block known DoH endpoints.
```

See `docs/troubleshooting.md` → "iPhone / device bypasses DNS".

## Reserved / known LAN devices

These are static hosts on the LAN; keep them out of the DNS node / VIP range
(`.243`–`.245`) when assigning addresses.

| Device | IP |
|---|---|
| Tapo C220 (hallway) | `192.168.8.100` |
| Tapo D210 | `192.168.8.107` |
| Tapo C400 | `192.168.8.137` |
| Tapo C410 | `192.168.8.142` |

(Plus the Philips Hue hub and assorted Hue lights/plugs via the Hue bridge.)
