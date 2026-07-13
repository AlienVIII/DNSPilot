# DNS Pilot App Store Connect Notes

Use this as the macOS App Store metadata starting point. Replace placeholders
before upload.

## Product Identity

- App name: DNS Pilot
- Bundle ID: `com.dnspilot.mac`
- Minimum macOS: 14.0
- Category: Utilities
- Age rating: 4+

## Subtitle

DNS benchmark and guided resolver setup

## Promotional Text

Find a reliable DNS option for your current network, save domain test suites,
and follow store-safe guidance for macOS DNS changes.

## Description

DNS Pilot helps you compare DNS resolvers and connection-path estimates for
your current network. It can benchmark DNS-only behavior, DNS plus TCP connect
timing, current macOS System DNS behavior, saved domain suites, and service
targets such as Dota 2 SEA, CS2, League of Legends, YouTube, GitHub, Azure, and
ChatGPT/OpenAI.

The Mac App Store edition is store-safe. It does not silently change system DNS.
When a resolver is worth applying, DNS Pilot shows a guided workflow: copy DNS
servers, open macOS Network Settings, make the OS-level change yourself, flush or
reconnect when needed, then validate System DNS.

DNS Pilot reports fastest observed DNS separately from balanced recommendations.
It can recommend keeping current DNS when confidence is low, failures are high,
or VPN, corporate, MDM, captive portal, or weak IPv4/IPv6 conditions make a DNS
change risky.

Local data stays local: custom DNS profiles, custom domain suites, and benchmark
history are stored on the Mac.

## Keywords

DNS, resolver, benchmark, network, latency, IPv6, IPv4, gaming, developer,
Azure, GitHub

## What's New

Initial macOS release.

## Review Notes

DNS Pilot benchmarks public DNS resolvers and saved domain suites using outbound
network requests initiated by the user. The Mac App Store edition does not run
privileged helper actions and does not silently mutate system DNS.

The App Sandbox enables outgoing connections and incoming UDP response traffic.
DNS Pilot uses the latter only to receive replies on an ephemeral local UDP socket
for user-initiated direct DNS lookups; it does not run a persistent listener or
accept inbound product connections.

To review:

1. Launch the app.
2. Select Check DNS and run the default benchmark.
3. Open Options, choose DNS + TCP, then run it again.
4. Choose Dota 2 SEA, CS2, or Riot/League from Targets. Confirm the mode changes
   to DNS + TCP and the game timing disclaimer is visible.
5. Open Profiles and save a plain DNS profile.
6. Return to Check DNS and confirm the saved profile appears in candidates.
7. After a reliable result, open the guided Apply confirmation. Confirm it only
   copies DNS values and opens macOS Network Settings.
8. Use Help > Show Setup and Settings to review guided mode and switch language
   between English and Vietnamese.

Expected behavior:

- Benchmarks and game target checks show progress while running.
- Apply actions ask for confirmation and guide the user to macOS Network
  Settings; they do not silently change system DNS.
- Flush DNS in the store-safe build copies a checklist and does not execute
  administrator commands.
- Direct Admin/Power actions are outside the store path. The Store-safe build
  must not expose an in-app path to enable administrator DNS mutation; Power
  behavior is documented separately for direct-install builds.

## Privacy Notes

Suggested App Privacy answers for the current store-safe macOS build:

- Data collection: none.
- Tracking: no.
- Third-party analytics: no.
- User accounts: none.
- Local storage: custom DNS profiles, custom domain suites, and benchmark
  history are stored locally on the Mac.
- Network use: user-initiated DNS/TCP benchmark probes to selected resolvers and
  target domains.
- Bundle privacy manifest: `PrivacyInfo.xcprivacy` declares no tracking, no
  collected data types, and UserDefaults reason `CA92.1` for app-local settings.

Confirm these answers again before submission if telemetry, crash reporting,
sync, accounts, or remote catalog updates are added.

Draft page sources:

- Support page: `apps/macos/AppStoreConnect/SupportPage.md`
- Privacy policy: `apps/macos/AppStoreConnect/PrivacyPolicy.md`
- Deploy-ready static pages: `apps/macos/AppStoreConnect/site/`

Build pages with the final public email and HTTPS URL:

```bash
DNSPILOT_SUPPORT_EMAIL="support@example.com" \
DNSPILOT_SITE_URL="https://example.com/dns-pilot" \
./script/build_app_store_site.sh
```

Before submission, replace contact placeholders and host these pages at the
public support/privacy URLs used in App Store Connect.

## Screenshot Checklist

- Check DNS default state.
- Check DNS running progress with per-step status.
- Check DNS result with the single apply action and Details disclosure.
- Check DNS Dota 2 SEA target showing DNS + TCP disclaimer.
- Profiles editor with saved profile management.
- Guided apply confirmation dialog.
- Help setup sheet.
- Settings language picker.

## Manual Release Blockers

- Apple Developer account access.
- App Store Connect app record for `com.dnspilot.mac`.
- Mac App Store signing identity and provisioning profile.
- Final screenshots from a signed release candidate; use
  `apps/macos/AppStoreConnect/ScreenshotPlan.md`.
- Publicly hosted support/privacy URLs.
- Marketing URL if you choose to provide one.
- Final privacy answers in App Store Connect.
