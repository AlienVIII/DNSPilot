# Platform Summary

Last integration pass: 2026-07-19.

## Integration State

| Lane | Reviewed head | `main` state | Next proof |
| --- | --- | --- | --- |
| Core CLI | `c6a624d` baseline | No separate lane delta | D8 DNS integrity, then D9 storage safety |
| macOS | `7609d57` | Merged by `554a9bc` | Signed EN/VI/accessibility and provider proof |
| Linux | `034621c` | Merged by `a5f8b57` | Milestone 6 plus source-built package/real-host proof |
| Windows | `2f3cef0` | Merged by `7535ea3` | Windows WinUI/MSIX/tray/accessibility proof |
| Mobile | `8dd1c26` | Isolated; not merged | Restore green verify, security/privacy/UX gates |
| Docs | This pass | Integration source of truth | Sync every worktree after docs commit |

`main` is the only cross-lane source of truth. A lane is integrated only after review,
lane validation, merge, and merged-result validation. Mobile source may integrate under
amended D1 after normal gates pass; its entitled iOS artifact remains separately blocked.

## Product Reference

macOS defines the first commercial decision journey, not shared OS implementation. Every
lane adapts provider permissions, settings, packaging, and accessibility honestly while
reusing Core recommendation, policy, storage, and JSON/JSONL contracts.

## Current Proof

- macOS: CI and Store/Power preflight pass; 270 Swift tests pass. Signed visual,
  VoiceOver, five-user, signing, and submission proof remain open.
- Linux: fmt, tests, clippy `-D warnings`, typed Core storage/results, streamed progress,
  cancellation, and consumer navigation pass. Real Linux packages/desktops are `NOT RUN`.
- Windows: 65 Core/static tests pass. WinUI/XAML/MSIX/tray/accessibility remain `NOT RUN`
  on this macOS host.
- Mobile: 95 tests, typecheck, Expo config, and route export pass. Full verify currently
  fails Expo patch compatibility; release preflight therefore did not run.

## Non-Negotiable Boundaries

- Default Store SKUs never silently mutate DNS.
- Restricted/admin capability is separately packaged, consented, reversible, and gated
  on generated/signed artifacts plus real-provider proof.
- Power Restore never overwrites state that changed after DNSPilot Apply.
- Android consumer uses Private DNS Settings guidance, not `VpnService` or device-owner
  control. Windows Store remains non-elevated. Linux Power remains fail-closed.
- Expo web is development/router QA, not a commercial surface.
- No proof/no claim: unavailable checks are `NOT RUN`, not inferred from mocks.
