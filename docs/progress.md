# Global Progress

Last integration pass: 2026-06-26.

## Current State

- `main` now contains the active mobile, macOS, Linux, and Windows lane work.
- Core CLI contracts cover catalog/capabilities, benchmark modes, progress,
  storage, apply-policy/apply-plan, history, custom profiles/suites, and
  system-DNS validation.
- macOS is the UX lead lane and is closest to release-shape behavior.
- Mobile is a store-safe Expo bridge shell for UX and policy validation, not the
  final public-store runtime architecture.
- Linux is code-complete for a headless/app-session lane plus packaging policy
  templates, but it still lacks a native GUI and real package QA.
- Windows is code-complete for store-safe core/view-model behavior that can be
  validated on macOS, but it still needs real Windows App SDK/MSIX/tray QA.

## Validated In This Integration

- `cargo test --workspace --tests`: pass.
- `swift test --package-path apps/macos/DNSPilotMac`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `npm test` in `apps/mobile/DNSPilotMobile`: pass.
- `npm run typecheck` in `apps/mobile/DNSPilotMobile`: pass.
- `apps/windows/validate-windows-lane.sh`: pass for core/build/static checks;
  WinUI probe fails on macOS as expected because the Windows App SDK XAML
  compiler is Windows-only.
- `git diff --check 36827f4..main`: found and should now stay clean after docs
  cleanup.

## Open Gates

- Mobile: native adapter/backend decision, real-device QA, store signing.
- macOS: signing/provisioning, App Store entitlement review, distribution
  validation.
- Linux: GUI adapter, package builds, distro QA, optional native helper
  implementation.
- Windows: Windows-host validation, MSIX/tray behavior, Partner Center
  capability justification.
- Security/release hygiene: `npm audit --omit=dev --audit-level=moderate`
  currently reports an Expo tooling dependency on vulnerable `uuid <11.1.1`;
  npm's suggested force fix is breaking and should be handled as a dependency
  upgrade decision, not an automatic patch.

## Next Actions

- Keep child branches fast-forwarded from `main` before new lane work.
- Use `docs/platform-summary.md` as the short cross-platform source of truth.
- Keep detailed platform release steps in `apps/<platform>/*publish*` and
  `apps/<platform>/*readiness*` docs instead of repeating them in chat.
