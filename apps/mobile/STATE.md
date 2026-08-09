# DNSPilot Mobile State

Last updated: 2026-08-09.

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

- On 2026-08-09, `npm run verify` passes: 106 tests, TypeScript, public config, Router
  warning gate, Expo compatibility, and the production audit policy. npm currently reports
  14 high findings inherited from Metro's build-time `image-size@1.2.1` chain and 8 moderate
  `uuid` findings. There is no fixed `image-size` version in the registry and forced npm fixes
  downgrade Expo/React Native, so `npm-audit-policy` allows only advisory sources `1138808` and
  `1138809` plus their known Metro-chain packages; any other high/critical finding fails
  the gate. A direct advisory on an otherwise known package also fails.
- `npx expo-doctor@latest` remains 20/20. `npm run preflight:release` passes Store/optional
  iOS DNS isolation and creates a fresh Android AAB and debug-key QA APK after clean prebuild.
  Manifest/dex gates confirm no dev client, VPN, overlay, storage, or privileged leakage in
  either artifact. AAB SHA-256: `d23f0a379a31e2caec5b6c999efaab118453922ed4a6e59c7281d2fc62bc80f8`.
  QA APK SHA-256: `c9896d3ef21debc9d78e1c4c93404abfbacf937551e73fd51e018780796e015d`.
- iOS Simulator Release with `CODE_SIGNING_ALLOWED=NO` succeeded again on 2026-08-09. Default `production`
  omits the iOS DNS Settings plugin/flag; `production-ios-dns` alone enables both.
- A predecessor debug-key-signed Android release-variant QA APK was installed on a physical Pixel
  9 Pro XL. It launched the in-process Rust runtime without crash; tutorial persistence,
  Help on all consumer tabs, DNS-only Quick Check, DNS + TCP, and history save passed.
  The current QA APK has been built and verified locally, but has not been installed on the
  physical Pixel because it was in use by another app during this final pass.
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
  privacy/support URLs, Data safety answers, and an Android test device.
- **Expected:** internal-release app has only normal network permissions; an
  eligible recommendation copies the DoT value and opens Settings, while the
  user performs the DNS change and returns to retest.

## Sources

- Consumer/manual contract: `mobile-readiness.md`.
- Build, publish, and device steps: `mobile-publish-checklist.md`.
- Shared platform boundaries: `../../docs/reference-lane-contract.md` and
  `../../docs/os-provider-trust.md`.
