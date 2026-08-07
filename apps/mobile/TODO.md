# DNSPilot Mobile Roadmap

Last reviewed: 2026-08-07.

## Completed Automated Scope

- [x] Store-safe Check DNS / Profiles / History consumer shell.
- [x] Foreground DNS-only, DNS + TCP, and system-resolver validation with
  diagnostics, reports, EN/VI, tablet layout, profiles, suites, and history.
- [x] Shared optional tutorial/Help with versioned persistence and no startup
  permission request.
- [x] Expo Router unresolved-route gate, Store profile entitlement isolation,
  Android release-manifest checks, and iOS Simulator consumer smoke.
- [x] Expo SDK 57.0.11 patch alignment, Rust runtime/Core contract checks, a fresh
  Android production AAB, and iOS Simulator Release build.

## Active Automated Scope

- [x] Rebuild/install the final Android QA APK on the connected Pixel. SHA-256:
  `08fd871028d95156a2d0dd4b652ead30d4d81186348d9e0a54347b474577923b`.
- [ ] After shared Core lands, implement D13's separate Health Check and DNS Benchmark.
- [ ] Prove D14 background continuation per OS before implementation; local completion
  notifications remain contextual opt-in and no run auto-retries.

## Manual Release Gates

- [ ] Run the same Android smoke on a Samsung S25 Ultra when it is attached. The
  connected Pixel 9 Pro XL is physical-device evidence but not Samsung-specific proof.
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
- No periodic/silent background benchmark scheduler. D14 permits only one explicitly
  user-started run to continue under proven OS limits; it never auto-retries.
- No ad hoc destructive-action confirmation; use a shared pattern only after a
  product-wide decision and test contract.

## References

- `STATE.md`
- `mobile-readiness.md`
- `mobile-publish-checklist.md`
- `../../docs/os-provider-trust.md`
