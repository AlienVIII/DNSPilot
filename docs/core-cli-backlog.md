# Core CLI Backlog

Last reviewed: 2026-07-19.

Core owns catalog, benchmark, recommendation, policy, persistence, history, apply-plan,
and versioned JSON/JSONL behavior. OS shells own settings URIs, distro/package discovery,
permission presentation, and privileged implementation unless two consumers prove one
shared policy contract.

## Priority Requests

1. **P0 DNS response integrity**
   Connect UDP to the selected resolver; generate unpredictable transaction IDs; require
   QR/standard opcode/one matching question/class/type/source before success. Add
   adversarial parser and resolver tests.
2. **P1 transaction-safe mutation**
   Keep schema v1 but load/validate/mutate/save inside `BEGIN IMMEDIATE` with a revision
   or explicit conflict outcome. Test concurrent profile, suite, and history writers.
3. **P1 structured issue/message IDs**
   Add stable locale-neutral IDs for errors, caveats, safety notes, and guidance. Shells
   localize IDs; raw Core text remains copyable technical evidence only.
4. **P1 progress JSONL contract**
   Version one schema across compare, path-compare, and system-benchmark with
   `schema_version`, `run_id`, event/status/failure kind, and exactly one terminal event.
   Test cancellation and no-partial-history semantics.
5. **Evidence-led extensions only**
   Add `runtime-info --json` only after a second consumer proves the same need. Do not
   move platform Settings metadata, Linux capability detail, or admin helpers into Core.

## Lane Feedback

- macOS: shared system-benchmark progress/history is resolved. Needs stable IDs; Power
  compare-before-restore remains app-side.
- Linux: typed Core SQLite/results and streamed progress are resolved. Keep package,
  resolver-stack, D-Bus, and polkit detection lane-local.
- Windows: existing contracts cover milestones 0-4. Needs stable IDs; Settings URI and
  future Power remain Windows-owned.
- Mobile: native adapter already wraps `dnspilot-core`. Preserve one payload schema and
  foreground jobs; bridge security and OS handoff remain app-owned.

## Validation Contract

Every Core item lands with targeted Rust tests and:

```bash
cargo test --workspace --tests
```

Run each affected platform decoder gate. Record unavailable native checks as `NOT RUN`.
