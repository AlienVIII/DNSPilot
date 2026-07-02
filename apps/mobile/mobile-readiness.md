# Mobile Readiness

## Main Goal Checklist
- Benchmark/recommendation UI: covered through CLI bridge jobs, foreground-only
  progress polling, result summary, recommendation JSON, diagnostics, and copy
  report.
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
- Native-style access prompt: covered on app open with Local Network/network
  access checks, OS-gated DNS apply status, iOS App Settings, Android Private
  DNS/network Settings, in-sheet System DNS retest, and explicit DNS flush
  unsupported status.
- Tablet layouts: covered by shared adaptive layout helpers, two-column flows on
  wide screens, and unlocked orientation for native portrait/landscape checks.
- IPv4/IPv6 and A/AAAA controls: covered by benchmark IP-family controls and
  help text.
- Vietnam/default suites: covered when the core catalog exposes
  `general-browsing` and `vietnam-daily`.
- Multilingual UX: covered for primary app chrome and workflows with system
  locale detection, manual English/Tiếng Việt override, localized validation
  errors, localized option controls, and localized guided DNS settings steps.
- Native build metadata: covered for iOS bundle ID/build number, Android package
  ID/version code, EN/VI supported locales, iOS Local Network permission text,
  Android normal network permissions, and EAS build profiles.
- Native build smoke: covered by local Android `assembleDebug`; the app is on
  Expo SDK 57 / React Native 0.86 with a narrow `expo-modules-jsi@57.0.0` Swift
  compatibility patch for Xcode 26. iOS Simulator build/install/launch smoke
  passes with Xcode 26.6 and an iOS 26.5 runtime.
- Development client flow: covered by `expo-dev-client`, launcher-mode config,
  and a `npm run start:dev-client` LAN script for installable real-device
  development builds.
- Real-device setup UX: covered by an in-app Device Setup evaluator that checks
  localhost vs LAN/emulator bridge URLs, OS permission expectations, and
  store-safe DNS mutation policy before benchmark testing.
- Native accessibility UX: covered for primary buttons, segmented controls,
  switches, text inputs, and selectable chips with labels and state metadata for
  real-device assistive technology checks.

## Critique
- Expo plus local Node bridge is the fastest store-safe test shell, but it is
  not the final public-store architecture if the app must work without a
  developer Mac. Expo Go cannot spawn or link Rust CLI inside the app process.
- The current app is honest about mobile OS limits. It does not silently mutate
  system DNS, does not use Android VpnService, and does not offer iOS
  DNSJumper-style plain DNS switching.
- The bridge contract is useful for validating UX and core payloads, but native
  release work must replace it with a direct Rust binding or approved native
  adapter.
- Guided settings is intentionally conservative. It may feel less powerful than
  desktop DNS switching, but that is the correct consumer mobile policy stance.
- "Apply" on mobile means user-approved OS settings/profile flow. The app can
  prepare values and open the right settings surface, but it cannot silently
  mutate iOS DNS settings, Android Private DNS, or flush system DNS cache.
- Live progress is implemented as foreground polling. This avoids background
  scheduler risk, but long worst-case benchmarks still need the app to stay
  open.
- Real-device testing is now easier because the bridge prints private LAN URLs,
  but iOS Local Network permission, Android device networking, signing, store
  account flows, and final OS settings validation are still inherently manual.

## Remaining Blockers
- iOS/iPadOS: real-device validation, Local Network prompt behavior, Apple
  signing/provisioning, and App Store Connect setup are manual.
- Android: real-device validation, Play Console setup, first manual upload if
  required by Play, and Private DNS settings validation are manual.
- Both: a public store build that must work without a developer Mac requires a
  native Rust adapter or approved backend/bridge decision.

## Manual Test Flow
1. Run `npm run bridge` from `apps/mobile/DNSPilotMobile`.
2. Copy the printed `Bridge URL: http://<mac-lan-ip>:8787` for physical device
   testing.
3. Run `npm start` for Expo Go, or `npm run start:dev-client` for an installed
   development build.
4. Use `http://localhost:8787` on web/iOS Simulator. Use the Mac LAN URL for a
   physical phone. Use `http://10.0.2.2:8787` for Android emulator if needed.
5. Overview: switch Auto/English/Tiếng Việt, choose the correct Device Setup
   target, confirm localhost is rejected for physical phones, paste the Mac LAN
   URL, refresh bridge, and confirm profiles/suites/capabilities/history load.
6. On first open, confirm System Access appears. iOS: tap Open App Settings if
   Local Network was denied, return to the app, then tap Retest System DNS.
   Android: tap Open Private DNS, confirm Android opens Private DNS or falls
   back to network settings, return to the app, then tap Retest System DNS.
7. If iOS asks for Local Network, allow it for bridge testing.
8. Benchmark: choose Default or Vietnam suite, select profiles, run DNS Compare
   and Path Compare, confirm live progress rows, final result, copy report, and
   guided settings plan.
9. Guided settings: tap Apply in OS DNS settings / Prepare DNS profile/settings.
   Expected behavior: DNS values are copied and Settings opens; no silent DNS
   mutation occurs. Tap Retest System DNS after returning.
10. Benchmark System DNS: choose iOS or Android, run with a suite/domain, confirm
   system validation result and diagnostics.
11. Storage: add/update/delete plain, DoH, DoT profiles and domain suites; confirm
   invalid forms are disabled before bridge calls.
12. Policy: toggle VPN/MDM/corporate DNS/captive portal and confirm guidance
   switches to protect-current-dns when required.
13. Tablet: rotate iPad and Android tablet portrait/landscape and validate the
    layout stays multi-column, not a stretched phone view.
14. Accessibility: with VoiceOver/TalkBack enabled, confirm buttons, segmented
    choices, switches, inputs, and selected chips announce their label and state.

## Validation Commands
- `npm run verify`
- `npm run postinstall`
- `npx expo-doctor@latest`
- `npm run start:dev-client`
- `npx expo run:ios --configuration Debug --device "iPhone 17e" --no-bundler --no-install --no-build-cache`
- `npx expo prebuild --platform android --no-install && ./android/gradlew -p android assembleDebug`
- `npm test`
- `npm run typecheck`
- `npx expo export --platform web`
- `git diff --check`

Current iOS local smoke status: build passed on `iPhone 17e` with iOS 26.5.
Because port 8081 was already owned by another process, app UI smoke used
`npm run start:dev-client` on port 8082 after install/launch and confirmed the
first-open System Access sheet by screenshot.
