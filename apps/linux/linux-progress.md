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

## Current Work
- Linux lane UX/spec/code is implemented for scoped store-safe and native-power planning behavior.

## Blockers
- No blocker for scoped code-complete lane.
- Real package verification still requires later distro/package QA.

## Next Actions
- Wire the Linux shell view-model package to the shared core CLI payloads when Linux core contracts are available.
- Later QA: Flatpak, Snap, deb, and rpm package-specific verification.
