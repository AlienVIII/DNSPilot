# DNS Pilot macOS Publishing

This document is the source of truth for getting the macOS build from local
validation to distribution.

## Product Split

### App Store edition

- Store-safe.
- No silent system DNS mutation.
- DNS apply is guided: copy DNS, open macOS Network Settings, user confirms the
  system change.
- DNS flush is guided unless Apple-approved APIs are added later.
- Power admin actions must stay disabled.

### Power edition

- Direct install only.
- Plain DNS apply/flush can ask for administrator approval when
  the app bundle has `DNSPilotPowerActionsEnabled=true` or
  `DNSPILOT_ENABLE_POWER_ACTIONS=1`.
- Not App Store-safe as implemented today.
- Needs separate signing/review positioning and manual QA on real network
  services before distribution.

## Local Release Gate

Run before any signing or upload work:

```bash
cd /Users/aart/Projects/Desktop/dnspilot-macos
./script/preflight_macos_release.sh
```

Expected:

- Rust tests pass.
- Swift tests pass.
- The bundle validator passes.
- Local bundle warnings are only ad-hoc signing warnings.

## App Store Manual Steps

1. Confirm bundle identity and app record.
   - Current bundle id: `com.dnspilot.mac`.
   - Create/confirm the App Store Connect app record.

2. Confirm signing assets.
   - Apple Developer account membership.
   - Mac App Store distribution certificate.
   - Provisioning profile for `com.dnspilot.mac`.

3. Confirm entitlements.
   - Required now: App Sandbox and outbound network client.
   - Current template: `apps/macos/DNSPilotMac/Packaging/DNSPilotMac.entitlements`.
   - Do not include Power/admin behavior in the App Store edition.
   - If Apple NetworkExtension DNS Settings is added later, request/verify the
     entitlement before submitting.

4. Build/export a signed app bundle.
   - Use release signing, not ad-hoc signing.
   - Sign nested helper with `DNSPilotHelper.entitlements`.
   - Sign app bundle with `DNSPilotMac.entitlements`.
   - Packaging driver:

```bash
DNSPILOT_CODESIGN_IDENTITY="<app distribution signing identity>" \
DNSPILOT_INSTALLER_IDENTITY="<installer signing identity>" \
./script/package_macos_distribution.sh
```

5. Validate the signed export.

```bash
./script/validate_macos_bundle.sh /path/to/DNSPilotMac.app --distribution
```

Expected:

- No ad-hoc signature failures.
- App Sandbox entitlement present.
- Helper sandbox inheritance present.
- `LSMinimumSystemVersion` is `14.0`.

6. Prepare App Store metadata.
   - Start from `apps/macos/AppStoreConnect/README.md`.
   - Explain DNS benchmarking and connection-path estimates.
   - State that the app does not claim full internet speed improvement.
   - State that store builds do not silently change system DNS.
   - State that local profiles, suites, and benchmark history are stored locally.
   - Include VPN/MDM/corporate DNS/captive portal caveats.

7. Upload with Xcode Organizer, Transporter, or App Store Connect workflow.

8. Manual review smoke test before submit.
   - Launch app.
   - Run Benchmark with default candidates.
   - Save custom DNS.
   - Save custom domain suite.
   - Run System DNS validation.
   - Open guided apply; confirm it only copies/opens settings.
   - Confirm Flush DNS copies checklist and does not run admin commands.

## Power Edition Manual Steps

1. Build and launch Power mode locally:

```bash
DNSPILOT_POWER_EDITION=1 ./script/build_and_run.sh --sandbox-verify
```

Or include Power bundle validation in the local release gate:

```bash
./script/preflight_macos_release.sh --include-power
```

The preflight restores a Store-safe bundle after optional Power validation so
`dist/DNSPilotMac.app` is not left Power-enabled by accident.

2. Confirm UI behavior.
   - `Apply Now (Admin)` appears only in Power mode.
   - `Flush Now (Admin)` appears only in Power mode.
   - Store-safe copy/open actions remain available.

3. Package Power edition when direct-install signing assets are available:

```bash
DNSPILOT_POWER_EDITION=1 \
DNSPILOT_CODESIGN_IDENTITY="<app distribution signing identity>" \
DNSPILOT_INSTALLER_IDENTITY="<installer signing identity>" \
./script/package_macos_distribution.sh
```

4. Test admin prompt on a disposable network setup.
   - Capture current DNS first.
   - Apply a known safe resolver.
   - Run System DNS validation.
   - Restore original DNS.
   - Run System DNS validation again.

5. Do not ship Power mode as the App Store edition.

## Current Publish Blockers

- Release signing identity and provisioning profile are not present in this
  worktree.
- Final App Store screenshots, support URL, marketing URL, and Apple account
  privacy answers are not present here.
- Power edition needs real manual DNS mutation QA before public distribution.
