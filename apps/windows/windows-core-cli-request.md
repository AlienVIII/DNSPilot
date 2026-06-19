# Windows Core CLI Requests

## Required APIs
- Windows platform capability payload. Current CLI exposes `windows-store` and `windows-power` platform IDs.
- Guided settings apply plan for store build. Current app can call `apply-plan windows-store` and render copy/open-settings guidance.
- Power apply contract for later admin service.
- Optional future: include Windows Settings URI/action labels directly in core apply-plan payload if core wants to own platform handoff copy.

## Required Contracts
- Store build must not require elevation.
- Admin/service behavior must be separate from store-safe shell.
- System DNS validation is consumed through `system-benchmark --platform windows-store`.
- DNS-only benchmark is consumed through `compare`.
- DNS + TCP benchmark is consumed through `path-compare`.
- Catalog is consumed through `catalog`.
- Capability matrix is consumed through `capabilities`.
- Profile management is consumed through `profile-add`, `profile-update`, `profile-delete`, and `profile-list`.
- History management is consumed through `history-list`, `history-delete --id`, and `history-clear`.

## Required Logging
- Process errors should include command, exit code, and safe stderr summary.
- Windows core runner now records command, exit code, stdout/stderr summary, failed step, elapsed time, and copyable report text.
