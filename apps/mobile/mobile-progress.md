# Mobile Progress

## BLUF

The mobile lane meets the current test-shell requirement: it validates DNSPilot
UX, bridge contracts, mobile policy limits, guided settings, localization, and
device setup flows. Local native iOS Simulator and Android debug builds now
compile. It is not yet the final public-store architecture.

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
- Benchmark mode/family/platform options and Storage protocol/filtering options
  localize in English/Vietnamese instead of staying hardcoded English.
- Primary controls expose accessibility labels and state metadata for
  VoiceOver/TalkBack real-device checks.
- Native build path is smoke-tested locally with iOS Simulator and Android
  `assembleDebug`; SDK 56 Xcode 26 support is stabilized through a
  `patch-package` patch for `expo-modules-jsi@56.0.10`.

## Validation

- `npm run verify`: preferred full local gate before real-device QA or EAS
  builds.
- `npm test`: pass.
- `npm run typecheck`: pass after `npm ci`.
- `npm run postinstall`: pass; applies the `expo-modules-jsi` Xcode 26 patch.
- `npx expo run:ios --configuration Debug --device "iPhone 16e" --no-bundler --no-install --no-build-cache`:
  pass on Xcode 26.0.1 iOS Simulator.
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`:
  pass with JDK 17 and Android SDK.

## Remaining Gates

- Real-device QA on physical iOS/iPadOS and Android devices.
- Apple/Google signing, store setup, and Local Network/Private DNS manual checks.
- Native Rust adapter, approved backend, or another release runtime decision.
- Dependency audit: Expo tooling currently pulls vulnerable `uuid <11.1.1`; npm's
  force fix is breaking.

## Source Of Truth

- Main checklist and manual flow: `apps/mobile/mobile-readiness.md`.
- Publish steps: `apps/mobile/mobile-publish-checklist.md`.
