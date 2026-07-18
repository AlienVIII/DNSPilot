# Mobile Risks

Last reviewed: 2026-07-19.

## Major

- The development Node bridge binds `0.0.0.0`, allows wildcard CORS, has no token, accepts
  a caller-selected database path, and leaks local paths. Installed native builds do not
  use it, but developer machines/LAN data remain exposed until it is hardened.
- Android generated config currently permits backup of local profiles/domains/history;
  Android and iOS need an explicit backup exclusion/retention decision.
- Current `npm run verify` is red because the Expo 57 patch set is one patch behind the
  versions expected by Expo. Release preflight was not reached in the latest rerun.
- Consumer Profiles and first-run web state expose implementation jargon, repeated titles,
  premature empty panels, and raw bridge failure. Progressive disclosure is incomplete.

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
