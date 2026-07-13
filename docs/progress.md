# Global Progress

Last integration pass: 2026-07-13.

## Completed

- Merged macOS reference lane into `main`, including focused consumer UX, singleton
  window ownership, DNS-only Quick Check, game/service target presets, one primary
  result action, native commands, Power rollback, app icon, release assets, and safe
  support/privacy site generation.
- Core/CLI DNS samples now expose optional failure detail with Rust/CLI tests.
- Re-ran macOS CI and Store/Power preflight successfully.
- Audited every worktree, restored the `core-cli` slot to branch `worktree/core-cli`,
  and preserved all dirty Windows/mobile work.
- Defined macOS-led product-contract parity in `PROJECT.md` and
  `docs/reference-lane-contract.md`.
- Routed Linux, Windows, and mobile engineer lanes to continue until only real
  provider/device/manual release gates remain.

## In Progress Outside `main`

- Linux: fail-close unsafe native execute first, then typed Core adapter, streaming
  progress/cancellation, consumer IA/results/data/accessibility/package evidence.
- Windows: finish dirty Runtime Readiness, then consumer IA, cancellation, result/apply
  hierarchy, preferences/diagnostics, and Windows QA artifacts.
- Mobile: finish Profiles/History consumer routes, remove startup permission UX, and
  make unresolved Expo Router routes fail verification.

## Deferred By Evidence

- Mobile commits based on restricted iOS entitlement are not merged into `main`.
- Linux native Power is not merged while exact rollback/privilege design is incomplete.
- Windows dirty work is not staged or merged until its owner commits and validation is
  reviewed.
- Shared `runtime-info --json` is not implemented until a second lane confirms the
  same contract need.

## Manual Gates

See `STATE.md` and `docs/os-provider-trust.md`. No signing, provider account, Store
submission, physical-device QA, or real privileged DNS mutation has been claimed.
