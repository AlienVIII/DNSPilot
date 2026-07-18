# Global Progress

Last integration pass: 2026-07-19.

## Completed

- Reviewed and merged clean macOS `7609d57`, Linux `034621c`, and Windows `2f3cef0`
  lane heads into `main` without rewriting branch history.
- Revalidated macOS CI/release preflight, Linux fmt/test/clippy, Windows Core/static gate,
  and dependency audit baselines.
- Confirmed macOS as the first commercial release lane and one shared cross-platform
  decision contract in `docs/reference-lane-contract.md`.
- Amended mobile entitlement isolation: provider risk is gated at the signed artifact,
  not all later source commits.
- Added architecture decisions for DNS response integrity, transaction-safe storage,
  mobile web scope, and compare-before-restore Power safety.
- Consolidated current product, UX, security, provider, and lane evidence in
  `docs/research/2026-07-19-overall-product-review.md`.

## Active Engineering Queue

1. Core D8 DNS response integrity.
2. Core D9 concurrent mutation safety.
3. Mobile Expo compatibility, dev-bridge security, backup/privacy, and concise UI.
4. macOS Power compare-before-restore.
5. Linux/Windows real-host release evidence and macOS signed/provider evidence.

## Isolated Work

- Mobile remains at `8dd1c26`. It has a native Rust-backed runtime and default Store
  entitlement isolation, but current verify/security/privacy/UX gates are not green.
- The optional `production-ios-dns` artifact remains blocked on Apple capability,
  signing, and physical-device evidence even after source integration.

## Manual Gates

Signing identities, publisher accounts, store submissions, physical-device proof, real
Windows/Linux host proof, and real privileged DNS mutation remain manual. They are
batched in `docs/os-provider-trust.md`; no provider action or push was performed.
