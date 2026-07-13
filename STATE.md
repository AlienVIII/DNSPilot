# DNSPilot State

Last updated: 2026-07-13.

## Current Truth

- `main` is the integration source of truth and includes the macOS reference lane
  through `13d3f35`.
- Rust Core/CLI owns catalog, benchmark, recommendation, policy, storage, history,
  apply-plan, and JSON/JSONL contracts. DNS sample payloads now include optional
  `failure_detail` with regression coverage.
- macOS Store-safe automated scope is complete: focused consumer IA, DNS-only Quick
  Check, game/service presets, single-window ownership, guided Apply/Retest, Power
  rollback isolation, release assets, and safe site generation all pass local gates.
- Linux passes its current fmt/test/clippy gate but remains an engineering shell. Its
  current native execute prototype is not releasable until fail-closed and exact
  rollback architecture are proven.
- Windows committed Store-safe baseline passes Core/static checks on macOS. Runtime
  readiness and consumer catch-up work is still isolated in the dirty worktree;
  WinUI/MSIX evidence requires Windows.
- Mobile has a standalone Expo native runtime around Rust Core and passes local
  JS/type/export checks, but consumer navigation catch-up is still isolated. Native
  iOS DNS Settings commit `345c41e` remains outside `main` pending Apple capability
  approval and signed physical-device evidence.

## Reference Contract

All lanes catch up to `docs/reference-lane-contract.md`. Parity means the same safe
decision journey and evidence, not identical platform features.

## Latest Validation

- macOS: `./script/ci_macos.sh` passed; 265 Swift tests, Rust workspace tests,
  Store-safe bundle validation, DNS-only smoke, and DNS+TCP smoke.
- macOS: `./script/preflight_macos_release.sh --include-power` passed, including
  Store-safe/Power bundle separation and App Store site safety tests.
- Linux branch baseline: fmt, tests, clippy, and `cargo test -p dnspilot-cli` passed.
- Windows dirty baseline: 44 Core tests passed; Windows-only XAML compiler was
  `NOT RUN` on macOS as expected.
- Mobile dirty baseline: 81 tests and typecheck passed; export exposed a missing
  `profiles` route and therefore was not accepted as a clean release gate.

## Manual Release Gates

- macOS: Apple signing/provisioning, hosted support/privacy URLs, signed screenshots,
  App Store Connect submission, five-user usability, and real Power Apply/Restore QA.
- Windows: Windows-host WinUI/MSIX/tray/accessibility QA, signing, Partner Center.
- Linux: real distro/package builds, GNOME/KDE and resolver-stack QA, signing/publish.
- Mobile: signed physical-device QA, Apple/Google accounts, Apple `dns-settings`
  approval for the optional entitled build, and store submission.

## Sources

- Architecture: `PROJECT.md`
- Roadmap: `TODO.md`
- Cross-platform contract: `docs/reference-lane-contract.md`
- Platform state: `docs/platform-summary.md`
- Manual provider steps: `docs/os-provider-trust.md`
