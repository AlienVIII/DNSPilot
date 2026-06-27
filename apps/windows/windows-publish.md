# Windows Publish Runbook

## BLUF
- Store build stays `asInvoker`: no UAC, no silent DNS mutation, no adapter write API.
- Native permissions are declared in the MSIX package template: `internetClient` plus `runFullTrust` for packaged desktop/WinUI + bundled CLI/tray.
- Remaining publish work requires a real Windows machine, Microsoft Store/Partner Center access, signing identity, and final asset approval/branding decision.

## Microsoft References
- App capabilities and restricted capability review: https://learn.microsoft.com/en-us/windows/uwp/packaging/app-capability-declarations
- Localized `.resw`, `x:Uid`, and `ms-resource` manifest strings: https://learn.microsoft.com/en-us/windows/uwp/app-resources/localize-strings-ui-manifest
- Windows Settings URI list, including `ms-settings:network-advancedsettings`: https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings

## Native Permission Position
- `app.manifest` stays `requestedExecutionLevel level="asInvoker"`.
- Store-safe app can benchmark network paths and open Settings, but it does not call `netsh`, `DnsClient`, registry DNS writes, or admin elevation.
- MSIX template declares `internetClient` because benchmarks perform DNS/network checks.
- MSIX template declares `runFullTrust` because this is a packaged desktop app with a WinUI shell, tray host, and bundled CLI helper.
- Partner Center restricted capability justification:
  - DNS Pilot runs as a normal user at medium integrity.
  - `runFullTrust` is used for the packaged desktop shell/helper process boundary and tray quick actions.
  - The Store edition never changes system DNS silently and never requests UAC.
  - DNS changes are user-mediated: copy DNS servers, open Windows Network Settings, user applies manually, then validates with System DNS benchmark.

## Prepare Windows Machine
1. Install Visual Studio 2022 or Build Tools with .NET desktop build tools, Windows App SDK tooling, and Windows 10/11 SDK.
2. Install .NET 8 SDK.
3. Install Rust stable if building `dnspilot-cli.exe` locally.
4. Confirm `dotnet --info`, `cargo --version`, and `pwsh --version` work.

## Build Helper
From repo root on Windows:

```powershell
cargo build --release -p dnspilot-cli
Copy-Item target\release\dnspilot-cli.exe apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\dnspilot-cli.exe -Force
```

The app project copies `dnspilot-cli.exe` to output when that file exists beside `DNSPilotWindows.App.csproj`.

## Validate Before Manual QA
From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File apps\windows\Validate-WindowsLane.ps1 -Configuration Release
```

Expected:
- 22 Windows core tests pass.
- Core solution builds.
- Store-safe static scan passes.
- Localization and package template checks pass.
- WinUI solution builds on Windows.

## Manual Real-Device QA
Run `apps/windows/windows-qa.md` end to end. Minimum release gate:
- Launch app without UAC.
- Confirm English and Vietnamese resource smoke by switching Windows display/app language or by forcing app language during QA if available.
- Run Quick benchmark.
- Run Validate DNS.
- Confirm successful benchmark refreshes Apply guidance.
- Copy DNS servers.
- Open Windows Network Settings.
- Manually set DNS in Windows Settings.
- Return to DNS Pilot and validate current/system DNS.
- Add, update, and delete a custom DNS profile.
- Refresh, delete selected, and clear history.
- Test tray quick benchmark, validate DNS, and open settings actions.
- Confirm no silent DNS mutation happened before the manual Windows Settings step.

## Package Assets
Baseline PNG assets are already present at:

- `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Assets\StoreLogo.png`
- `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Assets\Square44x44Logo.png`
- `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Assets\Square150x150Logo.png`
- `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Assets\Wide310x150Logo.png`
- `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Assets\SplashScreen.png`

Replace them only if final branding changes. Then copy
`Packaging\Package.Store.appxmanifest.template` to the real package manifest
used by Visual Studio/MSIX packaging and replace:
- `Identity Name`
- `Publisher`
- `Version`
- asset paths if branding files differ

## Store Submission Notes
- Include a privacy policy. DNS Pilot sends DNS queries and TCP probes to selected resolvers/domains and stores profile/history data locally.
- In Partner Center, disclose `runFullTrust` and explain the Store-safe boundary.
- Do not describe the Store build as one-click DNS apply. Correct wording: benchmark, copy guidance, open Windows settings, validate current DNS.
- Keep Power edition/admin-service wording out of Store screenshots and descriptions unless published as a separate SKU/distribution.

## Final Publish Gate
Only publish after all are true:
- `Validate-WindowsLane.ps1 -Configuration Release` passes on Windows.
- Manual QA checklist passes on a real Windows device.
- MSIX package installs, launches, and finds bundled `dnspilot-cli.exe`.
- Store capability declarations are accepted or explicitly approved.
- Signing and Partner Center identity match the package manifest.
