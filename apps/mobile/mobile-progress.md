# Mobile Progress

## BLUF

The mobile lane meets the current test-shell requirement: it validates DNSPilot
UX, bridge contracts, mobile policy limits, guided settings, localization, and
device setup flows. It is not yet the final public-store architecture.

## Requirement Coverage

- Expo/React Native shell with Overview, Benchmark, Catalog, Storage, and Policy
  tabs.
- Local Node bridge maps allowed mobile actions to `dnspilot-cli` commands.
- Benchmark UI covers DNS-only, DNS+TCP, and system-DNS validation with
  foreground progress polling, resolver rows, failure details, and copyable
  reports.
- Guided settings covers iOS/iPadOS profile/settings guidance and Android
  settings/Private DNS guidance without silent DNS mutation or VpnService.
- Storage forms cover custom plain DNS, DoH, DoT profiles, custom suites, local
  validation, and custom tag preservation.
- Adaptive phone/tablet layouts, A/AAAA controls, IPv4/IPv6 controls,
  Default/Vietnam quick picks, English/Vietnamese localization, and real-device
  bridge URL checks are implemented.

## Validation

- `npm test`: pass.
- `npm run typecheck`: pass after `npm ci`.

## Remaining Gates

- Real-device QA on iOS Simulator, Android emulator, and physical phones.
- Apple/Google signing, store setup, and Local Network/Private DNS manual checks.
- Native Rust adapter, approved backend, or another release runtime decision.
- Dependency audit: Expo tooling currently pulls vulnerable `uuid <11.1.1`; npm's
  force fix is breaking.

## Source Of Truth

- Main checklist and manual flow: `apps/mobile/mobile-readiness.md`.
- Publish steps: `apps/mobile/mobile-publish-checklist.md`.
