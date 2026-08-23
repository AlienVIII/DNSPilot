# Platform Summary

Last integration review: 2026-08-24.

## Integration State

| Lane | Reviewed head | `main` state | Current gate |
| --- | --- | --- | --- |
| Core CLI | `2c3ec20` | Integrated | Tests/fmt pass; Rust 1.96 clippy red |
| macOS | `78239d8` | Held outside `main` | CI/preflight pass; exact-result and real visual QA red |
| Linux | `2c3ec20` | Integrated | Tests/clippy pass; real Linux package/UI proof open |
| Windows | `2c3ec20` | Integrated | 65 Core/static pass; WinUI runtime needs Windows |
| Mobile | `2c3ec20` | Integrated | 106 tests/typecheck pass; Expo compatibility/preflight red |
| Docs | This pass | Integration source of truth | Sync clean lanes after review commit |

`main` remains the only cross-lane source of truth. A lane is integrated only after
review, owned validation, merge, and merged-result validation. A green unit suite does
not override a red lint, compatibility, runtime, visual, or provider gate.

## Product Priority

The leading value hypothesis is Guided Connection Check: diagnose, explain, recommend
one safe next action, and Retest. DNS Benchmark remains independent and is used after
connection health is sufficient for DNS selection. Do not expand resolver breadth or
background parity before Core D13 and the macOS reference journey are proven.

## Current Proof

- macOS branch: CI and Store/Power preflight pass with 282 Swift tests and shared Rust
  tests. Real visual smoke exits 6; signing, notification delivery/activation,
  VoiceOver, Power mutation, and App Review proof remain open.
- Linux: lane tests and clippy `-D warnings` pass on macOS. Native package, desktop,
  portal, accessibility, and publisher proof remain `NOT RUN` off Linux.
- Windows: 65 Core/static tests and the Core solution build pass. WinUI/XAML/MSIX,
  Narrator, high contrast, tray, install/upgrade, and Partner Center proof require Windows.
- Mobile: 106 tests and TypeScript pass. Expo SDK 57 patch compatibility and release
  preflight are red; signed physical-device and store proof remain open.
- Core: workspace tests and formatting pass. Rust 1.96 clippy reports four findings.

## Non-Negotiable Boundaries

- Default Store SKUs never silently mutate DNS.
- Health Check and DNS Benchmark never share a hidden score or claim DNS fixes Wi-Fi,
  bandwidth, router, ISP, VPN, or game latency.
- Restricted/admin capability is separately packaged, consented, reversible, and proven
  on generated/signed artifacts and the real OS.
- Android consumer uses Private DNS Settings guidance, not `VpnService` or device-owner
  control. Windows Store remains non-elevated. Linux Power remains fail-closed.
- Expo web is development/router QA, not a commercial surface.
- No proof/no claim: unavailable checks are `NOT RUN`, not inferred from mocks.
