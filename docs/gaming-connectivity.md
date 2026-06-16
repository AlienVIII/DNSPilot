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
- No validated gaming-specific evidence yet.
- Do not implement gaming recommendations until evidence is recorded here.

## Open Questions
- Which endpoints are stable enough to benchmark without violating terms or triggering abuse controls?
- Which measurements are allowed in store-safe builds?
- How should the UI separate DNS findings from gameplay connectivity findings?

