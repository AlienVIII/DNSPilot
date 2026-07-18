# DNSPilot Overall Product Review

Last reviewed: 2026-07-19. Role: Product Architect / security and UX reviewer.

## BLUF

Ship macOS Store-safe first. Keep one shared Core contract and make Windows, Linux,
and mobile prove the same decision journey with native evidence. Do not widen release
scope until DNS response integrity, mobile development-boundary security, and durable
cross-platform evidence are resolved.

## Findings

### Critical

No validated Critical release blocker was found in this pass. The earlier Deep Security
Scan workspace was canceled at preflight and produced no findings or report; this
document is a focused architecture/security review, not an exhaustive scan.

### Major

1. **Benchmark integrity is weaker than the product promise.** Core receives UDP from
   an unconnected socket, CLI transaction IDs are predictable, and response parsing
   does not require response semantics plus a matching question. A spoofed or malformed
   datagram can be counted as success. See `crates/dnspilot-core/src/dns_resolver.rs`,
   `crates/dnspilot-core/src/dns_wire.rs`, and `crates/dnspilot-cli/src/main.rs`.
2. **Shared local storage can lose concurrent writes.** CLI mutations load and replace
   one JSON snapshot without a transaction-scoped mutation boundary. Two app/process
   writers can overwrite each other. See `crates/dnspilot-core/src/storage.rs`.
3. **The mobile development bridge is unsafe on a normal LAN.** It binds all
   interfaces, allows wildcard CORS, has no authentication, accepts a caller database
   path, and returns local paths in health data. See
   `apps/mobile/DNSPilotMobile/server/dev-server.mjs`.
4. **Mobile backup/privacy behavior is undefined.** The generated Android manifest
   allows backup while Core stores DNS profiles, custom domains, and history. iOS has
   no explicit equivalent backup decision. Local-first is not sufficient without a
   retention and backup policy.
5. **macOS Power Restore can overwrite a later OS/VPN/MDM change.** Restore verifies
   snapshot age and active service, but not that current DNS still equals what DNSPilot
   applied. Store-safe macOS is unaffected; Power is not release-ready.
6. **Consumer UI still exposes implementation detail.** Mobile web visual QA at 390px
   showed repeated titles, empty Process/Result sections before a run, immediate
   `Failed to fetch`, and Core/CLI/storage jargon in Profiles. The tutorial and
   top-right Help affordance work, but progressive disclosure is incomplete.
7. **Cross-platform confidence is documentation-heavy.** macOS has strong automated
   proof; Windows and Linux still lack real-host visual/runtime evidence. No signed,
   durable EN/VI/accessibility screenshot matrix exists across platforms.

### Minor

1. Lane risk/progress files retained resolved claims, including Linux command execution
   and missing progress, macOS stateless system benchmark, and mobile bridge-only
   architecture.
2. The Linux Flatpak manifest is valid for local QA only because it consumes prebuilt
   ELF files. It is not a Flathub submission source build.
3. npm reports 11 moderate and no high/critical advisories. The current forced fix
   path would downgrade/replace incompatible tooling, so it must not be applied blindly.

## Product Decision

**Problem:** Parallel platform work is creating breadth faster than commercial proof.

**Options:** launch every shell together; pause non-macOS lanes; use macOS as the first
commercial release while other lanes close one evidence contract.

**Trade-offs:** a simultaneous launch maximizes reach but multiplies weak release gates;
pausing lanes wastes validated work; an evidence-led sequence delays platform breadth
but makes quality measurable and keeps architecture shared.

**Recommendation:** release macOS Store-safe first. Continue Windows, Linux, and mobile
only against `docs/reference-lane-contract.md`; do not promise their release dates until
native build, visual/accessibility, packaging, and provider evidence pass.

**Reason:** DNSPilot sells trust in a recommendation. One proven product is more
commercially credible than four partially proven shells.

**Confidence:** High.

## Architecture Decisions

- D1 amended: mobile source may integrate after normal gates pass; Apple restricted
  capability remains blocked at the generated/signed `production-ios-dns` artifact.
- D8 added: connected UDP, unpredictable transaction IDs, and strict DNS response
  validation are P0.
- D9 added: shared persistence mutations become transaction-scoped before background or
  multi-window growth.
- D10 added: Expo web is development/router QA only until it has a bridge-free runtime.
- Power Restore must compare current DNS with DNSPilot-applied state before rollback.

Full decision records are in `PROJECT.md`; execution order is in `TODO.md`.

## UX Direction

- Keep `Check DNS`, `Profiles`, and `History` as the only primary destinations.
- Render one title, one status, and one primary action. Do not render empty process or
  result panels before a run.
- Put policy, diagnostics, provider detail, and implementation terms behind Help/Info.
- Keep first-run tutorial optional, value-first, and reopenable from top-right Help.
- Treat hover as desktop enhancement only; every detail must also be keyboard/touch and
  assistive-technology reachable.

This follows Apple guidance to make onboarding optional and benefit-focused, Microsoft
Fluent progressive onboarding, and GNOME's rule that tooltips supplement rather than
replace labels:

- <https://developer.apple.com/design/human-interface-guidelines/onboarding>
- <https://developer.apple.com/design/human-interface-guidelines/privacy>
- <https://fluent2.microsoft.design/onboarding/>
- <https://developer.gnome.org/hig/patterns/feedback/tooltips.html>

## Provider And Distribution Direction

- Apple DNS Settings is user-enabled and restricted-capability gated; default Store
  artifacts omit it: <https://developer.apple.com/documentation/networkextension/dns-settings>
- Android Private DNS programmatic control is a device-owner API. Consumer Android keeps
  Settings guidance and no `VpnService`:
  <https://developer.android.com/reference/android/app/admin/DevicePolicyManager>
- Windows Store remains non-elevated; `runFullTrust` needs explicit declaration/review:
  <https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations>
- Flathub submission must build from declared source rather than local prebuilt ELF:
  <https://docs.flathub.org/docs/for-app-authors/requirements>

## Validation Snapshot

- macOS: CI and Store/Power preflight pass; 270 Swift tests pass.
- Linux: fmt, tests, and clippy `-D warnings` pass.
- Windows: lane validator passes 65 Core/static tests; WinUI/MSIX is `NOT RUN` here.
- Mobile: 95 tests, typecheck, and route export pass; full verify is red on current Expo
  patch compatibility and release preflight was not reached.
- Dependencies: RustSec and NuGet found no known advisories; npm has 11 moderate and no
  high/critical findings.

## Next Terra Scope

1. Core DNS response integrity, with adversarial tests.
2. Transaction-safe Core mutation API, with concurrent-writer tests.
3. Mobile dependency alignment, dev-bridge hardening, backup policy, and progressive UI.
4. macOS Power compare-before-restore guard.
5. Real-host evidence passes for Linux and Windows; signed/manual macOS provider gates
   stay batched at the end.
