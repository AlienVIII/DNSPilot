# macOS Risks

Last reviewed: 2026-07-19.

## Major

- Power Restore validates snapshot age and active service but does not prove current DNS
  still equals what DNSPilot applied. A later user/VPN/MDM change could be overwritten.
  Power stays unreleasable until compare-before-restore and real-network proof pass.
- Automated localization and interaction gates do not replace signed EN/VI, narrow
  window, Dark Mode, keyboard, and VoiceOver evidence.

## Product And UX

- Store-safe guidance must not imply DNSPilot changed DNS automatically.
- DNS+TCP target presets must remain explicit estimates, not game ping/in-match latency.
- Advanced flush, diagnostics, and Power explanation must stay behind disclosure/help.

## Platform And Release

- Store-safe and Power entitlement/signing/package boundaries must remain deterministic.
- App Store signing/provisioning, hosted support/privacy, clean-Mac proof, five-user QA,
  and submission are manual gates.
- Direct Power requires Developer ID/notarization and separate administrator/rollback QA;
  it must not block the Store-safe commercial release.

## Contract

- Unsupported Core schema versions fail closed; user-facing Core text still needs stable
  message IDs for complete native localization.
