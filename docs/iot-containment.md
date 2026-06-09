# IoT Containment

Your cameras and smart-home gear phone home constantly. This puts them in a
dedicated Pi-hole **group** so you can (1) **see** exactly what they contact and
(2) **block their telemetry** without breaking core function.

> Philosophy: **observe first, block deliberately.** Over-blocking can break
> features (Tapo remote view, firmware updates), so this is opt-in, dry-run by
> default, and fully reversible.

## 1. See what your devices do (no blocking yet)

Once the devices resolve through the VIP (`client-network-setup.md`), look at
their traffic:

- **Pi-hole UI** → Query Log → filter by the device IP (e.g. `192.168.8.100`).
- **Grafana / Loki** (if the monitoring stack is up) — query the Pi-hole log
  stream by client:
  ```
  {job="pihole"} |= "192.168.8.100"
  ```
  A panel of *top domains per IoT client* shows the phone-home endpoints.

Note which hostnames are **telemetry/analytics** (safe to block) vs **functional**
(cloud relay, firmware — keep).

## 2. Apply the containment group

Dry-run first (prints the exact SQL, changes nothing):

```bash
./scripts/setup-iot-containment.sh
```

Review it, then apply on the **primary** node (backs up `gravity.db` first):

```bash
./scripts/setup-iot-containment.sh --apply
./scripts/pihole-sync.sh            # replicate to the secondary
```

This creates an `IoT` group, adds the devices from `profiles/iot.yml` as clients
(in the IoT group **and** the default group, so base blocking still applies), and
attaches a **conservative telemetry-deny regex** to the IoT group only.

## 3. Test, then tighten

After applying:
- Exercise each device (Tapo app, live view, etc.). If something breaks, add its
  essential hostname to the `allow` list in `profiles/iot.yml` (and the script),
  or run `--remove --apply` to back out.
- From step 1's observations, add the specific analytics hostnames you saw to the
  regex/deny list, then re-apply (idempotent).

## 4. Revert

```bash
./scripts/setup-iot-containment.sh --remove --apply
```

Or restore the timestamped `gravity.db.<ts>.bak` the script left in the container.

## What's blocked by default

A deliberately small starter set (`profiles/iot.yml`): `telemetry.`, `metrics.`,
`analytics.`, `tracking.`, `data-collect*`, and `tplinkra.com`. It intentionally
does **not** block `*.tplinkcloud.com` (that path carries Tapo remote access).
Tighten from your own logs rather than blanket-blocking a vendor's cloud.

## Why bother

These devices are the least trustworthy things on your LAN and the most likely to
exfiltrate. Containing them turns "mystery traffic" into a reviewed allowlist, and
every block is visible in Grafana — a concrete step toward the NSM goals in
`REVIEW.md`.
