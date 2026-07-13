# Linux Consumer Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for
> behavior changes and commit each verified task independently.

**Goal:** Finish the Linux Store-safe consumer app and leave Native Power behind an
honest, separately verified capability boundary.

**Architecture:** Keep the packaged `dnspilot-cli` as the sole product/runtime contract.
Add a typed Linux adapter, streaming child supervisor, core-backed XDG SQLite storage,
and focused eframe UI. Replace the native command prototype only after the commercial
Power gate permits a real system D-Bus/polkit mechanism.

**Tech stack:** Rust 2021, eframe/egui 0.35, serde/serde_json, shared `dnspilot-cli`,
SQLite through CLI contracts, Linux D-Bus/polkit only in the separately gated Power
task.

Design and acceptance source: `apps/linux/linux-completion-plan.md`.

---

## File Map

Create during Store-safe completion:

- `apps/linux/DNSPilotLinux/src/paths.rs`: XDG data/state paths and legacy JSON path.
- `apps/linux/DNSPilotLinux/src/core_contract.rs`: versioned catalog, storage, result,
  history, policy, and apply-plan payload decoders.
- `apps/linux/DNSPilotLinux/src/core_client.rs`: typed CLI command construction and
  non-benchmark request execution.
- `apps/linux/DNSPilotLinux/src/migration.rs`: idempotent JSON-to-core SQLite profile
  migration with backup.
- `apps/linux/DNSPilotLinux/src/result.rs`: decision-quality result view models.
- `apps/linux/DNSPilotLinux/src/preferences.rs`: persisted System/EN/VI and setup state.
- `apps/linux/DNSPilotLinux/src/gui/mod.rs`: shared GUI state/navigation boundary.
- `apps/linux/DNSPilotLinux/src/gui/check_dns.rs`: setup, options, live run, result.
- `apps/linux/DNSPilotLinux/src/gui/profiles.rs`: built-in/custom profile management.
- `apps/linux/DNSPilotLinux/src/gui/history.rs`: history list/rerun/delete/clear.
- `apps/linux/DNSPilotLinux/src/gui/settings.rs`: locale and package capability settings.
- `apps/linux/DNSPilotLinux/src/gui/help.rs`: optional setup and support/about surfaces.
- `apps/linux/DNSPilotLinux/src/gui/components.rs`: status, option, error, and report UI.
- `apps/linux/scripts/ci.sh`: complete Linux-owned automated gate.
- `apps/linux/scripts/validate-release-metadata.sh`: one-version and metadata contract.
- `apps/linux/scripts/package-smoke.sh`: non-mutating installed-package smoke commands.
- `apps/linux/packaging/flatpak/io.dnspilot.DNSPilot.Source.yml`: Flathub source build.
- `apps/linux/packaging/flatpak/cargo-sources.json`: generated locked Cargo sources.
- Focused tests named below.

Retire after migration is proved:

- `apps/linux/DNSPilotLinux/src/storage.rs`: Linux-only JSON storage.
- Hardcoded built-in data in `apps/linux/DNSPilotLinux/src/suites.rs` and
  `apps/linux/DNSPilotLinux/src/gui_main.rs`.

Create only when Native Power is authorized by `PROJECT.md` D2:

- `apps/linux/DNSPilotLinux/src/native_service.rs`: narrow system D-Bus API.
- `apps/linux/DNSPilotLinux/src/native_authorization.rs`: caller-bound polkit check.
- `apps/linux/DNSPilotLinux/src/native_snapshot.rs`: exact, root-owned rollback record.
- `apps/linux/DNSPilotLinux/src/native_network_manager.rs`: NetworkManager D-Bus path.
- `apps/linux/DNSPilotLinux/src/native_resolved.rs`: systemd-resolved D-Bus fallback.
- `apps/linux/packaging/dbus/io.dnspilot.DNSPilot.Native1.service`.
- `apps/linux/packaging/systemd/dnspilot-native.service`.

## Task 0: Make Native Execute Fail Closed

**Files:** `Cargo.toml`, `src/native_power.rs`, `src/native_helper_main.rs`,
`tests/native_helper_protocol_behaviour.rs`, `tests/packaging_policy_behaviour.rs`,
`scripts/build-packages.sh`, deb/rpm recipes.

- [ ] Add a failing test proving a default build rejects every execute request before
  `snapshot_existing_dns`, `authorize`, or command execution.
- [ ] Add a failing package test proving default deb/rpm payloads do not install the
  helper or polkit action as a production capability.
- [ ] Add an explicit `ExecuteUnavailable` error and keep contract/dry-run inspection.
- [ ] Remove production D-Bus wording from command-backed code and output.
- [ ] Run targeted native/package tests, then full Linux fmt/test/clippy.
- [ ] Update progress/readiness/publish output and commit:
  `Harden Linux native power boundary`.

## Task 1: Introduce Typed CLI Contracts And XDG Paths

**Files:** create `paths.rs`, `core_contract.rs`, `core_client.rs`; modify `lib.rs`,
`Cargo.toml`; create `tests/core_contract_behaviour.rs` and
`tests/core_client_behaviour.rs`.

- [ ] Add RED fixtures for schema 1 catalog, profile list, suite list, history list,
  compare/path-compare/system result, policy, and apply-plan payloads.
- [ ] Add RED tests for unsupported schema, malformed JSON, nonzero CLI exit, missing
  executable, and invalid UTF-8 lossy diagnostic handling.
- [ ] Add `serde = { version = "1", features = ["derive"] }`; keep versions locked.
- [ ] Implement one `CoreClient` that accepts executable + DB path and returns typed
  results. Do not expose raw `Command` construction to GUI modules.
- [ ] Implement XDG data/state paths with deterministic test overrides.
- [ ] Run core adapter tests plus `cargo test -p dnspilot-cli`; commit:
  `Use typed Linux core contracts`.

## Task 2: Migrate To Shared SQLite Storage

**Files:** create `migration.rs`, `tests/profile_migration_behaviour.rs`; modify
`app.rs`, `profiles.rs`, `suites.rs`, `gui_main.rs`; retire `storage.rs` only after GREEN.

- [ ] RED: first launch imports valid legacy custom profiles through CLI `profile-add`,
  writes a `.migrated` marker, and retains a read-only `.bak`.
- [ ] RED: second launch is idempotent; built-in ID conflicts do not overwrite core
  data; malformed legacy data is preserved and reported, not deleted.
- [ ] Load catalog, custom profiles, suites, and history from `CoreClient`.
- [ ] Remove seeded Cloudflare/Quad9 and hardcoded suite domains.
- [ ] Pass the same DB path as profile/suite input and benchmark history output.
- [ ] Run migration/storage/CLI tests; commit: `Unify Linux local data with core`.

## Task 3: Stream Progress And Cancel Correctly

**Files:** replace internals of `worker.rs` and `benchmark.rs`; modify `process.rs`;
expand `tests/benchmark_worker_behaviour.rs` and `benchmark_runner_behaviour.rs`.

- [ ] RED: progress is observable before process completion.
- [ ] RED: cancel kills and waits for the child, returns a localized cancellation detail,
  and leaves no running/idle active rows.
- [ ] RED: large stdout/stderr cannot deadlock; invalid JSONL is retained in diagnostics;
  disconnect and spawn failure end every row.
- [ ] Replace `Command::output()` with piped `spawn`, dedicated stdout/stderr readers,
  event/control channels, `try_wait`, `kill`, and mandatory `wait`.
- [ ] Keep statuses idle/running/success/failed; cancellation is failed with a specific
  reason so the original process-state contract remains stable.
- [ ] Include `--save-db` and unique `--history-id` in every successful run plan.
- [ ] Run worker/process tests and full gate; commit:
  `Stream and cancel Linux benchmarks`.

## Task 4: Decode Results Into A Decision Model

**Files:** create `result.rs`, `tests/result_behaviour.rs`; modify `diagnostics.rs`,
`benchmark.rs`, `app.rs`.

- [ ] RED fixtures cover recommended, fastest-only, keep-current, low-confidence,
  partial resolver failure, total failure, system DNS, DNS-only, and DNS+TCP results.
- [ ] Model recommendation separately from fastest observed and include gate reasons,
  failure counts, DNS metrics, TCP metrics, and report context.
- [ ] Build one primary action enum: `ApplyGuidance`, `PowerApply`, `RetestSystemDns`,
  or `None`.
- [ ] Redact home paths and private custom domains by default in copied reports; expose
  an explicit include-private-details toggle.
- [ ] Run result/diagnostic tests; commit: `Add Linux decision-quality results`.

## Task 5: Restructure The Consumer Shell

**Files:** create `src/gui/**`; reduce `gui_main.rs` to startup/window wiring; modify
`native_app.rs`, `i18n.rs`; create `tests/gui_navigation_behaviour.rs` and
`tests/preferences_behaviour.rs`.

- [ ] RED: navigation contains exactly Check DNS, Profiles, History.
- [ ] RED: first launch setup is not marked complete merely by appearing; Skip/Done
  persist; Help reopens setup.
- [ ] RED: Quick Check selects DNS-only; advanced options preserve DNS+TCP/System DNS,
  family, records, attempts, profiles, suites, and custom domains.
- [ ] RED: System locale resolves vi/en, unsupported locale falls back to English, and
  manual selection persists.
- [ ] Extract focused GUI modules without changing benchmark contracts.
- [ ] Keep capability/permissions/diagnostics in Settings, Help, result Details, or
  errors, not primary navigation.
- [ ] Run navigation/preferences/i18n/full tests; commit:
  `Focus Linux consumer navigation`.

## Task 6: Complete Profiles, Suites, History, Apply, And Retest

**Files:** `gui/profiles.rs`, `gui/history.rs`, `gui/check_dns.rs`, `gui/components.rs`,
`core_client.rs`, `settings.rs`; create `tests/consumer_workflow_behaviour.rs`.

- [ ] RED: built-ins cannot be edited/deleted; custom profiles and suites support
  add/edit/delete using core validation and preserve selection safely.
- [ ] RED: history is newest-first; rerun restores inputs; delete/clear requires
  confirmation and updates empty state.
- [ ] RED: Default/Vietnam picks exist only when returned by catalog.
- [ ] RED: Store apply uses core policy/apply-plan, copies family-filtered values, shows
  guidance, never executes a DNS command, and offers System DNS retest only when
  capability-supported.
- [ ] RED: VPN/managed/captive signals suppress Apply and explain keep-current safety.
- [ ] Implement one visible primary result action and secondary Details/report actions.
- [ ] Run workflow/full tests; commit: `Complete Linux consumer workflows`.

## Task 7: Accessibility And Desktop Fit

**Files:** `gui/components.rs`, all GUI feature modules, `i18n.rs`,
`tests/accessibility_model_behaviour.rs`.

- [ ] Add semantic labels/state for controls, status text that does not depend on color,
  visible focus, keyboard activation, dialog focus restoration, and clipboard errors.
- [ ] Add deterministic layout model tests for minimum and wide content widths; long EN
  and VI labels must wrap without changing fixed control dimensions.
- [ ] Add a localization key coverage test for every user-facing view-model string.
- [ ] Document GNOME/Wayland, KDE/Wayland, X11, screen reader, IME, and clipboard checks
  as `NOT RUN` until a Linux host is available.
- [ ] Run full gate; commit: `Harden Linux accessibility and desktop UX`.

## Task 8: Make Packages Submission-Ready

**Files:** create release scripts/Flatpak source manifest above; modify all package
recipes, AppStream/desktop metadata, README, publish checklist, package tests.

- [ ] RED package tests prove Store packages contain no native helper/polkit/system-bus
  access and native packages do not claim Power readiness by default.
- [ ] RED metadata test fails any version/date mismatch across Cargo, Snap, deb, rpm,
  AppStream, artifact names, and changelog.
- [ ] Generate a Flathub manifest from public immutable source + locked Cargo sources;
  retain the ELF manifest with an explicit `.local-qa` name only.
- [ ] Make Snap build from pinned source inputs. Build deb/rpm payload ownership
  explicitly; no parity wording.
- [ ] Validate AppStream translations, icon, screenshots, URLs, desktop launch, license,
  checksums, install/uninstall, and non-mutating smoke.
- [ ] Add `apps/linux/scripts/ci.sh` and a concise request for main to call it from a
  Linux CI workflow without editing `.github/**` in this lane.
- [ ] Run all host-available package checks; mark unavailable tools `NOT RUN`; commit:
  `Prepare Linux packages for publisher QA`.

## Task 9: Implement Native Power Only After Gate Approval

**Files:** gated Native Power files listed in File Map, `Cargo.toml`, native package
recipes, polkit policy, tests, risks, publish checklist.

- [ ] RED mocked D-Bus tests prove unique caller identity, caller-bound polkit denial,
  literal IP/request-size validation, active configuration version checks, exact
  snapshot fields, stale snapshot rejection, and root-only snapshot permissions.
- [ ] RED NetworkManager tests cover GetAppliedConnection, DNS fields for IPv4/IPv6,
  `ignore-auto-dns`, version-guarded apply, validation, explicit restore, and automatic
  restore after each failure stage.
- [ ] RED resolved tests cover link ownership, DNS/DNSEx/domains/default-route capture,
  SetLinkDNS, validation, exact restore/RevertLink policy, and LinkBusy refusal.
- [ ] Expose a narrow system D-Bus API; the privileged mechanism authorizes the unique
  bus caller with polkit. Do not use `pkcheck --process <bare-pid>`.
- [ ] Keep the GUI and Store packages unable to install/contact the service.
- [ ] Pass mocked tests and package contract checks. Mark real Apply -> Validate ->
  Restore `NOT RUN` until disposable-device QA; commit:
  `Add gated Linux native power service`.

## Final Automated Gate

```sh
apps/linux/scripts/ci.sh
cargo test -p dnspilot-cli
apps/linux/scripts/validate-release-metadata.sh
bash -n apps/linux/scripts/*.sh
git diff --check
```

On a Linux package executor, additionally run:

```sh
apps/linux/scripts/build-packages.sh all
apps/linux/scripts/package-smoke.sh all
```

Final reporting must separate Store-safe code-complete, Native Power code-complete, and
release-ready. No signed/store/real-device claim is allowed without its artifact and
manual evidence.
