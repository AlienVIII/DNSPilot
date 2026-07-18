# DNS Pilot Screenshot Plan

Capture from a signed Store-safe release candidate at native macOS resolution.
Do not include Power/admin actions, terminal windows, DNS addresses from a
private network, or unrelated applications.

The Store-safe bundle includes `AppIcon.icns`; verify the icon appears in Finder
and the Dock before capture.

| File | Surface | Required state |
| --- | --- | --- |
| `01-check-dns.png` | Check DNS | Default target and Run action visible |
| `02-benchmark-running.png` | Check DNS | Progress rows show active resolver work |
| `03-result.png` | Result | Recommendation, one apply action, and Details disclosure visible |
| `04-game-target.png` | Check DNS | Dota 2 SEA target selected with DNS + TCP disclaimer |
| `05-profiles.png` | Profiles | Saved plain DNS profile list and editor |
| `06-guided-apply.png` | Confirmation | Store-safe copy/open Settings confirmation, no admin action |
| `07-setup.png` | Help | Guided setup sheet |
| `08-settings.png` | Settings | Language picker; no Power controls in Store-safe build |

Before final App Store capture, run the wider internal visual matrix from
`docs/research/2026-07-14-macos-localization-interaction-review.md`. Capture every
state in English and Vietnamese at the minimum supported window size and in Dark Mode;
the App Store set may use one locale, but it must not contain mixed-language copy.

Verify every screenshot against the current Store-safe binary immediately before
upload. The App Store review notes must use the same screen names and flow.
