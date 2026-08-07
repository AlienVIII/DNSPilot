# DNSPilot State

Last updated: 2026-08-07.

## Current Truth

- `main` is the integration source of truth. It includes the verified macOS source-build
  merge at `28a910e`, prior Linux/Windows lane milestones, mobile baseline `234a2e0`,
  and shared Core/CLI hardening through `8360ba7`.
- Rust Core/CLI remains the only owner of benchmark, recommendation, policy, storage,
  and versioned JSON/JSONL contracts.
- Independent validation checks may run in background from isolated clean worktrees, but only
  reaped tasks with an exit code and complete log count as evidence.
- Product background execution is a separate D14 contract: one user-initiated read-only
  measurement may continue while its UI is inactive under OS limits, then use an
  opt-in local completion notification. There is no remote push, silent scheduler,
  background DNS mutation, force-quit guarantee, or automatic retry.
- Product direction now separates read-only Network Health Check from DNS Benchmark.
  The guided journey recommends Health Check first and DNS selection last; this is an
  approved design direction, not an implemented or validated feature.
- Health Check will not use router credentials or mutate router/OS network state. DNS
  Benchmark keeps a user-selected resolver pool, separate A/IPv4 and AAAA/IPv6
  measurements, and a 500 ms maximum per DNS attempt.
- macOS Store-safe behavior, semantic EN/VI localization, packaging, and source-build
  workflow are integrated. `./script/ci_macos.sh` passed on 2026-08-07, including the
  source-build contract, Rust workspace, and 274 Swift tests. The local workflow builds,
  ad-hoc signs, validates, and opens `dist/DNSPilot.app`; certificate-backed distribution,
  signed visual/accessibility evidence, and provider steps remain open.
- Linux milestones 0-5 are substantially implemented: Power is fail-closed, Core
  contracts/storage are typed/shared, progress is streamed/cancellable, and the
  consumer decision/history loop exists. Accessibility, source-built packages, and
  real Linux evidence remain open.
- Windows milestones 0-4 and release preparation are committed. Core/static tests pass;
  WinUI/XAML/MSIX/tray/accessibility evidence still requires Windows.
- Mobile baseline is integrated through `234a2e0`: bridge access is loopback-by-default
  and LAN-token protected, local data is excluded from Android/iOS backup, and first-run
  UI hides empty technical sections. Its newer local release candidate is not integrated
  because current Expo patch alignment is red.

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
  summaries expose typed recommendation `gate_note_ids`; Capability Matrix, Preflight, and
  Apply Prompt Policy, Apply Plan, profile security, and connection-path caveats also have typed
  IDs, while old history remains readable.
- Mobile candidate: 99 tests, typecheck, Expo config, and router export pass on
  2026-08-07, but `npm run verify` is red at `expo install --check`. Expo now expects
  `expo`/`expo-router` 57.0.11 and `expo-symbols` 57.0.2; the audit step did not run.
  The candidate remains unmerged. Earlier Android AAB and iOS Simulator evidence is
  historical and does not make this candidate green.
- Dependency review: RustSec reports no known Rust advisories; NuGet reports no known
  vulnerable Windows packages; npm reports 11 moderate and no high/critical findings.
- Historical mobile web visual QA at 390px confirms tutorial/Help and three primary tabs,
  which now predates D13's four-area product direction. It also
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
