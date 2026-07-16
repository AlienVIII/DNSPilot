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
- Store packaging readiness uses single-project MSIX: top-level `Package.appxmanifest`, `Properties\launchSettings.json`, `Properties\PublishProfiles\win10-x64.pubxml`, and `Packaging\Package.Store.appxmanifest.template`.
- `Prepare-WindowsStorePackage.ps1` generates `Package.appxmanifest` from the template with Partner Center identity/version/publisher metadata and can copy the release `dnspilot-cli.exe` into the app project.
- Baseline Store logo/tile/splash PNG assets now exist; replace only if final branding changes.
- Privacy policy draft, Store listing copy, support copy, and certification notes live in `windows-privacy.md` and `windows-store-listing.md`.
- Packaged helper path is explicit: copy `dnspilot-cli.exe` beside `DNSPilotWindows.App.csproj`; the app project copies it to output when present.
- Cross-lane review selected selective parity plus release proof. Keep the CLI
  helper boundary; port consumer IA, readiness, cancellation, result safety,
  responsive/accessibility, preferences, and package evidence in that order.
- The complete Store workflow must remain available from the main window. Tray
  is optional and cannot be a release dependency.
- In-process Rust is deferred unless packaged-helper or Store evidence rejects
  the current architecture.
- Runtime Readiness is now a single startup/retry path: it probes the helper
  contracts independently, maps missing helper/malformed payload/unsupported
  schema/process/storage failures to recoverable EN/VI status, creates the
  local storage parent on first run, and gates only affected surfaces.
- The consumer shell now implements the shared reference navigation: Check DNS,
  Profiles, and History. Apply/recommendation remain in Check DNS, suites stay in
  Profiles, and technical reports move behind Advanced diagnostics. Root-grid
  size changes drive compact/wide stacking; static contracts cover keyboard and
  Narrator metadata pending Windows-host proof.
- Quick Check now uses the macOS-equivalent bounded DNS-only preset: first two
  plain profiles, the default three-domain suite, and one attempt. It deliberately
  ignores the current advanced selection so toolbar/tray behavior is predictable.
- A selected catalog suite tagged `gaming` forces DNS+TCP in the current preview
  and renders the catalog description as the limitation notice. The shell does
  not introduce Windows-specific game targets or ranking rules.
- Benchmark cancellation now flows from visible Cancel/Escape through a
  `CancellationToken` to the process boundary. The runner kills the full child
  tree, waits at most five seconds, and returns a typed cancelled result. A late
  cancel cannot overwrite a process that already exited successfully.
- The app reports saved history only when the Core result includes
  `saved_history_id`; Core remains responsible for atomic no-partial-history
  semantics, already requested in `windows-core-cli-request.md`.
- Result safety now keeps three distinct statements: `Recommended` is the Core
  high-confidence healthy recommendation; `Fastest observed` is a non-actionable
  median-DNS observation; `Keep current DNS` follows a failed/inconclusive or
  explicitly blocked Core gate. The Windows shell does not re-rank resolvers.
- Store apply now has one confirmed `Apply in Windows Settings` path. Confirmation
  copies the Core-selected servers then launches Settings; Windows remains the
  only writer. `Retest System DNS` appears after that handoff. Copy DNS/checklist
  and technical report remain secondary.
- VPN, managed DNS, corporate DNS, and captive portal are explicit user signals
  forwarded to `apply-plan`; no read-only adapter discovery or hidden detection
  was added. A protected Core disposition suppresses the primary CTA.

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
- Toolbar/tray Quick Check runs a bounded DNS-only preset; in-panel Run uses the
  current preview, while gaming-tagged suites force DNS+TCP. Toolbar Validate DNS
  forces system-DNS validation while preserving selected A/AAAA/attempts/timeout.
- Completed benchmark progress now preserves final per-resolver success/degraded/failed details.
- Persisted plain DNS profiles from `profile-list` are merged into the benchmark catalog, exposed in the Benchmark resolver profile picker, and preserved across apply-guidance refreshes when still valid.
- Profile rows now expose edit/delete safety state; only `use_case=custom` profiles are treated as editable/deletable by the Windows shell, and built-in update/delete is blocked by profile ID before any CLI mutation call.
- Persisted domain suites from `suite-list` are merged into the benchmark catalog, exposed in the Benchmark domain suite picker, and managed through suite add/update/delete commands.
- Initial apply guidance is blocked and empty until the runtime `apply-plan`
  loads; CLI load failures remain fail-closed.
- Suite duplicate validation canonicalizes case and trailing dots like Core CLI,
  while edit/delete ownership follows the CLI's exact custom markers.
- Profile/suite/history destructive mutations use native confirmation dialogs
  and disable the triggering button while running.
- Benchmark execution is single-flight across toolbar, in-panel, and tray entry
  points.
- Protected-network apply-plan dispositions hide DNS copy and Settings apply actions; only the protection checklist remains available.
- `Validate-WindowsLane.ps1` is the Windows-host validation entrypoint;
  `validate-windows-lane.sh` only tolerates the known Windows-only
  `XamlCompiler.exe` failure on macOS.

## Open Questions
- Store asset approval, signing, hosted privacy/support URLs, and MSIX submission metadata are not validated yet.
- Partner Center must approve/accept `runFullTrust` for the packaged desktop shell/helper/tray model.
- CLI-returned free-text notes/errors may still be English until CLI payloads expose stable message IDs or localized display fields.
- Confirm NotifyIcon behavior in packaged Store context during Windows QA.
- Core should expose locale-neutral runtime/schema metadata and stable message
  IDs; requests are recorded in `windows-core-cli-request.md`.

## Handoff
- Keep lane changes in `apps/windows/**`.
- Record Core CLI needs in `windows-core-cli-request.md`.
- Current validation was automated only; no real Windows UI/device/store testing was performed on macOS.
- `history-delete` uses core CLI `--id`; Windows command builder was corrected from the earlier `--history-id` mismatch.
- Publish path, MSIX build command, and Store capability justification are in `apps/windows/windows-publish.md`; listing/privacy copy is in `windows-store-listing.md` and `windows-privacy.md`.
- Windows now has macOS-equivalent `PartnerCenter/` reviewer notes, screenshot
  plan, support/privacy sources, and `Build-PartnerCenterSite.ps1` for generated
  public pages. The script is local-only and requires an explicit support email
  plus HTTPS URL; hosting remains a manual release gate.
- Milestones 0 through 4 are automated-complete. Milestone 5 is Windows-host
  release evidence only; continue automated checks while collecting its manual
  QA, signing, Partner Center, and hosted-URL gates in one final report.
- Milestone 4 adds versioned benchmark/language preferences normalized against
  the runtime catalog, catalog-tag Default/Vietnam quick picks, diagnostics
  capability rows, and privacy-safe report redaction. Windows-host QA must prove
  packaged persistence, restart language behavior, and visual rendering.
- Root `STATE.md` and `TODO.md` are stale relative to Windows commits `c3aa69c`
  and `a8216c0`.
  Refresh them from an integration/docs lane; do not widen Windows ownership.
