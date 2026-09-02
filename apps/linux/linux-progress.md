# Linux Progress

Last reviewed: 2026-09-02.

## BLUF

Store-safe Linux milestones 0-5 are substantially implemented. The lane has typed shared
Core storage/results, streamed/cancellable jobs, `Check DNS` / `Profiles` / `History`,
EN/VI, safe settings guidance, and fail-closed Power. It is not release-ready until
accessibility/desktop-fit and source-built package/real-Linux evidence pass.
The three-area navigation is the implemented baseline. D13's four-area Health Check/DNS
Benchmark contract and D14 background/notification adapter remain queued.

## Implemented

- eframe/egui main window works without tray and provides optional first-run tutorial
  plus top-right Help.
- Shared Core CLI owns catalog, profiles, suites, history, apply policy/plan, result and
  progress payloads; legacy Linux JSON migrates once to Core SQLite.
- Pollable worker streams JSONL, blocks duplicate runs, supports bounded process-group
  cancellation, reaps children, and normalizes malformed/missing terminal events.
- Quick Check is DNS-only; gaming targets use DNS+TCP caveats; history and custom profile/
  suite mutation use Core contracts with destructive confirmation. Built-in catalog items are
  read-only in the GUI; history rerun restores saved scope, domains, and resolver inputs
  without silently substituting missing profiles.
- Default debug reports redact private custom domains and local user paths. Full details are
  an explicit, disabled-by-default GUI disclosure.
- Main content is scrollable at the supported minimum window size and expanded GUI strings
  are localized for English/Vietnamese flow labels.
- Store-safe packages copy DNS guidance and never execute DNS mutation. Power helper
  execute is fail-closed and absent from default package payloads.
- Package templates, metadata, release scripts, and publish-check preparation exist. The
  Flatpak manifest is labeled local QA only until converted to a declared source build.
  Metadata version drift is checked against the Linux Cargo package version; CI and installed
  non-mutating package-smoke scripts are prepared.

## Validation

- Targeted unit, GUI-model, package-policy, and metadata checks: pass on 2026-09-02.
- Full Linux CI gate and Linux-host package tools: pending in this worktree.
- Core CLI compatibility and package/static checks: pass.
- Real packages, GNOME/KDE, resolver stacks, installed smoke, metadata tools, and
  assistive technology: `NOT RUN` on this host.

## Remaining Gates

- Milestone 6: real GNOME/KDE keyboard, screen reader, IME, clipboard, and visual layout
  evidence. Static localization, text status, and minimum-size scroll behavior are covered.
- Milestones 8-9: reproducible source builds, Linux CI artifacts, installed smoke,
  immutable source tag, hosted URLs, signing/publisher, and store evidence.
- Milestone 7 Power remains separately fail-closed until D-Bus/polkit and exact rollback
  pass real-host security review.

## Source Of Truth

- Plan: `apps/linux/linux-completion-plan.md`
- Risks: `apps/linux/linux-risks.md`
- Publish: `apps/linux/linux-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
