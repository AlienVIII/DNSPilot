#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "== Windows core tests =="
dotnet build apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj
test_binary="apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/bin/Debug/net8.0/DNSPilotWindows.Core.Tests"
if [[ ! -x "$test_binary" ]]; then
  test_binary="${test_binary}.exe"
fi
"$test_binary"

echo "== Windows core solution build =="
dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx

echo "== Store-safe static checks =="
manifest="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/app.manifest"
grep -q 'requestedExecutionLevel level="asInvoker"' "$manifest"

if rg -n 'netsh|Set-DnsClientServerAddress|Get-DnsClientServerAddress|Verb\s*=\s*runas|requireAdministrator|highestAvailable|HKLM|Registry|DnsClient' \
  apps/windows/DNSPilotWindows/app \
  apps/windows/DNSPilotWindows/src \
  --glob '!**/bin/**' \
  --glob '!**/obj/**'; then
  echo "Store-safe check failed: admin or DNS mutation token found in Windows app source." >&2
  exit 1
fi

echo "== Localization and packaging static checks =="
xaml="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/MainWindow.xaml"
en_resw="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Strings/en-US/Resources.resw"
vi_resw="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Strings/vi-VN/Resources.resw"
package_template="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Packaging/Package.Store.appxmanifest.template"
package_manifest="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Package.appxmanifest"
package_prep="apps/windows/Prepare-WindowsStorePackage.ps1"
app_project="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/DNSPilotWindows.App.csproj"
launch_settings="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Properties/launchSettings.json"
publish_profile="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/Properties/PublishProfiles/win10-x64.pubxml"

for required in "$xaml" "$en_resw" "$vi_resw" "$package_template" "$package_manifest" "$package_prep" "$app_project" "$launch_settings" "$publish_profile"; do
  test -f "$required"
done

grep -q 'x:Uid="AppTitle"' "$xaml"
grep -q 'name="AppDisplayName"' "$en_resw"
grep -q 'name="AppDisplayName"' "$vi_resw"
grep -q 'ms-resource:AppDisplayName' "$package_template"
grep -q 'Name="internetClient"' "$package_template"
grep -q 'Name="runFullTrust"' "$package_template"
grep -q 'ms-resource:AppDisplayName' "$package_manifest"
grep -q 'Name="DNSPilot.Windows.Store"' "$package_manifest"
grep -q 'Name="internetClient"' "$package_manifest"
grep -q 'Name="runFullTrust"' "$package_manifest"
grep -q '<EnableMsixTooling>true</EnableMsixTooling>' "$app_project"
grep -q '<EnableDefaultPriItems>false</EnableDefaultPriItems>' "$app_project"
grep -q 'Properties\\PublishProfiles\\win10-$(Platform).pubxml' "$app_project"
grep -q '"commandName": "MsixPackage"' "$launch_settings"
grep -q '<GenerateAppxPackageOnBuild>true</GenerateAppxPackageOnBuild>' "$publish_profile"
grep -q '<AppxPackageSigningEnabled>false</AppxPackageSigningEnabled>' "$publish_profile"
grep -q 'Package.Store.appxmanifest.template' "$package_prep"
grep -q 'Package.appxmanifest' "$package_prep"
grep -q 'Version must use four numeric parts' "$package_prep"

echo "== Windows App SDK build probe =="
winui_build_log="$(mktemp)"
trap 'rm -f "$winui_build_log"' EXIT
if dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx 2>&1 | tee "$winui_build_log"; then
  echo "WinUI solution build passed."
else
  if [[ "$(uname -s)" == "Darwin" ]] && rg -q 'XamlCompiler\.exe: (cannot execute binary file|Bad CPU type in executable)' "$winui_build_log"; then
    echo "WinUI build probe failed on macOS as expected: Windows App SDK XamlCompiler.exe is Windows-only."
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "WinUI build failed for a reason other than the Windows-only XAML compiler." >&2
    exit 1
  else
    echo "WinUI solution build failed on non-macOS host." >&2
    exit 1
  fi
fi

echo "Windows lane validation complete."
