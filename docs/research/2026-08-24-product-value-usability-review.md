# DNSPilot Product Value And Usability Review

Last reviewed: 2026-08-24. Role: Principal Product Architect / product reviewer.

## BLUF

The highest-value feature is a **Guided Connection Check**: diagnose the current
connection, explain the most likely problem in plain language, offer one safe next
action, and verify whether that action helped. DNS Benchmark remains an independent
measurement used only when the connection is healthy enough for DNS selection to be
meaningful.

Do not compete on resolver count, raw metrics, or advanced scoring. Existing products
already cover those areas deeply. DNSPilot should win on trustworthy interpretation and
safe follow-through for people who do not understand DNS.

## Findings

### Critical

No validated Critical finding was found in this pass.

### Major

1. **macOS D14 does not open the exact result.** Notification activation extracts a
   `runID`, but the shell ignores it and only selects Benchmark. The receipt also saves
   no result reference. This does not meet D14's exact-local-result contract. See
   `DNSPilotMacApp.swift:445`, `DNSPilotMacApp.swift:2955`, and
   `DNSPilotLocalNotifications.swift:58` on macOS head `78239d8`.
2. **macOS visual evidence is currently red while branch docs claim pass.** On
   2026-08-24, `visual_macos_smoke.sh` exited 6 because it expected `Run Quick Test`
   while the packaged UI exposed `Run`. The captured window also showed sidebar
   `Check DNS` paired with content title `Benchmark`, technical setup copy, and no
   implemented Health Check. Keep the branch outside `main` until proof and docs agree.
3. **The current information architecture exposes features before user outcomes.** Four
   equal destinations make normal users decide whether they need Health Check, Benchmark,
   Profiles, or History. Their real question is simpler: what is wrong, what should I do,
   and did it help?
4. **Current automated gates are not all green.** Core tests pass, but Rust 1.96
   `clippy -D warnings` reports three `manual_is_multiple_of` findings and one
   `too_many_arguments` finding. Mobile's 106 tests and typecheck pass, but Expo's
   compatibility gate requires newer SDK 57 patch packages and release preflight stops.
5. **Commercial value remains unproven with target users.** There is no five-user
   moderated evidence for diagnosis comprehension, correct next-action choice, or
   successful Retest. Automated tests cannot prove these outcomes.
6. **Mobile's successful runtime path still leads with implementation detail, not a
   user decision.** Fresh Android emulator QA on 2026-08-24 launched, completed a quick
   check, and had no crash, but immediately exposed `success`/`degraded`, `Process`,
   elapsed time, stage rows, and resolver samples. Six target chips also precede the
   primary action, while the first-run tutorial has three long explanatory paragraphs.
   The replay tutorial control is present and accessible in the top-right. Move raw
   evidence behind `Details`/Info and lead with one plain-language outcome plus one safe
   next action or Retest; keep the tutorial to three short titles with progressive detail.

### Minor

1. macOS stores an app preference for notifications without reconciling current OS
   authorization. The toggle can appear enabled after permission is revoked.
2. macOS ignores local-notification scheduling errors. A best-effort feature still needs
   an honest in-app state and diagnostic evidence when delivery cannot be scheduled.
3. The per-user installer validates the staged app, but its post-move failure path does
   not restore the previous app before cleanup. The probability is low; the update
   contract should still fail back to the last known-good bundle.

## Product Decision

**Problem:** Normal users experience "the internet is slow" but usually cannot distinguish
Wi-Fi, router/ISP, DNS, IPv4/IPv6, VPN, or one broken site. A resolver benchmark alone can
produce precise numbers without answering the user's actual problem.

**Options:**

1. Keep four equal primary areas: preserves feature separation, but requires users to
   understand the product before it can help them.
2. Use one Guided Connection Check home journey, with Benchmark, Profiles, History, and
   diagnostics available as secondary tools: reduces choice while preserving honest
   capability boundaries.
3. Use one `Optimize` button that diagnoses and changes DNS automatically: easiest to
   describe, but overpromises diagnosis, hides permissions, and risks unsafe mutation.

**Trade-offs:** Option 1 is easiest for the existing shells but keeps cognitive load.
Option 2 requires a new Core Health Check contract and shell navigation work, but creates
a defensible consumer product. Option 3 is superficially simple but conflicts with Store,
privacy, rollback, VPN/MDM, and evidence boundaries.

**Recommendation:** Choose option 2. Make `Check my connection` the dominant first action.
Return one outcome title, one state/risk statement, and one next action. Recommend DNS
Benchmark only after infrastructure observations are healthy or unsupported but not
contradictory. After setup, Retest and report `Better`, `No meaningful change`, or
`Restore previous DNS` when that action is safely available.

**Reason:** The market already has deep benchmark products. DNSPilot's durable advantage
is trusted interpretation plus a safe closed loop, not another table of resolver latency.

**Confidence:** High for the product direction; Medium for willingness to pay until five
moderated sessions and pricing tests exist.

## Acceptance Criteria

- Cold launch offers one primary `Check my connection` action without requiring setup.
- Result order is outcome, current state/risk, one next action, then disclosed evidence.
- DNS is never recommended as a fix for observed Wi-Fi/gateway/upstream instability.
- Health Check and DNS Benchmark keep separate contracts, scores, history, and caveats.
- The user can always open Benchmark directly; Profiles and History remain discoverable
  but secondary to the decision journey.
- Setup names the OS action and consequence before permission or administrator consent.
- Retest compares the same network scope and reports whether change is meaningful.
- EN/VI, narrow layout, text scaling, keyboard/touch, and assistive technology preserve
  the title/status/action relationship.
- Five moderated users can explain the result and choose the safe next action without
  facilitator help.

## Evidence

- Apple and Microsoft troubleshoot connection state before low-level DNS action. Apple
  Wireless Diagnostics returns detected issues and possible solutions without changing
  settings; Windows starts with automated network diagnostics and separates device,
  Wi-Fi/router, ISP, VPN, and app/site causes:
  <https://support.apple.com/guide/mac-help/use-wireless-diagnostics-mchlf4de377f/mac>,
  <https://support.microsoft.com/en-us/windows/fix-wi-fi-connection-issues-in-windows-9424a1f7-6a3b-65a6-4d78-7f07eee84d2c>.
- Android likewise starts with connection checks, Wi-Fi/mobile comparison, signal,
  router, and provider steps rather than assuming DNS:
  <https://support.google.com/android/answer/2651367>.
- DNS Benchmark+ already competes on UDP/DoH/DoT/DNSCrypt, endpoint probes, DNSSEC,
  jitter/P99, custom weights, history, export, and sync:
  <https://apps.apple.com/us/app/dns-benchmark/id6760799772>.
- Measurement research found no single DNS protocol or resolver best for every client,
  supporting local measurement and cautious recommendations:
  <https://arxiv.org/abs/2007.06812>.
- Apple recommends fast, optional, contextual onboarding and permission requests at the
  feature that needs them. Notification content should be concise, useful, private, and
  suppressed while the app is active:
  <https://developer.apple.com/design/human-interface-guidelines/onboarding>,
  <https://developer.apple.com/design/human-interface-guidelines/notifications>,
  <https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications>.

## Recommended Order

1. Restore green automated gates: Core clippy and Mobile Expo patch alignment.
2. Fix macOS D14 exact-result activation, OS authorization truth, scheduling evidence,
   installer rollback, and real visual smoke; then re-review the macOS branch for merge.
3. Implement the D13 Core Health Check contract with synthetic failure fixtures.
4. Implement Guided Connection Check on macOS as the reference consumer journey.
5. Run five moderated users; amend D3/reference navigation only after evidence confirms
   the proposed hierarchy.
6. Adapt the proven contract to Windows, Linux, iOS/iPadOS, and Android.

## Next Terra Scope

Use the per-lane prompts in `docs/codex-thread-prompts.md`. Do not start background parity
work on every OS before the Core Health Check contract and macOS reference journey are
green; that would multiply shell work before validating the product value.
