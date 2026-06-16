# macOS Session Notes

## Decisions
- macOS is UX lead lane.
- Store-safe manual apply only; no silent DNS mutation.
- Flush belongs to post-apply system DNS validation, not direct resolver benchmark.
- System DNS validation is a validation mode, not a recommendation/apply mode.
- Post-apply validation CTA should reuse the current benchmark target domains and never mutate DNS.
- Menu bar System DNS validation uses a short preset: GitHub, Microsoft login, and Vietnam daily domain.
- Flush remains user-approved/manual: app copies checklist/commands, not executing cache flush itself.

## Context
- Current app exists under `apps/macos/DNSPilotMac`.
- Core CLI helper is bundled for local/debug app flow.

## Open Questions
- Should encrypted DNS profile support wait until after App Store policy review?

## Handoff
- Keep platform changes in `apps/macos/**`.
- Request Core CLI schema changes through `macos-core-cli-request.md`.
