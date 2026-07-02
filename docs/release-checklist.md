# Release Checklist

## Product
- Benchmark modes are clear and scoped.
- Failure states show step, reason, elapsed time, and logs.
- Apply guidance is store-safe and does not imply silent DNS mutation.
- Protected network safeguards are visible.
- Fastest observed DNS is not presented as the same thing as the balanced/safe
  recommendation.
- Platform capability limits are visible instead of hidden behind parity claims.

## Engineering
- Rust workspace tests pass.
- macOS Swift tests pass.
- macOS non-mutating goal smoke passes:
  `./script/smoke_macos_goal_flows.sh`.
- Optional macOS live goal smoke passes on a normal network:
  `./script/smoke_macos_goal_flows.sh --include-network`.
- Linux lane tests pass.
- Mobile unit tests and TypeScript typecheck pass.
- Windows lane core/build/static validation passes on macOS; Windows App SDK
  runtime validation still requires a Windows host.
- Local macOS bundle verification passes: `./script/validate_macos_bundle.sh`.
- macOS local CI harness passes: `./script/ci_macos.sh`.
- Distribution bundle verification passes:
  `./script/validate_macos_bundle.sh dist/DNSPilotMac.app --distribution`.
- No debug-only entitlements in release signing.
- App Store copy avoids unsupported claims.
- `git diff --check <release-base>..HEAD` is clean.
- Dependency audit is reviewed. Current known issue: Expo tooling pulls
  vulnerable `uuid <11.1.1`; forced npm fix is breaking and needs a deliberate
  dependency upgrade path.

## Platform
- Capability matrix reviewed per OS.
- Store policy risks documented.
- Power-edition features excluded from store builds.
- Mobile real-device bridge/native-adapter behavior validated before mobile
  release claims.
- Linux Flatpak/Snap/deb/rpm package builds and permissions validated before
  Linux release claims.
- Windows MSIX, tray behavior, and Partner Center restricted capability
  justification validated before Windows release claims.

## Docs
- Platform coordination files updated.
- Core CLI backlog current.
- Release notes include limitations.
- `docs/platform-summary.md` reflects current lane status and hard gates.
