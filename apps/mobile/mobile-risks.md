# Mobile Risks

Last reviewed: 2026-07-19.

## Major

- The development Node bridge is hardened for loopback/LAN development use, but it remains
  an unsupported release transport. Installed native builds do not use it.
- Android backup is disabled and the iOS native database directory is marked excluded from
  backup. Physical backup/restore verification remains required.
- Expo 57 patch compatibility is green. npm audit still reports 11 moderate, transitive
  Expo toolchain findings; the only offered remediation is a breaking downgrade, so it is
  intentionally not applied.
- Check DNS no longer renders empty Process/Result panels. Profiles and remaining web-only
  diagnostics still need a physical-device copy/accessibility review.

## Platform And Contract

- Default iOS Store artifacts must omit `dns-settings`; optional
  `production-ios-dns` remains Apple capability/signing/physical-device blocked.
- Android consumer must keep Private DNS Settings guidance and no `VpnService` or silent
  mutation. Programmatic Private DNS is a device-owner API, not a consumer feature.
- Foreground native jobs preserve Core payload/recommendation/storage ownership and fail
  closed on unsupported schemas. Expo web remains development/router QA only.

## Release

- Physical-device VoiceOver/TalkBack, settings handoff/retest, backup behavior, signing,
  store metadata, privacy forms, and submission remain manual.
- npm audit reports 11 moderate and no high/critical findings. Do not apply npm's breaking
  forced downgrade; resolve through compatible upstream/direct package updates.
