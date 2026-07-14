# Windows Release Evidence Template

Copy this file into the release record for each candidate. Mark `PASS`, `FAIL`,
or `NOT RUN`; attach a screenshot, log, or package hash for every `PASS`.

## Release Metadata

- Date/time (UTC):
- Tester and Windows device/version/architecture:
- DNS Pilot commit:
- MSIX identity/version:
- CLI helper version and SHA-256:
- MSIX path and SHA-256:
- Package source: local sideload / Partner Center flight:

## Build And Package

- [ ] `cargo build --release -p dnspilot-cli` succeeds.
- [ ] `Prepare-WindowsStorePackage.ps1` succeeds with the real identity,
  publisher, version, and helper path.
- [ ] `Validate-WindowsLane.ps1 -Configuration Release` passes.
- [ ] Release MSIX build succeeds with `GenerateAppxPackageOnBuild=true`.
- [ ] Evidence: command logs and package hash.

## Package Install And Helper Smoke

- [ ] Clean-install MSIX succeeds and launches without UAC.
- [ ] Bundled `dnspilot-cli.exe` is discovered without `DNSPILOT_CLI_PATH`.
- [ ] Runtime readiness reaches Ready; missing-helper Retry recovers after the
  helper is restored.
- [ ] Upgrade preserves valid preferences/history; uninstall/reinstall has the
  expected clean-state behavior.
- [ ] Evidence: launch screenshots, runtime report, and install/upgrade notes.

## Store-Safe Workflow

- [ ] Quick Check is DNS-only, bounded, and does not use gaming targets.
- [ ] Run benchmark, cancellation, failure diagnostics, and history behavior
  match `windows-qa.md`.
- [ ] Recommended/Fastest observed/Keep current remain distinct.
- [ ] Confirmed Apply copies DNS and opens Settings only; no silent DNS change,
  elevation, `netsh`, or adapter write occurs.
- [ ] System DNS retest completes after a user-mediated Settings change.
- [ ] VPN, managed, corporate, and captive safeguards suppress the primary CTA.
- [ ] Evidence: screenshots, copied report sample with redaction verified.

## Accessibility And Localization

- [ ] Narrow/wide, 200% scaling, high contrast: no overlap or clipped controls.
- [ ] Keyboard Ctrl+Q, Ctrl+S, Ctrl+H, and Escape behave as documented.
- [ ] Narrator announces runtime/progress state without color-only meaning.
- [ ] EN and VI restart persistence renders resources and dynamic status text.
- [ ] Capability rows and diagnostics are legible; copied reports have no user
  paths, HOME/APPDATA values, or secret-like local environment values.
- [ ] Evidence: screenshots or recordings and Narrator notes.

## Tray And Network Conditions

- [ ] Toolbar workflow remains complete with tray disabled/unavailable.
- [ ] If tray is retained, its Quick Check, Validate DNS, and Settings actions
  route to the same shell behavior in packaged MSIX.
- [ ] Offline, firewall-denied, VPN, captive portal, and malformed Core payload
  cases show recovery diagnostics without a DNS mutation or crash.
- [ ] Evidence: case-by-case result and log location.

## Store Submission

- [ ] Partner Center identity/publisher matches the generated manifest.
- [ ] Signing certificate or Partner Center signing flow is verified.
- [ ] Public privacy, support, and website URLs resolve.
- [ ] Listing text and screenshots state manual Settings apply, not one-click DNS.
- [ ] `runFullTrust` restricted-capability justification is submitted/accepted.
- [ ] Submission/flight link and certification result:

## Final Decision

- Release status: `GO` / `NO-GO`
- Open defects and owner:
- Exceptions approved by:
- Evidence location:
