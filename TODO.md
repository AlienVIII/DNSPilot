# DNSPilot Roadmap

Last reviewed: 2026-07-11.

## P0: macOS Product UX Gate

- [x] Remove duplicate manual main-window creation; singleton `Window` count stays
  `1` after `Benchmark`, `Benchmark`, and `Run Quick Test` actions.
- [x] Reduce release navigation to Check DNS, Profiles, and History; move internal
  readiness/platform surfaces out of the consumer sidebar.
- [x] Replace permission-first onboarding with an optional interactive first check;
  setup is available from Help instead of blocking first value.
- [x] Make one result action primary. Move copy/debug/checklist actions behind
  secondary menus, disclosure, or contextual info.
- [x] Merge game checks into Check DNS target presets and state that DNS + TCP timing
  is not ICMP or in-match UDP latency.
- [x] Add native app commands and keyboard paths for Quick Test, Benchmark, Profiles,
  and History without creating another window.
- [ ] Add keyboard paths for cancel, result details, Settings, and Help flows.
- [ ] Split the 4,533-line app source incrementally by scene/feature without changing
  core contracts.
- [ ] Run a five-user moderated usability pass; require all participants to complete
  Check -> Recommendation -> Apply guidance -> Retest without assistance.

## P0: macOS Release Gates

- [ ] Acquire Apple signing identity and provisioning for `com.dnspilot.mac`.
- [ ] Package a certificate-signed Store-safe app and run distribution validation.
- [ ] Complete App Store Connect metadata, screenshots, support URL, privacy URL,
  privacy answers, and review notes.
- [ ] Perform Store-safe manual review smoke, then upload for review.

## P0: Commercial Validation

- [ ] Run the protocol in `docs/macos-v1-commercial-validation.md`.
- [ ] Interview 5-8 target users who actively change or troubleshoot DNS.
- [ ] Validate the primary promise: reliable DNS recommendation for the current
  network, not generic speed improvement.
- [ ] Define launch metrics: completed benchmark, recommendation confidence, guided
  apply completion, successful retest, and seven-day return rate.
- [ ] Test concise onboarding and permission copy with non-technical users.

## P1: Power Edition Release Gate

- [x] Implement and test service-scoped DNS rollback before Power Apply changes
  a network service; preserve automatic/DHCP DNS as a separate restore mode.
  Evidence: `5998142`; plan: `docs/superpowers/plans/2026-07-11-power-dns-rollback.md`.
- [ ] On a disposable network, enable Direct Admin Actions, apply a known-safe
  resolver, validate System DNS, restore the original DNS, and validate again.
- [ ] Package and sign Power edition separately from the App Store app.

## P2: Platform Expansion Gates

- [ ] Keep Windows/Linux/mobile benchmark-first until macOS release evidence and user
  research justify expansion.
- [ ] Mobile: obtain Apple `dns-settings` capability and signed-device evidence before
  considering merge of native DNS commit `345c41e`.
- [ ] Linux: build real Flatpak/Snap/deb/rpm artifacts and run distro QA.
- [ ] Windows: commit/review the isolated feature work, then validate WinUI/MSIX/tray
  behavior on Windows.
- [ ] Do not implement another direct-DNS adapter without provider approval, rollback
  evidence, and a clear commercial use case.

## References

- `STATE.md`
- `PROJECT.md`
- `apps/macos/PUBLISHING.md`
- `apps/macos/macos-engineering-handoff.md`
- `docs/research/2026-07-11-macos-product-ux-review.md`
