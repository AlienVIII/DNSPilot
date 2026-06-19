# macOS Progress

## Completed
- SwiftUI shell with sidebar, benchmark, catalog, history, custom DNS, custom suites, and menu bar quick run.
- Benchmark progress, result, failure, debug log, and apply-policy surfaces.
- Store-safe copy/open-settings apply guidance.
- System DNS validation mode in Benchmark tab using current Core CLI `system-benchmark` payload via macOS-side adapter.
- Post-apply result CTA to run System DNS validation against the current macOS resolver.
- Menu bar quick action for fast System DNS validation with Developer/Azure/Vietnam smoke-test domains.
- Copyable System DNS flush checklist for store-safe manual validation flow.
- Guided apply sequence after recommendations: copy DNS, open Network Settings, paste active service, flush/reconnect, validate System DNS.
- Apply-plan failure now falls back to local next-step guidance instead of hiding copy/open-settings actions.
- Bundle validator has distribution mode that fails debug/ad-hoc signing and missing release entitlements instead of warning only.

## Current Work
- macOS remains UX lead lane.
- Next focus: release-ready signing/entitlement checks and remaining App Store packaging risks.

## Blockers
- Release signing identity, provisioning, and App Store entitlement approval are not available in this worktree.
- Power-edition helper is out of scope for store build.

## Next Actions
- Add CI/release wiring around distribution bundle validation once signing credentials exist.
- Keep all Core CLI gaps in `macos-core-cli-request.md`.
