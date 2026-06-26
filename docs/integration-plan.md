# Integration Plan

## Branch and Worktree Model
- `main`: integrated source of truth after lane merges.
- `worktree/core-cli`: shared Rust contracts and CLI.
- `macos`: UX lead implementation.
- `worktree/mobile`: mobile shell and platform feasibility.
- `worktree/windows`: Windows shell and capability research.
- `worktree/linux`: Linux shell and distro capability research.
- `worktree/docs`: aggregation and release docs when a separate docs lane is needed.

## Merge Strategy
- Small commits per lane.
- Contracts land in core-cli before platform lanes depend on them.
- Platform mocks are allowed only with a matching core-cli request file entry.
- Docs lane periodically reads all platform coordination files and updates shared docs.
- After an integration pass, fast-forward child branches from `main` so later
  work starts from the same contract/docs baseline.
- If the user says "merge/tong hop thu muc goc", prefer local `main` as the
  integration target unless they explicitly ask for a review branch or PR.

## Integration Checks
- Rust: `cargo test --workspace --tests`.
- macOS: `swift test --package-path apps/macos/DNSPilotMac`.
- Linux: `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`.
- Mobile: `npm test` and `npm run typecheck` from `apps/mobile/DNSPilotMobile`.
- Windows lane from macOS: `apps/windows/validate-windows-lane.sh`.
- Whitespace: `git diff --check <base>..HEAD`.
- Release-only macOS bundle: `./script/ci_macos.sh` and signed distribution
  validation when signing assets exist.
