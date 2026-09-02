# Mobile Progress

Last reviewed: 2026-09-03. Reviewed branch: `worktree/mobile` after Expo SDK patch alignment.

## BLUF

Mobile is a native Expo app backed by local Expo modules and a Rust adapter around
`dnspilot-core`; installed builds do not require a developer Mac or Node bridge. The
consumer shell and entitlement isolation are release-candidate ready. D13 Health Check
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

- `npm run verify`: pass with 106 tests and Expo 57.0.19 compatibility; `expo-doctor`: 21/21.
  The audit policy fails all unapproved high/critical findings and has a source-locked
  exception only for Metro's presently unfixable build-time `image-size` advisory chain.
- `npm run preflight:release`: pass, including a local Android release-shape AAB and debug-key
  QA APK, each with manifest/dex capability gates. Both local artifacts use the debug
  certificate and are QA-only; EAS `production` signs the Play upload artifact remotely.
  iOS Simulator Release build with signing disabled: pass on 2026-09-03 after a clean
  prebuild, Rust artifact preparation, and CocoaPods/codegen installation.
- The latest local Android artifacts have SHA-256 `4475d1aac8db49cd7de39eb0bf2c7682861c2c22106283afcbd7f07b83ccaedc`
  (AAB) and `d8799ff834c1dfe2ee2a1a3fe256abbe57e2dd8873347f923ebb789bbb186601` (QA APK).
  The APK is Android Debug signed and verified with APK Signature Scheme v2, so both remain QA-only.
- Predecessor Pixel 9 Pro XL physical smoke: tutorial persistence, Help on all consumer tabs,
  foreground DNS-only and DNS + TCP jobs, native runtime launch, history save, and
  Vietnamese presentation: pass. Final QA APK re-smoke after Wi-Fi change also passed
  Quick Check and System DNS validation (`526 ms`) without mutating system DNS or crashing.
  Current final APK is installed on the Pixel with no launch crash, but interactive smoke is
  `NOT RUN` because the device was locked before automation could reach DNSPilot.
- Store review, signed iOS/iPadOS QA, TalkBack/VoiceOver, backup/restore, optional iOS
  entitlement, and Samsung-specific Settings handoff: `NOT RUN`.

## Remaining Gates

1. Install and smoke the current QA APK on Pixel 9 Pro XL, then run Samsung-specific Settings
   handoff when the S25 Ultra is attached.
2. Consume the D13 Health Check contract after Core lands; do not fork it in JavaScript.
3. Run D14 iOS/Android feasibility spikes. Keep unsupported platforms foreground-only.
4. Keep the entitled iOS artifact provider/device blocked independently.

## Source Of Truth

- Checklist: `apps/mobile/mobile-readiness.md`
- Risks: `apps/mobile/mobile-risks.md`
- Publish: `apps/mobile/mobile-publish-checklist.md`
- Provider gates: `docs/os-provider-trust.md`
