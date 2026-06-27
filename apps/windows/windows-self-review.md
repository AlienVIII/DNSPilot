# Windows Lane Self-Review

## BLUF
- Store-safe scope is coherent: benchmark, copy guidance, Settings handoff, profiles, history, tray actions.
- The biggest remaining risk is not missing core logic; it is unverified Windows App SDK/MSIX/tray runtime behavior.
- Native shell localization and Store packaging scaffolding are now present, but real Windows layout/package validation remains mandatory.
- Power edition must stay separate. Do not add admin DNS mutation to this Store lane.

## Counterarguments

### "Users expect one-click apply"
- Valid. A DNS tool feels incomplete without direct apply.
- Store-safe answer: copy DNS servers, open Settings, retest with System DNS validation.
- Power edition answer: separate admin/service design later, not hidden in Store build.

### "WinUI exists but was not really tested"
- Valid. macOS cannot run Windows App SDK `XamlCompiler.exe` or tray runtime.
- Mitigation: core/view-model behavior is covered by automated tests; `windows-qa.md`, `Validate-WindowsLane.ps1`, and `validate-windows-lane.sh` document the exact Windows checks still needed.

### "Multilingual support may be superficial"
- Partly mitigated. Native shell labels, headers, buttons, and main tooltips are localized through `.resw` for English and Vietnamese.
- Dynamic Windows shell text now follows `CurrentUICulture` for progress, validation issues, failure reports, apply checklist, history rows, and tray labels.
- Structured benchmark recommendation reports also follow `CurrentUICulture` for labels and confidence/health text.
- Remaining gap: free-text notes/errors returned by the CLI can still be English until CLI payloads expose localized display strings or stable message IDs.

### "CLI helper discovery can fail"
- Partly mitigated. Locator now checks `DNSPILOT_CLI_PATH`, bundled helper, then repo `target/release` and `target/debug`.
- Release packaging still must guarantee `dnspilot-cli.exe` is bundled beside the app or otherwise accessible.

### "Recommendation UI is thinner than macOS"
- Mitigated for this lane. Windows parses benchmark result JSON into a localized recommendation summary surface with selected recommendation, resolver metrics, notes, warnings, saved history ID, and a copyable report, then refreshes store-safe apply guidance.
- Remaining risk: final spacing/wrapping still needs real WinUI layout QA on Windows.
- Current acceptable state: diagnostics, recommendation summary, progress rows, resolver rows, copied reports, refreshed DNS servers, and history rows are implemented.
- Benchmark controls now update command preview/process rows before run, and completed runs keep final resolver status rows visible.

### "Tray behavior may be Store-sensitive"
- Valid. NotifyIcon is a desktop shell affordance and must be checked under packaged Store/MSIX context.
- If Store packaging rejects or degrades tray behavior, keep tray for unpackaged/power distribution and retain toolbar quick actions for Store.

### "`runFullTrust` may hurt Store approval"
- Valid. `runFullTrust` is a restricted capability and must be justified in Partner Center.
- Current rationale: packaged desktop WinUI shell, helper CLI process boundary, and tray actions. It is not used for elevation or DNS mutation.
- If Store review rejects it, reduce the Store SKU to toolbar-only packaged behavior or split tray/helper into a non-Store distribution.

### "No adapter-specific guidance"
- Valid. Windows network settings vary by adapter and Windows version.
- Current choice is stable, store-safe Settings handoff, not adapter mutation.
- Future work can add adapter detection as read-only context if it does not require broad capabilities or admin.

## Current Evidence
- `bash apps/windows/validate-windows-lane.sh` runs core tests, core build, store-safe static checks, and a WinUI build probe.
- Automated tests cover benchmark commands, live control previews, system DNS validation, progress/failure diagnostics, completed resolver statuses, apply guidance, structured benchmark recommendation reports and UI hooks, profile/history management, CLI contract decoders, benchmark result parsing, and CLI executable lookup.
- Automated tests also check `x:Uid` localization hooks, `en-US`/`vi-VN` resource keys, dynamic Vietnamese shell text, package capability template, and bundled CLI copy rule.
- Store-safe static scan currently finds no DNS mutation or admin-elevation implementation in `apps/windows/DNSPilotWindows`.
- XML well-formed checks pass for `MainWindow.xaml`, both `.resw` files, and the Store package manifest template.

## Next Hard Gate
- Run `apps/windows/Validate-WindowsLane.ps1 -Configuration Release` on Windows.
- Run the manual QA checklist in `apps/windows/windows-qa.md`.
- Validate MSIX/Store packaging and signing before any release claim.
- Follow `apps/windows/windows-publish.md` for the final publish sequence and capability justification.
