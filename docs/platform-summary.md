# Platform Summary

Last integration pass: 2026-07-11.

## Branch Integration

`main` is the integrated source of truth for this cross-platform slice. The
latest lane branches merged into `main` are:

- `worktree/mobile`
- `macos`
- `worktree/linux`
- `worktree/windows`

`worktree/core-cli` and `worktree/docs` are fast-forward lanes for shared
contract/docs follow-up. Keep all child branches fast-forwarded from `main` after
integration so future lane work starts from the same context.

Current local branch sync target: after this merge commit, fast-forward clean
child branches from `main`. Keep `worktree/windows` separate while its dirty
feature changes are reviewed and committed.

Architecture note: `worktree/mobile` commit `345c41e` is intentionally not merged;
its native iOS DNS Settings entitlement remains an isolated experiment until Apple
capability approval and signed-device validation.

## Requirement Coverage

| Lane | Current status | Requirement fit | Hard gate before release claim |
| --- | --- | --- | --- |
| Core CLI | Shared Rust catalog, capabilities, compare, path-compare, system-benchmark, preflight, apply-policy, apply-plan, profile/suite/history storage, and progress JSONL contracts are implemented. | Meets the current shell-consumer contract requirements. | Keep schema changes versioned and rerun full Rust workspace tests. |
| macOS | SwiftUI UX lead shell with benchmark, history, custom DNS/suites, menu bar, guided apply, System DNS validation, localization, gated Power edition, privacy manifest, support/privacy copy, and release preflight/smoke scripts. | Meets store-safe app behavior requirements for local validation. | Signing/provisioning, App Store entitlement review, signed distribution bundle validation. |
| Mobile | Expo/React Native bridge shell with benchmark, diagnostics, storage forms, guided settings, System Access recovery, native settings actions, localization, device setup checks, Expo SDK 57, Android debug build evidence, and iOS Simulator build/install/launch smoke evidence. | Meets test-shell and mobile-policy exploration requirements. | Native Rust adapter/backend decision, physical iOS/Android real-device QA, store account/signing flows. |
| Linux | Rust Linux app/session model with egui desktop launcher, CLI harness, package capability detection, store-safe guidance, native-power helper contract/dry-run protocol, packaging policy templates, and README entrypoint. | Meets scoped code-complete native-app/session requirements. | Real Flatpak/Snap/deb/rpm package builds and distro QA before publish or default Power behavior. |
| Windows | .NET/WinUI lane with core view-models, store-safe apply guidance, profile/history management, localization, tray model, Store MSIX manifest/assets, publish profile/script, privacy/listing/support docs. | Meets macOS-verifiable store-safe shell and packaging-prep requirements. | Windows App SDK runtime build, MSIX/tray/manual QA, Partner Center capability review and signing. |

## Cross-Platform Rules

- Default SKU is store-safe: benchmark, explain, copy guidance, settings handoff,
  and retest. Do not silently mutate system DNS in store builds.
- UI copy is concise by default: title/status/action inline, long explanation
  behind info/tooltip/tutorial/copy report.
- Each app has a first-run setup/tutorial surface and a top-right Help/Info
  affordance to reopen it.
- OS provider trust and signing gates are tracked in
  `docs/os-provider-trust.md`; do not ask users to disable OS protections.
- Power/admin DNS mutation stays explicitly gated per platform and separated
  from store-safe UX.
- Every shell should expose the exact capability for its OS/package type rather
  than promising parity.
- Benchmark UX must show step status, resolver status, elapsed time, failure
  reason, and a copyable debug report.
- Saved profiles, saved suites, history, IPv4/IPv6 controls, A/AAAA controls,
  protected-network suppression, and English/Vietnamese user-facing flows are
  now shared product expectations unless a platform doc states a scoped gap.
