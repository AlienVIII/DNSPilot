# DNSPilot Roadmap

Last reviewed: 2026-07-14.

## P0: macOS Commercial Release

- [ ] Complete the macOS localization and interaction-consistency gate in
  `docs/research/2026-07-14-macos-localization-interaction-review.md`.
- [ ] Replace mixed EN/VI and partial dictionary localization with one String Catalog;
  make `System` follow macOS and keep raw technical logs separate from localized UI.
- [ ] Make full visible option/disclosure rows clickable, keyboard reachable, and
  VoiceOver-labelled; hide Power-only settings from the Store-safe SKU.
- [ ] Capture the EN/VI visual-state matrix and pass the narrow-window, Dark Mode,
  keyboard, and VoiceOver review before moderated usability testing.
- [ ] Native-review Vietnamese copy and localize App Store metadata, support/privacy
  pages, and screenshot sets before submission.
- [x] Complete local benchmark, bundle, smoke, rollback, release-asset, and
  release-site safety automation.
- [ ] Run five moderated users through Check -> Recommend -> Apply -> Retest.
- [ ] Acquire Apple signing/provisioning and validate a certificate-signed bundle.
- [ ] Host support/privacy pages and capture signed-release screenshots.
- [ ] Complete App Store Connect privacy/review metadata and submit.

## P1: Reference-Lane Catch-Up

- [ ] Linux: complete Store-safe milestones 0-6 and 8-9 in
  `apps/linux/linux-completion-plan.md`; keep Power experimental and fail-closed.
- [ ] Windows: complete milestones 0-4 in
  `apps/windows/windows-predevelopment-review.md`; leave Windows-host release proof
  as the Milestone 5 manual gate.
- [x] Mobile isolated lane: finish Check DNS / Profiles / History navigation, remove
  app-open permission UX, fail verification on unresolved routes, and keep native DNS
  entitlement opt-in.
- [ ] Mobile integration: keep the consumer work on `worktree/mobile` until it can be
  integrated without violating approved entitlement isolation decision D1.
- [ ] Re-run each lane gate after merging `main`, then update the parity matrix in
  `docs/reference-lane-contract.md` with proof or `NOT RUN`.

## P1: Shared Core Contracts

- [x] Expose per-sample DNS `failure_detail` without changing recommendation rules.
- [ ] Add locale-neutral structured issue/message IDs before another lane parses
  English Core text.
- [ ] Document one progress JSONL contract across compare, path-compare, and
  system-benchmark, including cancellation/history semantics.
- [ ] Decide `runtime-info --json` only after Linux and Windows confirm the same
  version/readiness need; do not add a Windows-only Core contract prematurely.

## P1: Power Safety

- [ ] Run macOS Power Apply -> Validate -> Restore on a disposable network.
- [ ] Keep Linux Power disabled until a caller-bound polkit/D-Bus mechanism and exact
  rollback pass mocked plus real Linux QA.
- [ ] Keep Windows Power a separate future SKU; no Store elevation or DNS mutation.
- [ ] Keep mobile native DNS outside the default Store SKU until provider approval.

## References

- `PROJECT.md`
- `STATE.md`
- `docs/reference-lane-contract.md`
- `docs/core-cli-backlog.md`
- `docs/os-provider-trust.md`
