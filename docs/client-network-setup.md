# Client & Network Setup

How to make the rest of your LAN actually use the HA DNS — and how to stop devices
sneaking around it. The one rule: **everything resolves through the VIP
`192.168.8.243`.**

## 1. Router DHCP → the VIP (do this first)

In your router's LAN/DHCP settings, set the **DNS server handed to clients** to:

```
Primary DNS:   192.168.8.243      (the VIP)
Secondary DNS: (leave empty)
```

> Do **not** add a second DNS server (e.g. `1.1.1.1`). Clients treat both as
> equal and will randomly bypass Pi-hole via the secondary. One entry only.

Renew leases (or reboot clients) so they pick up the new DNS.

## 2. Point the router itself at the VIP

Set the router's **own upstream/resolver** to `192.168.8.243` too, and **disable
the router's built-in DNS forwarder / DoH** if it has one. Otherwise the router
answers DNS itself and your devices never reach Pi-hole.

## 3. Catch the escapees (devices with hardcoded DNS)

Phones, smart TVs and some IoT gear ship with hardcoded resolvers (e.g.
`8.8.8.8`). Force them through the VIP with a router firewall rule that redirects
all outbound port 53 to the VIP (syntax is router-specific; concept is the same):

```
# Redirect LAN → :53 (TCP/UDP) to 192.168.8.243, except queries already to the VIP.
# OpenWrt example:
iptables -t nat -A PREROUTING -i br-lan ! -d 192.168.8.243 -p udp --dport 53 -j DNAT --to 192.168.8.243
iptables -t nat -A PREROUTING -i br-lan ! -d 192.168.8.243 -p tcp --dport 53 -j DNAT --to 192.168.8.243
```

## 4. IPv6 — the usual bypass

If your LAN has IPv6, a device can ignore your IPv4 DNS and resolve over IPv6.
Pick one:

- **Hand out the VIP over IPv6** (advertise the node/VIP as the DNS server via
  DHCPv6 / RDNSS in your router's IPv6 settings), **or**
- **Disable IPv6 DNS** on the LAN (turn off IPv6 RA DNS / DHCPv6 DNS) so devices
  fall back to your IPv4 VIP.

Leaving IPv6 DNS pointing at your ISP is the most common reason "Pi-hole isn't
blocking anything" on phones.

## 5. Encrypted DNS (DoH/DoT) — the iPhone problem

Browsers and iOS/Android can use their own DoH/DoT and skip your DNS entirely.

**iCloud Private Relay is the big one** (it's why ads still show on iPhones). Block
its ingress domains so Safari falls back to your DNS — one command:

```bash
./scripts/block-private-relay.sh && ./scripts/pihole-sync.sh
```

Then on each iPhone, Private Relay shows "unavailable on this network" (expected),
and turn off Wi-Fi → (i) → "Limit IP Address Tracking". See `privacy-setup.md`.

Other DoH bypass:
- Pi-hole already blocks the Firefox canary (`use-application-dns.net`), nudging
  it off DoH.
- Block known public DoH endpoints at the router/Pi-hole (there are maintained
  blocklists for this).

Verify a device is actually filtered:

```bash
# From the client:
dig @192.168.8.243 doubleclick.net +short    # expect 0.0.0.0 (blocked)
nslookup flurry.com                            # uses the client's configured DNS
```

## 6. Static clients / servers

For anything with a static config, set DNS to `192.168.8.243`. If you want a host
reachable by name, add it as a Local DNS record in Pi-hole (Admin → Local DNS) —
both nodes serve it once synced.

## 7. Reverse DNS / local domain

`REV_SERVER` is enabled by default (`.env`), so `192.168.8.x` → router for local
name resolution and the `lan` domain. Adjust `REV_SERVER_*` if your domain
differs.

## 8. Smart-home / IoT note

Your Tapo cameras and other IoT devices phone home constantly. Once they resolve
through the VIP you can see (and block) that traffic in Pi-hole's query log — a good first step toward containing them (see
docs/iot-containment.md).
