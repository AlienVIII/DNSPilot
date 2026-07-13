# Linux Completion Design And Plan

Date: 2026-07-13.
Status: Approved working direction from the user's autonomous completion mandate.

## BLUF

The existing Linux lane is a tested engineering shell, not yet a production consumer
app. Complete the Store-safe benchmark product first, using the shared CLI as the only
behavior and persistence contract. Keep Flatpak and Snap guidance-only. Keep native
Power execution fail-closed until a real privileged D-Bus mechanism, caller-bound
polkit authorization, exact rollback state, and Linux-host evidence exist.

No macOS or mobile commit should be cherry-picked into this lane. Port product patterns,
not platform code. The macOS branch is 23 commits ahead of `main`; the mobile branch is
17 commits behind `main` plus two isolated commits, so both must be treated as research
inputs until their shared changes are integrated through `main`.

## Evidence Reviewed

- Project truth: `AGENTS.md`, `PROJECT.md`, `STATE.md`, and `TODO.md`.
- macOS lane through `39f4d33`, including consumer navigation, result actions,
  benchmark commands, cancellation, history, Power rollback, release assets, and
  publisher preparation.
- Mobile lane through `7cfb9b4`, including foreground job state, native core transport,
  core-backed storage, persisted locale, accessibility metadata, and store-safe system
  access guidance. The isolated iOS DNS Settings commit remains platform-specific.
- Linux source, tests, package recipes, CLI contracts, and current release documents.
- Official NetworkManager, systemd-resolved, polkit, Flatpak, Flathub, and Snap
  documentation referenced in `linux-risks.md`.

Fresh comparison evidence:

- `swift test --package-path apps/macos/DNSPilotMac`: 265 tests passed.
- `npm test` in `apps/mobile/DNSPilotMobile`: 69 tests passed.
- Shared `dnspilot-cli` exposes catalog, capability, policy, apply-plan, benchmark,
  profile, suite, and history commands needed by Linux.

## Findings

### Critical: Native Power Is Not A Releasable Privileged Mechanism

`native_power.rs` labels the path as NetworkManager/systemd-resolved D-Bus, but the
executor actually launches `nmcli`, `resolvectl`, `ip`, and `pkcheck`. `pkcheck` checks
whether a subject is authorized; it does not turn the unprivileged helper into a
privileged mechanism. The snapshot retains only a device or link identifier, not the
DNS fields required for exact restore. NetworkManager rollback calls `device reapply`
without restoring captured values.

Impact: native execute can fail after consent and cannot prove exact rollback. It must
not be installed or presented as production-ready until Milestone 0 and Milestone 7
are complete.

### Major: Linux Forks Shared Catalog And Storage Rules

The GUI seeds two resolver profiles, hardcodes suites with data that differs from the
shared catalog, and writes a Linux-only JSON profile schema. The shared CLI already owns
SQLite-backed profiles, suites, and history. This violates the architecture rule that
the core/CLI own policy, storage, and contracts.

Impact: catalog drift, no custom suite management, no history, incompatible local data,
and duplicated validation.

### Major: Progress Is Not Live And Runs Cannot Be Cancelled

The worker sends only one final result. The process runner uses `Command::output()`, so
JSONL progress is parsed after the child exits. Resolver rows appear running but cannot
advance from real events during a run. There is no child handle or cancellation path.

Impact: long benchmarks look stalled and cannot satisfy the consumer UX already proven
on macOS/mobile.

### Major: Results Are Raw Diagnostics, Not A Decision Surface

Successful stdout is appended to the debug report. The GUI does not decode and present
recommended DNS, fastest observed DNS, confidence/gate reasons, failure rates, or one
contextual Apply/Retest action.

Impact: the app measures but does not complete the product promise: decide, apply
safely, and verify.

### Major: Flatpak Recipe Is Local QA Only

The Flatpak manifest consumes prebuilt local ELF files. Flathub requires builds from
declared sources and does not accept bundled build artifacts in submissions. The
current recipe is useful for local package smoke only.

Impact: a local Flatpak may build, but the manifest is not submission-ready.

### Major: Consumer UX And Localization Are Partial

Linux exposes Benchmark, Settings, Diagnostics, and Permissions as peer destinations,
marks setup seen when shown instead of when completed, defaults to DNS + TCP, and leaves
many visible strings in English. Locale choice does not follow the system or persist.

Impact: Linux does not yet meet the focused macOS information architecture or the
persisted multilingual behavior proven on mobile.

### Minor: Release Automation Has No Linux CI Or Single Version Source

Version `0.1.0` is repeated in Cargo, shell, Snap, rpm, deb, and AppStream metadata.
There is no repository workflow running Linux checks or retaining package artifacts.

## Cross-Lane Adoption

| Proven pattern | Linux decision |
| --- | --- |
| Check DNS, Profiles, History primary navigation | Adopt |
| Optional value-first setup and Help reopen | Adopt |
| DNS-only Quick Check; advanced DNS + TCP | Adopt |
| Live resolver progress, elapsed state, cancellation | Adopt |
| Recommended vs fastest observed and keep-current gate | Adopt |
| One contextual Apply or Retest action | Adopt |
| Core-backed profiles, custom suites, and history | Adopt |
| Default/Vietnam quick targets from core catalog | Adopt |
| System/English/Vietnamese persisted locale | Adopt |
| Keyboard and accessibility semantics | Adopt |
| Local-only data and copyable redacted diagnostics | Adopt |
| Power rollback freshness and configuration identity checks | Adapt to Linux |
| Menu bar/tray as a required workflow | Reject; tray stays optional |
| Standalone game screen | Reject; game/service checks are target presets |
| Mobile Rust FFI/Expo transport | Reject; packaged CLI is the Linux runtime |
| iOS NetworkExtension or Android VpnService behavior | Reject as OS-specific |
| Background benchmark scheduling | Defer; foreground jobs only |

## Decision L1: Runtime And Data Boundary

- **Problem:** Linux duplicates core data but still needs responsive native process
  control.
- **Options:** link `dnspilot-core` directly; embed the mobile FFI runtime; keep the
  packaged CLI and add a typed streaming adapter.
- **Trade-offs:** direct linking reduces subprocesses but creates another shell-specific
  integration and packaging boundary; mobile FFI adds unnecessary ABI complexity;
  the CLI preserves one versioned contract and matches macOS at the cost of disciplined
  process management.
- **Recommendation:** keep `dnspilot-cli` as the packaged runtime. Add typed JSON/JSONL
  decoders, streaming child supervision, cancellation, and one XDG SQLite database.
- **Reason:** this removes duplicated product rules without inventing a new runtime.
- **Confidence:** High.

## Decision L2: Linux Consumer Information Architecture

- **Problem:** the current shell exposes implementation and permission concepts as
  primary product areas.
- **Options:** keep the engineering console; move internals under Advanced; use the
  macOS-proven Check DNS, Profiles, History model.
- **Trade-offs:** the console helps developers but burdens normal users; Advanced still
  creates navigation weight; the focused model keeps diagnostics available contextually.
- **Recommendation:** primary destinations are `Check DNS`, `Profiles`, and `History`.
  Put Settings and Help in the top command surface. Put diagnostics and capability
  details behind result/error disclosures.
- **Reason:** users need a decision loop, not a platform inspector.
- **Confidence:** High.

## Decision L3: Toolkit

- **Problem:** Linux should feel native across GNOME, KDE, Wayland, and X11 without a
  rewrite that delays product proof.
- **Options:** continue eframe/egui; rewrite with GTK4/libadwaita; rewrite with Qt.
- **Trade-offs:** GTK is strongest on GNOME but weaker as a neutral Linux target; Qt
  adds another large stack; egui is already tested and capability-neutral but requires
  explicit accessibility, keyboard, clipboard, and desktop integration validation.
- **Recommendation:** keep eframe/egui for v1 and split the current GUI by feature.
  Revisit only if Linux-host accessibility or IME evidence shows a release blocker.
- **Reason:** evolution preserves tested behavior and avoids toolkit-led scope growth.
- **Confidence:** Medium-high pending Linux-host QA.

## Decision L4: Package Editions

- **Problem:** four formats have different trust and privilege models.
- **Options:** promise parity; support Store-safe only; ship two capability editions.
- **Trade-offs:** parity is inaccurate; Store-only blocks legitimate power use; two
  editions require explicit package metadata and QA but match platform reality.
- **Recommendation:** Flatpak/Snap are Store-safe benchmark/guidance editions. deb/rpm
  are native packages; Power remains a separately enabled capability and is not release
  ready until Milestone 7. Prioritize Flatpak for store evidence and deb for native
  evidence, while retaining build contracts for Snap/rpm without parity claims.
- **Reason:** package trust boundaries are product behavior, not packaging detail.
- **Confidence:** High.

## Decision L5: Privileged Apply Architecture

- **Problem:** DNS mutation needs real privilege separation, exact rollback, and
  concurrent network-change protection.
- **Options:** continue shelling out after `pkcheck`; use `pkexec` per operation; install
  a small system D-Bus mechanism that authorizes the caller with polkit and talks to
  NetworkManager/systemd-resolved over D-Bus.
- **Trade-offs:** shell commands are easy but cannot prove privilege or state identity;
  `pkexec` is simpler but passes a broad root process surface; a narrow D-Bus mechanism
  costs packaging work but gives typed requests, caller identity, auditability, and
  minimal privilege.
- **Recommendation:** use a native deb/rpm-only system D-Bus mechanism. Prefer
  NetworkManager ownership; use systemd-resolved only when NetworkManager does not own
  the link. Validate the unique bus caller with polkit, validate literal IP input again,
  snapshot exact fields plus connection/link identity, reject stale snapshots, apply,
  retest, and restore on failure or explicit user action.
- **Reason:** this is the smallest architecture that can meet the stated Power safety
  contract for three years.
- **Confidence:** High on architecture, Medium on distro behavior until real QA.

## Target User Flow

1. Open one tray-independent main window.
2. Optional setup offers `Run Quick Check`; it is complete only after Skip or Done.
3. Check DNS defaults to DNS-only with a core-backed default target and recommended
   resolver candidates. Options reveal DNS + TCP, System DNS, IPv4/IPv6, A/AAAA,
   attempts, profiles, suites, and custom domains.
4. Live rows advance from idle to running to success/failed. Cancel terminates the
   child and marks unfinished work failed with a localized cancellation reason.
5. Result shows keep-current or one recommendation, fastest observed separately,
   confidence/reasons, resolver comparison, and one primary action.
6. Store edition copies DNS and shows honest desktop-specific guidance; it never claims
   a universal Linux Settings deep link. Native Power shows a confirmation only when
   the complete capability and rollback contract is available.
7. Return to the app and Retest System DNS when supported.
8. History saves every completed run locally and supports rerun, delete, and clear.

## Implementation Milestones

### Milestone 0: Fail-Closed Truth

- **Goal:** prevent accidental use or packaging claims for the incomplete execute path.
- **Acceptance criteria:** execute requests fail with an explicit unavailable reason in
  default builds; Store packages never include helper/polkit files; native package copy
  says preview/experimental until the real mechanism passes Milestone 7; tests prove no
  DNS command is invoked.
- **Risks:** breaking existing helper contract tests or developer dry-run workflows.
- **Dependencies:** none.

### Milestone 1: Typed Core Contract Adapter

- **Goal:** make the CLI the only Linux source for catalog, profiles, suites, history,
  policy, apply plans, and benchmark results.
- **Acceptance criteria:** schema versions are checked; unsupported payloads fail with
  a copyable error; XDG SQLite is used; existing Linux JSON custom profiles migrate once
  with backup and idempotency; hardcoded profile/suite catalogs are removed.
- **Risks:** migration loss or schema drift.
- **Dependencies:** current shared CLI contract tests.

### Milestone 2: Streaming Benchmark Supervisor

- **Goal:** show real progress and support cancellation without UI blocking or zombies.
- **Acceptance criteria:** stdout/stderr are piped; JSONL events update rows while the
  child runs; cancellation terminates and reaps the child; duplicate runs are rejected;
  all rows become terminal on success, failure, parse error, cancellation, or channel
  loss; history arguments are included.
- **Risks:** pipe deadlock, process-group cleanup, race between exit and final event.
- **Dependencies:** Milestone 1 typed result decoder.

### Milestone 3: Consumer Shell And Preferences

- **Goal:** implement focused Linux information architecture without a toolkit rewrite.
- **Acceptance criteria:** only Check DNS, Profiles, History are primary; Settings/Help
  are commands; Quick Check is DNS-only; Options contains advanced controls; setup is
  optional and completion-based; locale follows System/English/Vietnamese and persists;
  the 804-line GUI is split into focused modules.
- **Risks:** egui focus/layout regression at minimum size.
- **Dependencies:** Milestones 1-2 stable state models.

### Milestone 4: Decision-Quality Results And Safe Apply Loop

- **Goal:** complete Check -> Recommendation -> Apply guidance -> Retest.
- **Acceptance criteria:** typed result UI separates recommended, fastest observed, and
  keep-current outcomes; confidence, gate reasons, failures, and timings are visible;
  one primary action is selected from apply/retest; policy/apply-plan comes from the
  CLI; Store editions only copy/show guidance; reports redact local paths and command
  arguments that may reveal private domains unless the user explicitly includes them.
- **Risks:** overstating DNS performance or hiding diagnostic detail.
- **Dependencies:** Milestones 1-3.

### Milestone 5: Profiles, Suites, And History

- **Goal:** reach macOS/mobile local-data workflow coverage through shared storage.
- **Acceptance criteria:** built-in profiles/suites are read-only; custom plain DNS
  profiles and custom suites support add/edit/delete with core validation; history is
  newest-first and supports rerun/delete/clear; selection survives refresh; Default and
  Vietnam quick picks appear only when returned by the core catalog.
- **Risks:** destructive actions or stale selections after deletion.
- **Dependencies:** Milestone 1.

### Milestone 6: Accessibility And Desktop Fit

- **Goal:** make the main app usable without tray, mouse, or color-only status.
- **Acceptance criteria:** logical keyboard order; visible focus; labels/state for
  controls through egui/AccessKit; status includes text/icon, not color alone; dialogs
  restore focus; clipboard failures are visible; layouts hold at supported minimum and
  wide sizes; GNOME/Wayland remains the primary no-tray contract.
- **Risks:** toolkit/desktop accessibility gaps requiring a later GTK decision.
- **Dependencies:** Milestone 3 UI structure.

### Milestone 7: Native Power Mechanism

- **Goal:** replace the shell-command executor with a narrow, testable privileged
  service for native packages.
- **Acceptance criteria:** typed D-Bus API; caller-bound polkit check; strict request
  size/IP/profile validation; NetworkManager GetAppliedConnection/version guard and
  exact DNS-field snapshot/restore; systemd-resolved link snapshot/restore fallback;
  active configuration identity rechecked before write and restore; root-owned snapshot
  permissions; automatic rollback on write/flush/validation failure; explicit Restore;
  default Store build cannot connect to or install the mechanism.
- **Risks:** split DNS, VPN, multiple active routes, NetworkManager/resolved ownership,
  daemon crash, or stale root-owned rollback state.
- **Dependencies:** D2 commercial expansion gate, disposable Linux QA environment, and
  Milestone 4 apply/retest UX. Code/mock work may proceed, but release enablement may not.

### Milestone 8: Package And Publisher Readiness

- **Goal:** produce honest, versioned, verifiable artifacts for all four formats.
- **Acceptance criteria:** one version source; locked builds; Flatpak builds from public
  immutable source plus generated Cargo sources; Snap builds from source/pinned inputs;
  deb/rpm separate Store-safe and Power payload ownership; AppStream release data,
  translations, icon, screenshots, support/privacy links, and changelog validate;
  install/uninstall/smoke/rollback scripts are prepared; package artifacts and checksums
  are retained by a Linux CI integration request.
- **Risks:** store policy, source URL, unavailable publisher credentials, or distro ABI.
- **Dependencies:** public source/tag and hosted URLs are manual gates.

### Milestone 9: Release Evidence And Handoff

- **Goal:** leave only real Linux device and publisher actions.
- **Acceptance criteria:** fmt, unit, integration, clippy, core CLI compatibility,
  mocked capability, migration, process, package-policy, metadata, and source-build
  checks pass; automated package smoke runs where a Linux executor exists; exact manual
  GNOME/KDE, Flatpak/Snap/deb/rpm, polkit/apply/restore, screenshot, signing, and store
  steps are documented with expected results and rollback.
- **Risks:** no real host evidence; status must remain `NOT RUN`, not release-ready.
- **Dependencies:** Milestones 0-8.

## Recommended Order

Milestone 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 8 -> 9. Milestone 7 remains behind
the approved commercial/real-host gate and can run in parallel only as an explicitly
experimental native package track.

## TDD And Commit Contract

For each behavior milestone:

1. Add one focused failing behavior/contract test and record the valid RED reason.
2. Implement the smallest GREEN slice.
3. Refactor only the touched boundary.
4. Run targeted tests, full Linux tests, fmt, and clippy.
5. Update Linux progress/risk/publish evidence.
6. Commit only verified Linux-owned files with one milestone-focused message.

## Definition Of Code-Complete

Linux Store-safe is code-complete only when Milestones 0-6 and 8-9 pass automated
gates. Native Power is code-complete only when Milestone 7 passes mocked/contract tests;
it is not release-ready until real NetworkManager/systemd-resolved/polkit Apply ->
Validate -> Restore evidence exists. Signing, accounts, public hosting, store submission,
and final real-device QA remain the only accepted manual gates.
