# DNSPilot Product Architecture

Last reviewed: 2026-07-19.

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

- **Status:** Amended on 2026-07-19 after default-artifact entitlement isolation was
  automated.
- **Problem:** iOS native DoH/DoT installation requires the restricted
  NetworkExtension `dns-settings` capability, but isolating every later mobile commit
  also prevents safe consumer work from reaching `main`.
- **Options:** keep the whole branch isolated; remove native DNS source; integrate the
  source while gating the signed release artifact and entitled build profile.
- **Trade-offs:** branch isolation protects the Store SKU but creates permanent drift;
  removal discards useful work; artifact gating keeps one codebase but requires a
  deterministic preflight that proves the default Store artifact has no entitlement.
- **Recommendation:** integrate mobile after its normal validation passes. The default
  Store profile must omit `dns-settings`; `production-ios-dns` remains unreleasable
  until Apple provisioning/review and signed-device evidence exist.
- **Reason:** provider capability risk belongs at the signed artifact boundary, not in
  Git history. Safe mobile UX should not remain permanently forked.
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

- **Problem:** Restore must not overwrite a DNS change made after DNSPilot Apply.
- **Options:** accept a 24-hour snapshot; rely on another warning; compare current DNS
  with the DNSPilot-applied state before restoring.
- **Trade-offs:** age-only restore is unsafe; warnings shift safety to the user; state
  comparison adds snapshot data but prevents stale overwrites without a helper.
- **Recommendation:** implemented in `e4d3ec6`. Snapshots record the applied DNS mode
  and servers; legacy snapshots are cleared/hidden; restore validates active service and
  exact current DNS before presenting the privileged mutation.
- **Reason:** rollback reverses only DNSPilot's change, not a later user, VPN, MDM, or
  network-service change.
- **Confidence:** High. `swift test --package-path apps/macos/DNSPilotMac` passes 274
  tests, including current-state, legacy-snapshot, store, and UI visibility regressions.

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

### D8: DNS Benchmark Response Integrity

- **Status:** Implemented and regression-tested on 2026-07-19 in `8a53a31`.

- **Problem:** Core currently accepts UDP datagrams without binding the socket to the
  requested resolver and uses predictable transaction IDs. The parser does not require
  a response flag or matching question before a run is counted as successful.
- **Options:** document DNS as untrusted; add partial checks; harden the request/response
  boundary before recommendations consume measurements.
- **Trade-offs:** documentation does not protect recommendation integrity; partial
  checks leave spoofing and malformed-response ambiguity; full validation adds focused
  Core work but benefits every platform.
- **Recommendation:** connect the UDP socket to the selected resolver, generate a fresh
  unpredictable transaction ID per query, and validate QR, opcode, one matching
  question, class/type, and response source before recording success.
- **Reason:** the commercial product promise depends on trustworthy measurements.
- **Confidence:** High.

### D9: Shared Storage Mutation Model

- **Status:** Implemented and regression-tested on 2026-07-19 in `8a53a31`.

- **Problem:** every CLI mutation loads one JSON snapshot, changes it, then replaces the
  row. Concurrent benchmark/profile/history commands can silently lose the earlier
  writer's update.
- **Options:** rely on UI serialization; normalize the entire schema now; add a Core
  transaction-scoped mutation API with revision/conflict handling.
- **Trade-offs:** UI-only locking fails across processes; normalization is a larger
  migration; transaction-scoped mutation is incremental and protects current data.
- **Recommendation:** keep schema v1, but perform load/validate/mutate/save inside one
  `BEGIN IMMEDIATE` transaction and expose conflict-safe Core mutation functions to the
  CLI. Add concurrent writer tests before multi-window/background expansion.
- **Reason:** local-first must still be loss-safe across OS shells and CLI processes.
- **Confidence:** High.

### D10: Mobile Web Surface

- **Problem:** the Expo web export requires the local development bridge and currently
  opens with a fetch error, while native iOS/Android use the in-app Rust runtime.
- **Options:** market web now; build a WASM/backend runtime; keep web as development QA.
- **Trade-offs:** shipping the current web shell is broken; WASM/backend expands scope
  and privacy obligations; dev-only preserves route testing without product confusion.
- **Recommendation:** iOS and Android are the mobile release surfaces. Keep Expo web as
  a development/router QA target until it has a bridge-free runtime and its own release
  evidence.
- **Reason:** unsupported breadth weakens trust and distracts from macOS-first release.
- **Confidence:** High.

### D11: Progress JSONL Lifecycle

- **Status:** Implemented and regression-tested on 2026-07-19 in `cb70daf`.
- **Problem:** resolver-level progress could not be correlated to one run, had no terminal
  state, and allowed clients to confuse incomplete output with a successful result.
- **Options:** preserve loose resolver events; replace the stream with a breaking v2; add
  lifecycle fields and events while preserving all v1 resolver keys.
- **Trade-offs:** loose events are unsafe for UI state; a v2 blocks current consumers;
  additive fields need one compatibility test per stream consumer.
- **Recommendation:** retain `schema_version: 1` and resolver events, add one `run_id`,
  stable `failure_kind`, and exactly one `run_finished` or `run_cancelled` event. On
  `SIGINT`, finish the active resolver, emit cancellation, exit 130, and do not save
  partial benchmark history.
- **Reason:** shells can render trustworthy progress without inventing completion or
  persisting an incomplete recommendation.
- **Confidence:** High.

### D12: Additive Structured Detail IDs

- **Status:** Recommendation Gate (`86f314b`), Capability Matrix (`d6df518`), and Preflight/
  Apply Prompt Policy (`015a2aa`) are implemented and regression-tested on 2026-07-19; other
  Core detail families remain queued.
- **Problem:** raw English notes force shells to parse presentation copy and cannot be
  localized safely, but replacing v1 arrays would break stored histories and decoders.
- **Options:** keep raw text; use a breaking schema; add typed IDs alongside raw details.
- **Trade-offs:** raw-only locks UX to Core copy; a breaking migration disrupts releases;
  additive IDs temporarily duplicate fields but preserve history and independent adoption.
- **Recommendation:** emit typed `gate_note_ids` with existing `safety_notes`, retain raw
  notes as technical Details, and use `serde(default)` for old storage. Extend that pattern
  family-by-family before changing any shell presentation contract.
- **Reason:** localization must not trade away offline history or decoder compatibility.
- **Confidence:** High.

## Quality Gates

- No release-ready claim without platform build, automated tests, signed artifact
  validation, manual permission flow, rollback test, and user-visible smoke evidence.
- No privileged capability enters a default Store SKU without provider approval and a
  documented fallback.
- Restricted capabilities are gated on generated and signed artifacts, not merely on
  source presence.
- Power DNS Restore must prove current state still equals DNSPilot's applied state.
- DNS benchmark success requires validated response identity and semantics.
- Shared storage mutations must be transaction-safe across processes.
- Contract changes require compatibility/version review across every consumer lane.
- Reference parity is judged by user outcome and evidence, not identical controls,
  runtime technology, tray behavior, or privileged capability.
