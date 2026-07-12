# macOS V1 Commercial Validation

## Decision To Validate

DNSPilot should be valued as a trustworthy way to choose and verify DNS for the
current network. It must not be positioned as a generic internet-speed booster.

## Study

Recruit 5-8 macOS users who have changed DNS, use a VPN/corporate network, run
developer workloads, or troubleshoot gaming/video connectivity. Exclude people
who only have a theoretical interest in DNS.

Each participant completes this flow on their own normal network. Use
`docs/macos-v1-usability-session.md` for the task-by-task facilitator script.

1. Run the default DNS check, then choose DNS + TCP when connection-path timing is needed.
2. Explain the difference between fastest observed DNS and the recommendation.
3. Read a degraded or protected-network result and choose the next action.
4. Use the guided Apply flow and explain whether DNSPilot changed system DNS.
5. Choose a game target and explain that its timing is not in-match latency.
6. Find the Help/Setup explanation of Direct Admin Actions.

## Evidence To Capture

- Participant use case and network constraint, without account identifiers or
  DNS query logs.
- Completion/blocker for each task and exact confusing copy or terminology.
- Whether the participant correctly distinguishes DNS lookup timing from full
  browser, game, or application speed.
- Whether the participant would trust a recommendation, and what evidence is
  missing when they would not.

## Success Criteria

- At least five participants complete the benchmark and correctly explain the
  recommendation's scope without facilitator correction.
- No participant believes the Store-safe guided Apply button silently changes
  system DNS after reading its confirmation.
- Protected-network and degraded outcomes produce a safe next action instead of
  pressure to apply a resolver.
- Repeated terminology or flow failures become tracked product changes before
  launch; isolated preference comments do not drive architecture changes.

## Launch Metrics

Define these metrics before instrumentation work:

| Metric | Definition | Initial Collection |
| --- | --- | --- |
| Benchmark completion | Started benchmark reaches completed, failed, or cancelled terminal state | Consent-based study observation |
| Recommendation confidence | Result reports high, medium, low, or inconclusive confidence | Consent-based study observation |
| Guided apply completion | User copies DNS and opens Settings from a confirmed guided action | Consent-based study observation |
| Successful retest | Post-change System DNS validation completes without a blocking failure | Consent-based study observation |
| Seven-day return | Participant opens DNSPilot again within seven days for a new network need | Follow-up consent |

## Privacy Boundary

V1 stays local-first. Do not add analytics, account identity, or DNS query-log
upload to satisfy this study. If post-launch telemetry becomes necessary, create
a separate privacy/product decision with explicit user consent and App Store
privacy review.

## Exit Decision

Use the study to choose exactly one next product move:

- Improve macOS wording/flow if users misunderstand scope or permission state.
- Proceed to Store-safe macOS launch if the flow is understood and release gates
  are complete.
- Expand another OS only after macOS evidence supports the same user need.
