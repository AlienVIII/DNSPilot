# macOS Session Notes

## Decisions
- macOS is UX lead lane.
- Store-safe manual apply only; no silent DNS mutation.
- Flush belongs to post-apply system DNS validation, not direct resolver benchmark.
- System DNS validation is a validation mode, not a recommendation/apply mode.

## Context
- Current app exists under `apps/macos/DNSPilotMac`.
- Core CLI helper is bundled for local/debug app flow.

## Open Questions
- Should encrypted DNS profile support wait until after App Store policy review?
- Should v1 add a direct post-apply CTA that preselects System DNS validation?

## Handoff
- Keep platform changes in `apps/macos/**`.
- Request Core CLI schema changes through `macos-core-cli-request.md`.
