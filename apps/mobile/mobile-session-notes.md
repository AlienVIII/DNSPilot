# Mobile Session Notes

## Decisions
- Treat iOS/iPadOS and Android as separate capability surfaces.
- Use settings/profile guidance before any VPN/proxy design.

## Context
- No implementation exists yet.

## Open Questions
- Native mobile app per OS or shared mobile shell?
- How will Rust core be exposed to mobile builds?

## Handoff
- Keep lane changes in `apps/mobile/**`.
- Record Core CLI binding needs in `mobile-core-cli-request.md`.

