# DNS Pilot Introduction

## Goals
- Build a store-safe DNS benchmark and recommendation product first.
- Keep shared benchmark, scoring, provider catalog, policy, and logging behavior in Core CLI.
- Use macOS as the leading UI/UX lane, then reuse patterns on mobile, Windows, and Linux.
- Support plain DNS guidance now; reserve privileged DNS switching for later power editions.

## Lane Ownership
- main: orchestration, worktree setup, shared coordination.
- core-cli: `crates/dnspilot-core/**`, `crates/dnspilot-cli/**`.
- macos: `apps/macos/**`; UX lead lane.
- mobile: `apps/mobile/**`.
- windows: `apps/windows/**`.
- linux: `apps/linux/**`.
- docs: `docs/**` plus aggregation from platform coordination files.

## Workflow Rules
- Preserve dirty worktrees; do not revert unrelated work.
- Keep cross-lane contracts explicit before using them in UI.
- If Core CLI functionality is missing, mock only inside platform lane and document the request.
- Store-safe builds must not silently change system DNS.
- Gaming research must challenge assumptions; DNS latency is not game latency.

## Commit Convention
Use:

```text
[lane] [chunk][order] message
```

Examples:
- `[main] [docs-init][01] setup multi-worktree coordination`
- `[macos] [progress-ui][01] benchmark running state`
- `[core-cli] [contract][01] define benchmark event schema`

