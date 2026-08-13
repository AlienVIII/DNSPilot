# Reference Lane Contract

Last reviewed: 2026-08-07. Product reference: macOS Store-safe.

## Product Contract

- Primary navigation: `Health Check`, `DNS Benchmark`, `Profiles`, and `History`.
- Guided order: Health Check first, DNS Benchmark second; both remain independently
  runnable and never share a hidden score.
- Default: bounded DNS-only Quick Check. DNS+TCP is Advanced or a tagged target with a
  visible non-ping disclaimer.
- Result: Core-backed Recommended, Fastest observed, and Keep current DNS stay distinct.
- Action: exactly one contextual setup or Retest action. Raw diagnostics stay in Details.
- Setup: optional, value-first, complete only on Skip/Done, reopenable from top-right Help.
- UI: one title, one status, one primary action; no empty Process/Result before a run.
- Data: Core-backed local profiles, suites, and history; built-ins are read-only.
- Quality: EN/VI, keyboard/touch/assistive semantics, non-color status, cancellation,
  privacy-safe reports, fail-closed compatibility, and explicit `NOT RUN` evidence.
- Background completion: one user-started read-only measurement may continue under OS
  limits. No periodic scheduler, remote push, auto-retry, or background DNS mutation.

## Capability Adaptation

| Lane | Store-safe setup | Restricted/native boundary | Required release proof |
| --- | --- | --- | --- |
| macOS | Confirm, copy DNS, open Settings, retest | Separate non-sandbox Power build; admin consent, exact rollback, current-state guard | Signed Store sandbox bundle, signed Power artifact, EN/VI/VoiceOver, clean Mac, App Review |
| Windows | Confirm, copy DNS, open Settings, retest | Separate future SKU; never Store elevation/mutation | WinUI/MSIX/tray/accessibility, helper discovery, Partner Center |
| Linux | Package/desktop-aware copy guidance and retest | deb/rpm only after caller-bound D-Bus/polkit and exact rollback | Source-built packages, GNOME/KDE/resolver QA, publisher proof |
| iOS/iPadOS | Guided plain DNS; default Store omits entitlement | Optional user-enabled DoH/DoT `dns-settings` artifact | Signed device, capability provisioning/review, App Review |
| Android | Copy DoT hostname, open Private DNS, retest | No silent mutation, device-owner API, or `VpnService` | Signed device, Play policy/settings flow |

## Background And Notification Adaptation

| Lane | Run lifetime | Completion notification | Release proof |
| --- | --- | --- | --- |
| macOS | App-owned process while OS permits | UserNotifications, contextual opt-in | Background completion, deny, Force Quit, deep-link, lock-screen privacy |
| Windows | Non-elevated desktop process | Windows App SDK local app notification; no WNS | Packaged/unpackaged activation, deny/suppress, process exit, no-elevation check |
| Linux | Process plus XDG Background portal where sandbox requires it | XDG Notification portal, best effort | Flatpak plus GNOME/KDE allow/deny/suppress/activation matrix |
| iOS/iPadOS | Continued-processing API only on supported target; bounded fallback | Local UserNotifications | Signed physical-device expiration, force-quit, permission, lock-screen proof |
| Android | Bounded user-initiated native foreground execution only if Play policy fits | Required running disclosure plus separate opt-in completion channel | Signed device, notification denial, process kill, OEM battery policy, Play declaration |

Core/CLI owns progress and terminal result semantics. Each OS shell owns execution
lifetime, a versioned local run receipt, notification permission, delivery, and result
activation. See `docs/superpowers/specs/2026-08-07-background-measurement-notifications-design.md`.

## Evidence Matrix

| Lane | Contract/UI automation | Native visual/accessibility | Package/provider | Status |
| --- | --- | --- | --- | --- |
| macOS | Pass, including source-build contract | Partial; signed EN/VI/VoiceOver open | Local preflight pass; signing/review open | Commercial lead |
| Linux | Pass through M5 | `NOT RUN` on Linux | Local recipes only; source builds open | Catch-up |
| Windows | 65 Core/static pass | `NOT RUN` on Windows | MSIX/signing/Partner Center open | Catch-up |
| Mobile | 99 tests/typecheck/router pass; dependency check red | Simulator proof exists; physical devices open | Current Expo patch alignment and Store preflight open | Blocked from merge |

## Evidence Rule

A lane is caught up only when its tests/build/static gates pass and unavailable
provider/device checks are recorded `NOT RUN`. A doc, mock, simulator, or another OS
result is preparation, never release evidence for that lane.
