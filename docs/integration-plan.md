# Integration Plan

## Branch and Worktree Model
- main: orchestration and integration.
- worktree/core-cli: shared Rust contracts and CLI.
- worktree/macos: UX lead implementation.
- worktree/mobile: mobile shell and platform feasibility.
- worktree/windows: Windows shell and capability research.
- worktree/linux: Linux shell and distro capability research.
- worktree/docs: aggregation and release docs.

## Merge Strategy
- Small commits per lane.
- Contracts land in core-cli before platform lanes depend on them.
- Platform mocks are allowed only with a matching core-cli request file entry.
- Docs lane periodically reads all platform coordination files and updates shared docs.

## Integration Checks
- Rust: `CARGO_INCREMENTAL=0 cargo test --workspace --tests`.
- macOS: `swift package --package-path apps/macos/DNSPilotMac clean && swift test --package-path apps/macos/DNSPilotMac`.
- Bundle: `./script/build_and_run.sh --verify`.
- Whitespace: `git diff --check`.

