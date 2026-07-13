# Linux Risks

Last reviewed: 2026-07-13.

## Critical Risks

- Current Power labels claim D-Bus while the executor shells out to
  `nmcli`/`resolvectl`.
- `pkcheck` checks authorization but does not elevate the caller; a privileged
  mechanism must authorize the untrusted D-Bus caller and perform the narrow operation.
- Current rollback does not retain exact DNS values or configuration revision. Do not
  release or enable native mutation until exact snapshot/identity/restore tests and
  real-host evidence exist.

## UX Risks
- Tray assumptions can fail on GNOME/Wayland.
- Guided settings copy/open flows can drift by distro desktop environment.

## Technical Risks
- Multiple resolver stacks and package sandboxes.
- NetworkManager and systemd-resolved ownership can vary per interface.
- Store package permissions can differ between build manifest and user install state.
- Buffered child output prevents live progress and cancellation and can leave a long run
  looking stalled.
- Linux-only profile JSON and hardcoded suites can drift from shared SQLite/catalog
  contracts.
- Split DNS, VPN routes, multiple active default routes, and concurrent connection
  changes can make an apparently valid Power snapshot stale.

## Platform Risks
- Flatpak/Snap permissions may block apply behavior.
- Snap `network-manager` is privileged and not auto-connect.

## Contract Risks
- One Linux capability flag is insufficient.
- Current/system resolver validation must remain capability-gated.
- deb/rpm without supported resolver stack and polkit must not show guided settings as a fake apply path.
- Every CLI JSON/JSONL decoder must reject unsupported schema versions with a copyable
  compatibility error.

## Release Risks
- Need separate release checklist for Flatpak, Snap, deb, and rpm.
- Later QA must verify real packages because current automated tests use mocked capabilities.
- Build recipes and payload policy are automated, but generated artifacts must
  still pass package-tool and installed-runtime validation on Linux build hosts.
- Store publishing still needs credentials, screenshots, signing, release notes, and final metadata review.
- The current Flatpak manifest uses local prebuilt ELF files and is a QA recipe, not a
  Flathub submission manifest. Flathub requires declared source builds.
- Package version is duplicated and can drift across Cargo, Snap, deb, rpm, AppStream,
  artifact names, and release notes.
- No Linux CI artifact currently proves package construction or installed smoke.

## Official References

- NetworkManager Device D-Bus `GetAppliedConnection`/`Reapply` contract:
  <https://www.networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.Device.html>
- NetworkManager IPv4 DNS and `ignore-auto-dns` properties:
  <https://www.networkmanager.dev/docs/api/latest/settings-ipv4.html>
- systemd-resolved `SetLinkDNS`/`RevertLink` D-Bus contract:
  <https://www.freedesktop.org/software/systemd/man/247/org.freedesktop.resolve1.html>
- polkit privileged mechanism/subject architecture:
  <https://polkit.pages.freedesktop.org/polkit/polkit.8.html>
- `pkcheck` is an authorization check wrapper:
  <https://polkit.pages.freedesktop.org/polkit/pkcheck.1.html>
- Flatpak sandbox permissions:
  <https://docs.flatpak.org/en/latest/sandbox-permissions.html>
- Flathub source-build requirements:
  <https://docs.flathub.org/docs/for-app-authors/requirements>
- Snap `network-manager` is privileged and not auto-connected:
  <https://snapcraft.io/docs/reference/interfaces/network-manager-interface/>
