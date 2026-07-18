# DNSPilot Roadmap

Last reviewed: 2026-07-19.

## P0: Commercial Trust

- [x] Harden Core UDP response identity and DNS response validation per D8; added spoofed
  source, fresh-ID, wrong-question, and invalid response packet tests in `8a53a31`.
- [x] Make macOS Power Restore compare current DNS to the recorded applied state before
  mutation; legacy snapshots are hidden/cleared and 274 Swift tests pass in `e4d3ec6`.
- [ ] Capture macOS EN/VI, narrow-window, Dark Mode, keyboard, and VoiceOver evidence.
- [ ] Run five moderated users through Check -> Recommend -> Apply -> Retest.
- [ ] Complete Apple signing/provisioning, hosted support/privacy, signed screenshots,
  App Store Connect metadata, and submission.

## P1: Shared Core

- [x] Make snapshot mutations transaction-safe across concurrent CLI processes per D9
  with `BEGIN IMMEDIATE` and a two-writer regression test in `8a53a31`.
- [x] Preserve locale-neutral `primary_issue` IDs in benchmark contracts (for example,
  `all-resolvers-failed` and `partial-failure`).
- [ ] Continue locale-neutral detail IDs. Recommendation Gate IDs and `gate_note_ids`
  summaries are complete in `86f314b`, Capability Matrix IDs in `d6df518`, and Preflight/
  Apply Prompt Policy IDs in `015a2aa`; extend this additive contract to apply-plan,
  profile-security, and
  connection-path caveats before any shell removes raw Details fallback. Do not duplicate
  `primary_issue`.
- [x] Complete progress JSONL v1 lifecycle in `cb70daf`: every event carries
  `schema_version` and `run_id`; runs end with `run_finished` or `run_cancelled` plus
  stable failure kinds. `SIGINT` exits 130 after the active resolver and never writes
  partial benchmark history.
- [ ] Do not add platform settings URIs, distro detection, or privileged helpers to Core.
- [ ] Add `runtime-info --json` only after a second lane proves the same contract need.

## P1: Mobile Integration

- [x] Update the Expo 57 patch set and pass `npm run verify` (98 tests, typecheck,
  config/export, dependency compatibility, audit threshold) in `e24e893`.
- [x] Bind the dev bridge to loopback by default; LAN mode now needs a per-run token and
  origin allowlist, uses an app-owned database, redacts health/errors, and bounds/cancels jobs.
- [x] Disable Android backup and exclude iOS Application Support data from backup.
- [x] Simplify mobile first-run UI: hide empty Process/Result sections and keep advanced
  detail progressive.
- [x] Build Android Release AAB and pass its manifest/dex release gates; mobile source
  is merged in `234a2e0`.
- [x] Capture iOS Simulator Release exit evidence: `xcodebuild ... -configuration Release
  -sdk iphonesimulator ... CODE_SIGNING_ALLOWED=NO` reports `BUILD SUCCEEDED`.
  Signed physical-device QA and store release remain manual gates.
- [x] Integrate mobile source in `234a2e0`; treat Expo web as dev/router QA only and keep
  the `production-ios-dns` artifact blocked by provider/device evidence.

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
- `docs/reference-lane-contract.md`
- `docs/core-cli-backlog.md`
- `docs/os-provider-trust.md`
