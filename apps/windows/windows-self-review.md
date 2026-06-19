# Windows Lane Self-Review

## BLUF
- Store-safe scope is coherent: benchmark, copy guidance, Settings handoff, profiles, history, tray actions.
- The biggest remaining risk is not missing core logic; it is unverified Windows App SDK/MSIX/tray runtime behavior.
- Power edition must stay separate. Do not add admin DNS mutation to this Store lane.

## Counterarguments

### "Users expect one-click apply"
- Valid. A DNS tool feels incomplete without direct apply.
- Store-safe answer: copy DNS servers, open Settings, retest with System DNS validation.
- Power edition answer: separate admin/service design later, not hidden in Store build.

### "WinUI exists but was not really tested"
- Valid. macOS cannot run Windows App SDK `XamlCompiler.exe` or tray runtime.
- Mitigation: core/view-model behavior is covered by automated tests; `windows-qa.md` and `validate-windows-lane.sh` document the exact Windows checks still needed.

### "CLI helper discovery can fail"
- Partly mitigated. Locator now checks `DNSPILOT_CLI_PATH`, bundled helper, then repo `target/release` and `target/debug`.
- Release packaging still must guarantee `dnspilot-cli.exe` is bundled beside the app or otherwise accessible.

### "Recommendation UI is thinner than macOS"
- Valid. Windows parses benchmark result JSON enough to refresh store-safe apply guidance, but it does not yet render full macOS-style recommendation cards.
- Current acceptable state: diagnostics, progress rows, resolver rows, copied reports, refreshed DNS servers, and history rows are implemented.

### "Tray behavior may be Store-sensitive"
- Valid. NotifyIcon is a desktop shell affordance and must be checked under packaged Store/MSIX context.
- If Store packaging rejects or degrades tray behavior, keep tray for unpackaged/power distribution and retain toolbar quick actions for Store.

### "No adapter-specific guidance"
- Valid. Windows network settings vary by adapter and Windows version.
- Current choice is stable, store-safe Settings handoff, not adapter mutation.
- Future work can add adapter detection as read-only context if it does not require broad capabilities or admin.

## Current Evidence
- `bash apps/windows/validate-windows-lane.sh` runs core tests, core build, store-safe static checks, and a WinUI build probe.
- Automated tests cover benchmark commands, system DNS validation, progress/failure diagnostics, apply guidance, profile/history management, CLI contract decoders, benchmark result parsing, and CLI executable lookup.
- Store-safe static scan currently finds no DNS mutation or admin-elevation implementation in `apps/windows/DNSPilotWindows`.

## Next Hard Gate
- Run `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx` on Windows.
- Run the manual QA checklist in `apps/windows/windows-qa.md`.
- Validate MSIX/Store packaging and signing before any release claim.
