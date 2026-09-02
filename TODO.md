# DNSPilot Roadmap

Last reviewed: 2026-09-03.

## P0: Guided Connection Check

- [ ] Validate the proposed information-architecture amendment in
  `docs/research/2026-08-24-product-value-usability-review.md`: one guided Home journey,
  direct Benchmark access, and secondary Profiles/History instead of four equal choices.
- [ ] Make the primary loop `Check my connection -> one plain-language outcome -> one
  safe next action -> Retest`. Keep evidence behind Info/Details without hiding current
  network scope, unsupported checks, permission impact, or rollback risk.
- [ ] On Mobile, make `Run quick check` the visually immediate default. Lead the result
  with a plain-language conclusion and one safe action or Retest; put targets, stages,
  timings, resolver samples, and diagnostic states behind an explicit Details disclosure.
  Compress first-run tutorial copy to three short titles, with optional Info detail.
- [ ] Define `Better`, `No meaningful change`, and `Restore previous DNS` comparison
  outcomes. Never claim DNS repaired bandwidth, Wi-Fi, router, ISP, VPN, or game latency.
- [ ] Prove the journey with five moderated normal users before changing the approved D3
  navigation contract or pricing around it.

## P0: Separate Network Health Check

- [ ] Complete and approve the design spec for a read-only Health Check that remains
  separate from DNS Benchmark while appearing first in the guided journey.
- [ ] Define a versioned Core contract for observations, health status, confidence,
  capability gaps, reason IDs, privacy boundaries, and manual recheck suggestions.
- [ ] Define the cross-platform capability matrix. Do not use router credentials,
  router-specific scraping, port scanning, privileged mutation, or claims that an
  unmanaged switch count can be observed remotely.
- [ ] Preserve DNS Benchmark as an independent feature with a user-selected resolver
  pool, separate A/IPv4 and AAAA/IPv6 results, and a 500 ms timeout ceiling per DNS
  attempt.
- [ ] Add synthetic design fixtures for local gateway failure, upstream degradation,
  DNS-only failure, IPv4/IPv6 mismatch, transient loss, and unsupported observations
  before approving implementation.
- [ ] Place donate/fund prompts only after useful product value or in Support/About;
  never gate safety guidance, recheck steps, or warning explanations behind payment.

## P0: Background Measurement Completion

- [ ] Implement D14 from
  `docs/superpowers/specs/2026-08-07-background-measurement-notifications-design.md`:
  one user-initiated read-only measurement, cancel support, persisted local receipt,
  terminal/interrupted handling, and no automatic retry.
- [x] macOS benchmark reference path: persist/recover lifecycle receipt, prevent concurrent
  shell-owned measurements, and never retry an interrupted run.
- [x] macOS contextual local notification opt-in: generic EN/VI completion copy, no alert
  while active, Settings control, and no push/provider capability. CI and release
  preflight reject remote push, schedulers, login items, and lifecycle DNS mutation.
- [ ] Add a contextual `Notify me when done` opt-in after a run starts. Never request
  notification permission in first-run tutorial or make it a run prerequisite.
- [ ] Use local notifications only. Show generic lock-screen copy, suppress completion
  alerts while the app is active, deep-link to the exact local result, and clear the
  notification after that result is viewed.
- [ ] Prove foreground -> background -> complete, denied permission, cancellation,
  process termination, stale receipt, deep-link, EN/VI, accessibility, and lock-screen
  privacy fixtures in each lane. Record unsupported/simulator-only cases as `NOT RUN`.
- [ ] Do not add a Core daemon, periodic scheduler, remote push provider, account,
  analytics event, background DNS mutation, or auto-retry to satisfy this milestone.

## P0: Commercial Trust

- [x] Provide a one-command macOS source-build path that installs and opens one
  canonical per-user app without Apple signing credentials; Store/Power signing
  contracts, guarded replacement, local bundle validation, and runtime smoke pass.
- [x] Harden Core UDP response identity and DNS response validation per D8; added spoofed
  source, fresh-ID, wrong-question, and invalid response packet tests in `8a53a31`.
- [x] Make macOS Power Restore compare current DNS to the recorded applied state before
  mutation; legacy snapshots are hidden/cleared and 274 Swift tests pass in `e4d3ec6`.
- [x] Capture packaged macOS EN/VI light-mode screenshots and native accessibility
  evidence. The smoke validates compact localized actions, rejects blank captures, and
  waits for the prior process to exit before relaunching.
- [ ] Capture signed macOS Dark Mode, narrow-window, keyboard, and VoiceOver evidence.
- [ ] Run five moderated users through Health Check -> DNS Benchmark -> Set up -> Retest.
- [ ] Complete Apple signing/provisioning, hosted support/privacy, signed screenshots,
  App Store Connect metadata, and submission.
- [ ] Restore the Rust 1.96 quality gate: fix three `manual_is_multiple_of` findings and
  refactor or explicitly justify the nine-argument `apply_plan`; do not lower clippy.
- [ ] Align Mobile to the Expo SDK 57 compatible patch set reported by `expo install
  --check`, then rerun `npm run verify` and `npm run preflight:release` serially.
- [x] Re-review the macOS D14 candidate after exact-result notification activation, OS
  permission reconciliation, scheduling diagnostics, installer rollback, and real visual
  smoke pass. Real OS notification delivery and privileged DNS mutation remain manual
  evidence, not automated release claims.

## P1: Shared Core

- [x] Make snapshot mutations transaction-safe across concurrent CLI processes per D9
  with `BEGIN IMMEDIATE` and a two-writer regression test in `8a53a31`.
- [x] Preserve locale-neutral `primary_issue` IDs in benchmark contracts (for example,
  `all-resolvers-failed` and `partial-failure`).
- [ ] Continue locale-neutral detail IDs. Recommendation Gate IDs and `gate_note_ids`
  summaries are complete in `86f314b`, Capability Matrix IDs in `d6df518`, Preflight/Apply
  Prompt Policy IDs in `015a2aa`, exhaustive Apply Plan IDs in `bb51067`, profile security in
  `5b008fc`, and connection-path caveats in `8360ba7`. Migrate recommendation reasons/caveats
  and history metadata before any shell removes raw Details fallback. Do not duplicate
  `primary_issue`.
- [x] Complete progress JSONL v1 lifecycle in `cb70daf`: every event carries
  `schema_version` and `run_id`; runs end with `run_finished` or `run_cancelled` plus
  stable failure kinds. `SIGINT` exits 130 after the active resolver and never writes
  partial benchmark history.
- [ ] Do not add platform settings URIs, task schedulers, notification APIs, distro
  detection, or privileged helpers to Core.
- [ ] Add `runtime-info --json` only after a second lane proves the same contract need.

## P1: Mobile Integration

- [x] Update the Expo 57 patch set and pass `npm run verify` (106 tests, typecheck,
  config/export, dependency compatibility, Router warning gate, and fail-closed audit policy)
  in integrated mobile candidate `6190635`.
- [x] Bind the dev bridge to loopback by default; LAN mode now needs a per-run token and
  origin allowlist, uses an app-owned database, redacts health/errors, and bounds/cancels jobs.
- [x] Disable Android backup and exclude iOS Application Support data from backup.
- [x] Simplify mobile first-run UI: hide empty Process/Result sections and keep advanced
  detail progressive.
- [x] Build local Android release-shape AAB/APK and pass manifest/dex release gates;
  mobile source is integrated in `6190635`. These local debug-key artifacts are QA-only;
  Play needs EAS remote signing.
- [x] Capture iOS Simulator Release exit evidence: `xcodebuild ... -configuration Release
  -sdk iphonesimulator ... CODE_SIGNING_ALLOWED=NO` reports `BUILD SUCCEEDED`.
  Signed physical-device QA and store release remain manual gates.
- [x] Integrate the refreshed mobile source in `6190635`; Expo web remains dev/router QA
  only, local Android artifacts remain QA-only, and `production-ios-dns` stays blocked by
  provider/device evidence.

## P1: Platform Evidence

- [ ] Linux: finish accessibility/desktop-fit Milestone 6 and source-built package,
  publisher, CI, and evidence Milestones 8-9. Keep Milestone 7 Power fail-closed.
- [ ] Windows: run Release validator, WinUI/MSIX/tray, EN/VI wrapping, keyboard,
  Narrator, high-contrast, VPN/firewall, clean install/upgrade on Windows.
- [ ] macOS Power: run disposable-network Apply -> Validate -> Restore. Do not block
  Store-safe release on Power.
- [ ] Retain one durable visual/accessibility evidence matrix per platform; record
  unavailable checks as `NOT RUN`.

## P2: Product Learning

- [ ] Measure first-run completion, successful benchmark, recommendation confidence,
  Settings handoff, and System DNS retest locally/privately before adding accounts.
- [ ] Decide pricing and Power SKU only after macOS usability and release evidence.

## References

- `PROJECT.md`
- `STATE.md`
- `docs/research/2026-07-19-overall-product-review.md`
- `docs/research/2026-08-24-product-value-usability-review.md`
- `docs/reference-lane-contract.md`
- `docs/core-cli-backlog.md`
- `docs/os-provider-trust.md`
