# Windows Session Notes

## Decisions
- Store-safe first; power edition later.
- WinUI 3 plus Windows App SDK is the native shell path.
- Shared, testable behavior lives in `DNSPilotWindows.Core` targeting `net8.0`; Windows-only UI lives in `DNSPilotWindows.App`.
- Main solution `DNSPilotWindows.slnx` stays macOS-buildable for core/tests.
- Windows UI solution `DNSPilotWindows.WinUI.slnx` includes the WinUI app and is intended for Windows build validation.
- Store apply uses `ms-settings:network-advancedsettings` with `ms-settings:network-status` fallback and never mutates DNS.
- Tray quick actions are modeled in core and hosted in the WinUI app through a NotifyIcon context menu.

## Context
- Automated tests validate command construction, view models, capability logic, profile/history commands, and diagnostics on macOS.
- WinUI project uses `requestedExecutionLevel level="asInvoker"` and no admin/service path.
- CLI runtime path is `DNSPILOT_CLI_PATH` when set, otherwise `dnspilot-cli.exe` next to the app.
- Windows shell now has decoders/runners for catalog, capabilities, apply-plan, profile list, and history list.
- Custom DNS profile add/update/delete and history delete/clear run through the same CLI process boundary as benchmarks.
- Benchmark success path now decodes result JSON and refreshes apply guidance via `apply-plan windows-store` using recommended profile/tested resolver.

## Open Questions
- Store packaging assets, signing, and MSIX submission metadata are not validated yet.
- Confirm NotifyIcon behavior in packaged Store context during Windows QA.

## Handoff
- Keep lane changes in `apps/windows/**`.
- Record Core CLI needs in `windows-core-cli-request.md`.
- Current validation was automated only; no real Windows UI/device/store testing was performed on macOS.
- `history-delete` uses core CLI `--id`; Windows command builder was corrected from the earlier `--history-id` mismatch.
