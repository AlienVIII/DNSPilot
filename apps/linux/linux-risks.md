# Linux Risks

## UX Risks
- Tray assumptions can fail on GNOME/Wayland.
- Guided settings copy/open flows can drift by distro desktop environment.

## Technical Risks
- Multiple resolver stacks and package sandboxes.
- NetworkManager and systemd-resolved ownership can vary per interface.
- Store package permissions can differ between build manifest and user install state.

## Platform Risks
- Flatpak/Snap permissions may block apply behavior.
- Snap `network-manager` is privileged and not auto-connect.

## Contract Risks
- One Linux capability flag is insufficient.
- Current/system resolver validation must remain capability-gated.
- deb/rpm without supported resolver stack and polkit must not show guided settings as a fake apply path.

## Release Risks
- Need separate release checklist for Flatpak, Snap, deb, and rpm.
- Later QA must verify real packages because current automated tests use mocked capabilities.
