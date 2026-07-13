# Linux Progress

## BLUF

The original Linux engineering-shell scope is implemented and tested, but the lane is
not yet a production consumer app. A 2026-07-13 cross-lane audit found missing
core-backed catalog/storage/history, live progress/cancellation, structured result and
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
- The GUI resolves the packaged `dnspilot-cli` engine automatically, with an
  explicit `DNSPILOT_CLI_PATH` development override and `PATH` fallback.
- Process state covers idle/running/success/failed steps and resolver rows. The
  GUI runs benchmarks on a pollable background worker, remains responsive,
  blocks duplicate runs, and normalizes missing progress events into terminal
  success/failure states before rendering diagnostics.
- Custom plain DNS profile add/edit/delete/list and file-backed persistence are
  implemented.
- Store-safe guidance and native power package plans are separated.
- Settings is actionable: store builds copy family-filtered DNS values and show
  localized manual steps, while native power builds review the selected
  profile's resolver-stack/polkit/rollback plan before execution.
- English/Vietnamese strings cover primary native app labels/help, permission,
  guided settings, publish-check, and CLI surfaces.
- Packaging templates exist for Flatpak, Snap, deb, rpm, shared desktop/AppStream
  metadata, icon, core CLI/native helper install paths, and polkit policy.
- `scripts/build-packages.sh` builds locked Linux release binaries, rejects
  non-ELF payloads, validates metadata, stages one shared payload, and drives
  Flatpak Builder, Snapcraft, dpkg-deb, or rpmbuild without hard-requiring a
  resolver stack on benchmark-first deb/rpm installs.
- `publish-check` CLI emits package-specific or all-package automated gates,
  local package QA steps, manual credential/signing gates, and safety notes.
- Native helper contract binary supports contract and dry-run inspection without
  DNS mutation.
- Native helper request JSON models snapshot, authorization, would-write, flush,
  validation, rollback sequencing, and an execute mutation gate; contract/dry-run
  inspection is non-mutating.
- Native helper has a command-backed experimental execute prototype, but it is not a
  production privilege boundary: it uses `nmcli`/`resolvectl`, and its current snapshot
  is insufficient for exact restore. See `linux-completion-plan.md`.
- `apps/linux/README.md` is the Linux entrypoint for install, build, run,
  smoke, profile, native helper, and package QA steps.

## Validation

- `cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings`: pass.
- `cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release`: pass.
- `cargo test -p dnspilot-cli`: pass.
- `cargo build --release -p dnspilot-cli`: pass.
- `cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- readiness`: pass.
- `cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- publish-check --package deb --network-manager --polkit --system-resolver-probe`: pass.
- `bash -n apps/linux/scripts/build-packages.sh`: pass.
- `apps/linux/scripts/build-packages.sh --help`: pass.
- Real `flatpak-builder`, `snapcraft`, `dpkg-deb`, `rpmbuild`, `appstreamcli`,
  and `desktop-file-validate`: NOT RUN because they are unavailable on the
  current non-Linux host.

## Remaining Gates

- Complete Milestones 0-6 and 8-9 in `linux-completion-plan.md` for the Store-safe
  consumer app.
- Replace or disable the current native execute prototype before native package release.
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
