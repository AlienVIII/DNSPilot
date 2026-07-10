# DNSPilot Roadmap

Last reviewed: 2026-07-11.

## P0: macOS Release Gates

- [ ] Acquire Apple signing identity and provisioning for `com.dnspilot.mac`.
- [ ] Package a certificate-signed Store-safe app and run distribution validation.
- [ ] Complete App Store Connect metadata, screenshots, support URL, privacy URL,
  privacy answers, and review notes.
- [ ] Perform Store-safe manual review smoke, then upload for review.

## P0: Commercial Validation

- [ ] Interview 5-8 target users who actively change or troubleshoot DNS.
- [ ] Validate the primary promise: reliable DNS recommendation for the current
  network, not generic speed improvement.
- [ ] Define launch metrics: completed benchmark, recommendation confidence, guided
  apply completion, successful retest, and seven-day return rate.
- [ ] Test concise onboarding and permission copy with non-technical users.

## P1: Power Edition Release Gate

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
