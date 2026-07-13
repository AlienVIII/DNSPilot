# Platform Summary

Last integration pass: 2026-07-13.

## Integration State

| Lane | Integrated in `main` | Isolated work | Catch-up status |
| --- | --- | --- | --- |
| Core CLI | Current through macOS reference merge | No separate Core commit pending | Current contract is sufficient; shared message/progress hardening remains P1 |
| macOS | `13d3f35` via `Merge macOS reference lane` | None | Reference lane; automated Store-safe scope complete |
| Linux | Baseline through `8cf4502` | `510867e`..`d9ad771` plus active completion work | Not caught up; Store-safe milestones and fail-closed Power gate open |
| Windows | Baseline through `8cf4502` | `bad68e1`, `ae94c97`, and dirty Runtime Readiness work | Not caught up; consumer UX/readiness/cancellation work open |
| Mobile | Safe baseline only | `345c41e`..current plus active consumer work | Not integrated; restricted entitlement and consumer route work remain isolated |
| Docs | Baseline through previous main | This integration update | Fast-forward after docs commit |

`main` is the only cross-lane source of truth. Branch-ahead work is evidence only after
review, lane validation, merge, and merged-result validation.

## Product Reference

macOS defines the store-safe product journey, not the platform implementation. Every
lane follows `docs/reference-lane-contract.md` and adapts settings, packaging,
privileges, and provider gates honestly.

## Current Proof

- macOS: 265 Swift tests plus Rust workspace tests, bundle validation, live DNS-only
  and DNS+TCP smoke, Store/Power preflight, and release-site safety pass.
- Linux isolated baseline: fmt/test/clippy pass. Real Linux package and privileged
  behavior remain `NOT RUN`.
- Windows isolated dirty baseline: 44 Core tests pass. WinUI/MSIX is `NOT RUN` on the
  macOS host.
- Mobile isolated dirty baseline: 81 tests and typecheck pass, but export found an
  unresolved `profiles` route; the engineer lane is fixing the false-green gate.

## Non-Negotiable Boundaries

- Default Store SKUs do not silently mutate DNS.
- Power/native mutation is separately packaged, consented, reversible, and validated
  on the real provider/OS before release.
- iOS `dns-settings` stays out of `main` and the default Store profile until Apple
  approval and signed-device evidence exist.
- Linux shell-command mutation is not a production privilege mechanism.
- Windows Store stays `asInvoker`; no UAC, service, registry, `netsh`, or DNS write.
- No proof/no claim: unavailable platform checks are `NOT RUN`, not inferred from mocks.
