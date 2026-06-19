# DNSPilot Mobile

Expo/React Native shell for testing DNSPilot core and CLI contracts on mobile.

## Stack

- Expo SDK 56 with Expo Router.
- Local Node bridge at `server/dev-server.mjs`.
- Rust remains source of truth through `cargo run -p dnspilot-cli`.
- Dev SQLite lives at `.dnspilot/dnspilot.sqlite`.

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
replace the Bridge URL in the Overview tab with the Mac LAN URL, for example
`http://192.168.1.20:8787`.

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
