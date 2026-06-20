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
| Native power path plan | Covered as helper contract, not mutation | `settings.rs`, `native_power.rs`, `guide` CLI, `apply-plan` CLI |
| Tray optional | Covered as invariant | capability/report output and native app model say tray optional |
| Custom DNS profile add/edit/delete | Covered | in-memory store plus file-backed CLI commands |
| IPv4/IPv6 and A/AAAA controls | Covered | settings/app/session tests |
| Vietnam/default suites | Covered | suite catalog tests |
| Capability detection without real DNS mutation | Covered | detector snapshot/runtime path, CLI `detect` |
| Native app permission model | Covered as view-model/CLI | `permissions.rs`, `native_app.rs`, CLI `permissions`, CLI `app-model` |
| English/Vietnamese localization | Covered for Linux shell surface | `i18n.rs`, i18n behavior tests |
| Packaging/publish readiness | Covered as policy templates/checklist | `packaging/**`, packaging policy tests, `linux-publish-checklist.md` |

## Counterarguments And Resolution

1. **Counterargument: A CLI harness is not a finished Linux GUI.**  
   Valid. The lane now has product-grade app/session models, localized native app view-models, persistence, runner boundary, desktop metadata, and CLI surfaces, but no GTK/libadwaita or Qt rendering adapter. This remains the largest product gap before a real end-user GUI can be called complete.

2. **Counterargument: Capability detection can be wrong on some distros.**  
   Valid. Detection is intentionally conservative and non-mutating. It checks sandbox markers, resolver-stack tools, paths, and polkit availability. Later distro QA must validate real packaging behavior.

3. **Counterargument: deb/rpm without resolver stack gets diagnostics-only, not guided settings.**  
   Intentional. Guided settings are reserved for store/sandbox builds. Native packages without NetworkManager/systemd-resolved plus polkit should not pretend to have an apply path.

4. **Counterargument: Real DNS apply is still not implemented.**  
   Valid and intentional. Real DNS apply belongs to a native power package with NetworkManager D-Bus, systemd-resolved, and polkit. Current lane includes the helper contract, resolver-stack selection, polkit action id, rollback/validation steps, and safeguards, not privileged writes.

5. **Counterargument: Current/system resolver validation is not universally available.**  
   Valid. It remains capability-gated. Unsupported mode requests fail before core CLI execution.

6. **Counterargument: Store-safe builds can only guide, not apply.**  
   Correct. The product message must remain benchmark/guidance first for Flatpak and Snap.

7. **Counterargument: Packaging templates are not real store validation.**  
   Valid. The tests assert policy invariants and file presence, but Flatpak Builder, appstreamcli, desktop-file-validate, snapcraft, debuild, and rpmbuild still need to run on Linux.

8. **Counterargument: Vietnamese coverage is not app-wide translation.**  
   Partially valid. The Linux shell now supports English/Vietnamese strings for primary native app, permission, and CLI surfaces. Full GUI copy coverage should expand when the GTK/Qt adapter lands.

## Remaining Risks

- Real Flatpak/Snap/deb/rpm builds are not validated in this lane.
- NetworkManager D-Bus and systemd-resolved write execution is not implemented.
- Polkit helper signing/install/authorization flow is not implemented.
- Native GUI stack/rendering adapter remains undecided.
- Distro-specific settings handoff text may need UX refinement after QA.

## Recommended Next Phase

1. Select Linux native UI stack: GTK/libadwaita or Qt.
2. Bind the UI to the existing app/session, storage, runner, diagnostics, and guide modules.
3. Implement native power helper execution behind explicit deb/rpm packaging.
4. Add package-level QA fixtures for Flatpak, Snap, deb, and rpm.
