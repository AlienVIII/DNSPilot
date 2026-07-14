# Mobile Readiness

## Main Goal Checklist
- Consumer UI: covered by stable Check DNS, Profiles, and History tabs. Check
  DNS defaults to a foreground DNS-only quick check and exposes DNS + TCP and
  current resolver validation under Advanced options.
- DNS-only, DNS+TCP, and system resolver validation: covered by compare,
  path-compare, benchmark, path-estimate, and system-benchmark modes.
- Per-step/per-resolver process UI: covered by prepare, DNS, TCP, TLS, save,
  resolver rows, elapsed time, failure reason, debug command, and progress
  event count.
- Saved profiles and custom suites: covered by SQLite-backed add/update/delete,
  local form validation, custom tag preservation, catalog merge, and history.
- Guided DNS settings/profile flow: covered by core apply-plan payloads,
  iOS/iPadOS profile/settings guidance, Android settings/Private DNS guidance,
  protected-network suppression, one-tap copy-and-open OS settings actions, and
  native Open Settings actions.
- Native encrypted-DNS flow: covered by a local Expo module around
  `NEDNSSettingsManager`, but only in the opt-in `production-ios-dns` profile.
  Default Store builds omit the `dns-settings` entitlement and present guided
  setup only. An entitled build retains bootstrap IP validation, install/remove
  status, and explicit iOS user enablement.
- System setup: no app-open permission sheet. A first-run optional tutorial is
  shown only after local preferences load and completes only on Skip or Done.
  Its top-right Help icon is available on Check DNS, Profiles, and History;
  setup opens only from an evidence-backed result. Android opens Private
  DNS/network Settings; both platforms show DNS flush as unsupported.
- Tablet layouts: covered by shared adaptive layout helpers, two-column flows on
  wide screens, and unlocked orientation for native portrait/landscape checks.
- IPv4/IPv6 and A/AAAA controls: covered by benchmark IP-family controls and
  help text.
- Vietnam/default suites: covered when the core catalog exposes `general` (or
  legacy `general-browsing`) and `vietnam-daily`.
- Multilingual UX: covered for primary app chrome and workflows with system
  locale detection, manual English/Tiếng Việt override, localized validation
  errors, localized option controls, and localized guided DNS settings steps.
- Native build metadata: covered for iOS bundle ID/build number, Android package
  ID/version code, EN/VI supported locales, development-only iOS Local Network
  text for bridge fallback, Android normal network permissions, and EAS build profiles.
- Native build smoke: covered by local Android `assembleDebug`; the app is on
  Expo SDK 57 / React Native 0.86 with a narrow `expo-modules-jsi@57.0.1` Swift
  compatibility patch for Xcode 26. iOS Simulator Debug and production Release
  build/install/launch smoke pass with Xcode 26.6 and an iOS 26.5 runtime.
- Native release surface: covered for Android production manifests by excluding
  `expo-dev-client`, dev launcher/menu modules, dev-only overlay/storage/vibrate
  permissions, and VPN/system-DNS mutation permissions from release generation.
- Development client flow: covered by `expo-dev-client`, launcher-mode config,
  and a `npm run start:dev-client` LAN script for installable real-device
  development builds.
- Real-device setup UX: native builds use in-app Rust runtime directly; bridge
  URL checks remain only for Expo Go/web fallback development.
- Native persistence UX: covered by SQLite-backed core storage and manual
  language preference persistence across restarts.
- Native accessibility UX: covered for primary buttons, segmented controls,
  switches, text inputs, and selectable chips with labels and state metadata for
  real-device assistive technology checks.

## Critique
- The public native architecture is Expo Modules plus a Rust adapter around
  `dnspilot-core`. Installable builds run without a developer Mac or backend.
  Expo Go/web retains the bridge only because it cannot load local native code.
- The current app is honest about mobile OS limits. It does not silently mutate
  system DNS, does not use Android VpnService, and does not offer iOS
  DNSJumper-style plain DNS switching.
- The stable bridge JSON shape is retained by the native adapter so the UI and
  core payload contracts do not diverge across development and release builds.
- Guided settings is intentionally conservative. It may feel less powerful than
  desktop DNS switching, but that is the correct consumer mobile policy stance.
- The opt-in entitled iOS/iPadOS build can install a DoH/DoT DNS Settings configuration
  with `NEDNSSettingsManager`; the user must still explicitly enable it in
  Settings. Plain DNS remains guide-only. Android Private DNS cannot be
  silently mutated, and neither consumer OS can flush system DNS cache.
- Benchmark jobs are foreground-only. Long worst-case benchmarks keep the app
  open; no aggressive background scheduler is used.
- Real-device testing no longer needs a LAN bridge. Signing, store account
  flows, and final OS Settings validation remain inherently manual.
- Dev-client is intentionally a development-only surface. Production/preview
  EAS profiles remove it from Expo config/autolinking, while development builds
  keep it for real-device QA.

## Remaining Blockers
- iOS/iPadOS: real-device validation, Apple
  signing/provisioning, Network Extensions `dns-settings` capability, and App
  Store Connect setup are manual.
- Android: real-device validation, Play Console setup, first manual upload if
  required by Play, and Private DNS settings validation are manual.
- Both: real-device install/test and final store copy review.

## Manual Test Flow
1. Build/install an iOS or Android development binary. Run `npm run
   native:prepare:ios` or `npm run native:prepare:android` first; no bridge is
   needed for the installed app.
2. On first run, complete or skip the optional tutorial. Restart the app and
   confirm it does not return; use the top-right Help icon on Check DNS,
   Profiles, and History to reopen it. No permission sheet appears and opening
   or dismissing Help does not request system access.
3. Check DNS: choose General, Vietnam, or a gaming target; run Quick Check,
   DNS + TCP, and current System DNS validation. Confirm per-step/resolver
   status, failure reason, result, details, and Copy report.
4. Result: confirm Fastest observed is separate from the balanced
   recommendation and weak results say Keep current DNS. The sole setup button
   must appear only for a healthy, confident recommendation.
5. Guided settings: tap Set up DNS from a recommendation.
   Expected behavior: DNS values are copied and Settings opens; no silent DNS
   mutation occurs. Tap Retest System DNS after returning.
6. Profiles: add/update/delete plain, DoH, DoT profiles and domain suites; confirm
   invalid forms are disabled before native action calls.
7. History: confirm a saved recommendation says Retest before setup and returns
   to Check DNS instead of applying a stale result.
8. Tablet: rotate iPad and Android tablet portrait/landscape and validate the
   layout stays multi-column, not a stretched phone view.
9. Accessibility: with VoiceOver/TalkBack enabled, confirm buttons, segmented
   choices, switches, inputs, and selected chips announce their label and state.
10. iOS native DoH/DoT: build the opt-in `production-ios-dns` profile. In
    Profiles add a DoH or DoT profile with a valid endpoint and one or more
    bootstrap IPv4/IPv6 addresses, tap Install iOS DNS Settings, then open
    Settings > General > VPN & Device Management > DNS and enable DNSPilot.
    Return to Profiles, tap Refresh DNS status, and expect Installed + Enabled.
    Remove must return Installed to off. This needs an installable build signed
    with the `dns-settings` NetworkExtension capability; Expo Go cannot test it.

## Validation Commands
- `npm run verify`
- `npm run postinstall`
- `npx expo-doctor@latest`
- `npm run start:dev-client`
- `npx expo run:ios --configuration Debug --device "iPhone 17e" --no-bundler --no-install --no-build-cache`
- `npx expo prebuild --clean --platform ios && xcodebuild -workspace ios/DNSPilotMobile.xcworkspace -scheme DNSPilotMobile -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' CODE_SIGNING_ALLOWED=NO build`
- `EAS_BUILD_PROFILE=production xcodebuild -workspace ios/DNSPilotMobile.xcworkspace -scheme DNSPilotMobile -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' CODE_SIGNING_ALLOWED=NO build`
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`
- `EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform android --no-install && EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:processReleaseManifest`
- `EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:assembleRelease`
- `rg -n "expo-dev|DevLauncher|DevMenu|SYSTEM_ALERT_WINDOW|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|VIBRATE|VpnService|BIND_VPN" android/app/build/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml || true`
- `npm test`
- `npm run typecheck`
- `npm run verify:router` (fails on unresolved Expo Router route warnings)
- `git diff --check`

Current iOS local smoke status: the current Release bundle built, installed, and
launched on `iPhone 17e` with iOS 26.5. It showed the first-run tutorial and
header Help icon with no permission sheet. Signed-device proof remains `NOT RUN`.
