# Global Progress

Last integration pass: 2026-07-02.

## Current State

- `main` now contains the latest active mobile, macOS, Linux, and Windows lane
  work.
- Core CLI contracts cover catalog/capabilities, benchmark modes, progress,
  storage, apply-policy/apply-plan, history, custom profiles/suites, and
  system-DNS validation.
- macOS is the UX lead lane and now includes privacy manifest, support/privacy
  copy, release preflight, bundle validation, and non-mutating goal smoke
  scripts.
- Mobile is a store-safe Expo bridge shell for UX and policy validation, not the
  final public-store runtime architecture. It includes System Access recovery,
  native settings actions, Expo SDK 57, Android debug build evidence, and
  recorded iOS Simulator build/install/launch smoke evidence.
- Linux is code-complete for native app/session logic with an egui desktop
  launcher, helper contract/dry-run protocol, packaging policy templates, and
  package readiness commands; it still needs real package QA.
- Windows is code-complete for store-safe core/view-model behavior that can be
  validated on macOS and now includes Store manifest/assets, publish profile,
  packaging script, privacy/listing/support docs; it still needs real Windows
  App SDK/MSIX/tray QA.

## Validated In This Integration

- `cargo test --workspace --tests`: pass.
- `swift test --package-path apps/macos/DNSPilotMac`: pass.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `npm ci` in `apps/mobile/DNSPilotMobile`: pass; `patch-package` applies
  `expo-modules-jsi@57.0.0`.
- `npm run verify` in `apps/mobile/DNSPilotMobile`: pass for test,
  typecheck, public Expo config, web export, Expo install check, and high-severity
  audit gate.
- `apps/windows/validate-windows-lane.sh`: pass for core/build/static checks,
  packaging/localization/static checks, and expected macOS-only WinUI
  build-probe handling.
- `git diff --check`: pass for current working tree docs.
- `git diff --check origin/main..HEAD -- ':(exclude)apps/mobile/DNSPilotMobile/patches/*.patch'`:
  pass. Raw full-range check intentionally reports required unified-diff context
  spaces inside the patch-package file.

## Open Gates

- Mobile: native adapter/backend decision, real-device QA, store signing.
- macOS: signing/provisioning, App Store entitlement review, distribution
  validation.
- Linux: real Flatpak/Snap/deb/rpm package builds, distro QA, and release
  decision for default-disabled native helper execution.
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
