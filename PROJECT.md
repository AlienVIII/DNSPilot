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

### D3: Power DNS Rollback

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

## Quality Gates

- No release-ready claim without platform build, automated tests, signed artifact
  validation, manual permission flow, rollback test, and user-visible smoke evidence.
- No privileged capability enters a default Store SKU without provider approval and a
  documented fallback.
- Power DNS Apply must retain an exact active-service rollback record before it can
  be released outside test environments.
- Contract changes require compatibility/version review across every consumer lane.
