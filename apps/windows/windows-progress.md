# Windows Progress

## BLUF

The Windows lane meets the current store-safe core/view-model requirement:
benchmark, recommendation handoff, Settings guidance, profiles, history,
custom domain suites, localization, single-project MSIX scaffolding, and tray
models are implemented.
Real WinUI, MSIX, tray, and Store behavior still require a Windows host.

Runtime Readiness is implemented and automated-validated: startup and Retry use
one helper-contract loader, independently gate benchmark/apply/profiles/suites/
history, retain healthy surfaces when local storage fails, and expose an EN/VI
recovery status plus a copyable technical report. Windows-host rendering and
packaged-helper proof remain open.

The consumer shell now follows the shared reference contract: primary navigation
is Check DNS, Profiles, and History; apply/results remain in Check DNS; suites
remain with Profiles; raw reports are behind Advanced diagnostics. The shell has
compact/wide layout logic, keyboard command wiring, and Narrator live status
metadata; real Windows accessibility/layout proof remains open.

Milestone 2 is automated-complete: Quick Check is a bounded DNS-only preset,
gaming-tagged catalog suites force DNS+TCP with their Core limitation notice,
and a visible Cancel action terminates the child process tree within five seconds.
Cancelled runs are not treated as successful or saved history; successful history
is shown only when Core returns `saved_history_id`.

Milestone 3 is automated-complete: results distinguish Core-backed Recommended,
observation-only Fastest observed, and Keep current DNS. One confirmed Store-safe
Apply action copies the Core-selected servers, opens Windows Settings, then offers
System DNS retest. VPN, managed DNS, corporate DNS, and captive portal signals are
explicit `apply-plan` inputs; protected dispositions suppress the primary action.

Milestone 4 is automated-complete: a versioned LocalSettings adapter persists
normalized benchmark selections and language preference only after runtime
contracts load. Removed/corrupt catalog values fail back safely, Default and
Vietnam quick picks derive from catalog tags, capability rows distinguish Ready,
Recovery needed, OS-gated, and Unsupported, and copied diagnostic surfaces
redact user paths and common environment values.

Cross-lane pre-development review is complete. The next work is selective
consumer/release hardening, ordered in
`apps/windows/windows-predevelopment-review.md`; it does not reopen the
Store/Power architecture boundary.

## Requirement Coverage

- `.NET` solution under `apps/windows/DNSPilotWindows` with
  `DNSPilotWindows.Core` view-model/domain layer.
- Benchmark commands cover DNS-only, DNS+TCP, system-DNS validation, A/AAAA,
  resolver address-family controls, numeric controls, live preview, and
  progress/failure diagnostics. Toolbar/tray Quick Check uses a bounded DNS-only
  preset; in-panel Run uses the current preview; gaming-tagged suites force
  DNS+TCP and display their catalog limitation notice; Validate DNS forces
  system-DNS validation while preserving relevant controls.
- Persisted custom plain DNS profiles from `profile-list` are merged into the
  benchmark catalog, surfaced as selectable resolver profiles, and can be used
  in DNS-only or DNS+TCP runs.
- Persisted custom domain suites from `suite-list` are merged into the
  benchmark catalog, surfaced as selectable benchmark target suites, and can be
  added/updated/deleted from the WinUI shell through CLI suite storage commands.
- Benchmark success diagnostics now parse CLI benchmark-result JSON into a
  localized structured copyable recommendation report with health, reasons,
  resolver metrics, warning, and saved history ID.
- The WinUI diagnostics section also exposes the parsed recommendation summary,
  resolver metrics, and notes as native list/text surfaces, while preserving the
  copyable report.
- Store-safe apply guidance copies DNS servers/checklists and opens Windows
  Network Settings without admin DNS mutation.
- Results render the Core recommendation separately from the fastest observed DNS
  metric and keep-current safety state. The app never promotes an observation into
  an apply recommendation; the primary guided action is enabled only by Core's
  `apply-plan` guide disposition.
- Startup keeps apply actions blocked with no placeholder DNS servers until a
  valid runtime apply-plan loads; CLI load failure remains fail-closed.
- Runtime readiness classifies missing helper, malformed payload, unsupported
  schema, process, and local-storage failures. It creates the local app-data
  directory for first run, keeps independent healthy surfaces usable, and offers
  a Retry action without requiring elevation.
- Protected-network apply-plan dispositions suppress DNS copy and Settings
  apply actions, leaving only a copyable protection checklist.
- Domain suite validation matches Core CLI trailing-dot/case canonicalization,
  and custom-suite edit/delete ownership uses the exact CLI markers.
- Persisted delete/clear actions require native confirmation and disable the
  triggering button while the CLI mutation runs.
- Benchmark launch is single-flight across toolbar, in-panel, and tray actions.
- While a benchmark runs, Cancel is visible and keyboard-reachable with Escape.
  The process boundary receives a cancellation token, kills the entire child
  tree, waits up to five seconds, and reports a cancelled result without treating
  history as saved.
- Profile and history add/update/delete/list/clear flows use CLI contract
  runners and management row models. Built-in profile update/delete is blocked
  by profile ID before any CLI mutation call.
- WinUI host, tray host, native localization resources, Store MSIX manifest
  template, top-level `Package.appxmanifest`, MSIX launch/publish profiles,
  Store manifest preparation script, baseline package assets, bundled CLI
  locator, and publish/QA runbooks are present.
- WinUI shell now has a top-right Help button and first-run setup dialog
  persisted through `ApplicationData.LocalSettings`.
- The top-right EN/VI language selector persists for the next launch. Benchmark
  preferences persist as one versioned LocalSettings JSON document; no resolver
  data, benchmark history, or DNS changes are written outside Core storage.
- Advanced diagnostics includes per-capability readiness rows and redacts user
  paths and common environment values before reports are copied.
- Check DNS, Profiles, and History are the only primary navigation destinations.
  Technical diagnostics no longer compete with the decision workflow.
- Privacy policy draft, Store listing copy, support text, and certification
  notes are present for Partner Center preparation.

## Validation

- `apps/windows/validate-windows-lane.sh`: pass for core tests, core solution
  build, store-safe static checks, localization/packaging checks, and expected
  macOS-only WinUI build-probe handling. The script only tolerates the known
  Windows-only XAML compiler signature; unrelated WinUI failures remain fatal.
- Current automated count: 63 Windows core/static tests, including cancellation
  before launch, cancellation during progress, repeat-run, gaming-mode, and a
  bounded real-child-process termination regression, Core result-safety states,
  protected-network request flags, versioned preference normalization,
  catalog-derived quick picks, capability state rows, diagnostic/failure redaction, and
  confirmed guided-apply static wiring.

## Remaining Gates

- Run `apps/windows/Validate-WindowsLane.ps1 -Configuration Release` on Windows.
- Run `apps/windows/windows-qa.md` manual QA on Windows.
- Validate MSIX packaging, tray behavior, signing, and Partner Center
  `runFullTrust` justification.
- Ensure `dnspilot-cli.exe` is bundled or discoverable for live UI runs.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Next development roadmap and cross-lane evidence:
  `apps/windows/windows-predevelopment-review.md`.
- Critique and Store risk: `apps/windows/windows-self-review.md`.
- Publish steps: `apps/windows/windows-publish.md`.
- Privacy/listing source: `apps/windows/windows-privacy.md` and
  `apps/windows/windows-store-listing.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
