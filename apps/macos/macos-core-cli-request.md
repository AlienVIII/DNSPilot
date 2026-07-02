# macOS Core CLI Requests

## Required APIs
- Stable benchmark progress JSONL events.
- Stable system-DNS validation payload compatible with result decoder.
- Flush guidance payload with platform-specific wording.

## Required Contracts
- Apply-plan remains authoritative for copy/open-settings guidance.
- Benchmark results include health, confidence, primary issue, warnings, and row-level failure data.

## Required Logging
- Failed benchmark payloads include failed step, elapsed time, stderr summary, and debug-safe raw logs.

## Open Requests
- None for v0.1 macOS core flows.

## macOS Compatibility Adapter
- `system-benchmark` now exposes UI-ready `summary`, `runs`, `recommendation: null`, and preflight fields.
- macOS still adapts legacy `system-benchmark` payloads when `scope == "system-dns-validation"` for backward compatibility.
- `system-benchmark` supports `--progress-jsonl`, `--save-db`, and `--history-id`; macOS can show per-run progress and save validation runs to local history.
