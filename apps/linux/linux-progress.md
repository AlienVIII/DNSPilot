# Linux Progress

## BLUF

The original Linux engineering-shell scope is implemented and tested, but the lane is
not yet a production consumer app. A 2026-07-13 cross-lane audit found missing
live progress/cancellation, structured result and
apply/retest UX, complete localization/accessibility, submission-ready Flatpak sources,
and a releasable privileged mechanism.

The next approved working direction is `linux-completion-plan.md`. Store-safe Linux is
the active completion target. Native Power execute is experimental and must remain
fail-closed until its D-Bus/polkit/exact-rollback design and real Linux QA are complete.

## Requirement Coverage

- Rust shell package under `apps/linux/DNSPilotLinux`.
- `dnspilot-linux-gui` eframe/egui 0.35 main window is the desktop launcher and
  works without tray as the primary GNOME/Wayland-safe surface.
- GUI now has a first-run setup tutorial persisted in the XDG app data path,
  plus a top-right `?` Help button to reopen it.
- Capability model covers Flatpak, Snap, deb, and rpm.
- Benchmark planning covers DNS-only, DNS+TCP, and current/system resolver
  validation with mode gating.
- The GUI and shell resolve the packaged `dnspilot-cli` engine automatically, with an
  explicit `DNSPILOT_CLI_PATH` development override, packaged-sibling and `PATH`
  resolution, and a source-checkout debug fallback that is never a package dependency.
- Catalog, profiles, suites, history, apply policy/plan, and benchmark-result payloads
  use schema-checked typed Core CLI contracts. The GUI and shell use one Core-owned
  SQLite database; legacy Linux JSON profiles migrate once to a `.migrated` backup.
- Process state covers idle/running/success/failed steps and resolver rows. The
  GUI runs benchmarks on a pollable background worker, remains responsive,
  blocks duplicate runs, streams JSONL resolver updates while the Core CLI runs,
  and normalizes missing progress events into terminal success/failure states before
  rendering diagnostics. Cancel sends TERM to the Core CLI process group, escalates to
  KILL after 500 ms, and always reaps the child.
- Primary GUI navigation is now `Check DNS`, `Profiles`, and `History`; Settings and
  Help are top commands. Quick Check starts in DNS-only mode. System/English/Vietnamese
  language choice persists locally, and setup completes only after Skip or Done.
- Custom plain DNS profile add/edit/delete/list now use Core CLI SQLite persistence.
- Store-safe guidance and the unavailable native Power boundary are separated.
- Settings is actionable: store builds copy family-filtered DNS values and show
  localized manual steps; deb/rpm show diagnostics because Power is unavailable.
- English/Vietnamese strings cover primary native app labels/help, permission,
  guided settings, publish-check, and CLI surfaces.
- Packaging templates exist for Flatpak, Snap, deb, rpm, shared desktop/AppStream
  metadata, icon, and the core CLI. Default payloads exclude native helper/polkit files.
- `scripts/build-packages.sh` builds locked Linux release binaries, rejects
  non-ELF payloads, validates metadata, stages one shared payload, and drives
  Flatpak Builder, Snapcraft, dpkg-deb, or rpmbuild without hard-requiring a
  resolver stack on benchmark-first deb/rpm installs.
- `publish-check` CLI emits package-specific or all-package automated gates,
  local package QA steps, manual credential/signing gates, and safety notes.
- Native helper contract binary supports contract and dry-run inspection without
  DNS mutation.
- Native helper request JSON remains a development contract/dry-run probe. Every execute
  request is rejected before snapshot, authorization, or a system command can run.
- The command-backed execute prototype was removed from the default build and package
  payload. See `linux-completion-plan.md` for the separately gated Power architecture.
- `apps/linux/README.md` is the Linux entrypoint for install, build, run,
  smoke, profile, native helper, and package QA steps.

## Validation

- Milestone 0 targeted fail-closed helper, capability, package-policy, and permission
  tests: pass.
- Milestone 1 typed contract, XDG migration, Core-backed GUI/shell, and dynamic suite
  tests: pass.
- Milestone 2 live JSONL progress, cancellation/reap, malformed-event diagnostics, and
  Core SQLite history arguments: pass.
- Milestone 3 consumer navigation, DNS-only Quick Check, History surface, and persisted
  System/English/Vietnamese preferences: pass. GUI module extraction and full localized
  view coverage continue with the remaining consumer workflow work.
- `cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings`: pass.
- `cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release`: pass.
- `cargo test -p dnspilot-cli`: pass.
- `bash -n apps/linux/scripts/build-packages.sh`: pass.
- Real `flatpak-builder`, `snapcraft`, `dpkg-deb`, `rpmbuild`, `appstreamcli`,
  and `desktop-file-validate`: NOT RUN because they are unavailable on the
  current non-Linux host.

## Remaining Gates

- Complete Milestones 3-6 and 8-9 in `linux-completion-plan.md` for the Store-safe
  consumer app.
- Native Power remains unavailable pending the separately gated D-Bus/polkit mechanism.
- Real Flatpak/Snap/deb/rpm builds and distro/package QA.
- `dnspilot.io` currently does not resolve; homepage/support/privacy hosting and
  public immutable source tag setup are required before store submission.
- Linux package QA before publishing or enabling real DNS mutation by default in
  deb/rpm.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Completion design/order: `apps/linux/linux-completion-plan.md`.
- Critique and remaining risk: `apps/linux/linux-self-review.md`.
- Publish steps: `apps/linux/linux-publish-checklist.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
