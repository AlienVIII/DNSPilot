# Mobile Publish Checklist

Last reviewed: 2026-08-09.

## Release Posture

- Installable iOS/Android builds run the Rust adapter around `dnspilot-core` in-process;
  Node bridge is Expo Go/web development fallback only.
- Default iOS Store profile omits `dns-settings`. Optional `production-ios-dns` remains
  Apple capability/signing/physical-device gated and does not block default release.
- Android uses Private DNS Settings guidance and no `VpnService` or silent mutation.
- The automated release gate is green on the current lane: `npm run verify`, Expo
  Doctor, production config isolation, and a clean Android Store AAB. Do not submit
  until the physical-device and provider-owned gates in `apps/mobile/mobile-readiness.md`
  are complete.

## Automated Release Gate

```bash
npm run verify
npm run preflight:release
npx expo-doctor@latest
```

The gate must prove current package alignment, Router export, native Rust artifacts,
default/opt-in iOS entitlement isolation, Android release AAB and QA APK, no
dev/VPN/privileged surface, and approved backup behavior. The dependency gate fails all
unapproved high/critical production audit findings; Metro's documented `image-size` exception
is rechecked by source ID and should be removed as soon as Expo ships a compatible fix. Rerun
iOS Simulator and Android release smoke
after dependency or generated-config changes.

The local `android/app/build/outputs/apk/release/app-release.apk` is a debug-key-signed
release variant for local device QA only. The current SHA-256 is
`c9896d3ef21debc9d78e1c4c93404abfbacf937551e73fd51e018780796e015d`. Do not upload that APK
or its local signing key; the final Play artifact is the production AAB (current SHA-256
`d23f0a379a31e2caec5b6c999efaab118453922ed4a6e59c7281d2fc62bc80f8`) and Play App Signing.

## Physical Device Gate

1. Install signed native development/release candidates; no bridge is used.
2. Execute the flow in `apps/mobile/mobile-readiness.md` on iPhone/iPad and Android.
3. Capture EN/VI, phone/tablet, font scaling, VoiceOver/TalkBack, offline/restart,
   backup/restore, protected-network, Settings handoff, and System DNS retest evidence.
4. For optional iOS DNS Settings only, use a signed entitled build and validate
   install/explicit enable/status/remove on a physical device.

## Store Submission

1. Confirm final bundle/package ID before first submission.
2. Complete hosted privacy/support, Apple privacy details, and Google Data safety.
3. Build and submit default iOS `production` without Network Extensions.
4. Build Android `production`, complete first manual Play upload if required, then closed
   testing before production.
5. Describe Health Check, DNS Benchmark, and guided OS setup only after each is proven.
   Do not claim internet speed, automatic fastest-DNS apply, silent switching, VPN
   behavior, scheduled monitoring, remote push, or force-quit background completion.
6. Treat optional `production-ios-dns` as a later separately reviewed artifact.

Provider/account/signing steps and required returned proof are in
`docs/os-provider-trust.md`.
