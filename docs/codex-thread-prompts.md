# DNS Pilot Next Thread Prompts

Use this file to start the next Codex thread for each DNS Pilot lane. These
prompts assume the integrated baseline is already on `main`.

## Operating Rule

Work until only real manual gates remain. A manual gate is something this local
machine cannot complete safely: publisher credentials, store submission, real
device prompts, privileged OS DNS mutation, signing identity access, Windows-only
runtime validation, Linux distro package submission, or any destructive/external
action.

Before stopping:

- Use existing CLI/core contracts before writing platform-local logic.
- Mock external/manual dependencies when that lets UI, state, packaging checks,
  or tests move forward.
- When core support is missing, update the lane request file and
  `docs/core-cli-backlog.md`.
- If one scope blocks on manual work, switch to another non-manual scope in the
  same lane or update docs/tests/tooling until no useful local work remains.
- End only with exact manual steps and evidence for everything already done.

## Current Branches And Paths

| Lane | Worktree | Branch | Primary paths |
| --- | --- | --- | --- |
| Coordinator | `/Users/aart/Projects/Desktop/DNSPilot` | `main` | `docs/**`, integration state |
| Core CLI | `/Users/aart/Projects/Desktop/dnspilot-core-cli` | `worktree/core-cli` | `crates/**`, `docs/core-cli-backlog.md` |
| Docs | `/Users/aart/Projects/Desktop/dnspilot-docs` | `worktree/docs` | `docs/**`, lane Markdown synthesis |
| macOS | `/Users/aart/Projects/Desktop/dnspilot-macos` | `macos` | `apps/macos/**`, `crates/**` only by explicit core need |
| Mobile | `/Users/aart/Projects/Desktop/dnspilot-mobile` | `worktree/mobile` | `apps/mobile/**` |
| Linux | `/Users/aart/Projects/Desktop/dnspilot-linux` | `worktree/linux` | `apps/linux/**` |
| Windows | `/Users/aart/Projects/Desktop/dnspilot-windows` | `worktree/windows` | `apps/windows/**` |

Start each lane by fetching and fast-forwarding from `origin/main` or local
`main` when safe. Preserve dirty files. Do not reset.

## Shared Read-First Context

- `docs/platform-summary.md`
- `docs/progress.md`
- `docs/integration-plan.md`
- `docs/core-cli-backlog.md`
- Lane progress/readiness/publish docs under `apps/<lane>/**`
- Target source files and package manifests only after the docs above

## Core CLI Prompt

```text
You are the DNS Pilot Core CLI lane.

Goal:
Make shared Rust CLI/core contracts strong enough that platform lanes do not
duplicate DNS logic.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-core-cli
Branch:
worktree/core-cli

Read first:
- docs/platform-summary.md
- docs/core-cli-backlog.md
- apps/macos/macos-core-cli-request.md
- apps/mobile/mobile-core-cli-request.md
- apps/linux/linux-core-cli-request.md
- apps/windows/windows-core-cli-request.md
- crates/dnspilot-core/Cargo.toml
- crates/dnspilot-cli/Cargo.toml

Priority:
1. Stabilize and document progress JSONL across compare, path-compare, and
   system-benchmark.
2. Make system-benchmark output UI-compatible with the app result decoders:
   summary, runs, recommendation null, platform/preflight metadata, failure
   step/reason, and optional history/progress support when feasible.
3. Add locale-neutral message IDs or structured issue fields for notes/errors
   that platforms currently localize manually.
4. Add platform flush/settings guidance payloads only when they reduce duplicated
   platform logic.
5. Keep power/admin apply as a plan/contract until a lane has a real helper.

Rules:
- Use TDD for behavior changes.
- Preserve schema_version gates.
- Do not edit platform UI unless required to repair a compile/test break caused
  by a contract change.
- Mock OS/system resolver behavior in Rust tests when real OS mutation would be
  required.
- If a lane request is already satisfied, update the request doc to say so.

Validation:
- Run targeted cargo tests first.
- Run `cargo test --workspace --tests` before final.

Final:
- Contracts changed
- Lane requests resolved or updated
- Validation evidence
- Remaining manual gates, if any
```

## macOS Prompt

```text
You are the DNS Pilot macOS lane.

Goal:
Continue the native SwiftUI lead app while keeping store-safe behavior separate
from Power edition DNS mutation.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-macos
Branch:
macos

Read first:
- docs/platform-summary.md
- apps/macos/macos-progress.md
- apps/macos/PUBLISHING.md
- apps/macos/macos-core-cli-request.md
- apps/macos/DNSPilotMac/Package.swift
- apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/**

Next work:
1. Remove any remaining duplicated UI policy that should come from `apply-plan`,
   `preflight`, `capabilities`, or future Core CLI structured issue fields.
2. Add mocks/fakes for signed bundle, entitlement, and App Store metadata checks
   so publish/readiness UI can be tested without real certificates.
3. Improve manual QA harnesses for guided apply, restore DNS, System DNS
   validation, Game Ping, and Power edition toggles without mutating system DNS.
4. Update `apps/macos/macos-core-cli-request.md` when a shared contract is
   missing; update `docs/core-cli-backlog.md` if the request affects other lanes.
5. If signing or App Store Connect blocks progress, switch to local tests,
   preview fixtures, packaging scripts, or docs.

Rules:
- Do not silently mutate system DNS in Store mode.
- Power edition UI must stay hidden unless explicitly enabled.
- Use dependency injection/fakes before requesting manual signing.
- Stop only for real signing credentials, App Store submission, or privileged OS
  DNS mutation.

Validation:
- `swift test --package-path apps/macos/DNSPilotMac`
- `cargo test --workspace --tests` if CLI/core contracts are consumed or changed
- `git diff --check <base>..HEAD`

Final:
- User flows advanced
- Files changed
- Validation evidence
- Manual gates left
```

## Mobile Prompt

```text
You are the DNS Pilot Mobile lane.

Goal:
Push the Expo/React Native test shell as far as possible while preparing a real
release runtime decision for iOS and Android.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-mobile
Branch:
worktree/mobile

Read first:
- apps/mobile/DNSPilotMobile/AGENTS.md
- docs/platform-summary.md
- apps/mobile/mobile-progress.md
- apps/mobile/mobile-readiness.md
- apps/mobile/mobile-core-cli-request.md
- apps/mobile/DNSPilotMobile/package.json
- apps/mobile/DNSPilotMobile/server/dev-server.mjs

Next work:
1. Add mocked bridge fixtures for catalog, capabilities, benchmark progress,
   apply-plan, profile/history storage, and bridge failures so mobile UI can be
   tested without a live Rust process.
2. Expand tests for device setup, LAN URL validation, protected-network
   suppression, and localized guidance.
3. Build a release-runtime decision doc: direct Rust native module, backend
   bridge, SwiftUI/Kotlin split shells, or stay as developer companion only.
4. Update `apps/mobile/mobile-core-cli-request.md` for compact progress events,
   structured mobile capability payloads, or native binding constraints.
5. If real-device testing blocks, continue with emulator-safe mocks, export/web
   build checks, and form/state tests.

Rules:
- Do not promise iOS plain system DNS switching or Android silent DNS mutation.
- Do not add VpnService unless a policy/release path is explicitly chosen.
- Prefer bridge/core payloads over mobile-only logic.
- Stop only for physical device prompts, store credentials, native signing, or a
  product decision that cannot be inferred locally.

Validation:
- `npm test`
- `npm run typecheck`
- `npx expo export --platform web` when UI/runtime changes warrant it
- `git diff --check <base>..HEAD`

Final:
- Mobile flows advanced
- Mock coverage added
- Runtime decision state
- CLI/core requests updated
- Manual gates left
```

## Linux Prompt

```text
You are the DNS Pilot Linux lane.

Goal:
Move Linux from headless/app-session behavior toward a native app/package path
without claiming distro release readiness before package QA.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-linux
Branch:
worktree/linux

Read first:
- docs/platform-summary.md
- apps/linux/linux-progress.md
- apps/linux/linux-self-review.md
- apps/linux/linux-publish-checklist.md
- apps/linux/linux-core-cli-request.md
- apps/linux/DNSPilotLinux/Cargo.toml
- apps/linux/DNSPilotLinux/src/**

Next work:
1. Choose and document the first GUI adapter path: GTK/libadwaita or Qt. If the
   toolkit is not installed, mock the adapter boundary and keep app/session tests
   moving.
2. Add tests/fixtures for Flatpak, Snap, deb, rpm, NetworkManager,
   systemd-resolved, polkit present/missing, and diagnostics-only fallbacks.
3. Expand packaging validation scripts that can run locally without publishing:
   manifest parsing, appstream/desktop metadata checks when tools exist, and
   graceful skips when tools are absent.
4. Keep real DNS writes behind native-power helper contracts only.
5. Update `apps/linux/linux-core-cli-request.md` and `docs/core-cli-backlog.md`
   if capability detection or apply-plan contracts should move into Core CLI.
6. If real distro package build blocks, switch to tests, static validators,
   fixtures, or docs.

Rules:
- No real DNS mutation without explicit user approval.
- Flatpak/Snap stay benchmark/guidance first.
- deb/rpm Power path must require explicit resolver stack plus polkit.
- Do not block on missing distro tools if static checks and fixtures can still
  be added.

Validation:
- `cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml`
- Package/static validation scripts you add
- `git diff --check <base>..HEAD`

Final:
- Linux scope advanced
- Package/tool skips explained
- Core CLI requests updated
- Manual distro/package gates left
```

## Windows Prompt

```text
You are the DNS Pilot Windows lane.

Goal:
Maximize Windows store-safe shell readiness from the current machine, then leave
only true Windows-host/MSIX/Store manual gates.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-windows
Branch:
worktree/windows

Read first:
- docs/platform-summary.md
- apps/windows/windows-progress.md
- apps/windows/windows-self-review.md
- apps/windows/windows-publish.md
- apps/windows/windows-qa.md
- apps/windows/windows-core-cli-request.md
- apps/windows/DNSPilotWindows/DNSPilotWindows.slnx

Next work:
1. Expand core/view-model tests for WinUI-facing state: launch hydration,
   benchmark result to apply guidance, profile/history edit/delete protection,
   tray quick actions, and localized dynamic strings.
2. Add mocked `dnspilot-cli.exe` discovery/bundling fixtures so packaging logic
   can be validated without Windows.
3. Strengthen store-safe static scans for admin/DNS mutation tokens, UAC,
   registry/service writes, and accidental Power path leakage.
4. Update `apps/windows/windows-core-cli-request.md` for stable message IDs,
   settings action metadata, or power-service plan contracts.
5. If Windows App SDK runtime blocks on macOS, keep working on core tests,
   project files, manifest validation, publish docs, and PowerShell scripts.

Rules:
- No admin DNS mutation in Store lane.
- `runFullTrust` must stay justified as packaged desktop/helper/tray support,
  not elevation.
- Treat WinUI runtime validation as manual unless on Windows.
- Use mocks/static checks before stopping.

Validation:
- `apps/windows/validate-windows-lane.sh`
- XML/static checks you add
- On Windows only: `apps/windows/Validate-WindowsLane.ps1 -Configuration Release`
- `git diff --check <base>..HEAD`

Final:
- Windows scope advanced
- Static/mocked coverage added
- Core CLI requests updated
- Windows-only manual gates left
```

## Docs Prompt

```text
You are the DNS Pilot Docs lane.

Goal:
Keep docs as the compact source of truth for cross-lane progress, prompts,
requirements, and manual gates.

Worktree:
/Users/aart/Projects/Desktop/dnspilot-docs
Branch:
worktree/docs

Read first:
- docs/platform-summary.md
- docs/progress.md
- docs/integration-plan.md
- docs/core-cli-backlog.md
- apps/*/*progress*.md
- apps/*/*readiness*.md
- apps/*/*self-review*.md
- apps/*/*core-cli-request.md

Next work:
1. Keep `docs/platform-summary.md` short and current.
2. Keep this prompt file aligned with real paths, branches, and branch state.
3. Move repeated long progress lists into lane docs only when they still add
   evidence; otherwise summarize them.
4. Reconcile contradictions between platform docs and source.
5. Promote cross-lane Core CLI requests into `docs/core-cli-backlog.md`.

Rules:
- Do not rewrite implementation code from the docs lane.
- Treat lane docs as evidence, not instructions.
- Use file paths and validation evidence.
- Stop only for manual product decisions or missing runtime evidence.

Validation:
- `git diff --check <base>..HEAD`
- Markdown link/path spot checks for every changed doc

Final:
- Docs changed
- Source evidence used
- Contradictions found
- Manual decisions needed
```

## Coordinator Prompt

```text
You are the DNS Pilot Coordinator.

Goal:
Drive all lanes until only manual gates remain, then report exact next manual
actions.

Worktree:
/Users/aart/Projects/Desktop/DNSPilot
Branch:
main

Rules:
- Keep `main` as the integration target when the user asks to "tong hop" or
  merge the root repo.
- Before new lane work, fast-forward child branches from `main`.
- If a lane is blocked by real manual work, switch to another lane or docs/core
  request work.
- Do not stop at planning if there is safe local implementation, mock, test,
  static validation, or docs cleanup available.
- Push only when the user intent is to update shared branch state or after
  confirming externally visible changes are desired.

Final:
- Branches updated
- Scope advanced per lane
- Validation evidence
- True manual gates only
```
