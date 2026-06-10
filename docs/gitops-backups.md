# GitOps Convergence & Off-Box Backups

Two optional, opt-in capabilities that make the fleet self-maintaining: nodes
**converge to the repo's declared state** on a timer, and backups go **encrypted,
off-box** automatically. Both are off until you configure them.

## GitOps convergence — the repo is the source of truth

`ops/converge.sh` (`make converge`) fetches a ref, fast-forwards, re-applies the
stack, and **rolls back automatically if DNS breaks**. Run on a timer, drift
becomes impossible — a node always matches what's in git.

**Safety (built in):**
- aborts if the working tree is dirty (won't clobber local edits),
- **fast-forward only** (no surprise merges),
- `docker compose config -q` validates *before* applying,
- after `up -d` it verifies DNS answers; if not, it **resets to the previous
  commit and brings the known-good stack back**.

**Configure** (in `.env`):
```bash
CONVERGE_REF=main        # track latest …or pin to a release TAG for production:
# CONVERGE_REF=v2.6.0
```
> **Recommended for production:** pin `CONVERGE_REF` to a **tag** you promote
> deliberately, not `main`. Then "deploy to the fleet" = push a tag, and every node
> converges to it on its next timer — with automatic rollback if it misbehaves.

**Enable the timer** (per node):
```bash
sudo cp systemd/orion-dns-ha-converge.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-converge.timer   # daily, randomized delay
# one-off now:  make converge
```

## Off-box encrypted backups (restic)

The existing backup (`ops/orion-dns-backup.sh` / `make backup`) now **also pushes
the snapshot off-box via [restic](https://restic.net)** — *only* if
`RESTIC_REPOSITORY` is set. Encrypted, deduplicated, with retention. Off-box is
what turns "my Pi died / SD-card—err, NVMe—failed / I fat-fingered Pi-hole" into a
non-event.

**Install restic** (once, per node): `sudo apt-get install -y restic`

**Configure** (in `.env`):
```bash
# Pick a backend (restic supports SFTP, S3, B2, rclone, …):
RESTIC_REPOSITORY=sftp:backups@nas.lan:/volume1/orion     # NAS over SSH
# RESTIC_REPOSITORY=b2:my-bucket:orion                    # Backblaze B2
RESTIC_PASSWORD=<a strong passphrase you keep safe>       # encrypts the repo
RESTIC_KEEP_DAILY=7
RESTIC_KEEP_WEEKLY=4
```
> Keep `RESTIC_PASSWORD` in your password manager — **without it the backups are
> unrecoverable** (that's the point of encryption). For B2/S3 also export the
> provider credentials (e.g. `B2_ACCOUNT_ID`/`B2_ACCOUNT_KEY`) in the environment.

The backup runs on the existing `orion-dns-ha-backup.timer`; off-box happens in the
same run. Restore: `restic snapshots`, then `restic restore <id> --target /tmp/r`
and feed the tarball to `ops/orion-dns-restore.sh` (see `disaster-recovery.md`).

## How they fit together

```
push a tag ──► nodes converge (rollback-safe) ──► daily backup ──► off-box (restic)
                                  ▲                                      │
                                  └──────────── self-heals to declared state
```

Both are **optional and isolated**: leave `RESTIC_REPOSITORY` blank for local-only
backups, and don't enable the converge timer if you'd rather upgrade by hand
(`git pull && make update`). Nothing here runs unless you turn it on.
