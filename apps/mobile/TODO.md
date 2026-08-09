# DNSPilot Mobile Roadmap

Last reviewed: 2026-08-09.

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
- [x] Production Android gate now creates and checks both the Store AAB and a local
  debug-key QA APK under the same production environment; direct Gradle invocation cannot
  accidentally create a dev-client QA artifact.
- [x] Successful process diagnostics suppress the empty failed-step metric; failures still
  show the failed step visibly.
- [x] Production npm audit gate rejects all new high/critical findings while retaining the
  narrowly tested, unremediable Metro `image-size` advisory exception.

## Active Automated Scope

- [x] Build and verify the final Android QA APK locally. SHA-256:
  `c9896d3ef21debc9d78e1c4c93404abfbacf937551e73fd51e018780796e015d`.
- [ ] After shared Core lands, implement D13's separate Health Check and DNS Benchmark.
- [ ] Prove D14 background continuation per OS before implementation; local completion
  notifications remain contextual opt-in and no run auto-retries.

## Manual Release Gates

- [ ] Run the same Android smoke on a Samsung S25 Ultra when it is attached. The
  connected Pixel 9 Pro XL is physical-device evidence but not Samsung-specific proof.
- [ ] Current debug-key QA APK is installed on Pixel 9 Pro XL; unlock the device and execute
  the `mobile-readiness.md` native flow. Earlier Pixel evidence is from the predecessor
  candidate; do not replace this local APK in Play Console.
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
