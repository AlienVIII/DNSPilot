# DNSPilot Next Prompts

Last reviewed: 2026-08-24.

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
Treat the Guided Connection Check decision loop as the leading product-value hypothesis;
challenge any work that adds resolver breadth or platform parity before proving it.
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

First restore `cargo clippy --workspace --all-targets -- -D warnings` on Rust 1.96.
Use `is_multiple_of(2)` for the flagged median helpers and replace the private
nine-argument `apply_plan` helper with one coherent typed input/options value unless a
narrower reviewed design is cleaner. Do not lower or broadly allow the lint gate.

Then implement the approved D13 Health Check contract with TDD: separate versioned
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

Repair and finish the existing D14/source-install branch before new scope. Persist an
actual result reference, consume notification `runID` to open that exact local result,
clear the delivered alert after view, reconcile the toggle with current OS authorization,
and expose/log scheduling failure without promising delivery. Add tests for old-result
activation after a newer run. Make the per-user installer restore the previous app on any
post-move validation failure. Fix `visual_macos_smoke.sh` and UI/accessibility copy so the
real packaged EN/VI run passes; remove stale evidence claims. Preserve contextual opt-in,
generic lock-screen copy, foreground suppression, Store/Power isolation, no push/login
item/retry/background DNS mutation. Run `./script/ci_macos.sh`,
`./script/preflight_macos_release.sh --include-power`, and real visual smoke. After Core
D13 lands, implement Guided Connection Check as the reference journey: one outcome,
state/risk, action, then Details. Commit only owned verified files; leave Apple signing,
real notification/VoiceOver, admin Power QA, and Store submission as batched manual gates.
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

First restore green dependency alignment using the exact SDK 57 patch set reported by
`npx expo install --check` (2026-08-24 reported `expo`/router 57.0.15 and related patch
updates). Review lockfile/native patch compatibility, run `npm run verify` and
`npm run preflight:release` serially, and distinguish a reproducible dependency mismatch
from transient Expo service JSON failures. Do not merge a partial or red candidate.
After those gates are green, apply the reviewed mobile information hierarchy without
changing measurement semantics: make `Run quick check` the immediate default; result
starts with one plain-language outcome and one safe action or Retest; targets, process
stages, timings, resolver rows, and diagnostic labels move behind explicit Details/Info.
Keep the existing accessible top-right tutorial replay control, but compress first-run
tutorial to three short titles with optional progressive detail. Add/adjust behavioral
tests and rerun emulator QA for first run, replay, quick-check completion, Details, and
EN/VI before any D14 work.
Then perform D14
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
