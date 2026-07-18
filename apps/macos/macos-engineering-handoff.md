# macOS Engineering Handoff

Architecture decisions are fixed in `PROJECT.md`. Milestones 0-3 are implemented and
locally validated for behavior. Milestone 3A is reopened by reproduced localization
and interaction defects. Milestone 4 cannot complete until 3A passes.

## Milestone 0: Window Correctness

- **Goal:** one main-window lifecycle and consistent navigation state.
- **Acceptance criteria:** launch shows one main window; Dock reopen and menu actions
  reuse/open the SwiftUI scene; sidebar selection always matches detail; onboarding
  appears once; no direct `NSWindow` shell construction remains.
- **Risks:** regressing SwiftPM foreground launch or menu-bar reopen behavior.
- **Dependencies:** existing activation tests and `WindowGroup` identifier.
- **Validation:** focused window/activation tests, `swift test`, repeated cold launch,
  close/reopen, menu-bar open, Dock reopen, and screenshot evidence.

## Milestone 1: Consumer Information Architecture

- **Goal:** expose only Check DNS, Profiles, and History as primary destinations.
- **Acceptance criteria:** Benchmark becomes Check DNS and is the default; Game Ping is
  a preset; results remain in Check DNS; Custom DNS becomes Profiles; Publish, capability
  matrix, platform rows, validation evidence, and raw catalog are absent from release
  navigation but remain available through CLI/docs or development diagnostics.
- **Risks:** losing internal QA visibility or deep links from menu-bar actions.
- **Dependencies:** stable destination enum and development/release build policy.
- **Validation:** navigation tests plus a release-build screenshot inventory.

## Milestone 2: First-Run and Result UX

- **Goal:** teach the value loop through action, not permission explanation.
- **Acceptance criteria:** onboarding is optional, reopened from top-right Help, and
  starts a safe Quick Check; no Power copy in Store onboarding; onboarding is marked
  complete only after explicit completion; result clearly separates Recommended from
  Fastest observed; one primary action leads to Apply guidance or Retest; technical copy
  actions move behind secondary disclosure.
- **Risks:** oversimplifying confidence/safety states or hiding rollback information.
- **Dependencies:** recommendation state model and Store/Power SKU capability.
- **Validation:** view-model tests, accessibility identifiers, VoiceOver/keyboard pass,
  and five moderated users completing the full loop without assistance.

## Milestone 3: Desktop Fit and Maintainability

- **Goal:** native command surface and maintainable feature boundaries.
- **Acceptance criteria:** scene-level commands cover Quick Check, Cancel, Results,
  Settings, Help, and sidebar visibility; key actions remain visible; the monolithic app
  file is extracted incrementally into App, Shell, Onboarding, Benchmark, Results,
  Profiles, Readiness/Internal, and PlatformActions files; no core contract changes.
- **Risks:** behavior drift during extraction and duplicated shortcut ownership.
- **Dependencies:** Milestones 0-2 stabilize ownership and destination names.
- **Validation:** compile after each extraction, full Swift tests, shortcut audit, and
  no visual/behavior change outside approved UX scope.

## Milestone 3A: Localization And Interaction Consistency

- **Goal:** one selected language, one text source of truth, and predictable native
  click/keyboard behavior across every consumer surface.
- **Acceptance criteria:** adopt one `Localizable.xcstrings` catalog; `System` follows
  macOS; EN or VI updates every open app surface without mixed-language tooltips;
  Core diagnostic prose is represented by stable IDs for localized UI while raw logs
  remain copyable; toolbar language selection shows the current locale through a
  `globe + EN/VI/System` menu; Store-safe Settings hides Power controls; disclosure
  labels and option rows use their full visible bounds as the action target; all
  controls have keyboard focus and VoiceOver names.
- **Risks:** hiding useful diagnostics, changing test fixtures that assert English
  copy, bundle-resource lookup mistakes in SwiftPM, and accidental Store/Power UI
  crossover.
- **Dependencies:** D7 in `PROJECT.md`; locale-neutral Core issue/message IDs for
  Core-originated user messages; deterministic UI fixtures for visual capture.
- **Validation:** localization lint, catalog completeness/placeholder tests, EN/VI
  unit tests, keyboard and VoiceOver pass, and screenshot matrix for default, running,
  degraded result, failure, Profiles, History, and Settings at minimum window size in
  Light and Dark Mode.
- **Implementation brief:**
  `docs/research/2026-07-14-macos-localization-interaction-review.md`.

## Milestone 4: Release Evidence

- **Goal:** prove the Store SKU is commercially releasable.
- **Acceptance criteria:** production archive signed with the correct distribution
  identity; sandbox/helper entitlements match; hardened runtime validation passes;
  App Store metadata and review notes match actual guided behavior; final smoke covers
  Check, recommendation, apply handoff, restore guidance, retest, Results, Help, and
  Settings.
- **Risks:** signing/provisioning mismatch and Store copy overstating system mutation.
- **Dependencies:** Apple account, identifiers, certificates, hosted support/privacy
  URLs, and completed UX milestones.
- **Validation:** release preflight, signed bundle validation, App Store review checklist,
  and manual clean-Mac QA.

## Recommended Order

Milestone 0 -> Milestone 1 -> Milestone 2 -> Milestone 3 -> Milestone 3A ->
Milestone 4. Do not start Power release work before the Store SKU passes Milestone 4.

## Current Handoff

- Automated evidence: `./script/ci_macos.sh` and
  `./script/preflight_macos_release.sh --include-power` pass.
- Store-safe feature scope stays frozen, but Milestone 3A is authorized release-quality
  work based on reproduced localization and hit-target defects.
- Do not start a broad SwiftUI extraction during release stabilization.
- Implement the review brief in order; do not patch isolated strings while keeping
  the split localization architecture.
- Remaining work is Milestone 3A plus the manual list in `STATE.md` and
  `apps/macos/PUBLISHING.md`.
- Any new production change needs a reproduced defect or failed release gate, focused
  tests, and a new engineer assignment.
