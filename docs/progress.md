# Global Progress

Last integration review: 2026-09-03.

## Completed

- `main` contains shared Core/CLI hardening, macOS Store-safe baseline, Linux/Windows
  milestones, and the mobile release-candidate source through `2c3ec20`.
- Core DNS response identity, unpredictable transaction IDs, strict response validation,
  transaction-safe storage, typed policy IDs, and progress/cancel semantics are integrated.
- Mobile dev-bridge security, backup policy, concise first-run UI, Store entitlement
  isolation, and local release-shape gates are integrated.
- Current Linux tests/clippy and Windows 65-test/static gates pass.
- macOS D14 candidate resolves exact-result notification activation, reconciles OS
  notification authorization, surfaces scheduling failure, rolls back failed updates,
  and passes packaged EN/VI visual smoke. Swift test passes 285 tests; Quick Test has
  local accessibility evidence for a visible Result with a single open window.
- Product research identifies Guided Connection Check as the highest-value consumer
  direction; architecture amendment remains pending moderated evidence.

## Active Engineering Queue

1. Restore green gates: Core Rust 1.96 clippy and Mobile Expo SDK 57 patch alignment.
2. Implement Core D13 Health Check with synthetic failure fixtures.
3. Build the macOS Guided Connection Check reference journey and run five users.
4. Adapt the proven contract to Linux, Windows, iOS/iPadOS, and Android.

## Held Work

- macOS D14 runtime behavior remains subject to real notification delivery and privileged
  DNS mutation evidence; no Store-safety or automation boundary is relaxed to obtain it.
- Mobile source is integrated, but no new release candidate is claimed while Expo
  compatibility and preflight are red.
- Optional entitled iOS DNS remains blocked at Apple capability, signing, and physical
  device proof; it does not block default Store source work.

## Manual Gates

Apple/Google/Microsoft/Linux publisher credentials, signing identities, store submission,
signed physical-device proof, real Windows/Linux host proof, notification/VoiceOver
evidence, and real privileged DNS mutation remain manual. Batch them only after every
automatable gate above is green.
