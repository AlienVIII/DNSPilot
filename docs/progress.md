# Global Progress

Last integration pass: 2026-07-11.

## Current State

- `main` now contains the latest approved mobile contract state, latest committed
  macOS and Linux lane work, plus the reviewed Windows lane contract state. Dirty
  or architecture-gated lane work remains isolated until committed and reviewed.
- The committed Linux packaging/non-blocking benchmark work and macOS Power-action
  hardening are integrated. Mobile native DNS commit `345c41e` remains intentionally
  isolated behind Apple entitlement and signed-device gates.
- Core CLI contracts cover catalog/capabilities, benchmark modes, progress,
  storage, apply-policy/apply-plan, history, custom profiles/suites, and
  system-DNS validation.
- OS provider trust/manual gates are centralized in `docs/os-provider-trust.md`.
- Concise copy, info affordances, and tutorial behavior are centralized in
  `docs/ux-copy-onboarding.md`.
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

- `npm run verify` in `apps/mobile/DNSPilotMobile`: pass after Expo SDK 57
  package alignment; includes 48/48 node tests, TypeScript, Expo config, web
  export, `expo install --check`, and high-severity audit gate.
- `./script/preflight_macos_release.sh --include-power`: pass; validates Rust,
  Swift, Store-safe bundle, Power bundle, and Store-safe restore.
- `./script/ci_macos.sh`: pass; validates Rust, Swift, local sandbox bundle,
  DNS-only live smoke, and DNS+TCP live smoke. Distribution bundle verification
  is skipped unless `DNSPILOT_DISTRIBUTION_BUNDLE` points to a signed export.
- `./script/smoke_macos_goal_flows.sh --include-network`: pass; validates the
  six main macOS goal flows without mutating DNS.
- `swift test --package-path apps/macos/DNSPilotMac`: pass, 253 XCTest tests
  plus 0 Swift Testing tests.
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`: pass.
- `apps/windows/validate-windows-lane.sh`: pass for core/build/static checks,
  packaging/localization/static checks, and expected macOS-only WinUI
  build-probe handling.
- `git diff --check`: pass.

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
- Provider trust: Apple Developer, App Store Connect, Play Console, Microsoft
  Partner Center, Flathub/Snapcraft, and distro package QA remain manual.

## Next Actions

- Keep the five synced lanes based on `main`; preserve dirty Linux/Windows changes.
- Resolve mobile's dirty `package.json` ownership before merging `main` into that lane;
  keep native DNS commit `345c41e` out of `main` until its architecture gates pass.
- Follow the macOS-first commercial sequence in `PROJECT.md` and `TODO.md`.
- Use `docs/platform-summary.md` as the short cross-platform source of truth.
- Keep detailed platform release steps in `apps/<platform>/*publish*` and
  `apps/<platform>/*readiness*` docs instead of repeating them in chat.
- Keep OS provider account/signing/manual trust steps in
  `docs/os-provider-trust.md` and run them in one release pass.
