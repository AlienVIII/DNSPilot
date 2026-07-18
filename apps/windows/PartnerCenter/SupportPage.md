# DNS Pilot Windows Support

DNS Pilot is a Windows utility for DNS benchmarking, saved resolver profiles,
domain suites, and guided Windows DNS setup.

## Common Help

- Results estimate the current DNS and network path; they do not promise full
  browser, game, or internet speed improvement.
- The Microsoft Store build does not silently change Windows DNS. Guided Apply
  copies DNS servers and opens Windows Settings for the user to make the change.
- Quick Check is DNS-only. DNS + TCP adds connection-path estimates.
- Gaming presets use DNS + TCP timing. They are not ICMP ping or in-match UDP
  latency.

## Troubleshooting

- If all candidates fail, check VPN, firewall, captive portal, MDM, corporate
  DNS policy, and IPv4/IPv6 reachability.
- If DNS-only is inconclusive, retry with DNS + TCP.
- After changing DNS manually, return to DNS Pilot and run Validate DNS or
  Retest System DNS.
- Custom domain targets accept hostnames only. Omit protocol prefixes, paths,
  ports, and spaces.
- Use Copy report when contacting support. Review it before sharing because it
  includes benchmark domains, resolver addresses, timing, and error details.

## Local Data

DNS Pilot stores custom DNS profiles, domain suites, benchmark history, language,
and benchmark preferences locally. The Store-safe build has no accounts,
analytics, advertising, tracking, or cloud sync.

## Contact Placeholder

Replace this section with the public support email or issue form before hosting
and submitting the Store package.
