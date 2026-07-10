# DNSPilot TODO

## P0: macOS Release Gates

- [ ] Acquire Apple signing identity and provisioning for `com.dnspilot.mac`.
- [ ] Package a certificate-signed Store-safe app and run distribution validation.
- [ ] Complete App Store Connect metadata, screenshots, support URL, privacy URL,
  privacy answers, and review notes.
- [ ] Perform Store-safe manual review smoke, then upload for review.

## P1: Power Edition Release Gate

- [ ] On a disposable network, enable Direct Admin Actions, apply a known-safe
  resolver, validate System DNS, restore the original DNS, and validate again.
- [ ] Package and sign Power edition separately from the App Store app.

## P2: Next Product Decision

- [ ] Decide whether Windows/Linux/mobile receive benchmark-first shells before
  any platform-specific direct-DNS adapter is implemented.

## References

- `STATE.md`
- `apps/macos/PUBLISHING.md`
