# UX Copy And Onboarding Contract

Last reviewed: 2026-07-19.

## BLUF

DNSPilot is a consumer decision tool, not an engineering dashboard. Show one title, one
status, one primary action. Reveal explanation only when it helps the current decision.

## Primary-Surface Rules

- One screen/card title, ideally under six words; never repeat the navigation title.
- One supporting sentence, ideally under 90 characters.
- Do not render Process, Result, error, or diagnostics sections before relevant state
  exists. Use a purposeful ready state, not empty technical panels.
- Never show Core/CLI/schema/storage/bridge terms in consumer copy.
- Keep exactly one primary action. Secondary actions must not visually compete.
- Localize from semantic IDs. Raw messages appear only in opened/copied diagnostics.
- Show one language at a time; language choice must state the current locale.
- Status is never color-only and every icon-only control has an accessible name.

## Details And Help

- Put policy, caveats, permission rationale, and diagnostics behind Info/Details/Help.
- Hover tooltip is desktop enhancement only. The same content must be reachable by click,
  keyboard, touch, VoiceOver, Narrator, TalkBack, or screen reader.
- Keep a top-right `?`/Help action on `Check DNS`, `Profiles`, and `History`.
- Avoid info icons on every row. Use them only where the decision changes or a term is
  genuinely unfamiliar.

## First-Run Tutorial

- Optional, three steps maximum, shown only after persisted preferences load.
- Complete only through Skip or Done; never reopen automatically after completion.
- Ask for OS permission only at the feature that needs it, not during passive onboarding.
- Shared mental model: Check DNS -> set up in OS Settings -> Retest System DNS.
- Restricted Power/provider capability is not first-run content; explain it where offered.

Recommended titles:

1. `Check your DNS`
2. `Set it up safely`
3. `Retest the result`

## OS Patterns

| OS | Short status/detail | Tutorial reopen |
| --- | --- | --- |
| macOS | SwiftUI status + `.help`/sheet | Toolbar `questionmark.circle` |
| iOS/iPadOS | Card status + tappable info sheet | Header `?` |
| Android | Card status + tappable info sheet | Header `?` |
| Windows | Fluent status + ToolTip/ContentDialog | Top-right Help |
| Linux | egui status + hover/focus Help window | Top-right `?` |

## Copy Examples

Use:

```text
Ready to check
Compare DNS choices on this network.
```

Do not use:

```text
Core-owned provider and suite contracts. Custom storage entries are merged by the CLI.
```

Use `Open Private DNS` or `Open Network Settings`; put OS policy and provider limitations
behind Info. Never expose a raw `Failed to fetch` as first-run guidance.

## Research Sources

- Apple onboarding: <https://developer.apple.com/design/human-interface-guidelines/onboarding>
- Apple privacy and just-in-time permission: <https://developer.apple.com/design/human-interface-guidelines/privacy>
- Microsoft Fluent onboarding: <https://fluent2.microsoft.design/onboarding/>
- GNOME tooltips: <https://developer.gnome.org/hig/patterns/feedback/tooltips.html>
