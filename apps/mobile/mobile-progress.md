# Mobile Progress

Last reviewed: 2026-08-07. Reviewed branch: `worktree/mobile` at `61ac253`.

## BLUF

Mobile is a native Expo app backed by local Expo modules and a Rust adapter around
`dnspilot-core`; installed builds do not require a developer Mac or Node bridge. The
consumer shell and entitlement isolation are substantially implemented, but the lane is
not merge-ready because Expo's current patch compatibility check is red. D13 Health Check
separation and D14 background continuation are approved future work, not current behavior.

## Implemented

- `Check DNS`, `Profiles`, and `History` are the currently implemented tabs; D13's
  `Health Check`, `DNS Benchmark`, `Profiles`, `History` contract remains queued.
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
- D14 currently has no mobile background execution or local notification implementation.

## Latest Validation

- 99 tests, typecheck, Expo public config, and Router export: pass on 2026-08-07.
- Latest `npm run verify`: fail at Expo install compatibility. Expected patches are
  `expo`/`expo-router` 57.0.11 and `expo-symbols` 57.0.2.
- `npm run preflight:release`: not reached after verify failed.
- Earlier branch evidence includes iOS Release Simulator build/install/launch and Android
  release assembly/manifest checks; rerun after dependency/privacy changes.
- Physical-device, signing, Store review, VoiceOver/TalkBack, backup, and optional
  entitlement proof: `NOT RUN`.

## Remaining Gates

1. Restore current Expo compatibility and rerun the full release gate.
2. Consume the D13 Health Check contract after Core lands; do not fork it in JavaScript.
3. Run D14 iOS/Android feasibility spikes. Keep unsupported platforms foreground-only.
4. Merge source under amended D1 only after normal gates pass. Keep the entitled artifact
   provider/device blocked independently.

## Source Of Truth

- Checklist: `apps/mobile/mobile-readiness.md`
- Risks: `apps/mobile/mobile-risks.md`
- Publish: `apps/mobile/mobile-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
