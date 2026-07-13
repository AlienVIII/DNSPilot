# Windows Risks

## UX Risks
- Users may expect one-click DNS swap in Store build.
- Current UI must keep copy/open-settings language clear during Windows visual QA.
- Vietnamese labels are wired through `.resw`, but longer localized strings still need real Windows layout review.
- Six peer navigation destinations expose internal workflow structure instead of
  the consumer Check DNS, Profiles, and History tasks.
- A fixed two-column surface and wide toolbar are not proven at narrow window
  widths, 200% text scaling, or high contrast.
- Benchmark progress has a cancelling display state but no operational Cancel
  path from the UI to the child process.

## Technical Risks
- Adapter enumeration and DNS settings require careful permissions.
- WinUI app build and NotifyIcon host are not validated on Windows in this macOS lane.
- CLI lookup now supports env override, bundled helper, and repo target fallback; packaging still must ensure the helper is bundled for Store builds.
- Static localization covers native shell labels/tooltips; dynamic Windows shell text now follows `CurrentUICulture` for English/Vietnamese.
- Runtime loading is fail-closed but does not yet expose per-surface readiness,
  incompatibility, or recovery states for missing helper, malformed output,
  unsupported schema, and database failure.
- Cancellation needs bounded Windows process-tree shutdown and atomic no-history
  behavior to avoid zombie helpers or partial persisted runs.

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

- On 2026-07-13, direct NuGet packages reported no available updates and the
  WinUI solution reported no known vulnerable direct or transitive packages.
- Newer transitive packages exist, but force-pinning them would bypass parent
  package compatibility. Upgrade through tested direct packages only.
