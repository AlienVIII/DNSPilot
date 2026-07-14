# Mobile Progress

## BLUF

The mobile lane is a standalone Expo native app. Local Expo modules call a Rust
adapter around `dnspilot-core` for catalog, policy, profile/suite/history,
recommendation, DNS-only, DNS+TCP/TLS, and system-resolver actions. The Node
bridge remains an Expo Go/web development fallback only. Android debug builds
compile on SDK 57. Production iOS entitlement generation, Android release
assembly, and the current iOS Simulator consumer UI are validated locally. The
durable lane handoff is now `STATE.md`; this file remains a feature summary.

## Requirement Coverage

- Consumer shell with Check DNS, Profiles, and History tabs. Internal routes
  are hidden from tab navigation.
- Native Rust runtime preserves the JSON shell contract of the shared core;
  installable native builds do not call the Node bridge.
- Benchmark UI covers DNS-only, DNS+TCP/TLS, and system-DNS validation with
  foreground native jobs, resolver rows, failure details, and copyable reports.
- Guided settings covers iOS/iPadOS profile/settings guidance and Android
  settings/Private DNS guidance without silent DNS mutation or VpnService.
- No app-open permission sheet. A versioned, optional first-run tutorial waits
  for persisted preferences and completes only on Skip or Done. Its top-right
  Help icon reopens the shared tutorial from every consumer tab; settings
  guidance begins only from a healthy, confident recommendation.
- Storage forms cover custom plain DNS, DoH, DoT profiles, custom suites, local
  validation, and custom tag preservation.
- iOS/iPadOS has a native `NEDNSSettingsManager` module for installing/removing
  user-approved DoH/DoT DNS Settings configurations with bootstrap IPs. The
  default Store profile omits its entitlement; `production-ios-dns` gates the
  capability pending Apple approval and signed-device validation.
- Adaptive phone/tablet layouts, A/AAAA controls, IPv4/IPv6 controls,
  Default/Vietnam quick picks, and English/Vietnamese localization are
  implemented.
- Benchmark mode/family/platform options and Storage protocol/filtering options
  localize in English/Vietnamese instead of staying hardcoded English.
- Manual language choice persists with native AsyncStorage across app restarts.
- Primary controls expose accessibility labels and state metadata for
  VoiceOver/TalkBack real-device checks.
- Native build path is smoke-tested locally with Android `assembleDebug`; the
  app is on Expo SDK 57 / React Native 0.86 and carries a narrow
  `expo-modules-jsi@57.0.1` Swift compatibility patch for Xcode 26. The Store
  iOS prebuild has no DNS Settings entitlement; the opt-in profile adds it.
- Native system appearance metadata is backed by `expo-system-ui`, so Expo
  prebuild no longer warns about `userInterfaceStyle`.
- EAS development builds include `expo-dev-client`; the local real-device
  command is `npm run start:dev-client`.
- Production/preview EAS profiles exclude dev-client/dev-menu autolinking, and
  Android release manifests are checked to keep dev-only overlay/storage/vibrate
  permissions and VPN/system-DNS mutation permissions out of store builds.

## Validation

- `npm run native:prepare:ios` and `npm run native:prepare:android`: build the
  Rust artifacts consumed by native modules; EAS invokes the matching hook.
- `npm run verify`: preferred full local gate before real-device QA or EAS
  builds.
- `npm test`: 89 behavior/view-model/plugin tests pass at `5a49a2b`; do not
  treat the count as a release invariant.
- `npm run typecheck`: pass after `npm ci`.
- `npm run postinstall`: pass; applies the `expo-modules-jsi` Xcode 26 patch.
- `npx expo install --check`: pass with `expo-dev-client`.
- `npx expo-doctor@latest`: pass.
- `npm run verify:router`: runs Expo web export and fails on unresolved Expo
  Router routes; added after a false-green `profiles` warning.
- `EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform ios
  --no-install`: pass; generated entitlement plist is empty as required for the
  default Store build. The opt-in config has the DNS Settings plugin and flag.
- `EAS_BUILD_PROFILE=production xcodebuild ... -configuration Release ...`:
  current bundle built, installed, launched, and was visually checked on an
  iPhone 17e simulator. First launch showed the title-first tutorial and header
  Help icon; it made no permission request.
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`:
  pass with SDK 36/JDK 17.
- `EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:assembleRelease`:
  pass; packages the native Rust runtime and release JS bundle.
- `EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform android --no-install && EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:processReleaseManifest`:
  pass; release manifest grep has no `expo-dev`, dev menu/launcher,
  overlay/storage/vibrate, VPN, or system-DNS mutation permission matches.

## Remaining Gates

- Real-device QA on physical iOS/iPadOS and Android devices.
- Apple/Google signing, store setup, real-device QA, Android Private DNS manual
  checks, and Apple Network Extensions `dns-settings` capability setup.
- Dependency audit: Expo tooling currently pulls vulnerable `uuid <11.1.1`; npm's
  force fix is breaking.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Main checklist and manual flow: `apps/mobile/mobile-readiness.md`.
- Publish steps: `apps/mobile/mobile-publish-checklist.md`.
- Durable current truth and manual-gate report: `apps/mobile/STATE.md` and
  `apps/mobile/TODO.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
