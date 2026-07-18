# DNSPilot Roadmap

Last reviewed: 2026-07-19.

## P0: Commercial Trust

- [x] Harden Core UDP response identity and DNS response validation per D8; added spoofed
  source, fresh-ID, wrong-question, and invalid response packet tests in `8a53a31`.
- [ ] Capture macOS EN/VI, narrow-window, Dark Mode, keyboard, and VoiceOver evidence.
- [ ] Run five moderated users through Check -> Recommend -> Apply -> Retest.
- [ ] Complete Apple signing/provisioning, hosted support/privacy, signed screenshots,
  App Store Connect metadata, and submission.

## P1: Shared Core

- [x] Make snapshot mutations transaction-safe across concurrent CLI processes per D9
  with `BEGIN IMMEDIATE` and a two-writer regression test in `8a53a31`.
- [ ] Add locale-neutral issue/message IDs; keep raw technical text only in Details.
- [ ] Version the progress JSONL contract with `schema_version`, `run_id`, terminal
  event, failure kind, and tested cancellation/no-partial-history semantics.
- [ ] Do not add platform settings URIs, distro detection, or privileged helpers to Core.
- [ ] Add `runtime-info --json` only after a second lane proves the same contract need.

## P1: Mobile Integration

- [ ] Update the Expo 57 patch set to current compatible versions and rerun `npm run
  verify`, `npm run preflight:release`, Expo Doctor, iOS Simulator, and Android release.
- [ ] Bind the dev bridge to loopback by default; require explicit LAN mode plus a
  per-run token, origin allowlist, fixed app-owned database path, redacted health/errors,
  bounded jobs, and cancellation.
- [ ] Disable Android backup or explicitly exclude DNS profiles, custom domains, and
  benchmark history; apply equivalent iOS backup policy and document retention.
- [ ] Reduce mobile consumer UI to one title/status/action, hide empty Process/Result
  until needed, remove Core/CLI jargon, and keep advanced profile editing progressive.
- [ ] Treat Expo web as dev/router QA only. After all gates pass, merge mobile source to
  `main`; keep the `production-ios-dns` artifact blocked by provider/device evidence.

## P1: Platform Evidence

- [ ] Linux: finish accessibility/desktop-fit Milestone 6 and source-built package,
  publisher, CI, and evidence Milestones 8-9. Keep Milestone 7 Power fail-closed.
- [ ] Windows: run Release validator, WinUI/MSIX/tray, EN/VI wrapping, keyboard,
  Narrator, high-contrast, VPN/firewall, clean install/upgrade on Windows.
- [ ] macOS Power: add compare-before-restore state guard, then run disposable-network
  Apply -> Validate -> Restore. Do not block Store-safe release on Power.
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
