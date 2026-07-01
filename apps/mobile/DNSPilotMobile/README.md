# DNSPilot Mobile

Expo/React Native shell for testing DNSPilot core and CLI contracts on mobile.

## Stack

- Expo SDK 57 with Expo Router, React Native 0.86, and React 19.2.
- Local Node bridge at `server/dev-server.mjs`.
- Rust remains source of truth through `cargo run -p dnspilot-cli`.
- Dev SQLite lives at `.dnspilot/dnspilot.sqlite`.
- English/Vietnamese UI via `expo-localization`.
- Native build metadata is configured in `app.json`; EAS profiles are in
  `eas.json`.
- `patch-package` applies a narrow Expo SDK 57 `expo-modules-jsi` Swift
  compatibility fix required for Xcode 26 Simulator builds. Remove it after Expo
  ships the upstream fix.
- `expo-dev-client` is included for installable development builds; Expo Go is
  still usable for bridge-only UI testing.
- First-open System Access sheet checks Local Network/network access, OS-gated
  DNS apply, and DNS flush limitations. Guided apply actions copy values and
  open OS Settings; they do not silently mutate system DNS.

## Install

```bash
npm install
npx expo-doctor@latest
npx expo install --check
```

`npm install` runs `patch-package` and reapplies the current
`expo-modules-jsi@57.0.0` Xcode 26 compatibility patch.

After Expo SDK changes, prefer Expo's resolver instead of hand-pinning native
packages:

```bash
npx expo install expo@^57.0.0 --fix
```

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
npx expo-doctor@latest
```

This runs unit tests, TypeScript, Expo config export, web export, Expo install
checks, and the high-severity production dependency audit. `expo-doctor` then
validates SDK package alignment and native config health.

Local native smoke commands:

```bash
npx expo run:ios --configuration Debug --device "<simulator name>" --no-bundler --no-install --no-build-cache
npx expo prebuild --platform android --no-install
./android/gradlew -p android assembleDebug
```

The iOS Simulator command requires a Simulator runtime matching the selected
Xcode SDK. With Xcode 26.6, install the iOS 26.5 Simulator runtime from Xcode >
Settings > Components before rerunning the iOS smoke command.

## Real Device Notes

- iOS/iPadOS may ask for Local Network permission when connecting to the local
  bridge. Allow it for LAN bridge testing.
- Android should not show dangerous runtime permission prompts for normal
  network access.
- The app does not silently mutate system DNS and does not use Android
  `VpnService`.
- Mobile OSes do not expose a store-safe third-party DNS cache flush API; use
  System DNS retest after user-controlled settings/profile changes.
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
