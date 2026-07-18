# Global Progress

Last integration pass: 2026-07-18.

## Completed

- Merged macOS reference lane into `main`, including focused consumer UX, singleton
  window ownership, DNS-only Quick Check, game/service target presets, one primary
  result action, native commands, Power rollback, app icon, release assets, and safe
  support/privacy site generation.
- Core/CLI DNS samples now expose optional failure detail with Rust/CLI tests.
- Integrated committed Linux work through `d9ad771`, including package automation,
  settings flows, completion plan, provider steps, and lane risk documentation.
- Integrated committed Windows work through `ae94c97`, including the Store-safe
  baseline and selective-parity pre-development plan.
- Added Rust formatting to the macOS integration gate in `7209b70`.
- Re-ran macOS CI and Store/Power preflight successfully.
- Audited every worktree, restored the `core-cli` slot to branch `worktree/core-cli`,
  and preserved all dirty Windows/mobile work.
- Defined macOS-led product-contract parity in `PROJECT.md` and
  `docs/reference-lane-contract.md`.
- Preserved the uncommitted Windows overlay without staging or rewriting it.

## In Progress Outside `main`

- Linux: Store-safe milestones remain open; native execute is development-only until
  a fail-closed privilege boundary and exact rollback are proven.
- Windows: dirty Runtime Readiness remains outside `main`; later milestones remain
  queued in `apps/windows/windows-predevelopment-review.md`.
- Mobile: consumer work through `8dd1c26` is verified but remains isolated with the
  restricted entitlement history. The default Store slice has a separate release gate;
  no mobile worktree overlay is dirty.

## Deferred By Evidence

- Mobile commits based on restricted iOS entitlement are not merged into `main`.
- Linux native Power prototype is present in `main` for development history only and
  is explicitly not approved for release while rollback/privilege design is incomplete.
- Windows dirty work is not staged or merged until its owner commits and validation is
  reviewed.
- Shared `runtime-info --json` is not implemented until a second lane confirms the
  same contract need.

## Manual Gates

See `STATE.md` and `docs/os-provider-trust.md`. No signing, provider account, Store
submission, physical-device QA, or real privileged DNS mutation has been claimed.
