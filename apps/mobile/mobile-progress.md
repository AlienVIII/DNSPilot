# Mobile Progress

Last reviewed: 2026-08-04. Reviewed branch: `worktree/mobile`.

## BLUF

Mobile is a native Expo app backed by local Expo modules and a Rust adapter around
`dnspilot-core`; installed builds do not require a developer Mac or Node bridge. The
automated release lane is green. The remaining gates are physical-device evidence,
provider-owned signing/accounts, and the separately restricted iOS entitlement.

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

- `npm run verify`: pass, 98 tests, typecheck, public config, Router export,
  Expo compatibility, and high-severity audit threshold.
- `npx expo-doctor@latest`: 20/20 checks pass.
- Rust runtime contract tests: 13 pass. iOS Release Simulator build passes on
  iPhone 17e / iOS 26.5.
- `npm run native:prepare:android` rebuilt all ABIs; `npm run preflight:release`
  passed Android AAB, Store manifest, and dex gates. The companion local QA APK
  passes `apksigner verify` with v2 signing.
- Physical-device launch, signing, Store review, VoiceOver/TalkBack, backup, and
  optional entitlement proof: `NOT RUN`; the connected S25 Ultra awaits ADB authorization.

## Remaining Gates

1. Authorize S25 Ultra USB debugging, install the local QA APK, and run the Android
   smoke flow.
2. Run the full signed device matrix, including accessibility, tablet, offline, and
   Settings handoff evidence.
3. Complete Apple/Google signing and Store submission. Keep the entitled iOS artifact
   provider/device blocked independently.

## Source Of Truth

- Checklist: `apps/mobile/mobile-readiness.md`
- Risks: `apps/mobile/mobile-risks.md`
- Publish: `apps/mobile/mobile-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
