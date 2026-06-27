# DNS Pilot Windows Privacy Policy Draft

## BLUF
- Public Privacy policy URL: `REPLACE_WITH_PRIVACY_POLICY_URL`
- Public Support URL: `REPLACE_WITH_SUPPORT_URL`
- Contact email: `REPLACE_WITH_SUPPORT_EMAIL`
- This draft is for the Windows Store-safe edition. Review it before hosting.

## What DNS Pilot Does
DNS Pilot benchmarks DNS resolver performance, gives store-safe apply guidance, opens Windows Network Settings, and validates the current Windows DNS path after the user changes settings manually.

## Data Processed By The App
- DNS queries: the app asks selected resolvers to resolve benchmark domains so it can measure DNS latency, failure rate, timeout rate, IPv4 health, and IPv6 health.
- TCP connection probes: when DNS + TCP mode is selected, the app attempts TCP connection probes to benchmark targets to estimate path quality. It does not send application payloads beyond the connection attempt.
- Local profile data: custom DNS profile names and DNS server addresses are stored locally on the device.
- Local history data: benchmark history, recommendation IDs, timing metrics, warnings, and diagnostics are stored locally on the device when history persistence is enabled.
- Clipboard data: DNS server lists, command previews, checklists, and reports are copied only when the user presses a copy button.

## Data Not Collected
- DNS Pilot does not require account sign-in.
- DNS Pilot does not sell personal data.
- DNS Pilot does not use advertising identifiers.
- DNS Pilot does not upload profile or benchmark history to a DNS Pilot server in this Windows Store-safe edition.
- DNS Pilot does not silently change system DNS settings and performs no silent DNS mutation.

## Network Activity
The app sends DNS queries and TCP connection probes to the resolvers and benchmark domains selected by the app configuration or the user. Those external resolvers and target services may observe network metadata such as source IP address and query timing according to their own policies.

## Local Storage And Retention
Custom profiles and benchmark history are stored locally on the user's Windows device through the DNS Pilot CLI-backed storage path. The user can delete custom profiles and clear/delete history from the app UI. Uninstalling the app or deleting its local data may remove this data depending on Windows package storage behavior.

## User Control
- The Store-safe app guides DNS changes through Windows Settings.
- The user must manually apply DNS server changes in Windows Network Settings.
- The app can copy DNS servers and open Settings, but it does not call admin DNS mutation APIs, `netsh`, PowerShell DNS mutation, or registry DNS writes.

## Diagnostics And Support
If a user contacts support, they may choose to share copied diagnostic reports. These reports can include resolver names, DNS server addresses, benchmark domains, timing metrics, warnings, and local error messages.

## Children
DNS Pilot is a network diagnostics utility and is not directed to children.

## Changes
Update this policy when DNS Pilot adds account features, telemetry, cloud sync, crash reporting, direct DNS mutation, or any new data sharing path.

## Publisher Checklist
- Host this policy at a stable HTTPS URL before Store submission.
- Replace `REPLACE_WITH_PRIVACY_POLICY_URL`, `REPLACE_WITH_SUPPORT_URL`, and `REPLACE_WITH_SUPPORT_EMAIL`.
- Ensure the hosted text matches the submitted Store package behavior.
