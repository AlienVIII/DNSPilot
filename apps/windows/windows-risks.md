# Windows Risks

## UX Risks
- Users may expect one-click DNS swap in Store build.
- Current UI must keep copy/open-settings language clear during Windows visual QA.
- Vietnamese labels are wired through `.resw`, but longer localized strings still need real Windows layout review.
- A fixed two-column surface and wide toolbar are not proven at narrow window
  widths, 200% text scaling, or high contrast.

## Technical Risks
- Adapter enumeration and DNS settings require careful permissions.
- WinUI app build and NotifyIcon host are not validated on Windows in this macOS lane.
- CLI lookup now supports env override, bundled helper, and repo target fallback; packaging still must ensure the helper is bundled for Store builds.
- Static localization covers native shell labels/tooltips; dynamic Windows shell text now follows `CurrentUICulture` for English/Vietnamese.
- Runtime readiness, cancellation, result safety, preferences, and report
  redaction have automated core/static coverage; their real WinUI rendering and
  packaged behavior still need Windows-host proof.

## Platform Risks
- Store packaging and admin-service split.
- Microsoft Store policy review must confirm tray behavior, packaged desktop bridge packaging, and `runFullTrust` restricted capability approval.
- The Store workflow must remain complete without tray so NotifyIcon approval or
  packaged behavior cannot block the product.

## Contract Risks
- Power apply contract must not leak into store build.
- Core apply-plan owns DNS safety decisions, while Windows app currently owns Settings URI handoff text.
- CLI-returned free-text notes/errors still need stable message IDs or localized display fields for complete cross-platform multilingual diagnostics.
- Gaming behavior can use existing catalog `gaming` tags and descriptions;
  Windows must not duplicate suite IDs or reinterpret recommendation ranking.

## Release Risks
- Signing, MSIX packaging, and Store capability declarations.
- Windows App SDK package versions should be rechecked during release hardening.
- Baseline Store assets and listing/privacy drafts exist; final publisher identity, hosted URLs, signing, and Partner Center metadata still require real account access.
- Real Windows evidence must include installed helper discovery, clean install,
  upgrade, relaunch, Settings handoff, EN/VI wrapping, Narrator, keyboard, high
  contrast, firewall/VPN, and narrow/wide layouts.

## Dependency Audit

- On 2026-07-16, direct NuGet packages reported no available updates. The WinUI
  solution cannot run its Windows-only compiler on this macOS host, so runtime
  compatibility/vulnerability evidence must be refreshed on Windows.
- Newer transitive packages exist, but force-pinning them would bypass parent
  package compatibility. Upgrade through tested direct packages only.
