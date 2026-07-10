# DNSPilot State

## Product

DNSPilot finds and recommends DNS configurations for the current network, then
uses a platform-capability-specific apply flow.

## Current Delivery State

- Shared Rust core and CLI: implemented and tested.
- macOS 14+ SwiftUI shell: v1 core-goal coverage is implemented in code.
- App Store edition: guided apply/flush only; no silent DNS mutation.
- Power edition: direct-install only; explicit opt-in plus per-action macOS
  administrator approval for plain DNS Apply/Flush.

## Current Validation

- `./script/ci_macos.sh`
- `./script/preflight_macos_release.sh --include-power`

## Release Gates

- Apple signing identity and provisioning.
- Signed distribution bundle validation.
- Power Apply/Flush QA on a disposable network.
- App Store metadata, screenshots, hosted support and privacy URLs, and upload.

## Detailed Sources

- Product/runbook: `README.md`
- macOS scope and evidence: `apps/macos/macos-progress.md`
- Publishing steps: `apps/macos/PUBLISHING.md`
- Historical implementation log: `progress.md`
