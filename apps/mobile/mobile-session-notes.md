# Mobile Session Notes

## Decisions
- Treat iOS/iPadOS and Android as separate capability surfaces.
- Use settings/profile guidance before any VPN/proxy design.
- Use Expo SDK 56 for the first shared mobile test shell.
- Bind to existing core/CLI through a local Node bridge for Expo Go testing.

## Context
- `apps/mobile/DNSPilotMobile` contains the mobile shell.
- `server/dev-server.mjs` whitelists CLI actions and calls `cargo run -p
  dnspilot-cli`.
- Dev SQLite storage is `.dnspilot/dnspilot.sqlite` under the app folder.

## Open Questions
- Release path: direct Rust native module/FFI versus separate SwiftUI/Kotlin
  shells.
- Whether benchmark progress needs streaming events before CLI process exit.

## Handoff
- Keep lane changes in `apps/mobile/**`.
- Record Core CLI binding needs in `mobile-core-cli-request.md`.
- Run `npm run bridge` and `npm start` from `apps/mobile/DNSPilotMobile` for
  local testing.
