# Linux Risks

Last reviewed: 2026-07-19.

## Major

- Native Power execute is fail-closed and excluded from default packages. Do not enable
  it until a caller-bound D-Bus/polkit mechanism, exact snapshot/current-state guard/
  restore, and real Linux evidence exist. `pkcheck` alone is not that mechanism.
- Real GNOME/KDE layout, keyboard/screen-reader behavior, package confinement, and
  resolver-stack interaction are not proven by current macOS-hosted tests.
- The Flatpak manifest consumes local prebuilt ELF for QA. Flathub requires a declared,
  reproducible source build.

## Product And UX

- Tray cannot be required on GNOME/Wayland; the main window owns the full workflow.
- Settings guidance varies by package, desktop, resolver stack, VPN, and split DNS. It
  must fail closed instead of presenting a fake Apply path.
- Long EN/VI copy, narrow/wide layout, focus order, screen reader, and non-color status
  need real desktop proof.

## Technical And Contract

- Active interfaces/routes can change between snapshot and restore; future Power needs
  identity, configuration revision, and current-state validation.
- Every Core JSON/JSONL decoder rejects unsupported schema versions with a copyable
  compatibility error. Platform capability detail remains Linux-owned.
- Package version is duplicated across Cargo, package metadata, assets, and release notes;
  CI must reject drift before publishing.

## Release

- Real Flatpak/Snap/deb/rpm build/install/smoke, AppStream/desktop validation, source tag,
  signing, publisher accounts, hosted URLs, screenshots, and store review remain open.

## Official References

- NetworkManager D-Bus: <https://www.networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.Device.html>
- polkit architecture: <https://polkit.pages.freedesktop.org/polkit/polkit.8.html>
- Flathub requirements: <https://docs.flathub.org/docs/for-app-authors/requirements>
- Snap NetworkManager interface: <https://snapcraft.io/docs/reference/interfaces/network-manager-interface/>
