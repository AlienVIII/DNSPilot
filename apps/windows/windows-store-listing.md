# Windows Store Listing Draft

## BLUF
- Product name: DNS Pilot
- Store edition positioning: benchmark, copy guidance, open Windows settings, validate current DNS.
- Do not market the Store build as one-click DNS apply.
- Privacy policy URL: `REPLACE_WITH_PRIVACY_POLICY_URL`
- Support URL: `REPLACE_WITH_SUPPORT_URL`

## Short Description
Store-safe DNS benchmarking and apply guidance for Windows.

## Long Description
DNS Pilot helps Windows users compare DNS resolver performance without requiring administrator elevation. Run DNS-only, DNS + TCP, or current/system DNS validation benchmarks, review a clear recommendation report, copy DNS servers, open Windows Network Settings, and retest after applying changes manually.

The Store edition is intentionally safe: it does not silently change system DNS, does not request UAC, and does not call adapter DNS mutation APIs. Power/admin apply flows are kept separate from this Store package.

## Key Features
- DNS-only and DNS + TCP benchmarks.
- Current/system DNS validation after manual Windows Settings changes.
- Per-step and per-resolver progress states.
- Localized English and Vietnamese shell text.
- Recommendation summary with resolver metrics, warnings, and copyable diagnostics.
- Copy DNS servers and open Windows Network Settings.
- Custom DNS profile add, update, and delete.
- Local benchmark history management.
- Tray quick actions for benchmark, DNS validation, and settings handoff.

## Search Terms
DNS, benchmark, resolver, Windows DNS, network diagnostics, IPv4, IPv6, latency, DNS settings, DNS profile

## Category
Utilities and tools

## Age Rating Notes
No user-generated public content. No commerce. No account sign-in. Network diagnostics only.

## Support Copy
For support, include:
- Windows version and app version.
- Benchmark mode used: DNS only, DNS + TCP, or System DNS validation.
- Copied diagnostics report if the user chooses to share it.
- Whether `dnspilot-cli.exe` was bundled, supplied by `DNSPILOT_CLI_PATH`, or built locally.

## runFullTrust justification
DNS Pilot is a packaged desktop WinUI app. `runFullTrust` is used for the normal-user desktop shell, bundled CLI helper process boundary, and tray quick actions. The app remains `asInvoker`, does not request UAC, and does not perform silent DNS mutation.

## Notes for certification
- Store build must remain `asInvoker`.
- Store build must not call `netsh`, `DnsClient`, registry DNS writes, adapter DNS mutation APIs, or elevation prompts.
- Store screenshots and description should show copy/open-settings guidance, not direct apply.
- Power edition/admin service language must be excluded from Store screenshots unless shipped as a separate distribution.
- Privacy policy must disclose DNS queries, TCP connection probes, local profile/history storage, and user-shared diagnostics.

## Partner Center Fields
- Privacy policy URL: `REPLACE_WITH_PRIVACY_POLICY_URL`
- Website URL: `REPLACE_WITH_WEBSITE_URL`
- Support URL: `REPLACE_WITH_SUPPORT_URL`
- Copyright/trademark: `REPLACE_WITH_PUBLISHER_COPYRIGHT`
- Package identity name: `DNSPilot.Windows.Store` or Partner Center assigned value.
