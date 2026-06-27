# Windows Session Notes

## Decisions
- Store-safe first; power edition later.
- WinUI 3 plus Windows App SDK is the native shell path.
- Shared, testable behavior lives in `DNSPilotWindows.Core` targeting `net8.0`; Windows-only UI lives in `DNSPilotWindows.App`.
- Main solution `DNSPilotWindows.slnx` stays macOS-buildable for core/tests.
- Windows UI solution `DNSPilotWindows.WinUI.slnx` includes the WinUI app and is intended for Windows build validation.
- Store apply uses `ms-settings:network-advancedsettings` with `ms-settings:network-status` fallback and never mutates DNS.
- Tray quick actions are modeled in core and hosted in the WinUI app through a NotifyIcon context menu.
- Native shell localization uses WinUI `.resw` resources in `Strings/en-US` and `Strings/vi-VN` with `x:Uid` hooks in `MainWindow.xaml`.
- Dynamic Windows shell text follows `CurrentUICulture` for progress, validation, failure reports, apply checklist, history rows, and tray labels.
- Store packaging readiness is documented through `Packaging/Package.Store.appxmanifest.template`; the live package manifest still needs Partner Center identity, version, and publisher metadata.
- Baseline Store logo/tile/splash PNG assets now exist; replace only if final branding changes.
- Packaged helper path is explicit: copy `dnspilot-cli.exe` beside `DNSPilotWindows.App.csproj`; the app project copies it to output when present.

## Context
- Automated tests validate command construction, view models, capability logic, profile/history commands, and diagnostics on macOS.
- WinUI project uses `requestedExecutionLevel level="asInvoker"` and no admin/service path.
- CLI runtime path is `DNSPILOT_CLI_PATH` when set, otherwise `dnspilot-cli.exe` next to the app.
- Windows shell now has decoders/runners for catalog, capabilities, apply-plan, profile list, and history list.
- Custom DNS profile add/update/delete and history delete/clear run through the same CLI process boundary as benchmarks.
- Benchmark success path now decodes result JSON and refreshes apply guidance via `apply-plan windows-store` using recommended profile/tested resolver.
- Benchmark success diagnostics now render a localized structured copyable recommendation report from result JSON, including health, reasons, resolver metrics, warning, and saved history ID, with raw stdout fallback for unknown CLI output.
- Diagnostics UI also renders the same parsed recommendation as summary text, resolver metric rows, and notes without waiting for raw report copy.
- Benchmark controls now share a core plan factory so command preview and idle process rows update as mode/A-AAAA/resolver-family/timeouts change.
- Toolbar Quick forces DNS+TCP quick plan, in-panel Run uses the current preview, and toolbar Validate DNS forces system-DNS validation while preserving selected A/AAAA/attempts/timeout.
- Completed benchmark progress now preserves final per-resolver success/degraded/failed details.
- Profile rows now expose edit/delete safety state; only `use_case=custom` profiles are treated as editable/deletable by the Windows shell.
- `Validate-WindowsLane.ps1` is the Windows-host validation entrypoint; `validate-windows-lane.sh` remains useful from macOS.

## Open Questions
- Store asset approval, signing, and MSIX submission metadata are not validated yet.
- Partner Center must approve/accept `runFullTrust` for the packaged desktop shell/helper/tray model.
- CLI-returned free-text notes/errors may still be English until CLI payloads expose stable message IDs or localized display fields.
- Confirm NotifyIcon behavior in packaged Store context during Windows QA.

## Handoff
- Keep lane changes in `apps/windows/**`.
- Record Core CLI needs in `windows-core-cli-request.md`.
- Current validation was automated only; no real Windows UI/device/store testing was performed on macOS.
- `history-delete` uses core CLI `--id`; Windows command builder was corrected from the earlier `--history-id` mismatch.
- Publish path and Store capability justification are in `apps/windows/windows-publish.md`.
