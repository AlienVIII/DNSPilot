# DNSPilot Next Prompts

Last reviewed: 2026-07-19.

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

Implement TODO P0/P1 in order with TDD. First harden DNS response integrity: connected
UDP socket, cryptographically suitable unpredictable transaction ID, QR/standard opcode,
exact matching question/class/type and source validation, with spoofed/malformed/wrong-
question tests. Then make profile/suite/history snapshot mutations transaction-safe under
concurrent CLI processes without a schema rewrite. Next add stable issue IDs and version
the progress JSONL terminal/cancellation/history contract. Do not add OS settings URIs,
distro detection, or privileged helpers to Core. Run targeted tests, cargo fmt --check,
cargo clippy --workspace --all-targets -- -D warnings, and cargo test --workspace --tests.
Self-review security/compatibility and commit verified owned files. Stop only at a true
external/manual gate.
```

## macOS: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-macos
Ownership: apps/macos/**; use Core changes only after the Core contract lands.

Add a fail-closed Power Restore current-state guard: persist DNSPilot-applied service/DNS
state and refuse restore if current service/configuration no longer matches. Preserve
automatic/DHCP exact rollback and Store/Power isolation. Then prepare every automatable
EN/VI, narrow-window, Dark Mode, keyboard, VoiceOver, signed-bundle, and five-user test
artifact; leave only actual permission/signing/user gates manual. Run ./script/ci_macos.sh,
./script/preflight_macos_release.sh --include-power, and non-destructive goal-flow smoke.
Commit only owned verified files.
```

## Linux: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-linux
Ownership: apps/linux/**.

Continue Store-safe completion at Milestone 6, then 8-9. Finish EN/VI layout,
keyboard/screen-reader semantics, desktop-fit behavior, source-built Flatpak/Snap/deb/rpm
recipes, Linux CI artifacts, installed smoke, and evidence templates. Keep Power execute
fail-closed; do not reintroduce shell-backed mutation. Use mocks for unavailable package
tools, but mark real GNOME/KDE/resolver/package checks NOT RUN. Run fmt, tests, clippy
-D warnings, Core compatibility, and package/static gates. Commit owned verified files.
```

## Windows: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-windows
Ownership: apps/windows/**.

Do not reopen milestones 0-4. Prepare and, on a Windows host when available, execute the
Release validator, WinUI/MSIX/tray/helper-discovery, EN/VI wrapping, keyboard/Narrator,
high-contrast, VPN/firewall, clean-install, upgrade, relaunch, and Settings-handoff QA.
Store remains asInvoker with no UAC, netsh, service, registry, or DNS mutation. Keep the
core workflow complete without tray/runFullTrust approval. Run
apps/windows/validate-windows-lane.sh and fill release evidence; mark Windows-only checks
NOT RUN elsewhere. Commit owned verified files.
```

## Mobile: GPT-5.6-Terra, high

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-mobile
Ownership: apps/mobile/** and packages/mobile/**; consume Core contracts, do not fork them.

Update Expo 57 patch-compatible packages to current expected versions and restore a green
npm run verify plus npm run preflight:release. Harden the dev bridge: loopback default,
explicit LAN opt-in with per-run token and origin allowlist, fixed app-owned DB path,
redacted health/errors, bounded jobs and cancellation. Define and enforce Android/iOS
backup exclusion/retention for local DNS profiles/domains/history. Simplify consumer UI:
one title/status/action, no empty Process/Result before run, no Core/CLI jargon, advanced
profile editing behind progressive disclosure, tutorial/Help always touch/keyboard/
assistive accessible. Keep Expo web dev/router QA only. Default Store artifact must omit
dns-settings; production-ios-dns remains signed-device/provider blocked. Run tests,
typecheck, Expo install check/Doctor/router export, release preflight, iOS Simulator, and
Android release checks. Commit verified owned files; do not merge to main until all normal
gates pass.
```

## Docs

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-docs
Ownership: docs/** and status/risk/progress Markdown only.

Read current branch heads and actual validation artifacts. Remove stale resolved claims,
keep one current status/evidence/gap/manual-gate structure, update root SoT, and record
NOT RUN honestly. No production code and no inferred release claims.
```
