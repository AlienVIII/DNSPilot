# Mobile Session Notes

## Decisions
- Treat iOS/iPadOS and Android as separate capability surfaces.
- Use settings/profile guidance before any VPN/proxy design.
- Use Expo SDK 57 for the shared mobile test shell.
- Bind to existing core/CLI through a local Node bridge for Expo Go testing.
- Stream foreground benchmark progress through bridge jobs only for the Expo
  Go/web fallback; installable builds already use the native Rust adapter.

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
- Benchmark setup now builds a validated payload before bridge calls, reports
  real suite-domain counts, and exposes Default/Vietnam quick-picks when the
  core catalog supports them.
- `mobile-readiness.md` is the durable summary for main-goal coverage,
  critique, remaining blockers, and manual validation flows.
- Policy UI now derives store-safe guided flows from apply-plan payloads:
  iOS/iPadOS DNS Settings profile guidance, Android settings/Private DNS
  guidance, and protect-current-dns suppression.
- The consumer shell no longer opens a permission-first System Access sheet.
  A versioned optional tutorial appears only after preferences load, records
  completion only on Skip or Done, and has one shared top-right Help icon on
  Check DNS, Profiles, and History. Guided settings starts only after a valid
  recommendation. It never applies DNS silently or flushes the system DNS
  cache.
- Current production Simulator smoke built, installed, and launched the
  consumer shell on iPhone 17e. It starts at Check DNS with only Check DNS,
  Profiles, and History visible in the tab bar; no startup permission sheet.
- Shared UI now uses phone/tablet/expanded breakpoints to avoid stretched phone
  layouts on iPad and Android tablets; key forms use two-column adaptive
  sections when width allows it.

## Open Questions
- No release-runtime architecture decision is pending: installable builds use
  the Rust adapter and Expo Go/web use the bridge fallback. Provider signing,
  real-device evidence, and the optional Apple capability remain manual gates.

## Handoff
- Keep lane changes in `apps/mobile/**`.
- Record Core CLI binding needs in `mobile-core-cli-request.md`.
- Run `npm run bridge` and `npm start` from `apps/mobile/DNSPilotMobile` for
  local testing.
- Read `STATE.md` and `TODO.md` before treating older session notes as current
  release truth.
