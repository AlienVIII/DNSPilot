# Linux Session Notes

## Decisions
- Treat Linux packaging targets separately.
- Benchmark-first for sandboxed builds.
- Keep guided settings only for store/sandbox packages.
- Keep real DNS apply behind a native power package path with NetworkManager/systemd-resolved and polkit.
- Keep tray optional; main app works without tray.

## Context
- Linux shell package lives at `apps/linux/DNSPilotLinux`.
- Current implementation includes view-models, storage, GUI process table, CLI profile management, CLI plan/run/guide surfaces, and runner boundary.
- Current implementation also includes English/Vietnamese native app view-models, permission plans, native apply-plan contract, native helper contract binary, packaging templates, desktop/AppStream metadata, icon, and polkit policy template.
- It does not mutate system DNS by itself; real DNS apply remains native power package work behind NetworkManager/systemd-resolved plus polkit.
- Capability detection can be mocked so automated tests can run without Linux distro/package access.

## Open Questions
- `eframe/egui` is the current Linux app stack for this lane; GTK4/libadwaita
  or Qt can be revisited only if later distro QA requires deeper desktop
  integration.
- Real native resolver write execution exists behind the helper execute gate and still needs Linux package QA before release/default enablement.
- Exact store credentials, signing keys, screenshots, and final package build hosts remain external.

## Handoff
- Keep lane changes in `apps/linux/**`.
- Record Core CLI needs in `linux-core-cli-request.md`.
- Run `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`.
- CLI examples are documented in `linux-ux-spec.md`.
- Current critique/risk summary is documented in `linux-self-review.md`.
- Publish/manual QA steps are documented in `linux-publish-checklist.md`.
- Run `dnspilot-linux-shell readiness` before handoff or package QA to verify scoped Linux goals remain covered.
