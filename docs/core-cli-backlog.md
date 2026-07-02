# Core CLI Backlog

Last reviewed: 2026-07-02.

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

## Lane Requests

### macOS

- Keep `apply-plan` authoritative for copy/open-settings guidance.
- Preserve tested resolver ordering in copied DNS server lists.
- System-DNS validation parity is available; macOS keeps only a backward
  compatibility adapter for legacy payloads.
- Keep Power edition explicit and gated by bundle/env metadata.
- Next shared need, if any, is structured issue/message IDs for release UI and
  preflight copy. No open v0.1 blocker.

### Mobile

- Provide compact progress events usable by a foreground mobile run.
- Keep explicit unsupported/apply-via-settings dispositions for iOS/iPadOS and
  Android.
- Avoid any contract that implies iOS plain system DNS switching or Android
  silent DNS mutation.
- If native bindings become the chosen release path, document which CLI/core
  functions must be exposed through FFI/native modules.
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

## Temporary Adapters To Retire

- Mobile uses a local Node bridge to spawn the Rust CLI; release architecture is
  undecided.
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
