param(
    [Parameter(Mandatory = $true)]
    [string]$SupportEmail,

    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [string]$OutputPath = "dist/partner-center-site"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$TemplateRoot = Join-Path $PSScriptRoot "PartnerCenter/site"
$DistRoot = Join-Path $RepoRoot "dist"

if ($SupportEmail -notmatch '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') {
    throw "SupportEmail must be a public email address."
}

if ($SiteUrl -notmatch '^https://[^\s<>""|]+$') {
    throw "SiteUrl must be an HTTPS URL."
}

$SiteUrl = $SiteUrl.TrimEnd('/')
$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $OutputPath))
}
$resolvedDistRoot = [System.IO.Path]::GetFullPath($DistRoot)
if (-not $resolvedOutputPath.StartsWith($resolvedDistRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputPath must remain under the repository dist directory."
}

if ($resolvedOutputPath -eq $resolvedDistRoot) {
    throw "OutputPath must name a dedicated generated site directory."
}

$outputParent = Split-Path -Parent $resolvedOutputPath
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
$stagingPath = Join-Path $outputParent ("." + [System.IO.Path]::GetFileName($resolvedOutputPath) + ".staging." + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stagingPath | Out-Null

try {
    Copy-Item (Join-Path $TemplateRoot "styles.css") (Join-Path $stagingPath "styles.css")
    foreach ($templateName in @("index.html.template", "privacy.html.template")) {
        $content = Get-Content -Raw -Path (Join-Path $TemplateRoot $templateName)
        $content = $content.Replace("{{SUPPORT_EMAIL}}", $SupportEmail).Replace("{{SITE_URL}}", $SiteUrl)
        if ($content.Contains("{{")) {
            throw "Template placeholders remain after rendering $templateName."
        }

        $destinationName = $templateName.Replace(".template", "")
        Set-Content -NoNewline -Encoding utf8 -Path (Join-Path $stagingPath $destinationName) -Value $content
    }

    if (Test-Path $resolvedOutputPath) {
        Remove-Item -Recurse -Force $resolvedOutputPath
    }

    Move-Item $stagingPath $resolvedOutputPath
    Write-Host "Partner Center support site ready: $resolvedOutputPath"
}
finally {
    if (Test-Path $stagingPath) {
        Remove-Item -Recurse -Force $stagingPath
    }
}
