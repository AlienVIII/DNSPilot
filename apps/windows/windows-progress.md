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
- Added CLI payload decoders and runners for catalog, capabilities, apply-plan, profile-list, and history-list.
- Added custom DNS profile add/update/delete runners and history delete/clear runners.
- WinUI host now attempts to hydrate catalog, capabilities, apply-plan, profiles, and history from `dnspilot-cli` at launch.
- WinUI host now renders saved profile/history rows and can add/update/delete custom profiles plus refresh/clear history through the CLI boundary.
- Added benchmark result decoder and apply-plan request factory so successful benchmark JSON can refresh store-safe apply guidance from the measured recommendation.
- Added profile/history management row models so UI can distinguish custom editable profiles from built-in protected profiles and delete selected history rows.
- Added CLI executable locator: `DNSPILOT_CLI_PATH`, bundled `dnspilot-cli.exe`, then development `target/release` or `target/debug`.
- Added lane validation script for core tests, core build, store-safe static checks, and Windows App SDK build probe.
- Added self-review/counterargument summary for Windows lane release risk and scope discipline.
- Added native WinUI localization hooks with `x:Uid` and `Strings/en-US` plus `Strings/vi-VN` `.resw` resources.
- Added Store MSIX manifest template with localized `ms-resource` display strings and explicit `internetClient` plus `runFullTrust` capability declarations.
- Added conditional app project packaging rule to copy bundled `dnspilot-cli.exe` when present beside the WinUI project.
- Added Windows PowerShell validation script for real Windows build/test runs.
- Added Windows publish runbook covering helper bundling, validation, manual QA, MSIX assets, Partner Center capability justification, and Store-safe copy/settings positioning.

## Current Work
- Windows lane is code-complete for store-safe benchmark/recommend/apply-guidance shell behavior that can be validated on macOS.
- Remaining work is real Windows validation, Store signing, Partner Center metadata, package assets, and manual device QA.

## Blockers
- Real Windows UI, tray, MSIX, Store, and signing validation still require a Windows machine and store/signing access.
- Dynamic diagnostic/status strings from the shared Windows core layer remain English until a broader localization contract is added without touching core from this lane.

## Next Actions
- Follow `apps/windows/windows-publish.md` on a Windows device.
- Run Windows QA from `apps/windows/windows-qa.md`.
- On Windows, run `apps/windows/Validate-WindowsLane.ps1 -Configuration Release`.
- Bundle or point `DNSPILOT_CLI_PATH` at `dnspilot-cli.exe` before live UI benchmark runs.
- On Windows, verify hydrated catalog/profile/history/apply-plan state after launch.
- On Windows, verify benchmark success refreshes DNS servers in Apply guidance from the recommended profile/tested resolver.
- On Windows, verify selecting a custom profile populates the form and built-in profile update/delete is blocked.
- On Windows, verify app can find `dnspilot-cli.exe` through env override, bundled helper, or repo `target` fallback.
- In Partner Center, justify `runFullTrust` as packaged desktop shell/helper/tray support with no UAC and no DNS mutation.
