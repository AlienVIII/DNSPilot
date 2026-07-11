# DNSPilot State

Last updated: 2026-07-11.

## Product

DNSPilot finds and recommends DNS configurations for the current network, then
uses a platform-capability-specific apply flow.

## Current Delivery State

- Shared Rust core and CLI: implemented and tested.
- macOS 14+ SwiftUI shell: v1 core-goal coverage is implemented in code.
- macOS product/UX architecture review is complete; four Major findings must close
  before Store release. Engineering starts with single-window ownership.
- App Store edition: guided apply/flush only; no silent DNS mutation.
- Power edition: direct-install only; explicit opt-in plus per-action macOS
  administrator approval for plain DNS Apply/Flush.
- Power edition is not release-ready: service-scoped rollback must be implemented
  and verified before direct distribution.
- Linux committed lane: packages the shared CLI engine and runs benchmarks off the UI
  thread; real package/distro QA remains open.
- Mobile committed native DNS experiment (`345c41e`) remains isolated pending Apple
  NetworkExtension approval and signed-device validation.
- Windows feature work remains dirty and isolated pending owner commit/review.

## Current Validation

- `./script/ci_macos.sh`
- `./script/preflight_macos_release.sh --include-power`

## Release Gates

- Apple signing identity and provisioning.
- Signed distribution bundle validation.
- Power Apply/Flush QA on a disposable network.
- App Store metadata, screenshots, hosted support and privacy URLs, and upload.

## Detailed Sources

- Product architecture: `PROJECT.md`
- Prioritized roadmap: `TODO.md`
- Product/runbook: `README.md`
- macOS scope and evidence: `apps/macos/macos-progress.md`
- Publishing steps: `apps/macos/PUBLISHING.md`
- Historical implementation log: `progress.md`
- macOS research: `docs/research/2026-07-11-macos-product-ux-review.md`
- Engineering handoff: `apps/macos/macos-engineering-handoff.md`
