# UX Copy And Onboarding Contract

Last reviewed: 2026-07-14.

## BLUF

DNSPilot UI should read like a normal user app, not an engineering report. Show
one title, one status, one primary action. Move explanation to info affordances.

## UI Rules

- Primary text: 1 short title, ideally under 6 words.
- Supporting text: max 1 sentence, ideally under 90 characters.
- Details: put behind `info.circle`, tooltip/help tag, modal, popover, or
  copyable diagnostics.
- First-run tutorial: 3-5 steps max, shown once per app install/profile when
  persistence exists.
- Reopen tutorial: always expose a top-right `?` or `info` icon.
- Permission copy: say what will happen now, not platform policy history.
- Manual gate copy: say "Requires Apple Developer account" or equivalent, then
  link to the release/manual checklist.
- Avoid long inline paragraphs in normal flows. Long text belongs in docs,
  diagnostics, release notes, or expandable help.
- Show one selected language at a time. Never put `EN:` and `VI:` in the same
  user-facing tooltip or detail row.
- Localize user-facing status and guidance from semantic IDs. Keep raw technical
  messages available only in an explicitly opened/copied issue report.
- Language selectors show the current locale and use a menu when more than two
  choices exist; do not use an ambiguous next-language toggle.

## Recommended Patterns By OS

| OS | Inline pattern | Detail pattern | Tutorial reopen |
| --- | --- | --- | --- |
| macOS | SwiftUI title + `Label` status | `.help`, sheet, copy report | Toolbar `questionmark.circle` |
| iOS/iPadOS | Card title + status pill | Info row/modal, not hover-only | Header/top-right `?` |
| Android | Card title + status pill | Tappable info row, not hover-only | Header/top-right `?` |
| Windows | Fluent header + command buttons | `ToolTipService.ToolTip`, `ContentDialog` | Top-right Help button |
| Linux | egui section title + status | `on_hover_text`, Help window | Top-right `?` button |

## First Tutorial Content

Use the same mental model on every OS:

1. Test DNS speed.
2. Copy/open OS settings.
3. Retest System DNS.
4. Power/admin mode is separate.
5. Provider trust/signing is handled at release time.

## Current Copy Direction

Replace long paragraphs like:

```text
DNSPilot checks Local Network access for bridge testing. iOS DNS apply and DNS cache flush are OS-controlled...
```

with:

```text
Bridge needs Local Network. DNS changes stay in OS Settings.
```

Put the longer explanation behind info:

```text
DNSPilot never silently changes mobile DNS. It copies values, opens Settings,
and retests the resolver after the user changes OS settings.
```

## Research Sources

- Apple HIG offering help:
  https://developer.apple.com/design/human-interface-guidelines/offering-help
- Microsoft Fluent onboarding:
  https://fluent2.microsoft.design/onboarding
- Material Design 3 tooltips:
  https://m3.material.io/components/tooltips
- GNOME HIG:
  https://developer.gnome.org/hig/
