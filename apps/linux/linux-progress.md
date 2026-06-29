# Linux Progress

## BLUF

The Linux lane meets the scoped code-complete requirement for app/session logic,
CLI inspection, capability detection, store-safe guidance, packaging policy, and
native-power planning. It is not yet an end-user GUI or a verified distro
package release.

## Requirement Coverage

- Rust shell package under `apps/linux/DNSPilotLinux`.
- Capability model covers Flatpak, Snap, deb, and rpm.
- Benchmark planning covers DNS-only, DNS+TCP, and current/system resolver
  validation with mode gating.
- Process state covers idle/running/success/failed steps, resolver rows,
  diagnostics, and copyable debug reports.
- Custom plain DNS profile add/edit/delete/list and file-backed persistence are
  implemented.
- Store-safe guidance and native power package plans are separated.
- English/Vietnamese strings cover primary native app, permission, and CLI
  surfaces.
- Packaging templates exist for Flatpak, Snap, deb, rpm, shared desktop/AppStream
  metadata, icon, native helper install paths, and polkit policy.
- Native helper contract binary supports contract and dry-run inspection without
  DNS mutation.
- Native helper request JSON covers snapshot, authorization, would-write, flush,
  validation, rollback sequencing, and an execute mutation gate without DNS
  mutation.

## Validation

- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.

## Remaining Gates

- Native GUI stack decision: GTK/libadwaita or Qt.
- Real Flatpak/Snap/deb/rpm builds and distro/package QA.
- NetworkManager/systemd-resolved write backend and Linux package QA before
  enabling real DNS mutation.

## Source Of Truth

- Critique and remaining risk: `apps/linux/linux-self-review.md`.
- Publish steps: `apps/linux/linux-publish-checklist.md`.
