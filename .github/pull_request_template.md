<!-- Keep PRs focused and reviewable. Delete sections that don't apply. -->

## What & why
<!-- One or two sentences: what does this change and why. -->

## Type
- [ ] Fix
- [ ] Feature
- [ ] Refactor / cleanup
- [ ] Docs
- [ ] CI / tooling
- [ ] Security

## Checklist
- [ ] `docker compose --profile two-node-ha-primary config -q` passes
- [ ] Touched shell scripts pass `shellcheck`
- [ ] Docs updated (README / `docs/`) if behaviour or commands changed
- [ ] No secrets, passwords, or private IPs committed (`env/*.env` stays untracked)
- [ ] Uses the canonical IP scheme (`docs/networking.md`) — no new hardcoded IPs
- [ ] ARM64-compatible (images publish a `linux/arm64` manifest)

## Testing
<!-- How was this verified? Commands run, output, failover test, etc. -->

## Rollback
<!-- How to revert if this misbehaves in production. -->
