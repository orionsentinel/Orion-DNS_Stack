# One-Flash Provisioning — Plan

**Goal:** flash NVMe → plug in → working DNS node in **<10 minutes, zero typing**.
A dead Pi becomes "reflash and it rejoins itself." This is the plan; nothing here
is built yet (it's a design + starter snippets).

## Principles

- **No secrets baked into images.** Secrets arrive per-node at first boot (cloud-init
  user-data) or from a small file, never committed.
- **The repo stays the source of truth.** First boot just `git clone`s and runs the
  existing `bootstrap.sh` — provisioning adds *delivery*, not a second config system.
- **Idempotent.** Re-running first-boot (or a reflash) converges to the same state.
- **Boring tools.** Raspberry Pi Imager + cloud-init first; a custom image only if Phase 1 isn't enough.

## Approach comparison

| Approach | Effort | "Amazing" factor | Verdict |
|---|---|---|---|
| **A. Imager first-boot / cloud-init** (clone repo + bootstrap on first boot) | Low | High | **Recommended (Phase 1)** — achievable now, no image pipeline. |
| **B. Pre-baked image** (`pi-gen`/`rpi-image-gen` in CI, repo + Docker baked in) | High | Highest | Phase 2 — true "flash & go", but a CI image pipeline to maintain. |
| C. `ansible-pull` on first boot | Medium | Medium | Overkill — reintroduces a config system we deliberately don't have. |

## Phase 1 — cloud-init first-boot (do this first)

Raspberry Pi OS Bookworm supports a `firstrun.sh` injected by Imager, and `cloud-init`
via user-data. Either works; cloud-init is cleaner.

**Flash workflow (per Pi):**
1. Raspberry Pi Imager → choose Pi OS Lite 64-bit → ⚙️ customization: hostname
   (`pi-dns-1`/`pi-dns-2`), enable SSH (key), set user.
2. Drop a per-node `user-data` (below) onto the boot partition (Imager's "custom"
   or by hand).
3. Boot. First-boot installs git, clones the repo, writes `.env` from the cloud-init
   secrets, and runs `bootstrap.sh`.

**`provisioning/cloud-init/user-data.primary.yaml` (starter):**
```yaml
#cloud-config
package_update: true
packages: [git, ca-certificates]
write_files:
  - path: /opt/orion-dns-ha.env          # secrets delivered per-node, NOT in git
    permissions: '0600'
    content: |
      NODE_IP=192.168.8.244
      NODE_ROLE=MASTER
      KEEPALIVED_PRIORITY=200
      VIP_ADDRESS=192.168.8.243
      NETWORK_INTERFACE=eth0
      PEER_IP=192.168.8.245
      UNICAST_SRC_IP=192.168.8.244
      WEBPASSWORD=CHANGE_ME
      VRRP_PASSWORD=CHANGE_8c
      TZ=Europe/Athens
runcmd:
  - [ git, clone, "https://github.com/orionsentinel/Orion-DNS_Stack.git", /opt/orion-dns-ha ]
  - [ bash, -c, "install -m600 /opt/orion-dns-ha.env /opt/orion-dns-ha/.env" ]
  - [ bash, -c, "cd /opt/orion-dns-ha && ./bootstrap.sh --role primary --yes" ]
  - [ bash, -c, "cd /opt/orion-dns-ha && make install-systemd-primary" ]
```
(Secondary is identical with `.245` / `BACKUP` / priority `150` / mirrored peer IPs,
and `--role secondary` / `install-systemd-secondary`.)

**Files to add for Phase 1:**
```
provisioning/
├── README.md
├── cloud-init/
│   ├── user-data.primary.yaml      # template (placeholder secrets)
│   └── user-data.secondary.yaml
└── firstboot.sh                    # optional: the runcmd logic as one script
```
`bootstrap.sh` already supports `--role` and `--yes` (non-interactive), so the only
new code is delivery + the cloud-init templates.

## Phase 2 — pre-baked image (the "wow")

A GitHub Actions workflow builds a Pi OS image with the repo + Docker + images
**pre-pulled**, using `pi-gen` (official) or `rpi-image-gen`. Output: a `.img.xz`
attached to a GitHub Release. Flash it, drop per-node cloud-init for secrets, boot.
First boot is then seconds (no clone, no docker pull).

- **Build:** `pi-gen` stage that `git clone`s this repo into `/opt/orion-dns-ha`,
  installs Docker, and `docker compose pull`s the canonical images.
- **Release:** `softprops/action-gh-release` (SHA-pinned) uploads the image + its
  SHA256 + a cosign signature (ties into the supply-chain work).
- **Secrets:** still per-node via cloud-init — never in the image.

## Secrets handling (both phases)

- Per-node `.env` arrives via cloud-init user-data (which lives on the boot
  partition / your provisioning machine, not git).
- `VRRP_PASSWORD` must be **exactly 8 chars and identical on both nodes**.
- After first boot, rotate anything that was a placeholder; store in a password manager.

## Verification (first boot)

`bootstrap.sh` already runs `verify-ha.sh`. Add a one-line cloud-init final check:
```yaml
  - [ bash, -c, "cd /opt/orion-dns-ha && ./scripts/verify-ha.sh || true" ]
```
And confirm from a laptop: `dig @192.168.8.243 github.com +short`.

## Risks / decisions

- **Boot from NVMe:** ensure the Pi 5 bootloader is NVMe-first (`raspi-config` →
  Boot Order) — bake into the image in Phase 2.
- **First-boot network:** cloud-init needs DHCP up before `git clone`. Pi OS handles
  this; for static-IP nodes, set the IP via cloud-init `network:` before `runcmd`.
- **Image freshness (Phase 2):** rebuild the image on a schedule so pre-pulled
  images don't rot; Dependabot/Renovate already track the tags.

## Recommendation

Ship **Phase 1** now (cloud-init templates + `provisioning/README.md`) — it delivers
90% of the "flash and go" with ~20 lines of YAML and zero new moving parts. Treat
**Phase 2** (baked image + signed release) as a polish milestone if you end up
reflashing often or want to hand the image to someone else.
