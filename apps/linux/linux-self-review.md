# Linux Self Review

Last reviewed: 2026-07-13 against macOS `39f4d33`, mobile `7cfb9b4`, the shared CLI,
and current official Linux platform documentation.

## Findings

### Critical: Power Execute Is Not Release-Safe

- The prior command executor used `nmcli`/`resolvectl` after `pkcheck`, which was not a
  privilege boundary and could not prove exact rollback.
- Resolution completed for the default build: command execution and the shipped polkit
  policy were removed; every execute request now returns `ExecuteUnavailable` before
  any executor action; deb/rpm payloads do not ship a helper or policy. The future
  D-Bus/polkit mechanism remains separately gated in `linux-completion-plan.md`.

### Major: Shared Product Contracts Are Forked

- Linux hardcodes resolver/suite data and persists a Linux-only JSON profile schema.
- The shared CLI already owns catalog, profile, suite, history, policy, and apply-plan
  contracts through SQLite and versioned JSON.
- Resolution: Milestone 1 migrates Linux to a typed CLI adapter and one XDG SQLite DB.

### Major: Benchmark Progress Is Post-Processed

- `Command::output()` buffers until exit and the worker emits only one final result.
- There is no child cancellation/reaping contract.
- Resolution: Milestone 2 streams JSONL events and owns cancellation/terminal cleanup.

### Major: Results Do Not Complete The User Decision Loop

- Final benchmark JSON is appended to Diagnostics rather than decoded into a result.
- There is no recommended-versus-fastest presentation or contextual Apply/Retest CTA.
- Resolution: Milestones 3-5 adopt the focused macOS/mobile product loop.

### Major: Flatpak Is Not Flathub-Submission Ready

- The current manifest consumes local prebuilt ELF payloads.
- Resolution: retain it as local smoke input, then add an immutable source/Cargo-sources
  manifest for submission in Milestone 8.

### Major: Consumer Localization And Accessibility Are Incomplete

- Many visible labels/setup/status strings bypass `i18n.rs`; language does not follow
  the system or persist.
- Keyboard/screen-reader semantics lack release evidence.
- Resolution: Milestones 3 and 6.

### Minor: Version And CI Evidence Are Fragmented

- Version metadata is repeated across package formats and no Linux CI workflow retains
  package evidence.
- Resolution: Milestone 8 plus a main-branch CI integration request.

## Scope Guard

- This lane owns Linux app/product behavior under `apps/linux/**`.
- It does not implement real DNS mutation for store packages.
- It does not promise feature parity across Flatpak, Snap, deb, and rpm.
- It does not block on manual distro/package testing.

## Main Goal Coverage

| Goal | Status | Evidence |
| --- | --- | --- |
| Capability matrix: Flatpak, Snap, deb/rpm | Covered | `capabilities.rs`, `detect.rs`, capability tests |
| Benchmark modes: DNS only, DNS + TCP, current resolver | Covered | `benchmark.rs`, app/session tests, runner tests |
| Process UI: idle/running/success/failed per step/resolver | Covered | `process.rs`, `worker.rs`, non-blocking GUI process table, runner/worker/diagnostics tests |
| Result diagnostics and copyable debug report | Covered | `diagnostics.rs`, CLI/report tests |
| Guided settings only for store/sandbox builds | Covered | profile/family selection, copy action, localized in-app guide, settings/CLI tests |
| Native power path plan | Design covered; execute prototype not release-safe | `linux-completion-plan.md`, `native_power.rs`, helper tests |
| Tray optional | Covered as invariant | capability/report output and native app model say tray optional |
| Custom DNS profile add/edit/delete | Covered | in-memory store plus file-backed CLI commands |
| IPv4/IPv6 and A/AAAA controls | Covered | settings/app/session tests |
| Vietnam/default suites | Covered | suite catalog tests |
| Capability detection without real DNS mutation | Covered | detector snapshot/runtime path, CLI `detect` |
| Native app permission model | Covered as GUI/view-model/CLI | `gui_main.rs`, `permissions.rs`, `native_app.rs`, CLI `permissions`, CLI `app-model` |
| English/Vietnamese localization | Covered for Linux shell/native app/publish surfaces | `i18n.rs`, `native_app.rs`, `publish.rs`, i18n behavior tests |
| Packaging/publish readiness | Covered as build recipes/checklist; real artifacts remain a Linux-host gate | `scripts/build-packages.sh`, `packaging/**`, packaging policy tests, `linux-publish-checklist.md` |

## Counterarguments And Resolution

1. **Counterargument: A CLI harness is not a finished Linux GUI.**
   Resolved for this lane. `dnspilot-linux-gui` is now the desktop launcher, uses the existing app/session, storage, runner, process-status, diagnostics, permission, and localization modules, and does not depend on tray integration. Final Linux package QA still has to validate the window on GNOME/Wayland.

2. **Counterargument: Capability detection can be wrong on some distros.**
   Valid. Detection is intentionally conservative and non-mutating. It checks sandbox markers, resolver-stack tools, paths, and polkit availability. Later distro QA must validate real packaging behavior.

3. **Counterargument: deb/rpm without resolver stack gets diagnostics-only, not guided settings.**
   Intentional. Guided settings are reserved for store/sandbox builds. Native packages without NetworkManager/systemd-resolved plus polkit should not pretend to have an apply path.

4. **Counterargument: Real DNS apply is too risky without Linux QA.**
   Valid. Default builds are now fail-closed and ship no privileged DNS path. Milestone
   7 remains gated on the D-Bus privilege boundary, exact rollback, and real host QA.

5. **Counterargument: Current/system resolver validation is not universally available.**
   Valid. It remains capability-gated. Unsupported mode requests fail before core CLI execution.

6. **Counterargument: Store-safe builds can only guide, not apply.**
   Correct. The product message must remain benchmark/guidance first for Flatpak and Snap.

7. **Counterargument: Packaging recipes are not real store validation.**
   Valid. A unified script now builds and validates one Linux ELF payload and drives Flatpak Builder, Snapcraft, dpkg-deb, and rpmbuild. Structural tests cover recipe invariants, but the package tools and installed artifacts still need to run on Linux.

8. **Counterargument: Vietnamese coverage is not app-wide translation.**
   Partially valid. The Linux shell and GUI now support English/Vietnamese strings for primary native app labels/help, permission, guided settings, publish-check, and CLI surfaces. Remaining untranslated package-tool terms are intentionally kept copyable.

## Remaining Risks

- Real Flatpak/Snap/deb/rpm builds are not validated in this lane.
- Flathub still needs a public immutable source archive/tag and Cargo source
  manifest before store submission; local Flatpak QA uses staged ELF payloads.
- `dnspilot.io` homepage/support/privacy URLs do not currently resolve and must
  be hosted over HTTPS before package metadata is submitted.
- Native helper packaging/install paths and a command prototype exist, but the
  authorization/write design must be replaced before package QA or release enablement.
- Native GUI compiles in this lane, but real GNOME/Wayland rendering still needs Linux package QA.
- Distro-specific settings handoff text may need UX refinement after QA.

## Recommended Next Phase

1. Execute Milestones 0-2 in `linux-completion-plan.md` with TDD.
2. Complete the Store-safe consumer flow through Milestones 3-6.
3. Make package sources/release evidence honest in Milestones 8-9.
4. Keep Milestone 7 behind the approved commercial and real-host gates.
