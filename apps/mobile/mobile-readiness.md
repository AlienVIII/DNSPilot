# Mobile Readiness

Last reviewed: 2026-08-07.

## Green Before Main Integration

- [x] `npm run verify` passes with Expo 57.0.11/router 57.0.11/symbols 57.0.2:
  100 tests, typecheck, public config, Router export/warning gate, compatibility, and
  audit high threshold. Eleven moderate transitive `uuid` findings remain; forced audit
  fix is rejected because it would downgrade Expo.
- [x] `npm run preflight:release` passes after clean production prebuild and produces a
  fresh Android AAB with manifest/dex Store gates.
- [ ] Default iOS Store generated and signed entitlements omit `dns-settings`; public
  config isolation passes, but final signed evidence remains manual.
- [x] Android production manifest excludes dev-client, VPN/overlay/storage leakage and
  disables backup. The iOS native runtime excludes its `Application Support/DNSPilot`
  directory from backup; simulator/device verification remains open.
- [x] Native Rust jobs pass unit, type, Router, iOS Simulator Release, and Android
  release smoke on the same green candidate. The final debug-key QA APK installed and
  launched on Pixel; after a Wi-Fi change, DNS-only Quick Check and System DNS validation
  passed with final Vietnamese diagnostics and no crash. No system DNS setting was changed.
- [x] Dev bridge is loopback-only by default. Explicit LAN mode has a per-run bearer
  token and origin allowlist; the server owns the database path, redacts HTTP output,
  bounds jobs, and supports cancellation.
- [x] Check DNS first-run state hides empty Process/Result and keeps the primary quick
  check action above advanced controls. Broader physical-device copy review remains open.
- [ ] Tutorial/Help and advanced disclosure are keyboard/touch/assistive reachable.
- [ ] D13 exposes separate Health Check and DNS Benchmark without a shared hidden score.
- [ ] D14 feasibility is proven per OS before background continuation is enabled; local
  notifications are contextual opt-in and no interrupted run auto-retries.

## Native Manual Flow

1. Install signed iOS and Android builds; no bridge is used. For the connected
   S25 Ultra local QA artifact, first accept the USB-debugging RSA prompt.
2. Complete/skip tutorial, restart, confirm it stays complete, reopen Help on all tabs,
   and confirm passive Help does not request system access.
3. Run Quick Check, Advanced DNS+TCP, and System DNS; verify progress, cancellation,
   recommendation vs fastest observed, Keep current DNS, report, and saved history.
4. Set up only from a healthy Core recommendation; copy/open OS Settings and retest.
5. Add/edit/delete plain/DoH/DoT profiles and suites; invalid forms and built-ins fail
   closed.
6. Validate phone/tablet rotation, EN/VI, font scaling, VoiceOver/TalkBack, backup/restore,
   offline/restart, and protected VPN/managed network guidance.
7. Android: validate Private DNS handoff; no VPN service or silent mutation.
8. Optional iOS only: sign with Apple `dns-settings`, install/enable/status/remove DoH/DoT
   settings on a physical device. This does not block default Store release.
9. After D14 exists: test app switch/background completion, notification allow/deny,
   cancellation, OS expiration, Force Quit, generic lock-screen copy, and result activation.

## Automated Commands

```bash
npm run verify
npm run preflight:release
npx expo-doctor@latest
npm run native:prepare:ios
npm run native:prepare:android
npm run verify:router
git diff --check
```

Physical devices, signing, provider accounts/capability approval, and store submission
remain manual. See `docs/os-provider-trust.md`.
