# Windows Risks

## UX Risks
- Users may expect one-click DNS swap in Store build.
- Current UI must keep copy/open-settings language clear during Windows visual QA.

## Technical Risks
- Adapter enumeration and DNS settings require careful permissions.
- WinUI app build and NotifyIcon host are not validated on Windows in this macOS lane.
- `DNSPILOT_CLI_PATH` or bundled helper placement must be confirmed before live UI benchmark runs.

## Platform Risks
- Store packaging and admin-service split.
- Microsoft Store policy review must confirm tray behavior and Win32 desktop bridge packaging.

## Contract Risks
- Power apply contract must not leak into store build.
- Core apply-plan owns DNS safety decisions, while Windows app currently owns Settings URI handoff text.

## Release Risks
- Signing, MSIX packaging, and Store capability declarations.
- Windows App SDK package versions should be rechecked during release hardening.
