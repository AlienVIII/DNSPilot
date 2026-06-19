# Windows QA Checklist

## Automated Validation Run on macOS
- `dotnet run --project apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx` was attempted on macOS and reached the Windows App SDK XAML compiler, then failed because `XamlCompiler.exe` is Windows-only. Re-run this on Windows.

## Windows Build Validation
- Install .NET 8 SDK, Windows App SDK build tooling, and Windows SDK.
- From repo root, run `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx`.
- Set `DNSPILOT_CLI_PATH` to a built `dnspilot-cli.exe`, or place `dnspilot-cli.exe` beside the app output.

## Manual Windows UI Flow
- Launch DNS Pilot.
- Run `Quick benchmark`; expected: command preview uses `path-compare`, process rows move to running, diagnostics show success or a copyable failure report.
- Run `Validate DNS`; expected: command preview uses `system-benchmark --platform windows-store`.
- Change `Record family` to `A only` and `AAAA only`; expected: command preview uses `--ip-family ipv4-only` or `--ip-family ipv6-only`.
- Change `Resolver address` to `IPv4` and `IPv6`; expected: resolver args use matching DNS server families.
- Use `Copy DNS`; expected: clipboard contains one DNS server per line.
- Use `Open settings`; expected: Windows opens Network & internet advanced settings, or Network status fallback.
- Use `Copy checklist`; expected: clipboard text states no silent DNS mutation.
- Preview a custom DNS profile save; expected: valid profiles produce `profile-add`, invalid IPv4/IPv6 show validation errors.
- Open tray icon menu; expected: Quick benchmark, Validate current DNS, and Open Network Settings actions route to the same shell behavior.

## Store-Safe Checks
- App manifest remains `asInvoker`.
- No UAC prompt appears for benchmark, copy, open settings, profile preview, history list, or tray actions.
- No code path silently calls `netsh`, PowerShell DNS mutation, registry DNS mutation, or adapter DNS APIs.

## Known Risks
- Real Windows UI layout, tray behavior, MSIX packaging, Store policy, and signing are not validated from macOS.
- Core result JSON parsing into recommendation detail is not implemented in the Windows shell yet; process diagnostics and apply guidance are present.
- Power edition admin/service apply remains a separate future lane.
