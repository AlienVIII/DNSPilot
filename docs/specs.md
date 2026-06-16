# DNS Pilot Specs

## Benchmark UX
- Modes: DNS only, DNS + TCP, later DNS + TCP + TLS where supported.
- Direct resolver benchmarks do not need system DNS flush.
- System DNS validation after apply should surface flush guidance before testing.
- Each run must show selected profiles, domains, attempts, record family, and timeout risk.

## Benchmark Progress UX
- Lifecycle steps: preparing, resolving DNS, measuring TCP when enabled, parsing result, saving history.
- Each step has one status: idle, running, success, failed.
- Current step should show two concise verbose lines so the user can tell whether work is active.
- Resolver rows should show per-candidate status and failure rate.

## Failed Log UX
- Failures must include mode, failed step, elapsed time, user-facing reason, suggestion, and debug logs.
- DNS-only failures should identify resolving DNS as the likely failed step when applicable.
- Parse failures must include raw stderr/stdout summary where safe.

## Benchmark Lifecycle
- Validate inputs before process execution.
- Run process with cancellation support.
- Parse JSON result or map process/parse failures into user-facing failure state.
- Save history only after a completed parse.
- Load apply-plan policy only from completed benchmark results.

## Platform Consistency Rules
- Show capability-specific behavior rather than fake parity.
- Store-safe builds guide or use approved APIs; power builds may use privileged helpers later.
- Mobile has no menu bar; use foreground benchmark and settings/profile guidance.
- Linux tray is optional and must not be required.

