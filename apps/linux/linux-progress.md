# Linux Progress

## BLUF

The Linux lane meets the scoped code-complete requirement for app/session logic,
native GUI launch, CLI inspection, capability detection, store-safe guidance,
packaging policy, and native-power planning. It is not yet a verified distro
package release.

## Requirement Coverage

- Rust shell package under `apps/linux/DNSPilotLinux`.
- `dnspilot-linux-gui` eframe/egui 0.35 main window is the desktop launcher and
  works without tray as the primary GNOME/Wayland-safe surface.
- GUI now has a first-run setup tutorial persisted in the XDG app data path,
  plus a top-right `?` Help button to reopen it.
- Capability model covers Flatpak, Snap, deb, and rpm.
- Benchmark planning covers DNS-only, DNS+TCP, and current/system resolver
  validation with mode gating.
- Process state covers idle/running/success/failed steps, resolver rows,
  diagnostics, copyable debug reports, and the GUI benchmark process table.
- Custom plain DNS profile add/edit/delete/list and file-backed persistence are
  implemented.
- Store-safe guidance and native power package plans are separated.
- English/Vietnamese strings cover primary native app labels/help, permission,
  guided settings, publish-check, and CLI surfaces.
- Packaging templates exist for Flatpak, Snap, deb, rpm, shared desktop/AppStream
  metadata, icon, native helper install paths, and polkit policy.
- `publish-check` CLI emits package-specific automated gates, local package QA
  steps, manual credential/signing gates, and safety notes.
- Native helper contract binary supports contract and dry-run inspection without
  DNS mutation.
- Native helper request JSON covers snapshot, authorization, would-write, flush,
  validation, rollback sequencing, and an execute mutation gate without DNS
  mutation.
- Native helper command backend supports explicit deb/rpm execution through
  NetworkManager/systemd-resolved host commands after polkit and
  `--allow-system-dns-mutation`.
- `apps/linux/README.md` is the Linux entrypoint for install, build, run,
  smoke, profile, native helper, and package QA steps.

## Validation

- `cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings`: pass.
- `cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release`: pass.
- `cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- readiness`: pass.
- `cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- publish-check --package deb --network-manager --polkit --system-resolver-probe`: pass.

## Remaining Gates

- Real Flatpak/Snap/deb/rpm builds and distro/package QA.
- Linux package QA before publishing or enabling real DNS mutation by default in
  deb/rpm.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Critique and remaining risk: `apps/linux/linux-self-review.md`.
- Publish steps: `apps/linux/linux-publish-checklist.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
