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
  metrics and conservative caveats.
- CLI smoke commands for catalog, capability, and sample recommendation output.

## Not Implemented Yet

- TLS/SNI connect probe runner.
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
```
