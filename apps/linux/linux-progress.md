# Linux Progress

Last reviewed: 2026-07-19.

## BLUF

Store-safe Linux milestones 0-5 are substantially implemented. The lane has typed shared
Core storage/results, streamed/cancellable jobs, `Check DNS` / `Profiles` / `History`,
EN/VI, safe settings guidance, and fail-closed Power. It is not release-ready until
accessibility/desktop-fit and source-built package/real-Linux evidence pass.

## Implemented

- eframe/egui main window works without tray and provides optional first-run tutorial
  plus top-right Help.
- Shared Core CLI owns catalog, profiles, suites, history, apply policy/plan, result and
  progress payloads; legacy Linux JSON migrates once to Core SQLite.
- Pollable worker streams JSONL, blocks duplicate runs, supports bounded process-group
  cancellation, reaps children, and normalizes malformed/missing terminal events.
- Quick Check is DNS-only; gaming targets use DNS+TCP caveats; history and custom profile/
  suite mutation use Core contracts with destructive confirmation.
- Store-safe packages copy DNS guidance and never execute DNS mutation. Power helper
  execute is fail-closed and absent from default package payloads.
- Package templates, metadata, release scripts, and publish-check preparation exist. The
  Flatpak manifest is local QA only until converted to a declared source build.

## Validation

- `cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings`: pass.
- Core CLI compatibility and package/static checks: pass.
- Real packages, GNOME/KDE, resolver stacks, installed smoke, metadata tools, and
  assistive technology: `NOT RUN` on this host.

## Remaining Gates

- Milestone 6: EN/VI wrapping, desktop fit, keyboard, screen reader, and non-color status
  on real GNOME/KDE.
- Milestones 8-9: reproducible source builds, Linux CI artifacts, installed smoke,
  immutable source tag, hosted URLs, signing/publisher, and store evidence.
- Milestone 7 Power remains separately fail-closed until D-Bus/polkit and exact rollback
  pass real-host security review.

## Source Of Truth

- Plan: `apps/linux/linux-completion-plan.md`
- Risks: `apps/linux/linux-risks.md`
- Publish: `apps/linux/linux-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
