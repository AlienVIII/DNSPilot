# DNSPilot Next Prompts

Last reviewed: 2026-08-07.

Read `AGENTS.md`, `PROJECT.md`, `STATE.md`, `TODO.md`, and
`docs/reference-lane-contract.md` first. Preserve dirty worktrees. Reuse Core contracts,
use TDD for behavior, run the full owned-lane gate, and commit only owned verified files.
Continue every safe independent item; stop only when all remaining work is a true
credential, signing, store, physical-device, real-OS, or admin gate.

## Next Overall Review: GPT-5.6-Sol, xhigh

```text
Worktree: /Users/aart/Projects/Desktop/DNSPilot
Mode: Principal Product Architect. Do not modify production code.

Refresh remote metadata and inspect main plus every worktree. Review deltas, validation,
UI/UX, provider policy, security/privacy, Core/CLI ownership, package/release readiness,
and stale docs. Challenge claims with file/test evidence and official primary sources.
Review D13 Health Check separation and D14 background measurement/local notification
against privacy, Store policy, permission timing, interruption, and real-device evidence.
Findings first: Critical/Major/Minor/Suggestion. For material decisions record Problem,
Options, Trade-offs, one Recommendation, Reason, Confidence. Update PROJECT.md for
architecture, TODO.md for roadmap, STATE.md/docs/apps/<os> Markdown for current truth.
Merge only clean, reviewed, validated lane commits into main; never merge a red lane or
rewrite shared history. Then sync every worktree from main, rerun affected gates, commit
owned docs, and report concise progress, NOT RUN checks, manual gates, and next Terra
queue. No push or external release action without explicit approval.
```

## Core CLI: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-core-cli
Ownership: crates/** and shared Core contract docs only.

Implement the approved D13 Health Check contract with TDD: separate versioned
observations, measured/inferred/unsupported evidence, confidence, capability gaps,
stable reason IDs, privacy-safe manual recheck guidance, progress lifecycle, and
synthetic fixtures. Preserve DNS Benchmark as independent, including A/AAAA separation
and the 500 ms attempt ceiling. Reuse existing run ID, terminal/cancel, transaction-safe
history, and no-partial-history invariants. D14 does not require a Core daemon,
scheduler, retry, notification, deep-link, Settings URI, or OS permission API. Continue
remaining typed recommendation/history IDs only after the P0 contract is green. Run
targeted tests, cargo fmt --check, cargo clippy --workspace --all-targets -- -D warnings,
and cargo test --workspace --tests. Self-review compatibility/security and commit only
verified owned files.
```

## macOS: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-macos
Ownership: apps/macos/**; use Core changes only after the Core contract lands.

Implement D14 as the reference lane with TDD. One user-started read-only Health Check or
DNS Benchmark may continue while the window is inactive; persist a versioned local run
receipt; reuse Core run ID/terminal/cancel semantics; mark stale nonterminal work
interrupted; never auto-retry. Offer `Notify me when done` contextually after run start,
use local UserNotifications only, suppress while active, use generic lock-screen copy,
and deep-link to the exact result. No login item, helper, remote push, or background DNS
Apply/Restore. Add mocked allow/deny/termination/deep-link tests, then run real local
background smoke where automatable. Preserve the verified source-build path and Store/
Power isolation. Run ./script/ci_macos.sh and ./script/preflight_macos_release.sh
--include-power; commit only owned verified files. Leave Apple signing, physical user
permission, VoiceOver, and Store submission as consolidated manual gates.
```

## Linux: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-linux
Ownership: apps/linux/**.

After the D13 Core contract lands, implement the separate Health Check UI and D14 shell
adaptation. Keep one user-started read-only measurement alive; persist a local receipt;
use XDG Background/Notification portals for sandboxed packages where needed; treat
delivery as best effort; never add autostart, daemon, remote push, auto-retry, or
background mutation. Add mocked portal allow/deny/suppress/activation/interruption tests.
Then finish EN/VI layout, keyboard/screen-reader semantics, source-built packages, CI,
and evidence templates. Real Flatpak GNOME/KDE portal/package checks are NOT RUN off
Linux. Keep Power fail-closed. Run fmt, tests, clippy -D warnings, Core compatibility,
and package/static gates; commit only owned verified files.
```

## Windows: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-windows
Ownership: apps/windows/**.

After the D13 Core contract lands, implement separate Health Check and D14 in the
non-elevated shell. Keep one user-started read-only measurement alive, persist a local
receipt, use Windows App SDK AppNotificationManager for local completion/activation,
and suppress alerts while active. No WNS/Azure, service, auto-retry, or background DNS
mutation. Add mocked permission/suppression/process-exit/deep-link tests. Preserve
asInvoker and a complete no-tray path. Run apps/windows/validate-windows-lane.sh; prepare
WinUI/MSIX/EN-VI/Narrator/high-contrast/clean-install evidence and mark Windows-only
runtime checks NOT RUN elsewhere. Commit only owned verified files.
```

## Mobile: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-mobile
Ownership: apps/mobile/** and packages/mobile/**; consume Core contracts, do not fork them.

First restore green dependency alignment: Expo currently expects `expo` and
`expo-router` 57.0.11 plus `expo-symbols` 57.0.2. Run complete `npm run verify` and
`npm run preflight:release`; do not merge a partial or red candidate. Then perform D14
feasibility spikes, not assumed parity: supported iOS user-initiated continued processing
with bounded expiration, and an Android bounded native foreground path with a valid
service type/Play-policy fit and no auto-restart. If either proof fails, keep that OS
foreground-only. Completion notification is local and contextually opt-in; Android's
required running disclosure is separate. No remote push, periodic work, silent retry,
background DNS mutation, or force-quit promise. Add mocks, then physical-device gates.
Keep Expo web dev-only and default iOS Store entitlements unchanged. Commit verified
owned files only after all normal gates pass.
```

## Docs

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-docs
Ownership: docs/** and status/risk/progress Markdown only.

Read current branch heads and actual validation artifacts. Remove stale resolved claims,
keep one current status/evidence/gap/manual-gate structure, update root SoT, and record
NOT RUN honestly. No production code and no inferred release claims.
```
