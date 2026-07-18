# DNSPilot State

Last updated: 2026-07-19.

## Current Truth

- `main` integrates macOS rollback hardening through `4f7f750`, Linux through
  `034621c`, Windows through `2f3cef0`, and Core/CLI hardening through `d6df518`.
- Rust Core/CLI remains the only owner of benchmark, recommendation, policy, storage,
  and versioned JSON/JSONL contracts.
- macOS Store-safe behavior, semantic EN/VI localization, packaging, and local release
  preflight pass. Signed visual/accessibility evidence and provider steps remain open.
- Linux milestones 0-5 are substantially implemented: Power is fail-closed, Core
  contracts/storage are typed/shared, progress is streamed/cancellable, and the
  consumer decision/history loop exists. Accessibility, source-built packages, and
  real Linux evidence remain open.
- Windows milestones 0-4 and release preparation are committed. Core/static tests pass;
  WinUI/XAML/MSIX/tray/accessibility evidence still requires Windows.
- Mobile is integrated through `234a2e0`: Expo patch versions are current, bridge access is
  loopback-by-default and LAN-token protected, local data is excluded from Android/iOS
  backup, and first-run UI hides empty technical sections. Android Release AAB (87 MB),
  manifest, and dex gates pass; `xcodebuild` now reports `BUILD SUCCEEDED` for iOS
  Simulator Release without code signing.

## Review Findings

- UI parity is functional, not visually proven. No durable signed cross-platform
  screenshot/accessibility matrix exists; real Windows/Linux UI remains `NOT RUN`.
- Lane risk/progress docs contained stale resolved claims. Root state and the 2026-07-19
  overall review now supersede those claims.

## Latest Validation

- macOS: `./script/ci_macos.sh` and
  `./script/preflight_macos_release.sh --include-power` pass; 274 Swift tests pass.
  Power Restore verifies the applied DNS state before it can mutate DNS.
- Linux: fmt, tests, and clippy with `-D warnings` pass at `034621c`.
- Windows: `apps/windows/validate-windows-lane.sh` passes 65 Core/static tests; the
  expected Windows-only XAML compiler remains `NOT RUN` on macOS.
- Core/CLI: `cargo fmt --check`, `cargo test --workspace`, and `git diff --check` pass
  at `86f314b` (137 tests). Live DNS requests pin the resolver source, use OS entropy
  for transaction IDs, validate response semantics, serialize snapshot mutations, and
  emit versioned progress runs with terminal/failure/cancellation semantics. Benchmark
  summaries expose typed recommendation `gate_note_ids`; Capability Matrix notes also have
  typed IDs, while old history remains readable.
- Mobile: `npm run verify` passes 98 tests, typecheck, Expo config/router export,
  dependency compatibility, and high-severity audit threshold. Android `bundleRelease`
  passes in 5m19s; the 87 MB AAB passes manifest and dex release gates. iOS Simulator
  Release build completes with `BUILD SUCCEEDED` under `CODE_SIGNING_ALLOWED=NO`.
- Dependency review: RustSec reports no known Rust advisories; NuGet reports no known
  vulnerable Windows packages; npm reports 11 moderate and no high/critical findings.
- Mobile web visual QA at 390px confirms tutorial/Help and three primary tabs, but also
  confirms repeated titles, implementation jargon, premature empty sections, and a
  first-run bridge fetch error.

## Manual Release Gates

- macOS: Apple signing/provisioning, hosted support/privacy URLs, signed EN/VI visual
  and VoiceOver evidence, five-user usability, App Store submission, and real Power QA.
- Windows: Windows-host WinUI/MSIX/tray/accessibility QA, signing, Partner Center.
- Linux: source-built package CI, GNOME/KDE/resolver QA, signing, publisher accounts.
- Mobile: signed physical-device QA, Apple/Google accounts, store submission, and Apple
  entitlement/provisioning evidence only for the optional entitled profile.

## Sources

- Architecture: `PROJECT.md`
- Roadmap: `TODO.md`
- Overall review: `docs/research/2026-07-19-overall-product-review.md`
- Cross-platform contract: `docs/reference-lane-contract.md`
- Provider steps: `docs/os-provider-trust.md`
