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

## Current Work
- macOS remains UX lead lane.
- Next focus: release-ready signing/entitlement checks and remaining App Store packaging risks.

## Blockers
- Release signing and App Store entitlement verification are not complete.
- Power-edition helper is out of scope for store build.

## Next Actions
- Refine release signing and App Store entitlement validation.
- Keep all Core CLI gaps in `macos-core-cli-request.md`.
