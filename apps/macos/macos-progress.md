# macOS Progress

## Completed
- SwiftUI shell with sidebar, benchmark, catalog, history, custom DNS, custom suites, and menu bar quick run.
- Benchmark progress, result, failure, debug log, and apply-policy surfaces.
- Store-safe copy/open-settings apply guidance with confirmation before copy/open actions.
- System DNS validation mode in Benchmark tab using current Core CLI `system-benchmark` payload via macOS-side adapter.
- Post-apply result CTA to run System DNS validation against the current macOS resolver.
- Menu bar quick action for fast System DNS validation with Developer/Azure/Vietnam smoke-test domains.
- Confirmed `Flush DNS...` guidance from Benchmark and menu bar; store-safe build copies flush commands rather than running sudo/admin mutations.
- Guided apply sequence after recommendations: copy DNS, open Network Settings, paste active service, flush/reconnect, validate System DNS.
- Apply-plan failure now falls back to local next-step guidance instead of hiding copy/open-settings actions.
- Bundle validator has distribution mode that fails debug/ad-hoc signing and missing release entitlements instead of warning only.
- Menu bar can reuse the last actionable guided apply plan for up to 24h: copy last DNS or confirmed copy+open Network Settings, without silent system DNS mutation.
- System DNS validation mode shows current macOS DNS servers/search domains when SystemConfiguration exposes them, with refresh and copy fallback.
- Guided apply now captures current macOS DNS before apply, shows restore guidance, and stores restore DNS in the last-plan menu bar action when available.
- Copied benchmark result reports include captured restore DNS context when apply guidance is available.
- macOS local CI harness runs Rust tests, Swift tests, sandbox bundle verification, and live DNS smoke tests; distribution verification activates when a signed bundle path is provided.
- Built-in saved-domain suites cover YouTube/Google Video, GitHub, and ChatGPT/OpenAI.
- Built-in gaming suites cover Steam/Valve, Dota 2 SEA, CS2, and Riot/LoL DNS/TCP latency presets.
- Game Ping sidebar screen runs DNS/TCP path checks for gaming presets with selectable DNS candidates, progress, result grid, and copyable report; it is explicit that this is not ICMP or in-match UDP latency.
- Benchmark and Game Ping results show fastest observed DNS separately from the balanced recommendation.
- Catalog provider rows can start confirmed store-safe apply for selected plain DNS profiles.
- Capabilities screen includes Product Goals readiness with current support level and caveats for fastest DNS, balanced DNS, guided apply, guided flush, saved domains, and game checks.
- Power DNS action runner exists for direct-install builds, disabled by default and gated behind `DNSPILOT_ENABLE_POWER_ACTIONS`.
- Power apply/flush UI appears only when `DNSPILOT_ENABLE_POWER_ACTIONS=1`; default store-safe builds keep copy/open-settings guidance.

## Current Work
- macOS remains UX lead lane.
- Next focus: keep closing Store-safe core flows before power-edition/admin switching.

## Blockers
- Release signing identity, provisioning, and App Store entitlement approval are not available in this worktree.
- Power-edition helper is out of scope for store build.

## Next Actions
- Keep all Core CLI gaps in `macos-core-cli-request.md`.
