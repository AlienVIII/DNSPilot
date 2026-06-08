# DNS Pilot

DNS Pilot is a store-safe, cross-platform DNS recommendation foundation.

This repository currently implements the reusable Rust core and a smoke CLI.
Native platform shells are expected to bind to this core instead of duplicating
benchmark scoring, provider catalogs, test suites, and capability rules.

## Current Scope

- Built-in DNS provider catalog.
- Built-in test suites for General, Developer, Azure/Microsoft,
  Google/Firebase, and Vietnam/Daily use cases.
- Recommendation scoring for connection-path estimates.
- Store-safe platform capability matrix.
- Filtered DNS outcome classification.
- DNS wire query builder and compressed A/AAAA response parser.
- UDP resolver client with timeout and transaction ID validation.
- Multi-sample DNS benchmark aggregation for median, P95, failure rate,
  timeout rate, and IPv4/IPv6 health.
- TCP connect probe aggregation for connection-path estimates.
- Connection-path estimator that combines DNS lookup metrics with TCP connect
  metrics, optional TLS/SNI handshake metrics, and conservative caveats.
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
- DNS+TCP multi-resolver path-compare command that can reject raw-DNS-fast but
  connect-bad candidates.

## Not Implemented Yet

- OS-native TLS trust store integration for enterprise/corporate roots.
- Multi-resolver TLS path comparison.
- HTTP/3, browser cache, and application-layer timing.
- HTTPS probe runner.
- SQLite persistence.
- SwiftUI, Kotlin/Compose, WinUI, GTK/libadwaita shells.
- Platform apply adapters.
- Desktop power edition admin/helper paths.

## Commands

```sh
cargo test -p dnspilot-core
cargo run -p dnspilot-cli -- catalog
cargo run -p dnspilot-cli -- capability macos-store
cargo run -p dnspilot-cli -- recommend-sample
cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-compare --resolver cloudflare=1.1.1.1:53 --resolver google=8.8.8.8:53 --domain github.com --attempts 1
cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1 --tls-handshake-timeout-ms 1000
```
