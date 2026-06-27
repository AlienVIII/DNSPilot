# Mobile Publish Checklist

## Current Release Posture
- App config is prepared for native builds: `ios.bundleIdentifier`,
  `android.package`, version codes, EAS profiles, iOS Local Network usage text,
  Android normal network permissions, and EN/VI locale metadata.
- The app remains store-safe: no iOS plain system DNS switch, no Android silent
  Private DNS mutation, no Android `VpnService`, and no "apply fastest DNS" or
  internet speed claim.
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
   npx expo start --lan --port 8082
   ```
5. Open the app on the device with Expo Go or a development build.
6. Overview: choose language `Auto`, `English`, and `Tiếng Việt`; confirm tab
   titles, validation errors, and guided settings copy update.
7. Overview > Device Setup: choose the real-device target. Confirm localhost is
   rejected for physical phones, Android emulator recommends `10.0.2.2`, and
   store-safe policy says no silent DNS mutation/VpnService.
8. Overview: paste the Mac LAN bridge URL, tap Refresh, then confirm Bridge is
   up and profiles/suites/capabilities/history load.
9. iOS/iPadOS: when prompted for Local Network, tap Allow. If the prompt does
   not appear, check Settings > Privacy & Security > Local Network.
10. Android: no dangerous runtime permission prompt is expected for normal
   network access.
11. Benchmark: run DNS Compare, Path Compare, Single DNS, Single Path, and
    System DNS validation. Confirm per-step/per-resolver status, elapsed time,
    failed step/reason on failures, debug report, and Copy report.
12. Storage: add, edit, and delete plain DNS, DoH, DoT profiles, and custom
    domain suites. Invalid forms must disable actions before bridge calls.
13. Policy/Guided DNS Settings: toggle VPN, MDM, corporate DNS, and captive
    portal. Expected behavior is `protect-current-dns` or guide-only steps, not
    system mutation. Use Copy DNS servers and Open Settings; expected behavior
    is user-controlled OS settings, not an in-app DNS switch.
14. iPad/Android tablet: confirm the layout uses multi-column native tablet
    width and does not stretch a phone UI.

## Native Build Smoke
1. Install and login:
   ```bash
   npm install --global eas-cli
   eas login
   ```
2. Initialize the Expo project if it is not linked yet:
   ```bash
   npx eas-cli@latest init
   ```
3. Build installable internal binaries:
   ```bash
   npx eas-cli@latest build -p ios --profile development
   npx eas-cli@latest build -p android --profile development
   ```
4. Install on real devices and repeat the real-device manual test.

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
