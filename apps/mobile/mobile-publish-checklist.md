# Mobile Publish Checklist

## Current Release Posture
- App config is prepared for native builds: `ios.bundleIdentifier`,
  `android.package`, version codes, EAS profiles, development-only iOS Local
  Network usage text for bridge fallback, Android normal network permissions,
  and EN/VI locale metadata.
- Shared UX/provider gate references: `docs/ux-copy-onboarding.md` and
  `docs/os-provider-trust.md`.
- Local Android debug smoke passes. iOS Simulator build/install/launch smoke
  passes with Xcode 26.6 and an iOS 26.5 runtime. The app is on Expo SDK 57 /
  React Native 0.86 and carries a narrow
  `expo-modules-jsi@57.0.1` Swift compatibility patch for Xcode 26.
- EAS development builds include `expo-dev-client`; use `npm run
  start:dev-client` after installing the build on a device. Production/preview
  profiles exclude dev-client/dev-menu modules during Expo config and native
  autolinking.
- Android production release manifest generation is clean of dev-client,
  dev-launcher/menu classes, dev-only overlay/storage/vibrate permissions, VPN
  permissions, and silent system-DNS mutation permissions.
- The app remains store-safe: no iOS plain system DNS switch, no Android silent
  Private DNS mutation, no Android `VpnService`, and no "apply fastest DNS" or
  internet speed claim.
- Default iOS Store builds omit the `dns-settings` entitlement. The separate
  `production-ios-dns` profile is for Apple-approved/signed DoH/DoT DNS
  Settings validation only; iOS still requires user enablement and plain DNS
  remains guide-only.
- Check DNS has no app-open permission sheet. Setup begins only from a valid
  recommendation; Android opens Private DNS/network Settings, and DNS flush is
  explicitly unsupported.
- Manual language selection persists in native app storage across restarts.
- Installable native builds execute the shared Rust core in-process. The local
  bridge is limited to Expo Go/web development fallback and is not a release
  dependency.

## Real Device Manual Test
1. From `apps/mobile/DNSPilotMobile`, prepare the target native artifact:
   ```bash
   npm run native:prepare:ios
   npm run native:prepare:android
   ```
2. In another terminal, run:
   ```bash
   npm run start:dev-client
   ```
3. Open the installed development build on the device. The native runtime does
   not require a developer Mac, LAN bridge, or backend.
4. Open **Check DNS**: confirm no permission sheet appears. The top-right help
   entry must state foreground-only diagnostics and no DNS flush. Android setup
   must open Private DNS/network Settings only after an eligible result.
5. Profiles: choose language `Auto`, `English`, and `Tiếng Việt`; confirm tab
   titles, validation errors, process status labels, and guided settings copy
   update. Restart the app and confirm the last manual language choice remains.
6. Confirm Check DNS, Profiles, and History are the only visible consumer tabs;
   native runtime loads profiles/suites/history and does not show bridge setup.
7. iOS/iPadOS: native benchmark diagnostics use normal foreground network
   access; no Local Network bridge prompt is expected.
8. Android: no dangerous runtime permission prompt is expected for normal
   network access.
9. Check DNS: run Quick Check, DNS + TCP, and System DNS validation. Confirm
    per-step/per-resolver status, elapsed time, failed step/reason, details,
    and Copy report. Confirm Fastest observed differs from the balanced
    recommendation when reliability requires it.
10. Guided settings: tap Set up DNS from a healthy recommendation.
    Expected behavior is copy values + open settings + retest with visible
    success/failure status, not silent apply or DNS cache flush.
11. Profiles: add, edit, and delete plain DNS, DoH, DoT profiles, and custom
    domain suites. Invalid forms must disable actions before native calls.
12. History: confirm saved recommendation offers Retest before setup, never an
    apply action. Use Copy DNS servers and Open Settings only after a fresh
    recommendation; expected behavior is user-controlled OS settings, not an
    in-app DNS switch.
13. iPad/Android tablet: rotate portrait/landscape and confirm the layout uses
    multi-column native tablet width instead of stretching a phone UI.
14. iOS/iPadOS native DNS Settings: only in a signed `production-ios-dns`
    build, create a DoH or DoT profile in Profiles with bootstrap IP addresses, tap
    Install iOS DNS Settings, then explicitly enable DNSPilot from Settings >
    General > VPN & Device Management > DNS. Return and refresh status; expect
    Installed and Enabled. Tap Remove DNS Settings and confirm Installed turns
    off. Expo Go cannot exercise this local native module.

## Native Build Smoke
1. Run local gates:
   ```bash
   npm run verify
   npm run postinstall
   npx expo-doctor@latest
   npx expo install --check
   npx expo run:ios --configuration Debug --device "iPhone 17e" --no-bundler --no-install --no-build-cache
   npx expo prebuild --clean --platform ios
   xcodebuild -workspace ios/DNSPilotMobile.xcworkspace -scheme DNSPilotMobile -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' CODE_SIGNING_ALLOWED=NO build
   npx expo prebuild --platform android --no-install
   ./android/gradlew -p android assembleDebug
   EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform android --no-install
   EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:processReleaseManifest
   rg -n "expo-dev|DevLauncher|DevMenu|SYSTEM_ALERT_WINDOW|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|VIBRATE|VpnService|BIND_VPN" android/app/build/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml || true
   ```
   The final `rg` command should print no matches.
2. Install and login:
   ```bash
   npm install --global eas-cli
   eas login
   ```
3. Initialize the Expo project if it is not linked yet:
   ```bash
   npx eas-cli@latest init
   ```
4. Build installable internal binaries:
   ```bash
   npx eas-cli@latest build -p ios --profile development
   npx eas-cli@latest build -p android --profile development
   ```
5. Install on real devices and repeat the real-device manual test.

## Store Submission Steps
Review `docs/os-provider-trust.md` before starting so Apple Developer,
App Store Connect, Play Console, signing, Data safety, privacy/support URL, and
first-upload work can be batched once.

1. Confirm `com.dnspilot.mobile` is the final iOS bundle ID and Android package
   before first submission. Android package ID cannot be changed after publish.
2. Apple: submit the default `production` Store build without Network
   Extensions. Only after Apple approves DNS Settings for
   `com.dnspilot.mobile`, regenerate the provisioning profile and use
   `production-ios-dns` for signed capability validation:
   ```bash
   npx eas-cli@latest build -p ios --profile production
   npx eas-cli@latest submit -p ios --profile production
   ```
3. Google Play: create Play Console app, set up a service account, upload the
   first Android build manually if required by Play, then run:
   ```bash
   npx eas-cli@latest build -p android --profile production
   npx eas-cli@latest submit -p android --profile production
   ```
4. Store metadata: describe "DNS benchmarking and guided DNS settings" only.
   Do not claim automatic fastest DNS apply, silent DNS switching, VPN behavior,
   or internet speed improvement.
5. Privacy/Data Safety: disclose network diagnostics and user-entered DNS
   profiles/suites. No account, tracking, precise location, contacts, camera,
   microphone, or background scheduler is expected in the current app.

## Remaining Manual Blockers
- iOS-only: Apple signing/provisioning, App Store Connect setup, optional
  Network Extensions `dns-settings` capability enablement,
  and final DoH/DoT profile validation on a signed physical device.
- Android-only: Play Console app/service account, first manual upload if Play
  API requires it, and manual Private DNS settings validation.
- Both: real-device install/test and final store copy review.
