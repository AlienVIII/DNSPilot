# Mobile Publish Checklist

## Current Release Posture
- App config is prepared for native builds: `ios.bundleIdentifier`,
  `android.package`, version codes, EAS profiles, iOS Local Network usage text,
  Android normal network permissions, and EN/VI locale metadata.
- Local Android debug smoke passes. iOS Simulator build/install/launch smoke
  passes with Xcode 26.6 and an iOS 26.5 runtime. The app is on Expo SDK 57 /
  React Native 0.86 and carries a narrow
  `expo-modules-jsi@57.0.0` Swift compatibility patch for Xcode 26.
- EAS development builds include `expo-dev-client`; use `npm run
  start:dev-client` after installing the build on a device.
- The app remains store-safe: no iOS plain system DNS switch, no Android silent
  Private DNS mutation, no Android `VpnService`, and no "apply fastest DNS" or
  internet speed claim.
- First-open System Access shows permission/apply/flush status, opens iOS App
  Settings or Android Private DNS/network Settings, and can retest System DNS.
  DNS flush is explicitly unsupported on mobile consumer OS APIs.
- Core/CLI coverage is exercised through the local bridge. A public store build
  that must work without a developer Mac still needs a native Rust adapter or an
  approved backend/bridge decision.

## Real Device Manual Test
1. Put the Mac and phone/tablet on the same trusted Wi-Fi.
2. From `apps/mobile/DNSPilotMobile`, run:
   ```bash
   npm run bridge
   ```
3. Copy the printed `Bridge URL: http://<mac-lan-ip>:8787`.
4. In another terminal, run:
   ```bash
   npm run start:dev-client
   ```
5. Open the installed development build on the device. Expo Go remains usable
   for bridge-only UI checks, but the development build is the native smoke path.
6. Overview: confirm the first-open System Access sheet appears. iOS should
   offer App Settings plus Retest System DNS. Android should offer Private DNS,
   Network Settings, App Settings, and Retest System DNS.
7. Overview: choose language `Auto`, `English`, and `Tiếng Việt`; confirm tab
   titles, validation errors, and guided settings copy update.
8. Overview > Device Setup: choose the real-device target. Confirm localhost is
   rejected for physical phones, Android emulator recommends `10.0.2.2`, and
   store-safe policy says no silent DNS mutation/VpnService.
9. Overview: paste the Mac LAN bridge URL, tap Refresh, then confirm Bridge is
   up and profiles/suites/capabilities/history load.
10. iOS/iPadOS: when prompted for Local Network, tap Allow. If the prompt does
   not appear, check Settings > Privacy & Security > Local Network.
11. Android: no dangerous runtime permission prompt is expected for normal
   network access.
12. Benchmark: run DNS Compare, Path Compare, Single DNS, Single Path, and
    System DNS validation. Confirm per-step/per-resolver status, elapsed time,
    failed step/reason on failures, debug report, and Copy report.
13. Guided settings: tap Apply in OS DNS settings / Prepare DNS profile/settings.
    Expected behavior is copy values + open settings + retest with visible
    success/failure status, not silent apply or DNS cache flush.
14. Storage: add, edit, and delete plain DNS, DoH, DoT profiles, and custom
    domain suites. Invalid forms must disable actions before bridge calls.
15. Policy/Guided DNS Settings: toggle VPN, MDM, corporate DNS, and captive
    portal. Expected behavior is `protect-current-dns` or guide-only steps, not
    system mutation. Use Copy DNS servers and Open Settings; expected behavior
    is user-controlled OS settings, not an in-app DNS switch.
16. iPad/Android tablet: rotate portrait/landscape and confirm the layout uses
    multi-column native tablet width instead of stretching a phone UI.

## Native Build Smoke
1. Run local gates:
   ```bash
   npm run verify
   npm run postinstall
   npx expo-doctor@latest
   npx expo install --check
   npx expo run:ios --configuration Debug --device "iPhone 17e" --no-bundler --no-install --no-build-cache
   npx expo prebuild --platform android --no-install
   ./android/gradlew -p android assembleDebug
   ```
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
1. Confirm `com.dnspilot.mobile` is the final iOS bundle ID and Android package
   before first submission. Android package ID cannot be changed after publish.
2. Apple: create App Store Connect app, configure signing/provisioning, and run:
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
- iOS-only: Apple signing/provisioning, App Store Connect setup, Local Network
  prompt validation, and NetworkExtension DNS Settings entitlement only if a
  future native DNS profile installer is added and approved.
- Android-only: Play Console app/service account, first manual upload if Play
  API requires it, and manual Private DNS settings validation.
- Both: real-device install/test and final store copy review.
