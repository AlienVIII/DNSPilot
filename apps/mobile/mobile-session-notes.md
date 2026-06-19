# Mobile Session Notes

## Decisions
- Treat iOS/iPadOS and Android as separate capability surfaces.
- Use settings/profile guidance before any VPN/proxy design.
- Use Expo SDK 56 for the first shared mobile test shell.
- Bind to existing core/CLI through a local Node bridge for Expo Go testing.
- Stream foreground benchmark progress through bridge jobs; keep this as a dev
  bridge capability until native Rust/platform adapters are chosen.

## Context
- `apps/mobile/DNSPilotMobile` contains the mobile shell.
- `server/dev-server.mjs` whitelists CLI actions and calls `cargo run -p
  dnspilot-cli`.
- Dev SQLite storage is `.dnspilot/dnspilot.sqlite` under the app folder.
- Benchmark UI now builds diagnostics from CLI result/progress payloads:
  process steps, resolver rows, failed step/reason, debug command, and report
  copy via `expo-clipboard`.
- Benchmark runs now start bridge jobs and poll while foregrounded, so partial
  resolver progress appears before the final parsed JSON result.
- Benchmark results can now request a core apply-plan directly from the
  recommendation, with iOS/Android selector and protected-network flags.
- Storage forms now validate local profile/suite payloads before bridge calls
  and preserve `custom` tags so saved items stay visible in the custom lists.
- Policy UI now derives store-safe guided flows from apply-plan payloads:
  iOS/iPadOS DNS Settings profile guidance, Android settings/Private DNS
  guidance, and protect-current-dns suppression.
- Shared UI now uses phone/tablet/expanded breakpoints to avoid stretched phone
  layouts on iPad and Android tablets; key forms use two-column adaptive
  sections when width allows it.

## Open Questions
- Release path: direct Rust native module/FFI versus separate SwiftUI/Kotlin
  shells.
- How much of the bridge job contract should become a native module contract
  once release-grade mobile builds start.

## Handoff
- Keep lane changes in `apps/mobile/**`.
- Record Core CLI binding needs in `mobile-core-cli-request.md`.
- Run `npm run bridge` and `npm start` from `apps/mobile/DNSPilotMobile` for
  local testing.
