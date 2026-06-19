# Windows Progress

## Completed
- Initialized `apps/windows/DNSPilotWindows` with a Windows-lane .NET solution.
- Added `DNSPilotWindows.Core` view-model/domain layer for store-safe Windows shell behavior.
- Added tests for DNS-only, DNS + TCP, and System DNS validation command construction.
- Added progress state models for idle/running/success/failed steps and per-resolver rows.
- Added failure diagnostics with failed step, reason, elapsed time, debug log, and copyable report.
- Added store-safe apply guidance: copy DNS servers, copy checklist, open Windows Network Settings.
- Added custom plain DNS profile add/update/delete command builders with IPv4/IPv6 validation.
- Added benchmark history save/list/delete/clear command builders.
- Added tray quick action models for quick benchmark, validate current/system DNS, and open settings.
- Added WinUI 3 app host with toolbar actions, process/status panes, profile form preview, diagnostics copy, and NotifyIcon tray host.

## Current Work
- Windows lane code-complete for the store-safe benchmark/recommend/apply-guidance shell surface.

## Blockers
- Real Windows UI, tray, MSIX, Store, and signing validation still require a Windows machine and store/signing access.

## Next Actions
- Run Windows QA from `apps/windows/windows-qa.md`.
- On Windows, build `apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx`.
- Bundle or point `DNSPILOT_CLI_PATH` at `dnspilot-cli.exe` before live UI benchmark runs.
