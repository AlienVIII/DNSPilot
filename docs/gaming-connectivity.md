# Gaming Connectivity Research

## Principle
DNS latency is not game latency. DNS may affect login, store, matchmaking host lookup, or CDN bootstrap, but gameplay quality usually depends on routing, server region, packet loss, jitter, NAT, and transport behavior.

## Research Areas
- Steam login, store, CDN, workshop, downloads.
- Valve services and API endpoints.
- Dota2 SEA matchmaking and coordinator connectivity.
- ISP routing, packet loss, jitter, and region selection.

## Candidate Measurements
- DNS lookup timing for Steam and Valve domains.
- TCP/TLS connect timing to resolved service endpoints.
- Optional ICMP/UDP reachability where platform policy allows.
- Repeated run stability, not single-run winner claims.

## Evidence Log
- 2026-06-30: `./script/smoke_macos_goal_flows.sh --include-network`
  successfully ran the Dota 2 SEA preset through DNS+TCP path comparison on the
  current network.
- This validates that the preset executes and returns candidate runs. It does
  not validate ICMP ping, in-match UDP latency, server tick quality, packet loss,
  or gameplay routing.
- Keep UI wording to a Check DNS game-target connection-path estimate and avoid
  gaming performance recommendations until richer evidence is recorded.

## Open Questions
- Which endpoints are stable enough to benchmark without violating terms or triggering abuse controls?
- Which measurements are allowed in store-safe builds?
- How should the UI separate DNS findings from gameplay connectivity findings?
