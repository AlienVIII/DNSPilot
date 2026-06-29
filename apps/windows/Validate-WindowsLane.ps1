param(
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $content = Get-Content -Raw -Path $Path
    if ($content -notmatch [regex]::Escape($Pattern)) {
        throw $Message
    }
}

Write-Host "== Windows core tests =="
dotnet build apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj --configuration $Configuration
$testBinary = "apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/bin/$Configuration/net8.0/DNSPilotWindows.Core.Tests.exe"
if (-not (Test-Path $testBinary)) {
    $testBinary = "apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/bin/$Configuration/net8.0/DNSPilotWindows.Core.Tests"
}
if (-not (Test-Path $testBinary)) {
    throw "Missing Windows core test binary after build."
}
& $testBinary

Write-Host "== Windows core solution build =="
dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx --configuration $Configuration

Write-Host "== Store-safe static checks =="
$manifest = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/app.manifest"
Assert-Contains $manifest 'requestedExecutionLevel level="asInvoker"' "App manifest must stay asInvoker."

$unsafePattern = 'netsh|Set-DnsClientServerAddress|Get-DnsClientServerAddress|Verb\s*=\s*runas|requireAdministrator|highestAvailable|HKLM|Registry|DnsClient'
$sourceFiles = Get-ChildItem apps/windows/DNSPilotWindows/app, apps/windows/DNSPilotWindows/src -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\\(bin|obj)\\' -and
        $_.Extension -in @(".cs", ".xaml", ".csproj", ".manifest", ".template")
    }
$unsafeMatches = $sourceFiles | Select-String -Pattern $unsafePattern
if ($unsafeMatches) {
    $unsafeMatches | Format-Table -AutoSize
    throw "Store-safe check failed: admin or DNS mutation token found in Windows app source."
}

Write-Host "== Localization and packaging static checks =="
$xaml = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/MainWindow.xaml"
$en = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Strings/en-US/Resources.resw"
$vi = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Strings/vi-VN/Resources.resw"
$packageTemplate = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Packaging/Package.Store.appxmanifest.template"
$packagePrep = "apps/windows/Prepare-WindowsStorePackage.ps1"

foreach ($required in @($xaml, $en, $vi, $packageTemplate, $packagePrep)) {
    if (-not (Test-Path $required)) {
        throw "Missing required Windows lane artifact: $required"
    }
}

Assert-Contains $xaml 'x:Uid="AppTitle"' "MainWindow.xaml must declare x:Uid localization hooks."
Assert-Contains $en 'name="AppDisplayName"' "en-US resources must include AppDisplayName."
Assert-Contains $vi 'name="AppDisplayName"' "vi-VN resources must include AppDisplayName."
Assert-Contains $packageTemplate 'ms-resource:AppDisplayName' "Store package template must use localized display name."
Assert-Contains $packageTemplate 'Name="internetClient"' "Store package template must declare internetClient."
Assert-Contains $packageTemplate 'Name="runFullTrust"' "Packaged desktop app template must declare runFullTrust."
Assert-Contains $packagePrep 'Package.Store.appxmanifest.template' "Store package preparation script must read the template."
Assert-Contains $packagePrep 'Version must use four numeric parts' "Store package preparation script must validate version shape."

Write-Host "== Windows App SDK build probe =="
dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx --configuration $Configuration

Write-Host "Windows lane validation complete."
