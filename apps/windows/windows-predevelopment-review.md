# Windows Pre-Development Review

## BLUF

Windows should not pursue literal macOS/mobile feature parity. The selected
approach is selective parity plus release proof: keep the existing CLI boundary,
port proven consumer UX and resilience patterns, and make the toolbar flow fully
Store-viable even when tray integration is unavailable.

The current baseline is Windows commit `bad68e1f`. It already covers the scoped
benchmark modes, progress and diagnostics, profiles, suites, history, guided
Settings handoff, localization, tray models, and MSIX scaffolding. The remaining
engineering work is product hardening, not a second shell implementation.

This review is the source of truth for the next Windows development milestones.
It does not authorize Power-edition or privileged DNS mutation work.

## Evidence Baseline

| Area | Proven elsewhere | Current Windows state | Decision |
| --- | --- | --- | --- |
| Consumer navigation | macOS exposes Check DNS, Profiles, and History as primary destinations | Six top-level destinations expose Apply, Suites, and Diagnostics like a QA console | Promote the three-destination information architecture; keep apply/results contextual and technical diagnostics secondary |
| Quick check | macOS Quick Test is DNS-only; gaming presets explicitly use DNS + TCP | Toolbar Quick always forces DNS + TCP | Promote DNS-only Quick Check; force DNS + TCP only for connection-path targets such as gaming suites |
| Long-running work | macOS supports visible cancellation and terminates the process | Windows is single-flight but has no operational Cancel path | Promote bounded cancellation and an explicit cancelled result |
| Result safety | macOS separates balanced recommendation, fastest observed, and keep-current decisions | Windows renders recommendation data but has a thinner hierarchy | Promote confidence-aware result states before changing apply UX |
| Guided apply | macOS uses one primary edition-aware action | Windows exposes copy, open Settings, and checklist as peer actions | Promote one confirmed primary guided action; keep copy/checklist as secondary actions |
| Runtime readiness | Mobile installable builds prove a standalone runtime and explicit ready/os-gated/unsupported states | Windows bundles a CLI helper and fails closed, but startup errors are mostly diagnostic text | Keep the helper architecture; add explicit readiness and recovery states |
| Responsive UX | Mobile has deterministic compact/expanded layouts | Windows XAML is a fixed two-column surface with a wide toolbar | Promote WinUI visual states, 200% scaling, high contrast, and narrow-window behavior |
| Accessibility | macOS/mobile expose command and accessibility state contracts | Windows has tooltips but no complete keyboard, Narrator, or live-status contract | Promote semantic names, live announcements, focus recovery, and keyboard accelerators |
| Persistence | Mobile validates and persists user preferences; all lanes use Core-backed profile/suite/history storage | Core storage is present; benchmark controls are not a versioned preference contract | Promote validated LocalSettings preferences; keep Core storage authoritative |
| Release evidence | macOS/mobile have strict preflight and native build smoke artifacts | Windows has scripts and package scaffolding but no Windows-host proof | Promote package/launch/helper smoke evidence; retain real-device and Store submission as manual gates |

Evidence sources:

- macOS commits `39f4d33`, `a8b973f`, `c5f9cd1`, `aee3fb8`, and
  `bb8758a`, plus `apps/macos/macos-progress.md` and
  `apps/macos/macos-engineering-handoff.md`.
- Mobile commits `7cfb9b4`, `79df2e2`, `1ca726f`, `ab2d735`, and
  `2d46749`, plus `apps/mobile/mobile-progress.md` and
  `apps/mobile/mobile-readiness.md`.
- Windows commit `bad68e1f`, the 40 core/view-model tests, and
  `apps/windows/validate-windows-lane.sh`.

Evidence is intentionally asymmetric. Mobile does not prove streaming native
progress better than Windows, and Windows already has persisted first-run Help.
Those implementations should not be replaced.

## Principal Findings

### Critical

- The release shell exposes internal workflow structure instead of the consumer
  task. Apply, Suites, and Diagnostics must not remain peer destinations in the
  Store navigation.
- Runtime/helper compatibility is not a first-class state. Missing helper,
  unsupported payload schema, corrupt output, and local database failure need
  distinct fail-closed recovery states.
- There is no real Windows-host evidence for WinUI launch, packaged helper
  discovery, MSIX install, tray behavior, or Store capability acceptance. This
  blocks a release claim but must not block automated implementation work.

### Major

- A running benchmark cannot be cancelled even though the progress model has a
  cancelling state.
- Quick Benchmark uses the more expensive DNS + TCP mode by default. The
  consumer quick path should be DNS-only; tagged gaming/connection-path suites
  should select DNS + TCP and show the Core catalog disclaimer.
- Results do not yet communicate recommended, fastest observed, and keep-current
  states with the same safety hierarchy as macOS.
- Guided apply has multiple peer actions instead of one clear confirmed action,
  followed by System DNS validation.
- The fixed layout, toolbar, focus behavior, and status announcements are not
  ready for narrow windows, high contrast, 200% scaling, keyboard-only use, or
  Narrator.

### Minor

- Benchmark preferences should be persisted through a validated, versioned
  LocalSettings model.
- Default and Vietnam suites should be first-class quick picks derived from the
  Core catalog, not duplicated constants.
- Copyable diagnostics should include app/CLI/schema readiness while keeping raw
  paths and unrestricted stderr behind technical disclosure.

### Suggestion

- Add notifications and diagnostics bundle export only after runtime, UX,
  accessibility, and package gates pass.

## Decision

### Options Considered

1. Full macOS/mobile parity, including in-process Rust, tray parity, adapter
   discovery, notifications, and Power actions. This maximizes scope and creates
   Store/policy risk without proving user value.
2. Release hardening only. This is the shortest route to a package, but it would
   freeze a QA-console information architecture and weak cancellation/result UX.
3. Selective parity plus proof-first hardening. Port only proven consumer and
   resilience patterns, retain the current CLI boundary, and make optional shell
   integrations non-blocking.

### Recommendation

Choose option 3.

It improves the release product without a cross-language runtime rewrite. It
also preserves the Store-safe boundary, keeps Core authoritative, and provides
a clear fallback when tray or restricted capabilities are rejected. Confidence
is high for the engineering direction and medium for Store acceptance until a
real package reaches Partner Center.

## Architecture Invariants

- Core CLI owns catalog, benchmark, recommendation, policy, apply-plan, and
  profile/suite/history contracts.
- The bundled CLI helper remains the Windows runtime. An in-process Rust adapter
  is reconsidered only if packaged-helper or Store validation fails with
  evidence.
- Store build stays `asInvoker`. It never invokes UAC, `netsh`, DNS registry
  writes, `DnsClient` mutation, a privileged service, or silent flush/apply.
- Store apply means confirm, copy DNS, open Windows Settings, and retest.
- The complete workflow is available in the main window. Tray is optional and
  cannot be required for Store acceptance.
- Power edition is a separate future product boundary with separate packaging,
  permission, rollback, and commercial approval.
- No background or scheduled benchmark work is added without a separate product
  and policy decision.
- Local app data remains local by default. Reports must avoid secrets and redact
  environment-specific paths from the consumer surface.

## Engineering Milestones

### Milestone 0: Runtime Readiness

**Status: automated implementation complete on 2026-07-14; Windows-host WinUI/MSIX
proof remains a Milestone 5 manual gate.**

- **Goal:** make helper and contract availability explicit, recoverable, and
  fail-closed.
- **Acceptance criteria:** Checking, Ready, Degraded, and Incompatible states are
  modeled; missing helper, non-zero probe, malformed JSON, unsupported schema,
  and database errors have tested recovery copy; benchmark/apply actions are
  enabled only when their required contracts are ready; diagnostics include app,
  CLI, and schema versions when available; bundled-helper validation remains in
  both macOS static and Windows Release gates.
- **Risks:** an all-or-nothing readiness model could block safe local storage or
  Settings guidance unnecessarily. Capability readiness must be per surface.
- **Dependencies:** existing locator, catalog/capabilities decoders, and the Core
  requests in `windows-core-cli-request.md`. Initial work may probe existing
  commands while the requested runtime metadata contract is pending.
- **Validation:** TDD covers missing helper, malformed JSON, unsupported schema,
  isolated storage failure, first-run local storage directory creation, partial
  shell hydration, and static startup/retry/gating wiring. `validate-windows-lane.sh`
  passed 54 tests on macOS at Milestone 2; packaged-helper smoke remains Windows-host work.

### Milestone 1: Consumer Shell And Accessibility

**Status: automated implementation complete on 2026-07-14; Windows-host layout,
keyboard, Narrator, high-contrast, and 200% scaling proof remain a Milestone 5
manual gate.**

- **Goal:** turn the current feature console into a native consumer task flow.
- **Acceptance criteria:** primary navigation is Check DNS, Profiles, and History;
  suites live with Profiles; results/apply remain in Check DNS; Diagnostics is an
  Advanced disclosure; narrow and wide WinUI visual states have stable layouts;
  controls have AutomationProperties names/IDs; running/result status is
  announced; keyboard accelerators cover Quick Check, Cancel, Results, Settings,
  and Help; focus returns to the relevant result/error action.
- **Risks:** moving surfaces can break existing scroll/navigation behavior and
  localization resource bindings.
- **Dependencies:** Milestone 0 readiness surfaces and the current localized
  resource keys.
- **Validation:** navigation/resource/static tests cover the three destinations,
  contextual diagnostics, EN/VI resources, keyboard accelerator wiring, live
  readiness announcements, and compact/wide layout contract. Windows narrow/wide,
  200%, high-contrast, keyboard, and Narrator QA remain host work.

### Milestone 2: Benchmark Control And Cancellation

**Status: automated implementation complete on 2026-07-14; Windows-host process,
WinUI, tray, and MSIX proof remain a Milestone 5 manual gate.**

- **Goal:** make the default check fast, predictable, and interruptible.
- **Acceptance criteria:** Quick Check uses a small DNS-only plan; explicit DNS +
  TCP remains available; Core suites tagged `gaming` force DNS + TCP and show
  their catalog description as the limitation notice; Cancel is visible only
  while running; cancellation stops the child process within a bounded timeout,
  produces a Cancelled result, saves no partial history, and preserves
  single-flight behavior; subsequent runs work without restarting the app.
- **Risks:** process-tree termination and progress pipe shutdown differ on
  Windows; a race can save incomplete history or overwrite the cancelled state.
- **Dependencies:** existing progress JSONL runner, catalog tags/descriptions,
  and a documented atomic-history expectation from Core.
- **Validation:** RED tests for cancel-before-start, cancel-during-progress,
  bounded termination, no history save, repeat run, gaming mode, and disclaimer;
  then core tests and mocked process tests. The Windows lane now has those RED/GREEN
  tests plus a real local child-process cancellation regression. The app marks
  history saved only when Core returns `saved_history_id`; its no-partial-row
  guarantee remains the documented Core CLI atomic-history contract.

### Milestone 3: Result Safety And Guided Apply

- **Goal:** make the recommendation trustworthy and the Store-safe next action
  obvious.
- **Acceptance criteria:** results distinguish Recommended, Fastest observed, and
  Keep current DNS; low confidence or unhealthy gates never produce an apply
  recommendation; one primary `Apply in Windows Settings` action requires
  confirmation, copies the selected servers, opens Settings, and presents
  `Retest System DNS`; copy/checklist/report remain secondary; VPN, managed DNS,
  corporate DNS, and captive portal inputs can request protected guidance;
  protected dispositions suppress apply actions.
- **Risks:** UI-derived safety logic could diverge from Core. The app may only
  render Core decisions and must not re-rank resolvers independently.
- **Dependencies:** existing benchmark result, recommendation gate, and
  `apply-plan windows-store` payloads. Read-only adapter discovery is not required.
- **Validation:** decision-state and CTA tests first; protected-plan fixtures;
  localization tests; mocked clipboard/Settings launch tests; real Settings and
  System DNS retest QA later.

### Milestone 4: Preferences And Diagnostics

- **Goal:** make repeated use efficient without creating hidden state.
- **Acceptance criteria:** a versioned LocalSettings model persists valid mode,
  record family, resolver family, numeric controls, selected profiles/suite, and
  language choice; corrupt or removed values fall back safely; Default/Vietnam
  quick picks come from catalog tags/IDs; capability rows clearly label ready,
  OS-gated, unsupported, and recovery states; consumer reports are copyable and
  privacy-safe; technical details retain command, elapsed time, safe stderr, and
  version/schema data.
- **Risks:** stale IDs and settings migrations can silently alter benchmark
  scope.
- **Dependencies:** Milestones 0-3 stable state models.
- **Validation:** preference migration/corruption tests; catalog-removal tests;
  EN/VI copy tests; report redaction tests.

### Milestone 5: Windows Release Evidence

- **Goal:** produce a Store candidate for which only account, signing, final
  device QA, and submission remain manual.
- **Acceptance criteria:** Release validation builds WinUI and MSIX; the installed
  package launches and finds the bundled helper; toolbar actions complete the
  entire workflow without tray; tray is retained only when packaged behavior and
  Store policy allow it; package identity/version/assets/capabilities and listing
  claims are validated; clean-install, upgrade, uninstall/reinstall, offline,
  firewall, VPN, narrow/wide, EN/VI, accessibility, and Settings handoff cases
  are recorded in the QA evidence template.
- **Risks:** `runFullTrust`, NotifyIcon, publisher identity, signing, or package
  architecture may fail Partner Center validation.
- **Dependencies:** Windows 10/11 host, Visual Studio/Windows SDK, Partner Center
  identity, signing identity, and hosted privacy/support URLs for final release.
- **Validation:** `Validate-WindowsLane.ps1 -Configuration Release`, installed
  package smoke, `windows-qa.md`, and `windows-publish.md`.

Recommended order is Milestone 0 through Milestone 5. Automated and mocked work
continues when a Windows device or Store account is unavailable; manual gates do
not pause implementation.

## Explicitly Deferred Or Rejected

### Deferred

- In-process Rust runtime, until helper/package evidence requires it.
- Read-only adapter/VPN/captive-portal auto-detection, pending a stable privacy
  and capability contract. Manual context inputs are sufficient for v1.
- Notifications and diagnostics bundle export.
- Power-edition service, direct apply, flush, and rollback implementation.

### Rejected For The Store SKU

- Silent DNS mutation, UAC, admin services, `netsh`, registry writes, and hidden
  Power behavior.
- Tray-only workflows or claims that DNS was applied/flushed automatically.
- Mobile-specific NetworkExtension, Private DNS, VPN, bridge, or background-job
  architecture.
- macOS-specific MenuBarExtra, AppKit activation, AppleScript/networksetup, and
  signing/notarization behavior.

## Definition Of Ready

- Baseline is `bad68e1f`; no milestone reimplements its completed flows.
- Each behavior milestone starts with RED view-model/process-boundary tests.
- Core dependencies are recorded in `windows-core-cli-request.md`; Windows does
  not edit Core to bypass lane ownership.
- Store-safe and Power boundaries are fixed by automated static checks.
- Consumer IA, cancellation semantics, result states, responsive breakpoints,
  accessibility expectations, and failure states have acceptance criteria above.
- Manual Windows/signing/Store gates are isolated in Milestone 5 and do not block
  implementation.
- Direct NuGet dependencies are current and no vulnerable direct/transitive
  packages were reported on 2026-07-13. Transitive updates are not force-pinned;
  they should arrive through tested parent package upgrades.
- Root `STATE.md` and `TODO.md` still describe the pre-`bad68e1f` Windows lane;
  their integration owner should refresh them after this Windows-only milestone.

The next engineering session starts with Milestone 0 only, then completes and
commits each verified milestone before moving forward.
