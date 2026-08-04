# Mobile Readiness

Last reviewed: 2026-08-04.

## Green Before Main Integration

- [x] `npm run verify` passes with Expo 57.0.10-compatible patches (98 tests,
  typecheck, router export, Expo compatibility check).
- [x] `npm run preflight:release` passes after clean generated Android build;
  production AAB, Store manifest, and dex capability checks pass.
- [x] Default iOS Store public config omits `dns-settings`; the opt-in profile
  remains deterministic and separately blocked.
- [x] Android production manifest excludes dev-client, VPN/overlay/storage leakage and
  disables backup. The iOS native runtime excludes its `Application Support/DNSPilot`
  directory from backup; simulator/device verification remains open.
- [x] Native Rust contract tests, typecheck, Router, iOS Simulator Release build,
  Android release AAB, and APK signature verification pass.
- [x] Dev bridge is loopback-only by default. Explicit LAN mode has a per-run bearer
  token and origin allowlist; the server owns the database path, redacts HTTP output,
  bounds jobs, and supports cancellation.
- [x] Check DNS first-run state hides empty Process/Result and keeps the primary quick
  check action above advanced controls. Broader physical-device copy review remains open.
- [ ] Tutorial/Help and advanced disclosure are keyboard/touch/assistive reachable
  on physical devices.

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
