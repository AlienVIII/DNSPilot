# Core CLI Backlog

Last reviewed: 2026-08-24.

Core owns catalog, benchmark, recommendation, policy, persistence, history, apply-plan,
and versioned JSON/JSONL behavior. OS shells own settings URIs, distro/package discovery,
permission presentation, and privileged implementation unless two consumers prove one
shared policy contract.

## Active Requests

1. **P0 separate Health Check contract**
   Define versioned observations, measured/inferred/unsupported evidence, confidence,
   capability gaps, stable reason IDs, privacy boundaries, manual recheck guidance, and
   progress lifecycle. Keep it independent from DNS Benchmark scores and history.
2. **P0 restore Rust 1.96 clippy**
   Fix the three median helpers flagged by `manual_is_multiple_of`. Replace the private
   nine-argument `apply_plan` helper with one typed input/options object unless review
   proves a narrower refactor; do not add a broad lint allow or lower `-D warnings`.
3. **P1 remaining structured IDs**
   Migrate recommendation reasons/caveats and history metadata. Preserve raw Details and
   backward decoding until every shell proves the typed path.
4. **Evidence-led extensions only**
   Add `runtime-info --json` only after a second consumer proves the same need. Do not
   move platform Settings metadata, notification APIs, task scheduling, distro discovery,
   or privileged helpers into Core.

## Resolved Baseline

- DNS response identity/semantics are hardened.
- SQLite snapshot mutations are transaction-safe across processes.
- Progress JSONL has one `run_id`, stable failures, terminal/cancel events, and no partial
  history on cancellation.
- Recommendation gate, capability, preflight/apply, profile-security, and connection-path
  detail families expose additive stable IDs.

## Lane Feedback

- macOS: current benchmark lifecycle is sufficient for D14. Background lifetime, local
  receipt, UserNotifications, authorization truth, exact-result activation, and
  scheduling diagnostics remain app-side. The current macOS `runID` activation gap does
  not require a Core notification API.
- Linux: typed Core SQLite/results and streamed progress are resolved. Keep package,
  resolver-stack, D-Bus, and polkit detection lane-local.
- Windows: existing contracts cover current benchmark execution. Settings URI,
  `AppNotificationManager`, process lifetime, and future Power remain Windows-owned.
- Mobile: native adapter wraps `dnspilot-core`. Background feasibility, OS expiration,
  notification permission, and activation are native app concerns; do not add a Core
  scheduler or retry contract.

## Validation Contract

Every Core item lands with targeted Rust tests and:

```bash
cargo test --workspace --tests
```

Run each affected platform decoder gate. Record unavailable native checks as `NOT RUN`.
