#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "== Windows core tests =="
dotnet run --project apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj

echo "== Windows core solution build =="
dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx

echo "== Store-safe static checks =="
manifest="apps/windows/DNSPilotWindows/app/DNSPilotWindows.App/app.manifest"
grep -q 'requestedExecutionLevel level="asInvoker"' "$manifest"

if rg -n 'netsh|Set-DnsClientServerAddress|Get-DnsClientServerAddress|Verb\s*=\s*runas|requireAdministrator|highestAvailable|HKLM|Registry|DnsClient' apps/windows/DNSPilotWindows; then
  echo "Store-safe check failed: admin or DNS mutation token found in Windows app source." >&2
  exit 1
fi

echo "== Windows App SDK build probe =="
if dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx; then
  echo "WinUI solution build passed."
else
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "WinUI build probe failed on macOS as expected: Windows App SDK XamlCompiler.exe is Windows-only."
  else
    echo "WinUI solution build failed on non-macOS host." >&2
    exit 1
  fi
fi

echo "Windows lane validation complete."
