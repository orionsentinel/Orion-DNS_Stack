# Branching & Release Strategy

Keep `main` always deployable. Small, reviewable PRs.

## Branches

| Branch | Purpose | Rules |
|---|---|---|
| `main` | Stable, production. Every commit should be deployable to a Pi. | Protected: PR + green CI required; no force-push/delete. |
| `develop` | Optional integration branch for batching larger work. | PR into `main` when stable. |
| `feature/*` | New work, experiments, fixes. | Branch from `main` (or `develop`); open a PR. |

> Do **not** commit breaking changes directly to `main`. Branch, open a PR, let
> CI validate, then merge.

## Flow

```bash
git switch main && git pull
git switch -c feature/short-description
# ... work, commit ...
git push -u origin feature/short-description
# open a PR; CI must be green; squash-merge into main
```

## CI gate (required on `main`)

A PR must pass before merge:
- `Validate compose config` — `docker compose config` across all profiles
- `ARM64 build check` — keepalived builds for `linux/arm64`; DNS image has an arm64 manifest
- `Documentation validation` — required docs present, no stale clone URLs
- `Security scan (Trivy)` and `Secret scan` — no committed secrets / criticals
- `Dockerfile lint`, `YAML lint`

(`Shell lint` is advisory until `scripts/` is deduplicated, then it becomes required.)

## Releases

Tag stable points on `main` with SemVer (`vMAJOR.MINOR.PATCH`) and record changes
in `CHANGELOG.md`. Pin production nodes to a tag; upgrade intentionally
(`docs/upgrade-guide.md`).
