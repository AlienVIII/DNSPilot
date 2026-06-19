# Linux Session Notes

## Decisions
- Treat Linux packaging targets separately.
- Benchmark-first for sandboxed builds.
- Keep guided settings only for store/sandbox packages.
- Keep real DNS apply behind a native power package path with NetworkManager/systemd-resolved and polkit.
- Keep tray optional; main app works without tray.

## Context
- Linux shell package lives at `apps/linux/DNSPilotLinux`.
- Current implementation is view-model/CLI validation only; it does not mutate system DNS.
- Capability detection is mocked so automated tests can run without Linux distro/package access.

## Open Questions
- GTK4/libadwaita or Qt?
- Exact native UI stack remains open.
- Exact core CLI Linux payload shape remains open.

## Handoff
- Keep lane changes in `apps/linux/**`.
- Record Core CLI needs in `linux-core-cli-request.md`.
- Run `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`.
- CLI examples are documented in `linux-ux-spec.md`.
