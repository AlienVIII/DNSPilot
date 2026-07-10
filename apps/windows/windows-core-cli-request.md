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
- Suite management is consumed through `suite-add`, `suite-update`, `suite-delete`, and `suite-list`.
- History management is consumed through `history-list`, `history-delete --id`, and `history-clear`.
- Protected-network apply suppression is consumed through `apply-plan` dispositions such as `protect-current-dns`.

## Required Logging
- Process errors should include command, exit code, and safe stderr summary.
- Windows core runner now records command, exit code, stdout/stderr summary, failed step, elapsed time, and copyable report text.

## Localization Requests
- Add a CLI payload localization contract for notes/errors/safety guidance currently returned as free text.
- Prefer stable message IDs plus structured fields over pre-localized free text so Windows, macOS, Linux, and mobile can render localized UI consistently.
- Keep CLI JSON payloads machine-readable and locale-neutral by default; localized display strings can be optional fields or app-side resources.
