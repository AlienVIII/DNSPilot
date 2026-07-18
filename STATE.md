# DNSPilot State

Last updated: 2026-07-19.

## Current Truth

- `main` integrates macOS through `7609d57`, Linux through `034621c`, Windows through
  `2f3cef0`, and Core/CLI hardening through `8a53a31`.
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
- Mobile remains isolated at `8dd1c26`. Its native consumer/runtime work may merge under
  amended D1 only after current dependency, bridge security, privacy, and UX gates pass.
  The optional entitled iOS artifact remains provider/device blocked.

## Review Findings

- Mobile dev bridge binds the LAN with wildcard CORS, no authentication, and a
  caller-controlled database path. Android currently allows backup of local DNS/history
  data. Both must be hardened before mobile integration.
- macOS Power Restore does not yet compare current DNS with the state DNSPilot applied.
  Store-safe macOS is unaffected; Power remains unreleasable.
- UI parity is functional, not visually proven. No durable signed cross-platform
  screenshot/accessibility matrix exists; real Windows/Linux UI remains `NOT RUN`.
- Lane risk/progress docs contained stale resolved claims. Root state and the 2026-07-19
  overall review now supersede those claims.

## Latest Validation

- macOS: `./script/ci_macos.sh` and
  `./script/preflight_macos_release.sh --include-power` pass; 270 Swift tests pass.
- Linux: fmt, tests, and clippy with `-D warnings` pass at `034621c`.
- Windows: `apps/windows/validate-windows-lane.sh` passes 65 Core/static tests; the
  expected Windows-only XAML compiler remains `NOT RUN` on macOS.
- Core/CLI: `cargo fmt --check`, `cargo test --workspace`, and `git diff --check` pass
  at `8a53a31` (121 tests). Live DNS requests pin the resolver source, use OS entropy
  for transaction IDs, validate response semantics, and serialize snapshot mutations.
- Mobile: 95 tests, typecheck, and route export pass, but `npm run verify` fails because
  Expo now expects `expo 57.0.7`, `expo-constants 57.0.6`, `expo-dev-client 57.0.7`, and
  `expo-router 57.0.7`; release preflight was therefore not reached in this rerun.
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
