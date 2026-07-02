param(
    [Parameter(Mandatory = $true)]
    [string]$IdentityName,

    [Parameter(Mandatory = $true)]
    [string]$Publisher,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$PublisherDisplayName = "DNS Pilot",
    [string]$CliPath = "",
    [string]$OutputPath = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Package.appxmanifest"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

$templatePath = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Packaging/Package.Store.appxmanifest.template"
$appProjectRoot = "apps/windows/DNSPilotWindows/app/DNSPilotWindows.App"
$bundledCliPath = Join-Path $appProjectRoot "dnspilot-cli.exe"

if ($IdentityName.Trim().Length -eq 0) {
    throw "IdentityName is required."
}

if ($Publisher.Trim().Length -eq 0 -or $Publisher -eq "CN=REPLACE_WITH_PARTNER_CENTER_PUBLISHER") {
    throw "Publisher must be the Partner Center publisher subject, for example CN=Contoso LLC."
}

if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "Version must use four numeric parts, for example 1.0.0.0."
}

if (-not (Test-Path $templatePath)) {
    throw "Missing Store package template: $templatePath"
}

if ($CliPath.Trim().Length -gt 0) {
    if (-not (Test-Path $CliPath)) {
        throw "CLI helper not found: $CliPath"
    }

    Copy-Item $CliPath $bundledCliPath -Force
    Write-Host "Copied CLI helper to $bundledCliPath"
}
elseif (-not (Test-Path $bundledCliPath)) {
    Write-Warning "dnspilot-cli.exe is not bundled yet. Build it and copy it beside DNSPilotWindows.App.csproj before packaging."
}

[xml]$manifest = Get-Content -Raw -Path $templatePath
$manifest.Package.Identity.Name = $IdentityName
$manifest.Package.Identity.Publisher = $Publisher
$manifest.Package.Identity.Version = $Version
$manifest.Package.Properties.PublisherDisplayName = $PublisherDisplayName

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
}
else {
    Join-Path (Get-Location) $OutputPath
}

$manifest.Save($resolvedOutputPath)
$generated = Get-Content -Raw -Path $resolvedOutputPath

if ($generated -match 'REPLACE_WITH_PARTNER_CENTER_PUBLISHER') {
    throw "Generated manifest still contains the Partner Center publisher placeholder."
}

Write-Host "Generated Store package manifest: $resolvedOutputPath"
