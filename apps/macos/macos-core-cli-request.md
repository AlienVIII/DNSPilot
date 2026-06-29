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
- Expose system-DNS validation in UI-ready schema with `summary`, `runs`, `recommendation: null`, and preflight.

## macOS Temporary Adapter
- macOS currently adapts `system-benchmark` payloads locally when `scope == "system-dns-validation"`.
- `system-benchmark` supports `--progress-jsonl`, `--save-db`, and `--history-id`; macOS can show per-run progress and save validation runs to local history.
