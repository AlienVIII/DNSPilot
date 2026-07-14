# DNSPilot Mobile State

Last updated: 2026-07-14.

## Current Truth

- `worktree/mobile` is an isolated delivery lane. Do not merge its optional iOS
  DNS Settings work into `main` until Apple approves `dns-settings` and a signed
  physical device validates the flow.
- The native consumer product has exactly three primary tabs: Check DNS,
  Profiles, and History. Installable builds call the shared Rust core in-process;
  Expo Go/web use the Node bridge only as a development fallback.
- Check DNS starts with foreground DNS-only Quick Check. DNS + TCP and current
  resolver validation are advanced controls. Results distinguish Fastest
  observed, balanced recommendation, and Keep current DNS.
- Profiles manages custom plain DNS, DoH, DoT, bootstrap addresses, and domain
  suites. History is retest-only; it never applies a saved recommendation.
- A versioned optional tutorial shows only after preferences load. Skip or Done
  records completion; the top-right Help icon reopens it from every consumer
  tab without a permission request.
- Default iOS Store builds are benchmark-first and guide-only. The separate
  `production-ios-dns` profile enables the restricted DoH/DoT DNS Settings
  experiment; iOS users still enable it in Settings. Android only guides the
  user to Private DNS/network settings. Neither platform silently mutates DNS,
  uses `VpnService`, or flushes system DNS.
- Delete/clear actions have no shared confirmation pattern in this lane. Do not
  add one ad hoc; introduce a shared, tested pattern only when a product-wide
  decision requires it.

## Latest Validation

- `npm run verify`: pass on commit `5a49a2b`; 89 tests, TypeScript, Expo Router
  export gate, dependency alignment, and high-severity audit threshold pass.
  Expo tooling still reports 11 moderate `uuid` findings; its force fix would
  downgrade Expo and is intentionally not applied.
- Production config assertions: pass. Default `production` omits the iOS DNS
  Settings plugin and flag; `production-ios-dns` alone enables both.
- iOS Simulator: current Release bundle built, installed, and launched on
  iPhone 17e / iOS 26.5. First launch showed the title-first tutorial and the
  header Help icon; no permission sheet appeared.
- Android: prior production `assembleRelease` and merged-manifest checks pass.
  The release manifest has no dev-client, overlay, storage, VPN, or silent DNS
  mutation capability. A signed physical Android device is `NOT RUN`.

## Manual Release Gates

### Both Platforms

- **Need:** install a signed internal build and complete the real-device matrix
  in `mobile-readiness.md`.
- **Why manual:** foreground networking, accessibility, tablet layout, and OS
  Settings handoff cannot be proven by simulator/export tests.
- **Inputs:** physical iPhone/iPad and Android phone/tablet, normal Wi-Fi or
  cellular network, and TestFlight/internal-distribution access.
- **Expected:** tutorial persists only after Skip/Done, Check DNS/Profiles/
  History remain the only tabs, diagnostics are readable, and retest/settings
  handoff stays user-controlled.

### iOS / iPadOS

- **Need:** Apple Developer membership, App Store Connect app record for
  `com.dnspilot.mobile`, signing/provisioning, privacy/review metadata, and a
  signed default Store build.
- **Why manual:** certificates, provisioning, App Review, and real Settings
  behavior are provider-controlled.
- **Inputs:** Apple Developer and App Store Connect access, team ID, bundle ID,
  support/privacy URLs, screenshots, and review notes describing benchmark and
  guided-settings behavior.
- **Expected:** TestFlight/App Store default build performs benchmarks and
  guided settings only. For the optional profile, Apple must first approve
  `dns-settings`; then validate Install -> user enables DNSPilot in Settings ->
  Refresh reports Enabled -> Remove reports not installed.

### Android

- **Need:** Play Console app for `com.dnspilot.mobile`, Play App Signing,
  Data safety/app-content declarations, internal test upload, and Private DNS
  handoff validation.
- **Why manual:** developer account, upload key/app signing, Play forms, and
  manufacturer Settings paths are external to this workspace.
- **Inputs:** Play Console access, package reservation, App Signing setup,
  privacy/support URLs, Data safety answers, and an Android test device.
- **Expected:** internal-release app has only normal network permissions; an
  eligible recommendation copies the DoT value and opens Settings, while the
  user performs the DNS change and returns to retest.

## Sources

- Consumer/manual contract: `mobile-readiness.md`.
- Build, publish, and device steps: `mobile-publish-checklist.md`.
- Shared platform boundaries: `../../docs/reference-lane-contract.md` and
  `../../docs/os-provider-trust.md`.
