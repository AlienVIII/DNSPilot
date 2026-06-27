# Windows Progress

## BLUF

The Windows lane meets the current store-safe core/view-model requirement:
benchmark, recommendation handoff, Settings guidance, profiles, history,
localization, package scaffolding, and tray models are implemented. Real WinUI,
MSIX, tray, and Store behavior still require a Windows host.

## Requirement Coverage

- `.NET` solution under `apps/windows/DNSPilotWindows` with
  `DNSPilotWindows.Core` view-model/domain layer.
- Benchmark commands cover DNS-only, DNS+TCP, system-DNS validation, A/AAAA,
  resolver address-family controls, numeric controls, live preview, and
  progress/failure diagnostics. Toolbar Quick forces DNS+TCP, in-panel Run
  uses the current preview, and Validate DNS forces system-DNS validation while
  preserving relevant controls.
- Benchmark success diagnostics now parse CLI benchmark-result JSON into a
  localized structured copyable recommendation report with health, reasons,
  resolver metrics, warning, and saved history ID.
- The WinUI diagnostics section also exposes the parsed recommendation summary,
  resolver metrics, and notes as native list/text surfaces, while preserving the
  copyable report.
- Store-safe apply guidance copies DNS servers/checklists and opens Windows
  Network Settings without admin DNS mutation.
- Profile and history add/update/delete/list/clear flows use CLI contract
  runners and management row models.
- WinUI host, tray host, native localization resources, Store MSIX manifest
  template, bundled CLI locator, and publish/QA runbooks are present.

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
