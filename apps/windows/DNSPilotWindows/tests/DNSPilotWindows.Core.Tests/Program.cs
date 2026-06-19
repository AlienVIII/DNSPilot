using DNSPilotWindows.Core;

var tests = new WindowsCoreTestSuite();
tests.RunAll();

internal sealed class WindowsCoreTestSuite
{
    private int _passed;

    public void RunAll()
    {
        Run("DNS only benchmark builds compare command with record-family controls", DnsOnlyBenchmarkBuildsCompareCommand);
        Run("DNS plus TCP benchmark builds path-compare command with TCP controls", DnsPlusTcpBenchmarkBuildsPathCompareCommand);
        Run("System DNS validation uses windows-store platform without resolver mutation", SystemDnsValidationUsesWindowsStorePlatform);
        Run("Resolver address-family control filters IPv4 and IPv6 resolver addresses", ResolverAddressFamilyFiltersResolverAddresses);
        Run("Benchmark progress shows per-step and per-resolver status with failure report", BenchmarkProgressShowsStatusesAndFailureReport);
        Run("Store apply guidance only copies DNS servers and opens Windows settings", StoreApplyGuidanceIsCopyAndSettingsOnly);
        Run("Custom DNS profile form validates addresses and builds storage commands", CustomDnsProfileFormBuildsStorageCommands);
        Run("Tray quick actions expose quick benchmark, system validation, and settings handoff", TrayQuickActionsExposeStoreSafeCommands);
        Run("History persistence appends save args and exposes management commands", HistoryPersistenceBuildsSaveAndManagementCommands);
        Run("Windows capability policy separates Store-safe shell from Power edition", WindowsCapabilityPolicySeparatesStoreAndPower);
        Run("Windows shell state exposes benchmark, apply, profile, history, and tray surfaces", WindowsShellStateExposesStoreSafeSurfaces);
        Run("Benchmark runner validates plan, appends progress and history args, and reports process failure", BenchmarkRunnerBuildsProcessBoundary);

        Console.WriteLine($"Passed {_passed} Windows core tests.");
    }

    private void Run(string name, Action test)
    {
        try
        {
            test();
            _passed++;
            Console.WriteLine($"PASS {name}");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"FAIL {name}");
            Console.Error.WriteLine(ex);
            Environment.ExitCode = 1;
            throw;
        }
    }

    private static void DnsOnlyBenchmarkBuildsCompareCommand()
    {
        var plan = TestData.Plan(mode: BenchmarkMode.DnsOnly);

        Assert.Equal(BenchmarkValidation.Valid, plan.Validation);
        Assert.SequenceEqual(
            new[]
            {
                "compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--resolver", "google=8.8.8.8:53",
                "--domain", "github.com",
                "--domain", "microsoft.com",
                "--domain", "example.com",
                "--attempts", "2",
                "--ip-family", "both",
                "--timeout-ms", "750",
            },
            plan.CommandArguments);
        Assert.Equal("DNS only", plan.Mode.DisplayLabel);
        Assert.Contains("AAAA", DnsRecordFamily.Both.HelpText);
    }

    private static void DnsPlusTcpBenchmarkBuildsPathCompareCommand()
    {
        var plan = TestData.Plan(
            mode: BenchmarkMode.DnsAndTcp,
            recordFamily: DnsRecordFamily.Ipv4Only,
            dnsTimeoutMs: 700,
            connectTimeoutMs: 1_200,
            maxConnectTargetsPerDomain: 3);

        Assert.SequenceEqual(
            new[]
            {
                "path-compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--resolver", "google=8.8.8.8:53",
                "--domain", "github.com",
                "--domain", "microsoft.com",
                "--domain", "example.com",
                "--attempts", "2",
                "--ip-family", "ipv4-only",
                "--dns-timeout-ms", "700",
                "--connect-timeout-ms", "1200",
                "--max-connect-targets-per-domain", "3",
            },
            plan.CommandArguments);
        Assert.Equal("DNS + TCP", plan.Mode.DisplayLabel);
        Assert.Contains("TCP", plan.Mode.HelpText);
    }

    private static void SystemDnsValidationUsesWindowsStorePlatform()
    {
        var plan = TestData.Plan(
            mode: BenchmarkMode.SystemDnsValidation,
            selectedProfileIds: Array.Empty<string>(),
            recordFamily: DnsRecordFamily.Ipv6Only);

        Assert.Equal(BenchmarkValidation.Valid, plan.Validation);
        Assert.SequenceEqual(
            new[]
            {
                "system-benchmark",
                "--platform", "windows-store",
                "--domain", "github.com",
                "--domain", "microsoft.com",
                "--domain", "example.com",
                "--attempts", "2",
                "--ip-family", "ipv6-only",
                "--timeout-ms", "750",
            },
            plan.CommandArguments);
        Assert.DoesNotContain("resolver", string.Join(" ", plan.CommandArguments));
    }

    private static void ResolverAddressFamilyFiltersResolverAddresses()
    {
        var ipv6Plan = TestData.Plan(
            mode: BenchmarkMode.DnsOnly,
            selectedProfileIds: new[] { "cloudflare" },
            resolverAddressFamily: ResolverAddressFamily.Ipv6Only);
        var ipv4Plan = TestData.Plan(
            mode: BenchmarkMode.DnsOnly,
            selectedProfileIds: new[] { "v6only" },
            resolverAddressFamily: ResolverAddressFamily.Ipv4Only);

        Assert.SequenceEqual(
            new[] { "compare", "--resolver", "cloudflare=[2606:4700:4700::1111]:53", "--domain", "github.com", "--domain", "microsoft.com", "--domain", "example.com", "--attempts", "2", "--ip-family", "both", "--timeout-ms", "750" },
            ipv6Plan.CommandArguments);
        Assert.Contains("Select at least one plain DNS profile with IPv4 resolver.", string.Join("\n", ipv4Plan.Validation.Issues));
    }

    private static void BenchmarkProgressShowsStatusesAndFailureReport()
    {
        var summary = TestData.Plan(mode: BenchmarkMode.DnsAndTcp).ProgressSummary;
        var running = BenchmarkProgressViewModel.From(
            BenchmarkMode.DnsAndTcp,
            BenchmarkRunState.Running,
            summary,
            progressEvents: new[]
            {
                new BenchmarkProgressEvent(ProgressEventType.ResolverStarted, "cloudflare", "1.1.1.1:53", 1, 2),
                new BenchmarkProgressEvent(ProgressEventType.ResolverFinished, "cloudflare", "1.1.1.1:53", 1, 2, ProgressEventStatus.Success, 0, 82),
            });

        Assert.Equal(ProgressStatus.Running, running.Steps.Single(step => step.Id == BenchmarkFailureStep.ResolvingDns.Id).Status);
        Assert.Equal(ProgressStatus.Success, running.ResolverStatuses.Single(row => row.Id == "cloudflare").Status);
        Assert.Equal(ProgressStatus.Idle, running.ResolverStatuses.Single(row => row.Id == "google").Status);
        Assert.Contains("Current", string.Join("\n", running.CurrentStepLines));

        var failure = new BenchmarkExecutionFailure(
            BenchmarkFailureStep.MeasuringConnection,
            "TCP probes timed out",
            elapsed: TimeSpan.FromMilliseconds(1530),
            debugLog: "path-compare --resolver cloudflare=1.1.1.1:53\nstderr: timeout");
        var failed = BenchmarkProgressViewModel.From(BenchmarkMode.DnsAndTcp, BenchmarkRunState.Completed, summary, failure: failure);

        Assert.Equal(ProgressStatus.Failed, failed.Steps.Single(step => step.Id == BenchmarkFailureStep.MeasuringConnection.Id).Status);
        Assert.Contains("Failed at: Measuring TCP", failure.CopyableReport("DNS + TCP"));
        Assert.Contains("Elapsed: 1530 ms", failure.CopyableReport("DNS + TCP"));
        Assert.Contains("Debug log:", failure.CopyableReport("DNS + TCP"));
    }

    private static void StoreApplyGuidanceIsCopyAndSettingsOnly()
    {
        var guidance = ApplyGuidanceViewModel.FromPlan(
            new ApplyPlan(
                ApplyDecision.Guide,
                "Cloudflare",
                new[] { "1.1.1.1", "1.0.0.1" },
                "1.1.1.1:53",
                "Copy these DNS servers, then paste them in Windows Settings."));

        Assert.Equal("ms-settings:network-advancedsettings", guidance.OpenSettingsUri.PrimaryUri);
        Assert.Equal("ms-settings:network-status", guidance.OpenSettingsUri.FallbackUri);
        Assert.SequenceEqual(new[] { ApplyActionKind.CopyDnsServers, ApplyActionKind.OpenWindowsSettings, ApplyActionKind.CopyChecklist }, guidance.Actions.Select(action => action.Kind));
        Assert.DoesNotContain(ApplyActionKind.MutateSystemDns.ToString(), string.Join(" ", guidance.Actions.Select(action => action.Kind)));
        Assert.Equal("1.1.1.1\r\n1.0.0.1", guidance.CopyableDnsServers);
        Assert.Contains("No silent DNS mutation", guidance.CopyableChecklist);
    }

    private static void CustomDnsProfileFormBuildsStorageCommands()
    {
        var form = new CustomDnsProfileFormViewModel(
            name: "  Cloudflare Lab  ",
            ipv4Servers: "1.1.1.1, 1.0.0.1",
            ipv6Servers: "2606:4700:4700::1111",
            filtering: DnsFiltering.Security,
            tags: "lab,fast");

        Assert.True(form.Validation.CanSave, "Expected valid profile form.");
        Assert.Equal("cloudflare-lab", form.ProfileId);
        Assert.SequenceEqual(
            new[] { "profile-add", "--db", @"C:\Users\aart\AppData\Local\DNSPilot\dnspilot.sqlite", "--id", "cloudflare-lab", "--name", "Cloudflare Lab", "--protocol", "plain", "--ipv4", "1.1.1.1", "--ipv4", "1.0.0.1", "--ipv6", "2606:4700:4700::1111", "--filtering", "security", "--tag", "lab", "--tag", "fast" },
            form.AddCommandArguments(@"C:\Users\aart\AppData\Local\DNSPilot\dnspilot.sqlite"));
        Assert.SequenceEqual(
            new[] { "profile-update", "--db", "profiles.sqlite", "--id", "existing-id", "--name", "Cloudflare Lab", "--protocol", "plain", "--ipv4", "1.1.1.1", "--ipv4", "1.0.0.1", "--ipv6", "2606:4700:4700::1111", "--filtering", "security", "--tag", "lab", "--tag", "fast" },
            form.UpdateCommandArguments("profiles.sqlite", "existing-id"));
        Assert.SequenceEqual(
            new[] { "profile-delete", "--db", "profiles.sqlite", "--id", "existing-id" },
            ProfileManagementCommands.Delete("profiles.sqlite", "existing-id"));

        var invalid = new CustomDnsProfileFormViewModel("Broken", "999.1.1.1", "not:ipv6");
        Assert.False(invalid.Validation.CanSave, "Expected invalid profile form.");
        Assert.Contains("Invalid IPv4 DNS server: 999.1.1.1", string.Join("\n", invalid.Validation.Issues));
        Assert.Contains("Invalid IPv6 DNS server: not:ipv6", string.Join("\n", invalid.Validation.Issues));
    }

    private static void TrayQuickActionsExposeStoreSafeCommands()
    {
        var tray = TrayQuickActionsViewModel.CreateDefault(TestData.Catalog);

        Assert.SequenceEqual(
            new[] { TrayActionKind.QuickBenchmark, TrayActionKind.ValidateSystemDns, TrayActionKind.OpenSettings },
            tray.Actions.Select(action => action.Kind));
        Assert.Equal(BenchmarkMode.DnsAndTcp, tray.QuickBenchmarkPlan.Mode);
        Assert.Contains("microsoft.com", string.Join(" ", tray.QuickBenchmarkPlan.CommandArguments));
        Assert.Equal("system-benchmark", tray.ValidateSystemDnsPlan.CommandArguments.First());
        Assert.Equal("ms-settings:network-advancedsettings", tray.OpenSettingsUri.PrimaryUri);
    }

    private static void HistoryPersistenceBuildsSaveAndManagementCommands()
    {
        var save = new BenchmarkHistoryPersistence("profiles.sqlite", "win-run-001");

        Assert.SequenceEqual(new[] { "--save-db", "profiles.sqlite", "--history-id", "win-run-001" }, save.CommandArguments);
        Assert.SequenceEqual(new[] { "history-list", "--db", "profiles.sqlite" }, HistoryManagementCommands.List("profiles.sqlite"));
        Assert.SequenceEqual(new[] { "history-delete", "--db", "profiles.sqlite", "--history-id", "win-run-001" }, HistoryManagementCommands.Delete("profiles.sqlite", "win-run-001"));
        Assert.SequenceEqual(new[] { "history-clear", "--db", "profiles.sqlite" }, HistoryManagementCommands.Clear("profiles.sqlite"));
    }

    private static void WindowsCapabilityPolicySeparatesStoreAndPower()
    {
        var store = WindowsCapabilityPolicy.StoreSafe;
        var power = WindowsCapabilityPolicy.PowerEdition;

        Assert.False(store.CanMutateSystemDns, "Store build must not mutate DNS.");
        Assert.False(store.RequiresAdministrator, "Store build must not require UAC/admin.");
        Assert.True(store.CanCopyDnsServers, "Store build should support copy guidance.");
        Assert.True(store.CanOpenNetworkSettings, "Store build should support settings handoff.");
        Assert.True(power.CanMutateSystemDns, "Power edition can plan admin DNS mutation separately.");
        Assert.True(power.RequiresAdministrator, "Power edition must be explicit about admin requirement.");
    }

    private static void WindowsShellStateExposesStoreSafeSurfaces()
    {
        var shell = WindowsShellViewModel.CreateDefault(@"C:\Users\aart\AppData\Local\DNSPilot\dnspilot.sqlite");

        Assert.SequenceEqual(
            new[] { "DNS only", "DNS + TCP", "System DNS validation" },
            shell.AvailableBenchmarkModes.Select(mode => mode.DisplayLabel));
        Assert.Equal(BenchmarkMode.DnsAndTcp, shell.BenchmarkPlan.Mode);
        Assert.Equal("path-compare", shell.BenchmarkPlan.CommandArguments.First());
        Assert.Equal("system-benchmark", shell.SystemDnsValidationPlan.CommandArguments.First());
        Assert.True(shell.BenchmarkPlan.SupportsHistoryPersistence, "DNS + TCP should support history persistence.");
        Assert.False(shell.SystemDnsValidationPlan.SupportsHistoryPersistence, "System DNS validation does not support CLI history save args yet.");
        Assert.Equal("ms-settings:network-advancedsettings", shell.ApplyGuidance.OpenSettingsUri.PrimaryUri);
        Assert.DoesNotContain(ApplyActionKind.MutateSystemDns.ToString(), string.Join(" ", shell.ApplyGuidance.Actions.Select(action => action.Kind)));
        Assert.SequenceEqual(new[] { "profile-list", "--db", @"C:\Users\aart\AppData\Local\DNSPilot\dnspilot.sqlite" }, shell.ProfileListCommand);
        Assert.SequenceEqual(new[] { "history-list", "--db", @"C:\Users\aart\AppData\Local\DNSPilot\dnspilot.sqlite" }, shell.HistoryListCommand);
        Assert.Equal(TrayActionKind.QuickBenchmark, shell.TrayQuickActions.Actions.First().Kind);
        Assert.Contains("A + AAAA", shell.BenchmarkControlHelpText);
        Assert.Contains("IPv4", shell.BenchmarkControlHelpText);
    }

    private static void BenchmarkRunnerBuildsProcessBoundary()
    {
        var processRunner = new RecordingProcessRunner(new CliProcessOutput(0, "{\"ok\":true}", ""));
        var runner = new BenchmarkRunner(@"C:\Program Files\DNSPilot\dnspilot-cli.exe", processRunner);
        var result = runner.Run(
            TestData.Plan(mode: BenchmarkMode.DnsOnly),
            new BenchmarkHistoryPersistence("profiles.sqlite", "win-run-001"),
            progressHandler: _ => { });

        Assert.True(result.Succeeded, "Expected successful process result.");
        Assert.SequenceEqual(
            TestData.Plan(mode: BenchmarkMode.DnsOnly).CommandArguments
                .Concat(new[] { "--progress-jsonl", "--save-db", "profiles.sqlite", "--history-id", "win-run-001" }),
            processRunner.LastArguments);
        Assert.Equal(@"C:\Program Files\DNSPilot\dnspilot-cli.exe", processRunner.LastExecutablePath);

        var failingRunner = new BenchmarkRunner("dnspilot-cli", new RecordingProcessRunner(new CliProcessOutput(2, "", "network timeout")));
        var failedResult = failingRunner.Run(TestData.Plan(mode: BenchmarkMode.DnsAndTcp));
        var failure = failedResult.ToFailure(BenchmarkFailureStep.MeasuringConnection, TimeSpan.FromMilliseconds(404));

        Assert.False(failedResult.Succeeded, "Expected failed process result.");
        Assert.Contains("exit code 2", failure.DebugLog);
        Assert.Contains("network timeout", failure.DebugLog);
        Assert.Contains("path-compare", failure.DebugLog);
        Assert.Contains("Elapsed: 404 ms", failure.CopyableReport("DNS + TCP"));
    }
}

internal static class TestData
{
    public static CatalogSnapshot Catalog { get; } = new(
        Profiles: new[]
        {
            new CatalogProfile("cloudflare", "Cloudflare", DnsProtocol.Plain, new[] { "1.1.1.1", "1.0.0.1" }, new[] { "2606:4700:4700::1111" }),
            new CatalogProfile("google", "Google", DnsProtocol.Plain, new[] { "8.8.8.8" }, Array.Empty<string>()),
            new CatalogProfile("v6only", "IPv6 Lab", DnsProtocol.Plain, Array.Empty<string>(), new[] { "2001:4860:4860::8888" }),
        },
        TestSuites: new[]
        {
            new CatalogTestSuite("developer", "Developer", new[] { "github.com", "microsoft.com" }),
        });

    public static BenchmarkPlanViewModel Plan(
        BenchmarkMode mode,
        IReadOnlyList<string>? selectedProfileIds = null,
        DnsRecordFamily? recordFamily = null,
        ResolverAddressFamily? resolverAddressFamily = null,
        int dnsTimeoutMs = 750,
        int connectTimeoutMs = 1_000,
        int maxConnectTargetsPerDomain = 4)
    {
        return new BenchmarkPlanViewModel(
            Catalog,
            selectedProfileIds ?? new[] { "cloudflare", "google" },
            selectedSuiteId: "developer",
            customDomains: new[] { "example.com", "github.com" },
            attempts: 2,
            dnsTimeoutMs: dnsTimeoutMs,
            connectTimeoutMs: connectTimeoutMs,
            maxConnectTargetsPerDomain: maxConnectTargetsPerDomain,
            recordFamily: recordFamily ?? DnsRecordFamily.Both,
            resolverAddressFamily: resolverAddressFamily ?? ResolverAddressFamily.Automatic,
            mode: mode);
    }
}

internal static class Assert
{
    public static void Equal<T>(T expected, T actual)
    {
        if (!EqualityComparer<T>.Default.Equals(expected, actual))
        {
            throw new InvalidOperationException($"Expected <{expected}> but got <{actual}>.");
        }
    }

    public static void True(bool condition, string? message = null)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message ?? "Expected condition to be true.");
        }
    }

    public static void False(bool condition, string? message = null)
    {
        if (condition)
        {
            throw new InvalidOperationException(message ?? "Expected condition to be false.");
        }
    }

    public static void Contains(string expected, string actual)
    {
        if (!actual.Contains(expected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected <{actual}> to contain <{expected}>.");
        }
    }

    public static void DoesNotContain(string unexpected, string actual)
    {
        if (actual.Contains(unexpected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected <{actual}> not to contain <{unexpected}>.");
        }
    }

    public static void SequenceEqual<T>(IEnumerable<T> expected, IEnumerable<T> actual)
    {
        var expectedArray = expected.ToArray();
        var actualArray = actual.ToArray();
        if (!expectedArray.SequenceEqual(actualArray))
        {
            throw new InvalidOperationException(
                "Expected sequence:\n" + string.Join("\n", expectedArray) + "\nActual sequence:\n" + string.Join("\n", actualArray));
        }
    }
}

internal sealed class RecordingProcessRunner : ICliProcessRunner
{
    private readonly CliProcessOutput _output;

    public RecordingProcessRunner(CliProcessOutput output)
    {
        _output = output;
    }

    public string LastExecutablePath { get; private set; } = "";
    public IReadOnlyList<string> LastArguments { get; private set; } = Array.Empty<string>();

    public CliProcessOutput Run(string executablePath, IReadOnlyList<string> arguments, Action<BenchmarkProgressEvent>? progressHandler)
    {
        LastExecutablePath = executablePath;
        LastArguments = arguments.ToArray();
        progressHandler?.Invoke(new BenchmarkProgressEvent(ProgressEventType.ResolverStarted, "cloudflare", "1.1.1.1:53", 1, 1));
        return _output;
    }
}
