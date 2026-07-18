# Windows QA Checklist

Record this checklist's results in
`apps/windows/windows-release-evidence-template.md`; do not mark a release
ready from a checklist without package hash and Windows-host evidence.

Capture the required signed Store-safe screenshots using
`apps/windows/PartnerCenter/ScreenshotPlan.md`, then attach their paths to the
release evidence record. Do not capture private resolver addresses or Power/admin
surfaces.

## Automated Validation Run on macOS
- `bash apps/windows/validate-windows-lane.sh`
- `dotnet build apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/DNSPilotWindows.Core.Tests.csproj`
- `apps/windows/DNSPilotWindows/tests/DNSPilotWindows.Core.Tests/bin/Debug/net8.0/DNSPilotWindows.Core.Tests`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.slnx`
- `dotnet build apps/windows/DNSPilotWindows/DNSPilotWindows.WinUI.slnx` was attempted on macOS and reached the Windows App SDK XAML compiler, then failed because `XamlCompiler.exe` is Windows-only. Re-run this on Windows.
- Automated tests cover CLI contract decoding for catalog, capabilities, apply-plan, protected-network apply suppression, benchmark results, structured recommendation reports, profile-list, suite-list, history-list, profile mutations, suite mutations, history mutations, hydrated shell state, persisted custom profile/suite merge into the benchmark catalog, resolver profile selection, domain suite selection, built-in profile/suite mutation guards, live benchmark control previews, completed resolver statuses, apply-plan request generation from recommendations, CLI helper lookup, runtime readiness, native localization resources, dynamic Vietnamese shell text, package PNG assets, README install/run/package instructions, privacy/listing docs, MSIX project/profile wiring, package manifest, and package permission template checks.

## Windows Build Validation
- Install .NET 8 SDK, Windows App SDK build tooling, and Windows SDK.
- Build the CLI helper: `cargo build --release -p dnspilot-cli`.
- For local unpackaged QA, set `DNSPILOT_CLI_PATH` or copy the helper beside `DNSPilotWindows.App.csproj`.
- Generate the Store manifest with `powershell -ExecutionPolicy Bypass -File apps\windows\Prepare-WindowsStorePackage.ps1 -IdentityName <PartnerCenterIdentity> -Publisher <PartnerCenterPublisher> -Version <x.y.z.w> -CliPath target\release\dnspilot-cli.exe`. This writes `apps\windows\DNSPilotWindows\app\DNSPilotWindows.App\Package.appxmanifest`.
- From repo root, run `powershell -ExecutionPolicy Bypass -File apps\windows\Validate-WindowsLane.ps1 -Configuration Release`.
- If running checks manually, run `dotnet build apps\windows\DNSPilotWindows\DNSPilotWindows.WinUI.slnx -c Release /p:Platform=x64 /p:GenerateAppxPackageOnBuild=true`.

## Manual Windows UI Flow
- Launch DNS Pilot.
- Confirm the only primary destinations are Check DNS, Profiles, and History.
  Apply/results stay in Check DNS, custom suites stay in Profiles, and raw report
  text appears only after expanding Advanced diagnostics.
- Resize from a wide desktop window to a narrow window; expected: Check DNS cards
  stack without overlap or clipped controls. At 200% text scaling and high
  contrast, labels/actions remain visible and status is not color-only.
- With keyboard only, use Ctrl+Q for Quick Check, Ctrl+S for Settings, and Ctrl+H
  for Help. With Narrator, confirm runtime status changes are announced.
- Before runtime contracts finish loading, confirm the runtime status shows
  Checking and benchmark/apply/storage controls are disabled without an admin
  prompt. After a successful probe, status becomes Ready.
- Temporarily point `DNSPILOT_CLI_PATH` at a missing path, then use Retry;
  expected: status becomes Degraded, the report identifies the missing helper,
  every dependent surface stays disabled, and no DNS settings are changed.
- Restore a valid env path or bundled helper and choose Retry; expected: ready
  surfaces recover without restarting the app. If profile storage alone fails,
  benchmark/apply/suites/history retain their own readiness states.
- Confirm the app launches without UAC/admin prompt.
- Change the top-right language selector to Vietnamese, close and relaunch; expected:
  the EN/VI selection persists and native labels load in the selected language.
  Change it back to English and relaunch. Verify dynamic progress, validation,
  and readiness text in each language.
- Change benchmark mode, families, numeric controls, selected profiles/suite,
  close and relaunch after runtime reaches Ready; expected: valid values restore.
  Delete a selected custom profile/suite outside the app or corrupt the LocalSettings
  preference value, relaunch; expected: DNS Pilot falls back to valid catalog defaults
  and never launches a command with stale IDs.
- Confirm Default and Vietnam suite quick picks are visible only when catalog tags
  provide those suites, and that selecting either updates the domain-suite preview.
- Expand Advanced diagnostics; expected: capability rows use Ready, Recovery
  needed, OS-gated, or Unsupported states. Copy the report and confirm it contains
  no local user path, HOME, APPDATA, or token-like environment value.
- Change benchmark mode, record family, resolver address family, and timeout controls before running; expected: command preview and idle process rows update immediately.
- Select and unselect resolver profiles in the Benchmark panel; expected: DNS-only and DNS + TCP command preview uses exactly the selected plain DNS profiles, including custom profiles loaded from `profile-list`.
- Select a domain suite in the Benchmark panel; expected: command preview uses the suite domains, including custom suites loaded from `suite-list`.
- Unselect all resolver profiles and run DNS-only or DNS + TCP; expected: benchmark is blocked with copyable diagnostics instead of launching the CLI without resolvers.
- With no resolver profiles selected, close and relaunch after runtime reaches
  Ready; expected: the deliberate empty selection remains empty and the benchmark
  stays blocked until the user explicitly selects profiles again.
- Use in-panel `Run benchmark`; expected: it runs the current command preview exactly.
- Run toolbar `Quick Check`; expected: it runs DNS-only with the first two plain
  resolver profiles, the default three-domain suite, and one attempt. It does
  not silently use the advanced DNS+TCP controls.
- Select a catalog suite tagged `gaming`; expected: the preview switches to
  DNS+TCP and displays the suite's catalog limitation notice. This is not ICMP
  ping or in-match UDP latency.
- While a benchmark is running, confirm toolbar Quick/Validate and in-panel Run
  are disabled; a tray benchmark action must not start a second run.
- While a benchmark is running, confirm Cancel is visible and Escape works.
  Expected: Cancel becomes disabled after one request, the CLI child tree exits
  within five seconds, result diagnostics say cancelled, no saved history row is
  reported, and a subsequent Quick Check can run without restarting the app.
- After successful benchmark, expected: step rows show success and resolver rows keep final success/degraded/failed details instead of reverting to idle.
- After successful benchmark, expected: recommendation summary explicitly shows
  Recommended, Fastest observed DNS, or Keep current DNS. Fastest observed is
  diagnostic only and must not be presented as an apply recommendation.
- After a successful recommendable benchmark, expected: Apply guidance refreshes
  from `apply-plan windows-store` for the recommended profile/tested resolver.
- Run toolbar `Validate DNS`; expected: it uses `system-benchmark --platform windows-store` while preserving selected A/AAAA, attempts, and DNS timeout.
- Change `Record family` to `A only` and `AAAA only`; expected: command preview uses `--ip-family ipv4-only` or `--ip-family ipv6-only`.
- Change `Resolver address` to `IPv4` and `IPv6`; expected: resolver args use matching DNS server families.
- Use `Apply in Windows Settings`; expected: a confirmation defaults to Cancel.
  After confirmation, the app copies one DNS server per line and opens Network &
  internet advanced settings, or Network status fallback. The app never writes DNS.
- After the confirmed handoff, use `Retest System DNS`; expected: it runs
  `system-benchmark --platform windows-store` against the user-saved settings.
- Toggle VPN active, Managed DNS profile, Corporate DNS, or Captive portal under
  Network safeguards; expected: the app refreshes Core `apply-plan` guidance and
  suppresses the primary Apply action when Core returns a protected disposition.
- Use `Copy DNS`; expected: clipboard contains one DNS server per line as a
  secondary action.
- Use `Copy checklist`; expected: clipboard text states no silent DNS mutation.
- Manually paste DNS servers into Windows Settings; expected: app does not perform the mutation for the user.
- Return to DNS Pilot and run `Validate DNS`; expected: current/system DNS benchmark reflects the user-applied resolver path or reports a copyable reason.
- Preview a custom DNS profile save; expected: valid profiles produce `profile-add`, invalid IPv4/IPv6 show validation errors.
- Add/update/delete a custom DNS profile; expected: no UAC prompt, profile list refreshes, the custom profile appears in Benchmark resolver profiles, and it can be selected for a run.
- Delete a custom profile; expected: a native confirmation defaults to Cancel
  and no mutation runs until Delete is confirmed.
- Select a built-in profile or type a built-in profile ID and try update/delete; expected: blocked with diagnostics before any CLI mutation call.
- Add/update/delete a custom domain suite; expected: no UAC prompt, suite list refreshes, the custom suite appears in the Benchmark domain suite picker, and it can be selected for a run.
- Enter `Example.com, example.com.`; expected: suite Preview reports a
  duplicate before invoking the CLI.
- Delete a custom suite; expected: a native confirmation defaults to Cancel.
- Select a built-in suite or type a built-in suite ID and try update/delete; expected: blocked with diagnostics before any CLI mutation call.
- Force or mock an `apply-plan` payload with `disposition=protect-current-dns`; expected: Copy DNS and Apply in Windows Settings are hidden and only the protection checklist remains copyable.
- Select a history row and delete selected; expected: the row is removed after refresh.
- Refresh storage; expected: saved profiles and history rows reload from the CLI-backed SQLite store.
- Clear history; expected: history rows empty after refresh.
- Delete/clear history; expected: each destructive action requires confirmation
  and the triggering button stays disabled until refresh finishes.
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
