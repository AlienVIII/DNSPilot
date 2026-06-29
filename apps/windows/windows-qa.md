# Windows QA Checklist

## Automated Validation Run on macOS
- `bash apps/windows/validate-windows-lane.sh`
- `dotnet build apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj`
- `apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/bin/Debug/net8.0/DNSPilotWindows.Core.Tests`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx` was attempted on macOS and reached the Windows App SDK XAML compiler, then failed because `XamlCompiler.exe` is Windows-only. Re-run this on Windows.
- Automated tests cover CLI contract decoding for catalog, capabilities, apply-plan, benchmark results, structured recommendation reports, profile-list, history-list, profile mutations, history mutations, hydrated shell state, live benchmark control previews, completed resolver statuses, apply-plan request generation from recommendations, CLI helper lookup, native localization resources, dynamic Vietnamese shell text, package PNG assets, privacy/listing docs, and package permission template checks.

## Windows Build Validation
- Install .NET 8 SDK, Windows App SDK build tooling, and Windows SDK.
- Build the CLI helper: `cargo build --release -p dnspilot-cli`.
- For local unpackaged QA, set `DNSPILOT_CLI_PATH` or copy the helper beside `DNSPilotWindows.App.csproj`.
- Generate the Store manifest with `powershell -ExecutionPolicy Bypass -File apps\windows\Prepare-WindowsStorePackage.ps1 -IdentityName <PartnerCenterIdentity> -Publisher <PartnerCenterPublisher> -Version <x.y.z.w> -CliPath target\release\dnspilot-cli.exe`.
- From repo root, run `powershell -ExecutionPolicy Bypass -File apps\windows\Validate-WindowsLane.ps1 -Configuration Release`.
- If running checks manually, run `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx -c Release`.

## Manual Windows UI Flow
- Launch DNS Pilot.
- Confirm diagnostics do not report CLI contract load failure; expected: locator finds env, bundled, release, or debug CLI path.
- Confirm the app launches without UAC/admin prompt.
- Confirm English and Vietnamese localized UI labels render by switching Windows app/display language or using the Windows language override available during QA.
- Change benchmark mode, record family, resolver address family, and timeout controls before running; expected: command preview and idle process rows update immediately.
- Use in-panel `Run benchmark`; expected: it runs the current command preview exactly.
- Run toolbar `Quick benchmark`; expected: it forces DNS + TCP quick mode while preserving selected A/AAAA, resolver address family, and numeric controls.
- After successful benchmark, expected: step rows show success and resolver rows keep final success/degraded/failed details instead of reverting to idle.
- After successful benchmark, expected: recommendation summary, resolver metric rows, notes, and diagnostics show localized health, recommendation, reasons, warning, and saved history ID when the CLI returns benchmark-result JSON.
- After a successful recommendable benchmark, expected: Apply guidance DNS servers refresh from `apply-plan windows-store` for the recommended profile/tested resolver.
- Run toolbar `Validate DNS`; expected: it uses `system-benchmark --platform windows-store` while preserving selected A/AAAA, attempts, and DNS timeout.
- Change `Record family` to `A only` and `AAAA only`; expected: command preview uses `--ip-family ipv4-only` or `--ip-family ipv6-only`.
- Change `Resolver address` to `IPv4` and `IPv6`; expected: resolver args use matching DNS server families.
- Use `Copy DNS`; expected: clipboard contains one DNS server per line.
- Use `Open settings`; expected: Windows opens Network & internet advanced settings, or Network status fallback.
- Use `Copy checklist`; expected: clipboard text states no silent DNS mutation.
- Manually paste DNS servers into Windows Settings; expected: app does not perform the mutation for the user.
- Return to DNS Pilot and run `Validate DNS`; expected: current/system DNS benchmark reflects the user-applied resolver path or reports a copyable reason.
- Preview a custom DNS profile save; expected: valid profiles produce `profile-add`, invalid IPv4/IPv6 show validation errors.
- Add/update/delete a custom DNS profile; expected: no UAC prompt, profile list refreshes, built-in profiles are not mutated by the app.
- Select a built-in profile and try update/delete; expected: blocked with diagnostics, no CLI mutation call succeeds.
- Select a history row and delete selected; expected: the row is removed after refresh.
- Refresh storage; expected: saved profiles and history rows reload from the CLI-backed SQLite store.
- Clear history; expected: history rows empty after refresh.
- Open tray icon menu; expected: Quick benchmark, Validate current DNS, and Open Network Settings actions route to the same shell behavior.
- Package/install MSIX; expected: packaged app launches, tray actions still work, and bundled `dnspilot-cli.exe` is found without setting `DNSPILOT_CLI_PATH`.

## Store-Safe Checks
- App manifest remains `asInvoker`.
- No UAC prompt appears for benchmark, copy, open settings, profile preview, history list, or tray actions.
- No code path silently calls `netsh`, PowerShell DNS mutation, registry DNS mutation, or adapter DNS APIs.
- Store package template declares only the required native capabilities for this lane: `internetClient` and `runFullTrust`.

## Known Risks
- Real Windows UI layout, tray behavior, MSIX packaging, Store policy, and signing are not validated from macOS.
- Recommendation summary/resolver metric UI is implemented, but final spacing and wrapping still require real WinUI layout QA.
- Free-text notes/errors returned by the CLI may still be English until CLI payloads expose localized display strings or stable message IDs.
- Power edition admin/service apply remains a separate future lane.
