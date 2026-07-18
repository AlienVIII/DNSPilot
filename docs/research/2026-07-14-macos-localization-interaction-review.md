# macOS Localization And Interaction Review

Date: 2026-07-14

Audience: macOS Tech Lead

Scope: planning and acceptance criteria only; no production implementation in this pass.

## Implementation Status (2026-07-14)

Implemented after this review:

- `System`, English, and Vietnamese language selection with an explicit `globe EN/VI`
  toolbar menu and immediate app-wide rendering.
- One active-language tooltip path; CI rejects `EN:`/`VI:` source blocks across macOS
  presentation and Core sources.
- Store-safe Settings omit Power-only controls; Power builds retain their separate
  presentation.
- Full-row Benchmark Options control with native button, keyboard, and VoiceOver
  semantics.
- Bundle launch validation now includes localized resources; the packaged app keeps
  `DNSPilotMac_DNSPilotMacCore.bundle` in `Contents/Resources`.

Implementation uses `en.lproj`/`vi.lproj` `Localizable.strings`, not an `.xcstrings`
catalog. This is deliberate: DNS Pilot is built by SwiftPM, where the `.strings`
resource bundle is deterministic in both tests and the packaged app. Move to an Xcode
String Catalog only when Xcode owns the build/resource pipeline. The remaining work is
the manual visual/accessibility matrix and native Vietnamese review.

Latest automated evidence (2026-07-18): CI, Store-safe/Power preflight, goal smoke,
localized resource validation, and packaged one-window launch pass. Per-window image
capture on the current host fails before an image is created, and the Accessibility API
does not expose the app window. This is a workstation privacy permission limitation, not
passing visual proof; run the matrix on a signed build with Screen Recording and
Accessibility available.

## BLUF

The screenshot is a release-quality defect, not a translation polish issue. DNS Pilot
currently renders one screen from several text sources: a partial custom EN/VI
dictionary, hard-coded English Swift strings, bilingual `EN:/VI:` help text, and
English Core diagnostics. The `System` language choice is also hard-coded to English.

Adopt one Apple String Catalog and one locale store. Show one language at a time. Keep
raw technical diagnostics available in issue reports, but localize their user-facing
summary from stable IDs. Fix interaction semantics at the same boundary so every
visible option/disclosure row is clickable and keyboard/VoiceOver reachable.

## Findings

### Major: Split Localization Ownership

- `DNSPilotLocalization.swift` stores a hand-written dictionary covering only selected
  labels.
- Production Swift still contains many direct `Text`, `Label`, `Button`, `.help`,
  dialog, status, and error literals outside that dictionary.
- `BenchmarkPlanViewModel`, `BenchmarkSetupViewModel`, and benchmark option views embed
  both English and Vietnamese in a single tooltip.
- `DNSPilotLanguage.system` follows the English branch instead of inspecting the
  user's preferred macOS language.
- Core result/caveat/failure strings reach visible UI as English prose. Translating
  arbitrary prose in the shell would create a brittle parser contract.

Impact: Vietnamese mode is visibly incomplete, System mode is incorrect, support copy
is hard to maintain, and every new language multiplies drift.

### Major: Store/Power Settings Leak

The Store-safe Settings window displays an English `Power Actions` section and
direct-install explanation even when the capability is unavailable. This is not an
actionable preference for Store users and contradicts the focused consumer IA.

Required behavior:

- Store-safe Settings: language and genuine Store preferences only.
- Power build: a separately labelled, localized `Advanced` section with direct-admin
  opt-in and risk copy.
- Never market unavailable Power behavior inside the Store-safe preference flow.

### Major: Small Or Ambiguous Action Targets

Options and disclosure affordances visually occupy a row but can behave like a tiny
chevron/icon target. Icon-only menus also depend on precise pointer placement.

Required behavior:

- The full visible label/header bounds perform the disclosed action.
- Keep native focus rings, pressed/hover state, keyboard activation, and VoiceOver
  traits.
- Add padding/content shape to standalone icon controls; do not turn dense result
  tables into touch-first cards.
- Tooltips explain unfamiliar symbols; they must not be the only way to discover a
  primary action.

### Major: Result Hierarchy Is Too Technical

The result screen leads with mixed-language status/table content and exposes many
technical columns before the user has a clear decision. Settings adds implementation
copy rather than user choices.

Required hierarchy:

1. Outcome: `Keep current DNS` or recommended profile, confidence, and one primary
   Apply/Retest action.
2. Short reason in the selected language.
3. Top comparison or compact candidate summary.
4. Full candidate table, raw diagnostics, saved run ID, and copy actions under
   `Technical details`.

Provider names and protocol terms such as DNS, TCP, A/AAAA, IPv4/IPv6, and P95 stay
unchanged. Surrounding grammar, statuses, actions, and explanations are localized.

### Minor: Language Control Semantics

A binary `[EN]` button is ambiguous: it can mean the current language or the language
that will be selected after clicking, and it does not scale to a third language.

Use a toolbar `Menu` with a globe icon and the current value:

- `globe  System`
- `globe  EN`
- `globe  VI`

The menu contains `Follow System`, `English`, and `Tiếng Việt`, with a checkmark on the
active choice. Settings uses the same preference. Changing it updates all open DNS
Pilot windows immediately. `System` follows macOS instead of forcing English.

## Recommended Architecture

### One Source Of Truth

Use one semantic-key resource family at
`apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/Resources/{en,vi}.lproj/Localizable.strings`,
set the package default localization to English, process the resource in the
`DNSPilotMacCore` target, and access it through a package-aware bundle facade. Keep a small
catalog-backed facade so view models and SwiftUI surfaces use the same explicit locale
and resource bundle. Migrate the current `DNSPilotLocalizer` API incrementally, then
remove the static dictionaries; do not run both systems permanently.

Use the native resource family for:

- English and Vietnamese values.
- interpolation and plural variants.
- translator comments for short terms such as `Run`, `Apply`, `Resolver`, and
  `Failure`.
- stable semantic keys rather than English sentences as business identifiers.

Do not mutate `AppleLanguages` or require an app restart. One app-level language store
owns `System/en/vi`, injects the selected locale into SwiftUI, and supplies the same
locale when formatting non-view strings.

### Separate State From Copy

- Swift/macOS view models should expose semantic state for status, confidence, action,
  and diagnostic category instead of prebuilt English sentences.
- Rust Core/CLI should emit locale-neutral message IDs plus raw details. Add this before
  trying to translate every English Core caveat.
- User-facing UI maps IDs to the String Catalog.
- `Copy Issue Report` retains stable IDs and raw English/technical detail so support can
  diagnose the run regardless of app language.

### Vietnamese Product Glossary

Prefer user language over internal engineering terms:

| English | Vietnamese UI |
| --- | --- |
| Check DNS | Kiểm tra DNS |
| Profiles | Cấu hình DNS |
| Keep current DNS | Giữ DNS hiện tại |
| Degraded | Kém ổn định |
| Failed | Thất bại |
| Options | Tùy chọn nâng cao |
| Details | Chi tiết kỹ thuật |
| Run | Kiểm tra |
| Resolver | Máy chủ DNS |

Do not translate provider/product names or established protocol acronyms.

## Implementation Order

1. Add catalog resources and a catalog-backed locale store; fix real System-language
   resolution. Preserve the existing preference key through migration.
2. Move shell, commands, menu bar, Settings, dialogs, errors, tooltips, accessibility
   labels, and notification copy to the catalog.
3. Replace bilingual help with one selected-language value. Keep concise help behind
   the info/hover surface.
4. Introduce semantic diagnostic/message IDs and localize visible benchmark/result
   states. Preserve raw logs in issue reports.
5. Hide Power settings in Store-safe builds; localize and move them to Advanced in
   Power builds.
6. Fix full-row action targets for Options, Details, candidate selection, and icon
   menus. Audit hover, pressed, focus, keyboard, and VoiceOver behavior.
7. Simplify result hierarchy and reduce default technical density without removing
   copyable diagnostics.
8. Add automated localization/visual gates, then run the moderated usability pass.

For disclosure rows, prefer a semantic full-width `Button` header bound to the
expanded state when native `DisclosureGroup` hit behavior does not cover the visible
label. Use a rectangular content shape and plain native styling while preserving focus
and accessibility traits. Do not solve the issue with `onTapGesture` on a decorative
stack because that loses button semantics and keyboard behavior.

## Automated Quality Gates

Add these before declaring Milestone 3A complete:

- Catalog completeness: every supported locale has a value and interpolation
  placeholders match.
- Static localization lint: reject new user-facing `EN:`/`VI:` blocks and maintain a
  narrow allowlist for intentional raw technical strings.
- Unit tests: System-language resolution, immediate runtime switching, status/action
  localization, pluralization, and Store/Power visibility.
- Interaction tests: clicking anywhere in each visible option/disclosure label toggles
  it; Space/Return works; icon menus have an accessibility label.
- Visual matrix: EN and VI across default Check DNS, running, degraded result, failed
  result, Profiles, History, Settings, and guided Apply.
- Run the matrix at the 900x620 minimum and a wide window, in Light and Dark Mode.
  Fail for clipping, overlap, mixed-language visible copy, missing focus, or truncated
  primary actions.

For self-capture, prefer deterministic debug-only fixture states and an XCUITest/window
capture path. A developer capture script may supplement this, but Screen Recording or
Accessibility permission is a manual workstation gate and must not be required by the
normal unit-test CI lane.

## Non-Code Release Work

- Have a native Vietnamese reviewer edit the catalog and approve the glossary in
  context; machine translation alone is not release evidence.
- Add Vietnamese App Store Connect name/subtitle/description/keywords/release notes
  where available. Keep capability claims identical to the English metadata.
- Publish equivalent English and Vietnamese support/privacy pages. The privacy meaning,
  Store-safe apply behavior, and Power separation must not diverge by locale.
- Capture clean EN and VI screenshot sets after the visual matrix passes. Do not mix
  locales within one storefront set.
- Run the five-user flow with at least Vietnamese and English macOS accounts, including
  `Follow System`, toolbar language switching, Settings, failure, and guided Apply.

## Acceptance Criteria

- Vietnamese selection produces no visible English sentence except provider names,
  protocol terms, user data, and explicitly opened raw debug content.
- English selection produces no Vietnamese copy.
- System selection follows macOS preferred language and has a tested unsupported-locale
  fallback.
- No user-facing tooltip contains both `EN:` and `VI:`.
- The toolbar language menu shows the current choice, never an ambiguous next choice.
- Store-safe Settings contains no Power/direct-install controls or marketing copy.
- Every visible option/disclosure label is a coherent action target and works by
  pointer, keyboard, and VoiceOver.
- The primary result decision and action remain visible before technical details.
- The EN/VI visual matrix passes before five-user testing or App Store screenshots.

## External References

- Apple String Catalogs:
  https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Apple localization guidance, including per-app macOS language behavior:
  https://developer.apple.com/localization/
- Apple SwiftUI localization preparation:
  https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- Apple localized Swift Package resources and `Bundle.module`:
  https://developer.apple.com/documentation/xcode/localizing-package-resources
- Apple Human Interface Guidelines:
  https://developer.apple.com/design/human-interface-guidelines/
- DNS Easy Switcher: useful workflow benchmark for menu-bar switching, speed tests,
  custom DNS, flush, and IPv4/IPv6; do not copy its outside-Store privilege model:
  https://github.com/glinford/dns-easy-switcher
- OnlySwitch: evidence that a native macOS utility can scale translations through a
  centralized `Localizable.xcstrings` catalog:
  https://github.com/jacklandrin/OnlySwitch/tree/main/Localization
