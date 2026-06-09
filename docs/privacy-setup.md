# Privacy Setup — do this in order

The final recommendation, highest-ROI first. Do them top to bottom; each step
assumes the previous. Commands are copy-paste ready (run from the repo root on the
**primary** node unless noted). Canonical addresses: nodes `.244`/`.245`, VIP `.243`.

> **Reality check (read first):** DNS blocking kills *third-party* trackers,
> telemetry, smart-TV junk and malware. It **cannot** block *first-party* in-app
> ads (YouTube, Instagram, Facebook, Spotify serve ads from their content
> domains). If ads persist in those specific apps after all this, that's a DNS
> limit, not a misconfig. See `troubleshooting.md`.

## 1. Block iCloud Private Relay — #1 fix for "ads still on iPhone"

Private Relay routes Safari's DNS around Pi-hole, so your blocklists never apply.
Block its ingress domains so iOS falls back to *your* DNS:

```bash
./scripts/block-private-relay.sh          # applies + backs up gravity.db
./scripts/pihole-sync.sh                  # replicate to the secondary
```

Then on each iPhone: **Settings → [your name] → iCloud → Private Relay** will show
"unavailable on this network" (expected). Also **Wi-Fi → (i) → turn OFF "Limit IP
Address Tracking"** (it uses the same relay).

## 2. Make devices actually use your DNS (router enforcement)

At the **router** (this matters more than any blocklist):
1. **DHCP DNS = `192.168.8.243` only.** Remove any secondary (e.g. `1.1.1.1`) —
   clients treat it as equal and bypass Pi-hole.
2. **Point the router's own upstream** at `192.168.8.243`; disable its built-in DNS/DoH.
3. **Redirect** all outbound `:53` (UDP/TCP) → `192.168.8.243` (catches hardcoded
   `8.8.8.8`/`1.1.1.1`).
4. **Block** outbound `:853` (DoT) and known DoH resolver IPs.
5. **IPv6:** hand out the VIP over IPv6 *or* disable IPv6 DNS — else phones bypass
   over v6.

Full router syntax + examples: `client-network-setup.md`.

## 3. Better blocklists — Hagezi Multi PRO + TIF

Two curated lists beat thirty random ones (less overlap, fewer false positives):

```bash
./scripts/setup-blocklists.sh             # defaults to Hagezi Multi PRO + TIF
./scripts/pihole-sync.sh
```

Pi-hole updates gravity weekly on its own. For false positives: Pi-hole admin →
Tools → Query Log → whitelist the domain (keep the allowlist small).

## 4. Contain the IoT / cameras (optional, high visibility)

See what your Tapo cams phone home to, then block telemetry without breaking them:

```bash
./scripts/setup-iot-containment.sh        # dry-run; review, then --apply
```

Details + the observe-first workflow: `iot-containment.md`.

---

## Final recommendation — what to run

For a home network optimising **privacy ↑ / ads ↓ / maintenance ↓**:

- **2× Raspberry Pi 5**, NVMe SSD (HAT), each running the canonical stack:
  Pi-hole + Unbound (recursive, DNSSEC, ARM64 `2026.05.0`) + keepalived VRRP + autoheal.
- **One VIP** (`192.168.8.243`) handed out by DHCP; router-enforced as above.
- **Hagezi Multi PRO + TIF**; **Private Relay blocked**; **IoT contained**.
- **No monitoring/observability stack** — Pi-hole's admin page is the dashboard.
- **Nightly backups** (`make backup`) off-box; rebuild a node in <1h
  (`disaster-recovery.md`).

That's the whole thing. Resist adding more — every extra service is maintenance
and attack surface for little privacy gain.

## What this can't do (be honest)

- First-party in-app ads (YouTube/IG/FB/Spotify) — DNS can't touch them.
- Apps with built-in DoH (some Google apps) — only the router `:53`/DoH blocks help,
  and ECH/DoH-over-443 to a shared CDN can still leak.
- On-device VPNs route around you entirely.
- Blocking a shared CDN domain can break an app — keep an allowlist and test.
