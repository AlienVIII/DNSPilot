# Linux Session Notes

## Decisions
- Treat Linux packaging targets separately.
- Benchmark-first for sandboxed builds.
- Keep guided settings only for store/sandbox packages.
- Keep real DNS apply behind a native power package path with NetworkManager/systemd-resolved and polkit.
- Keep tray optional; main app works without tray.
- Keep `dnspilot-cli` as the Linux runtime and replace hardcoded shell data with typed
  CLI JSON/JSONL contracts.
- Adopt the macOS consumer information architecture: Check DNS, Profiles, History;
  keep Settings/Help as commands and diagnostics contextual.
- Treat mobile's foreground job, persisted locale, accessibility, and core-storage
  patterns as product input; do not port Expo/FFI or iOS/Android capability code.
- Treat the current native execute path as experimental and fail-closed until a real
  system D-Bus/polkit/exact-rollback mechanism is proven.

## Context
- Linux shell package lives at `apps/linux/DNSPilotLinux`.
- Current implementation includes view-models, storage, GUI process table, CLI profile management, CLI plan/run/guide surfaces, and runner boundary.
- Current implementation also includes English/Vietnamese native app view-models, permission plans, native apply-plan contract, native helper contract binary, packaging templates, desktop/AppStream metadata, icon, and polkit policy template.
- The GUI does not invoke mutation. A manually gated helper execute prototype exists,
  but it is not release-safe because it is command-backed and lacks exact rollback.
- Capability detection can be mocked so automated tests can run without Linux distro/package access.

## Open Questions
- `eframe/egui` is the current Linux app stack for this lane; GTK4/libadwaita
  or Qt can be revisited only if later distro QA requires deeper desktop
  integration.
- eframe/egui remains conditional on Linux-host keyboard, screen-reader, IME, clipboard,
  and GNOME/Wayland evidence. Revisit the toolkit only on a proved blocker.
- Native Power implementation is additionally gated by `PROJECT.md` D2 commercial
  evidence; design/mock work does not authorize release enablement.
- Exact store credentials, signing keys, screenshots, and final package build hosts remain external.

## Handoff
- Keep lane changes in `apps/linux/**`.
- Record Core CLI needs in `linux-core-cli-request.md`.
- Run `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`.
- CLI examples are documented in `linux-ux-spec.md`.
- Current critique/risk summary is documented in `linux-self-review.md`.
- Publish/manual QA steps are documented in `linux-publish-checklist.md`.
- Completion order and acceptance criteria are in `linux-completion-plan.md`.
- Run `dnspilot-linux-shell readiness` before handoff or package QA to verify scoped Linux goals remain covered.
