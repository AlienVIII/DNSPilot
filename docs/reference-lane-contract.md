# Reference Lane Contract

Last reviewed: 2026-07-13. Reference implementation: macOS.

## Product Contract

- Primary navigation: `Check DNS`, `Profiles`, `History` only.
- Default action: fast DNS-only Quick Check. DNS+TCP is advanced or selected by a
  tagged game/service preset with an explicit non-ping disclaimer.
- Result: separate Recommended, Fastest observed, and Keep current DNS. Render Core
  safety decisions; never re-rank in an OS shell.
- Next step: exactly one contextual Apply guidance or Retest action. Technical copy,
  raw diagnostics, and checklists stay behind Details/info.
- Setup: value-first and optional, marked complete only by Skip/Done, with a top-right
  Help/Info affordance to reopen it.
- Data: Core-backed profiles, suites, and history remain local; built-ins are read-only.
- Quality: EN/VI, keyboard/touch semantics, assistive labels, visible non-color status,
  cancellation where the runtime supports it, privacy-safe reports, and fail-closed
  runtime compatibility.

## Capability Adaptation

| Lane | Store-safe Apply | Power/native boundary | Required release proof |
| --- | --- | --- | --- |
| macOS | Confirm, copy DNS, open Network Settings, retest | Separate direct build with admin consent and exact service rollback | Signed sandbox bundle, clean-Mac flow, App Review |
| Windows | Confirm, copy DNS, open Windows Settings, retest | Separate future SKU; never Store/UAC mutation | WinUI/MSIX install, helper discovery, accessibility, Partner Center |
| Linux | Copy guidance appropriate to package/desktop, retest when supported | deb/rpm only after caller-bound polkit, D-Bus, exact rollback | Real Flatpak/Snap/deb/rpm plus GNOME/KDE/resolver QA |
| iOS/iPadOS | Guide plain DNS; optional entitled DoH/DoT settings build | Restricted `dns-settings`, explicit user enablement | Signed device, Apple capability approval, App Review |
| Android | Copy DoT hostname, open Private DNS settings, retest | No silent mutation or VpnService in consumer SKU | Signed device, Play policy/settings flow |

## Evidence Rule

A lane is caught up only when its own tests/build/static gates pass and unavailable
provider/device checks are reported `NOT RUN`. A doc, mock, or another OS result is not
release evidence for that lane.
