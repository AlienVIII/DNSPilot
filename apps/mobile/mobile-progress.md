# Mobile Progress

Last reviewed: 2026-07-19. Reviewed branch: `worktree/mobile` at `8dd1c26`.

## BLUF

Mobile is a native Expo app backed by local Expo modules and a Rust adapter around
`dnspilot-core`; installed builds do not require a developer Mac or Node bridge. The
consumer shell and entitlement isolation are substantially implemented, but the lane is
not merge-ready while verify, bridge security, backup/privacy, and concise-UI gates are
open.

## Implemented

- `Check DNS`, `Profiles`, and `History` primary tabs; internal routes stay hidden.
- Foreground DNS-only, DNS+TCP/TLS, and System DNS jobs reuse Core catalog, policy,
  recommendation, storage, history, result, and progress contracts.
- Optional persisted first-run tutorial waits for preferences, completes on Skip/Done,
  requests no permission, and reopens from top-right Help on every consumer tab.
- Guided iOS/Android Settings handoff never silently mutates plain DNS or uses Android
  `VpnService`.
- Default iOS Store profile omits `dns-settings`; optional `production-ios-dns` contains
  user-enabled `NEDNSSettingsManager` DoH/DoT support behind provider/device gates.
- EN/VI, adaptive layout, accessibility metadata, custom profiles/suites, persistence,
  production dev-client exclusion, and Android release policy checks exist.

## Latest Validation

- 95 tests, typecheck, Expo config, and Router export: pass.
- Latest `npm run verify`: fail at Expo install compatibility. Expected patches are
  `expo 57.0.7`, `expo-constants 57.0.6`, `expo-dev-client 57.0.7`, and
  `expo-router 57.0.7`.
- `npm run preflight:release`: not reached after verify failed.
- Earlier branch evidence includes iOS Release Simulator build/install/launch and Android
  release assembly/manifest checks; rerun after dependency/privacy changes.
- Physical-device, signing, Store review, VoiceOver/TalkBack, backup, and optional
  entitlement proof: `NOT RUN`.

## Remaining Gates

1. Restore current Expo compatibility and rerun the full release gate.
2. Harden development bridge and local database boundary.
3. Enforce/document mobile backup and retention policy.
4. Remove duplicate titles, empty technical panels, raw errors, and Core/CLI jargon;
   keep advanced profile editing behind progressive disclosure.
5. Merge source under amended D1 only after normal gates pass. Keep the entitled artifact
   provider/device blocked independently.

## Source Of Truth

- Checklist: `apps/mobile/mobile-readiness.md`
- Risks: `apps/mobile/mobile-risks.md`
- Publish: `apps/mobile/mobile-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
