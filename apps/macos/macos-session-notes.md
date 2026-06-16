# macOS Session Notes

## Decisions
- macOS is UX lead lane.
- Store-safe manual apply only; no silent DNS mutation.
- Flush belongs to post-apply system DNS validation, not direct resolver benchmark.

## Context
- Current app exists under `apps/macos/DNSPilotMac`.
- Core CLI helper is bundled for local/debug app flow.

## Open Questions
- How much system-DNS validation UI belongs in v1?
- Should encrypted DNS profile support wait until after App Store policy review?

## Handoff
- Keep platform changes in `apps/macos/**`.
- Request Core CLI schema changes through `macos-core-cli-request.md`.

