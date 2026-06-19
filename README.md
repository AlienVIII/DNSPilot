# DNS Pilot

DNS Pilot is a store-safe, cross-platform DNS recommendation foundation.

This repository currently implements the reusable Rust core and a smoke CLI.
Native platform shells are expected to bind to this core instead of duplicating
benchmark scoring, provider catalogs, test suites, and capability rules.
The first macOS SwiftUI shell scaffold lives under `apps/macos/DNSPilotMac`.

## Current Scope

- Built-in DNS provider catalog.
- Built-in Vietnam ISP DNS profiles for FPT Telecom, VNPT, and Viettel
  benchmarking presets.
- Built-in test suites for General, Developer, Azure/Microsoft,
  Google/Firebase, Vietnam/Daily, and gaming presets for Steam/Valve,
  Dota 2 SEA, CS2, and Riot/LoL use cases.
- Versioned core-owned shell payload contracts for catalog and capability
  matrix JSON.
- Recommendation scoring for connection-path estimates.
- Recommendation wording distinguishes DNS-only lookup estimates from DNS + TCP
  connection-path estimates.
- Shared recommendation safety gate for `can_recommend`, health, and primary
  issue decisions before UI/apply prompts.
- Apply-prompt safety policy that protects VPN, MDM, corporate DNS, and captive
  portal networks.
- Versioned storage snapshot contract for profiles, test suites, and benchmark
  history.
- SQLite storage backend for saving/loading the versioned snapshot.
- CLI storage smoke command for creating and verifying a local SQLite snapshot.
- CLI custom plain/DoH/DoT profile add/list/update/delete commands backed by
  SQLite snapshots.
- Custom DNS profile validation for IPv4/IPv6 family mismatch and duplicate
  servers.
- Custom encrypted DNS profile validation for HTTPS DoH URLs and DoT hostnames.
- CLI custom profile filtering metadata for malware/family/ads/security DNS.
- CLI benchmark, compare, path-estimate, and path-compare commands can use saved
  custom plain DNS profiles.
- CLI custom domain suite add/list/update/delete commands backed by SQLite snapshots.
- Custom domain suite validation for invalid and duplicate domains.
- CLI benchmark, compare, path-estimate, and path-compare commands can use saved
  custom domain suites.
- CLI benchmark commands reject invalid or duplicate resolved domains before
  network activity.
- CLI system-DNS validation benchmark measures the OS resolver path after manual
  DNS changes and carries flush-before-test preflight guidance.
- CLI benchmark, compare, and path-compare history save/list/delete/clear
  commands backed by SQLite snapshots.
- Store-safe platform capability matrix.
- Platform DNS cache flush capability matrix for store-safe versus power builds.
- Benchmark preflight policy that distinguishes direct resolver tests from
  system-DNS validation after apply.
- Versioned preflight/apply-policy shell payload contracts for UI consumers.
- Shared apply-plan contract that combines benchmark gate, recommendation,
  platform capability, network environment, and DNS profile data before any UI
  or power adapter offers DNS apply.
- CLI `apply-plan` command for shell/UI consumers to obtain the shared apply
  decision as versioned JSON.
- CLI/macOS apply-plan payloads preserve the tested resolver and place it first
  in copyable plain-DNS server lists when it belongs to the recommended profile.
- macOS SwiftUI shell scaffold with centralized design tokens and capability
  matrix view model tests.
- macOS capability JSON decoder/bridge for the Rust `capabilities` schema and
  ViewModel load-error handling.
- macOS catalog JSON decoder/bridge for the Rust `catalog` schema and
  ViewModel load-error handling.
- macOS preview catalog bridge with summary metrics for native shell UI.
- macOS catalog display summaries for provider and test-suite UI rows.
- macOS shell sidebar with capability matrix and catalog overview screens.
- macOS shell sidebar has a wider default column so platform names fit in the
  default app window.
- macOS shell benchmark screen for setup, readiness, run action, and result
  rows.
- macOS shell payload decoders reject unsupported `schema_version` values.
- macOS preflight/apply-policy JSON decoders for flush and apply-safety UI.
- macOS apply-plan JSON decoder for shared guide/apply/protect payloads.
- macOS apply-plan runner boundary for invoking the Rust `apply-plan` command
  through the shared process runner.
- macOS benchmark-to-apply-plan request factory for converting benchmark health,
  confidence, recommended profile, and protected-network flags into shared
  apply-plan inputs.
- macOS benchmark result ViewModel can build apply-plan requests from the source
  benchmark payload without exposing raw payload data to SwiftUI.
- macOS benchmark apply-plan load coordinator maps benchmark results to
  `ApplyPlanViewModel` or actionable load errors through an injectable runner.
- macOS Benchmark result UI now loads shared apply-plan policy after a
  completed run and shows store-safe copy/open-settings actions.
- macOS Benchmark UI has network safeguard toggles for VPN, MDM, corporate DNS,
  and captive portal states; apply-plan reloads when they change.
- macOS copied benchmark result reports include apply-plan loading, success, or
  failure details when available.
- macOS apply-plan ViewModel for guide/apply/protect labels, action gating, and
  copyable plan text.
- macOS Benchmark apply-policy UI shows the tested resolver used to build the
  copy/open-settings plan.
- macOS Benchmark apply-policy UI shows the recommended profile beside the
  tested resolver and copyable DNS servers.
- macOS Benchmark apply-policy UI offers one guided primary action that copies
  measured DNS servers and opens Network Settings without mutating DNS itself.
- macOS guided apply actions require confirmation before copying DNS/opening
  Network Settings, including last-plan menu bar reuse.
- macOS Benchmark apply-policy UI offers a copyable guided apply/retest
  checklist for store-safe manual DNS changes.
- macOS menu bar and System DNS validation mode expose store-safe `Flush DNS...`
  guidance with confirmation before copying macOS flush commands.
- macOS Benchmark result surface treats apply-policy as authoritative when it is
  loading or available, avoiding conflicting legacy next-step apply guidance.
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
- macOS menu bar quick benchmark uses a compact DNS + TCP preset across
  developer, Microsoft login, and Vietnam daily domains.
- macOS benchmark cancellation token wired through coordinator/runner/process
  execution for best-effort process termination.
- macOS benchmark history persistence options for appending `--save-db` and
  `--history-id` to validated benchmark runs.
- macOS benchmark auto-save wiring to an Application Support `dnspilot.sqlite`
  database when the app can prepare the directory.
- macOS benchmark history-list decoder and display ViewModel for newest-first
  saved run rows.
- macOS benchmark history runner for invoking `history-list`, `history-delete`,
  and `history-clear` through the shared process boundary.
- macOS History sidebar screen with refresh, loading, empty, error, delete, clear
  all, and saved run display states.
- macOS History rows warn that saved recommendations should be retested before
  apply, because history snapshots are not live apply-plan inputs.
- macOS benchmark result display includes saved history IDs when a run is
  persisted.
- macOS DNS-only result decoder accepts missing/null connection latency and
  keeps DNS-only result rendering instead of turning it into a parse failure.
- macOS benchmark result decoder accepts all-timeout DNS results with null DNS
  latency metrics and renders failed resolver rows instead of parse failure.
- macOS Benchmark custom-domain input uses an AppKit-backed multiline text
  input for stable keyboard entry in the ScrollView-based form.
- macOS SwiftPM dev launch promotes the app from background-only to foreground
  activation so keyboard input routes into app windows.
- macOS Benchmark displays process stage statuses and structured failure
  details with failed step, reason, suggestion, elapsed time, and debug log.
- macOS Benchmark process runner drains stdout/stderr while the CLI runs, so
  large result JSON cannot deadlock the app, and shows two verbose current-step
  lines while a benchmark is running.
- macOS Benchmark shows per-DNS status rows, select-all runnable profiles, a
  copyable full issue report, and developer OSLog diagnostics for
  process/parse failure.
- CLI `compare` and `path-compare` can emit opt-in per-resolver progress JSONL
  on stderr, including finished resolver elapsed time, while preserving final
  benchmark JSON on stdout.
- macOS Benchmark warns on long worst-case benchmark plans and exposes DNS
  timeout, TCP timeout, and TCP target cap controls.
- macOS Benchmark exposes DNS record-family controls (`A + AAAA`, `A only`,
  `AAAA only`) so IPv6-broken networks do not force misleading partial failures.
- macOS Benchmark exposes resolver address-family controls (`Auto`, `IPv4`,
  `IPv6`) so profiles with IPv6 DNS servers can be tested explicitly.
- macOS Benchmark result panel protects current DNS for degraded/inconclusive
  all-weak runs while preserving best measured candidate context in notes.
- macOS Benchmark result notes call out similar partial-failure patterns across
  many DNS candidates as possible current-network/VPN/firewall/captive
  portal/IPv6 issues.
- macOS Benchmark result notes suggest an `A only` retest when IPv6 is weak
  across many DNS candidates.
- macOS Benchmark result decoder/ViewModel surfaces deduplicated per-run CLI
  caveats, such as TCP endpoint failures, in result notes.
- macOS Benchmark strong recommendations include store-safe guided apply
  details: DNS servers to paste, tested resolver, copy action, and Network
  Settings handoff without changing system DNS silently.
- macOS Benchmark and Game Ping results separate fastest observed DNS from the
  balanced recommendation so users can see raw latency versus safety-gated pick.
- macOS Catalog provider rows expose confirmed store-safe apply for selected
  plain DNS profiles.
- macOS Benchmark result failure cells annotate weak IPv4/IPv6 family health
  when partial failures line up with a specific IP family.
- macOS Benchmark result rows and copied result reports include per-resolver
  diagnosis labels for DNS lookup failures, TCP path failures, weak IP family,
  timeouts, and all-failed cases.
- macOS Benchmark result panel shortens long saved-run IDs while preserving and
  copying the full ID in result/history/storage.
- macOS custom plain DNS profile form ViewModel for IPv4/IPv6 parsing,
  validation, profile ID generation, and `profile-add` arguments.
- macOS custom plain DNS save runner/coordinator for executing `profile-add`
  and surfacing storage/process failures.
- macOS custom DNS editor ViewModel for save button state, profile ID preview,
  validation issues, and save status messages.
- macOS Custom DNS sidebar screen for entering IPv4/IPv6 plain DNS profiles and
  saving them through the shared CLI/storage boundary.
- macOS Custom DNS saved-profile management for editing/deleting custom plain
  DNS profiles.
- macOS Benchmark saved-suite management for editing/deleting custom domain
  suites.
- macOS Game Ping screen for gaming DNS/TCP path checks with selectable
  built-in gaming presets and DNS candidates. It reports connection-path
  estimates, not ICMP or in-match UDP latency.
- macOS storage-backed catalog bridge for merging persisted profiles/suites into
  the built-in catalog with fallback to built-ins on storage failure.
- macOS shell refreshes the storage-backed catalog on launch and after Custom
  DNS saves, so saved profiles can appear in Benchmark/Catalog flows.
- macOS shared app storage path uses `DNSPilot/dnspilot.sqlite` for profiles,
  suites, and history.
- macOS development bundle places the CLI in `Contents/Library/Helpers`, ships
  App Store sandbox entitlement templates for the app and helper, and has
  structural plus sandbox-signing verification scripts.
- CLI full capability matrix command for platform shell contract checks.
- CLI benchmark preflight command for flush guidance contract checks.
- CLI apply-policy command for protected-network apply prompt checks.
- Filtered DNS outcome classification.
- DNS wire query builder and compressed A/AAAA response parser.
- UDP resolver client with timeout and transaction ID validation.
- Multi-sample DNS benchmark aggregation for median, P95, failure rate,
  timeout rate, and IPv4/IPv6 health.
- DNS benchmark configs can limit measured DNS records to both A/AAAA, A only,
  or AAAA only; unmeasured families stay neutral instead of counting as failed.
- CLI benchmark commands reject zero-attempt runs before network activity.
- CLI benchmark commands reject zero timeout settings before network activity.
- CLI benchmark commands reject zero resolver/connect ports before network
  activity.
- TCP connect probe aggregation for connection-path estimates.
- Connection-path estimator that combines DNS lookup metrics with TCP connect
  metrics, optional TLS/SNI handshake metrics, and conservative caveats.
- Connection-path IPv4/IPv6 health combines DNS family health with probed
  TCP/TLS family health, so unreachable IPv6 paths are not misreported as
  healthy just because AAAA lookup succeeded.
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
- CLI benchmark, compare, path-estimate, and path-compare accept `--ip-family`
  (`both`, `ipv4-only`, `ipv6-only`) and emit `summary.ip_family`.

## Not Implemented Yet

- OS-native TLS trust store integration for enterprise/corporate roots.
- HTTP/3, browser cache, and application-layer timing.
- HTTPS probe runner.
- Incremental normalized SQLite tables beyond the current snapshot backend.
- Direct Rust FFI bindings for the macOS SwiftUI shell.
- Kotlin/Compose, WinUI, GTK/libadwaita shells.
- Platform apply adapters.
- Desktop power edition admin/helper paths.

## Commands

```sh
cargo test -p dnspilot-core
swift test --package-path apps/macos/DNSPilotMac
swift build --package-path apps/macos/DNSPilotMac
./script/build_and_run.sh --verify
./script/build_and_run.sh --sandbox-verify
./script/validate_macos_bundle.sh
./script/smoke_quick_benchmark.sh
./script/smoke_quick_benchmark.sh dns-only
cargo run -p dnspilot-cli -- catalog
cargo run -p dnspilot-cli -- capability macos-store
cargo run -p dnspilot-cli -- capabilities
cargo run -p dnspilot-cli -- preflight macos-store --scope system-dns-validation
cargo run -p dnspilot-cli -- apply-policy macos-store --vpn-active
cargo run -p dnspilot-cli -- apply-plan macos-store --profile-id cloudflare
cargo run -p dnspilot-cli -- apply-plan macos-store --profile-id cloudflare --tested-resolver 1.0.0.1:53
cargo run -p dnspilot-cli -- system-benchmark --domain localhost --ip-family ipv4-only --attempts 1
cargo run -p dnspilot-cli -- recommend-sample
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1 --ip-family ipv4-only
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --progress-jsonl
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1 --ip-family ipv4-only
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --progress-jsonl
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1 --tls-handshake-timeout-ms 1000
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --tls-handshake-timeout-ms 1000
cargo run -p dnspilot-cli -- storage-smoke --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-lab --name "Custom Lab" --ipv4 4.4.4.4 --tag custom
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id family-filter --name "Family Filter" --ipv4 1.1.1.3 --filtering family
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-doh --name "Custom DoH" --protocol doh --doh-url https://dns.example/dns-query
cargo run -p dnspilot-cli -- profile-add --db /tmp/dnspilot.sqlite --id custom-dot --name "Custom DoT" --protocol dot --dot-hostname dns.example
cargo run -p dnspilot-cli -- profile-list --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- profile-update --db /tmp/dnspilot.sqlite --id custom-lab --name "Custom Lab Updated" --ipv4 9.9.9.9 --tag custom
cargo run -p dnspilot-cli -- profile-delete --db /tmp/dnspilot.sqlite --id custom-dot
cargo run -p dnspilot-cli -- benchmark --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --profile-db /tmp/dnspilot.sqlite --profile-id custom-lab --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- suite-add --db /tmp/dnspilot.sqlite --id azure-lab --name "Azure Lab" --domain portal.azure.com --domain login.microsoftonline.com --tag azure
cargo run -p dnspilot-cli -- suite-list --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- suite-update --db /tmp/dnspilot.sqlite --id azure-lab --name "Azure Lab Updated" --domain management.azure.com --domain blob.core.windows.net --tag custom
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --suite-db /tmp/dnspilot.sqlite --suite-id azure-lab --attempts 1
cargo run -p dnspilot-cli -- suite-delete --db /tmp/dnspilot.sqlite --id azure-lab
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-run
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-dns-run
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1 --save-db /tmp/dnspilot.sqlite --history-id manual-path-run
cargo run -p dnspilot-cli -- history-list --db /tmp/dnspilot.sqlite
cargo run -p dnspilot-cli -- history-delete --db /tmp/dnspilot.sqlite --id manual-run
cargo run -p dnspilot-cli -- history-clear --db /tmp/dnspilot.sqlite
```
