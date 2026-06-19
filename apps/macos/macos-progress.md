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
- Menu bar can reuse the last actionable guided apply plan for up to 24h: copy last DNS or copy+open Network Settings, without silent system DNS mutation.
- System DNS validation mode shows current macOS DNS servers/search domains when SystemConfiguration exposes them, with refresh and copy fallback.
- Guided apply now captures current macOS DNS before apply, shows restore guidance, and stores restore DNS in the last-plan menu bar action when available.
- Copied benchmark result reports include captured restore DNS context when apply guidance is available.

## Current Work
- macOS remains UX lead lane.
- Next focus: keep closing Store-safe core flows before power-edition/admin switching.

## Blockers
- Release signing identity, provisioning, and App Store entitlement approval are not available in this worktree.
- Power-edition helper is out of scope for store build.

## Next Actions
- Add CI/release wiring around distribution bundle validation once signing credentials exist.
- Keep all Core CLI gaps in `macos-core-cli-request.md`.
