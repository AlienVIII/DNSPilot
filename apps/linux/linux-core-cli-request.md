# Linux Core CLI Requests

Last reviewed: 2026-07-13.

## Current Status

The shared CLI already exposes the catalog, capability, preflight, apply-policy,
apply-plan, benchmark, system-benchmark, compare, path-compare, profile, suite, and
history commands required by Store-safe Linux. Linux should consume these versioned
JSON/JSONL contracts instead of requesting or duplicating product behavior.

## Remaining Integration Needs

- Keep every shell payload schema-versioned and compatibility-tested across consumers.
- Preserve live progress JSONL on stderr and final JSON on stdout for compare,
  path-compare, and system-benchmark.
- Preserve `--save-db`/`--history-id` and profile/suite/history SQLite commands.
- Do not put Linux privilege or resolver-owner detection into the shared core. Those are
  Linux capability-adapter concerns.
- Raise a shared CLI request only if implementation proves a missing cross-platform
  contract; do not add a parallel Linux-only storage or recommendation rule.

## Required Contracts
- Flatpak/Snap store-safe builds default to benchmark/guidance.
- deb/rpm Power remains a Linux adapter capability and is unavailable for release until
  its system D-Bus/polkit/exact-rollback gate passes.
- deb/rpm without resolver stack plus polkit must stay diagnostics-only for apply.
- Unsupported benchmark modes must be rejected before run start.
- Linux shell currently maps DNS only to `compare`, DNS + TCP to `path-compare`, and current resolver validation to `system-benchmark`.
- Direct benchmark runs expect progress JSONL on stderr and final payload JSON on stdout.

## Required Logging
- Distro/package capability detection logs must be issue-report friendly.
- Process reports need per-step and per-resolver status details.
- Debug reports need enough package, resolver-stack, and capability notes for later QA.
