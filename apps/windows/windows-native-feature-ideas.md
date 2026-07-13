# Windows Native Feature Queue

The ordered roadmap and acceptance criteria live in
`apps/windows/windows-predevelopment-review.md`. This file is only a compact
promote/defer/reject index.

## Promote Next

- Runtime/helper readiness and recovery states.
- Consumer navigation: Check DNS, Profiles, History.
- Responsive WinUI visual states and keyboard/Narrator accessibility.
- DNS-only Quick Check, tagged gaming DNS + TCP behavior, and operational Cancel.
- Confidence-aware result hierarchy and one primary guided Settings action.
- Versioned benchmark preferences and Default/Vietnam suite quick picks.
- Strict installed-package/helper launch evidence.

## Implemented In Store-Safe Lane

- Guided DNS settings checklist.
- Tray quick benchmark, Validate current DNS, and Open Network Settings.
- Custom resolver profile picker for DNS-only and DNS + TCP benchmarks.
- Custom domain suite picker and suite storage management.
- Protected-network apply suppression from `apply-plan` dispositions.

## Deferred

- Adapter-aware read-only network context detection.
- Windows notifications.
- Export diagnostics bundle.
- In-process Rust runtime unless Store/package evidence rejects the helper model.
- Power edition Windows service for explicit admin apply and rollback.

## Rejected For Store

- UAC, silent DNS mutation, `netsh`, registry/DnsClient writes, privileged
  services, direct DNS flush, and tray-only workflows.
