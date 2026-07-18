# macOS Progress

## BLUF

macOS is the UX lead lane and currently has the most complete native shell. The
store-safe path is implemented around benchmark, guidance, copy/open settings,
flush guidance, and system-DNS validation. Direct DNS mutation is available only
in Power/direct-install capable builds after explicit Direct Admin opt-in, or a
local force flag, and still requires macOS administrator approval.

Consumer UX gates now have a singleton main window, task-first navigation, optional
setup, one primary result action, compact technical details, and semantic EN/VI native
resources. Automated localization and interaction checks pass. Store release still
needs signed visual review, external usability, and publishing evidence. Further
presentation-file extraction is post-stabilization maintenance except where it is
required to establish one text source of truth. See `apps/macos/macos-engineering-handoff.md`.

## Requirement Coverage

- SwiftUI shell with Check DNS, Profiles, History, custom DNS, custom suites,
  menu-bar quick actions, Help setup, Settings, and native commands.
- Benchmark UX covers setup, progress, cancellation, diagnostics, result rows,
  saved history, fastest observed DNS, balanced recommendation, A/AAAA controls,
  IPv4/IPv6 controls, and copyable reports.
- Guided apply uses shared `apply-plan`, captures restore DNS when available,
  confirms copy/open Settings actions, and validates with System DNS mode with
  visible progress and saved history.
- Store-safe flush copies commands instead of running privileged mutations.
- Profile candidates can launch confirmed store-safe apply guidance for plain DNS
  profiles.
- Optional setup explains macOS permission reality:
  there is no System Settings pre-toggle for plain DNS edits; Direct Admin
  Actions are unavailable in Store-safe builds, available only in Power/direct-
  install builds, and macOS asks for administrator approval at Apply/Flush time.
- First-run setup copy is now short by default, with detailed permission
  context behind SwiftUI `.help`; the toolbar has a `Show Setup` Help action to
  reopen the tutorial.
- Product Goals list all six acceptance goals with concrete app entry points,
  validation evidence, and EN/VI localized user-facing copy.
- Dota 2 SEA, CS2, and Riot/League checks are Check DNS target presets. They force
  DNS + TCP mode and state that the output is not ICMP or in-match UDP latency.
- English/Vietnamese presentation copy uses one semantic `Localizable.strings` family.
  `System` resolves macOS preferences, tooltips use one active language, and structured
  diagnostics/results/history are localized while raw CLI evidence stays in Technical
  details. Signed visual review remains required for native-language quality.
- Power actions are disabled by default. Store-safe builds cannot enable them
  from a stale preference alone; Power/direct-install builds require
  `DNSPilotPowerActionsEnabled` plus Direct Admin opt-in, while
  `DNSPILOT_ENABLE_POWER_ACTIONS=1` is the local/dev force path.
- Publishing docs, App Store Connect notes, and distribution packaging scripts
  are present; release signing defaults to hardened runtime for certificate-
  backed packages, with local preflight, privacy-manifest readiness, and
  distribution validation documented outside the consumer navigation.
- Power Apply validates literal IPv4/IPv6 addresses at the privileged boundary;
  hostnames and malformed input are rejected before any administrator prompt.
- Power Apply captures a fresh service-scoped DNS rollback record before
  elevation, rechecks the active service/configuration before mutation, and
  restores manual or automatic/DHCP DNS only through an explicit Power action.
- Local bundle validation requires macOS target, version/build metadata,
  sandbox entitlements, privacy manifest, and Store-safe/Power split checks.
- Non-mutating goal smoke covers store-safe apply-plan, Power apply-plan
  contract, System DNS validation progress/history, optional live DNS/game-target
  probes, and optional Store/Power bundle mode checks.

## Validation

- `./script/ci_macos.sh`: pass; includes Rust tests, Swift tests, sandbox
  bundle verification, DNS-only live smoke, and DNS+TCP live smoke.
- `swift test --package-path apps/macos/DNSPilotMac`: pass.
- `cargo test --workspace --tests`: pass for shared CLI/core consumed by macOS.
- `./script/smoke_macos_goal_flows.sh --include-network --include-bundles`: pass on
  the current network; restores the Store-safe bundle afterward.
- `./script/preflight_macos_release.sh --include-power`: pass; validates Rust,
  Swift, Store-safe bundle, Power bundle, and restores Store-safe bundle.

## Remaining Gates

- Capture the signed EN/VI visual-state matrix in
  `docs/research/2026-07-14-macos-localization-interaction-review.md`. The current
  host passes packaged-window launch validation but lacks the Screen Recording and
  Accessibility evidence path required for pixel/VoiceOver capture.
- Product UX evidence in `TODO.md`: a five-user moderated usability pass after the
  consistency milestone passes.
- Release signing identity, provisioning, and App Store entitlement approval.
- Signed distribution bundle validation.
- Power-edition helper/runtime QA remains separate from the Store build.
- Real-network Power Apply/Restore QA remains required before direct distribution.
- OS provider trust/manual release steps remain in `docs/os-provider-trust.md`.

## Source Of Truth

- Publish/release steps: `apps/macos/PUBLISHING.md`.
- Core CLI requests: `apps/macos/macos-core-cli-request.md`.
- Shared UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual gates: `docs/os-provider-trust.md`.
- Product/UX research: `docs/research/2026-07-11-macos-product-ux-review.md`.
- Localization/interaction review:
  `docs/research/2026-07-14-macos-localization-interaction-review.md`.
- Engineering milestones: `apps/macos/macos-engineering-handoff.md`.
