# Platform Summary

Last integration pass: 2026-07-14.

## Integration State

| Lane | Integrated in `main` | Isolated work | Catch-up status |
| --- | --- | --- | --- |
| Core CLI | Current through the macOS reference merge | No separate Core commit pending | Shared message/progress hardening remains P1 |
| macOS | Through `7209b70` | Localization/interaction plan pending | Behavior gates pass; commercial UI consistency reopened |
| Linux | Through `d9ad771` via `3daca3d` | No committed delta | Git-integrated; Store-safe completion and fail-closed Power gate remain open |
| Windows | Through `ae94c97` via `8b441b5` | Dirty Runtime Readiness vertical slice | Git-integrated through committed head; milestones 0-4 remain open |
| Mobile | Safe baseline only | `345c41e`..`3d1a34f` plus dirty tutorial work | Kept isolated by approved entitlement decision D1 |
| Docs | Current integration state | Lane-local dirty docs are not copied | Sync after this docs commit |

`main` is the only cross-lane source of truth. Branch-ahead work is evidence only after
review, lane validation, merge, and merged-result validation.

## Product Reference

macOS defines the store-safe product journey, not the platform implementation. Every
lane follows `docs/reference-lane-contract.md` and adapts settings, packaging,
privileges, and provider gates honestly.

## Current Proof

- macOS: 265 Swift tests plus Rust workspace tests, bundle validation, live DNS-only
  and DNS+TCP smoke, Store/Power preflight, and release-site safety pass.
- macOS localization/interaction visual matrix is `NOT RUN`; partial localization and
  compact hit-target defects block the commercial UI gate.
- Linux pre-integration baseline: fmt/test/clippy pass. Real Linux package and
  privileged behavior remain `NOT RUN`; merged-result validation is rerun in this pass.
- Windows committed baseline: 40 Core/static tests pass. The dirty Runtime Readiness
  overlay passes 44 Core tests but is not integrated; WinUI/MSIX is `NOT RUN` on macOS.
- Mobile isolated committed branch: 86 tests, typecheck, route export, and default
  production entitlement checks pass. Signed physical-device QA is `NOT RUN`.

## Non-Negotiable Boundaries

- Default Store SKUs do not silently mutate DNS.
- Power/native mutation is separately packaged, consented, reversible, and validated
  on the real provider/OS before release.
- iOS `dns-settings` stays out of `main` and the default Store profile until Apple
  approval and signed-device evidence exist.
- Linux shell-command mutation present in the integrated prototype is not an approved
  production privilege mechanism and must not be released.
- Windows Store stays `asInvoker`; no UAC, service, registry, `netsh`, or DNS write.
- No proof/no claim: unavailable platform checks are `NOT RUN`, not inferred from mocks.
