# DNSPilot Product Architecture

Last reviewed: 2026-07-14.

## Product

DNSPilot helps normal users choose a DNS configuration that performs reliably on
their current network, apply it through an OS-honest flow, and verify the result.
Commercial trust depends on measurable recommendations, reversible actions, concise
UX, local-first data, and signed OS-native distribution.

## Architecture

- Rust core and `dnspilot-cli` own benchmark, recommendation, policy, storage, and
  versioned JSON/JSONL contracts.
- OS apps are thin native presentation and capability adapters. They must not fork
  benchmark or recommendation rules.
- Store editions are benchmark-first and guided by default. Direct DNS mutation is a
  separate Power capability requiring explicit consent, rollback, and OS authorization.
- User profiles, suites, settings, and history remain local unless a future product
  decision introduces an account or sync service.
- `main` is the integrated source of truth; OS worktrees are isolated delivery lanes.

## Commercial Sequence

Ship and validate macOS first. While macOS is blocked on external release gates,
Windows, Linux, and mobile catch up to the same store-safe consumer contract. They do
not copy macOS-specific APIs or expand privileged adapters without separate evidence.

## Decisions

### D1: Mobile Native DNS Settings

- **Problem:** iOS native DoH/DoT installation requires the restricted
  NetworkExtension `dns-settings` capability and changes the release architecture.
- **Options:** ship entitlement by default; keep the feature isolated; remove it.
- **Trade-offs:** default inclusion increases differentiation but can block signing and
  review; isolation preserves the experiment without making release depend on approval;
  removal loses validated work.
- **Recommendation:** keep commit `345c41e` isolated on `worktree/mobile` until Apple
  capability approval and signed-device validation exist. Do not merge it into `main`.
- **Reason:** optional differentiation must not block the benchmark-first Store SKU.
- **Confidence:** High.

### D2: Platform Delivery Order

- **Status:** Approved on 2026-07-11; amended by D6 on 2026-07-13.
- **Problem:** parallel feature expansion across four OS lanes dilutes release focus.
- **Options:** continue parity work; pause all but macOS; keep thin validation lanes.
- **Trade-offs:** parity maximizes breadth but delays proof; a full pause creates stale
  ports; thin lanes preserve contracts at controlled cost.
- **Recommendation:** macOS-first commercial release; other lanes continue only
  store-safe product-contract parity and validation until their release gate is opened.
- **Reason:** one trusted, publishable product creates faster commercial learning than
  four partially releasable products.
- **Confidence:** Medium-high pending user research.

### D3: macOS Consumer Information Architecture

- **Problem:** the current sidebar mixes the core user journey with capabilities,
  permissions, publishing checks, catalog internals, and other-platform status.
- **Options:** keep the QA console; hide internal surfaces behind Advanced; remove them
  from the release UI while retaining CLI/docs diagnostics.
- **Trade-offs:** keeping everything aids development but harms comprehension; an
  Advanced area still adds product weight; removing release-only surfaces gives the
  clearest product while preserving evidence outside the consumer UI.
- **Recommendation:** the release UI has three primary areas: `Check DNS`, `Profiles`,
  and `History`; results remain within the Check DNS decision flow. Game targets become
  benchmark presets. Publishing, capability matrix, validation evidence, catalog
  internals, and platform parity stay in CLI/docs or a development-only diagnostics
  surface.
- **Reason:** commercial users buy a trustworthy decision loop, not an implementation
  dashboard.
- **Confidence:** High.

### D4: macOS Window Ownership

- **Problem:** `WindowGroup` and a manually created fallback `NSWindow` can create two
  main windows with independent navigation models.
- **Options:** retain the fallback; use a `WindowGroup`; use one singleton SwiftUI
  `Window` as the sole main-window owner.
- **Trade-offs:** fallback code masks launch defects but creates state races;
  `WindowGroup` restores or creates multiple main scenes for a utility app; a singleton
  `Window` prevents duplicate app surfaces while preserving normal launch behavior.
- **Recommendation:** use one `Window` scene. Menu actions activate it when present
  and open it only when absent.
- **Reason:** DNSPilot is a utility, not a multi-document app. One visible state owner
  avoids duplicate benchmarks and contradictory navigation.
- **Confidence:** High; cold launch and repeated menu `Benchmark`/`Run Quick Test`
  actions each verified one AX window.

### D5: Power DNS Rollback

- **Problem:** Power Apply changes the active macOS network service but currently
  does not retain a service-scoped rollback record. The existing guided-apply
  resolver snapshot is not sufficient to restore an exact network service.
- **Options:** keep manual Network Settings recovery; capture the active service
  and its DNS mode before Power Apply, then offer explicit in-app Restore; add a
  persistent privileged helper/service.
- **Trade-offs:** manual recovery is simple but makes a privileged mutation
  operationally unsafe; service-scoped capture/restore adds bounded local state
  and one more confirmed admin action; a helper adds signing, install, and
  attack-surface cost without improving the v1 rollback contract.
- **Recommendation:** capture a minimal per-service DNS rollback record before
  Power Apply and expose Restore only in the Power edition after explicit
  confirmation. Preserve automatic/DHCP DNS as a distinct restore mode.
- **Reason:** reversibility is required for user trust and Power release QA; it
  can be achieved without a new privileged service architecture.
- **Confidence:** High.

### D6: macOS As Product Reference, Not Platform Template

- **Problem:** independent OS lanes drift into engineering consoles, while exact
  macOS feature parity would copy invalid provider assumptions and privileged APIs.
- **Options:** independent products; exact feature parity; one shared consumer
  contract with capability-specific platform adapters.
- **Trade-offs:** independence accelerates local work but forks the product; exact
  parity is simple to track but unsafe across providers; contract parity needs an
  explicit matrix but preserves one product and honest OS behavior.
- **Recommendation:** macOS is the reference for the store-safe user journey and
  quality bar. Every lane implements `Check DNS`, `Profiles`, and `History`, a
  DNS-only Quick Check, honest DNS+TCP presets, recommendation safety, one primary
  Apply/Retest action, optional tutorial/Help, concise copy, local persistence,
  accessibility, and release evidence. OS-specific mutation remains separate.
- **Reason:** users should recognize one DNSPilot product without hiding real OS,
  store, privilege, or packaging differences.
- **Confidence:** High.

### D7: macOS Localization Ownership

- **Problem:** macOS currently mixes a hand-built EN/VI dictionary, hard-coded
  English presentation strings, bilingual tooltips, and English Core diagnostics.
  The `System` language option also resolves to English instead of the user's macOS
  language.
- **Options:** keep extending the dictionary; use native localized `.strings` resources
  in the current SwiftPM package; migrate to an Xcode-managed String Catalog after an
  Xcode project owns the build pipeline.
- **Trade-offs:** extending the dictionary preserves split ownership; `.strings`
  resources are the supported, deterministic SwiftPM route but need key-completeness
  tests; a String Catalog gives extraction and translator tooling but is not the
  package build's reliable resource runtime today.
- **Recommendation:** use one semantic-key `Localizable.strings` resource family under
  `en.lproj` and `vi.lproj`, with a locale-aware facade. Keep one app-language
  preference (`System`, English, Vietnamese), resolve `System` from macOS, and
  localize non-view strings through the same explicit locale. Shared Core emits
  structured states and raw technical details, never localized prose. macOS renders
  structured benchmark/result/history state through the locale facade and keeps raw
  CLI evidence inside an explicit Technical details disclosure. Do not show two
  languages in one user-facing tooltip.
- **Reason:** one locale produces one coherent UI without a package/runtime mismatch;
  an Xcode String Catalog remains a future tooling migration, not a second source of
  truth today.
- **Confidence:** High.

## Quality Gates

- No release-ready claim without platform build, automated tests, signed artifact
  validation, manual permission flow, rollback test, and user-visible smoke evidence.
- No privileged capability enters a default Store SKU without provider approval and a
  documented fallback.
- Power DNS Apply must retain an exact active-service rollback record before it can
  be released outside test environments.
- Contract changes require compatibility/version review across every consumer lane.
- Reference parity is judged by user outcome and evidence, not identical controls,
  runtime technology, tray behavior, or privileged capability.
