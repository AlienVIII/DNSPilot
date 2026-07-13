# DNSPilot Engineer Prompts

Last reviewed: 2026-07-13.

Use these only for explicitly assigned Engineer Mode tasks. The coordinator remains
Architect Mode. Read `AGENTS.md`, `PROJECT.md`, `STATE.md`, `TODO.md`, and
`docs/reference-lane-contract.md` first.

## Shared Rules

- Work in the named lane only. Preserve dirty files and do not pull/merge while another
  task owns that worktree.
- Reuse Core/CLI contracts. Record missing shared contracts in the lane request doc and
  `docs/core-cli-backlog.md`; do not fork product rules locally.
- Use TDD for behavior changes, validate the full lane, self-review, and commit only
  owned verified files.
- Store builds are benchmark/guidance first. Power/provider-restricted capability is a
  separate SKU with consent, rollback, and real-provider proof.
- Continue across unblocked scope. Stop only for credentials, signing, store submission,
  real-device/provider QA, or unavoidable OS/admin consent.
- Final report: commits, requirement coverage, commands/evidence, `NOT RUN` checks, and
  one consolidated manual-gate list.

## Core CLI

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-core-cli
Branch: worktree/core-cli
Ownership: crates/** and shared Core docs only.

Priority:
1. Add structured locale-neutral issue/message IDs before any shell parses English.
2. Document and test one progress JSONL schema plus cancellation/history semantics.
3. Consider runtime-info --json only after at least Linux and Windows confirm the same
   version/readiness contract.
4. Keep OS settings URIs, package detection, and privileged helpers lane-local unless
   two consumers need the same policy contract.

Validation: targeted Rust tests, then cargo test --workspace --tests.
```

## macOS

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-macos
Branch: macos
Ownership: apps/macos/**; crates/** only for an approved shared contract.

State: automated Store-safe scope is frozen and locally complete. Do not refactor or
add features without a reproduced defect or failed release gate. Preserve singleton
Window, Check DNS / Profiles / History, one primary result action, Store/Power split,
and exact Power rollback.

Validation: ./script/ci_macos.sh and
./script/preflight_macos_release.sh --include-power.
```

## Linux

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-linux
Branch: worktree/linux
Ownership: apps/linux/**.

Execute apps/linux/linux-completion-plan.md in order: 0-6, 8-9. Milestone 7 stays
experimental and fail-closed until real Linux evidence. Port the reference user
journey, not macOS APIs. First remove/default-disable unsafe command-based mutation;
then typed Core storage/results, streaming/cancellation, consumer IA, apply/retest,
accessibility, and honest source/package automation.

Validation: fmt, tests, clippy, Core CLI compatibility, package/static scripts; mark
real Flatpak/Snap/deb/rpm, GNOME/KDE, polkit, and resolver tests NOT RUN when absent.
```

## Windows

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-windows
Branch: worktree/windows
Ownership: apps/windows/**.

Execute apps/windows/windows-predevelopment-review.md milestones 0-4. Finish any dirty
Runtime Readiness slice first. Then consumer IA/accessibility, DNS-only Quick Check,
gaming DNS+TCP caveat, bounded cancellation/no partial history, safe result/apply/retest,
versioned preferences, and privacy-safe diagnostics. Store remains asInvoker; never
add UAC, netsh, registry/service, or DNS mutation.

Validation: apps/windows/validate-windows-lane.sh. Prepare but do not claim Milestone 5
until WinUI/MSIX/tray/accessibility tests run on Windows.
```

## Mobile

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-mobile
Branch: worktree/mobile
Ownership: apps/mobile/** and packages/mobile/**.

Finish Check DNS / Profiles / History consumer navigation, value-first Help/tutorial,
one safe result action, and a verification gate that fails unresolved Expo Router
routes. Release builds use the local Rust-backed Expo module; Node bridge is dev
fallback. Keep foreground jobs and Core payload compatibility. Default iOS Store must
exclude dns-settings; entitled DoH/DoT remains opt-in and requires signed-device proof.
Android consumer uses settings guidance, never silent mutation or VpnService.

Validation: npm run verify, Rust adapter tests, production Expo config/manifests,
available iOS Simulator and Android release builds. Physical devices/signing are manual.
```

## Docs

```text
Worktree: /Users/aart/Projects/Desktop/dnspilot-docs
Branch: worktree/docs
Ownership: docs/** and status Markdown only.

Read branch heads and validation artifacts. Update main truth, remove stale claims, and
keep OS details in apps/<os> docs. No production code. No proof/no claim.
```
