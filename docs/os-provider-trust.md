# OS Provider Trust And Manual Release Steps

Last reviewed: 2026-07-19.

This is the consolidated manual-gate queue. Do not ask users to disable Gatekeeper,
Play Protect, Windows security, sandboxing, or OS permission controls. Store-safe builds
benchmark, explain, open Settings, and retest; restricted/admin mutation is a separate
artifact with consent, rollback, and provider proof.

## macOS

Goal: install and open DNSPilot without bypassing Gatekeeper.

1. Enroll in Apple Developer Program; return Team ID and available signing identities.
2. Create the macOS App Store record and bundle ID.
3. Host final support/privacy URLs and complete privacy details.
4. Run `./script/preflight_macos_release.sh --include-power`.
5. Build/sign the Store-safe app; verify sandbox entitlements and clean-Mac launch.
6. For direct Power only: sign with Developer ID, notarize, staple, then run real-network
   Apply -> Validate -> Restore after the current-state rollback guard lands.
7. Submit Store-safe and direct Power artifacts separately.

Return: Team ID, certificate/profile identity, hosted URLs, signed bundle validation,
notarization log when applicable, screenshots, and App Store review result.

Sources: <https://developer.apple.com/developer-id/>,
<https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>,
<https://developer.apple.com/app-store/app-privacy-details/>.

## iOS / iPadOS

Goal: native app needs no developer bridge; plain DNS stays guided through Settings.

1. Create the iOS App Store record, bundle ID, signing, privacy details, and hosted URLs.
2. Build the default Store profile and prove its generated/signed entitlements omit
   `com.apple.developer.networking.networkextension` DNS Settings capability.
3. Install on a physical device; test tutorial, Help, benchmark, Profiles, History,
   settings handoff, app restart, backup policy, VoiceOver, and System DNS retest.
4. Only for optional `production-ios-dns`: request/provision Apple Network Extension
   `dns-settings`, sign the artifact, install DoH/DoT settings, explicitly enable it in
   Settings, refresh status, remove, and capture review evidence.
5. Submit default Store first; do not make its release depend on optional capability.

Return: bundle/profile IDs, generated and signed entitlement dumps, physical-device
screenshots/logs, review notes, and capability approval only for the optional artifact.

Sources: <https://developer.apple.com/documentation/networkextension/dns-settings>,
<https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension>.

## Android

Goal: normal-permission Play build using Private DNS Settings guidance, not `VpnService`.

1. Create Play Console app, reserve package, and configure Play App Signing/upload key.
2. Complete Data safety, privacy URL, content, and store listing forms.
3. Build the production AAB; verify no dev-client, backup leakage, VPN, overlay, storage,
   or privileged DNS permission/service is present.
4. Install on a physical device; test tutorial, Help, benchmark, Profiles, History,
   Private DNS handoff/retest, app restart, backup policy, and TalkBack.
5. Perform first manual upload if required, then use closed testing before production.

Return: package/signing status, merged manifest evidence, Data safety answers, physical-
device proof, and Play review result.

Sources: <https://developer.android.com/studio/publish/app-signing>,
<https://support.google.com/googleplay/android-developer/answer/9842756>,
<https://support.google.com/googleplay/android-developer/answer/12564964>.

## Windows

Goal: signed MSIX install with no trust bypass and a complete no-tray workflow.

1. Create Partner Center account; reserve app name, identity, and publisher.
2. Fill package identity/version inputs and hosted support/privacy URLs.
3. On Windows run the Release validator and build/sign the MSIX with the real identity.
4. Submit the minimal `runFullTrust` justification; product must still work if tray
   approval is delayed or denied.
5. Validate clean install/upgrade/relaunch, helper discovery, tray, Settings handoff,
   EN/VI, Narrator, high contrast, VPN/firewall, and uninstall.
6. Complete Partner Center submission and attach the release evidence template.

Return: identity/publisher, validator output, signed MSIX/install proof, capability review,
screenshots/accessibility evidence, and Partner Center result.

Sources: <https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations>,
<https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/create-app-submission>.

## Linux

Goal: each package states its trust boundary; sandboxed packages never imply DNS mutation.

1. Replace local-prebuilt Flatpak input with a declared, reproducible source build.
2. Build/install/smoke Flatpak and Snap on Linux; validate confinement and metadata.
3. Build/install/smoke deb/rpm on supported distros; keep Power absent until a caller-
   bound D-Bus/polkit mechanism and exact rollback pass real-host QA.
4. Run AppStream/desktop-file validation and GNOME/KDE keyboard/screen-reader/layout QA.
5. Create Flathub/Snap publisher accounts, verify app ID/name ownership, sign distro
   packages where applicable, and submit only artifacts backed by collected evidence.

Return: immutable source/tag, package build/install logs, desktop/resolver matrix,
publisher verification, metadata output, screenshots, and store review results.

Sources: <https://docs.flathub.org/docs/for-app-authors/requirements>,
<https://docs.flathub.org/docs/for-app-authors/submission>,
<https://documentation.ubuntu.com/snapcraft/9.0/how-to/publishing/publish-a-snap/>.
