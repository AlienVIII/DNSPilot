# Mobile Progress

## BLUF

The mobile lane meets the current test-shell requirement: it validates DNSPilot
UX, bridge contracts, mobile policy limits, guided settings, localization,
native persistence, and device setup flows. Android debug builds compile on SDK
57, and iOS Simulator Debug plus production Release build/install/launch smoke
passes with Xcode 26.6 + iOS 26.5 runtime. Android production manifest
generation strips dev-client/dev-only release surface. It is not yet the final
public-store architecture unless the bridge/back-end runtime decision is
approved.

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
  recovery, OS-gated DNS apply, iOS App Settings, Android Private DNS/network
  Settings, in-sheet System DNS retest, and explicit DNS flush unsupported
  status.
- Overview now has a top-right setup Help button; System Access rows use short
  title/status copy with per-row info expansion for detailed policy text.
- Storage forms cover custom plain DNS, DoH, DoT profiles, custom suites, local
  validation, and custom tag preservation.
- iOS/iPadOS has a native `NEDNSSettingsManager` module for installing/removing
  user-approved DoH/DoT DNS Settings configurations with bootstrap IPs; iOS
  still requires the user to enable the configuration in Settings.
- Adaptive phone/tablet layouts, A/AAAA controls, IPv4/IPv6 controls,
  Default/Vietnam quick picks, English/Vietnamese localization, and real-device
  bridge URL checks are implemented.
- Benchmark mode/family/platform options and Storage protocol/filtering options
  localize in English/Vietnamese instead of staying hardcoded English.
- Bridge URL and manual language choice persist with native AsyncStorage across
  app restarts.
- Primary controls expose accessibility labels and state metadata for
  VoiceOver/TalkBack real-device checks.
- Native build path is smoke-tested locally with Android `assembleDebug`; the
  app is on Expo SDK 57 / React Native 0.86 and carries a narrow
  `expo-modules-jsi@57.0.1` Swift compatibility patch for Xcode 26. iOS
  Simulator Debug and production Release build/install/launch are smoke-tested
  on an iOS 26.5 simulator.
- Native system appearance metadata is backed by `expo-system-ui`, so Expo
  prebuild no longer warns about `userInterfaceStyle`.
- EAS development builds include `expo-dev-client`; the local real-device
  command is `npm run start:dev-client`.
- Production/preview EAS profiles exclude dev-client/dev-menu autolinking, and
  Android release manifests are checked to keep dev-only overlay/storage/vibrate
  permissions and VPN/system-DNS mutation permissions out of store builds.

## Validation

- `npm run verify`: preferred full local gate before real-device QA or EAS
  builds.
- `npm test`: pass with 60 behavior/view-model/plugin tests.
- `npm run typecheck`: pass after `npm ci`.
- `npm run postinstall`: pass; applies the `expo-modules-jsi` Xcode 26 patch.
- `npx expo install --check`: pass with `expo-dev-client`.
- `npx expo-doctor@latest`: pass.
- `npx expo run:ios --configuration Debug --device "iPhone 17e" --no-bundler --no-install --no-build-cache`:
  build pass. The app was installed/launched with `simctl`, then loaded through
  `npm run start:dev-client` on port 8082; screenshot confirmed the first-open
  System Access sheet.
- `npx expo prebuild --clean --platform ios` plus direct `xcodebuild`
  Simulator build on `iPhone 17e` with iOS 26.5: pass after production
  autolinking guards were added.
- `EAS_BUILD_PROFILE=production xcodebuild -workspace ios/DNSPilotMobile.xcworkspace -scheme DNSPilotMobile -configuration Release -sdk iphonesimulator -destination 'id=DD41C6AF-ED3D-4B44-AC21-1F7FC1B8204D' CODE_SIGNING_ALLOWED=NO build -quiet`:
  pass; installed with `simctl` and screenshot confirmed the standalone app
  opens directly into the first-open System Access sheet.
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`:
  pass with SDK 36/JDK 17.
- `EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform android --no-install && EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:processReleaseManifest`:
  pass; release manifest grep has no `expo-dev`, dev menu/launcher,
  overlay/storage/vibrate, VPN, or system-DNS mutation permission matches.

## Remaining Gates

- Real-device QA on physical iOS/iPadOS and Android devices.
- Apple/Google signing, store setup, real-device QA, Local Network/Private DNS
  manual checks, and Apple Network Extensions `dns-settings` capability setup.
- Native Rust adapter, approved backend, or another release runtime decision.
- Dependency audit: Expo tooling currently pulls vulnerable `uuid <11.1.1`; npm's
  force fix is breaking.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Main checklist and manual flow: `apps/mobile/mobile-readiness.md`.
- Publish steps: `apps/mobile/mobile-publish-checklist.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
