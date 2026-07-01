# Mobile Progress

## BLUF

The mobile lane meets the current test-shell requirement: it validates DNSPilot
UX, bridge contracts, mobile policy limits, guided settings, localization, and
device setup flows. Android debug builds compile on SDK 57; iOS Simulator smoke
is blocked on this machine by an Xcode Simulator runtime mismatch. It is not yet
the final public-store architecture.

## Requirement Coverage

- Expo/React Native shell with Overview, Benchmark, Catalog, Storage, and Policy
  tabs.
- Local Node bridge maps allowed mobile actions to `dnspilot-cli` commands.
- Benchmark UI covers DNS-only, DNS+TCP, and system-DNS validation with
  foreground progress polling, resolver rows, failure details, and copyable
  reports.
- Guided settings covers iOS/iPadOS profile/settings guidance and Android
  settings/Private DNS guidance without silent DNS mutation or VpnService.
- First-open System Access prompt covers Local Network/network permission
  recovery, OS-gated DNS apply, one-tap copy-and-open Settings actions, and
  explicit DNS flush unsupported status.
- Storage forms cover custom plain DNS, DoH, DoT profiles, custom suites, local
  validation, and custom tag preservation.
- Adaptive phone/tablet layouts, A/AAAA controls, IPv4/IPv6 controls,
  Default/Vietnam quick picks, English/Vietnamese localization, and real-device
  bridge URL checks are implemented.
- Benchmark mode/family/platform options and Storage protocol/filtering options
  localize in English/Vietnamese instead of staying hardcoded English.
- Primary controls expose accessibility labels and state metadata for
  VoiceOver/TalkBack real-device checks.
- Native build path is smoke-tested locally with Android `assembleDebug`; the
  app is on Expo SDK 57 / React Native 0.86 and carries a narrow
  `expo-modules-jsi@57.0.0` Swift compatibility patch for Xcode 26. iOS
  Simulator smoke needs a matching iOS 26.5 runtime for local Xcode 26.6.
- EAS development builds include `expo-dev-client`; the local real-device
  command is `npm run start:dev-client`.

## Validation

- `npm run verify`: preferred full local gate before real-device QA or EAS
  builds.
- `npm test`: pass.
- `npm run typecheck`: pass after `npm ci`.
- `npm run postinstall`: pass; applies the `expo-modules-jsi` Xcode 26 patch.
- `npx expo install --check`: pass with `expo-dev-client`.
- `npx expo-doctor@latest`: pass.
- `npx expo run:ios --configuration Debug --device "iPhone 16e" --no-bundler --no-install --no-build-cache`:
  blocked locally because Xcode 26.6 exposes iOS Simulator SDK 26.5 while only
  the iOS 26.0 Simulator runtime is installed; install iOS 26.5 runtime and
  rerun.
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`:
  pass with SDK 36/JDK 17.

## Remaining Gates

- Real-device QA on physical iOS/iPadOS and Android devices.
- iOS 26.5 Simulator runtime for local Xcode 26.6 smoke, Apple/Google signing,
  store setup, and Local Network/Private DNS manual checks.
- Native Rust adapter, approved backend, or another release runtime decision.
- Dependency audit: Expo tooling currently pulls vulnerable `uuid <11.1.1`; npm's
  force fix is breaking.

## Source Of Truth

- Main checklist and manual flow: `apps/mobile/mobile-readiness.md`.
- Publish steps: `apps/mobile/mobile-publish-checklist.md`.
