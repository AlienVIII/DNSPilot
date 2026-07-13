# macOS Engineering Handoff

Architecture decisions are fixed in `PROJECT.md`. Implement only the milestones below;
raise an architecture question instead of expanding scope.

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

Milestone 0 -> Milestone 1 -> Milestone 2 -> Milestone 3 -> Milestone 4. Do not start
Power release work before the Store SKU passes Milestone 4.

## Engineer Thread Prompt

Implement Milestone 0 only on the macOS worktree. Follow `AGENTS.md`, preserve the
Store/Power boundary, use tests before behavior changes, and stop if the single-window
design requires a new architecture decision. Report changed files, test evidence,
runtime launch/reopen evidence, and remaining risks. Do not touch other OS lanes.
