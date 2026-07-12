# DNSPilot Mobile

Standalone Expo/React Native DNSPilot app for iOS/iPadOS and Android.

## Stack

- Expo SDK 57 with Expo Router, React Native 0.86, and React 19.2.
- Local Expo modules bind a Rust adapter around `dnspilot-core` directly inside
  installable builds.
- Local Node bridge at `server/dev-server.mjs` is an Expo Go/web development
  fallback only.
- Native SQLite lives in app-private Application Support/files storage.
- English/Vietnamese UI via `expo-localization`.
- Native build metadata starts from `app.json`; `app.config.cjs` filters
  development-only plugins for production/preview EAS profiles. EAS profiles
  are in `eas.json`.
- `patch-package` applies a narrow Expo SDK 57 `expo-modules-jsi` Swift
  compatibility fix required for Xcode 26 Simulator builds. Remove it after Expo
  ships the upstream fix.
- `expo-dev-client` is included for installable development builds. Production
  and preview profile config excludes dev-client/dev-menu autolinking before
  release manifests are generated. Expo Go is still usable for bridge-only UI
  testing.
- `expo-system-ui` backs native automatic light/dark appearance metadata during
  prebuild.
- `@react-native-async-storage/async-storage` persists the selected language.
- First-open System Access sheet checks native foreground network access, OS-gated
  DNS apply, and DNS flush limitations. It opens App Settings, Android Private
  DNS/network Settings, and System DNS retest without silently mutating DNS.
- A local iOS Expo module wraps `NEDNSSettingsManager` for user-approved DoH/DoT
  DNS Settings install/remove/status. The config plugin declares the
  `dns-settings` NetworkExtension entitlement; Apple signing capability and
  physical-device enablement remain manual release gates.

## Install

```bash
npm install
npx expo-doctor@latest
npx expo install --check
```

`npm install` runs `patch-package` and reapplies the current
`expo-modules-jsi@57.0.1` Xcode 26 compatibility patch.

After Expo SDK changes, prefer Expo's resolver instead of hand-pinning native
packages:

```bash
npx expo install --fix
```

## Run

Installable native builds use the in-app runtime and do not need a bridge:

```bash
npm run native:prepare:ios
npm run native:prepare:android
npm run start:dev-client
```

Use `npm run bridge` only for Expo Go/web fallback development. The UI hides
bridge setup whenever the native runtime is available.

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

Prepare Rust artifacts before a clean prebuild, local native build, or EAS
release build:

```bash
npm run native:prepare:ios
npm run native:prepare:android
```

Production Android release-surface check:

```bash
EAS_BUILD_PROFILE=production npx expo prebuild --clean --platform android --no-install
EAS_BUILD_PROFILE=production ./android/gradlew -p android :app:processReleaseManifest
rg -n "expo-dev|DevLauncher|DevMenu|SYSTEM_ALERT_WINDOW|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|VIBRATE|VpnService|BIND_VPN" android/app/build/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml || true
```

The final `rg` command should print no matches. Re-run the default development
prebuild before local dev-client Android work if the ignored native project was
last generated with a production profile.

The iOS Simulator command requires a Simulator runtime matching the selected
Xcode SDK. With Xcode 26.6, use an iOS 26.5 Simulator such as `iPhone 17e`.
If another process owns Metro port 8081, build with `--no-bundler`, then run
`npm run start:dev-client` on port 8082 for JS app smoke.

## Real Device Notes

- Native iOS/iPadOS diagnostics use normal foreground network access. Local
  Network is only relevant to optional bridge fallback development.
- Native iOS DNS Settings requires an installable entitled build, a DoH/DoT
  profile with bootstrap IP addresses, and explicit user enablement in Settings
  > General > VPN & Device Management > DNS. Expo Go cannot test this module.
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

Installable builds are store-safe and standalone: they call the shared Rust
core in-process for benchmarking, storage, recommendations, and policy. Expo
Go/web uses the development bridge because it cannot load the local native
module. iOS plain DNS remains guide-only; Android does not silently mutate
Private DNS or use `VpnService`.
