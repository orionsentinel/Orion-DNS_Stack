# Security Policy

## Reporting a vulnerability

This is a self-hosted homelab project. If you find a security issue, please
open a **private** report via GitHub Security Advisories
(`Security` → `Report a vulnerability`) rather than a public issue. Include
reproduction steps and affected versions/commit.

## Secrets handling

- **Never commit real secrets.** Real env files (`env/*.env`, root `.env`) are
  git-ignored; only `*.env.example` templates are tracked. CI runs a Trivy
  secret scan that **fails the build** if a credential is committed.
- Secrets to protect: `VRRP_PASSWORD`, `WEBPASSWORD`,
  `FTLCONF_webserver_api_password`, and the SSH keys used for Pi-hole sync.
- Keep them in a password manager so a node rebuild (`docs/disaster-recovery.md`)
  can repopulate `.env` without relying on git.

### ⚠️ Known historical exposure

Earlier history of this repository contained committed node secrets in
`env/primary.env` / `env/secondary.env` (now removed from the tree). Because the
repo is public, those values must be considered **compromised**:

- **Rotate** `VRRP_PASSWORD`, `WEBPASSWORD`, and the Pi-hole API password on both
  nodes.
- Optionally scrub history (`git filter-repo`) — but rotation is the real fix;
  scrubbing alone does not un-expose values already public.

## Hardening baseline

- DNS containers run with the **minimum capabilities** required
  (`NET_ADMIN`, plus `NET_RAW` for keepalived's VRRP); review before adding more.
- Local recursive resolution (Unbound → root, DNSSEC) by default — no third-party
  DNS unless explicitly configured.
- Images are **pinned to explicit version tags** (no `:latest` in the canonical
  build path) and checked for a `linux/arm64` manifest in CI.
- **GitHub Actions are pinned to full commit SHAs** (with a `# vN` comment so
  Dependabot can still propose updates) — prevents a moved tag from injecting
  untrusted CI code.
- Dependencies and base images are tracked by Dependabot (pip, docker,
  github-actions); merge security updates promptly. Digest-level image pinning is
  a candidate future step (best driven by Renovate to avoid stale-digest churn).

## Supported versions

`main` is the supported line. Run the latest tagged release or `main`.
