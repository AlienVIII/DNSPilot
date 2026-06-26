# Platform Summary

Last integration pass: 2026-06-26.

## Branch Integration

`main` is the integrated source of truth for the current cross-platform slice.
The active lane branches merged into `main` were:

- `worktree/mobile`
- `macos`
- `worktree/linux`
- `worktree/windows`

`worktree/core-cli` and `worktree/docs` had no additional commits at the time of
integration. Keep child branches fast-forwarded from `main` after shared docs or
contract changes so future lane work starts from the same context.

## Requirement Coverage

| Lane | Current status | Requirement fit | Hard gate before release claim |
| --- | --- | --- | --- |
| Core CLI | Shared Rust catalog, benchmark, compare, path-compare, storage, apply-policy, apply-plan, and system-DNS validation contracts are implemented. | Meets the current shell-consumer contract requirements. | Keep schema changes versioned and rerun full Rust workspace tests. |
| macOS | SwiftUI UX lead shell with benchmark, history, custom DNS/suites, menu bar, guided apply, System DNS validation, localization, and gated Power edition. | Meets store-safe app behavior requirements for local validation. | Signing/provisioning, App Store entitlement review, distribution bundle validation. |
| Mobile | Expo/React Native bridge shell with benchmark, diagnostics, storage forms, guided settings, localization, and device setup checks. | Meets test-shell and mobile-policy exploration requirements. | Native Rust adapter/backend decision, iOS/Android real-device QA, store account/signing flows. |
| Linux | Rust Linux app/session model, CLI harness, package capability detection, store-safe guidance, native-power helper contract, packaging policy templates. | Meets scoped code-complete/headless lane requirements. | Native GUI adapter choice, real Flatpak/Snap/deb/rpm package QA, privileged helper implementation if Power path proceeds. |
| Windows | .NET/WinUI lane with core view-models, store-safe apply guidance, profile/history management, localization, tray model, package scaffolding. | Meets macOS-verifiable store-safe shell logic requirements. | Windows App SDK runtime build, MSIX/tray/manual QA, Partner Center capability review. |

## Cross-Platform Rules

- Default SKU is store-safe: benchmark, explain, copy guidance, settings handoff,
  and retest. Do not silently mutate system DNS in store builds.
- Power/admin DNS mutation stays explicitly gated per platform and separated
  from store-safe UX.
- Every shell should expose the exact capability for its OS/package type rather
  than promising parity.
- Benchmark UX must show step status, resolver status, elapsed time, failure
  reason, and a copyable debug report.
- Saved profiles, saved suites, history, IPv4/IPv6 controls, A/AAAA controls,
  protected-network suppression, and English/Vietnamese user-facing flows are
  now shared product expectations unless a platform doc states a scoped gap.
