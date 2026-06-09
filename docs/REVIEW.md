# Architecture & DevSecOps Review

> A maturity assessment of `Orion-DNS_Stack` after the consolidation work (PR #83).
> Written wearing two hats — **architect** (is the design sound and reproducible?)
> and **DevSecOps engineer** (is it secure, observable, and operable with minimal
> babysitting?). Companion to `docs/AUDIT.md`, which catalogued the original drift.

## TL;DR

The **core HA DNS design is genuinely good** — two nodes, one unified ARM64-safe
Pi-hole+Unbound image, Keepalived VRRP, local recursion with DNSSEC. The recent
work fixed the things that actually bite: committed secrets, the ARM64 image,
three conflicting IP schemes, and a CI that validated nothing. What remains is
**breadth debt** — too many half-built optional stacks and installer scripts
around a solid centre. Maturity is now roughly **"works and is safe to run"**;
the path to **"runs itself"** is mostly *subtraction* plus a few operability bolts.

## Maturity scorecard

| Dimension | Before | Now | Target | Notes |
|---|:--:|:--:|:--:|---|
| Reproducibility (IaC) | 🔴 | 🟡 | 🟢 | Clone+compose works; single `bootstrap.sh` still owed. |
| Secrets management | 🔴 | 🟡 | 🟢 | Untracked + CI secret gate; **rotation still owed**; consider SOPS/age. |
| Supply chain | 🔴 | 🟡 | 🟢 | Dependabot (pip/docker/actions), Trivy. Pin images by digest; pin actions to SHA. |
| CI/CD | 🔴 | 🟢 | 🟢 | compose/yaml/docker/ARM64/Trivy/secret/docs gates. Make shell-lint blocking post-dedup. |
| Observability | 🟡 | 🟡 | 🟢 | Exporters exist; 3 overlapping stacks → collapse to one, provision dashboards + alerts. |
| HA / resilience | 🟢 | 🟢 | 🟢 | VRRP validated (8-char pass, unicast, split-brain guards). Add an automated failover test. |
| Documentation | 🔴 | 🟢 | 🟢 | Canonical `docs/` set + audit/review. ~58 legacy docs still to retire. |
| Governance | 🔴 | 🟢 | 🟢 | CODEOWNERS, PR template, SECURITY.md, branching strategy, this PR. Add branch protection + LICENSE. |
| Footprint / clarity | 🔴 | 🟡 | 🟢 | 466 files, many stub stacks. Subtraction is the main lever. |

🔴 weak · 🟡 partial · 🟢 solid

## What's good (keep it)

- **Right primitives.** VRRP for a floating VIP is the correct, transparent HA
  mechanism here; unified Pi-hole+Unbound removes a moving part and fixed ARM64.
- **Keepalived entrypoint is hardened** — strict env validation (exact 8-char
  VRRP password, peer IPs), permission fixing, split-brain prevention. This is
  the most mature component and should be the model for the rest.
- **Profiles over copies.** The canonical `compose.yml` expresses single-node and
  both HA roles via profiles — the correct pattern (the deleted `deployments/`
  did the opposite).
- **Privacy by default** — local recursion + DNSSEC, optional DoT forwarding.

## Risks & gaps (prioritised)

### P0 — do now
1. **Rotate the historically-exposed secrets** (`VRRP_PASSWORD`, `WEBPASSWORD`,
   Pi-hole API password). Untracking ≠ un-exposing on a public repo. *(operator)*
2. **Enable branch protection on `main`** (PR + green CI). Without it, the drift
   this project just paid down can silently return. *(owner; no API tool here)*

### P1 — soon
3. **Kill the `deployments/` tree** (7 variants shipping the broken
   `mvance/unbound-rpi` ARM32 image). They're a live foot-gun and contradict the
   canonical stack. Do it with the installer consolidation (below) so dangling
   references go too.
4. **Collapse `scripts/` (72 files) and the ~10 installers into one
   `bootstrap.sh`** — `clone → ./bootstrap.sh → working node`. Today the install
   story is many overlapping, partly-broken scripts; this is the biggest
   operability win and the IaC promise in the brief.
5. **One observability stack.** `stacks/{observability,monitoring,nsm}` overlap.
   Pick one, **provision Grafana dashboards + Prometheus alert rules as code**,
   and wire degraded-state alerts (the "silent service failure" risk).
6. **Retire the ~58 legacy docs** in favour of the canonical `docs/` set to end
   contradictory instructions.

### P2 — maturity polish
7. **Pin container images by digest** (not just tag) and **GitHub Actions by
   commit SHA** — closes the remaining supply-chain gap; Dependabot keeps both moving.
8. **Remove or relocate stub "AI" stacks** (`ai-watchdog`, `self-healing`,
   `traffic-analytics`, `agents/*`) to the `Orion-sentinel-netsec-ai` repo where
   that mandate lives — they're aspirational here and dilute the DNS focus.
9. **Add a `LICENSE`** (README says "open source" but none is committed) and an
   automated **failover integration test** (stop primary → assert VIP moves →
   assert `dig @VIP` resolves).
10. **Secrets at rest:** consider SOPS+age or Docker/compose secrets so `.env`
    values aren't plaintext on the SD card.

## DevSecOps specifics

- **Attack surface:** containers run `network_mode: host` (required for VRRP/VIP).
  Acceptable on a trusted LAN, but it means container ports are host ports —
  keep the Pi-hole admin UI (`:80`) off the WAN and behind auth.
- **Least privilege:** current caps are tight (`NET_ADMIN`, `NET_RAW`). cAdvisor
  runs `privileged: true` (NetSec profile) — gate it behind the optional profile
  (already is) and document the trade-off.
- **Detection:** the new CI **secret-scan gate fails the build on committed
  credentials**, closing the loop on the original incident. Trivy also covers
  vuln/misconfig (advisory) — graduate misconfig to blocking once the tree is clean.
- **Verification, not trust:** the "iPhone bypasses DNS" risk is a real control
  gap — enforce it at the router (redirect `:53` to the VIP, block DoH) and keep
  the verification steps in `docs/troubleshooting.md`.

## Recommended sequence

1. Branch protection + secret rotation (P0).
2. `deployments/` removal **+** single `bootstrap.sh` **+** installer cleanup (P1, one PR).
3. Observability collapse with provisioned dashboards/alerts (P1).
4. Legacy-docs retirement (P1).
5. Digest/SHA pinning, stub-stack relocation, LICENSE, failover test (P2).

Net: the project is past its risky phase. The remaining work is disciplined
**subtraction** plus a handful of operability bolts — exactly the cheap,
high-leverage moves that take it from "safe to run" to "runs itself."
