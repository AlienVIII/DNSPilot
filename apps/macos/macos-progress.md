# macOS Progress

## BLUF

macOS is the UX lead lane and currently has the most complete native shell. The
store-safe path is implemented around benchmark, guidance, copy/open settings,
flush guidance, and system-DNS validation. Direct DNS mutation remains Power
edition only and explicitly gated.

## Requirement Coverage

- SwiftUI shell with sidebar, Benchmark, Catalog, History, custom DNS, custom
  suites, Game Ping, Permissions, Publish readiness, and menu bar quick actions.
- Benchmark UX covers setup, progress, cancellation, diagnostics, result rows,
  saved history, fastest observed DNS, balanced recommendation, A/AAAA controls,
  IPv4/IPv6 controls, and copyable reports.
- Guided apply uses shared `apply-plan`, captures restore DNS when available,
  confirms copy/open Settings actions, and validates with System DNS mode.
- Store-safe flush copies commands instead of running privileged mutations.
- Catalog rows can launch confirmed store-safe apply for plain DNS profiles.
- Product Goals list all six acceptance goals with concrete app entry points,
  validation evidence, and EN/VI localized user-facing copy.
- English/Vietnamese localization covers primary native surfaces.
- Power actions are disabled by default and require
  `DNSPilotPowerActionsEnabled`, `DNSPILOT_ENABLE_POWER_ACTIONS`, or a Power
  edition bundle switch.
- Publishing docs, App Store Connect notes, and distribution packaging scripts
  are present; the Publish screen also surfaces local release preflight and
  privacy manifest readiness.
- Local bundle validation requires macOS target, version/build metadata,
  sandbox entitlements, privacy manifest, and Store-safe/Power split checks.

## Validation

- `swift test --package-path apps/macos/DNSPilotMac`: pass.
- `cargo test --workspace --tests`: pass for shared CLI/core consumed by macOS.

## Remaining Gates

- Release signing identity, provisioning, and App Store entitlement approval.
- Signed distribution bundle validation.
- Power-edition helper/runtime QA remains separate from the Store build.

## Source Of Truth

- Publish/release steps: `apps/macos/PUBLISHING.md`.
- Core CLI requests: `apps/macos/macos-core-cli-request.md`.
