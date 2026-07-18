# DNSPilot Mobile

Standalone Expo/React Native app for iOS/iPadOS and Android.

## Architecture

- Expo SDK 57, Expo Router, React Native 0.86, React 19.2.
- Local Expo modules call a Rust adapter around `dnspilot-core` inside installable builds.
- App-private SQLite owns profiles, suites, history, recommendation, and policy state.
- Node `server/dev-server.mjs` is Expo Go/web development fallback only. It is not a
  release dependency; keep it loopback-only until the LAN security gate is implemented.
- Production/preview exclude dev-client/dev-menu. `production-ios-dns` alone opts into
  user-enabled `NEDNSSettingsManager` DoH/DoT after Apple approval.
- EN/VI, persisted language/tutorial state, three consumer tabs, contextual setup, and
  foreground benchmark jobs reuse shared Core contracts.

## Install

```bash
npm install
npx expo install --check
npx expo-doctor@latest
```

Use Expo's resolver after SDK changes; do not hand-pin incompatible native packages:

```bash
npx expo install --fix
```

## Native Development

```bash
npm run native:prepare:ios
npm run native:prepare:android
npm run start:dev-client
```

Native builds do not need a bridge. Use `npm run bridge` only for local Expo Go/web route
QA. Do not expose the current bridge to an untrusted LAN.

## Verify

```bash
npm run verify
npm run preflight:release
npx expo-doctor@latest
```

`verify` covers unit tests, TypeScript, Expo config, Router web export, package alignment,
and dependency policy. `preflight:release` prepares Rust artifacts, validates Store vs
opt-in iOS entitlement isolation, builds Android release, and rejects dev/VPN/privileged
surface. Current status is recorded in `../mobile-progress.md`.

## Platform Boundaries

- iOS plain DNS is guided through Settings. Optional entitled DoH/DoT still requires user
  enablement and physical-device provider proof.
- Android opens Private DNS Settings; it does not use `VpnService` or silently mutate DNS.
- Mobile DNS cache flush is unsupported; retest System DNS after user-controlled setup.
- Expo web is a development/router target until it has a bridge-free runtime.

Release QA and publishing: `../mobile-readiness.md`,
`../mobile-publish-checklist.md`, and `../../../docs/os-provider-trust.md`.
