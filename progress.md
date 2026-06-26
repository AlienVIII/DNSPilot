# Implementation Progress

## Plan Overview

Build DNS Pilot as a cross-platform product with a shared reusable core and
native platform shells. The first implementation slice creates the Rust core
contract for provider catalogs, test suites, recommendation scoring, filtered
DNS handling, and platform capability reporting.

## Chunks

- [x] [1] Workspace and RED tests — created Rust workspace and behavior tests.
- [x] [2] Shared core — implemented catalog, scoring, capability matrix, and validation.
- [x] [3] CLI smoke tool — added JSON commands for catalog, capability, and sample recommendation.
- [x] [4] Verification — core tests and CLI smoke commands pass.
- [x] [5] v0.1 DNS wire codec — deterministic DNS query builder and response parser.
- [x] [6] v0.1 UDP resolver client — local-testable UDP query execution.
- [x] [7] v0.1 DNS benchmark runner — multi-sample aggregation for latency and reliability.
- [x] [8] v0.1 live benchmark CLI — JSON benchmark command for manual resolver smoke tests.
- [x] [9] v0.1 TCP connect probe — local-testable connection latency aggregation.
- [x] [10] v0.1 connection-path estimator — DNS + TCP connect combined metrics with caveats.
- [x] [11] v0.1 connection-path CLI — manual DNS + TCP estimate command.
- [x] [12] v0.1 connection target guardrails — per-domain TCP target limiting and precise caveats.
- [x] [13] v0.1 dual-stack target selection — balanced IPv4/IPv6 endpoint limiting.
- [x] [14] v0.1 TLS/SNI probe contract — handshake metrics and certificate failure classification.
- [x] [15] v0.1 live TLS/SNI handshaker — Rustls handshake to resolved IP with SNI.
- [x] [16] v0.1 connection-path TLS integration — opt-in TLS/SNI reliability in core estimates.
- [x] [17] v0.1 TLS path-estimate CLI — flag and JSON samples for TLS/SNI probing.
- [x] [18] v0.1 path-estimate summary JSON — stable UI/recommendation summary fields.
- [x] [19] v0.1 path health verdicts — stable health and primary issue summary fields.
- [x] [20] v0.1 DNS resolver compare CLI — DNS-only multi-resolver recommendation.
- [x] [21] v0.1 connection-path compare CLI — DNS+TCP multi-resolver recommendation.
- [x] [22] v0.1 TLS path-compare CLI — optional TLS/SNI multi-resolver comparison.
- [x] [23] v0.1 recommendation safety gate — shared core gate for recommend/apply readiness.
- [x] [24] v0.1 storage snapshot contract — versioned local data schema.
- [x] [25] v0.1 SQLite storage backend — save/load versioned snapshots.
- [x] [26] v0.1 storage smoke CLI — create and verify SQLite snapshot.
- [x] [27] v0.1 custom profile persistence CLI — add/list custom DNS profiles.
- [x] [28] v0.1 benchmark history persistence CLI — save/list benchmark history.
- [x] [29] v0.1 path-compare history persistence CLI — save/list path comparison history.
- [x] [30] v0.1 compare history persistence CLI — save/list DNS-only comparison history.
- [x] [31] v0.1 custom suite persistence CLI — add/list custom domain suites.
- [x] [32] v0.1 benchmark saved-suite input — run benchmark from saved suite domains.
- [x] [33] v0.1 compare saved-suite input — run DNS comparison from saved suite domains.
- [x] [34] v0.1 path-compare saved-suite input — run path comparison from saved suite domains.
- [x] [35] v0.1 path-estimate saved-suite input — run path estimate from saved suite domains.
- [x] [36] v0.1 benchmark saved-profile input — run benchmark from saved plain DNS profile.
- [x] [37] v0.1 compare saved-profile input — run DNS comparison from saved plain DNS profiles.
- [x] [38] v0.1 path-estimate saved-profile input — run path estimate from saved plain DNS profile.
- [x] [39] v0.1 path-compare saved-profile input — run path comparison from saved plain DNS profiles.
- [x] [40] v0.1 custom encrypted profile persistence CLI — add/list DoH and DoT profiles.
- [x] [41] v0.1 custom filtering profile metadata — persist filtering DNS category.
- [x] [42] v0.1 DNS flush capability matrix — model flush support per platform.
- [x] [43] v0.1 full capability matrix CLI — emit all platform capabilities at once.
- [x] [44] v0.1 benchmark preflight policy — avoid flushing for direct resolver tests.
- [x] [45] v0.1 benchmark preflight CLI — expose flush guidance as JSON.
- [x] [46] v0.1 apply prompt safety policy — protect managed/intercepted networks.
- [x] [47] v0.1 apply prompt policy CLI — expose protected-network policy as JSON.
- [x] [48] v0.1 custom suite domain validation — reject invalid/duplicate domains.
- [x] [49] v0.1 custom profile server validation — reject family mismatch/duplicates.
- [x] [50] v0.1 zero-attempt CLI guards — reject empty benchmark runs consistently.
- [x] [51] v0.1 zero-timeout CLI guards — reject impossible benchmark timeouts.
- [x] [52] v0.1 zero connection-target CLI guards — reject empty path probes.
- [x] [53] v0.1 zero-port CLI guards — reject invalid resolver/connect ports.
- [x] [54] v0.1 resolved-domain CLI validation — reject invalid/duplicate domains.
- [x] [55] v0.1 encrypted profile endpoint validation — reject insecure DoH/invalid DoT.
- [x] [56] v0.1 macOS SwiftUI shell scaffold — add design tokens and capability ViewModel.
- [x] [57] v0.1 macOS capability JSON bridge — decode Rust capability schema into Swift ViewModel.
- [x] [58] v0.1 macOS catalog JSON bridge — decode Rust catalog schema into Swift ViewModel.
- [x] [59] v0.1 core shell payload contracts — expose catalog/capability payloads from Rust core.
- [x] [60] v0.1 shell payload schema version — version catalog/capability JSON contracts.
- [x] [61] v0.1 macOS schema version gate — reject unsupported shell payload versions.
- [x] [62] v0.1 macOS preview catalog summary — add default catalog bridge and summary metrics.
- [x] [63] v0.1 macOS catalog display summaries — prepare provider/suite labels for UI.
- [x] [64] v0.1 macOS catalog overview UI — render catalog summaries in the shell.
- [x] [65] v0.1 versioned policy payloads — version preflight/apply-policy JSON contracts.
- [x] [66] v0.1 macOS policy JSON decoders — decode preflight/apply-policy contracts.
- [x] [67] v0.1 macOS policy guidance ViewModel — summarize flush/apply safety.
- [x] [68] v0.1 macOS benchmark plan ViewModel — build compare/path-compare CLI args.
- [x] [69] v0.1 macOS benchmark runner — execute validated benchmark plans through an injectable process boundary.
- [x] [70] v0.1 macOS benchmark result decoder — parse compare/path-compare CLI JSON for UI display.
- [x] [71] v0.1 macOS benchmark result ViewModel — present result summaries, rows, and all-fail guardrails.
- [x] [72] v0.1 macOS benchmark execution coordinator — connect runner, decoder, and result presentation.
- [x] [73] v0.1 macOS benchmark executable locator — locate bundled CLI or development override.
- [x] [74] v0.1 macOS benchmark executable resolver — validate CLI path availability before launch.
- [x] [75] v0.1 macOS custom domain plan validation — reject invalid custom benchmark domains before launch.
- [x] [76] v0.1 macOS benchmark setup ViewModel — prepare screen defaults, options, and readiness.
- [x] [77] v0.1 macOS benchmark setup UI — render setup, readiness, run action, and result rows.
- [x] [78] v0.1 macOS benchmark run state machine — guard running/cancelled/stale result transitions.
- [x] [79] v0.1 macOS benchmark run controls — wire running/cancelling UI state and stale result guardrails.
- [x] [80] v0.1 macOS benchmark process cancellation — terminate active benchmark process from Cancel.
- [x] [81] v0.1 macOS benchmark history persistence args — append save-db/history-id through runner.
- [x] [82] v0.1 macOS benchmark history app path — auto-save runs to Application Support when available.
- [x] [83] v0.1 macOS benchmark history decoder — parse history-list JSON and build display rows.
- [x] [84] v0.1 macOS benchmark history runner — invoke history-list through process boundary.
- [x] [85] v0.1 macOS history UI — add sidebar screen for loading and viewing saved runs.
- [x] [86] v0.1 macOS result saved-history label — show saved history ID in benchmark results.
- [x] [87] v0.1 macOS custom DNS form ViewModel — validate v4/v6 input and build profile-add args.
- [x] [88] v0.1 macOS custom DNS save runner — persist custom profiles through the CLI boundary.
- [x] [89] v0.1 macOS custom DNS editor state — derive save button/status UI state.
- [x] [90] v0.1 macOS shared storage filename — use dnspilot.sqlite for profiles/suites/history.
- [x] [91] v0.1 macOS custom DNS UI — add sidebar form and save action.
- [x] [92] v0.1 macOS storage-backed catalog bridge — merge persisted profiles/suites into catalog.
- [x] [93] v0.1 macOS catalog refresh wiring — refresh storage-backed catalog on launch/save.
- [x] [94] v0.1 macOS DNS-only null latency decode — accept null connection latency in results.
- [x] [95] v0.1 macOS benchmark domain input typing — replace TextEditor with vertical TextField.
- [x] [96] v0.1 macOS benchmark progress failure details — show stage statuses and debug failure detail.
- [x] [97] v0.1 macOS benchmark AppKit domain input — use AppKit-backed multiline input.
- [x] [98] v0.1 macOS dev foreground activation — launch SwiftPM dev app as foreground.
- [x] [99] v0.1 macOS benchmark pipe drain and verbose progress — prevent pipe deadlock and show running detail.
- [x] [100] v0.1 macOS custom DNS management — edit/delete saved custom plain DNS profiles.
- [x] [101] v0.1 macOS benchmark diagnostics and DNS statuses — decode all-timeout results, add issue logs, select-all, and per-DNS status.
- [x] [102] v0.1 macOS benchmark result trust states — soften degraded recommendations and show degraded row status.
- [x] [103] v0.1 macOS benchmark common-failure note — explain similar partial failures as possible network conditions.
- [x] [104] v0.1 macOS result saved-run label polish — shorten long saved-run IDs in the result panel.
- [x] [105] v0.1 macOS result run caveats — decode and show per-run benchmark caveats in result notes.
- [x] [106] v0.1 path family health — reduce IPv4/IPv6 path health when probed TCP/TLS family paths fail.
- [x] [107] v0.1 macOS result family failure label — show weak IPv4/IPv6 family in failure cells.
- [x] [108] v0.1 macOS sidebar width — prevent platform names from truncating in default window.
- [x] [109] v0.1 gaming suites — add Steam/Valve, Dota 2 SEA, CS2, and Riot/LoL DNS/TCP presets.
- [x] [110] v0.1 macOS Game Ping — add gaming preset screen backed by path-compare.
- [x] [111] v0.1 macOS confirmed apply and flush guidance — confirm copy/open apply and store-safe flush checklist actions.
- [x] [112] v0.1 macOS fastest vs balanced result labels — separate raw fastest DNS from safety-gated recommendation.
- [x] [113] v0.1 macOS selected profile guided apply — apply selected plain DNS profiles from Catalog with confirmation.
- [x] [114] v0.1 saved-domain suites — add YouTube, GitHub, and ChatGPT/OpenAI presets.
- [x] [115] v0.1 macOS product goal readiness — show support level and caveats for main goals.
- [x] [116] v0.1 macOS power DNS action runner — add disabled-by-default admin apply/flush adapter.
- [x] [117] v0.1 macOS power apply/flush UI — expose admin actions only behind explicit Power flag.
- [x] [118] v0.1 macOS power capability alignment — reflect Power path in readiness and capability matrix.
- [x] [119] v0.1 macOS permission/publish readiness — add native screens and copyable checklists.
- [x] [120] v0.1 macOS localization foundation — add English/Vietnamese top-level language support.
- [x] [121] v0.1 macOS publishing source-of-truth — document App Store and Power edition release steps.
- [x] [122] v0.1 macOS native localization pass — localize primary app surfaces and split large SwiftUI benchmark body.
- [x] [123] v0.1 macOS App Store metadata template — add review notes, privacy notes, and screenshot checklist.
- [x] [124] v0.1 macOS distribution packaging script — sign, validate, and package release bundle when identities are provided.
- [x] [125] v0.1 macOS Power edition bundle switch — enable direct-install admin apply/flush from bundle metadata.

---

## Chunk 1: Workspace and RED Tests

**Status:** Complete
**Files changed:** `Cargo.toml`, `crates/dnspilot-core/tests/core_behaviour.rs`

### What changed

Created the workspace and behavior-first tests for the core contract. The tests
cover catalog completeness, keep-current recommendation behavior, positive
recommendation behavior, filtered DNS expected-block semantics, and platform
capabilities.

### Before

Before: nothing.

### After

```mermaid
graph LR
  TESTS[Core behavior tests NEW] --> CORE[dnspilot-core placeholder NEW]
```

---

## Chunk 2: Shared Core

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`

### What changed

Implemented the reusable store-safe core: DNS profile/test suite models, built-in
catalog, recommendation scoring, filtered DNS classification, profile validation,
and per-platform apply capability matrix.

### Before

```mermaid
graph LR
  TESTS[Core behavior tests] --> CORE[dnspilot-core placeholder]
```

### After

```mermaid
graph LR
  TESTS[Core behavior tests] --> CORE[dnspilot-core CHANGED]
  CORE --> CATALOG[Provider and suite catalog NEW]
  CORE --> SCORE[Recommendation scoring NEW]
  CORE --> CAP[Platform capability matrix NEW]
  CORE --> FILTER[Filtered outcome classifier NEW]
```

---

## Chunk 3: CLI Smoke Tool

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`

### What changed

Added a small CLI wrapper around the shared core. It emits catalog JSON,
platform capability JSON, and a deterministic sample recommendation for quick
manual checks and future integration smoke tests.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> CATALOG[Catalog]
  CORE --> SCORE[Scoring]
  CORE --> CAP[Capabilities]
```

---

## Chunk 4: Verification

**Status:** Complete
**Files changed:** none

### What changed

Verified the current foundation with `cargo test -p dnspilot-core --tests` and
CLI smoke commands. The Rust toolchain initially hung during first launch, then
recovered; `rustfmt` still hangs at process startup and was not used.

### Before

```mermaid
graph LR
  CLI[dnspilot-cli] --> CORE[dnspilot-core]
  TESTS[Core behavior tests] --> CORE
```

### After

```mermaid
graph LR
  CLI[dnspilot-cli] --> CORE[dnspilot-core]
  TESTS[Core behavior tests] --> CORE
  VERIFY[Cargo verification COMPLETE] --> CORE
  VERIFY --> CLI
```

### Verification

```text
cargo test -p dnspilot-core --tests
Result: 10 passed, 0 failed

cargo run -p dnspilot-cli -- catalog
Result: emitted 9 profiles; first profile cloudflare

cargo run -p dnspilot-cli -- capability macos-store
Result: platform macos-store, apply apple-network-extension-dns-settings

cargo run -p dnspilot-cli -- recommend-sample
Result: recommends quad9 with high confidence
```

---

## Chunk 5: v0.1 DNS Wire Codec

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/dns_wire.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/dns_wire_behaviour.rs`

### What changed

Added deterministic DNS wire support for building plain A/AAAA query packets and
parsing compressed A/AAAA responses. This still performs no live network I/O;
it is the codec layer the future UDP benchmark runner will call.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> SCORE[Scoring]
  CORE --> CATALOG[Catalog]
  CORE --> CAP[Capabilities]
```

### After

```mermaid
graph LR
  CORE[dnspilot-core CHANGED] --> SCORE[Scoring]
  CORE --> CATALOG[Catalog]
  CORE --> CAP[Capabilities]
  CORE --> WIRE[DNS wire codec NEW]
  WIRE --> QUERY[Build A/AAAA query NEW]
  WIRE --> PARSE[Parse compressed A/AAAA response NEW]
```

### Verification

```text
cargo test -p dnspilot-core --test dns_wire_behaviour
Result: 4 passed, 0 failed

cargo test -p dnspilot-core --tests
Result: 10 passed, 0 failed
```

---

## Chunk 6: v0.1 UDP Resolver Client

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/dns_resolver.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/dns_udp_resolver_behaviour.rs`

### What changed

Added a synchronous UDP DNS client that sends one query to a resolver, enforces
timeout, validates the response transaction ID, rejects non-zero DNS response
codes, and returns elapsed time with the parsed response. Tests use a local fake
UDP resolver, so this layer is verified without internet dependency.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> WIRE[DNS wire codec]
  WIRE --> QUERY[Build A/AAAA query]
  WIRE --> PARSE[Parse compressed A/AAAA response]
```

### After

```mermaid
graph LR
  CORE[dnspilot-core CHANGED] --> WIRE[DNS wire codec]
  CORE --> UDP[UDP resolver client NEW]
  UDP --> WIRE
  UDP --> TIMEOUT[Timeout handling NEW]
  UDP --> TXID[Transaction ID validation NEW]
```

### Verification

```text
cargo test -p dnspilot-core --test dns_udp_resolver_behaviour
Result: 3 passed, 0 failed

cargo test -p dnspilot-core --tests
Result: 13 passed, 0 failed
```

---

## Chunk 7: v0.1 DNS Benchmark Runner

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/dns_benchmark.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/dns_benchmark_behaviour.rs`

### What changed

Added a multi-sample benchmark runner that executes A and AAAA lookups across
domains, records per-sample success/timeout/failure, and aggregates median DNS
latency, P95 latency, failure rate, timeout rate, and IPv4/IPv6 health. The
runner is testable with an injected lookup function and has a wrapper that uses
the UDP resolver client.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> UDP[UDP resolver client]
  UDP --> WIRE[DNS wire codec]
```

### After

```mermaid
graph LR
  CORE[dnspilot-core CHANGED] --> BENCH[DNS benchmark runner NEW]
  BENCH --> UDP[UDP resolver client]
  UDP --> WIRE[DNS wire codec]
  BENCH --> METRICS[BenchmarkMetrics CHANGED]
```

### Verification

```text
cargo test -p dnspilot-core --test dns_benchmark_behaviour
Result: 2 passed, 0 failed

cargo test --workspace --tests
Result: 15 passed, 0 failed
```

---

## Chunk 8: v0.1 Live Benchmark CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`

### What changed

Added `dnspilot-cli benchmark`, which accepts a resolver socket address, one or
more domains, attempt count, timeout, and optional profile ID. The command runs
the UDP benchmark path and emits JSON with metrics, per-sample outcomes, and a
plain warning that DNS results estimate resolver behavior rather than full
internet speed.

### Before

```mermaid
graph LR
  CLI[dnspilot-cli] --> CATALOG[Catalog output]
  CLI --> CAP[Capability output]
  CLI --> SAMPLE[Sample recommendation]
```

### After

```mermaid
graph LR
  CLI[dnspilot-cli CHANGED] --> BENCHCMD[benchmark command NEW]
  BENCHCMD --> BENCH[DNS benchmark runner]
  BENCH --> UDP[UDP resolver client]
  CLI --> CATALOG[Catalog output]
  CLI --> CAP[Capability output]
```

### Verification

```text
cargo test -p dnspilot-cli --test cli_benchmark_behaviour
Result: 1 passed, 0 failed

cargo test --workspace --tests
Result: 16 passed, 0 failed

cargo run -p dnspilot-cli -- benchmark --resolver 1.1.1.1:53 --domain github.com --attempts 1 --timeout-ms 1000
Result: sample_count 2, failure_rate 0.0, timeout_rate 0.0 in this run
```

---

## Chunk 9: v0.1 TCP Connect Probe

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connect_probe.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/connect_probe_behaviour.rs`

### What changed

Added a TCP connect probe layer for connection-path estimates. It can measure a
single TCP connect attempt, classify timeout/failure outcomes, and aggregate
multi-sample median, P95, failure rate, and timeout rate without doing TLS yet.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> BENCH[DNS benchmark runner]
  BENCH --> UDP[UDP resolver client]
```

### After

```mermaid
graph LR
  CORE[dnspilot-core CHANGED] --> BENCH[DNS benchmark runner]
  CORE --> TCP[TCP connect probe NEW]
  BENCH --> UDP[UDP resolver client]
  TCP --> METRIC[Connection-path metrics NEW]
```

### Verification

```text
cargo test -p dnspilot-core --test connect_probe_behaviour
Result: 3 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 19 passed, 0 failed
```

---

## Chunk 10: v0.1 Connection-Path Estimator

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connection_path.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/connection_path_behaviour.rs`

### What changed

Added a connection-path estimator that resolves A/AAAA records, extracts usable
IP endpoints, probes TCP connect latency to the configured port, and combines
DNS metrics with connect metrics. Combined failure and timeout rates are
conservative: the estimator uses the worse of DNS and connect rates so a fast
resolver with unreachable endpoints is not over-recommended.

### Before

```mermaid
graph LR
  CORE[dnspilot-core] --> DNS[DNS benchmark runner]
  CORE --> TCP[TCP connect probe]
```

### After

```mermaid
graph LR
  CORE[dnspilot-core CHANGED] --> PATH[Connection-path estimator NEW]
  PATH --> DNS[DNS benchmark runner]
  PATH --> TCP[TCP connect probe]
  PATH --> CAVEATS[Truthful caveats NEW]
```

### Edge Cases Covered

- DNS success with no usable A/AAAA answers skips TCP probes and records a caveat.
- IPv6 DNS timeout lowers IPv6 health and DNS timeout rate.
- TCP connect timeout after DNS success raises combined failure/timeout rates.
- The estimator explicitly does not claim full web/app speed because TLS, HTTP,
  QUIC, browser cache, and server latency are not measured yet.

### Verification

```text
cargo test -p dnspilot-core --test connection_path_behaviour
Result: 3 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 22 passed, 0 failed
```

---

## Chunk 11: v0.1 Connection-Path CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`

### What changed

Added `dnspilot-cli path-estimate`, which runs the connection-path estimator from
the command line and emits JSON with combined metrics, DNS samples, TCP connect
samples, connect targets, and caveats. The integration test uses a local fake DNS
resolver plus a local TCP listener so it is deterministic and does not depend on
public network state.

### Before

```mermaid
graph LR
  CLI[dnspilot-cli] --> BENCHCMD[benchmark command]
  BENCHCMD --> DNS[DNS benchmark runner]
```

### After

```mermaid
graph LR
  CLI[dnspilot-cli CHANGED] --> PATHCMD[path-estimate command NEW]
  PATHCMD --> PATH[Connection-path estimator]
  PATH --> DNS[DNS benchmark runner]
  PATH --> TCP[TCP connect probe]
```

### Edge Cases / Caveats

- CLI output includes caveats stating this is not TLS, HTTP, QUIC, browser-cache,
  or server-latency measurement.
- A resolver can still look good here while failing TLS/SNI later; that is a
  known next-step gap.
- Public live smoke can vary by network, VPN, IPv6 availability, and firewall.

### Verification

```text
cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 1 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 23 passed, 0 failed

cargo run -p dnspilot-cli -- path-estimate --resolver 1.1.1.1:53 --domain github.com --attempts 1 --dns-timeout-ms 1000 --connect-timeout-ms 1000 --connect-port 443
Result in this run: dns_sample_count 2, connect_sample_count 1, target_count 1, failure_rate 0.0
```

---

## Chunk 12: v0.1 Connection Target Guardrails

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connection_path.rs`, `crates/dnspilot-core/tests/connection_path_behaviour.rs`, `crates/dnspilot-cli/src/main.rs`

### What changed

Added `max_connect_targets_per_domain` to limit how many resolved endpoints are
TCP-probed per domain. The CLI exposes it as
`--max-connect-targets-per-domain` with default `4`, and caveats now report only
when endpoints were actually skipped due to the limit.

### Before

```mermaid
graph LR
  PATH[Connection-path estimator] --> TARGETS[All unique resolved endpoints]
  TARGETS --> TCP[TCP connect probes]
```

### After

```mermaid
graph LR
  PATH[Connection-path estimator CHANGED] --> LIMIT[Per-domain target limit NEW]
  LIMIT --> TCP[TCP connect probes]
  LIMIT --> CAVEAT[Precise limit caveat NEW]
```

### Edge Cases / Caveats

- Large CDN answer sets are capped to avoid excessive TCP probes, battery drain,
  slow tests, and noisy network behavior.
- If endpoint count exactly equals the limit, no limit caveat is emitted because
  nothing was skipped.
- This still does not choose “best IP”; it preserves DNS answer order and limits
  probe volume. Smarter target selection is a later step.

### Verification

```text
cargo test -p dnspilot-core --test connection_path_behaviour limits_connect_targets_per_domain_and_records_caveat
Result: 1 passed, 0 failed

cargo test -p dnspilot-core --test connection_path_behaviour does_not_record_limit_caveat_when_no_endpoint_was_skipped
Result: 1 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 24 passed, 0 failed
```

### After

```mermaid
graph LR
  CLI[dnspilot-cli NEW] --> CORE[dnspilot-core]
  CORE --> CATALOG[Catalog]
  CORE --> SCORE[Scoring]
  CORE --> CAP[Capabilities]
```

---

## Chunk 13: v0.1 Dual-Stack Target Selection

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connection_path.rs`, `crates/dnspilot-core/tests/connection_path_behaviour.rs`, `README.md`

### What changed

Changed connection-path target limiting from "first N endpoints per domain" to a
balanced selector that preserves both IPv4 and IPv6 when both are available.
This avoids a real bias where A records could fill the per-domain limit before
AAAA records were considered.

### Before

```mermaid
graph LR
  DNS[DNS answers] --> FIRST[First N endpoints per domain]
  FIRST --> TCP[TCP probes]
  FIRST --> BIAS[Possible IPv4-only selection]
```

### After

```mermaid
graph LR
  DNS[DNS answers] --> CANDIDATES[Unique endpoint candidates CHANGED]
  CANDIDATES --> BALANCE[Balanced IPv4/IPv6 selector NEW]
  BALANCE --> TCP[TCP probes]
  BALANCE --> CAVEAT[Balanced limit caveat CHANGED]
```

### Edge Cases / Caveats

- With limit `2` and both families available, the selector keeps one IPv4 and
  one IPv6 endpoint.
- With limit `1`, it cannot represent both families; the estimate should be
  considered weaker for dual-stack diagnosis.
- This still does not prove the best CDN endpoint. It only avoids family bias
  while keeping probe volume bounded.

### Verification

```text
cargo test -p dnspilot-core --test connection_path_behaviour limit_keeps_both_ipv4_and_ipv6_when_available
Result: 1 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 25 passed, 0 failed
```

---

## Chunk 14: v0.1 TLS/SNI Probe Contract

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/tls_probe.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/tls_probe_behaviour.rs`, `README.md`

### What changed

Added a TLS/SNI probe contract with targets, config, samples, outcomes, errors,
and aggregation. The runner accepts an injected handshaker so latency, timeout,
and certificate failure behavior can be tested deterministically before adding a
live TLS dependency.

### Before

```mermaid
graph LR
  PATH[Connection-path estimator] --> TCP[TCP connect probe]
  TCP --> METRICS[Connect latency metrics]
```

### After

```mermaid
graph LR
  PATH[Connection-path estimator] --> TCP[TCP connect probe]
  CORE[dnspilot-core CHANGED] --> TLS[TLS/SNI probe contract NEW]
  TLS --> SAMPLES[TLS samples NEW]
  TLS --> CERT[Certificate failure rate NEW]
```

### Edge Cases / Caveats

- Certificate failures are tracked separately from generic handshake failures.
  This matters for captive portals, corporate MITM, wrong endpoints, and SNI
  mismatch cases.
- The target keeps `server_name` separate from endpoint IP so future live TLS
  can connect to resolved IPs while sending the original domain as SNI.
- This chunk does not perform live TLS yet. The next chunk should add a real
  Rustls/native TLS handshaker and local deterministic TLS test coverage.

### Verification

```text
cargo test -p dnspilot-core --test tls_probe_behaviour
Result: 2 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 27 passed, 0 failed
```

---

## Chunk 15: v0.1 Live TLS/SNI Handshaker

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/tls_probe.rs`, `crates/dnspilot-core/tests/tls_probe_behaviour.rs`, `crates/dnspilot-core/Cargo.toml`, `Cargo.lock`, `README.md`

### What changed

Added a live Rustls TLS handshaker that connects to a resolved IP endpoint while
verifying the certificate against the target `server_name` used for SNI. The
test runs against a local Rustls server with a generated localhost certificate,
so it verifies real TLS behavior without external network dependency.

### Before

```mermaid
graph LR
  TLS[TLS/SNI probe contract] --> INJECT[Injected handshaker only]
  INJECT --> METRICS[TLS metrics]
```

### After

```mermaid
graph LR
  TLS[TLS/SNI probe CHANGED] --> LIVE[Live Rustls handshaker NEW]
  LIVE --> IP[Resolved IP endpoint]
  LIVE --> SNI[SNI server_name]
  LIVE --> CERT[Certificate verification]
  TLS --> INJECT[Injected handshaker]
```

### Edge Cases / Caveats

- The live handshaker now separates endpoint IP from SNI name. This is required
  because DNS Pilot resolves IPs first, but TLS certificates are issued for
  hostnames.
- Certificate rejection is mapped separately from generic handshake failure.
- Default trust currently uses Mozilla `webpki-roots`, not the OS trust store.
  Corporate/MDM roots can therefore be rejected here even when Safari/Chrome on
  that machine would trust them. OS-native trust should be a later platform
  adapter step.
- Rustls default crypto backend pulls `aws-lc-rs`, which increases build cost
  and should be revisited before broad mobile/Linux distribution.

### Verification

```text
cargo test -p dnspilot-core --test tls_probe_behaviour performs_live_tls_handshake_to_endpoint_with_sni_server_name
Result: 1 passed, 0 failed

cargo test -p dnspilot-core --test tls_probe_behaviour
Result: 3 passed, 0 failed

/Users/aart/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo test --workspace --tests
Result: 28 passed, 0 failed
```

---

## Chunk 16: v0.1 Connection-Path TLS Integration

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connection_path.rs`, `crates/dnspilot-core/tests/connection_path_behaviour.rs`, `crates/dnspilot-cli/src/main.rs`, `README.md`

### What changed

Integrated TLS/SNI probing into the connection-path estimator as an opt-in core
capability. When `tls_handshake_timeout` is set, the estimator probes TLS for
the selected resolved endpoints, includes TLS failure/timeout rates in combined
reliability, and records certificate-specific caveats.

### Before

```mermaid
graph LR
  PATH[Connection-path estimator] --> DNS[DNS benchmark]
  PATH --> TCP[TCP connect probe]
  PATH --> METRICS[Combined DNS/TCP reliability]
```

### After

```mermaid
graph LR
  PATH[Connection-path estimator CHANGED] --> DNS[DNS benchmark]
  PATH --> TCP[TCP connect probe]
  PATH --> TLS[TLS/SNI probe OPTIONAL NEW]
  TLS --> CERT[Certificate failure caveat NEW]
  TLS --> METRICS[Combined DNS/TCP/TLS reliability CHANGED]
```

### Edge Cases / Caveats

- TLS is opt-in at core level. Existing CLI `path-estimate` keeps
  `tls_handshake_timeout: None`, so manual CLI behavior is unchanged in this
  chunk.
- A path with DNS success and TCP success can still be marked unreliable if TLS
  certificate verification fails.
- Certificate failures can be valid signals for captive portals, SNI mismatch,
  or wrong edge mapping, but can be false negatives in corporate/MDM networks
  until OS-native trust store adapters exist.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test connection_path_behaviour tls_certificate_failures_reduce_combined_reliability_when_enabled
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 30 passed, 0 failed
```

---

## Chunk 17: v0.1 TLS Path-Estimate CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Exposed TLS/SNI probing in `dnspilot-cli path-estimate` with
`--tls-handshake-timeout-ms`. CLI JSON now includes `tls_samples` with
`server_name`, endpoint, elapsed time, and TLS outcome when TLS probing is
enabled.

### Before

```mermaid
graph LR
  CLI[path-estimate CLI] --> CORE[Connection-path core]
  CLI --> DNS[DNS samples]
  CLI --> TCP[TCP samples]
```

### After

```mermaid
graph LR
  CLI[path-estimate CLI CHANGED] --> CORE[Connection-path core]
  CLI --> DNS[DNS samples]
  CLI --> TCP[TCP samples]
  CLI --> TLS[TLS samples OPTIONAL NEW]
```

### Edge Cases / Caveats

- TLS probing remains opt-in because it adds network work and can produce
  certificate failures in captive portal, proxy, VPN, or corporate/MDM
  environments.
- CLI output keeps `tls_samples: []` when the flag is not provided, preserving
  the existing default path-estimate behavior.
- Current TLS verification still uses bundled Mozilla roots, not OS-native
  enterprise roots.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_can_include_tls_samples_when_enabled
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 31 passed, 0 failed
```

## Chunk 19: v0.1 Path Health Verdicts

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added `summary.health` and `summary.primary_issue` to `dnspilot-cli
path-estimate`. This gives UI and recommendation flows stable verdict fields
instead of forcing them to infer state from metrics, samples, and caveat text.

### Before

```mermaid
graph LR
  SUMMARY[Path summary] --> COUNTS[Counts and scope]
  UI[UI] --> METRICS[Infer health from metrics/caveats]
```

### After

```mermaid
graph LR
  SUMMARY[Path summary CHANGED] --> COUNTS[Counts and scope]
  SUMMARY --> HEALTH[health NEW]
  SUMMARY --> ISSUE[primary_issue NEW]
  HEALTH --> UI[UI/recommendation layer]
```

### Edge Cases / Caveats

- `healthy` currently means no DNS/TCP/TLS failure or timeout was observed in
  the measured path.
- `failed` is emitted for total DNS/connect/TLS failure conditions, including
  TLS handshake failure after TCP connect succeeds.
- `degraded` is reserved for partial failures. This is a product-facing verdict,
  not a full recommendation across multiple DNS profiles yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_outputs_dns_and_connect_metrics
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_can_include_tls_samples_when_enabled
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 31 passed, 0 failed
```

## Chunk 20: v0.1 DNS Resolver Compare CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `README.md`

### What changed

Added `dnspilot-cli compare`, a DNS-only multi-resolver benchmark command. It
accepts repeated `--resolver id=host:port` entries, benchmarks each resolver
against the same domains, runs core recommendation scoring in
`fastest-raw-dns` mode, and emits stable JSON with `summary`, `runs`,
`recommendation`, and a scope warning.

### Before

```mermaid
graph LR
  CLI[CLI] --> BENCH[Single resolver benchmark]
  CLI --> PATH[Single resolver path-estimate]
```

### After

```mermaid
graph LR
  CLI[CLI CHANGED] --> BENCH[Single resolver benchmark]
  CLI --> PATH[Single resolver path-estimate]
  CLI --> COMPARE[Multi-resolver DNS compare NEW]
  COMPARE --> SCORE[Core fastest-raw-dns recommendation]
```

### Edge Cases / Caveats

- This is DNS-only compare. It does not include TCP connect, TLS/SNI, HTTP,
  QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior.
- If every resolver fails, compare returns `can_recommend=false` and
  `recommendation=null` instead of picking the least-bad failed resolver.
- Resolver IDs must be unique because recommendation/profile persistence uses
  `profile_id` as the stable identifier.
- IPv6 resolver addresses must use socket address bracket syntax, for example
  `cloudflare=[2606:4700:4700::1111]:53`.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 6 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 34 passed, 0 failed
```

---

## Chunk 21: v0.1 Connection-Path Compare CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added `dnspilot-cli path-compare`, a DNS+TCP multi-resolver comparison command.
It accepts repeated `--resolver id=host:port` entries, runs the existing
connection-path estimator for each resolver, scores candidates in
`best-overall` mode, and emits JSON with top-level health, per-run summaries,
raw samples, recommendation, and a scope warning.

### Before

```mermaid
graph LR
  COMPARE[compare] --> DNS[DNS-only recommendation]
  PATH[path-estimate] --> SINGLE[Single resolver DNS+TCP estimate]
```

### After

```mermaid
graph LR
  COMPARE[compare] --> DNS[DNS-only recommendation]
  PATH[path-estimate] --> SINGLE[Single resolver DNS+TCP estimate]
  PATHCOMPARE[path-compare NEW] --> MULTI[Multi-resolver DNS+TCP recommendation]
  MULTI --> SCORE[best-overall scoring]
```

### Edge Cases / Caveats

- A resolver with fast DNS can lose if its resolved endpoint fails TCP connect.
  This closes the main weakness of raw DNS-only ranking.
- If every candidate path fails or is inconclusive, path-compare returns
  `can_recommend=false` and `recommendation=null`.
- This still does not include TLS/SNI, HTTP, QUIC, browser cache, VPN, MDM,
  captive portal, or app-specific behavior.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 8 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 36 passed, 0 failed
```

---

## Chunk 22: v0.1 TLS Path-Compare CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Extended `dnspilot-cli path-compare` with `--tls-handshake-timeout-ms`. When the
flag is present, each candidate resolver runs DNS, TCP connect, and TLS/SNI
handshake probes, then emits `dns-tcp-tls` scope, trust-store metadata,
per-run `tls_samples`, and conservative recommendation suppression when every
TLS path fails.

### Before

```mermaid
graph LR
  PATHCOMPARE[path-compare] --> DNS[DNS samples]
  PATHCOMPARE --> TCP[TCP connect samples]
  PATHCOMPARE --> SCORE[best-overall scoring]
```

### After

```mermaid
graph LR
  PATHCOMPARE[path-compare CHANGED] --> DNS[DNS samples]
  PATHCOMPARE --> TCP[TCP connect samples]
  PATHCOMPARE --> TLS[TLS/SNI samples NEW]
  PATHCOMPARE --> SCORE[best-overall scoring]
  TLS --> HEALTH[health and suppression CHANGED]
```

### Edge Cases / Caveats

- TLS probing currently uses the Rustls/webpki root set, not the OS-native trust
  store. Corporate roots or TLS interception can therefore appear as certificate
  failure until OS trust integration exists.
- If TCP succeeds but TLS/SNI fails for every candidate, path-compare returns
  `can_recommend=false` and `recommendation=null`.
- This still does not include HTTP, QUIC, browser cache, VPN, MDM, captive
  portal, or app-specific behavior.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 9 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 37 passed, 0 failed
```

---

## Chunk 23: v0.1 Recommendation Safety Gate

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/src/main.rs`, `README.md`

### What changed

Added a shared `recommendation_gate(metrics, scope)` API in `dnspilot-core`.
It returns stable `can_recommend`, `health`, `primary_issue`, and `notes`
before any caller asks the scoring engine to pick a candidate. CLI `compare`
and `path-compare` now consume this core gate instead of keeping local duplicated
rules.

### Before

```mermaid
graph LR
  COMPARE[compare CLI] --> LOCAL1[local can_recommend rule]
  PATHCOMPARE[path-compare CLI] --> LOCAL2[local can_recommend rule]
  CORE[core recommend] --> SCORE[score candidates]
```

### After

```mermaid
graph LR
  CORE[core CHANGED] --> GATE[recommendation_gate NEW]
  CORE --> SCORE[score candidates]
  COMPARE[compare CLI CHANGED] --> GATE
  PATHCOMPARE[path-compare CLI CHANGED] --> GATE
  GATE --> APPLY[UI/apply readiness]
```

### Edge Cases / Caveats

- DNS-only comparison can still recommend when TCP latency is absent, because
  that scope intentionally measures raw DNS only.
- DNS+TCP/TLS scopes suppress recommendation when every candidate lacks a usable
  connection path, even if DNS lookups themselves were fast.
- Degraded candidates can still be recommended when at least one candidate is
  usable; UI should present conservative confidence and caveats.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour recommendation_gate
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 9 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 40 passed, 0 failed
```

---

## Chunk 24: v0.1 Storage Snapshot Contract

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/storage.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/storage_behaviour.rs`, `README.md`

### What changed

Added a versioned storage snapshot contract for local profiles, test suites, and
benchmark history. The core now validates schema version, duplicate IDs,
profile validity, suite domains, and benchmark history shape before future
SQLite/native shells persist user data.

### Before

```mermaid
graph LR
  CORE[core] --> PROFILE[profiles]
  CORE --> SUITE[test suites]
  CORE --> BENCH[benchmark metrics]
```

### After

```mermaid
graph LR
  CORE[core CHANGED] --> PROFILE[profiles]
  CORE --> SUITE[test suites]
  CORE --> BENCH[benchmark metrics]
  CORE --> STORAGE[storage snapshot contract NEW]
  STORAGE --> VALIDATE[validation NEW]
```

### Edge Cases / Caveats

- This is a schema contract, not SQLite I/O yet.
- Schema version is strict; future migrations need explicit version handling.
- History records currently persist metrics/gate/recommendation profile id, not
  raw DNS/TCP/TLS sample arrays.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test storage_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 34 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 43 passed, 0 failed
```

---

## Chunk 25: v0.1 SQLite Storage Backend

**Status:** Complete
**Files changed:** `crates/dnspilot-core/Cargo.toml`, `Cargo.lock`, `crates/dnspilot-core/src/storage.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/storage_behaviour.rs`, `README.md`

### What changed

Added `SqliteStorage`, a core SQLite backend that initializes local tables,
saves a validated `StorageSnapshot`, and loads it back with validation. The
first backend stores the versioned snapshot JSON as the source of truth, keeping
migration and normalized-table work separate.

### Before

```mermaid
graph LR
  STORAGE[storage snapshot contract] --> JSON[JSON serialize/validate]
```

### After

```mermaid
graph LR
  STORAGE[storage snapshot contract] --> JSON[JSON serialize/validate]
  SQLITE[SQLite backend NEW] --> STORAGE
  SQLITE --> LOAD[load snapshot NEW]
  SQLITE --> SAVE[save snapshot NEW]
```

### Edge Cases / Caveats

- `rusqlite` is pinned to `0.32` because `0.40.1` pulled a `libsqlite3-sys`
  build script using unstable `cfg_select` on the current stable toolchain.
- The backend currently stores one snapshot blob, not normalized profile/history
  tables.
- `load_snapshot` returns an error when no snapshot has been saved yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test storage_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 35 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 44 passed, 0 failed
```

---

## Chunk 26: v0.1 Storage Smoke CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `dnspilot-cli storage-smoke --db <path>`. The command creates a SQLite
storage backend, saves a built-in catalog snapshot, loads it back, and prints a
JSON summary for manual persistence checks.

### Before

```mermaid
graph LR
  CORE[SQLite backend] --> TEST[core storage tests]
```

### After

```mermaid
graph LR
  CORE[SQLite backend] --> TEST[core storage tests]
  CLI[storage-smoke CLI NEW] --> CORE
  CLI --> JSON[summary JSON NEW]
```

### Edge Cases / Caveats

- This persists built-in profiles/suites only; custom profile/history CLI flows
  are not implemented yet.
- Existing DB path is overwritten at snapshot row `id = 1`.
- The command is a smoke tool, not final user-facing UX.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 10 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 45 passed, 0 failed
```

---

## Chunk 27: v0.1 Custom Profile Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `profile-add` and `profile-list` CLI commands backed by SQLite snapshots.
`profile-add` seeds a new DB with built-in catalog data when no snapshot exists,
validates the custom plain DNS profile, saves it, and `profile-list` reads it
back as JSON.

### Before

```mermaid
graph LR
  CLI[storage-smoke] --> SQLITE[SQLite snapshot]
```

### After

```mermaid
graph LR
  CLI[storage-smoke] --> SQLITE[SQLite snapshot]
  ADD[profile-add NEW] --> SQLITE
  LIST[profile-list NEW] --> SQLITE
```

### Edge Cases / Caveats

- Only plain DNS custom profiles are supported in this chunk.
- Duplicate profile IDs are rejected by snapshot validation.
- DoH/DoT custom profile fields are not exposed in CLI yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 11 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 46 passed, 0 failed
```

---

## Chunk 18: v0.1 Path-Estimate Summary JSON

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added a stable `summary` object to `dnspilot-cli path-estimate` JSON output.
It reports measurement scope, TLS enablement, trust store, sample counts, target
count, domain count, and caveat count so native shells and recommendation flows
do not need to infer these from raw arrays.

### Before

```mermaid
graph LR
  CLI[path-estimate CLI] --> RAW[Raw DNS/TCP/TLS arrays]
  RAW --> UI[UI infers coverage]
```

### After

```mermaid
graph LR
  CLI[path-estimate CLI CHANGED] --> RAW[Raw DNS/TCP/TLS arrays]
  CLI --> SUMMARY[Stable summary JSON NEW]
  SUMMARY --> UI[UI/recommendation layer]
```

### Edge Cases / Caveats

- `measurement_scope` is `dns-tcp` by default and `dns-tcp-tls` only when TLS
  probing is enabled.
- `trust_store` is `null` when TLS is disabled and `mozilla-webpki-roots` when
  TLS probing is enabled, making the current non-OS trust behavior explicit.
- Summary counts are descriptive only; scoring still comes from core metrics.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_outputs_dns_and_connect_metrics
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_can_include_tls_samples_when_enabled
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 31 passed, 0 failed
```

---

## Chunk 28: v0.1 Benchmark History Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/storage_behaviour.rs`, `README.md`

### What changed

Added `benchmark --save-db <path> --history-id <id>` and `history-list --db
<path>`. Benchmark history now persists through the SQLite snapshot backend, and
DNS-only records can round-trip path metrics where connect latency is not
applicable.

### Before

```mermaid
graph LR
  BENCH[benchmark CLI] --> JSON[live JSON only]
  SQLITE[SQLite snapshot] --> PROFILES[profiles/suites]
```

### After

```mermaid
graph LR
  BENCH[benchmark CLI CHANGED] --> JSON[live JSON]
  BENCH --> HISTORY[benchmark history NEW]
  HISTORY --> SQLITE[SQLite snapshot CHANGED]
  LIST[history-list CLI NEW] --> SQLITE
```

### Edge Cases / Caveats

- `recommendation_profile_id` is stored only when the recommendation gate allows
  a recommendation.
- JSON turns non-finite latency values into `null`; storage deserialize maps only
  latency `null` values back to `Infinity` and keeps rate/health fields strict.
- This is still snapshot persistence, not normalized history tables.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test storage_behaviour
Result: 5 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 12 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 48 passed, 0 failed
```

---

## Chunk 29: v0.1 Path-Compare History Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added `path-compare --save-db <path> --history-id <id>`. Multi-resolver
connection-path comparisons now persist resolver IDs, domains, metrics,
recommendation gate, and selected recommendation profile into benchmark history.

### Before

```mermaid
graph LR
  PATH[path-compare CLI] --> JSON[live JSON only]
  HISTORY[history-list CLI] --> SQLITE[SQLite snapshot]
```

### After

```mermaid
graph LR
  PATH[path-compare CLI CHANGED] --> JSON[live JSON]
  PATH --> HISTORY[benchmark history NEW]
  HISTORY --> SQLITE[SQLite snapshot]
  LIST[history-list CLI] --> SQLITE
```

### Edge Cases / Caveats

- Saved scope is `dns-tcp` by default and `dns-tcp-tls` when TLS probing is
  enabled.
- Duplicate history IDs are rejected by storage snapshot validation.
- Failed or inconclusive path comparisons can still be saved; they persist
  `recommendation_profile_id: null`.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_can_save_history_to_sqlite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 13 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 49 passed, 0 failed
```

---

## Chunk 30: v0.1 Compare History Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `README.md`

### What changed

Added `compare --save-db <path> --history-id <id>`. DNS-only multi-resolver
comparisons now persist resolver IDs, domains, metrics, recommendation gate, and
selected DNS recommendation into benchmark history.

### Before

```mermaid
graph LR
  COMPARE[compare CLI] --> JSON[live JSON only]
  HISTORY[history-list CLI] --> SQLITE[SQLite snapshot]
```

### After

```mermaid
graph LR
  COMPARE[compare CLI CHANGED] --> JSON[live JSON]
  COMPARE --> HISTORY[benchmark history NEW]
  HISTORY --> SQLITE[SQLite snapshot]
  LIST[history-list CLI] --> SQLITE
```

### Edge Cases / Caveats

- Saved scope is always `dns-only`; connection-path history remains owned by
  `path-compare`.
- Failed or inconclusive DNS comparisons can still be saved; they persist
  `recommendation_profile_id: null`.
- Duplicate history IDs are rejected by storage snapshot validation.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_can_save_history_to_sqlite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 14 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 50 passed, 0 failed
```

---

## Chunk 31: v0.1 Custom Suite Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `suite-add` and `suite-list` CLI commands backed by SQLite snapshots. This
lets custom domain test suites, such as Azure-focused checks, be saved as a
local option instead of typed repeatedly.

### Before

```mermaid
graph LR
  BUILTIN[built-in test suites] --> SNAPSHOT[SQLite snapshot]
  CLI[CLI] --> DOMAINS[ad hoc --domain args]
```

### After

```mermaid
graph LR
  BUILTIN[built-in test suites] --> SNAPSHOT[SQLite snapshot]
  ADD[suite-add CLI NEW] --> SNAPSHOT
  LIST[suite-list CLI NEW] --> SNAPSHOT
  CLI[CLI] --> DOMAINS[ad hoc --domain args]
```

### Edge Cases / Caveats

- Duplicate suite IDs are rejected by storage snapshot validation.
- `suite-add` requires at least one `--domain`.
- Saved suites are persisted and listed; benchmark commands do not consume
  `--suite-id` yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour suite_add_command_persists_custom_domain_suite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 15 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 51 passed, 0 failed
```

---

## Chunk 32: v0.1 Benchmark Saved-Suite Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `benchmark --suite-db <path> --suite-id <id>`. Benchmark can now resolve
domains from a saved custom test suite, so saved Azure/Microsoft or other
domain sets become runnable options.

### Before

```mermaid
graph LR
  SUITE[suite-add/suite-list] --> SQLITE[SQLite snapshot]
  BENCH[benchmark CLI] --> DOMAIN[required --domain args]
```

### After

```mermaid
graph LR
  SUITE[suite-add/suite-list] --> SQLITE[SQLite snapshot]
  SQLITE --> BENCH[benchmark CLI CHANGED]
  BENCH --> DOMAINS[suite domains plus ad hoc domains NEW]
```

### Edge Cases / Caveats

- `--domain` or `--suite-id` is required.
- `--suite-db` is required when `--suite-id` is used.
- `compare` and `path-compare` do not consume saved suites yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour benchmark_command_can_use_saved_domain_suite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 5 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 16 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 52 passed, 0 failed
```

---

## Chunk 33: v0.1 Compare Saved-Suite Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `README.md`

### What changed

Added `compare --suite-db <path> --suite-id <id>`. DNS-only multi-resolver
comparison can now run against saved custom domain suites and still supports
additional ad hoc `--domain` values.

### Before

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  COMPARE[compare CLI] --> DOMAIN[required --domain args]
```

### After

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  SQLITE --> COMPARE[compare CLI CHANGED]
  COMPARE --> DOMAINS[suite domains plus ad hoc domains NEW]
```

### Edge Cases / Caveats

- `--domain` or `--suite-id` is required.
- `--suite-db` is required when `--suite-id` is used.
- `path-compare` does not consume saved suites yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_can_use_saved_domain_suite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour
Result: 5 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 17 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 53 passed, 0 failed
```

---

## Chunk 34: v0.1 Path-Compare Saved-Suite Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added `path-compare --suite-db <path> --suite-id <id>`. Connection-path
multi-resolver comparison can now run against saved custom domain suites while
still allowing extra ad hoc `--domain` values.

### Before

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  PATH[path-compare CLI] --> DOMAIN[required --domain args]
```

### After

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  SQLITE --> PATH[path-compare CLI CHANGED]
  PATH --> DOMAINS[suite domains plus ad hoc domains NEW]
```

### Edge Cases / Caveats

- `--domain` or `--suite-id` is required.
- `--suite-db` is required when `--suite-id` is used.
- `path-estimate` does not consume saved suites yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_can_use_saved_domain_suite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 5 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 18 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 54 passed, 0 failed
```

---

## Chunk 35: v0.1 Path-Estimate Saved-Suite Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added `path-estimate --suite-db <path> --suite-id <id>`. Single-resolver
connection-path estimates can now run against saved custom domain suites, making
suite usage consistent across benchmark, compare, path-estimate, and
path-compare.

### Before

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  EST[path-estimate CLI] --> DOMAIN[required --domain args]
```

### After

```mermaid
graph LR
  SUITE[saved suites] --> SQLITE[SQLite snapshot]
  SQLITE --> EST[path-estimate CLI CHANGED]
  EST --> DOMAINS[suite domains plus ad hoc domains NEW]
```

### Edge Cases / Caveats

- `--domain` or `--suite-id` is required.
- `--suite-db` is required when `--suite-id` is used.
- Saved suite domains can be combined with extra ad hoc `--domain` values.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_can_use_saved_domain_suite
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 3 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 19 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 55 passed, 0 failed
```

---

## Chunk 36: v0.1 Benchmark Saved-Profile Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `benchmark --profile-db <path> --profile-id <id>`. A saved plain DNS
profile can now provide the resolver address for benchmark runs, defaulting to
port 53 with `--resolver-port` available for local/test resolvers.

### Before

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  BENCH[benchmark CLI] --> RESOLVER[required --resolver address]
```

### After

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  SQLITE --> BENCH[benchmark CLI CHANGED]
  BENCH --> RESOLVER[saved plain DNS resolver NEW]
```

### Edge Cases / Caveats

- Only plain DNS profiles are runnable in this chunk.
- IPv4 addresses are preferred before IPv6 addresses when both exist.
- Saved profiles store IPs, not ports; runtime uses port 53 unless
  `--resolver-port` is provided.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour benchmark_command_can_use_saved_plain_dns_profile
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 6 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 20 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 56 passed, 0 failed
```

---

## Chunk 37: v0.1 Compare Saved-Profile Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `README.md`

### What changed

Added `compare --profile-db <path> --profile-id <id>`. DNS-only multi-resolver
comparison can now include saved plain DNS profiles and still mix in explicit
`--resolver id=host:port` entries.

### Before

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  COMPARE[compare CLI] --> RESOLVER[explicit --resolver entries]
```

### After

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  SQLITE --> COMPARE[compare CLI CHANGED]
  RESOLVER[explicit --resolver entries] --> COMPARE
  COMPARE --> RUNS[manual plus saved profile runs NEW]
```

### Edge Cases / Caveats

- Only plain DNS profiles are runnable.
- Saved profile IPs use port 53 unless `--resolver-port` is provided.
- Duplicate resolver/profile IDs are rejected across manual and saved inputs.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_can_use_saved_plain_dns_profiles
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour
Result: 6 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 21 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 57 passed, 0 failed
```

---

## Chunk 38: v0.1 Path-Estimate Saved-Profile Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added `path-estimate --profile-db <path> --profile-id <id>`. A saved plain DNS
profile can now provide the resolver address for single-resolver
connection-path estimates.

### Before

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  EST[path-estimate CLI] --> RESOLVER[required --resolver address]
```

### After

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  SQLITE --> EST[path-estimate CLI CHANGED]
  EST --> RESOLVER[saved plain DNS resolver NEW]
```

### Edge Cases / Caveats

- Only plain DNS profiles are runnable.
- Saved profile IPs use port 53 unless `--resolver-port` is provided.
- `path-compare` does not consume saved profiles yet.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_can_use_saved_plain_dns_profile
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 22 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 58 passed, 0 failed
```

---

## Chunk 39: v0.1 Path-Compare Saved-Profile Input

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added `path-compare --profile-db <path> --profile-id <id>`. Connection-path
multi-resolver comparison can now include saved plain DNS profiles and still mix
in explicit `--resolver id=host:port` entries.

### Before

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  PATH[path-compare CLI] --> RESOLVER[explicit --resolver entries]
```

### After

```mermaid
graph LR
  PROFILE[profile-add/profile-list] --> SQLITE[SQLite snapshot]
  SQLITE --> PATH[path-compare CLI CHANGED]
  RESOLVER[explicit --resolver entries] --> PATH
  PATH --> RUNS[manual plus saved profile runs NEW]
```

### Edge Cases / Caveats

- Only plain DNS profiles are runnable.
- Saved profile IPs use port 53 unless `--resolver-port` is provided.
- Duplicate resolver/profile IDs are rejected across manual and saved inputs.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_can_use_saved_plain_dns_profiles
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour
Result: 6 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 23 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 59 passed, 0 failed
```

---

## Chunk 40: v0.1 Custom Encrypted Profile Persistence CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Extended `profile-add` with `--protocol plain|doh|dot`, `--doh-url`, and
`--dot-hostname`. Custom DoH and DoT profiles can now be stored and listed in
the same SQLite snapshot as plain DNS profiles.

### Before

```mermaid
graph LR
  ADD[profile-add CLI] --> PLAIN[plain DNS only]
  PLAIN --> SQLITE[SQLite snapshot]
```

### After

```mermaid
graph LR
  ADD[profile-add CLI CHANGED] --> PLAIN[plain DNS]
  ADD --> DOH[DoH profile NEW]
  ADD --> DOT[DoT profile NEW]
  PLAIN --> SQLITE[SQLite snapshot]
  DOH --> SQLITE
  DOT --> SQLITE
```

### Edge Cases / Caveats

- DoH profiles require `--doh-url`.
- DoT profiles require `--dot-hostname`.
- Benchmark runners still only execute plain DNS profiles; DoH/DoT persistence
  prepares store-safe apply/profile flows.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_persists_custom_encrypted_dns_profiles
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 7 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 24 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 60 passed, 0 failed
```

---

## Chunk 41: v0.1 Custom Filtering Profile Metadata

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added `profile-add --filtering none|malware|family|ads|security`. Custom DNS
profiles can now preserve their filtering category and security note metadata,
which is needed so filtered DNS can be benchmarked and explained separately from
plain performance DNS.

### Before

```mermaid
graph LR
  ADD[profile-add CLI] --> PROFILE[custom profile]
  PROFILE --> NONE[filtering_type none only]
```

### After

```mermaid
graph LR
  ADD[profile-add CLI CHANGED] --> PROFILE[custom profile]
  PROFILE --> FILTER[filtering category NEW]
  FILTER --> NOTES[filtered DNS security note NEW]
```

### Edge Cases / Caveats

- Default filtering remains `none`.
- Filtered DNS may intentionally block domains; UI/recommendation flows must not
  treat expected blocks as generic failures.
- Runner classification still needs selected test mode/filtering goal context.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_persists_custom_filtering_type
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour
Result: 8 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 25 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 61 passed, 0 failed
```

---

## Chunk 42: v0.1 DNS Flush Capability Matrix

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `README.md`

### What changed

Added `FlushCapability` to `PlatformCapability`. The core now explicitly tells
platform shells whether DNS cache flush should be guided, unsupported, handled
by a desktop admin service, or handled through Linux resolver/polkit paths.

### Before

```mermaid
graph LR
  CAP[platform capability] --> APPLY[apply capability]
  CAP --> NOTES[notes only for flush ambiguity]
```

### After

```mermaid
graph LR
  CAP[platform capability CHANGED] --> APPLY[apply capability]
  CAP --> FLUSH[flush capability NEW]
  FLUSH --> UI[flush/test UI decisions]
```

### Edge Cases / Caveats

- Store-safe builds do not claim automatic DNS cache flush.
- iOS exposes flush as unsupported for normal apps.
- Power/native builds can later wire helper, admin service, or polkit adapters.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour flush_capabilities_match_platform_constraints
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 37 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 62 passed, 0 failed
```

---

## Chunk 43: v0.1 Full Capability Matrix CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_capability_behaviour.rs`, `README.md`

### What changed

Added a core `all_platforms()` contract and a CLI `capabilities` command that
emits every platform capability in one JSON payload. This gives native shells a
single matrix read for UI capability tables while preserving per-platform
`apply` and `flush` distinctions.

### Before

```mermaid
graph LR
  CLI[CLI] --> ONE[capability platform]
  ONE --> SINGLE[single platform JSON]
```

### After

```mermaid
graph LR
  CORE[core platform list NEW] --> MATRIX[all capability records NEW]
  CLI[CLI CHANGED] --> ONE[capability platform]
  CLI --> ALL[capabilities command NEW]
  ALL --> MATRIX
```

### Edge Cases / Caveats

- The matrix is descriptive only; store-safe UI must still avoid hidden admin
  apply or flush actions.
- Linux remains capability-based, not feature-parity-based. Flatpak/Snap and
  native deb/rpm read different apply/flush paths from the same matrix.
- Adding a new platform must update the canonical `ALL_PLATFORMS` list or it
  will not appear in matrix output.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_capability_behaviour capabilities_command_outputs_full_matrix_with_flush_contract
RED result: failed because subcommand `capabilities` did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_capability_behaviour capabilities_command_outputs_full_matrix_with_flush_contract
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 63 passed, 0 failed
```

---

## Chunk 44: v0.1 Benchmark Preflight Policy

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `README.md`

### What changed

Added a core benchmark preflight contract that separates direct resolver
benchmarks from system-DNS validation after apply. Direct resolver scoring does
not require OS DNS cache flush because it sends DNS packets to the selected
resolver directly; system-DNS validation can recommend flush/guidance based on
the platform capability matrix.

### Before

```mermaid
graph LR
  TEST[test action] --> FLUSH[flush assumption]
  FLUSH --> BENCH[benchmark]
```

### After

```mermaid
graph LR
  TEST[test action CHANGED] --> SCOPE{preflight scope NEW}
  SCOPE --> DIRECT[direct resolver benchmark]
  SCOPE --> SYSTEM[system DNS validation after apply]
  DIRECT --> NOFLUSH[flush not needed NEW]
  SYSTEM --> POLICY[platform flush policy NEW]
```

### Edge Cases / Caveats

- Unconditional flush before every benchmark is misleading and may imply the CLI
  is testing OS resolver state when it is actually testing a selected resolver.
- iOS can recommend validation caution while still reporting normal-app DNS
  cache flush as unsupported.
- Even after flush, browser Secure DNS, VPN, MDM, captive portal, and app caches
  can invalidate system-DNS validation results.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour benchmark_preflight_distinguishes_direct_resolver_from_system_validation
RED result: failed because benchmark preflight types/function did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour benchmark_preflight_distinguishes_direct_resolver_from_system_validation
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 38 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 64 passed, 0 failed
```

---

## Chunk 45: v0.1 Benchmark Preflight CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_preflight_behaviour.rs`, `README.md`

### What changed

Added a CLI `preflight` command that emits the core benchmark preflight policy
as JSON. Native shells and smoke scripts can now ask whether a direct resolver
benchmark or system-DNS validation needs DNS cache flush guidance for a specific
platform.

### Before

```mermaid
graph LR
  CORE[core preflight policy] --> LIB[core consumers only]
```

### After

```mermaid
graph LR
  CORE[core preflight policy] --> CLI[preflight CLI NEW]
  CLI --> JSON[platform/scope flush JSON NEW]
```

### Edge Cases / Caveats

- The command defaults to direct resolver benchmarking, where flush is not
  needed.
- System-DNS validation remains advisory; it cannot prove browser/app traffic
  used the system resolver.
- Store-safe shells should use this output to show guidance, not to execute
  hidden admin commands.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_preflight_behaviour
RED result: failed because subcommand `preflight` did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_preflight_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 66 passed, 0 failed
```

---

## Chunk 46: v0.1 Apply Prompt Safety Policy

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `README.md`

### What changed

Added an apply-prompt policy for network environments. The core now defaults to
protecting the current DNS and suppressing apply prompts when VPN, MDM,
corporate DNS, or captive portal signals are present, even if a benchmark found
a faster resolver.

### Before

```mermaid
graph LR
  REC[recommendation] --> APPLY[apply prompt]
```

### After

```mermaid
graph LR
  REC[recommendation] --> POLICY[apply prompt policy NEW]
  ENV[network environment NEW] --> POLICY
  POLICY --> ALLOW[allow or guide]
  POLICY --> PROTECT[protect current DNS NEW]
```

### Edge Cases / Caveats

- VPN and MDM can intentionally own DNS; changing DNS can break security or
  corporate access.
- Captive portals can make DNS behavior look broken until login finishes.
- Windows Store and similar store-safe builds can guide settings, but should not
  perform hidden DNS changes.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour apply_prompt_policy_protects_managed_or_intercepted_networks
RED result: failed because apply prompt policy types/function did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour apply_prompt_policy_protects_managed_or_intercepted_networks
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 39 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 67 passed, 0 failed
```

---

## Chunk 47: v0.1 Apply Prompt Policy CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_apply_policy_behaviour.rs`, `README.md`

### What changed

Added a CLI `apply-policy` command that exposes the protected-network apply
prompt policy as JSON. Platform shells can pass detected VPN, MDM, corporate
DNS, or captive portal signals and receive an explicit allow/guide/protect
decision.

### Before

```mermaid
graph LR
  CORE[core apply policy] --> LIB[core consumers only]
```

### After

```mermaid
graph LR
  SIGNALS[platform network signals] --> CLI[apply-policy CLI NEW]
  CORE[core apply policy] --> CLI
  CLI --> JSON[apply prompt JSON NEW]
```

### Edge Cases / Caveats

- The CLI does not detect VPN/MDM/corporate state itself; native shells provide
  those signals.
- A protected signal overrides otherwise valid apply capability.
- Guided store flows remain guide-only and must not imply automatic DNS changes.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour
RED result: failed because subcommand `apply-policy` did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour
Result: 2 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 69 passed, 0 failed
```

---

## Chunk 48: v0.1 Custom Suite Domain Validation

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/src/dns_wire.rs`, `crates/dnspilot-core/src/storage.rs`, `crates/dnspilot-core/tests/storage_behaviour.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added shared `TestSuite::validate()` logic for custom domain suites. Storage and
CLI persistence now reject invalid DNS names and duplicate domains before a bad
suite can pollute benchmark runs or fail later inside the DNS wire layer.

### Before

```mermaid
graph LR
  SUITE[suite-add] --> SAVE[save snapshot]
  SAVE --> BAD[bad domains stored]
  BAD --> BENCH[late benchmark failure]
```

### After

```mermaid
graph LR
  SUITE[suite-add CHANGED] --> VALIDATE[TestSuite validate NEW]
  VALIDATE --> WIRE[DNS wire domain validator NEW]
  VALIDATE --> SAVE[save snapshot]
  VALIDATE --> REJECT[reject invalid or duplicate domains NEW]
```

### Edge Cases / Caveats

- Duplicate domains can overweight a target domain and distort scoring.
- Invalid domain names should fail at profile/suite creation time, not during a
  benchmark run.
- The validator reuses DNS wire name rules so suite validation matches query
  construction.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test storage_behaviour storage_snapshot_rejects_invalid_or_duplicate_suite_domains
RED result: failed because invalid and duplicate suite domains were accepted

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour suite_add_command_rejects_invalid_domain
RED result: failed because suite-add accepted an invalid domain

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test storage_behaviour storage_snapshot_rejects_invalid_or_duplicate_suite_domains
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour suite_add_command_rejects_invalid_domain
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 40 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 71 passed, 0 failed
```

---

## Chunk 49: v0.1 Custom Profile Server Validation

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Strengthened DNS profile validation so IPv4 server lists only accept IPv4
addresses, IPv6 server lists only accept IPv6 addresses, and duplicate DNS
servers are rejected. CLI profile persistence inherits this validation before a
bad profile can be saved.

### Before

```mermaid
graph LR
  PROFILE[profile-add] --> PARSE[parse as any IP]
  PARSE --> SAVE[save mislabeled server]
```

### After

```mermaid
graph LR
  PROFILE[profile-add CHANGED] --> VALIDATE[profile validate CHANGED]
  VALIDATE --> IPV4[IPv4 list requires IPv4 NEW]
  VALIDATE --> IPV6[IPv6 list requires IPv6 NEW]
  VALIDATE --> DEDUPE[reject duplicate servers NEW]
```

### Edge Cases / Caveats

- An IPv6 address in `ipv4_servers` can silently break UI assumptions and later
  resolver selection.
- Duplicate server entries overweight one resolver and waste probes.
- Built-in profile validation still runs through the same storage contract.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour dns_profile_validation_rejects_mismatched_or_duplicate_server_families
RED result: failed because IPv6 addresses in the IPv4 list were accepted

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_rejects_mismatched_ipv4_server
RED result: failed because profile-add accepted IPv6 in the IPv4 list

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour dns_profile_validation_rejects_mismatched_or_duplicate_server_families
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_rejects_mismatched_ipv4_server
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 41 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 73 passed, 0 failed
```

---

## Chunk 50: v0.1 Zero-Attempt CLI Guards

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added zero-attempt validation to `benchmark` and `path-estimate` so all benchmark
entry points reject empty runs consistently. `compare` and `path-compare` already
had this guard; this closes the remaining direct command gap.

### Before

```mermaid
graph LR
  CLI[benchmark/path-estimate] --> ZERO[attempts 0]
  ZERO --> EMPTY[empty run output]
```

### After

```mermaid
graph LR
  CLI[benchmark/path-estimate CHANGED] --> CHECK[attempts guard NEW]
  CHECK --> REJECT[exit 2 with message NEW]
  CHECK --> RUN[run benchmark]
```

### Edge Cases / Caveats

- Zero samples can produce misleading success output and invalid statistics.
- Validation happens before resolver/domain work, so bad runs do not touch the
  network.
- The same user-facing error string is used across benchmark commands.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_zero_attempts
RED result: failed because benchmark accepted `--attempts 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_attempts
RED result: failed because path-estimate accepted `--attempts 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_zero_attempts
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_attempts
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 34 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 75 passed, 0 failed
```

---

## Chunk 51: v0.1 Zero-Timeout CLI Guards

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added zero-timeout validation across benchmark, compare, path-estimate, and
path-compare commands. DNS, TCP connect, and optional TLS/SNI timeouts now reject
`0` before any network work starts.

### Before

```mermaid
graph LR
  CLI[benchmark CLI] --> ZERO[timeout 0ms]
  ZERO --> RUN[network run with impossible timeout]
```

### After

```mermaid
graph LR
  CLI[benchmark CLI CHANGED] --> CHECK[timeout guard NEW]
  CHECK --> REJECT[exit 2 with flag-specific message NEW]
  CHECK --> RUN[network run]
```

### Edge Cases / Caveats

- `0ms` timeout creates deterministic failure/noise, not useful benchmark data.
- Optional TLS timeout also rejects `0`; absence still means TLS probing disabled.
- Validation shares the same helper style as zero-attempt guards.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_zero_timeout
RED result: failed because benchmark accepted `--timeout-ms 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_rejects_zero_timeout
RED result: failed because compare accepted `--timeout-ms 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_connect_timeout
RED result: failed because path-estimate accepted `--connect-timeout-ms 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_rejects_zero_tls_timeout
RED result: failed because path-compare accepted `--tls-handshake-timeout-ms 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests zero
Result: 7 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 38 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 79 passed, 0 failed
```

---

## Chunk 52: v0.1 Zero Connection-Target CLI Guards

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `crates/dnspilot-cli/tests/cli_path_compare_behaviour.rs`, `README.md`

### What changed

Added validation for `--max-connect-targets-per-domain` on `path-estimate` and
`path-compare`. A zero value is rejected before DNS/TCP work starts because it
would produce an empty connection-path probe.

### Before

```mermaid
graph LR
  PATH[path command] --> LIMIT[max targets 0]
  LIMIT --> EMPTY[no TCP targets]
```

### After

```mermaid
graph LR
  PATH[path command CHANGED] --> CHECK[target limit guard NEW]
  CHECK --> REJECT[exit 2 with message NEW]
  CHECK --> RUN[path probes]
```

### Edge Cases / Caveats

- A path benchmark with zero connect targets is not a path benchmark.
- This guard keeps recommendation-gate no-target failures for real resolver/CDN
  behavior, not user input mistakes.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_max_connect_targets
RED result: failed because path-estimate accepted `--max-connect-targets-per-domain 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_rejects_zero_max_connect_targets
RED result: failed because path-compare accepted `--max-connect-targets-per-domain 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_max_connect_targets
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_compare_behaviour path_compare_command_rejects_zero_max_connect_targets
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 40 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 81 passed, 0 failed
```

---

## Chunk 53: v0.1 Zero-Port CLI Guards

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `crates/dnspilot-cli/tests/cli_path_estimate_behaviour.rs`, `README.md`

### What changed

Added port validation for resolver and connect ports. Direct resolver addresses,
multi-resolver specs, saved-profile resolver-port fallback, and path connect
ports now reject `0` before network work starts.

### Before

```mermaid
graph LR
  CLI[benchmark CLI] --> PORT[port 0]
  PORT --> RUN[network run with invalid target]
```

### After

```mermaid
graph LR
  CLI[benchmark CLI CHANGED] --> CHECK[port guard NEW]
  CHECK --> REJECT[exit 2 with message NEW]
  CHECK --> RUN[network run]
```

### Edge Cases / Caveats

- `SocketAddr` can parse port `0`, but it is not a meaningful DNS resolver or
  TCP connect target for this app.
- Resolver specs and direct resolver args use the same `--resolver port` message.
- `--resolver-port` fallback is guarded for saved profile runs even when no
  direct resolver argument is provided.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_zero_resolver_port
RED result: failed because benchmark accepted `--resolver 127.0.0.1:0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_rejects_zero_resolver_port
RED result: failed because compare accepted resolver spec port 0

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_connect_port
RED result: failed because path-estimate accepted `--connect-port 0`

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_zero_resolver_port
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_rejects_zero_resolver_port
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_path_estimate_behaviour path_estimate_command_rejects_zero_connect_port
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 43 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 84 passed, 0 failed
```

---

## Chunk 54: v0.1 Resolved-Domain CLI Validation

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`, `crates/dnspilot-cli/tests/cli_compare_behaviour.rs`, `README.md`

### What changed

Added validation after suite and explicit `--domain` values are merged. CLI
benchmark commands now reject invalid DNS names and duplicate resolved domains
before starting network work.

### Before

```mermaid
graph LR
  SUITE[suite domains] --> MERGE[merge domains]
  CLI[--domain values] --> MERGE
  MERGE --> RUN[benchmark run]
```

### After

```mermaid
graph LR
  SUITE[suite domains] --> MERGE[merge domains CHANGED]
  CLI[--domain values] --> MERGE
  MERGE --> VALIDATE[DNS wire validation + dedupe NEW]
  VALIDATE --> REJECT[reject invalid/duplicate NEW]
  VALIDATE --> RUN[benchmark run]
```

### Edge Cases / Caveats

- Invalid explicit domains should not be counted as resolver failures.
- Duplicate domains can overweight one destination and distort ranking.
- Suite and CLI domains are validated after merge so cross-source duplicates are
  also caught.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_invalid_domain_before_network
RED result: failed because benchmark accepted invalid explicit domain

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_rejects_duplicate_domains
RED result: failed because compare accepted duplicate domains

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour benchmark_command_rejects_invalid_domain_before_network
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_compare_behaviour compare_command_rejects_duplicate_domains
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --tests
Result: 45 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 86 passed, 0 failed
```

---

## Chunk 55: v0.1 Encrypted Profile Endpoint Validation

**Status:** Complete
**Files changed:** `crates/dnspilot-core/Cargo.toml`, `Cargo.lock`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `README.md`

### What changed

Added validation for encrypted DNS profile endpoints. DoH profiles now require a
parseable HTTPS URL with a host, and DoT profiles validate their hostname using
the DNS wire domain validator.

### Before

```mermaid
graph LR
  PROFILE[encrypted profile] --> FIELD[field exists]
  FIELD --> SAVE[save profile]
```

### After

```mermaid
graph LR
  PROFILE[encrypted profile CHANGED] --> DOH[DoH URL validation NEW]
  PROFILE --> DOT[DoT hostname validation NEW]
  DOH --> SAVE[save profile]
  DOT --> SAVE
  DOH --> REJECT[reject insecure/invalid endpoint NEW]
  DOT --> REJECT
```

### Edge Cases / Caveats

- `http://` is not acceptable for DoH.
- DoT needs a DNS hostname suitable for SNI, not arbitrary text.
- This still does not implement encrypted DNS benchmarking; it only validates
  stored profile metadata for future store-safe apply flows.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour dns_profile_validation_rejects_invalid_encrypted_endpoints
RED result: failed because insecure DoH URL was accepted

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_rejects_insecure_doh_url
RED result: failed because profile-add accepted insecure DoH URL

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour dns_profile_validation_rejects_invalid_encrypted_endpoints
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_add_command_rejects_insecure_doh_url
Result: 1 passed, 0 failed

cargo clean
Reason: stable toolchain updated from rustc 1.93 artifacts to rustc 1.96 during dependency fetch; target cache had incompatible proc-macro artifacts.

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --tests
Result: 42 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 88 passed, 0 failed
```

---

## Chunk 56: v0.1 macOS SwiftUI Shell Scaffold

**Status:** Complete
**Files changed:** `.gitignore`, `apps/macos/DNSPilotMac/Package.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/*`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CapabilityMatrixViewModelTests.swift`, `README.md`

### What changed

Added the first macOS 14+ SwiftUI shell scaffold as a Swift Package. The shell
has centralized design tokens, capability matrix models, a bridge protocol with
preview data, ViewModel tests, and a simple SwiftUI capability matrix window.

### Before

```mermaid
graph LR
  CORE[Rust core/CLI] --> NONE[no native shell]
```

### After

```mermaid
graph LR
  MAC[macOS SwiftUI shell NEW] --> VM[capability ViewModel NEW]
  VM --> BRIDGE[core bridge protocol NEW]
  MAC --> TOKENS[design tokens NEW]
  BRIDGE --> PREVIEW[preview data NEW]
```

### Edge Cases / Caveats

- The macOS shell currently uses preview bridge data; real Rust/UniFFI or CLI
  bridge wiring is a separate chunk.
- Visual/manual app inspection is not claimed yet; this chunk only verifies
  package build and ViewModel/design-token tests.
- `.build/` is ignored so SwiftPM artifacts stay out of git.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because CapabilityMatrixViewModel and DNSPilotDesign did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 2 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete
```

---

## Chunk 57: v0.1 macOS Capability JSON Bridge

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CapabilityMatrixJSONDecoder.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CapabilityMatrixViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CapabilityMatrixViewModelTests.swift`, `README.md`

### What changed

Added a Swift decoder and bridge for the Rust CLI/core `capabilities` JSON
schema. The ViewModel now supports throwing bridges and exposes a load error
message, so future CLI/FFI bridge failures do not silently render an empty
matrix.

### Before

```mermaid
graph LR
  VM[capability ViewModel] --> PREVIEW[preview bridge only]
  RUST[Rust capabilities JSON] --> GAP[not decoded by macOS shell]
```

### After

```mermaid
graph LR
  RUST[Rust capabilities JSON] --> DECODER[Swift JSON decoder NEW]
  DECODER --> JSONBRIDGE[JSON capability bridge NEW]
  JSONBRIDGE --> VM[capability ViewModel CHANGED]
  PREVIEW[preview bridge] --> VM
  VM --> ERROR[load error message NEW]
```

### Edge Cases / Caveats

- Unknown `apply` or `flush` values fail fast to catch schema drift.
- Unknown platform IDs still get a readable fallback display name, so new
  platforms can appear without losing the row.
- The macOS app still does not execute the Rust CLI or link Rust FFI at runtime;
  this chunk only locks the data contract and error path.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CapabilityMatrixViewModelTests/testCapabilitiesDecoderMapsRustCliSchema
RED result: failed because CapabilityMatrixJSONDecoder did not exist

swift test --package-path apps/macos/DNSPilotMac --filter CapabilityMatrixViewModelTests/testViewModelLoadsRowsFromJSONBridge
RED result: failed because the bridge protocol was non-throwing, CapabilityMatrixJSONBridge did not exist, and ViewModel had no loadErrorMessage

swift test --package-path apps/macos/DNSPilotMac
Result: 6 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete
```

---

## Chunk 58: v0.1 macOS Catalog JSON Bridge

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogJSONDecoder.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `README.md`

### What changed

Added Swift catalog models, a JSON decoder, a JSON bridge, and a CatalogViewModel
for the Rust CLI/core `catalog` schema. This covers DNS profiles and test
suites so the macOS shell can later show provider and suite data without
duplicating catalog rules.

### Before

```mermaid
graph LR
  RUSTCAT[Rust catalog JSON] --> GAP[not decoded by macOS shell]
  MAC[macOS shell] --> CAP[capability bridge only]
```

### After

```mermaid
graph LR
  RUSTCAT[Rust catalog JSON] --> CATDECODER[Swift catalog decoder NEW]
  CATDECODER --> CATBRIDGE[catalog JSON bridge NEW]
  CATBRIDGE --> CATVM[Catalog ViewModel NEW]
  MAC[macOS shell] --> CAP[capability bridge]
```

### Edge Cases / Caveats

- Unknown DNS protocol or filtering enum values fail decode, which catches
  schema drift before UI recommendation code consumes bad assumptions.
- Provider metadata and created/updated timestamps are intentionally not shown
  in the Swift shell model yet.
- Catalog data is decoded and view-modeled, but not rendered in the app UI yet.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testCatalogDecoderMapsRustCliSchema
RED result: failed because CatalogSnapshot, DNSPilotCatalogBridge, CatalogJSONDecoder, CatalogJSONBridge, and CatalogViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Intermediate result: failed because optional `.none` in the test assertion resolved to Optional.none instead of CatalogFilteringType.none

swift test --package-path apps/macos/DNSPilotMac
Result: 10 passed, 0 failed
```

---

## Chunk 59: v0.1 Core Shell Payload Contracts

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/src/main.rs`, `README.md`

### What changed

Added core-owned payload structs and factory functions for the shell-facing
`catalog` and `capabilities` contracts. The CLI now serializes those core
payloads instead of hand-building duplicate JSON wrappers.

### Before

```mermaid
graph LR
  CORE[core built-ins] --> CLIJSON[CLI hand-built JSON]
  CORE --> FUTURE[future FFI bridge]
  CLIJSON --> SWIFT[Swift JSON decoders]
```

### After

```mermaid
graph LR
  CORE[core built-ins] --> PAYLOADS[core payload contracts NEW]
  PAYLOADS --> CLI[CLI catalog/capabilities CHANGED]
  PAYLOADS --> FUTURE[future FFI bridge]
  CLI --> SWIFT[Swift JSON decoders]
```

### Edge Cases / Caveats

- CLI object field order may differ because it now serializes typed structs
  directly; consumers must parse JSON fields rather than compare raw text.
- `testSuites` remains explicitly camel-cased for the macOS decoder contract.
- This still does not bind Rust into Swift at runtime; it creates the single
  Rust source for the bridge payload shape.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour
RED result: failed because catalog_payload and capability_matrix_payload did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour
Result: 16 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_capability_behaviour
Intermediate result: failed because builtin storage snapshot still needed built_in_profiles and built_in_test_suites imports

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_capability_behaviour
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo run -p dnspilot-cli -- catalog
Result: command emitted profiles and testSuites JSON
```

---

## Chunk 60: v0.1 Shell Payload Schema Version

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/tests/cli_catalog_behaviour.rs`, `crates/dnspilot-cli/tests/cli_capability_behaviour.rs`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CapabilityMatrixViewModelTests.swift`, `README.md`

### What changed

Added `schema_version` to the core-owned catalog and capability payloads and
locked it through CLI tests. Swift fixtures now include the version field while
the decoders continue to ignore unknown root fields they do not need.

### Before

```mermaid
graph LR
  PAYLOADS[core shell payloads] --> JSON[JSON without schema_version]
  JSON --> SWIFT[Swift decoders]
```

### After

```mermaid
graph LR
  PAYLOADS[core shell payloads CHANGED] --> VERSION[schema_version NEW]
  VERSION --> CLI[CLI contract tests NEW]
  VERSION --> SWIFT[Swift fixtures CHANGED]
```

### Edge Cases / Caveats

- This is payload schema versioning, not storage schema versioning.
- Swift currently tolerates extra root fields; if Swift later needs strict
  migration behavior, it should decode and gate on `schema_version`.
- Version stays `1` because the added field is backward-compatible for current
  decoders.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour catalog_payload_matches_builtin_catalog_contract
RED result: failed because CatalogPayload and CapabilityMatrixPayload had no schema_version field

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_catalog_behaviour
RED result: failed because catalog JSON emitted null schema_version

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour catalog_payload_matches_builtin_catalog_contract
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_catalog_behaviour
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_capability_behaviour
Result: 1 passed, 0 failed
```

---

## Chunk 61: v0.1 macOS Schema Version Gate

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ShellPayloadSchema.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogJSONDecoder.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CapabilityMatrixJSONDecoder.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CapabilityMatrixViewModelTests.swift`, `README.md`

### What changed

Added a shared Swift schema gate for shell payloads and wired it into catalog
and capability decoders. macOS now rejects unsupported payload schema versions
instead of parsing future contracts with v1 assumptions.

### Before

```mermaid
graph LR
  JSON[payload schema_version] --> DECODER[Swift decoder ignores version]
  DECODER --> VM[ViewModel]
```

### After

```mermaid
graph LR
  JSON[payload schema_version] --> GATE[Swift schema gate NEW]
  GATE --> DECODER[Swift decoder CHANGED]
  DECODER --> VM[ViewModel]
  GATE --> ERROR[unsupported version error NEW]
```

### Edge Cases / Caveats

- Decoders now require `schema_version`; older payloads without it fail decode.
- Only version `1` is supported.
- This still does not implement migrations for future schema versions.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CapabilityMatrixViewModelTests/testCapabilitiesDecoderRejectsUnsupportedSchemaVersion
RED result: failed because the decoder did not throw for schema_version 2

swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testCatalogDecoderRejectsUnsupportedSchemaVersion
RED result: failed because the decoder did not throw for schema_version 2

swift test --package-path apps/macos/DNSPilotMac
Result: 12 passed, 0 failed
```

---

## Chunk 62: v0.1 macOS Preview Catalog Summary

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `README.md`

### What changed

Added a default preview catalog bridge and summary metrics on CatalogViewModel.
The macOS shell now has testable catalog counts and Azure-suite presence before
the UI renders catalog panels or runtime Rust data is wired.

### Before

```mermaid
graph LR
  CALLER[caller] --> CATVM[Catalog ViewModel requires injected bridge]
  CATVM --> SNAPSHOT[catalog snapshot]
```

### After

```mermaid
graph LR
  CATVM[Catalog ViewModel CHANGED] --> PREVIEW[preview catalog bridge NEW]
  CATVM --> COUNTS[summary metrics NEW]
  PREVIEW --> SNAPSHOT[catalog snapshot]
```

### Edge Cases / Caveats

- Preview catalog data is intentionally small and is not the canonical built-in
  catalog.
- Runtime Rust catalog loading is still not wired.
- Summary counts return zero if the bridge fails and catalog is unavailable.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testDefaultCatalogViewModelProvidesPreviewSummary
RED result: failed because CatalogViewModel required an explicit bridge and had no summary metrics

swift test --package-path apps/macos/DNSPilotMac
Result: 13 passed, 0 failed
```

---

## Chunk 63: v0.1 macOS Catalog Display Summaries

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `README.md`

### What changed

Added provider and test-suite summary rows to CatalogViewModel. The future
SwiftUI catalog surface can bind to preformatted server counts, filtering
labels, and domain-count labels instead of embedding formatting logic in views.

### Before

```mermaid
graph LR
  CATVM[Catalog ViewModel] --> RAW[raw catalog snapshot]
  UI[future UI] --> FORMAT[would need inline formatting]
```

### After

```mermaid
graph LR
  CATVM[Catalog ViewModel CHANGED] --> RAW[raw catalog snapshot]
  CATVM --> PROFILES[profile summaries NEW]
  CATVM --> SUITES[test suite summaries NEW]
  PROFILES --> UI[future UI]
  SUITES --> UI
```

### Edge Cases / Caveats

- Summary strings are UI-facing and English-only for now.
- IPv4/IPv6 counts are summaries, not server health checks.
- This still does not render the catalog in SwiftUI.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testCatalogViewModelBuildsDisplaySummaries
RED result: failed because CatalogViewModel had no profileSummaries or testSuiteSummaries

swift test --package-path apps/macos/DNSPilotMac
Result: 14 passed, 0 failed
```

---

## Chunk 69: v0.1 macOS Benchmark Runner

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunner.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunnerTests.swift`, `README.md`

### What changed

Added a macOS core benchmark runner boundary that validates
`BenchmarkPlanViewModel`, passes CLI arguments to an injectable process runner,
and preserves non-zero process output for UI error display.

### Edge Cases / Caveats

- Invalid plans are rejected before process execution.
- Non-zero CLI exits are result data, not thrown errors, so UI can render stderr.
- This does not yet wire the SwiftUI benchmark screen or locate the bundled CLI.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkRunner types did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 26 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 87: v0.1 macOS Custom DNS Form ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileFormViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CustomDNSProfileFormViewModelTests.swift`, `README.md`

### What changed

Added a custom plain DNS form ViewModel that normalizes profile IDs, parses
IPv4/IPv6 server lists, validates address family and duplicates, and builds
`profile-add` CLI arguments.

### Edge Cases / Caveats

- This supports plain DNS profiles only; DoH/DoT custom profiles remain later.
- Profile ID collision against existing storage is not handled yet.
- UI and process runner wiring are next.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because CustomDNSProfileFormViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 80 passed, 0 failed
```

---

## Chunk 88: v0.1 macOS Custom DNS Save Runner

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileSaveRunner.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CustomDNSProfileSaveRunnerTests.swift`, `README.md`

### What changed

Added a custom DNS save runner and coordinator that validate the form, execute
`profile-add` through the shared process boundary, and map CLI/storage failures
into UI-ready messages.

### Edge Cases / Caveats

- Duplicate profile IDs are still rejected by storage/CLI, not pre-detected in
  the macOS form.
- Save is plain DNS only; encrypted custom profiles remain out of this path.
- UI wiring is next; this chunk only adds the tested execution boundary.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CustomDNSProfileSaveRunnerTests
RED result: failed because CustomDNSProfileSaveRunner/Coordinator did not exist

swift test --package-path apps/macos/DNSPilotMac --filter CustomDNSProfileSaveRunnerTests
Result: 4 passed, 0 failed
```

---

## Chunk 89: v0.1 macOS Custom DNS Editor State

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileEditorViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CustomDNSProfileEditorViewModelTests.swift`, `README.md`

### What changed

Added a tested editor ViewModel for the custom DNS form. It derives save button
enablement, profile ID preview, validation issue display, and save status
messages from form input plus save state.

### Edge Cases / Caveats

- This does not inspect storage for duplicate IDs before save.
- UI wiring is still next; this chunk keeps state behavior testable.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CustomDNSProfileEditorViewModelTests
RED result: failed because CustomDNSProfileEditorViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac --filter CustomDNSProfileEditorViewModelTests
Result: 4 passed, 0 failed
```

---

## Chunk 90: v0.1 macOS Shared Storage Filename

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryPersistence.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryPersistenceTests.swift`, `README.md`

### What changed

Changed the default Application Support database filename from
`history.sqlite` to `dnspilot.sqlite` because the same SQLite store now holds
custom profiles, custom suites, and benchmark history.

### Edge Cases / Caveats

- This is a pre-release path change; released builds would need migration from
  a legacy filename.
- The factory type is still named for history; a broader storage factory can be
  split later if it becomes confusing.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkHistoryPersistenceTests/testPersistenceFactoryBuildsApplicationSupportDatabaseLocation
RED result: failed because factory still used history.sqlite

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkHistoryPersistenceTests/testPersistenceFactoryBuildsApplicationSupportDatabaseLocation
Result: 1 passed, 0 failed
```

---

## Chunk 91: v0.1 macOS Custom DNS UI

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`

### What changed

Added a Custom DNS sidebar destination with a native SwiftUI form for profile
name, IPv4 servers, IPv6 servers, profile ID preview, validation issues, save
status, and asynchronous `profile-add` execution.

### Edge Cases / Caveats

- Saved custom profiles are persisted, but the Benchmark screen still needs a
  storage catalog merge before the new profile appears as a selectable option.
- Duplicate profile IDs are surfaced from CLI/storage errors after Save.
- Visual/manual interaction testing should wait until custom profiles can be
  saved and selected in one app flow.

### Verification

```text
swift build --package-path apps/macos/DNSPilotMac
Result: build complete
```

---

## Chunk 92: v0.1 macOS Storage-Backed Catalog Bridge

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogStorageBridge.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogStorageBridgeTests.swift`, `README.md`

### What changed

Added profile-list and suite-list payload decoders, a catalog storage runner,
and a storage-backed catalog bridge. The bridge merges persisted profiles/suites
with the built-in catalog, deduplicating by ID and falling back to built-ins if
storage fails.

### Edge Cases / Caveats

- Storage wins on duplicate IDs, so a persisted built-in ID can replace the
  built-in row.
- Storage failures are intentionally non-fatal for the catalog; custom options
  may be hidden until storage is healthy.
- The macOS shell still needs to refresh this bridge after a custom profile is
  saved.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CatalogStorageBridgeTests
RED result: failed because catalog storage bridge types did not exist

swift test --package-path apps/macos/DNSPilotMac --filter CatalogStorageBridgeTests
Result: 5 passed, 0 failed
```

---

## Chunk 93: v0.1 macOS Catalog Refresh Wiring

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`

### What changed

Changed the macOS shell catalog model into state and refreshes it through the
storage-backed catalog bridge on launch and after a Custom DNS profile is saved.
This lets persisted custom profiles flow into Benchmark and Catalog screens.

### Edge Cases / Caveats

- If the CLI is unavailable or storage cannot be prepared, the app falls back to
  the built-in preview catalog.
- Refresh is asynchronous; a newly saved profile may appear after the process
  round trip rather than instantly in the same render pass.

### Verification

```text
swift build --package-path apps/macos/DNSPilotMac
Result: build complete
```

---

## Chunk 94: v0.1 macOS DNS-Only Null Latency Decode

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultDecoderTests.swift`, `README.md`

### What changed

Changed benchmark result decoding so `median_connect_latency_ms: null` is valid.
DNS-only compare payloads do not measure TCP latency, so the UI now renders the
result instead of turning it into a generic parse failure.

### Edge Cases / Caveats

- This fixes a schema mismatch, not network-level DNS timeouts.
- DNS-only runs can still be degraded or inconclusive; those states need richer
  failure/process UI next.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultDecoderTests/testDecoderMapsDnsOnlyCompareResult
RED result: failed because null median_connect_latency_ms could not decode as Double

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultDecoderTests/testDecoderMapsDnsOnlyCompareResult
Result: 1 passed, 0 failed
```

---

## Chunk 95: v0.1 macOS Benchmark Domain Input Typing

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`

### What changed

Replaced the Benchmark custom-domain `TextEditor` with a vertical `TextField`.
This avoids the macOS SwiftUI focus/typing issue seen inside the ScrollView form
where paste worked but manual keyboard entry did not.

### Edge Cases / Caveats

- This is a UI behavior fix verified by build; final keyboard behavior still
  needs manual app testing.
- The parser remains unchanged and still accepts whitespace/comma/newline
  separated domains.

### Verification

```text
swift build --package-path apps/macos/DNSPilotMac
Result: build complete
```

---

## Chunk 96: v0.1 macOS Benchmark Progress Failure Details

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkProgressViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutionCoordinator.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkProgressViewModelTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutionCoordinatorTests.swift`, `README.md`, `progress.md`

### What changed

Added benchmark process status rows and structured failure details for DNS-only
and DNS+TCP runs. Failures now include failed step, reason, suggestion, elapsed
time, and debug log with exit code/stdout/stderr/arguments.

### Edge Cases / Caveats

- CLI benchmark execution still does not stream per-stage progress, so running
  DNS+TCP status is coarse-grained until result/failure returns.
- Manual app testing is still needed for real focus behavior and live network
  failure rendering.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkProgressViewModelTests
RED result: failed because BenchmarkProgressViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkExecutionCoordinatorTests
Result: 6 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkProgressViewModelTests
Result: 4 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 97 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 112 passed, 0 failed

git diff --check
Result: clean
```

---

## Chunk 97: v0.1 macOS Benchmark AppKit Domain Input

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MultilineTextInput.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MultilineTextInputTests.swift`, `README.md`, `progress.md`

### What changed

Replaced the Benchmark custom-domain SwiftUI multiline field with an
AppKit-backed `NSTextView` wrapper. This keeps native macOS key input and IME
handling while still updating the SwiftUI binding used by benchmark planning.

### Edge Cases / Caveats

- Manual app testing is still needed because actual keyboard focus/IME behavior
  cannot be fully proven by unit tests.
- If this still fails, the likely cause moves from SwiftUI control choice to
  app/window focus, OS input source, or a parent view stealing first responder.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter MultilineTextInputTests
RED result: failed because DNSPilotMultilineTextInput did not exist

swift test --package-path apps/macos/DNSPilotMac --filter MultilineTextInputTests
Result: 2 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 99 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 112 passed, 0 failed

git diff --check
Result: clean
```

---

## Chunk 98: v0.1 macOS Dev Foreground Activation

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ApplicationActivationPlan.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ApplicationActivationPlanTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MultilineTextInputTests.swift`, `README.md`, `progress.md`

### What changed

Added launch activation bootstrap so the SwiftPM-run macOS app sets regular
activation policy and activates itself. This fixes the dev app being registered
as `BackgroundOnly`, which can leave keyboard events outside the app even when
mouse paste works.

### Evidence

```text
Before: lsappinfo reported ApplicationType="BackgroundOnly"
After:  lsappinfo reported ApplicationType="Foreground"
```

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter ApplicationActivationPlanTests
RED result: failed because DNSPilotApplicationActivationPlan did not exist

swift test --package-path apps/macos/DNSPilotMac --filter ApplicationActivationPlanTests
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter MultilineTextInputTests
Result: 4 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 102 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 112 passed, 0 failed

git diff --check
Result: clean
```

---

## Chunk 99: v0.1 macOS Benchmark Pipe Drain and Verbose Progress

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkProgressViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkPlanViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkProgressViewModelTests.swift`, `README.md`, `progress.md`

### What changed

Fixed benchmark hangs by draining stdout/stderr while the CLI process runs
instead of waiting for process exit before reading pipes. Added two verbose
current-step lines to the Benchmark process panel with resolver/domain/attempt
counts and worst-case DNS wait estimates.

### Evidence

```text
RED: large stdout process blocked, then cancellation killed it with exit 15 and 0 bytes stdout.
GREEN: same process completed with exit 0 and 2,000,000 bytes stdout.
```

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkRunnerTests/testFoundationRunnerDrainsLargeStdoutWhileProcessRuns
RED result: failed with exit 15 and 0 stdout bytes

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkRunnerTests --filter BenchmarkProgressViewModelTests
Result: 13 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 105 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 112 passed, 0 failed

git diff --check
Result: clean
```

---

## Chunk 100: v0.1 macOS Custom DNS Management

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_storage_behaviour.rs`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileFormViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileSaveRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CustomDNSProfileManagementViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MultilineTextInput.swift`

### What changed

Added `profile-update`/`profile-delete`, stable edit IDs, saved-profile rows,
Edit/Delete actions, and AppKit-backed Custom DNS server inputs.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CustomDNSProfile
Result: 18 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_storage_behaviour profile_
Result: 10 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 111 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 101: v0.1 macOS Benchmark Diagnostics and DNS Statuses

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutionCoordinator.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkProgressViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkSetupViewModel.swift`

### What changed

Fixed all-timeout DNS-only parse failures where CLI JSON contains `null`
latency metrics, added parse diagnostics/OSLog, issue-log copy, select-all
runnable profiles, and per-DNS status rows.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultDecoderTests/testDecoderMapsAllFailedDnsOnlyNullLatencyMetrics
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkProgressViewModelTests
Result: 8 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 115 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 102: v0.1 macOS Benchmark Result Trust States

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkProgressViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`

### What changed

Degraded or inconclusive benchmark winners now render as "Best measured
candidate" instead of "Recommended", result rows can show degraded status for
partial failures, and redundant "Recommended profile" notes are filtered from
the user-facing result notes.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultViewModelSoftensRecommendationForDegradedInconclusiveRuns
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkProgressViewModelTests
Result: 8 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 116 passed, 0 failed

cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 103: v0.1 macOS Benchmark Common-Failure Note

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`

### What changed

Added a narrow UI heuristic for degraded benchmark results: when many candidates
fail at a similar partial rate, the result notes now explain that the pattern
can come from the current network, VPN, firewall, captive portal, or IPv6
reachability rather than one bad DNS provider.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultViewModelSoftensRecommendationForDegradedInconclusiveRuns
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 116 passed, 0 failed

cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 104: v0.1 macOS Result Saved-Run Label Polish

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`

### What changed

Changed the Result panel saved-run label from a raw full history ID to a
shorter "Saved run" label. UUID-style history IDs keep the mode prefix plus the
first UUID group, while full IDs remain unchanged in storage/history.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultViewModelShortensLongSavedHistoryIDForResultPanel
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 117 passed, 0 failed

cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 105: v0.1 macOS Result Run Caveats

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultDecoderTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`

### What changed

Decoded optional per-run `caveats` from benchmark JSON and surfaced deduplicated
run caveats in Result notes. This makes real DNS+TCP edge cases visible in the
macOS app, including TCP endpoint failures that often explain uniform 50%
failure rates when IPv6 endpoints are unreachable.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultDecoderTests
Result: 3 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultViewModelIncludesDedupedRunCaveats
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 118 passed, 0 failed

cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 106: v0.1 Path Family Health

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/connection_path.rs`, `crates/dnspilot-core/tests/connection_path_behaviour.rs`

### What changed

Connection-path metrics now combine DNS family health with actual probed TCP/TLS
family health. If DNS returns AAAA successfully but the IPv6 TCP path fails,
`ipv6_health` drops instead of staying at 1.0. This fixes the real 50%
DNS+TCP failure pattern observed on the current network.

### Verification

```text
cargo test -p dnspilot-core --test connection_path_behaviour tcp_family_failures_reduce_path_ip_family_health
Result: 1 passed, 0 failed

rustfmt --check crates/dnspilot-core/src/connection_path.rs crates/dnspilot-core/tests/connection_path_behaviour.rs
Result: clean

cargo test -p dnspilot-core --test connection_path_behaviour
Result: 8 passed, 0 failed

cargo test --workspace --tests
Result: pass

swift test --package-path apps/macos/DNSPilotMac
Result: 118 passed, 0 failed

Runtime path-compare smoke:
Result: completed in about 2.23s; IPv6 TCP failures now report ipv6_health 0.0.
```

---

## Chunk 107: v0.1 macOS Result Family Failure Label

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`

### What changed

Result table failure cells now include weak IP-family context when metrics show
partial failure tied to IPv4 or IPv6 health, for example `50% failed (IPv6
weak)`.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultViewModelLabelsWeakIPFamilyInFailureCell
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests
Result: 7 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 119 passed, 0 failed

cargo test --workspace --tests
Result: pass

git diff --check
Result: clean
```

---

## Chunk 108: v0.1 macOS Sidebar Width

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`

### What changed

Set a wider NavigationSplitView sidebar column so default platform names such as
`Linux Native Power` and `Windows Store` are readable in the default app window.

### Verification

```text
swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac --filter CapabilityMatrixViewModelTests/testDesignTokensStayWithinCompactControlRules
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 119 passed, 0 failed

Runtime screenshot:
Result: platform names no longer truncate in the default window.

git diff --check
Result: clean
```

---

## Chunk 86: v0.1 macOS Result Saved-History Label

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`

### What changed

Benchmark results now expose and render a saved history label when the CLI
returns `saved_history_id`, making auto-save visible to the user.

### Edge Cases / Caveats

- Results without `saved_history_id` keep the panel unchanged.
- The label shows the technical history ID for now; richer friendly timestamps
  belong in the History screen.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkResultViewModel.savedHistoryLabel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 76 passed, 0 failed
```

---

## Chunk 85: v0.1 macOS History UI

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryLoadCoordinator.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryLoadCoordinatorTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryDecoderTests.swift`, `README.md`

### What changed

Added a load coordinator for saved benchmark history and wired a native History
sidebar screen with refresh, loading, empty, error, and saved-run display states.

### Edge Cases / Caveats

- History screen still requires the CLI executable to be available.
- In development without a bundled CLI, use `DNSPILOT_CLI_PATH`.
- Manual UI inspection is still needed for final layout polish.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkHistoryLoadCoordinator did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 76 passed, 0 failed
```

---

## Chunk 84: v0.1 macOS Benchmark History Runner

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryRunner.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryDecoderTests.swift`, `README.md`

### What changed

Added a dedicated history runner that calls `history-list --db <path>` through
the shared process boundary and decodes the saved run payload.

### Edge Cases / Caveats

- Non-zero CLI exits surface stderr first, then stdout, then a default exit-code
  message.
- History loading is separate from benchmark execution so UI can refresh history
  without starting a benchmark.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkHistoryRunner did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 73 passed, 0 failed
```

---

## Chunk 83: v0.1 macOS Benchmark History Decoder

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryModels.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryDecoderTests.swift`, `README.md`

### What changed

Added Swift models for `history-list` JSON, schema validation, and a display
ViewModel that summarizes saved benchmark rows with scope, domains, resolver
count, health, and recommendation labels.

### Edge Cases / Caveats

- Decoder rejects unsupported schema versions.
- ViewModel handles missing recommendation by showing `No recommendation`.
- This does not yet call the CLI or render the History screen.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkHistoryJSONDecoder and BenchmarkHistoryViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 70 passed, 0 failed
```

---

## Chunk 82: v0.1 macOS Benchmark History App Path

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryPersistence.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryPersistenceTests.swift`, `README.md`

### What changed

Added an Application Support persistence factory and wired the Benchmark screen
to create the app SQLite database before launching the CLI. Successful runs now
pass save arguments automatically when the directory can be prepared.

### Edge Cases / Caveats

- If Application Support is unavailable or directory creation fails, benchmark
  still runs without history persistence.
- The app does not yet expose history-list UI or a save-warning banner.
- SQLite write errors from the CLI still return as benchmark process failures.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkHistoryPersistenceFactory did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 67 passed, 0 failed
```

---

## Chunk 81: v0.1 macOS Benchmark History Persistence Args

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryPersistence.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutionCoordinator.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryPersistenceTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutionCoordinatorTests.swift`, `README.md`

### What changed

Added `BenchmarkHistoryPersistence` and `BenchmarkHistoryIDFactory`, then passed
persistence options through the runner/coordinator so benchmark CLI invocations
can append `--save-db` and `--history-id`.

### Edge Cases / Caveats

- This chunk creates the save-argument contract but does not choose the macOS
  Application Support database path yet.
- History IDs use UUIDs, avoiding clock collisions from rapid repeated runs.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkHistoryPersistence and persistence parameters did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 66 passed, 0 failed
```

---

## Chunk 80: v0.1 macOS Benchmark Process Cancellation

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunCancellation.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutionCoordinator.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunCancellationTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutionCoordinatorTests.swift`, `README.md`

### What changed

Added a thread-safe cancellation token, passed it through coordinator and runner,
and registered `Process.terminate()` in the Foundation process runner. The
Benchmark UI now stores the active token and calls `cancel()` when the user
presses Cancel.

### Edge Cases / Caveats

- Process termination is best-effort `terminate()`, not a force-kill escalation.
- A child process that ignores termination can still delay completion.
- The runner handles cancel-before-start by terminating immediately after launch.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkRunCancellation and cancellation parameters did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 62 passed, 0 failed
```

---

## Chunk 79: v0.1 macOS Benchmark Run Controls

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunControlsViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunControlsViewModelTests.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`

### What changed

Added run-control presentation state and wired the Benchmark UI to
`BenchmarkRunStateMachine` for running/cancelling labels, Cancel button
availability, and stale result suppression.

### Edge Cases / Caveats

- Cancelling currently prevents stale completion UI updates but does not
  terminate the underlying `Process`.
- Actual process termination is the next layer.
- Completion after cancellation is rendered as `Benchmark cancelled.` only after
  the background run returns.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkRunControlsViewModel did not exist

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

swift test --package-path apps/macos/DNSPilotMac
Result: 56 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 78: v0.1 macOS Benchmark Run State Machine

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkRunState.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkRunStateTests.swift`, `README.md`

### What changed

Added a small race-safe benchmark run state machine with explicit running,
cancelling, completed, cancelled, and failed states. Each run gets an ID so
stale completions cannot overwrite newer state.

### Edge Cases / Caveats

- Completion after cancellation request is ignored until cancellation finishes.
- Stale run IDs are ignored.
- This does not yet terminate an underlying `Process`; that is the next layer.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkRunStateMachine did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 52 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 77: v0.1 macOS Benchmark Setup UI

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkPlanViewModel.swift`, `README.md`

### What changed

Added the Benchmark sidebar screen with mode picker, runnable profile toggles,
suite picker, custom domain editor, attempt stepper, readiness issues, run
button, and result/error rendering.

### Edge Cases / Caveats

- Run action checks CLI executable availability before launching.
- Benchmark work runs off the main queue.
- Catalog/plan models now conform to `Sendable` for background execution.
- Manual UI inspection is needed for layout, interaction, and dev CLI flow.

### Verification

```text
swift build --package-path apps/macos/DNSPilotMac
Result: build complete; initial Sendable warnings fixed

swift test --package-path apps/macos/DNSPilotMac
Result: 47 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 76: v0.1 macOS Benchmark Setup ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkSetupViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkSetupViewModelTests.swift`, `README.md`

### What changed

Added benchmark setup presentation state for default runnable profiles, first
suite selection, profile/suite options, custom-domain text parsing, and run
readiness combining executable availability with plan validation.

### Edge Cases / Caveats

- Encrypted DNS profiles are visible but marked not runnable for plain CLI
  benchmark mode.
- Explicit `selectedSuiteID: nil` means no suite, not default suite.
- UI rendering and actual interaction state are still separate work.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkSetupViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
RED result: explicit selectedSuiteID nil incorrectly defaulted to first suite

swift test --package-path apps/macos/DNSPilotMac
Result: 47 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 75: v0.1 macOS Custom Domain Plan Validation

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkPlanViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkPlanViewModelTests.swift`, `README.md`

### What changed

Added Swift-side custom domain validation to benchmark plans before process
execution, matching Rust DNS label rules for alphanumeric/hyphen labels and
trailing-dot handling.

### Edge Cases / Caveats

- Custom domains are trimmed for UI input ergonomics.
- Suite domains are trusted from the catalog contract.
- Invalid custom domains block benchmark execution before CLI launch.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because invalid custom domains were accepted

swift test --package-path apps/macos/DNSPilotMac
Result: 43 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 74: v0.1 macOS Benchmark Executable Resolver

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutableResolver.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutableResolverTests.swift`, `README.md`

### What changed

Added executable availability checks on top of the path locator, covering ready,
missing, directory, and non-executable states before launching the benchmark
process.

### Edge Cases / Caveats

- Filesystem is injected for deterministic tests.
- Error text is stable for UI display.
- Packaging still needs to include an executable `dnspilot-cli` resource.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkExecutableResolver did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 41 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 73: v0.1 macOS Benchmark Executable Locator

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutableLocator.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutableLocatorTests.swift`, `README.md`

### What changed

Added path resolution for the benchmark CLI, preferring
`DNSPILOT_CLI_PATH` in development and falling back to a bundled
`dnspilot-cli` resource.

### Edge Cases / Caveats

- Missing CLI returns a stable display message.
- This is a path locator, not a filesystem/executable permission validator.
- Actual packaging/bundling is still not implemented.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkExecutableLocator did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 37 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 72: v0.1 macOS Benchmark Execution Coordinator

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkExecutionCoordinator.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkExecutionCoordinatorTests.swift`, `README.md`

### What changed

Added a sync coordinator that validates and runs a benchmark plan, maps non-zero
CLI exits to displayable errors, decodes successful JSON output, and returns a
benchmark result ViewModel.

### Edge Cases / Caveats

- Invalid plans do not start the process.
- Non-zero exits prefer stderr, then stdout, then exit code text.
- Invalid JSON becomes a stable user-facing parse error.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkExecutionCoordinator did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 34 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 71: v0.1 macOS Benchmark Result ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `README.md`

### What changed

Added presentation labels and rows for decoded benchmark results, including
catalog-backed profile names, confidence/health/scope labels, notes, warning,
and all-failed latency `n/a` guardrails.

### Edge Cases / Caveats

- Result rows use CLI order; sorting/filtering is still UI work.
- All-failed zero latency is displayed as `n/a` to avoid implying a fast run.
- This still does not render the benchmark screen.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkResultViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 30 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 70: v0.1 macOS Benchmark Result Decoder

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultModels.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultDecoderTests.swift`, `README.md`

### What changed

Added Swift models and JSON decoder for compare/path-compare CLI result
payloads, covering summary status, run metrics, optional recommendation, saved
history id, and warning text.

### Edge Cases / Caveats

- Per-sample DNS/TCP/TLS arrays are intentionally not decoded yet.
- `primary_issue` stays a raw string so path-estimate/path-compare issue labels
  can evolve without blocking UI summary rendering.
- CLI result payloads are not schema-versioned yet.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
RED result: failed because BenchmarkResultJSONDecoder did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 28 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed
```

---

## Chunk 66: v0.1 macOS Policy JSON Decoders

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyJSONDecoder.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`

### What changed

Added Swift models and strict JSON decoders for versioned `preflight` and
`apply-policy` payloads. macOS can now parse flush requirement, apply
capability, protected-network disposition, and schema-version failures.

### Before

```mermaid
graph LR
  CLI[versioned preflight/apply JSON] --> GAP[no macOS decoder]
```

### After

```mermaid
graph LR
  CLI[versioned preflight/apply JSON] --> DECODER[macOS policy decoders NEW]
  DECODER --> PREFLIGHT[PreflightPolicy NEW]
  DECODER --> APPLY[ApplyPolicy NEW]
  DECODER --> GATE[schema gate]
```

### Edge Cases / Caveats

- Unknown enum values fail fast instead of falling back.
- Only schema version `1` is supported.
- These decoders are not yet wired into a benchmark/apply UI workflow.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testPreflightDecoderMapsRustCliSchema
RED result: failed because PreflightJSONDecoder and policy models did not exist

swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testApplyPolicyDecoderMapsRustCliSchema
RED result: failed because ApplyPolicyJSONDecoder and policy models did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 18 passed, 0 failed
```

---

## Chunk 67: v0.1 macOS Policy Guidance ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`

### What changed

Added a ViewModel that turns decoded preflight/apply-policy data into UI-ready
guidance labels. It explicitly distinguishes direct resolver benchmarks that do
not need flushing from system-DNS validation that should guide a flush first.

### Before

```mermaid
graph LR
  POLICY[decoded policies] --> UI[future UI would decide labels]
```

### After

```mermaid
graph LR
  POLICY[decoded policies] --> VM[policy guidance ViewModel NEW]
  VM --> FLUSH[flush label NEW]
  VM --> APPLY[apply action label NEW]
  VM --> NOTES[merged notes NEW]
```

### Edge Cases / Caveats

- Guidance labels are English-only for now.
- This is UI guidance, not an OS apply adapter.
- Protected-network policy suppresses apply prompts even if the platform can
  normally apply.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testPolicyGuidanceKeepsDirectBenchmarkFromFlushing
RED result: failed because PolicyGuidanceViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 20 passed, 0 failed
```

---

## Chunk 68: v0.1 macOS Benchmark Plan ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkPlanViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkPlanViewModelTests.swift`, `README.md`

### What changed

Added a testable macOS benchmark planning ViewModel. It turns selected plain DNS
profiles, suite/custom domains, attempts, and DNS-only/path mode into CLI
arguments for `compare` or `path-compare`.

### Before

```mermaid
graph LR
  CATALOG[catalog] --> UI[future benchmark UI]
  UI --> ARGS[would need ad hoc CLI args]
```

### After

```mermaid
graph LR
  CATALOG[catalog] --> PLAN[benchmark plan ViewModel NEW]
  PLAN --> VALIDATION[validation NEW]
  PLAN --> ARGS[compare/path-compare args NEW]
```

### Edge Cases / Caveats

- Only plain DNS profiles with a usable IPv4/IPv6 server are runnable for this
  plain resolver benchmark path.
- DoH/DoT profiles are rejected for this path until encrypted benchmarking is
  implemented.
- This builds arguments only; it does not execute benchmark processes yet.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkPlanViewModelTests/testBenchmarkPlanBuildsCompareArgsFromSelectedProfilesAndSuite
RED result: failed because BenchmarkPlanViewModel did not exist

swift test --package-path apps/macos/DNSPilotMac
Result: 23 passed, 0 failed
```

---

## Chunk 64: v0.1 macOS Catalog Overview UI

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`, `progress.md`

### What changed

Reworked the macOS shell into a sidebar-driven shell with Capabilities and
Catalog destinations. The Catalog detail now renders provider/test-suite
summary metrics and rows using the existing design tokens.

### Before

```mermaid
graph LR
  APP[macOS app] --> CAP[capability matrix only]
  CATVM[catalog ViewModel] --> UNUSED[not rendered]
```

### After

```mermaid
graph LR
  APP[macOS app CHANGED] --> SIDEBAR[sidebar navigation NEW]
  SIDEBAR --> CAP[capability matrix]
  SIDEBAR --> CAT[catalog overview NEW]
  CAT --> METRICS[summary metrics NEW]
  CAT --> ROWS[provider/suite rows NEW]
```

### Edge Cases / Caveats

- Catalog UI currently uses preview catalog data, not live Rust runtime data.
- Unit/build tests verify compilation, but visual spacing and sidebar behavior
  need manual inspection in the running macOS app.
- Menu bar/tray behavior is still not implemented.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
Result: 14 passed, 0 failed

swift build --package-path apps/macos/DNSPilotMac
Result: build complete

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 91 passed, 0 failed
```

---

## Chunk 65: v0.1 Versioned Policy Payloads

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_preflight_behaviour.rs`, `crates/dnspilot-cli/tests/cli_apply_policy_behaviour.rs`, `README.md`

### What changed

Added versioned shell payload wrappers for benchmark preflight and apply-policy
JSON. CLI commands now emit `schema_version` while keeping existing root fields
through flattened payloads.

### Before

```mermaid
graph LR
  CORE[preflight/apply policy] --> CLI[CLI JSON without version]
  CLI --> UI[future shell parser]
```

### After

```mermaid
graph LR
  CORE[preflight/apply policy] --> PAYLOAD[versioned payloads NEW]
  PAYLOAD --> CLI[CLI JSON CHANGED]
  CLI --> UI[future shell parser]
```

### Edge Cases / Caveats

- Existing fields stay at the JSON root; only `schema_version` is added.
- This versions shell/CLI policy payloads, not storage data.
- macOS Swift decoders for these policy payloads are still a later chunk.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour benchmark_preflight_payload_versions_shell_contract
RED result: failed because benchmark_preflight_payload_for/apply_prompt_policy_payload_for did not exist

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_preflight_behaviour preflight_command_outputs_flush_policy_for_system_dns_validation
RED result: failed because preflight JSON emitted null schema_version

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour apply_policy_command_protects_current_dns_when_vpn_is_active
RED result: failed because apply-policy JSON emitted null schema_version

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 93 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 14 passed, 0 failed
```

---

## Chunk 194: v0.1 macOS Guided Apply From Recommendation

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `README.md`, `progress.md`

### What changed

Strong benchmark recommendations now produce store-safe guided apply data. The
result panel can show the recommended profile, tested resolver, IPv4/IPv6 DNS
servers to paste, a copy-DNS action, and a Network Settings handoff while
explicitly stating that DNS Pilot has not changed system DNS.

### Before

```mermaid
graph LR
  RESULT[benchmark result] --> NEXT[next step text]
  NEXT --> SETTINGS[open Network Settings]
```

### After

```mermaid
graph LR
  RESULT[benchmark result] --> APPLY[guided apply model NEW]
  APPLY --> DNS[copy DNS servers NEW]
  APPLY --> SETTINGS[open Network Settings]
  APPLY --> REPORT[result report with servers CHANGED]
```

### Edge Cases / Caveats

- Store-safe builds still do not mutate system DNS silently.
- The result shows the tested resolver separately from provider fallback
  servers, because the benchmark currently measures the selected resolver
  address used for the run.
- Weak/degraded/inconclusive runs still keep current DNS and do not expose an
  apply action.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests
Result: 14 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 180 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 111: v0.1 macOS Confirmed Apply and Flush Guidance

**Status:** Complete

Store-safe guided apply actions now require confirmation before copying DNS
servers and opening macOS Network Settings. Menu bar `Apply Last DNS` opens the
app and confirms before reuse. `Flush DNS...` is available from the menu bar and
System DNS validation mode; it confirms and copies the macOS flush checklist
instead of running sudo/admin commands.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter "BenchmarkResultViewModelTests/testNextStepGuidanceAllowsManualSettingsOnlyForStrongRecommendation|StoreSafeDNSActionViewModelTests|MenuBarQuickActionsViewModelTests"
Result: 10 passed, 0 failed
```

---

## Chunk 112: v0.1 macOS Fastest vs Balanced Result Labels

**Status:** Complete

Benchmark and Game Ping results now show the fastest observed DNS candidate
separately from the balanced recommendation. Reports include both labels so raw
median-DNS speed is not confused with the safety-gated pick.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter "BenchmarkResultViewModelTests/testResultViewModelBuildsRecommendedSummaryAndRows|BenchmarkResultViewModelTests/testResultViewModelSeparatesFastestObservedFromBalancedRecommendation"
Result: 2 passed, 0 failed
```

---

## Chunk 113: v0.1 macOS Selected Profile Guided Apply

**Status:** Complete

Catalog provider rows now expose confirmed store-safe apply for selected plain
DNS profiles. The action copies that profile's DNS servers and opens macOS
Network Settings after confirmation; encrypted or empty profiles do not offer
the guided apply button.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests
Result: 8 passed, 0 failed
```

---

## Chunk 114: v0.1 Saved-Domain Suites

**Status:** Complete

The built-in catalog now includes dedicated YouTube/Google Video, GitHub, and
ChatGPT/OpenAI suites in both the Rust core and macOS preview catalog. Custom
company API domains remain covered through saved custom suites.

### Verification

```text
cargo test -p dnspilot-core --test core_behaviour built_in_catalog_contains_required_profiles_and_suites
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testDefaultCatalogViewModelProvidesPreviewSummary
Result: 1 passed, 0 failed
```

---

## Chunk 216: v0.1 System DNS Validation CLI

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/system_dns.rs`, `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_benchmark_behaviour.rs`, `README.md`, `progress.md`

### What changed

Added a bounded system-DNS benchmark path for post-apply validation. The CLI
`system-benchmark` command measures the OS resolver path, returns normal DNS
metrics/sample JSON, and embeds system-DNS validation preflight guidance so
flush-before-test is scoped to the right workflow.

### Edge Cases / Caveats

- Direct resolver benchmarks still must not flush; they bypass the OS DNS cache.
- System resolver lookup is bounded by a timeout from the caller perspective,
  but an OS resolver worker thread may finish later after a timeout.
- Browser Secure DNS, VPN, MDM, captive portals, and app caches can still
  distort system-DNS validation results.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_benchmark_behaviour system_benchmark_command_outputs_system_dns_validation_payload
Result: RED first, then 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 125 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 215: v0.1 Apply Policy Checklist

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Store-safe apply-policy guidance now has a copyable guided apply checklist. It
states that DNS Pilot has not changed system DNS, includes the recommended
profile, tested resolver, DNS servers, macOS Network Settings steps, and retest
step.

### Edge Cases / Caveats

- Checklist is only available for guide-only plain DNS plans with copyable DNS
  servers.
- Protected/unsupported/not-recommended plans do not expose apply steps.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testApplyPlanViewModel
Result: RED first, then 2 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 214: v0.1 Broader Menu Bar Quick Benchmark

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkSetupViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkSetupViewModelTests.swift`, `README.md`, `progress.md`

### What changed

The menu bar quick benchmark preset now uses a compact three-domain set:
developer (`github.com`), Microsoft login (`login.microsoftonline.com`), and
Vietnam daily (`vnexpress.net`). It remains DNS + TCP, two default unfiltered
resolvers, one attempt, and two TCP targets per domain.

### Edge Cases / Caveats

- This is still a quick estimate, not a full benchmark suite.
- It avoids silent DNS swapping; the result still goes through the store-safe
  apply guide.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkSetupViewModelTests/testQuickRunPresetUsesFastSafeDefaults
Result: RED first, then 1 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 213: v0.1 Recommended Profile in Apply Policy

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Apply-policy guidance now exposes a recommended profile label and renders it
beside the tested resolver and DNS server list. This makes the store-safe
"copy DNS + open settings" path visibly tied to the benchmark winner.

### Edge Cases / Caveats

- The label falls back to `profileID` when a profile name is unavailable.
- This remains guided apply only on the macOS store-safe build; system DNS is
  not changed by the app.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testApplyPlanViewModel
Result: RED first, then 2 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 211: v0.1 History Apply Guardrail

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkHistoryModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkHistoryDecoderTests.swift`, `README.md`, `progress.md`

### What changed

History rows now show explicit apply guidance. Recommended saved runs say to
retest before applying the saved recommendation; weak saved runs say not to
apply from that saved run.

### Edge Cases / Caveats

- Saved history remains a local audit/reference surface, not a live apply-plan
  source.
- This avoids applying stale DNS recommendations without current network,
  confidence, resolver address, and safeguard context.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkHistoryViewModelTests/testViewModelBuildsDisplayRows
Result: 1 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 210: v0.1 Policy-Aware Result Guidance

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `README.md`, `progress.md`

### What changed

Benchmark results now treat apply-policy as the authoritative guidance source
when that policy is loading or available. The legacy next-step panel is hidden
in that state, and copied result reports can omit legacy next-step text before
appending the apply-policy result.

### Edge Cases / Caveats

- If apply-policy is not available at all, the legacy next-step guidance still
  appears as a fallback.
- This prevents safeguard states like VPN/MDM/corporate/captive portal from
  conflicting with an older manual apply suggestion.
- Store-safe behavior remains unchanged: no automatic system DNS mutation.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkResultViewModelTests/testResultReportCanSuppressLegacyNextStepWhenApplyPolicyIsAuthoritative
Result: 1 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 209: v0.1 Guided Apply Primary Action

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

The apply-policy panel now exposes a single guided primary action for store-safe
plain DNS recommendations. It copies the measured DNS server list to the
pasteboard and opens macOS Network Settings, while keeping copy-only and full
apply-plan debug actions available.

### Edge Cases / Caveats

- The guided action appears only for guide-only plans with copyable DNS servers.
- Protected, unsupported, not-recommended, or future power-apply plans do not
  expose this store-safe guided action.
- DNS Pilot still does not mutate system DNS in the store-safe build.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testApplyPlanViewModelGuidesPlainDNSApply
Result: 1 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 197 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 212: v0.1 Vietnam ISP DNS Profiles

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CatalogViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CatalogViewModelTests.swift`, `README.md`, `progress.md`

### What changed

Added FPT Telecom, VNPT, and Viettel plain DNS profiles to the shared catalog
and the macOS preview/fallback catalog. They are Vietnam ISP benchmark
candidates only; recommendations still depend on measured reliability,
latency, and confidence.

### Edge Cases / Caveats

- FPT server data is sourced from FPT; VNPT/Viettel entries are common public
  ISP DNS listings and should remain benchmark-first, not official-best claims.
- Adding these profiles increases the candidate count, so long benchmark
  warnings remain important when all profiles are selected.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour built_in_catalog_contains_required_profiles_and_suites
Result: RED first, then 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter CatalogViewModelTests/testDefaultCatalogViewModelProvidesPreviewSummary
Result: RED first, then 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 124 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 198 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed

git diff --check
Result: no whitespace errors
```

---

## Chunk 207: v0.1 Network Safeguards for Apply Policy

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `README.md`, `progress.md`

### What changed

Added Benchmark UI toggles for VPN active, MDM managed, corporate DNS required,
and captive portal states. These flags feed the shared apply-plan request after
benchmark completion and reload apply policy when changed, so protected networks
can keep current DNS even if the benchmark has a fast candidate.

### Edge Cases / Caveats

- Safeguards affect apply policy only; benchmark measurements still run.
- Quick benchmark presets do not reset safeguards, because safety state should
  survive preset changes.
- Toggles are disabled during an active benchmark to avoid mid-run policy drift.
- Store-safe builds still guide settings changes only; no silent DNS mutation.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 197 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 206: v0.1 Apply Plan Result Report

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkApplyPlanReportFormatter.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Added a report formatter that appends apply-plan status to copied benchmark
reports. The Result screen now copies benchmark details plus apply-policy
loading, success, or failure information when available.

### Edge Cases / Caveats

- If no apply-plan state exists yet, copied reports stay unchanged.
- Loading reports say the apply policy is still checking instead of implying
  guidance is ready.
- Failed apply-plan loads preserve the failure message for issue reports.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac --filter PolicyPayloadDecoderTests/testApplyPlanReportFormatterAppendsLoadedPlan
Result: expected RED compile failure before production code; formatter missing.

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 197 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 205: v0.1 Benchmark Apply Plan UI Wiring

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `README.md`, `progress.md`

### What changed

The Benchmark result screen now loads shared apply-plan policy after a completed
run and displays an Apply policy section. Store-safe plain DNS plans expose copy
DNS and open Network Settings actions; protect/not-recommended/unsupported
plans show policy notes and copyable plan text without changing system DNS.

### Edge Cases / Caveats

- Apply-plan loading is guarded by the benchmark run ID so stale async results
  cannot overwrite a newer run.
- The panel is hidden until loading starts or an apply-plan result exists, so it
  does not render empty dividers.
- Result models now conform to `Sendable` to keep Swift 6 background loading
  warning-free.
- This is still guided apply for store builds; no silent DNS mutation.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 195 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 204: v0.1 Benchmark Apply Plan Load Coordinator

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkApplyPlanLoadCoordinator.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkApplyPlanRequestFactoryTests.swift`, `README.md`, `progress.md`

### What changed

Added a testable coordinator that loads shared apply-plan policy from a
benchmark result and returns either an `ApplyPlanViewModel` or a user-facing
failure message. The coordinator uses closure injection for tests and can wrap
the real `ApplyPlanRunner` in the app shell.

### Edge Cases / Caveats

- Runner failures preserve concrete process messages instead of falling back to
  generic localized errors.
- The coordinator remains side-effect free except for the injected load call;
  SwiftUI still owns async scheduling and current-result staleness checks.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkApplyPlanRequestFactoryTests/testLoadCoordinatorLoadsApplyPlanForBenchmarkResult
Result: expected RED compile failure before production code; coordinator missing.

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 195 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 203: v0.1 Benchmark Result Apply Plan Source

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkApplyPlanRequestFactoryTests.swift`, `README.md`, `progress.md`

### What changed

`BenchmarkResultViewModel` now keeps the source benchmark payload privately and
can create an `ApplyPlanRequest` through the shared request factory. This gives
SwiftUI a typed bridge to apply-plan without reconstructing policy inputs from
display labels.

### Edge Cases / Caveats

- The raw benchmark payload stays private; UI receives only the request builder.
- Profile database URL and protected-network flags are provided by the caller so
  UI/app shell can include runtime context later.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkApplyPlanRequestFactoryTests/testResultViewModelBuildsApplyPlanRequestFromSourcePayload
Result: expected RED compile failure before production code; ViewModel method missing.

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 193 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 202: v0.1 Benchmark Apply Plan Request Factory

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkApplyPlanRequestFactory.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkApplyPlanRequestFactoryTests.swift`, `README.md`, `progress.md`

### What changed

Added a macOS core factory that turns benchmark result payloads into
`ApplyPlanRequest` values for the shared `apply-plan` policy path. It maps
benchmark health to gate health, benchmark confidence to apply-plan confidence,
preserves measured candidates when the gate should decide, and suppresses
profile IDs when the benchmark summary says not to recommend.

### Edge Cases / Caveats

- Low-confidence healthy candidates are still passed to `apply-plan`; the shared
  core returns not-recommended instead of UI code making a parallel decision.
- `canRecommend == false` suppresses profile IDs even if stale result payloads
  still contain a recommended profile.
- Targeted SwiftPM filtering can hang after build in this environment; clean +
  full-suite testing remains the stable verification path.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter BenchmarkApplyPlanRequestFactoryTests
Result: expected RED compile failure before production code; factory missing.

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 192 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 201: v0.1 macOS Apply Plan ViewModel

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Added `ApplyPlanViewModel` to convert decoded apply-plan payloads into stable
status labels, primary action labels, primary-action gating, DNS-server copy
text, and issue-report copy text.

### Edge Cases / Caveats

- Guide-only plans can offer a primary action only when DNS servers are present.
- Protect/unsupported/not-recommended plans cannot expose apply actions.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 188 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 200: v0.1 macOS Apply Plan Runner

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ApplyPlanRunner.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ApplyPlanRunnerTests.swift`, `README.md`, `progress.md`

### What changed

Added a macOS core runner boundary for `dnspilot-cli apply-plan`. The app can
now build apply-plan CLI arguments, invoke the helper through the shared process
runner, decode the payload, and surface process failures.

### Edge Cases / Caveats

- This is process-boundary plumbing, not UI wiring yet.
- Incremental SwiftPM test runs can hang at XCTest bundle load in this local
  environment; clean + full test remains the reliable validation path.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 186 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 197: v0.1 Shared Apply Plan Contract

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-core/tests/core_behaviour.rs`, `README.md`, `progress.md`

### What changed

Added a shared Rust `apply_plan_for` contract. It combines the benchmark
recommendation gate, recommendation confidence/decision, platform capability,
network environment, and DNS profile data before any UI or future power adapter
offers DNS apply.

### Edge Cases / Caveats

- Store-safe plain DNS is guide-only, not silent system mutation.
- Power/native platforms can plan user-approved plain DNS apply, but the actual
  privileged adapter remains a later edition.
- Managed network signals still force Protect current DNS before profile logic.

### Verification

```text
cargo fmt --all
Result: formatted

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour
Result: 25 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 120 passed, 0 failed
```

---

## Chunk 198: v0.1 CLI Apply Plan Payload

**Status:** Complete
**Files changed:** `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_apply_policy_behaviour.rs`, `README.md`, `progress.md`

### What changed

Added `dnspilot-cli apply-plan`, a versioned JSON shell command for the shared
apply-plan contract. UI shells can now request guide/apply/protect decisions
from core inputs instead of duplicating platform policy rules.

### Edge Cases / Caveats

- The command accepts recommended profile ID, gate health, recommendation
  confidence, optional profile DB, and managed-network flags.
- It still returns a plan only; no OS DNS mutation happens in the CLI.

### Verification

```text
cargo fmt --all
Result: formatted

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour
Result: 4 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 122 passed, 0 failed
```

---

## Chunk 199: v0.1 macOS Apply Plan Decoder

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyJSONDecoder.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Added macOS Swift models and decoder for the Rust `apply-plan` shell payload.
The native shell can now parse guide/apply/protect/not-recommended decisions,
profile metadata, DNS servers, and notes from the shared core contract.

### Edge Cases / Caveats

- Decoder rejects unsupported schema versions.
- This is decode/readiness plumbing; UI wiring to call `apply-plan` remains a
  later chunk.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac
Result: 183 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 196: v0.1 Manual Apply Checklist

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `progress.md`

### What changed

Strong plain-DNS recommendations now expose a copyable manual apply checklist
beside the DNS-server copy action. The checklist includes the recommended
servers, macOS Network Settings handoff, retest guidance, and override caveats
for VPN, MDM, corporate DNS, captive portals, and browser Secure DNS.

### Edge Cases / Caveats

- The checklist is only exposed when manual apply is actually eligible.
- This remains guided apply; Store-safe builds still do not change system DNS.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 181 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 195: v0.1 Harden Manual Apply Eligibility

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkResultViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkResultViewModelTests.swift`, `progress.md`

### What changed

Manual apply is now gated on copyable plain DNS server data. Strong benchmark
winners that are encrypted-only, missing from the loaded catalog, or missing
IPv4/IPv6 server addresses no longer expose the apply/open-settings action.
They show a specific unavailable reason instead.

### Edge Cases / Caveats

- This keeps Store-safe builds from implying that encrypted DNS profiles can be
  applied through the current plain DNS settings flow.
- SwiftPM test filtering hung while loading the test bundle in this environment;
  cleaning the package and running the full suite passed.

### Verification

```text
swift package --package-path apps/macos/DNSPilotMac clean
Result: clean complete

swift test --package-path apps/macos/DNSPilotMac
Result: 181 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 208: v0.1 Apply Plan Tested Resolver

**Status:** Complete
**Files changed:** `crates/dnspilot-core/src/lib.rs`, `crates/dnspilot-cli/src/main.rs`, `crates/dnspilot-cli/tests/cli_apply_policy_behaviour.rs`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ApplyPlanRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/BenchmarkApplyPlanRequestFactory.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyModels.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyJSONDecoder.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PolicyGuidanceViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ApplyPlanRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/BenchmarkApplyPlanRequestFactoryTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PolicyPayloadDecoderTests.swift`, `README.md`, `progress.md`

### What changed

Apply-plan payloads now preserve the resolver address that actually won the
benchmark. Plain-DNS apply plans move that measured resolver to the top of the
copyable DNS server list when it belongs to the recommended profile, while
keeping remaining provider addresses as fallbacks.

### Edge Cases / Caveats

- Store-safe builds still guide/copy/open settings only; no system DNS mutation
  is performed.
- If the measured resolver is not part of the profile server list, the original
  provider order is kept and the plan notes explain the mismatch.
- Custom profile databases are covered so user-added DNS options can still
  produce copyable apply plans.

### Verification

```text
CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour apply_plan_command_preserves_tested_resolver_as_primary_dns_server
Result: 1 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac --filter ApplyPlanRunnerTests/testRequestBuildsApplyPlanArguments
Result: 1 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-cli --test cli_apply_policy_behaviour
Result: 6 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test -p dnspilot-core --test core_behaviour
Result: 25 passed, 0 failed

CARGO_INCREMENTAL=0 cargo test --workspace --tests
Result: 124 passed, 0 failed

swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac
Result: 197 passed, 0 failed

./script/build_and_run.sh --verify
Result: macOS bundle structural validation passed
```

---

## Chunk 115: v0.1 macOS Product Goal Readiness

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ProductGoalReadinessViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ProductGoalReadinessViewModelTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

The macOS Capabilities screen now includes a Product Goals readiness section.
It shows the current support level for fastest DNS, balanced DNS, selected DNS
apply, DNS flush, saved domain suites, and game server checks.

### Edge Cases / Caveats

- Apply and flush are intentionally marked as Store-safe guided, not silent
  system mutation.
- Game checks are marked as estimates because they use DNS + TCP path probes,
  not ICMP ping or in-match UDP latency.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter ProductGoalReadinessViewModelTests
Result: 3 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 229 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```

---

## Chunk 119: v0.1 macOS Permission and Publish Readiness

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSReadinessViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSReadinessViewModelTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added native sidebar screens for Permissions and Publish. Permissions explains
ask-as-needed authorization, including Network Settings handoff and admin
approval only when Power apply/flush is pressed. Publish separates App Store
edition requirements from Power edition distribution.

### Edge Cases / Caveats

- macOS does not provide a normal pre-grant permission for plain DNS edits.
- Release signing, provisioning, App Store entitlement approval, and review
  metadata remain manual publisher steps.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter MacOSReadinessViewModelTests
Result: 3 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 244 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```

---

## Chunk 120: v0.1 macOS Localization Foundation

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/DNSPilotLocalization.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/DNSPilotLocalizationTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added English/Vietnamese language options and a native Settings scene. Top-level
navigation, Settings, and the new readiness surfaces use the localizer.

### Edge Cases / Caveats

- Existing deep benchmark/result strings remain English until the next
  localization pass.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter DNSPilotLocalizationTests --filter MacOSReadinessViewModelTests
Result: 7 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 244 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```

---

## Chunk 121: v0.1 macOS Publishing Source of Truth

**Status:** Complete
**Files changed:** `apps/macos/PUBLISHING.md`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added the macOS publishing source-of-truth with App Store and Power edition
tracks, local release gate commands, signing/entitlement checks, App Store
manual submission steps, Power manual QA steps, and current blockers.

### Edge Cases / Caveats

- App Store edition must keep Power apply/flush disabled and use guided flows.
- Power edition can request administrator approval, but needs real manual QA
  because it can change system DNS and flush DNS cache.
- Release signing, provisioning, App Store Connect metadata, screenshots, and
  final upload remain publisher-owned manual steps.

### Verification

```text
git diff --check
Result: passed
```

---

## Chunk 122: v0.1 macOS Native Localization Pass

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/DNSPilotLocalization.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/DNSPilotLocalizationTests.swift`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Expanded English/Vietnamese localization keys and wired the localizer through
primary native surfaces: Benchmark, Game Ping, Custom DNS, History, Catalog,
Capability Matrix, and common result/failure/progress labels.

### Edge Cases / Caveats

- Technical CLI/debug payload strings remain English to preserve issue-report
  precision.
- `BenchmarkDetailView` was split into smaller SwiftUI subviews because the
  localized body otherwise exceeded Swift compiler type-check limits.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter DNSPilotLocalizationTests
Result: 5 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 245 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed
```

---

## Chunk 123: v0.1 macOS App Store Metadata Template

**Status:** Complete
**Files changed:** `apps/macos/AppStoreConnect/README.md`, `apps/macos/PUBLISHING.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added an App Store Connect source-of-truth covering product identity, subtitle,
description, keywords, review notes, privacy notes, screenshot checklist, and
manual release blockers.

### Edge Cases / Caveats

- Support URL, marketing URL, final privacy answers, and screenshots remain
  manual publisher inputs.
- Metadata assumes the current store-safe build; update it if telemetry, sync,
  accounts, remote catalog updates, or Power edition distribution are added.

### Verification

```text
git diff --check
Result: passed
```

---

## Chunk 124: v0.1 macOS Distribution Packaging Script

**Status:** Complete
**Files changed:** `script/package_macos_distribution.sh`, `apps/macos/PUBLISHING.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added a release packaging driver that requires a distribution signing identity,
signs the app/helper with existing entitlement templates, runs distribution
bundle validation, and creates a `.pkg` with an optional installer identity.

### Edge Cases / Caveats

- The script does not upload to App Store Connect.
- Real signing identities and installer identity remain manual Apple Developer
  account inputs.
- The script intentionally fails if no distribution app signing identity is
  provided, so ad-hoc signed builds are not mistaken for release artifacts.

### Verification

```text
bash -n script/package_macos_distribution.sh
Result: passed

git diff --check
Result: passed
```

---

## Chunk 125: v0.1 macOS Power Edition Bundle Switch

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSPowerDNSActionRunner.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSReadinessViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ProductGoalReadinessViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSPowerDNSActionRunnerTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSReadinessViewModelTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ProductGoalReadinessViewModelTests.swift`, `script/build_and_run.sh`, `script/validate_macos_bundle.sh`, `script/package_macos_distribution.sh`, `README.md`, `apps/macos/PUBLISHING.md`, `apps/macos/AppStoreConnect/README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Power edition can now be enabled by bundle metadata through
`DNSPilotPowerActionsEnabled=true`, not only by Terminal environment. The local
build script can create a Power bundle with `DNSPILOT_POWER_EDITION=1`, and the
validator distinguishes Store-safe bundles from Power bundles.

### Edge Cases / Caveats

- Store-safe/App Store validation rejects Power-enabled distribution bundles by
  default.
- Power edition still requires manual QA because admin apply/flush mutates real
  macOS DNS state.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter MacOSPowerDNSActionRunnerTests --filter MacOSReadinessViewModelTests --filter ProductGoalReadinessViewModelTests
Result: 14 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 247 passed, 0 failed

cargo test --workspace --tests
Result: 125 passed, 0 failed

bash -n script/build_and_run.sh script/validate_macos_bundle.sh script/package_macos_distribution.sh
Result: passed

DNSPILOT_POWER_EDITION=1 ./script/build_and_run.sh --sandbox-verify
Result: macOS Power bundle structural validation passed

./script/build_and_run.sh --sandbox-verify
Result: macOS Store-safe bundle structural validation passed

git diff --check
Result: passed
```

---

## Chunk 118: v0.1 macOS Power Capability Alignment

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/CapabilityMatrixViewModel.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/ProductGoalReadinessViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/CapabilityMatrixViewModelTests.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/ProductGoalReadinessViewModelTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

The Swift preview capability matrix now includes `macos-power`, matching the
Rust core capability model. Product Goals caveats now explicitly mention the
`DNSPILOT_ENABLE_POWER_ACTIONS` path for admin apply/flush.

### Edge Cases / Caveats

- macOS Store remains the default store-safe product path.
- macOS Power is direct-install only and not App Store-safe.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter CapabilityMatrixViewModelTests/testDefaultMatrixIncludesPlatformFlushAndApplyPolicy --filter ProductGoalReadinessViewModelTests/testApplyAndFlushStayHonestAboutStoreSafeLimits
Result: 2 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 237 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```

---

## Chunk 117: v0.1 macOS Power Apply/Flush UI

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`, `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/StoreSafeDNSActionViewModel.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/StoreSafeDNSActionViewModelTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Power apply buttons now appear in Benchmark recommendation, legacy next-step,
and Catalog profile flows only when `DNSPILOT_ENABLE_POWER_ACTIONS=1`.
The Flush DNS confirmation dialog also offers `Flush Now (Admin)` only under
that same explicit flag.

### Edge Cases / Caveats

- Default store-safe builds keep copy/open-settings guidance only.
- Power actions run asynchronously so the macOS administrator prompt does not
  block SwiftUI state updates.
- Power apply targets the active network service; unusual VPN or enterprise
  routing can still fail and surfaces as a user-visible error alert.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter StoreSafeDNSActionViewModelTests --filter MacOSPowerDNSActionRunnerTests
Result: 11 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 237 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```

---

## Chunk 116: v0.1 macOS Power DNS Action Runner

**Status:** Complete
**Files changed:** `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSPowerDNSActionRunner.swift`, `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSPowerDNSActionRunnerTests.swift`, `README.md`, `apps/macos/macos-progress.md`, `progress.md`

### What changed

Added a disabled-by-default macOS Power DNS action runner for future
direct-install builds. When explicitly enabled, it builds an administrator
AppleScript prompt to apply plain DNS servers to the active macOS network
service and flush local DNS cache.

### Edge Cases / Caveats

- Store-safe builds keep using guided copy/open-settings flows.
- The runner validates DNS server strings before prompting for administrator
  rights.
- Active service detection can still fail on unusual routing/VPN/enterprise
  network setups; the process error is returned to the UI layer.

### Verification

```text
swift test --package-path apps/macos/DNSPilotMac --filter MacOSPowerDNSActionRunnerTests
Result: 6 passed, 0 failed

swift test --package-path apps/macos/DNSPilotMac
Result: 235 passed, 0 failed

git diff --check
Result: passed

./script/build_and_run.sh --sandbox-verify
Result: macOS bundle structural validation passed; app exposed an on-screen window
```
