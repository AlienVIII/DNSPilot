# macOS Product and UX Review

Date: 2026-07-11.

## Positioning

DNSPilot should not compete as another resolver list or one-provider toggle. Its useful
position is: **a trustworthy recommendation for this Mac on this network, with a safe,
reversible apply and retest loop**.

GRC emphasizes deep resolver benchmarking, while Cloudflare WARP emphasizes a simple
provider-specific on/off experience. DNSPilot's differentiation is balanced local
measurement, explicit confidence, keep-current safety, and provider-neutral guidance.

Market references:

- GRC DNS Benchmark exposes deep resolver measurement and uncached-query analysis:
  <https://www.grc.com/dns/operation.htm>.
- Cloudflare WARP favors a provider-specific menu-bar toggle and DNS/WARP modes:
  <https://developers.cloudflare.com/warp-client/get-started/macos/>.

## Evidence

- Runtime command: `./script/build_and_run.sh --verify`.
- Result: build, ad-hoc sandbox signing, launch, bundle validation, privacy manifest,
  app/helper signatures, and sandbox entitlements passed for local review.
- Distribution signing and notarization were not tested; the artifact is ad-hoc signed.
- Runtime review showed separate main windows with different navigation/detail state.
- Source review: `DNSPilotMacApp.swift` is 4,533 lines and owns scenes, window fallback,
  onboarding, every feature view, commands, and platform actions.

## Findings

### Major: Duplicate Main-Window Ownership

`DNSPilotMacApp.swift:13` declares the primary `WindowGroup`, while
`DNSPilotMacApp.swift:617` can create a second `NSWindow` with a new
`DNSPilotNavigationModel`. Runtime review observed inconsistent sidebar/detail state.
The release must have one scene owner and one navigation state per window.

### Major: Internal QA Console in Consumer Navigation

`DNSPilotMacApp.swift:672` exposes Capabilities, Permissions, Publish, Catalog, and six
platform rows beside the primary workflow. Publish checks and cross-platform parity are
developer concerns. Keep the release sidebar to Check DNS, Results, and Profiles.

### Major: Permission-First Onboarding

`DNSPilotMacApp.swift:732` redirects first launch to Permissions and marks onboarding
seen before completion. The sheet explains Power builds before the user receives value
and offers Network Settings without a recommendation. First use should run a safe check;
permission/apply explanation belongs at the action that needs it.

### Major: Monolithic Presentation Source

`DNSPilotMacApp.swift` contains 4,533 lines and more than 30 view types. Windowing,
onboarding, benchmark, profiles, results, publishing, and platform glue cannot evolve
independently. Extract by feature in behavior-preserving steps; do not rewrite core view
models or contracts.

### Minor: Weak Desktop Command Surface

The app has only default dialog shortcuts and no scene-level command menu for primary
actions. Add discoverable menu and keyboard paths while retaining visible buttons.

### Minor: Result Action Overload

The result/apply surfaces expose multiple copy actions, checklists, Network Settings,
Power Apply, and full-plan copy at the same level. Keep one contextual primary action;
move technical exports and restore details behind disclosure or an overflow menu.

### Minor: Menu Bar Scope

The menu bar contains Benchmark, Quick Test, Apply, Copy, Flush, Validate, History,
Settings, and Quit. Limit it to Open, Quick Check, last recommendation/status, Results,
and Quit. Never show Apply/Flush until a valid plan exists and the SKU supports it.

## Apple Guidance Applied

- Apple recommends onboarding that is fast, optional, interactive, and contextual:
  <https://developer.apple.com/design/human-interface-guidelines/onboarding>.
- Apple describes sidebars as peer product areas and recommends familiar symbols and
  standard show/hide behavior:
  <https://developer.apple.com/design/human-interface-guidelines/sidebars>.
- Apple macOS design guidance favors fewer nested levels, resizable windows, menus, and
  keyboard workflows:
  <https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/>.
- `NEDNSSettingsManager` still requires users to enable saved DNS settings in System
  Settings; it is not silent apply:
  <https://developer.apple.com/documentation/networkextension/nednssettingsmanager>.
- Developer ID distribution requires correct signing, hardened runtime, secure
  timestamp, and notarization; Mac App Store distribution follows its own review path:
  <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>.

## Security and Release Review

- Keep Store and Power SKUs separate. Ship Store first; treat Power as a later beta.
- Do not add NetworkExtension to the Store SKU without approved product need and Apple
  capability review.
- Keep direct DNS actions opt-in, IP-validated, administrator-approved, and reversible.
- Add a verified restore/rollback path before commercial Power release.
- Keep telemetry local during moderated studies. Any network analytics requires a
  separate privacy/product decision and updated disclosures.

## Recommended Outcome

The first commercial release should feel like a focused utility, not a control panel:
open app, run one check, understand one recommendation, apply safely, and verify.
