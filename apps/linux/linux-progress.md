# Linux Progress

## Completed
- Created `apps/linux/DNSPilotLinux`, an isolated Rust Linux shell package.
- Added capability matrix view-models for Flatpak, Snap, deb, and rpm.
- Added benchmark mode gating for DNS only, DNS + TCP, and current/system resolver validation.
- Added process UI state models for idle/running/success/failed per step and resolver.
- Added copyable debug report rendering.
- Added custom plain DNS profile add/edit/delete/list validation.
- Added IPv4/IPv6 resolver controls and A/AAAA record-family controls with help text.
- Added store-safe guided settings actions and native power package plan.
- Added default suites with Vietnam daily gated by catalog support.
- Added CLI validation harness with mocked capability inputs and no DNS mutation.
- Added core CLI runner boundary for `compare`, `path-compare`, and `system-benchmark`.
- Added Linux app/session workflow for mode/profile/suite/domain readiness and benchmark plan construction.
- Added file-backed custom profile repository with schema versioning.
- Added CLI product commands for profile add/list/delete, benchmark plan generation, executable run, and guided apply/native-plan output.
- Added non-mutating Linux capability auto-detection plus mocked snapshot detection for deterministic QA.
- Added self-review and counterargument summary in `linux-self-review.md`.

## Current Work
- Linux lane UX/spec/code is implemented for scoped benchmark, profile, diagnostics, guidance, and native-power planning behavior.

## Blockers
- No blocker for scoped code-complete lane.
- Real package verification still requires later distro/package QA.

## Next Actions
- Wire a native GUI shell to the Linux app/session package when GTK/libadwaita or Qt is selected.
- Later QA: Flatpak, Snap, deb, and rpm package-specific verification.
- Use `linux-self-review.md` as the current critique/risk summary before starting GUI/native-helper work.
