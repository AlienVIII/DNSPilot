# DNS Pilot Partner Center Review Notes

Use this folder as the source of truth for Microsoft Store metadata and review
evidence. It describes the Store-safe Windows package only; Power/admin DNS
behavior is a separate future distribution.

## Product Identity

- Product name: DNS Pilot
- Category: Utilities and tools
- Package identity: `DNSPilot.Windows.Store` until Partner Center assigns the
  final identity.
- Store promise: benchmark DNS, copy guidance, open Windows Settings, and
  validate current DNS. It is not one-click DNS apply.

## Review walkthrough

1. Launch the packaged app. It runs as `asInvoker`; no UAC or administrator
   prompt should appear.
2. In Check DNS, run Quick Check. It is bounded DNS-only benchmarking.
3. Select DNS + TCP or a catalog game preset. The app states that game checks
   are DNS + TCP estimates, not ICMP ping or in-match UDP latency.
4. Add a custom plain DNS profile and a custom domain suite in Profiles, then
   select each in Check DNS.
5. After a healthy result, open Apply in Windows Settings. Confirm the dialog
   defaults to Cancel. On confirmation it copies DNS values and opens Windows
   Settings; it never changes DNS itself.
6. Apply a DNS change manually in Windows Settings, return to DNS Pilot, and
   run Retest System DNS.
7. Open Help and change EN/VI language; restart to observe persisted language
   and normalized benchmark preferences.
8. Open Advanced diagnostics. Capability state and copyable reports remain
   available without exposing local user paths.

Expected behavior: all benchmark, profile, history, copy, Settings, and
retest actions work without elevation. The app does not call `netsh`, adapter
DNS APIs, PowerShell DNS mutation, or registry DNS writes.

## Permission And Capability Notes

- `internetClient`: DNS and TCP benchmark probes initiated by the user.
- `runFullTrust`: packaged WinUI desktop shell, bundled CLI process boundary,
  and optional tray integration. It is not used for elevation or silent DNS
  mutation.
- `app.manifest` remains `asInvoker`.

Use the exact restricted-capability justification in
`apps/windows/windows-store-listing.md`. If Partner Center rejects tray behavior
or `runFullTrust`, retain the complete toolbar workflow and reassess the
package architecture before submission; do not add elevation to the Store SKU.

## Metadata Sources

- Listing and certification text: `apps/windows/windows-store-listing.md`.
- Privacy policy source: `apps/windows/windows-privacy.md` and
  `PartnerCenter/PrivacyPolicy.md`.
- Public support source: `PartnerCenter/SupportPage.md`.
- Signed-release captures: `PartnerCenter/ScreenshotPlan.md`.
- QA evidence: `apps/windows/windows-release-evidence-template.md`.

## Manual Release Blockers

- Partner Center app record and final package identity/publisher.
- Signing certificate or Partner Center signing access.
- Signed Windows-host MSIX build, install, accessibility, tray, and Settings
  handoff proof.
- Public HTTPS support, privacy, and website URLs.
- Final screenshots and certification/privacy answers in Partner Center.
