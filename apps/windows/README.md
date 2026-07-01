# DNS Pilot Windows

Store-safe Windows shell for DNS Pilot. This lane benchmarks DNS resolvers,
shows recommendation diagnostics, guides manual DNS apply through Windows
Settings, manages custom DNS profiles/history, and exposes tray quick actions.

The Microsoft Store build must stay normal-user only: no UAC prompt, no silent DNS mutation, no `netsh`, no `DnsClient` adapter writes, and no registry DNS writes. Power/admin apply belongs in a separate edition.

## Requirements

- Windows 10/11 x64.
- Visual Studio 2022 or Build Tools with .NET desktop build tools, Windows App
  SDK tooling, and a Windows 10/11 SDK.
- .NET 8 SDK.
- Rust stable when building `dnspilot-cli.exe` locally.
- PowerShell 5+ or PowerShell 7+.

macOS can run core/view-model validation, but it cannot build the WinUI app
because the Windows App SDK XAML compiler is Windows-only.

## Install Dependencies

From the repository root:

```powershell
dotnet restore apps\windows\DNSPilotWindows\DNSPilotWindows.slnx
dotnet restore apps\windows\DNSPilotWindows\DNSPilotWindows.WinUI.slnx
cargo build --release -p dnspilot-cli
```

For local app runs, either set `DNSPILOT_CLI_PATH`:

```powershell
$env:DNSPILOT_CLI_PATH = (Resolve-Path target\release\dnspilot-cli.exe)
```

or copy the helper beside the WinUI app project:

```powershell
Copy-Item target\release\dnspilot-cli.exe apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\dnspilot-cli.exe -Force
```

## Validate

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File apps\windows\Validate-WindowsLane.ps1 -Configuration Release
```

On macOS/Linux for core checks:

```bash
bash apps/windows/validate-windows-lane.sh
```

Expected macOS behavior: core tests and static checks pass; the WinUI build
probe reaches `XamlCompiler.exe` and is reported as Windows-only.

## Run The App

On Windows after building or exposing `dnspilot-cli.exe`:

```powershell
dotnet build apps\windows\DNSPilotWindows\DNSPilotWindows.WinUI.slnx -c Debug /p:Platform=x64
dotnet run --project apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\DNSPilotWindows.App.csproj -c Debug /p:Platform=x64
```

If launching from Visual Studio, use the `MsixPackage` launch profile.

Manual smoke flow:

1. Launch DNS Pilot and confirm no UAC prompt appears.
2. Run Quick benchmark.
3. Add a custom DNS profile and select it in Benchmark resolver profiles.
4. Run DNS-only or DNS + TCP and confirm diagnostics/recommendation populate.
5. Copy DNS servers, open Windows Network Settings, apply manually, then run
   Validate DNS.
6. Test tray actions: Quick benchmark, Validate current DNS, Open settings.

## Build Store Package

Generate the Store manifest and bundle the helper:

```powershell
powershell -ExecutionPolicy Bypass -File apps\windows\Prepare-WindowsStorePackage.ps1 `
  -IdentityName "<PartnerCenterIdentity>" `
  -Publisher "<PartnerCenterPublisher>" `
  -Version "1.0.0.0" `
  -CliPath "target\release\dnspilot-cli.exe"
```

Build the MSIX package:

```powershell
dotnet build apps\windows\DNSPilotWindows\DNSPilotWindows.WinUI.slnx -c Release /p:Platform=x64 /p:GenerateAppxPackageOnBuild=true
```

Follow `windows-qa.md` for real-device QA and `windows-publish.md` for Partner
Center, signing, privacy, Store listing, and restricted capability notes.

## Package Updates

Check Windows NuGet package drift from the repository root:

```powershell
dotnet list apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\DNSPilotWindows.App.csproj package --outdated
dotnet list apps\windows\DNSPilotWindows\src\DNSPilotWindows.Core\DNSPilotWindows.Core.csproj package --outdated
dotnet list apps\windows\DNSPilotWindows\tests\DNSPilotWindows.Core.Tests\DNSPilotWindows.Core.Tests.csproj package --outdated
```

After any package update, run the validation commands above before committing.
