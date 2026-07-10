# DNSPilot Product Architecture

Last reviewed: 2026-07-11.

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

Ship and validate macOS first. Maintain Windows, Linux, and mobile as benchmark-first
lanes, but do not expand privileged adapters until macOS release evidence and user
research establish demand.

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

- **Problem:** parallel feature expansion across four OS lanes dilutes release focus.
- **Options:** continue parity work; pause all but macOS; keep thin validation lanes.
- **Trade-offs:** parity maximizes breadth but delays proof; a full pause creates stale
  ports; thin lanes preserve contracts at controlled cost.
- **Recommendation:** macOS-first release with thin benchmark-first validation lanes.
- **Reason:** one trusted, publishable product creates faster commercial learning than
  four partially releasable products.
- **Confidence:** Medium-high pending user research.

## Quality Gates

- No release-ready claim without platform build, automated tests, signed artifact
  validation, manual permission flow, rollback test, and user-visible smoke evidence.
- No privileged capability enters a default Store SKU without provider approval and a
  documented fallback.
- Contract changes require compatibility/version review across every consumer lane.
