# DNSPilot State

Last updated: 2026-07-14.

## Current Truth

- `main` is the integration source of truth. It includes macOS through `7209b70`,
  Linux through `d9ad771`, and the committed Windows lane through `ae94c97`.
- Rust Core/CLI owns catalog, benchmark, recommendation, policy, storage, history,
  apply-plan, and JSON/JSONL contracts. DNS sample payloads now include optional
  `failure_detail` with regression coverage.
- macOS benchmark, single-window, guided Apply/Retest, Power isolation, release-asset,
  packaging, and localization gates pass. Presentation copy is centralized in native
  `en.lproj`/`vi.lproj` `Localizable.strings`; `System` resolves macOS preferences,
  tooltips render one active language, Store-safe Settings hide Power-only controls,
  and the Benchmark Options row has full keyboard/VoiceOver button semantics.
- Linux committed packaging, settings, planning, and lane docs are integrated. The
  app remains an engineering shell; its native execute prototype is present for
  development only and is not releasable until fail-closed privilege and exact
  rollback architecture are proven.
- Windows committed Store-safe baseline and selective-parity plan are integrated.
  Runtime Readiness implementation remains an uncommitted worktree overlay;
  WinUI/MSIX evidence still requires Windows.
- Mobile has a standalone Expo native runtime and a verified consumer shell through
  `3d1a34f` on `worktree/mobile`. The branch remains outside `main` because it contains
  native iOS DNS Settings commit `345c41e`, pending Apple capability approval and
  signed physical-device evidence. A newer tutorial change is still uncommitted.

## Reference Contract

All lanes catch up to `docs/reference-lane-contract.md`. Parity means the same safe
decision journey and evidence, not identical platform features.

## Latest Validation

- macOS: `./script/ci_macos.sh` passed; 270 Swift tests, Rust workspace tests,
  Store-safe bundle validation, localization guard, DNS-only smoke, and DNS+TCP smoke.
- macOS: `./script/preflight_macos_release.sh --include-power` passed, including
  Store-safe/Power bundle separation and App Store site safety tests.
- Linux pre-integration baseline: fmt, tests, clippy, and
  `cargo test -p dnspilot-cli` passed. Merged-result rerun is pending this pass.
- Windows committed baseline: 40 Core/static tests passed. The uncommitted Runtime
  Readiness overlay passes 44 Core tests; Windows-only XAML/MSIX remains `NOT RUN`.
- Mobile committed branch: `npm run verify` passed 86 tests, typecheck, route export,
  dependency compatibility, and production config checks. Physical-device proof is
  still `NOT RUN`.
- macOS localization/interaction visual matrix: implementation and static/runtime
  checks pass; clean EN/VI, narrow-window, Dark Mode, keyboard, and VoiceOver capture
  remains a manual release gate in
  `docs/research/2026-07-14-macos-localization-interaction-review.md`.

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
