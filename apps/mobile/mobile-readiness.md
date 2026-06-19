# Mobile Readiness

## Main Goal Checklist
- Benchmark/recommendation UI: covered through CLI bridge jobs, foreground-only
  progress polling, result summary, recommendation JSON, diagnostics, and copy
  report.
- DNS-only, DNS+TCP, and system resolver validation: covered by compare,
  path-compare, benchmark, path-estimate, and system-benchmark modes.
- Per-step/per-resolver process UI: covered by prepare, DNS, TCP, TLS, save,
  resolver rows, elapsed time, failure reason, debug command, and progress
  event count.
- Saved profiles and custom suites: covered by SQLite-backed add/update/delete,
  local form validation, custom tag preservation, catalog merge, and history.
- Guided DNS settings/profile flow: covered by core apply-plan payloads,
  iOS/iPadOS profile/settings guidance, Android settings/Private DNS guidance,
  and protected-network suppression.
- Tablet layouts: covered by shared adaptive layout helpers and two-column
  flows on wide screens.
- IPv4/IPv6 and A/AAAA controls: covered by benchmark IP-family controls and
  help text.
- Vietnam/default suites: covered when the core catalog exposes
  `general-browsing` and `vietnam-daily`.

## Critique
- Expo plus local Node bridge is the fastest store-safe test shell, but it is
  not a release architecture. Expo Go cannot spawn or link Rust CLI inside the
  app process.
- The current app is honest about mobile OS limits. It does not silently mutate
  system DNS, does not use Android VpnService, and does not offer iOS
  DNSJumper-style plain DNS switching.
- The bridge contract is useful for validating UX and core payloads, but native
  release work must replace it with a direct Rust binding or approved native
  adapter.
- Guided settings is intentionally conservative. It may feel less powerful than
  desktop DNS switching, but that is the correct consumer mobile policy stance.
- Live progress is implemented as foreground polling. This avoids background
  scheduler risk, but long worst-case benchmarks still need the app to stay
  open.

## Remaining Blockers
- iOS/iPadOS: Simulator/device validation is blocked until the user accepts the
  system "Open in Expo Go?" prompt and manually verifies OS settings/profile
  flows.
- Android: emulator/device validation is blocked until an Android target is
  attached.
- Both: release builds require a native Rust/platform adapter decision,
  packaging, signing/provisioning, and store-policy review.

## Manual Test Flow
1. Run `npm run bridge` from `apps/mobile/DNSPilotMobile`.
2. Run `npm start` or `npx expo start --ios --port 8082`.
3. Use `http://localhost:8787` on web/iOS Simulator. Use the Mac LAN URL for a
   physical phone. Use `http://10.0.2.2:8787` for Android emulator if needed.
4. Overview: refresh bridge, confirm profiles, suites, capabilities, and
   history load.
5. Benchmark: choose Default or Vietnam suite, select profiles, run DNS Compare
   and Path Compare, confirm live progress rows, final result, copy report, and
   guided settings plan.
6. Benchmark System DNS: choose iOS or Android, run with a suite/domain, confirm
   system validation result and diagnostics.
7. Storage: add/update/delete plain, DoH, DoT profiles and domain suites; confirm
   invalid forms are disabled before bridge calls.
8. Policy: toggle VPN/MDM/corporate DNS/captive portal and confirm guidance
   switches to protect-current-dns when required.

## Validation Commands
- `npm test`
- `npm run typecheck`
- `npx expo export --platform web`
- `git diff --check`
