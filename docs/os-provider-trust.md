# OS Provider Trust And Manual Release Steps

Last reviewed: 2026-07-08.

This file is the manual-gate source of truth for OS provider trust. Keep these
steps out of normal implementation prompts unless a release pass needs them.

## Product Rule

- Do not ask users to disable Gatekeeper, Play Protect, Windows security, or
  sandbox controls.
- Use provider-backed trust where available: Apple signing/notarization, App
  Store review, Google Play App Signing, Microsoft Partner Center review,
  Flathub verification, Snap Store publisher/review, and distro package QA.
- In-app permission copy should be one short title plus status. Put the longer
  explanation behind an info icon, tooltip, tutorial, or copyable report.
- Store-safe builds benchmark, explain, copy settings, open OS settings, and
  retest. Power/admin DNS mutation stays separate and explicitly gated.

## macOS

Goal: users can open DNSPilot without disabling Gatekeeper.

Manual steps:

1. Enroll or confirm access to the Apple Developer Program.
2. For Mac App Store: create the app in App Store Connect and configure bundle
   ID, signing, sandbox entitlements, privacy details, support URL, and review
   notes.
3. For direct distribution outside the Mac App Store: build with Developer ID,
   notarize the app, staple the notarization ticket, then verify Gatekeeper on a
   clean Mac.
4. Host support and privacy pages before submission.
5. Run local release checks:
   `./script/preflight_macos_release.sh --include-power`.
6. Submit App Store edition separately from Power/direct-install edition.

Provider evidence to collect:

- Apple Developer team ID.
- Developer ID Application certificate or App Store signing identity.
- Notarization success log for direct distribution.
- App Store Connect privacy details screenshot/export.
- Hosted privacy/support URLs.

Sources:

- Apple Developer ID and notarization:
  https://developer.apple.com/developer-id/
- Apple notarization before distribution:
  https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple app privacy details:
  https://developer.apple.com/app-store/app-privacy-details/
- Apple privacy manifest files:
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

## iOS / iPadOS

Goal: DNSPilot asks only for permissions it can justify and uses OS-approved
settings/profile flows.

Manual steps:

1. Use the same Apple Developer Program access as macOS.
2. Create the iOS app record in App Store Connect.
3. Configure bundle ID, signing, provisioning, app privacy details, Local
   Network usage text, and any entitlement request that is actually required.
4. Run real-device QA for Local Network, bridge LAN URL, app settings handoff,
   DNS profile/settings handoff, and System DNS retest.
5. Submit only after the release runtime decision is final: native Rust binding,
   approved backend bridge, split native shells, or developer companion.

Provider evidence to collect:

- App Store Connect app ID and bundle ID.
- Provisioning/signing proof.
- Real-device screenshots for first-open tutorial and Local Network prompt.
- Review notes explaining no silent DNS mutation.

## Android

Goal: DNSPilot stays normal-permission and Play-safe unless a future product
decision explicitly chooses VPN/service behavior.

Manual steps:

1. Create/confirm Google Play Console developer account.
2. Create Play app and reserve package name.
3. Enable/configure Play App Signing.
4. Complete Data safety and app content forms.
5. Upload the first Android build manually if Play requires it for the account.
6. Run physical Android QA for Private DNS/settings handoff, bridge URL,
   background/foreground expectations, and System DNS retest.

Provider evidence to collect:

- Play Console package name.
- Play App Signing status and upload key handling.
- Data safety answers.
- Physical-device screenshots for tutorial and settings handoff.

Sources:

- Android app signing:
  https://developer.android.com/studio/publish/app-signing
- Google Play App Signing:
  https://support.google.com/googleplay/android-developer/answer/9842756
- Google Play Data safety:
  https://support.google.com/googleplay/android-developer/answer/10787469

## Windows

Goal: users install a signed MSIX/package without manual trust bypasses.

Manual steps:

1. Create/confirm Microsoft Partner Center developer account.
2. Reserve app name and package identity.
3. Replace placeholder identity/publisher/version values in
   `apps/windows/Prepare-WindowsStorePackage.ps1` inputs.
4. Build/package on Windows with the Windows App SDK toolchain.
5. Sign package with the Store/Partner Center identity.
6. Submit restricted capability justification for `runFullTrust`.
7. Validate MSIX install, launch, tray, Settings handoff, and bundled
   `dnspilot-cli.exe` discovery on Windows.

Provider evidence to collect:

- Partner Center package identity and publisher subject.
- MSIX signing proof.
- Restricted capability approval/review notes.
- Hosted privacy/support URLs.

Sources:

- Microsoft app capability declarations:
  https://learn.microsoft.com/windows/uwp/packaging/app-capability-declarations

## Linux

Goal: each package format states its trust model and avoids pretending sandboxed
builds can mutate system DNS.

Manual steps:

1. Flatpak/Flathub: submit app, get developer portal access, verify app ID
   ownership, and keep permissions minimal.
2. Snap Store: create Snapcraft account, register snap name, publish to the
   right channel, and request review/approval for confinement exceptions only if
   needed.
3. deb/rpm: validate package metadata, polkit policy, native helper install
   paths, and distro package QA on target distros.
4. AppStream: validate metainfo so software centers show clear publisher,
   support, screenshots, and permission context.

Provider evidence to collect:

- Flathub verified app status or verification token flow.
- Snapcraft account/name/channel status.
- Package QA logs per distro.
- AppStream validation output and screenshots.

Sources:

- Flathub app verification:
  https://docs.flathub.org/docs/for-app-authors/verification
- Flatpak sandbox permissions:
  https://docs.flatpak.org/en/latest/sandbox-permissions.html
- Snapcraft publishing:
  https://documentation.ubuntu.com/snapcraft/9.0/how-to/publishing/publish-a-snap/
- AppStream metadata:
  https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html
