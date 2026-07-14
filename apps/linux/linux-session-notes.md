# Linux Session Notes

## Decisions
- Treat Linux packaging targets separately.
- Benchmark-first for sandboxed builds.
- Keep guided settings only for store/sandbox packages.
- Keep real DNS apply behind a native power package path with NetworkManager/systemd-resolved and polkit.
- Keep tray optional; main app works without tray.
- Keep `dnspilot-cli` as the Linux runtime and replace hardcoded shell data with typed
  CLI JSON/JSONL contracts.
- Core CLI is now the sole runtime source for Linux catalog/profiles/suites/history and
  policy/apply/result contracts; legacy `profiles.json` is migration-only and renamed
  to `.migrated` after a successful import.
- Adopt the macOS consumer information architecture: Check DNS, Profiles, History;
  keep Settings/Help as commands and diagnostics contextual.
- Treat mobile's foreground job, persisted locale, accessibility, and core-storage
  patterns as product input; do not port Expo/FFI or iOS/Android capability code.
- Treat native Power as unavailable until a real system D-Bus/polkit/exact-rollback
  mechanism is proven. Default package payloads contain no helper or polkit action.

## Context
- Linux shell package lives at `apps/linux/DNSPilotLinux`.
- Current implementation includes view-models, Core SQLite storage, GUI process table,
  CLI profile management, CLI plan/run/guide surfaces, and runner boundary.
- Current implementation includes English/Vietnamese native app view-models, permission
  plans, a fail-closed native apply-plan contract, development-only helper inspection,
  packaging templates, desktop/AppStream metadata, and icon.
- The GUI and shipped packages never invoke mutation. Execute requests fail before any
  executor action; the helper and polkit action are excluded from package payloads.
- Capability detection can be mocked so automated tests can run without Linux distro/package access.
- Benchmark workers now supervise a piped Core CLI child directly: stdout/stderr reader
  threads avoid pipe deadlock, JSONL events update the process model live, cancel tears
  down the Unix process group and reaps it, and benchmark commands save history through
  the Core SQLite database.

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
- Run `cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --all-targets -- -D warnings`.
- CLI examples are documented in `linux-ux-spec.md`.
- Current critique/risk summary is documented in `linux-self-review.md`.
- Publish/manual QA steps are documented in `linux-publish-checklist.md`.
- Completion order and acceptance criteria are in `linux-completion-plan.md`.
- Run `dnspilot-linux-shell readiness` before handoff or package QA to verify scoped Linux goals remain covered.
