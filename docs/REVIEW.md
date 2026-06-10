# Architecture & DevSecOps Review (current)

> Re-review after the simplification + second-layer cleanup. Companion to
> `docs/AUDIT.md` (the original drift catalogue — kept as a historical record).
> Hats: **architect** (sound, reproducible?) and **DevSecOps** (secure, operable
> with minimal babysitting?).

## TL;DR

The repo is a **lean, boring, reliable privacy appliance** — exactly the goal.
From 466 files / 9 stacks / 49 scripts / 11 services down to **74 files / 0 extra
stacks / 14 scripts / 3 containers** (`pihole_unbound` + `keepalived` + `autoheal`).
The risky phase is long over; the second-layer dead config and tool duplication are
now gone too. What remains is **two operator clicks** and **GitHub branch hygiene**.

## Maturity scorecard

| Dimension | Orig | Now | Note |
|---|:--:|:--:|---|
| Reproducibility (IaC) | 🔴 | 🟢 | `git clone → ./bootstrap.sh → working node`; 3-service compose. |
| Footprint / clarity | 🔴 | 🟢 | 466 → 74 files. Subtraction did its job. |
| CI/CD | 🔴 | 🟢 | compose/ARM64/Trivy/secret/docs gates + Dependabot **auto-merge**. |
| Supply chain | 🔴 | 🟢 | Actions SHA-pinned; images tag-pinned + Dependabot (docker/actions). |
| Documentation | 🔴 | 🟢 | 16 canonical docs incl. the do-this-in-order `privacy-setup.md`. |
| HA / resilience | 🟢 | 🟢 | VRRP (8-char pass, unicast, split-brain guards) + healthchecks + autoheal + `make test-failover`. |
| Governance | 🔴 | 🟢 | CODEOWNERS, PR template, SECURITY.md, branching strategy, auto-merge. |
| Secrets mgmt | 🔴 | 🟡 | CI secret-gate solid; **rotation still owed (operator)**. |

🔴 weak · 🟡 partial · 🟢 solid

## What's good (keep it)

- **Right primitives, minimum parts.** One unified ARM64 Pi-hole+Unbound image
  (recursive, DNSSEC), VRRP floating VIP, `autoheal` for wedged containers. Three
  containers, host networking, tight caps.
- **Layered self-healing** — `restart: unless-stopped` → healthcheck+autoheal →
  keepalived VIP failover → systemd. No bespoke daemon.
- **Privacy-first** — local recursion, the iCloud Private Relay block, Hagezi
  Multi PRO + TIF, IoT containment, router-enforcement docs.
- **CI is the guardrail** — every change is validated; Dependabot keeps deps/images
  current and auto-merges when green.

## What's left

### P0 — operator (the only real gaps)
1. **Rotate the historically-exposed secrets** (`VRRP_PASSWORD`, `WEBPASSWORD`,
   Pi-hole API password). They persist in git history.
2. **Enable branch protection on `main` + "Allow auto-merge"** (Settings → Branches
   / General). This also activates the hands-off Dependabot merging already built.

### P1 — hygiene
3. **Prune ~54 stale `copilot/*` / `alert-autofix-*` branches** + the merged
   `claude/*` branches. (No code impact; pure tidiness.)
4. **Slim `README.md`** (~740 lines) — the manual two-node steps duplicate
   `docs/two-pi-quickstart.md`. Trim to: what-it-is, quick start, links to `docs/`.

### P2 — optional
5. **Secrets at rest** — `.env` is plaintext on the NVMe. Fine for a home LAN;
   SOPS/age or Docker secrets is available if you want it.
6. Graduate Trivy **misconfig** + **shellcheck** from advisory to blocking now the
   tree is clean.

## DevSecOps notes (current)

- **Attack surface is small and correct.** Host networking is required for VRRP;
  caps are `NET_ADMIN`/`NET_RAW` only. Keep the Pi-hole admin UI (`:80`) off the WAN.
- **`autoheal` mounts the Docker socket** (`/var/run/docker.sock`) — the one
  remaining privilege. Acceptable for self-healing on a trusted box; noted here so
  it's a conscious choice, not a surprise.
- **Detection loop closed** — CI fails the build on any committed secret.
- **Control, not trust** — the "iPhone bypasses DNS" gap is handled by the Private
  Relay block + router `:53` redirect / DoT-DoH block (`docs/privacy-setup.md`).

## Honest limits (unchanged, by design)

DNS blocking kills third-party trackers/telemetry/smart-TV junk/malware. It
**cannot** block first-party in-app ads (YouTube/IG/FB/Spotify). That's the ceiling
of any DNS approach — not a misconfiguration.

**Net:** the project is done in the sense that matters — it's simple, reproducible,
self-healing, CI-gated, and privacy-focused. The remaining items are two settings
in the GitHub UI and a branch prune. Resist re-adding complexity.
