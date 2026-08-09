# Mobile Publish Checklist

Last reviewed: 2026-08-09.

## Release Posture

- Installable iOS/Android builds run the Rust adapter around `dnspilot-core` in-process;
  Node bridge is Expo Go/web development fallback only.
- Default iOS Store profile omits `dns-settings`. Optional `production-ios-dns` remains
  Apple capability/signing/physical-device gated and does not block default release.
- Android uses Private DNS Settings guidance and no `VpnService` or silent mutation.
- EAS identity is not initialized in this checkout (`eas whoami` is unauthenticated and
  `extra.eas.projectId` is absent). Creating/linking the Expo project and configuring its
  upload credential are owner-controlled release gates.
- The automated release gate is green on the current lane: `npm run verify`, Expo
  Doctor, production config isolation, and a clean local Android release-shape AAB. Do not submit
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

The local `android/app/build/outputs/apk/release/app-release.apk` and
`android/app/build/outputs/bundle/release/app-release.aab` both use the Android debug
certificate. Their current SHA-256 values are respectively
`c9896d3ef21debc9d78e1c4c93404abfbacf937551e73fd51e018780796e015d` and
`d23f0a379a31e2caec5b6c999efaab118453922ed4a6e59c7281d2fc62bc80f8`. They prove local
capability shape only. Do not upload either artifact or its local signing key. The Play
artifact must be built by EAS `production` with the configured upload credential.

## Physical Device Gate

1. Install signed native development/release candidates; no bridge is used.
2. Execute the flow in `apps/mobile/mobile-readiness.md` on iPhone/iPad and Android.
3. Capture EN/VI, phone/tablet, font scaling, VoiceOver/TalkBack, offline/restart,
   backup/restore, protected-network, Settings handoff, and System DNS retest evidence.
4. For optional iOS DNS Settings only, use a signed entitled build and validate
   install/explicit enable/status/remove on a physical device.

## Store Submission

1. Log in to the owner Expo account with `npx eas-cli@latest login`, then run
   `npx eas-cli@latest init` to create/link the `dnspilot-mobile` EAS project. Commit the
   resulting project ID only after the owner confirms the project/organization.
2. In `npx eas-cli@latest credentials`, create or import the Android upload key for that
   EAS project and confirm its SHA-1/SHA-256 with Play App Signing. Never use the local
   `android/app/debug.keystore`.
3. Confirm final bundle/package ID before first submission and complete hosted
   privacy/support, Apple privacy details, and Google Data safety.
4. Build and submit default iOS `production` without Network Extensions.
5. Run
   `npx eas-cli@latest build --platform android --profile production`. Download that remote
   signed AAB, complete first manual Play upload if required, then closed testing before production.
6. Describe Health Check, DNS Benchmark, and guided OS setup only after each is proven.
   Do not claim internet speed, automatic fastest-DNS apply, silent switching, VPN
   behavior, scheduled monitoring, remote push, or force-quit background completion.
7. Treat optional `production-ios-dns` as a later separately reviewed artifact.

Provider/account/signing steps and required returned proof are in
`docs/os-provider-trust.md`.
