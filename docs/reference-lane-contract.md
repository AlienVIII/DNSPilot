# Reference Lane Contract

Last reviewed: 2026-07-19. Product reference: macOS Store-safe.

## Product Contract

- Primary navigation: `Check DNS`, `Profiles`, `History` only.
- Default: bounded DNS-only Quick Check. DNS+TCP is Advanced or a tagged target with a
  visible non-ping disclaimer.
- Result: Core-backed Recommended, Fastest observed, and Keep current DNS stay distinct.
- Action: exactly one contextual setup or Retest action. Raw diagnostics stay in Details.
- Setup: optional, value-first, complete only on Skip/Done, reopenable from top-right Help.
- UI: one title, one status, one primary action; no empty Process/Result before a run.
- Data: Core-backed local profiles, suites, and history; built-ins are read-only.
- Quality: EN/VI, keyboard/touch/assistive semantics, non-color status, cancellation,
  privacy-safe reports, fail-closed compatibility, and explicit `NOT RUN` evidence.

## Capability Adaptation

| Lane | Store-safe setup | Restricted/native boundary | Required release proof |
| --- | --- | --- | --- |
| macOS | Confirm, copy DNS, open Settings, retest | Separate Power build; admin consent, exact rollback, current-state guard | Signed sandbox bundle, EN/VI/VoiceOver, clean Mac, App Review |
| Windows | Confirm, copy DNS, open Settings, retest | Separate future SKU; never Store elevation/mutation | WinUI/MSIX/tray/accessibility, helper discovery, Partner Center |
| Linux | Package/desktop-aware copy guidance and retest | deb/rpm only after caller-bound D-Bus/polkit and exact rollback | Source-built packages, GNOME/KDE/resolver QA, publisher proof |
| iOS/iPadOS | Guided plain DNS; default Store omits entitlement | Optional user-enabled DoH/DoT `dns-settings` artifact | Signed device, capability provisioning/review, App Review |
| Android | Copy DoT hostname, open Private DNS, retest | No silent mutation, device-owner API, or `VpnService` | Signed device, Play policy/settings flow |

## Evidence Matrix

| Lane | Contract/UI automation | Native visual/accessibility | Package/provider | Status |
| --- | --- | --- | --- | --- |
| macOS | Pass | Partial; signed EN/VI/VoiceOver open | Local preflight pass; signing/review open | Commercial lead |
| Linux | Pass through M5 | `NOT RUN` on Linux | Local recipes only; source builds open | Catch-up |
| Windows | 65 Core/static pass | `NOT RUN` on Windows | MSIX/signing/Partner Center open | Catch-up |
| Mobile | Partial; current verify red | Simulator proof exists; physical devices open | Store preflight not reached in latest run | Isolated |

## Evidence Rule

A lane is caught up only when its tests/build/static gates pass and unavailable
provider/device checks are recorded `NOT RUN`. A doc, mock, simulator, or another OS
result is preparation, never release evidence for that lane.
