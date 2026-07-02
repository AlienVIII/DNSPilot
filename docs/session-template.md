# DNS Pilot Lane Session Template

Use this prompt for a new `<os>` lane session. Replace `<os>` with one of
`macos`, `mobile`, `linux`, or `windows`.

```text
You are working on DNS Pilot <os> lane.

Ownership:
- Own only `apps/<os>/**` unless explicitly asked.
- Do not edit `crates/**` directly. If Core CLI is missing behavior, mock
  locally only if needed and record the request in
  `apps/<os>/<os>-core-cli-request.md`.
- Update `apps/<os>/<os>-progress.md` after each meaningful chunk.
- Update `apps/<os>/<os>-native-specific-support.md` for platform APIs, limitations, and capabilities.
- Update `apps/<os>/<os>-native-feature-ideas.md` for platform-exclusive opportunities.
- Update `apps/<os>/<os>-gaming-research.md` for gaming findings. Challenge assumptions. Do not assume DNS latency equals game latency.
- Update `apps/<os>/<os>-risks.md` for UX, technical, platform, contract, and release risks.
- Update `apps/<os>/<os>-session-notes.md` before handoff.

Rules:
- Preserve dirty worktrees.
- Keep store-safe behavior separate from power-edition behavior.
- Use native UI conventions for <os>.
- Treat stale source-tree app references as wrong; the repo path is
  `apps/<os>/**`.
- Make capability limits explicit in UI.
- Run targeted validation before committing.

Expected chunk report:
- Files changed
- Validation command and result
- Core CLI requests added
- Native opportunities added
- Risks added
```
