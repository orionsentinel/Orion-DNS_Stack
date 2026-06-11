# Zero-touch provisioning (cloud-init)

Flash → drop one file → boot → a self-installing DNS node. No typing on the Pi.

This is **Phase 1** of [`docs/provisioning-plan.md`](../docs/provisioning-plan.md):
cloud-init delivers the per-node secrets, then the node clones this repo and runs the
existing [`bootstrap.sh`](../bootstrap.sh). The repo stays the single source of truth —
provisioning adds *delivery*, not a second config system.

## What's here

```
provisioning/
├── README.md
├── firstboot.sh                     # idempotent: clone → seed .env → bootstrap → systemd
└── cloud-init/
    ├── user-data.primary.yaml       # Node A (MASTER, .244)
    ├── user-data.secondary.yaml     # Node B (BACKUP, .245)
    └── user-data.single.yaml        # single node, no HA
```

## Flash workflow (per Pi)

1. **Raspberry Pi Imager** → Raspberry Pi OS **Lite, 64-bit** (the stack is ARM64).
2. In Imager's ⚙️ customization: set the **hostname** (`pi-dns-1` / `pi-dns-2`), enable
   **SSH** (key auth), and set your user — so you can still get in.
3. Copy the matching `cloud-init/user-data.*.yaml` onto the boot partition as
   **`user-data`** (some Imager builds expose a custom cloud-init box; otherwise mount the
   boot partition and copy it by hand).
4. **Edit the two secrets** in that file before first boot:
   - `WEBPASSWORD` — strong, unique, **identical on both nodes**.
   - `VRRP_PASSWORD` — **exactly 8 characters**, **identical on both nodes**.
   Confirm `NODE_IP` / `VIP_ADDRESS` / `NETWORK_INTERFACE` match your LAN
   (see [`docs/networking.md`](../docs/networking.md)).
5. Boot. First boot installs git, clones the repo, writes `.env`, brings the stack up, and
   installs the systemd units. Do the primary first, then the secondary.

The secrets live **only** in `user-data` (on the boot partition / your provisioning
machine) — never committed to git, never baked into an image.

## Verify

From a laptop on the LAN once both nodes are up:

```bash
dig @192.168.8.243 github.com +short        # resolves via the floating VIP
```

On a node: `./scripts/verify-ha.sh` (VIP owner, keepalived state, DNS via VIP + node).

## Re-flash a dead node

cloud-init runs `firstboot.sh`, which is idempotent: drop the same `user-data` on a fresh
card, boot, and the node rejoins itself. You can also re-run it by hand:

```bash
sudo /opt/orion-dns-ha/provisioning/firstboot.sh --env /etc/orion-dns/node.env
```

## Notes & gotchas

- **Boot from NVMe (Pi 5):** set the bootloader to NVMe-first (`raspi-config` → Advanced →
  Boot Order) so the Pi boots the SSD, not an empty SD slot.
- **First-boot network:** cloud-init needs the network up before `git clone`. DHCP is
  simplest — reserve `.244`/`.245` on your router. For a static IP without DHCP, add a
  cloud-init `network-config` (a separate file) or pin it post-boot with
  `make configure-nic`.
- **Rotate placeholders:** after first boot, rotate anything that started as a placeholder
  and store it in a password manager.

## Phase 2 — pre-baked image (future)

A CI-built Pi OS image with the repo + Docker + images **pre-pulled** (via `pi-gen`),
published as a signed GitHub Release, would cut first boot to seconds. It's a polish
milestone — not built yet. See [`docs/provisioning-plan.md`](../docs/provisioning-plan.md)
for the design.
