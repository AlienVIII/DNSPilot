# Windows Progress

## BLUF

The Windows lane meets the current store-safe core/view-model requirement:
benchmark, recommendation handoff, Settings guidance, profiles, history,
localization, single-project MSIX scaffolding, and tray models are implemented.
Real WinUI, MSIX, tray, and Store behavior still require a Windows host.

## Requirement Coverage

- `.NET` solution under `apps/windows/DNSPilotWindows` with
  `DNSPilotWindows.Core` view-model/domain layer.
- Benchmark commands cover DNS-only, DNS+TCP, system-DNS validation, A/AAAA,
  resolver address-family controls, numeric controls, live preview, and
  progress/failure diagnostics. Toolbar Quick forces DNS+TCP, in-panel Run
  uses the current preview, and Validate DNS forces system-DNS validation while
  preserving relevant controls.
- Persisted custom plain DNS profiles from `profile-list` are merged into the
  benchmark catalog, surfaced as selectable resolver profiles, and can be used
  in DNS-only or DNS+TCP runs.
- Benchmark success diagnostics now parse CLI benchmark-result JSON into a
  localized structured copyable recommendation report with health, reasons,
  resolver metrics, warning, and saved history ID.
- The WinUI diagnostics section also exposes the parsed recommendation summary,
  resolver metrics, and notes as native list/text surfaces, while preserving the
  copyable report.
- Store-safe apply guidance copies DNS servers/checklists and opens Windows
  Network Settings without admin DNS mutation.
- Profile and history add/update/delete/list/clear flows use CLI contract
  runners and management row models. Built-in profile update/delete is blocked
  by profile ID before any CLI mutation call.
- WinUI host, tray host, native localization resources, Store MSIX manifest
  template, top-level `Package.appxmanifest`, MSIX launch/publish profiles,
  Store manifest preparation script, baseline package assets, bundled CLI
  locator, and publish/QA runbooks are present.
- Privacy policy draft, Store listing copy, support text, and certification
  notes are present for Partner Center preparation.

## Validation

- `apps/windows/validate-windows-lane.sh`: pass for core tests, core solution
  build, store-safe static checks, localization/packaging checks, and expected
  macOS-only WinUI build-probe handling.

## Remaining Gates

- Run `apps/windows/Validate-WindowsLane.ps1 -Configuration Release` on Windows.
- Run `apps/windows/windows-qa.md` manual QA on Windows.
- Validate MSIX packaging, tray behavior, signing, and Partner Center
  `runFullTrust` justification.
- Ensure `dnspilot-cli.exe` is bundled or discoverable for live UI runs.

## Source Of Truth

- Critique and Store risk: `apps/windows/windows-self-review.md`.
- Publish steps: `apps/windows/windows-publish.md`.
- Privacy/listing source: `apps/windows/windows-privacy.md` and
  `apps/windows/windows-store-listing.md`.
