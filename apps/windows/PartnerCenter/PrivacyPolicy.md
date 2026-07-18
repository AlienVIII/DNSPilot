# DNS Pilot Windows Privacy Policy Draft

This draft matches the Store-safe Windows package. Review it before publishing
if telemetry, crash reporting, accounts, sync, remote catalog updates, or a
hosted backend are added.

## Data Collection And Tracking

DNS Pilot does not collect personal data, track users across apps or websites,
use advertising identifiers, include analytics, or include third-party tracking
SDKs in the current Store-safe Windows build.

## Local Data

DNS Pilot stores custom DNS profiles, custom domain suites, benchmark history,
app language, and benchmark preferences locally on the user's Windows device.
This data is used only to provide app features on that device.

## Network Activity

When the user starts a benchmark, DNS Pilot sends DNS queries and optional TCP
connection probes to selected resolvers and target domains. External resolvers
and targets can observe normal network metadata such as the source IP address
and request timing under their own privacy policies.

## System DNS Changes

The Store-safe Windows build does not silently change Windows DNS. Guided Apply
copies DNS servers and opens Windows Settings so the user can make the OS-level
change. It does not request UAC, call `netsh`, or use adapter DNS mutation APIs.

## Support Contact Placeholder

Replace this section with the public privacy contact before hosting and
submitting the Store package.
