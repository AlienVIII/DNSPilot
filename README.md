# DNS Pilot

DNS Pilot is a store-safe, cross-platform DNS recommendation foundation.

This repository currently implements the reusable Rust core and a smoke CLI.
Native platform shells are expected to bind to this core instead of duplicating
benchmark scoring, provider catalogs, test suites, and capability rules.
The first macOS SwiftUI shell scaffold lives under `apps/macos/DNSPilotMac`.

## Current Scope

- Built-in DNS provider catalog.
- Built-in test suites for General, Developer, Azure/Microsoft,
  Google/Firebase, and Vietnam/Daily use cases.
- Versioned core-owned shell payload contracts for catalog and capability
  matrix JSON.
- Recommendation scoring for connection-path estimates.
- Shared recommendation safety gate for `can_recommend`, health, and primary
  issue decisions before UI/apply prompts.
- Apply-prompt safety policy that protects VPN, MDM, corporate DNS, and captive
  portal networks.
- Versioned storage snapshot contract for profiles, test suites, and benchmark
  history.
- SQLite storage backend for saving/loading the versioned snapshot.
- CLI storage smoke command for creating and verifying a local SQLite snapshot.
- CLI custom plain/DoH/DoT profile add/list commands backed by SQLite snapshots.
- Custom DNS profile validation for IPv4/IPv6 family mismatch and duplicate
  servers.
- Custom encrypted DNS profile validation for HTTPS DoH URLs and DoT hostnames.
- CLI custom profile filtering metadata for malware/family/ads/security DNS.
- CLI benchmark, compare, path-estimate, and path-compare commands can use saved
  custom plain DNS profiles.
- CLI custom domain suite add/list commands backed by SQLite snapshots.
- Custom domain suite validation for invalid and duplicate domains.
- CLI benchmark, compare, path-estimate, and path-compare commands can use saved
  custom domain suites.
- CLI benchmark commands reject invalid or duplicate resolved domains before
  network activity.
- CLI benchmark, compare, and path-compare history save/list commands backed by
  SQLite snapshots.
- Store-safe platform capability matrix.
- Platform DNS cache flush capability matrix for store-safe versus power builds.
- Benchmark preflight policy that distinguishes direct resolver tests from
  system-DNS validation after apply.
- Versioned preflight/apply-policy shell payload contracts for UI consumers.
- macOS SwiftUI shell scaffold with centralized design tokens and capability
  matrix view model tests.
- macOS capability JSON decoder/bridge for the Rust `capabilities` schema and
  ViewModel load-error handling.
- macOS catalog JSON decoder/bridge for the Rust `catalog` schema and
  ViewModel load-error handling.
- macOS preview catalog bridge with summary metrics for native shell UI.
- macOS catalog display summaries for provider and test-suite UI rows.
- macOS shell sidebar with capability matrix and catalog overview screens.
- macOS shell benchmark screen for setup, readiness, run action, and result
  rows.
- macOS shell payload decoders reject unsupported `schema_version` values.
- macOS preflight/apply-policy JSON decoders for flush and apply-safety UI.
- macOS policy guidance ViewModel for flush/apply labels and protected-network
  prompt suppression.
- macOS benchmark plan ViewModel for selected profiles, suites/custom domains,
  and compare/path-compare CLI arguments.
- macOS benchmark plan validation rejects invalid custom domains before process
  execution while matching Rust DNS label rules.
- macOS benchmark runner abstraction with injectable process execution for
  store-safe UI wiring and deterministic tests.
- macOS benchmark result decoder for compare/path-compare summary, run metrics,
  optional recommendation, and warning text.
- macOS benchmark result ViewModel for recommendation labels, health/scope
  labels, metric rows, and all-failed display guardrails.
- macOS benchmark execution coordinator that connects runner, JSON decoder, and
  result presentation with validation/process/parse error handling.
- macOS benchmark executable locator for bundled CLI paths and development
  `DNSPILOT_CLI_PATH` overrides.
- macOS benchmark executable resolver for missing, directory, and non-executable
  CLI path guardrails.
- macOS benchmark setup ViewModel for default selections, profile/suite options,
  custom-domain text parsing, and run readiness.
- macOS benchmark run state machine for race-safe running/cancelling/completion
  transitions.
- macOS benchmark run controls for running/cancelling UI state and stale result
  guardrails.
- macOS benchmark cancellation token wired through coordinator/runner/process
  execution for best-effort process termination.
- macOS benchmark history persistence options for appending `--save-db` and
  `--history-id` to validated benchmark runs.
- macOS benchmark auto-save wiring to an Application Support `dnspilot.sqlite`
  database when the app can prepare the directory.
- macOS benchmark history-list decoder and display ViewModel for saved run rows.
- macOS benchmark history runner for invoking `history-list --db` through the
  shared process boundary.
- macOS History sidebar screen with refresh, loading, empty, error, and saved
  run display states.
- macOS benchmark result display includes saved history IDs when a run is
  persisted.
- macOS DNS-only result decoder accepts missing/null connection latency and
  keeps DNS-only result rendering instead of turning it into a parse failure.
- macOS Benchmark custom-domain input uses a vertical TextField for stable
  keyboard entry in the ScrollView-based form.
- macOS custom plain DNS profile form ViewModel for IPv4/IPv6 parsing,
  validation, profile ID generation, and `profile-add` arguments.
- macOS custom plain DNS save runner/coordinator for executing `profile-add`
  and surfacing storage/process failures.
- macOS custom DNS editor ViewModel for save button state, profile ID preview,
  validation issues, and save status messages.
- macOS Custom DNS sidebar screen for entering IPv4/IPv6 plain DNS profiles and
  saving them through the shared CLI/storage boundary.
- macOS storage-backed catalog bridge for merging persisted profiles/suites into
  the built-in catalog with fallback to built-ins on storage failure.
- macOS shell refreshes the storage-backed catalog on launch and after Custom
  DNS saves, so saved profiles can appear in Benchmark/Catalog flows.
- macOS shared app storage path uses `DNSPilot/dnspilot.sqlite` for profiles,
  suites, and history.
- CLI full capability matrix command for platform shell contract checks.
- CLI benchmark preflight command for flush guidance contract checks.
- CLI apply-policy command for protected-network apply prompt checks.
- Filtered DNS outcome classification.
- DNS wire query builder and compressed A/AAAA response parser.
- UDP resolver client with timeout and transaction ID validation.
- Multi-sample DNS benchmark aggregation for median, P95, failure rate,
  timeout rate, and IPv4/IPv6 health.
- CLI benchmark commands reject zero-attempt runs before network activity.
- CLI benchmark commands reject zero timeout settings before network activity.
- CLI benchmark commands reject zero resolver/connect ports before network
  activity.
- TCP connect probe aggregation for connection-path estimates.
- Connection-path estimator that combines DNS lookup metrics with TCP connect
  metrics, optional TLS/SNI handshake metrics, and conservative caveats.
- CLI path commands reject zero connection target limits before network activity.
- Connection target limiting to avoid excessive TCP probes for large CDN answer
  sets, with balanced IPv4/IPv6 selection when both are available.
- TLS/SNI probe contract and live Rustls handshaker with handshake latency,
  timeout, and certificate failure classification.
- CLI smoke commands for catalog, capability, benchmark, connection-path, and
  optional TLS/SNI path-estimate output.
- Stable path-estimate summary JSON with health verdicts for
  UI/recommendation consumers.
- DNS-only multi-resolver compare command that benchmarks several resolvers and
  emits a core recommendation with explicit scope caveats and all-fail
  suppression.
- DNS+TCP multi-resolver path-compare command with optional TLS/SNI probing,
  so raw-DNS-fast but connect/TLS-bad candidates can be rejected.

## Not Implemented Yet

- OS-native TLS trust store integration for enterprise/corporate roots.
- HTTP/3, browser cache, and application-layer timing.
- HTTPS probe runner.
- Incremental normalized SQLite tables beyond the current snapshot backend.
- Runtime Rust FFI/CLI wiring for the macOS SwiftUI shell.
- Kotlin/Compose, WinUI, GTK/libadwaita shells.
- Platform apply adapters.
- Desktop power edition admin/helper paths.

## Commands

```sh
cargo test -p dnspilot-core
swift test --package-path apps/macos/DNSPilotMac
swift build --package-path apps/macos/DNSPilotMac
cargo run -p dnspilot-cli -- catalog
cargo run -p dnspilot-cli -- capability macos-store
cargo run -p dnspilot-cli -- capabilities
cargo run -p dnspilot-cli -- preflight macos-store --scope system-dns-validation
cargo run -p dnspilot-cli -- apply-policy macos-store --vpn-active
cargo run -p dnspilot-cli -- recommend-sample
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1 --tls-handshake-timeout-ms 1000
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --tls-handshake-timeout-ms 1000
cargo run -p dnspilot-cli -- storage-smoke --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-lab --name "Custom Lab" --ipv4 4.4.4.4 --tag custom
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id family-filter --name "Family Filter" --ipv4 1.1.1.3 --filtering family
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-doh --name "Custom DoH" --protocol doh --doh-url https://dns.example/dns-query
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-dot --name "Custom DoT" --protocol dot --dot-hostname dns.example
cargo run -p dnspilot-cli -- profile-list --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- benchmark --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- suite-add --db /tmp/dnspilot.sqlite --id azure-lab --name "Azure Lab" --domain portal.azure.com --domain login.microsoftonline.com --tag azure
cargo run -p dnspilot-cli -- suite-list --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-run
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-dns-run
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-path-run
cargo run -p dnspilot-cli -- history-list --db /tmp/dnspilot.sqlite
```
