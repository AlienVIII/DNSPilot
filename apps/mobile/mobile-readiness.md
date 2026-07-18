# Mobile Readiness

Last reviewed: 2026-07-19.

## Green Before Main Integration

- [ ] `npm run verify` passes with current Expo-compatible patches.
- [ ] `npm run preflight:release` passes after clean generated iOS/Android builds.
- [ ] Default iOS Store generated/signed entitlements omit `dns-settings`; the opt-in
  profile remains deterministic and separately blocked.
- [ ] Android production manifest excludes dev-client, VPN/overlay/storage leakage and
  applies the approved backup policy; iOS applies the equivalent local-data policy.
- [ ] Native Rust jobs pass unit, type, Router, iOS Simulator, and Android release smoke.
- [ ] Dev bridge is loopback-only by default; LAN mode requires per-run auth/origin
  controls, fixed app database, redacted output, bounded jobs, and cancellation.
- [ ] Check DNS first-run state has one title/status/action, no empty Process/Result, no
  raw fetch error, and no implementation jargon.
- [ ] Tutorial/Help and advanced disclosure are keyboard/touch/assistive reachable.

## Native Manual Flow

1. Install signed iOS and Android builds; no bridge is used.
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
