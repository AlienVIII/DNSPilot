# DNSPilot Mobile State

Last updated: 2026-09-03.

## Current Truth

- `worktree/mobile` is the current delivery lane. Source may integrate after normal
  gates pass, but the default Store artifact must omit `dns-settings`; only the optional
  entitled artifact remains blocked on Apple approval and signed-device evidence.
- The implemented shell still has three primary tabs: Check DNS, Profiles, and History.
  D13's separate Health Check/DNS Benchmark four-area direction is approved but not
  implemented. Installable builds call shared Rust Core in-process; Expo Go/web use the
  Node bridge only as a development fallback.
- Check DNS starts with foreground DNS-only Quick Check. DNS + TCP and current
  resolver validation are advanced controls. Results distinguish Fastest
  observed, balanced recommendation, and Keep current DNS.
- D14 background continuation/local notification is planned, not implemented. Mobile
  must prove OS support first and must not promise force-quit survival or auto-retry.
- Profiles manages custom plain DNS, DoH, DoT, bootstrap addresses, and domain
  suites. History is retest-only; it never applies a saved recommendation.
- A versioned optional tutorial shows only after preferences load. Skip or Done
  records completion; the top-right Help icon reopens it from every consumer
  tab without a permission request.
- Default iOS Store builds are benchmark-first and guide-only. The separate
  `production-ios-dns` profile enables the restricted DoH/DoT DNS Settings
  experiment; iOS users still enable it in Settings. Android only guides the
  user to Private DNS/network settings. Neither platform silently mutates DNS,
  uses `VpnService`, or flushes system DNS.
- Delete/clear actions have no shared confirmation pattern in this lane. Do not
  add one ad hoc; introduce a shared, tested pattern only when a product-wide
  decision requires it.

## Latest Validation

- On 2026-09-03, `npm run verify` passes: 106 tests, TypeScript, public config, Router
  warning gate, Expo 57.0.19 compatibility, and the production audit policy. npm reports
  4 high findings inherited from Metro's build-time `image-size@1.2.1` chain and 15 moderate
  findings. There is no fixed `image-size` version in the registry and forced npm fixes
  downgrade Expo/React Native, so `npm-audit-policy` allows only advisory sources `1138808` and
  `1138809` plus their known Metro-chain packages; any other high/critical finding fails
  the gate. A direct advisory on an otherwise known package also fails.
- `npx expo-doctor@latest` passes 21/21. `npm run preflight:release` passes Store/optional
  iOS DNS isolation and creates a fresh local Android release-shape AAB and debug-key QA APK
  after clean prebuild.
  Manifest/dex gates confirm no dev client, VPN, overlay, storage, or privileged leakage in
  either artifact. Both local artifacts use the debug certificate and are never upload-ready.
  AAB SHA-256: `4475d1aac8db49cd7de39eb0bf2c7682861c2c22106283afcbd7f07b83ccaedc`.
  QA APK SHA-256: `d8799ff834c1dfe2ee2a1a3fe256abbe57e2dd8873347f923ebb789bbb186601`.
  The APK verifies with the local Android Debug certificate and APK Signature Scheme v2 only.
- iOS Simulator Release with `CODE_SIGNING_ALLOWED=NO` succeeded again on 2026-09-03 after a
  clean iOS prebuild, Rust artifact preparation, and CocoaPods/codegen installation. Default `production`
  omits the iOS DNS Settings plugin/flag; `production-ios-dns` alone enables both.
- The iOS build currently requires the tracked version-specific `expo-modules-jsi` Swift-concurrency
  patch. Treat a future `expo-modules-jsi` update as a native release risk: regenerate its patch and
  repeat the clean Simulator Release build before accepting the dependency update.
- A predecessor debug-key-signed Android release-variant QA APK was installed on a physical Pixel
  9 Pro XL. It launched the in-process Rust runtime without crash; tutorial persistence,
  Help on all consumer tabs, DNS-only Quick Check, DNS + TCP, and history save passed.
  The current QA APK was installed on the physical Pixel (`versionCode 1`, `targetSdk 36`)
  and launch produced no crash log. The device was locked before UI automation could reach
  DNSPilot, so the current artifact's interactive flow remains manual.
  After a Wi-Fi change, physical Pixel smoke again passed DNS-only Quick Check and
  System DNS validation (`526 ms`), including final Vietnamese diagnostics/copy labels
  and no crash. No system DNS setting was changed.
- The newest QA APK installs and launches in the Android emulator. Its first-run tutorial
  is visible without an Android runtime permission prompt. Device/emulator foreground changed
  to another app before post-tutorial automation, so current-result visual QA remains manual.

## Manual Release Gates

### Both Platforms

- **Need:** install a signed internal build and complete the real-device matrix
  in `mobile-readiness.md`.
- **Why manual:** foreground networking, accessibility, tablet layout, and OS
  Settings handoff cannot be proven by simulator/export tests.
- **Inputs:** physical iPhone/iPad and Android phone/tablet, normal Wi-Fi or
  cellular network, and TestFlight/internal-distribution access.
- **Expected:** tutorial persists only after Skip/Done, D13 navigation is coherent when
  implemented, diagnostics are readable, and retest/settings handoff stays user-controlled.

### iOS / iPadOS

- **Need:** Apple Developer membership, App Store Connect app record for
  `com.dnspilot.mobile`, signing/provisioning, privacy/review metadata, and a
  signed default Store build.
- **Why manual:** certificates, provisioning, App Review, and real Settings
  behavior are provider-controlled.
- **Inputs:** Apple Developer and App Store Connect access, team ID, bundle ID,
  support/privacy URLs, screenshots, and review notes describing benchmark and
  guided-settings behavior.
- **Expected:** TestFlight/App Store default build performs benchmarks and
  guided settings only. For the optional profile, Apple must first approve
  `dns-settings`; then validate Install -> user enables DNSPilot in Settings ->
  Refresh reports Enabled -> Remove reports not installed.

### Android

- **Need:** Play Console app for `com.dnspilot.mobile`, Play App Signing,
  Data safety/app-content declarations, internal test upload, and Private DNS
  handoff validation.
- **Why manual:** developer account, upload key/app signing, Play forms, and
  manufacturer Settings paths are external to this workspace.
- **Inputs:** Play Console access, package reservation, App Signing setup,
  privacy/support URLs, Data safety answers, an Android test device, and an Expo account.
  This checkout is not logged into EAS and has no EAS project ID, so the owner must first
  run EAS login/init and configure the remote Android upload credential.
- **Expected:** internal-release app has only normal network permissions; an
  eligible recommendation copies the DoT value and opens Settings, while the
  user performs the DNS change and returns to retest.

## Sources

- Consumer/manual contract: `mobile-readiness.md`.
- Build, publish, and device steps: `mobile-publish-checklist.md`.
- Shared platform boundaries: `../../docs/reference-lane-contract.md` and
  `../../docs/os-provider-trust.md`.
