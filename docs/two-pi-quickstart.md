# Two-Pi Quickstart

End-to-end setup of the full HA DNS stack on two Raspberry Pis, in one page.
Addresses use the canonical scheme (`networking.md`): Node A `192.168.8.244`,
Node B `192.168.8.245`, floating VIP `192.168.8.243`, gateway `.1`.

> **Prefer zero typing?** Flash each Pi with a per-node cloud-init file and the node
> installs itself on first boot — see [`../provisioning/README.md`](../provisioning/README.md).
> The guided manual flow below is the alternative.

## Prerequisites

**Hardware (per node):**
- Raspberry Pi 4 or 5, 4 GB+ RAM.
- **Boot from the NVMe SSD (HAT)** — reliable, no SD-card wear-out.
- Wired Ethernet. (Optional: a USB-C / USB 2.5–10 G NIC — see `networking.md`.)

**OS & software:**
- Raspberry Pi OS **Bookworm, 64-bit** (Lite is fine). 64-bit is required — the
  stack is ARM64.
- `bootstrap.sh` installs Docker + the compose plugin; you just need `git`
  (and `sudo`).

**Network:**
- Three addresses free on the LAN: `.244`, `.245` (nodes) and `.243` (VIP).
  Reserve `.244`/`.245` as DHCP reservations (or set static — `make configure-nic`).
- A router where you can set the DHCP "DNS server" option (and ideally add a
  NAT/redirect rule). Unicast VRRP is used, so multicast is not required.

**Optional extras:**
- Key-based SSH between the nodes (for Pi-hole config sync).
- A spare phone number registered with signal-cli (for Signal alerts).

## 1. Prepare both Pis

Flash Pi OS 64-bit to each Pi's SSD, enable SSH, boot, and update:

```bash
sudo apt update && sudo apt full-upgrade -y && sudo reboot
```

Give each Pi its address (`.244` on Node A, `.245` on Node B) via a DHCP
reservation, or pin it:

```bash
sudo ./scripts/configure-nic.sh --iface eth0 --ip 192.168.8.244/24 --gateway 192.168.8.1
```

## 2. Node A — primary

```bash
sudo apt update
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha
sudo ./bootstrap.sh --role primary
```

`bootstrap.sh` seeds `.env` from the primary template and then **walks you through the
handful of values that matter** — IPs, interface, timezone, web password, and the
8-char VRRP password (hidden, with confirmation). It validates each, runs a preflight
check, and brings the stack up. (Prefer editing by hand? Run
`sudo ./bootstrap.sh --role primary --yes` after `nano .env`, or just press Enter
through the prompts to accept the defaults.)

## 3. Node B — secondary

Same, on the second Pi, with the **secondary** role. The wizard reminds you that
`WEBPASSWORD` and `VRRP_PASSWORD` must be the **same** as Node A:

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git /opt/orion-dns-ha
cd /opt/orion-dns-ha
sudo ./bootstrap.sh --role secondary       # guided: enter NODE_IP=192.168.8.245 + matching secrets
```

## 4. Verify HA

On either node:

```bash
./scripts/verify-ha.sh                     # VIP owner, keepalived state, DNS via VIP + node
dig @192.168.8.243 github.com +short       # resolves via the VIP
make test-failover                         # forces a failover and confirms recovery (on MASTER)
```

Expected: Node A holds the VIP (state MASTER); stopping it moves the VIP to Node B
and DNS keeps resolving.

## 5. Point your network at it

Set your router's DHCP "DNS server" to the **VIP `192.168.8.243`**. Full client +
router + IPv6 details: **[client-network-setup.md](client-network-setup.md)**.

## 6. Optional add-ons

- **"Is DNS up?" (optional):** Pi-hole's admin page is your dashboard. For an
  external check, run a single Uptime-Kuma container elsewhere pointed at the VIP.
- **Automated backups + boot persistence:** install the systemd timers — see
  [disaster-recovery.md](disaster-recovery.md) and `../systemd/README.md`.
- **Pi-hole config sync** (primary → secondary): `scripts/pihole-sync.sh` + timer.

## Trouble?

See [troubleshooting.md](troubleshooting.md) (split-brain, VIP not assigned,
device bypass, NIC flapping). Rebuild a dead node: [disaster-recovery.md](disaster-recovery.md).
