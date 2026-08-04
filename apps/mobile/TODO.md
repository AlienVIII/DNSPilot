# DNSPilot Mobile Roadmap

Last reviewed: 2026-08-04.

## Completed Automated Scope

- [x] Store-safe Check DNS / Profiles / History consumer shell.
- [x] Foreground DNS-only, DNS + TCP, and system-resolver validation with
  diagnostics, reports, EN/VI, tablet layout, profiles, suites, and history.
- [x] Shared optional tutorial/Help with versioned persistence and no startup
  permission request.
- [x] Expo Router unresolved-route gate, Store profile entitlement isolation,
  Android release-manifest checks, and iOS Simulator consumer smoke.
- [x] Expo SDK 57.0.10 patch alignment, Rust runtime/Core contract checks, and
  a fresh Android production AAB plus locally installable release-variant APK.

## Manual Release Gates

- [ ] Authorize the connected Samsung S25 Ultra for ADB, install the local
  release-variant APK, and record on-device smoke evidence.
- [ ] Run signed physical iOS/iPadOS and Android device QA using
  `mobile-readiness.md`; record pass/fail evidence and screenshots.
- [ ] Apple: create/confirm App Store Connect record, signing/provisioning,
  privacy/review metadata, support/privacy URLs, and submit the default
  `production` build.
- [ ] Google: create/confirm Play Console app, configure Play App Signing,
  complete Data safety/content forms, upload internal test AAB, and validate
  Private DNS handoff.
- [ ] Apple optional capability: request/obtain `dns-settings` approval, then
  run the signed `production-ios-dns` device flow. This is not a prerequisite
  for the default benchmark-first Store SKU.

## Non-Goals Until Evidence Changes

- No iOS plain system-DNS switch.
- No Android silent Private DNS mutation or `VpnService`.
- No background benchmark scheduler.
- No ad hoc destructive-action confirmation; use a shared pattern only after a
  product-wide decision and test contract.

## References

- `STATE.md`
- `mobile-readiness.md`
- `mobile-publish-checklist.md`
- `../../docs/os-provider-trust.md`
