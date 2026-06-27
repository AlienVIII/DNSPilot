# DNS Pilot Support

DNS Pilot is a macOS utility for DNS benchmarking, saved domain test suites, and
guided resolver setup.

## Common Help

- Benchmark results are estimates for the current network path. They do not
  claim full browser, game, or internet speed improvement.
- Store-safe builds do not silently change macOS DNS. Apply flows copy DNS
  servers, open Network Settings, and ask the user to make the OS-level change.
- Flush DNS in the Store-safe build copies a checklist. It does not run
  administrator commands.
- Power edition admin apply/flush is separate from the App Store build and
  should be used only on networks where you can safely restore DNS.

## Troubleshooting

- If every DNS candidate fails, check VPN, firewall, captive portal, MDM,
  corporate DNS policy, and IPv4/IPv6 reachability.
- If DNS-only is inconclusive, retry with DNS + TCP to include connection-path
  behavior.
- If results look stale after changing DNS, flush DNS or reconnect the network,
  then run System DNS validation.
- If a custom domain fails validation, remove protocol prefixes, paths, ports,
  and spaces; enter only hostnames.

## Data

DNS Pilot stores custom DNS profiles, custom domain suites, and benchmark history
locally on the Mac. The current Store-safe build has no accounts, analytics,
tracking, or cloud sync.

## Contact Placeholder

Replace this section with the public support email or issue form before hosting
the page and submitting the App Store build.
