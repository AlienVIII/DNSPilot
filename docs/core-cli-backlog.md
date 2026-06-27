# Core CLI Backlog

Last reviewed: 2026-06-27.

Core CLI already provides the main shared contracts used by platform lanes:
catalog, capabilities, compare, path-compare, system-benchmark, preflight,
apply-policy, apply-plan, profile storage, suite storage, history, and progress
JSONL for direct resolver benchmark flows. Do not duplicate those behaviors in
platform UI unless a lane doc records a temporary adapter.

## Priority Requests

1. **System DNS validation parity**
   - Make `system-benchmark` output match app result decoder shape:
     `summary`, `runs`, `recommendation: null`, platform/preflight metadata,
     and machine-readable failed step/reason.
   - Decide whether `system-benchmark` should support `--progress-jsonl`,
     `--save-db`, and `--history-id`; if intentionally stateless, document that
     contract so platform lanes stop adding temporary adapters.

2. **Structured issue/message IDs**
   - Add locale-neutral message IDs or structured issue fields for errors,
     caveats, safety notes, and guidance currently returned as free text.
   - Platforms should localize from stable IDs instead of parsing English text.

3. **Progress event contract hardening**
   - Stabilize one progress JSONL schema across DNS-only, DNS+TCP, TLS-enabled
     path checks, and future system-DNS validation.
   - Include resolver ID, step, status, elapsed time, failure kind, and safe
     human/debug summaries.

4. **Platform guidance payloads**
   - Extend preflight/apply-plan payloads only where shared payloads reduce real
     duplication: flush guidance, settings handoff metadata, restore guidance,
     protected-network dispositions, and explicit unsupported states.
   - Keep platform-specific UI copy app-side unless a field must be shared for
     policy consistency.

5. **Power/admin helper contracts**
   - Keep privileged DNS mutation as plan-only contracts until a platform lane
     has a real helper implementation.
   - Model macOS Power, Windows Power, and Linux deb/rpm Power separately from
     store-safe SKUs.

## Lane Requests

### macOS

- Keep `apply-plan` authoritative for copy/open-settings guidance.
- Preserve tested resolver ordering in copied DNS server lists.
- Add system-DNS validation parity noted above so macOS can remove its temporary
  local adapter for result shape/progress/history.
- Keep Power edition explicit and gated by bundle/env metadata.

### Mobile

- Provide compact progress events usable by a foreground mobile run.
- Keep explicit unsupported/apply-via-settings dispositions for iOS/iPadOS and
  Android.
- Avoid any contract that implies iOS plain system DNS switching or Android
  silent DNS mutation.
- If native bindings become the chosen release path, document which CLI/core
  functions must be exposed through FFI/native modules.

### Linux

- Decide whether Linux package capability detection remains shell-local or moves
  into Core CLI as a structured capability probe.
- If moved into Core CLI, model Flatpak, Snap, deb, rpm, NetworkManager,
  systemd-resolved, polkit present/missing, and diagnostics-only states.
- Keep store/sandbox guidance separate from deb/rpm native-power apply plans.

### Windows

- Add stable message IDs for notes/errors/safety guidance consumed by localized
  Windows UI.
- Optional: expose Windows Settings action metadata in apply-plan if this avoids
  duplicated platform handoff logic.
- Future only: define a Windows Power service/admin apply plan contract without
  adding Store-lane elevation behavior.

## Temporary Adapters To Retire

- macOS adapts `system-benchmark` payloads locally when
  `scope == "system-dns-validation"`.
- Mobile uses a local Node bridge to spawn the Rust CLI; release architecture is
  undecided.
- Linux capability detection is currently implemented in the Linux lane.
- Windows localizes some dynamic free-text because CLI payloads do not yet expose
  stable message IDs.

## Validation Contract

Every Core CLI backlog item should land with targeted Rust tests plus:

```bash
cargo test --workspace --tests
```

If a change affects a platform decoder, run that lane's validation or update the
lane request doc with exact follow-up commands.
