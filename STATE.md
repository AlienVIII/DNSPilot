# DNSPilot State

Last updated: 2026-09-03.

## Current Truth

- `main` is the integration source of truth. It includes the verified macOS source-build
  merge at `28a910e`, prior Linux/Windows lane milestones, the refreshed mobile release
  candidate through `6190635`, and shared Core/CLI hardening through `8360ba7`.
- Rust Core/CLI remains the only owner of benchmark, recommendation, policy, storage,
  and versioned JSON/JSONL contracts.
- Independent validation checks may run in background from isolated clean worktrees, but only
  reaped tasks with an exit code and complete log count as evidence.
- Product background execution is a separate D14 contract: one user-initiated read-only
  measurement may continue while its UI is inactive under OS limits, then use an
  opt-in local completion notification. There is no remote push, silent scheduler,
  background DNS mutation, force-quit guarantee, or automatic retry.
- macOS D14 benchmark support persists a versioned receipt, marks stale nonterminal work
  interrupted at launch, offers notification permission only after a run begins or from
  Settings, and sends generic local completion alerts only while inactive. Notification
  permission, Focus/lock-screen, and activation behavior still need real OS evidence.
- Product direction now separates read-only Network Health Check from DNS Benchmark.
  The guided journey recommends Health Check first and DNS selection last; this is an
  approved design direction, not an implemented or validated feature.
- The 2026-08-24 product review recommends making that sequence one Guided Connection
  Check home journey, with Benchmark independently available and Profiles/History
  secondary. This is a proposed D3 amendment pending user evidence, not an architecture
  change yet.
- Health Check will not use router credentials or mutate router/OS network state. DNS
  Benchmark keeps a user-selected resolver pool, separate A/IPv4 and AAAA/IPv6
  measurements, and a 500 ms maximum per DNS attempt.
- macOS Power candidate resolves notification activation to the exact saved result,
  reconciles the app preference with actual OS notification authorization, surfaces
  local scheduling failures, restores a prior app after post-install validation failure,
  and has packaged EN/VI visual smoke. The local workflow builds, ad-hoc signs,
  validates, installs, and opens one `~/Applications/DNS Pilot.app`; Store builds are
  sandboxed and Power direct-install builds are explicitly non-sandbox.
- Linux milestones 0-5 are substantially implemented: Power is fail-closed, Core
  contracts/storage are typed/shared, progress is streamed/cancellable, and the
  consumer decision/history loop exists. Accessibility, source-built packages, and
  real Linux evidence remain open.
- Windows milestones 0-4 and release preparation are committed. Core/static tests pass;
  WinUI/XAML/MSIX/tray/accessibility evidence still requires Windows.
- Mobile release-candidate source is integrated through `6190635`: Expo SDK 57 patches,
  localized result presentation, Router warning gate, narrow production audit policy,
  release-shape Android manifest/dex gates, tutorial/Help, and Store-vs-opt-in iOS DNS
  entitlement isolation are all current. Local Android artifacts are debug-signed QA only;
  remote EAS signing and physical/store validation remain manual.

## Review Findings

- UI parity is functional, not visually proven. No durable signed cross-platform
  screenshot/accessibility matrix exists; real Windows/Linux UI remains `NOT RUN`.
- Lane risk/progress docs contained stale resolved claims. Root state and the 2026-07-19
  overall review now supersede those claims.
- The highest-value consumer feature is diagnosis plus one safe next action and Retest,
  not a broader resolver catalog or more advanced benchmark metrics. See the 2026-08-24
  product value review.
- Current automated gates are mixed: Core and Mobile functional tests pass, but Core
  clippy and Mobile Expo compatibility/release preflight are red on the current toolchain.

## Latest Validation

- macOS: `swift test`, `./script/ci_macos.sh`, and
  `./script/preflight_macos_release.sh --include-power` pass on 2026-09-03. They cover
  live DNS-only/DNS+TCP smoke, Store/Power bundle validation, and the D14 Store-safety
  contract. Packaged EN/VI visual smoke now passes after checking compact
  actions and waiting for process termination before relaunch. Accessibility-driven
  Quick Test reaches Result while one visible window and one process remain. Power
  signing fails closed unless the direct-install artifact avoids App Sandbox, while
  Store signing requires sandbox/network entitlements. Power Restore verifies the
  applied DNS state before mutation. Reopen policy keeps an existing window singleton
  and defers to AppKit only when no window is visible.
- Linux: fmt, tests, and clippy with `-D warnings` pass at `034621c`.
- Windows: `apps/windows/validate-windows-lane.sh` passes 65 Core/static tests; the
  expected Windows-only XAML compiler remains `NOT RUN` on macOS.
- Core/CLI: `cargo fmt --check`, `cargo test --workspace`, and `git diff --check` pass
  at `86f314b` (137 tests). Live DNS requests pin the resolver source, use OS entropy
  for transaction IDs, validate response semantics, serialize snapshot mutations, and
  emit versioned progress runs with terminal/failure/cancellation semantics. Benchmark
  summaries expose typed recommendation `gate_note_ids`; Capability Matrix, Preflight, and
  Apply Prompt Policy, Apply Plan, profile security, and connection-path caveats also have typed
  IDs, while old history remains readable.
- Core/CLI on 2026-08-24: workspace tests and format pass. Rust 1.96
  `cargo clippy --workspace --all-targets -- -D warnings` fails on three
  `manual_is_multiple_of` findings and one nine-argument `apply_plan` finding.
- Mobile candidate: `npm run verify` passes 106 tests, TypeScript, Expo config,
  Router warning gate, compatibility, and a fail-closed production audit policy on
  2026-08-09; `expo-doctor` passes 20/20. `npm run preflight:release` and the iOS
  Simulator Release build pass. The current debug-key QA APK is installed on Pixel 9 Pro XL
  with no launch crash, but the interactive current-artifact flow remains manual because
  the device was locked. The local AAB/APK are release-shape QA artifacts, not Play uploads.
- Mobile recheck on 2026-08-24: 106 tests and TypeScript pass, but full verify/preflight
  are red. Expo reports SDK 57 patch drift (`expo`/router and related packages); one
  verify attempt also received malformed JSON from Expo's version service. A fresh local
  Android release-shape build passes manifest/dex gates and produces debug-key QA AAB/APK;
  it does not restore the red verify/preflight gates or constitute a release candidate.
- Linux recheck on 2026-08-24: lane tests and app-manifest clippy `-D warnings` pass.
- Windows recheck on 2026-08-24: 65 Core/static tests and solution build pass; the WinUI
  XAML compiler remains correctly classified `NOT RUN` on macOS.
- Dependency review: RustSec reports no known Rust advisories; NuGet reports no known
  vulnerable Windows packages. Mobile npm reports 14 high findings inherited from Metro's
  currently unremediable `image-size` chain plus 8 moderate findings; the production gate
  permits only the two locked advisory sources and fails every other high/critical finding.
- Historical mobile web visual QA at 390px confirms tutorial/Help and three primary tabs,
  which now predates D13's four-area product direction. It also
  confirms repeated titles, implementation jargon, premature empty sections, and a
  first-run bridge fetch error.

## Manual Release Gates

- macOS: Apple signing/provisioning, hosted support/privacy URLs, signed Dark
  Mode/narrow/keyboard/VoiceOver evidence, five-user usability, App Store submission,
  and real Power QA.
- Windows: Windows-host WinUI/MSIX/tray/accessibility QA, signing, Partner Center.
- Linux: source-built package CI, GNOME/KDE/resolver QA, signing, publisher accounts.
- Mobile: unlock and complete current Pixel QA, signed iOS/iPadOS/Android device QA,
  EAS project/login/upload credentials, Apple/Google accounts, store submission, and Apple
  entitlement/provisioning evidence only for the optional entitled profile.

## Sources

- Architecture: `PROJECT.md`
- Roadmap: `TODO.md`
- Overall review: `docs/research/2026-07-19-overall-product-review.md`
- Product value review: `docs/research/2026-08-24-product-value-usability-review.md`
- Cross-platform contract: `docs/reference-lane-contract.md`
- Provider steps: `docs/os-provider-trust.md`
