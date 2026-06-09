# Orion Sentinel — DNS HA Stack: Architecture Audit

> Source-of-truth audit of `orionsentinel/Orion-DNS_Stack`, performed as part of
> the consolidation effort. Sections A–J. Companion to the consolidation PR.

## Context

The repo is the source of truth for a Raspberry Pi high-availability DNS stack
(Pi-hole + Unbound + Keepalived VRRP). Across ~50 AI-generated `copilot/*`
branches it accreted heavy drift: **466 files, ~58 Markdown docs (25 root + 33 in
`docs/`), 35 compose files, 7 near-duplicate deployment variants, 3 keepalived
implementations, 3 competing DNS resolvers, several abandoned experiments, and
3+ mutually inconsistent IP schemes.** It reads like a hobby repo that
snowballed, not a production DevOps repo.

### Canonical decisions
- **Single monorepo**, reorganized to the standard layout.
- **Canonical topology:** 2 Pis, 1 Pi-hole+Unbound each, Keepalived VRRP.
- **Remove** components not wired into the canonical stack/docs; keep working
  optional stacks, clearly labeled.

### Canonical IP scheme (configurable via `.env`)
| Role | Host | IP | VRRP |
|---|---|---|---|
| Node A (MASTER) | pi-dns-1 | `192.168.8.244` | priority 200 |
| Node B (BACKUP) | pi-dns-2 | `192.168.8.245` | priority 150 |
| Floating VIP | clients → here | `192.168.8.243` | VRRP-managed |
| Router/gateway | — | `192.168.8.1` | — |

This replaces the README's `.249/.243`+VIP`.250`, the env files' `.250/.251`+VIP
`.249`, and CoreDNS's `.251/.252` schemes everywhere.

---

## A. Architecture audit (what exists)

Three parallel, overlapping definitions of the **same** DNS stack:

1. **Root `compose.yml`** — the canonical-by-README path. Profile-based
   (`single-node`, `two-node-ha-primary`, `two-node-ha-backup`). Uses the unified
   ARM64-safe image `ghcr.io/mpgirro/docker-pihole-unbound:2026.05.0` + custom
   `./keepalived` build. Also embeds optional exporters and a NetSec profile
   (Suricata/cAdvisor/EveBox). **Keep — this is the canonical runtime.**
2. **`deployments/` (7 variants × node1/node2 = 14 compose files)** —
   `HighAvail_{1Pi2P2U,2Pi1P1U,2Pi2P2U}(_VPN)` + `Production_2Pi_HA`. ~80%
   duplicated 175–316-line files, no `extends`/`include`. Still reference the
   **broken `mvance/unbound-rpi`** ARM32 image. **Remove — superseded.**
3. **`stacks/dns/docker-compose.yml`** (442 lines) — separate `pihole/pihole` +
   custom `./unbound` (klutchell, ARM64-safe) + sync overlay, plus the optional
   resolvers (blocky, cloudflared, coredns). **Demote — fold useful bits into the
   canonical stack; drop experiments.**

Supporting sprawl: 3 keepalived copies (`/keepalived`, `/config/keepalived`,
`/stacks/dns/keepalived`); 4 Pi-hole sync mechanisms; 2 web installers
(`wizard/`, `stacks/setup-ui/`); 3 observability stacks
(`stacks/{observability,monitoring,nsm}`); plus `stacks/{vpn,sso,remote-access,
management,ai-watchdog,self-healing,traffic-analytics,agents}`.

## B. Risks
- **No single source of truth for the runtime** → operator runs the wrong stack.
- **3+ conflicting IP schemes** → guaranteed misconfiguration on rebuild.
- **Committed secrets** in `env/primary.env`/`env/secondary.env` on a **public**
  repo (real `VRRP_PASSWORD`, `WEBPASSWORD`, Pi-hole API password). *(Untracked in
  this PR; operator must rotate — they persist in history.)*
- **6 Dependabot vulnerabilities on `main`** (1 high, 2 moderate, 3 low); 2 open
  security PRs (#81, #82) unmerged.
- **`main` has no branch protection.**
- **~50 stale branches** (`copilot/*`, `alert-autofix-*`).

## C. What is broken
- **`deployments/*` use `mvance/unbound-rpi`** — the exact image known to fail on
  64-bit Raspberry Pi OS. Root compose & `stacks/dns` already moved to ARM64-safe
  images; the deployments never got the fix.
- **README clone URL was wrong** — pointed at a non-existent `…-ha-dns` repo
  instead of `Orion-DNS_Stack`, so copy-paste install failed at step 1.
  (Fixed across all docs in this PR.)
- **`stacks/dns/coredns/Corefile`** hard-codes `.251/.252` and is wired into nothing.
- **Broken symlinks** `stacks/{dns,observability,ai-watchdog}/.env → ../../.env`
  (target absent).

## D. What is fragile
- **4 competing Pi-hole HA sync implementations** (`ops/pihole-sync.sh`,
  `stacks/dns/pihole-sync.sh`, `docker-compose.sync.yml` multinode-sync,
  `Production_2Pi_HA` auto-scripts); some reference scripts not in the repo.
- **3 keepalived implementations** with differing validation; deployments ship
  static configs that bypass the validated `/keepalived` entrypoint.
- **~58 Markdown docs** with overlapping/contradicting install & upgrade steps.

## E. What is overengineered
- 7 deployment variants for one real topology; `_VPN` doubling of each.
- 3 observability stacks where one suffices.
- Aspirational "AI" stacks (`ai-watchdog`, `self-healing`, `traffic-analytics`,
  `agents/*`): stub-grade, not wired in, overlapping the separate
  `Orion-sentinel-netsec-ai` repo's mandate.
- Two web installers.

## F. Recommended target architecture
Single monorepo, one canonical runtime:

```
Orion-DNS_Stack/
├── compose.yml          # CANONICAL 2-node HA (mpgirro unified + keepalived)
├── .env.example         # ONE template (node-role-parameterized)
├── bootstrap.sh         # git clone + ./bootstrap.sh → working node
├── README.md            # single source of truth
├── docs/                # AUDIT, architecture, networking, troubleshooting,
│   └── diagrams/        #   disaster-recovery, upgrade-guide
├── keepalived/          # the ONE validated VRRP build
├── config/              # unbound + pihole config (ARM64 build)
├── scripts/             # deduped: bootstrap, verify-ha, sync, backup, restore, doctor
├── monitoring/          # ONE optional observability stack (profiled, off by default)
├── backups/ provisioning/ tests/
└── systemd/             # backup/sync/health timers (deduped)
```
- One DNS image (mpgirro unified, ARM64-safe). One keepalived (validated
  `/keepalived`). One SSH-based sync on a systemd timer. One observability stack
  behind a compose profile. Optional stacks kept only if functional.

## G. Exact implementation plan
Phased, non-breaking (see PR description / plan): 0 security → 1 canonical
runtime → 2 dead-code removal → 3 IP/config standardization → 4 bootstrap +
backup/restore + CI → 5 doc consolidation → 6 GitHub hygiene. Each phase is an
isolated, reviewable commit.

## H. Migration path
Existing nodes keep running throughout. To adopt the canonical stack:
1. `git pull` the consolidated branch.
2. `cp env/primary.env.example env/primary.env` (and secondary on Node B); set
   secrets + confirm the canonical IPs.
3. `docker compose --profile two-node-ha-primary up -d` (backup profile on Node B).
4. `scripts/verify-ha.sh` to confirm VIP ownership + failover.
5. Decommission `deployments/*` once verified.

## I. GitHub improvements
- Merge security PRs #81/#82 after CI; resolve the 6 Dependabot alerts.
- Branch protection on `main` (PR + green CI required); add `develop`.
- Prune ~50 stale `copilot/*` / `alert-autofix-*` branches.
- Harden CI: compose-config, yamllint, hadolint, shellcheck, Trivy, ARM64 buildx,
  doc-link check.
- Add `CODEOWNERS`, PR template, branching-strategy doc.

## J. Operational playbook
Consolidate into `docs/troubleshooting.md` + `docs/disaster-recovery.md`:
VIP-failover test, "iPhone bypasses DNS" verification (force-redirect :53 at the
router + `scripts/verify-ha.sh` checks), degraded-state alerts, timed restore
drill (<1h), upgrade procedure, backup verification.

---

## Pressure-test / trade-offs
- **Monorepo vs split:** monorepo chosen for solo-maintainer simplicity; the
  NetSec/AI ambitions live in the separate `Orion-sentinel-netsec-ai` repo, so the
  stub AI stacks here are redundant and removed rather than maintained twice.
- **Unified mpgirro image vs separate pihole+unbound:** unified image reduces
  moving parts and fixed the ARM64 failure; trade-off is less independent control
  of Unbound, acceptable for a 2-node home HA setup (robustness > flexibility).
- **Deleting `deployments/`:** the variants are unmaintained and ship a broken
  image; the canonical profile-based `compose.yml` covers the one supported
  topology. Migration is documented (H) so nothing is stranded.
