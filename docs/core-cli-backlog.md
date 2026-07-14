# Core CLI Backlog

Last reviewed: 2026-07-14.

Review status: behavior contracts are resolved for the current v0.1 app slice.
Structured issue/message IDs are now a blocker for complete localized macOS result
and failure UI; they remain shared Core work rather than a shell-side English parser.

Core CLI already provides the main shared contracts used by platform lanes:
catalog, capabilities, compare, path-compare, system-benchmark, preflight,
apply-policy, apply-plan, profile storage, suite storage, history, and progress
JSONL for direct resolver and system-DNS validation flows. Do not duplicate
those behaviors in platform UI unless a lane doc records a temporary adapter.
Do not reopen the old system-benchmark UI-parity request; it is resolved for
v0.1 unless a lane records a new schema gap with failing evidence.

## Priority Requests

1. **Structured issue/message IDs**
   - Add locale-neutral message IDs or structured issue fields for errors,
     caveats, safety notes, and guidance currently returned as free text.
   - Platforms should localize from stable IDs instead of parsing English text.

2. **Progress event contract hardening**
   - Stabilize one documented progress JSONL schema across DNS-only, DNS+TCP,
     TLS-enabled path checks, and system-DNS validation.
   - Include resolver ID, step, status, elapsed time, failure kind, and safe
     human/debug summaries.

3. **Platform guidance payloads**
   - Extend preflight/apply-plan payloads only where shared payloads reduce real
     duplication: flush guidance, settings handoff metadata, restore guidance,
     protected-network dispositions, and explicit unsupported states.
   - Keep platform-specific UI copy app-side unless a field must be shared for
     policy consistency.

4. **Power/admin helper contracts**
   - Keep privileged DNS mutation as plan-only contracts until a platform lane
     has a real helper implementation.
   - Model macOS Power, Windows Power, and Linux deb/rpm Power separately from
     store-safe SKUs.

5. **Linux capability ownership decision**
   - Decide whether package/resolver/polkit capability detection stays in the
     Linux lane or becomes a Core CLI structured probe.
   - Move it into Core only if multiple lanes or CLI workflows need the same
     payload; otherwise keep Linux-specific distro detail app-side.

## Resolved For v0.1

- `system-benchmark` emits UI-ready `summary`, `runs`,
  `recommendation: null`, preflight, and legacy compatibility fields.
- `system-benchmark` supports `--progress-jsonl`, `--save-db`, and
  `--history-id` so platform lanes can show progress and save validation runs.
- DNS benchmark result samples expose optional `failure_detail`; timeout and
  resolver failures have Core and CLI regression tests.

## Lane Requests

### macOS

- Keep `apply-plan` authoritative for copy/open-settings guidance.
- Preserve tested resolver ordering in copied DNS server lists.
- System-DNS validation parity is available; macOS keeps only a backward
  compatibility adapter for legacy payloads.
- Keep Power edition explicit and gated by bundle/env metadata.
- Structured issue/message IDs are required for localized result status, caveats,
  failure reasons, and preflight copy. Preserve raw technical detail separately for
  issue reports.

### Mobile

- Mobile release builds now use a local Expo module backed by a Rust adapter around
  `dnspilot-core`; the Node bridge is development fallback only.
- Preserve compact foreground job/progress payloads across native adapter changes.
- Keep explicit unsupported/apply-via-settings dispositions for iOS/iPadOS and
  Android.
- Avoid any contract that implies iOS plain system DNS switching or Android
  silent DNS mutation.
- Keep the native adapter contract aligned with Core payload schemas; do not create a
  second recommendation or persistence implementation.
- Stable issue/message IDs would let mobile localize system-access and bridge
  failures without parsing English text.

### Linux

- Decide whether Linux package capability detection remains shell-local or moves
  into Core CLI as a structured capability probe.
- If moved into Core CLI, model Flatpak, Snap, deb, rpm, NetworkManager,
  systemd-resolved, polkit present/missing, and diagnostics-only states.
- Keep store/sandbox guidance separate from deb/rpm native-power apply plans.
- Keep the current native helper protocol lane-local until a second consumer
  needs a shared Core CLI contract.

### Windows

- Add stable message IDs for notes/errors/safety guidance consumed by localized
  Windows UI.
- Optional: expose Windows Settings action metadata in apply-plan if this avoids
  duplicated platform handoff logic.
- Future only: define a Windows Power service/admin apply plan contract without
  adding Store-lane elevation behavior.
- Proposed `runtime-info --json` remains deferred until Linux confirms the same
  version/readiness need; Windows can probe existing contracts meanwhile.

## Temporary Adapters To Retire

- Mobile keeps a local Node bridge only for Expo Go/web development fallback.
- Linux capability detection is currently implemented in the Linux lane.
- Windows localizes some dynamic free-text because CLI payloads do not yet expose
  stable message IDs.

## Compatibility Adapters To Keep

- macOS still adapts legacy `system-benchmark` payloads with
  `scope == "system-dns-validation"` for older CLI builds.

## Validation Contract

Every Core CLI backlog item should land with targeted Rust tests plus:

```bash
cargo test --workspace --tests
```

If a change affects a platform decoder, run that lane's validation or update the
lane request doc with exact follow-up commands.
