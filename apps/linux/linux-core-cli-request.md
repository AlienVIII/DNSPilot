# Linux Core CLI Requests

## Required APIs
- Linux platform capability payloads by packaging type.
- NetworkManager/systemd-resolved detection contract.
- Polkit-capable power apply contract for native packages.
- Current/system resolver validation support flag.
- Linux suite catalog support flag for Vietnam daily defaults.

## Required Contracts
- Flatpak/Snap store-safe builds default to benchmark/guidance.
- deb/rpm power path may use NetworkManager or systemd-resolved with polkit.
- deb/rpm without resolver stack plus polkit must stay diagnostics-only for apply.
- Unsupported benchmark modes must be rejected before run start.
- Linux shell currently maps DNS only to `compare`, DNS + TCP to `path-compare`, and current resolver validation to `system-benchmark`.
- Direct benchmark runs expect progress JSONL on stderr and final payload JSON on stdout.

## Required Logging
- Distro/package capability detection logs must be issue-report friendly.
- Process reports need per-step and per-resolver status details.
- Debug reports need enough package, resolver-stack, and capability notes for later QA.
