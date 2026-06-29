# DNSPilot Mobile

Expo/React Native shell for testing DNSPilot core and CLI contracts on mobile.

## Stack

- Expo SDK 56 with Expo Router.
- Local Node bridge at `server/dev-server.mjs`.
- Rust remains source of truth through `cargo run -p dnspilot-cli`.
- Dev SQLite lives at `.dnspilot/dnspilot.sqlite`.
- English/Vietnamese UI via `expo-localization`.
- Native build metadata is configured in `app.json`; EAS profiles are in
  `eas.json`.
- `patch-package` applies an Expo SDK 56 `expo-modules-jsi` Swift fix required
  for Xcode 26 Simulator builds. Remove it after Expo ships the upstream fix.
- `expo-dev-client` is included for installable development builds; Expo Go is
  still usable for bridge-only UI testing.

## Run

Terminal 1:

```bash
npm run bridge
```

Terminal 2:

```bash
npm start
```

Use `http://localhost:8787` for web and iOS Simulator. For a physical phone,
replace the Bridge URL in the Overview tab with the printed Mac LAN URL, for
example `http://192.168.1.20:8787`.

Native local builds use:

```bash
npm run ios
npm run android
```

For a development build installed on a real device, start Metro with:

```bash
npm run start:dev-client
```

## Verify

Before real-device QA or EAS builds, run:

```bash
npm run verify
```

This runs unit tests, TypeScript, Expo config export, web export, Expo install
checks, and the high-severity production dependency audit.

Local native smoke commands:

```bash
npx expo run:ios --configuration Debug --device "<simulator name>" --no-bundler --no-install --no-build-cache
npx expo prebuild --platform android --no-install
./android/gradlew -p android assembleDebug
```

## Real Device Notes

- iOS/iPadOS may ask for Local Network permission when connecting to the local
  bridge. Allow it for LAN bridge testing.
- Android should not show dangerous runtime permission prompts for normal
  network access.
- The app does not silently mutate system DNS and does not use Android
  `VpnService`.
- Publish and store-review steps are tracked in
  `../mobile-publish-checklist.md`.

## Covered CLI Surface

- `catalog`
- `capability`, `capabilities`
- `preflight`
- `apply-policy`, `apply-plan`
- `benchmark`, `system-benchmark`
- `compare`
- `path-estimate`, `path-compare`
- `profile-add`, `profile-update`, `profile-delete`, `profile-list`
- `suite-add`, `suite-update`, `suite-delete`, `suite-list`
- `history-list`, `history-delete`, `history-clear`
- `recommend-sample`

## Boundary

This is a store-safe test shell. Expo Go cannot spawn or link the Rust CLI
inside the mobile app process, so the current build uses a local bridge. A
release app should replace the bridge with native Rust bindings or approved
platform adapters.
