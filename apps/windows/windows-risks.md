# Windows Risks

## UX Risks
- Users may expect one-click DNS swap in Store build.
- Current UI must keep copy/open-settings language clear during Windows visual QA.
- Vietnamese labels are wired through `.resw`, but longer localized strings still need real Windows layout review.

## Technical Risks
- Adapter enumeration and DNS settings require careful permissions.
- WinUI app build and NotifyIcon host are not validated on Windows in this macOS lane.
- CLI lookup now supports env override, bundled helper, and repo target fallback; packaging still must ensure the helper is bundled for Store builds.
- Static localization covers native shell labels/tooltips; dynamic Windows shell text now follows `CurrentUICulture` for English/Vietnamese.

## Platform Risks
- Store packaging and admin-service split.
- Microsoft Store policy review must confirm tray behavior, packaged desktop bridge packaging, and `runFullTrust` restricted capability approval.

## Contract Risks
- Power apply contract must not leak into store build.
- Core apply-plan owns DNS safety decisions, while Windows app currently owns Settings URI handoff text.
- CLI-returned free-text notes/errors still need stable message IDs or localized display fields for complete cross-platform multilingual diagnostics.

## Release Risks
- Signing, MSIX packaging, and Store capability declarations.
- Windows App SDK package versions should be rechecked during release hardening.
- Final Store assets and Partner Center metadata are placeholders until real publisher identity and branding files are supplied.
