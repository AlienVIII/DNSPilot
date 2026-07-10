# macOS Progress

## BLUF

macOS is the UX lead lane and currently has the most complete native shell. The
store-safe path is implemented around benchmark, guidance, copy/open settings,
flush guidance, and system-DNS validation. Direct DNS mutation is available only
in Power/direct-install capable builds after explicit Direct Admin opt-in, or a
local force flag, and still requires macOS administrator approval.

## Requirement Coverage

- SwiftUI shell with sidebar, Benchmark, Catalog, History, custom DNS, custom
  suites, Game Ping, Permissions, Publish readiness, and menu bar quick actions.
- Benchmark UX covers setup, progress, cancellation, diagnostics, result rows,
  saved history, fastest observed DNS, balanced recommendation, A/AAAA controls,
  IPv4/IPv6 controls, and copyable reports.
- Guided apply uses shared `apply-plan`, captures restore DNS when available,
  confirms copy/open Settings actions, and validates with System DNS mode with
  visible progress and saved history.
- Store-safe flush copies commands instead of running privileged mutations.
- Catalog rows can launch confirmed store-safe apply for plain DNS profiles.
- First-run setup and the Permissions screen explain macOS permission reality:
  there is no System Settings pre-toggle for plain DNS edits; Direct Admin
  Actions are unavailable in Store-safe builds, available only in Power/direct-
  install builds, and macOS asks for administrator approval at Apply/Flush time.
- First-run setup copy is now short by default, with detailed permission
  context behind SwiftUI `.help`; the toolbar has a `Show Setup` Help action to
  reopen the tutorial.
- Product Goals list all six acceptance goals with concrete app entry points,
  validation evidence, and EN/VI localized user-facing copy.
- English/Vietnamese localization covers primary native surfaces.
- Power actions are disabled by default. Store-safe builds cannot enable them
  from a stale preference alone; Power/direct-install builds require
  `DNSPilotPowerActionsEnabled` plus Direct Admin opt-in, while
  `DNSPILOT_ENABLE_POWER_ACTIONS=1` is the local/dev force path.
- Publishing docs, App Store Connect notes, and distribution packaging scripts
  are present; release signing defaults to hardened runtime for certificate-
  backed packages, and the Publish screen surfaces local release preflight,
  privacy manifest readiness, and hardened-runtime distribution validation.
- Local bundle validation requires macOS target, version/build metadata,
  sandbox entitlements, privacy manifest, and Store-safe/Power split checks.
- Non-mutating goal smoke covers store-safe apply-plan, Power apply-plan
  contract, System DNS validation progress/history, optional live DNS/Game Ping
  probes, and optional Store/Power bundle mode checks.

## Validation

- `./script/ci_macos.sh`: pass; includes Rust tests, Swift tests, sandbox
  bundle verification, DNS-only live smoke, and DNS+TCP live smoke.
- `swift test --package-path apps/macos/DNSPilotMac`: pass.
- `cargo test --workspace --tests`: pass for shared CLI/core consumed by macOS.
- `./script/smoke_macos_goal_flows.sh --include-network`: pass on current
  network.
- `./script/smoke_macos_goal_flows.sh --include-bundles`: pass; restores
  Store-safe bundle afterward.
- `./script/preflight_macos_release.sh --include-power`: pass; validates Rust,
  Swift, Store-safe bundle, Power bundle, and restores Store-safe bundle.

## Remaining Gates

- Release signing identity, provisioning, and App Store entitlement approval.
- Signed distribution bundle validation.
- Power-edition helper/runtime QA remains separate from the Store build.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Publish/release steps: `apps/macos/PUBLISHING.md`.
- Core CLI requests: `apps/macos/macos-core-cli-request.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
