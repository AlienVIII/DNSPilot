# Mobile Progress

## Completed
- Initialized Expo/React Native app at `apps/mobile/DNSPilotMobile`.
- Added local CLI bridge that maps mobile actions to whitelisted `dnspilot-cli`
  commands.
- Added mobile tabs for Overview, Benchmark, Catalog, Storage, and Policy.
- Exposed catalog, capability, preflight, apply-policy/apply-plan, benchmark,
  compare, path-estimate/path-compare, custom profile/suite storage, history,
  and recommendation sample flows.
- Added benchmark process diagnostics: per-step status, resolver status rows,
  elapsed time, failed step/reason, debug log, and copyable report.
- Added capability-based guided DNS settings/profile flow for iOS/iPadOS and
  Android, including protected-network suppression.

## Current Work
- Test shell is ready for local Expo Go/web validation through the bridge.

## Blockers
- Expo Go cannot spawn or link the Rust CLI inside the app process.
- Release-grade mobile builds still need native Rust bindings or approved
  platform adapters.

## Next Actions
- Test on iOS Simulator, Android emulator, and a physical phone using LAN bridge
  URL.
- Decide whether release work should use direct Rust FFI/native modules or
  separate SwiftUI/Kotlin shells.
