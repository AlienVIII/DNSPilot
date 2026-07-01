# Linux Self Review

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
| Process UI: idle/running/success/failed per step/resolver | Covered | `process.rs`, diagnostics tests |
| Result diagnostics and copyable debug report | Covered | `diagnostics.rs`, CLI/report tests |
| Guided settings only for store/sandbox builds | Covered | settings/guide tests |
| Native power path plan | Covered as helper contract plus explicit mutation gate/backend | `settings.rs`, `native_power.rs`, `native_helper_main.rs`, `guide` CLI, `apply-plan` CLI |
| Tray optional | Covered as invariant | capability/report output and native app model say tray optional |
| Custom DNS profile add/edit/delete | Covered | in-memory store plus file-backed CLI commands |
| IPv4/IPv6 and A/AAAA controls | Covered | settings/app/session tests |
| Vietnam/default suites | Covered | suite catalog tests |
| Capability detection without real DNS mutation | Covered | detector snapshot/runtime path, CLI `detect` |
| Native app permission model | Covered as GUI/view-model/CLI | `gui_main.rs`, `permissions.rs`, `native_app.rs`, CLI `permissions`, CLI `app-model` |
| English/Vietnamese localization | Covered for Linux shell/native app/publish surfaces | `i18n.rs`, `native_app.rs`, `publish.rs`, i18n behavior tests |
| Packaging/publish readiness | Covered as policy templates/checklist | `packaging/**`, packaging policy tests, `linux-publish-checklist.md` |

## Counterarguments And Resolution

1. **Counterargument: A CLI harness is not a finished Linux GUI.**
   Resolved for this lane. `dnspilot-linux-gui` is now the desktop launcher, uses the existing app/session, storage, runner, diagnostics, permission, and localization modules, and does not depend on tray integration. Final Linux package QA still has to validate the window on GNOME/Wayland.

2. **Counterargument: Capability detection can be wrong on some distros.**
   Valid. Detection is intentionally conservative and non-mutating. It checks sandbox markers, resolver-stack tools, paths, and polkit availability. Later distro QA must validate real packaging behavior.

3. **Counterargument: deb/rpm without resolver stack gets diagnostics-only, not guided settings.**
   Intentional. Guided settings are reserved for store/sandbox builds. Native packages without NetworkManager/systemd-resolved plus polkit should not pretend to have an apply path.

4. **Counterargument: Real DNS apply is too risky without Linux QA.**
   Resolved for code scope. Real DNS apply remains native-power only and now has a command backend behind `confirm_system_dns_mutation` plus `--allow-system-dns-mutation`, with polkit, snapshot, write, flush, validation, and rollback sequencing. Linux package QA still has to validate it on real NetworkManager/systemd-resolved hosts before release.

5. **Counterargument: Current/system resolver validation is not universally available.**
   Valid. It remains capability-gated. Unsupported mode requests fail before core CLI execution.

6. **Counterargument: Store-safe builds can only guide, not apply.**
   Correct. The product message must remain benchmark/guidance first for Flatpak and Snap.

7. **Counterargument: Packaging templates are not real store validation.**
   Valid. The tests assert policy invariants and file presence, but Flatpak Builder, appstreamcli, desktop-file-validate, snapcraft, debuild, and rpmbuild still need to run on Linux.

8. **Counterargument: Vietnamese coverage is not app-wide translation.**
   Partially valid. The Linux shell and GUI now support English/Vietnamese strings for primary native app labels/help, permission, guided settings, publish-check, and CLI surfaces. Remaining untranslated package-tool terms are intentionally kept copyable.

## Remaining Risks

- Real Flatpak/Snap/deb/rpm builds are not validated in this lane.
- Native helper packaging/install paths and command backend exist, but real helper authorization/write execution still needs Linux package QA before enabling mutation by default.
- Native GUI compiles in this lane, but real GNOME/Wayland rendering still needs Linux package QA.
- Distro-specific settings handoff text may need UX refinement after QA.

## Recommended Next Phase

1. Run package-level QA fixtures for Flatpak, Snap, deb, and rpm.
2. Validate the GUI on GNOME/Wayland and common X11 fallback sessions.
3. Collect screenshots, release notes, signing credentials, and store metadata for submission.
