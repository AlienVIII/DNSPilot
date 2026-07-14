using DNSPilotWindows.Core;
using System.Globalization;
using System.Xml.Linq;

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
        Run("Protected apply guidance suppresses copy and settings apply actions", ProtectedApplyGuidanceSuppressesApplyActions);
        Run("Custom DNS profile form validates addresses and builds storage commands", CustomDnsProfileFormBuildsStorageCommands);
        Run("Custom domain suite form validates domains and builds storage commands", CustomDomainSuiteFormBuildsStorageCommands);
        Run("Custom domain suite validation matches CLI domain canonicalization", CustomDomainSuiteValidationMatchesCliCanonicalization);
        Run("Tray quick actions expose quick benchmark, system validation, and settings handoff", TrayQuickActionsExposeStoreSafeCommands);
        Run("History persistence appends save args and exposes management commands", HistoryPersistenceBuildsSaveAndManagementCommands);
        Run("Windows capability policy separates Store-safe shell from Power edition", WindowsCapabilityPolicySeparatesStoreAndPower);
        Run("Windows shell state exposes benchmark, apply, profile, history, and tray surfaces", WindowsShellStateExposesStoreSafeSurfaces);
        Run("Default Windows shell blocks apply actions until runtime policy loads", DefaultWindowsShellBlocksApplyUntilRuntimePolicyLoads);
        Run("Benchmark control selection builds live preview plans", BenchmarkControlSelectionBuildsLivePreviewPlans);
        Run("Benchmark runner validates plan, appends progress and history args, and reports process failure", BenchmarkRunnerBuildsProcessBoundary);
        Run("CLI payload decoders map catalog, capabilities, and apply-plan contracts", CliPayloadDecodersMapCoreContracts);
        Run("CLI contract runners invoke catalog, capabilities, apply-plan, profile, and history commands", CliContractRunnersInvokeCommands);
        Run("Suite list decoder and runner map persisted suite management contracts", SuiteListDecoderAndRunnerMapPersistedSuites);
        Run("Profile and history list decoders map persisted rows for management UI", ProfileAndHistoryListDecodersMapRows);
        Run("Windows shell can hydrate from CLI payloads for catalog, policy, apply, profiles, and history", WindowsShellHydratesFromCliPayloads);
        Run("Windows shell merges persisted custom profiles into benchmark catalog", WindowsShellMergesPersistedProfilesIntoBenchmarkCatalog);
        Run("Windows shell merges persisted custom suites into benchmark catalog", WindowsShellMergesPersistedSuitesIntoBenchmarkCatalog);
        Run("Benchmark control selection can target custom DNS profiles", BenchmarkControlSelectionCanTargetCustomProfiles);
        Run("Benchmark control selection can target custom domain suites", BenchmarkControlSelectionCanTargetCustomSuites);
        Run("Benchmark control selection falls back when selected suite is missing", BenchmarkControlSelectionFallsBackWhenSelectedSuiteIsMissing);
        Run("Profile management guards built-in update and delete by profile ID", ProfileManagementGuardsBuiltInMutationById);
        Run("Suite management guards built-in update and delete by suite ID", SuiteManagementGuardsBuiltInMutationById);
        Run("Suite ownership matches Core CLI custom markers exactly", SuiteOwnershipMatchesCoreCliMarkersExactly);
        Run("Benchmark result decoder and apply-plan request factory map recommendations", BenchmarkResultDecoderBuildsApplyPlanRequest);
        Run("Profile and history management rows expose safe edit/delete state", ProfileAndHistoryRowsExposeManagementState);
        Run("CLI executable locator prefers env, bundled helper, then development target paths", CliExecutableLocatorFindsRuntime);
        Run("Windows app declares native localization resources and Store packaging permissions", WindowsAppDeclaresLocalizationAndPackagingReadiness);
        Run("Windows shell confirms and serializes persistent deletion actions", WindowsShellConfirmsAndSerializesPersistentDeletionActions);
        Run("Windows shell serializes benchmark launches", WindowsShellSerializesBenchmarkLaunches);
        Run("Windows app uses runtime readiness for startup, recovery, and surface gating", WindowsAppUsesRuntimeReadinessForStartupRecoveryAndGating);
        Run("Windows app follows the Check DNS, Profiles, and History consumer contract", WindowsAppFollowsConsumerNavigationContract);
        Run("macOS validation only tolerates the Windows-only XAML compiler failure", MacOsValidationOnlyToleratesWindowsXamlCompilerFailure);
        Run("Windows publish docs include privacy, listing, and certification copy", WindowsPublishDocsIncludePrivacyListingAndCertificationCopy);
        Run("Windows README documents install, run, validation, and package steps", WindowsReadmeDocumentsInstallRunValidationAndPackageSteps);
        Run("Windows dynamic shell text follows current UI culture", WindowsDynamicShellTextFollowsCurrentUiCulture);
        Run("Runtime readiness blocks every surface when the helper is missing", RuntimeReadinessBlocksMissingHelper);
        Run("Runtime readiness degrades malformed benchmark contracts without hiding storage", RuntimeReadinessDegradesMalformedBenchmarkContract);
        Run("Runtime readiness marks unsupported payload schemas incompatible", RuntimeReadinessMarksUnsupportedSchemaIncompatible);
        Run("Runtime readiness preserves healthy surfaces when profile storage fails", RuntimeReadinessPreservesHealthySurfacesWhenProfileStorageFails);
        Run("Runtime readiness creates the local storage directory before probing storage", RuntimeReadinessCreatesStorageDirectory);

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

        var completed = BenchmarkProgressViewModel.From(
            BenchmarkMode.DnsAndTcp,
            BenchmarkRunState.Completed,
            summary,
            progressEvents: new[]
            {
                new BenchmarkProgressEvent(ProgressEventType.ResolverFinished, "cloudflare", "1.1.1.1:53", 1, 2, ProgressEventStatus.Success, 0, 82),
                new BenchmarkProgressEvent(ProgressEventType.ResolverFinished, "google", "8.8.8.8:53", 2, 2, ProgressEventStatus.Degraded, 0.25, 140),
            },
            historySaved: true);

        Assert.Equal(ProgressStatus.Success, completed.ResolverStatuses.Single(row => row.Id == "cloudflare").Status);
        Assert.Equal(ProgressStatus.Degraded, completed.ResolverStatuses.Single(row => row.Id == "google").Status);
        Assert.Contains("0% failed", completed.ResolverStatuses.Single(row => row.Id == "cloudflare").Detail);
        Assert.Equal(ProgressStatus.Success, completed.Steps.Single(step => step.Id == BenchmarkFailureStep.SavingHistory.Id).Status);
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

    private static void ProtectedApplyGuidanceSuppressesApplyActions()
    {
        var protectedPlan = ApplyPlanJsonDecoder.Decode(SampleJson.ProtectedApplyPlan);
        var guidance = ApplyGuidanceViewModel.FromPlan(protectedPlan);

        Assert.Equal(ApplyDecision.Protect, guidance.Plan.Decision);
        Assert.Equal("", guidance.CopyableDnsServers);
        Assert.DoesNotContain(ApplyActionKind.CopyDnsServers.ToString(), string.Join(" ", guidance.Actions.Select(action => action.Kind)));
        Assert.DoesNotContain(ApplyActionKind.OpenWindowsSettings.ToString(), string.Join(" ", guidance.Actions.Select(action => action.Kind)));
        Assert.SequenceEqual(new[] { ApplyActionKind.CopyChecklist }, guidance.Actions.Select(action => action.Kind));
        Assert.Contains("Keep current DNS settings", guidance.CopyableChecklist);
        Assert.Contains("VPN is active", guidance.CopyableChecklist);
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

    private static void CustomDomainSuiteFormBuildsStorageCommands()
    {
        var form = new CustomDomainSuiteFormViewModel(
            name: "  Azure Lab  ",
            domains: "portal.azure.com, login.microsoftonline.com\nportal.azure.com");

        Assert.False(form.Validation.CanSave, "Duplicate domain should block save.");
        Assert.Contains("Duplicate domain: portal.azure.com", string.Join("\n", form.Validation.Issues));

        var valid = new CustomDomainSuiteFormViewModel(
            name: "  Azure Lab  ",
            domains: "portal.azure.com, login.microsoftonline.com",
            tags: "azure,custom");

        Assert.True(valid.Validation.CanSave, "Expected valid custom suite.");
        Assert.Equal("custom-azure-lab", valid.SuiteId);
        Assert.SequenceEqual(
            new[] { "suite-add", "--db", "profiles.sqlite", "--id", "custom-azure-lab", "--name", "Azure Lab", "--domain", "portal.azure.com", "--domain", "login.microsoftonline.com", "--tag", "azure", "--tag", "custom" },
            valid.AddCommandArguments("profiles.sqlite"));
        Assert.SequenceEqual(
            new[] { "suite-update", "--db", "profiles.sqlite", "--id", "custom-azure-lab", "--name", "Azure Lab", "--domain", "portal.azure.com", "--domain", "login.microsoftonline.com", "--tag", "azure", "--tag", "custom" },
            valid.UpdateCommandArguments("profiles.sqlite", "custom-azure-lab"));
        Assert.SequenceEqual(
            new[] { "suite-delete", "--db", "profiles.sqlite", "--id", "custom-azure-lab" },
            SuiteManagementCommands.Delete("profiles.sqlite", "custom-azure-lab"));

        var invalid = new CustomDomainSuiteFormViewModel("", "bad_domain, -broken.com");
        Assert.False(invalid.Validation.CanSave, "Expected invalid suite form.");
        Assert.Contains("Suite name is required.", string.Join("\n", invalid.Validation.Issues));
        Assert.Contains("Invalid domain: bad_domain", string.Join("\n", invalid.Validation.Issues));
        Assert.Contains("Invalid domain: -broken.com", string.Join("\n", invalid.Validation.Issues));
    }

    private static void CustomDomainSuiteValidationMatchesCliCanonicalization()
    {
        var duplicate = new CustomDomainSuiteFormViewModel(
            "Canonical duplicate",
            "Example.com, example.com.");

        Assert.False(duplicate.Validation.CanSave, "Trailing-dot and casing variants must be treated as duplicate domains.");
        Assert.Contains("Duplicate domain: example.com.", string.Join("\n", duplicate.Validation.Issues));
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
        Assert.SequenceEqual(new[] { "history-delete", "--db", "profiles.sqlite", "--id", "win-run-001" }, HistoryManagementCommands.Delete("profiles.sqlite", "win-run-001"));
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

    private static void DefaultWindowsShellBlocksApplyUntilRuntimePolicyLoads()
    {
        var shell = WindowsShellViewModel.CreateDefault("profiles.sqlite");

        Assert.Equal(ApplyDecision.Block, shell.ApplyGuidance.Plan.Decision);
        Assert.Equal("", shell.ApplyGuidance.CopyableDnsServers);
        Assert.SequenceEqual(
            new[] { ApplyActionKind.CopyChecklist },
            shell.ApplyGuidance.Actions.Select(action => action.Kind));
        Assert.Contains("Keep current DNS settings", shell.ApplyGuidance.CopyableChecklist);
        Assert.Contains("safety policy", shell.ApplyGuidance.CopyableChecklist);
    }

    private static void BenchmarkControlSelectionBuildsLivePreviewPlans()
    {
        var shell = WindowsShellViewModel.CreateDefault("profiles.sqlite");

        var dnsOnly = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 0,
            RecordFamilyIndex: 1,
            ResolverFamilyIndex: 0,
            Attempts: 3,
            DnsTimeoutMs: 900,
            TcpTimeoutMs: 1_100,
            TcpTargetsPerDomain: 5));
        Assert.Equal(BenchmarkMode.DnsOnly, dnsOnly.Mode);
        Assert.SequenceEqual(
            new[] { "compare", "--resolver", "cloudflare=1.1.1.1:53", "--resolver", "google=8.8.8.8:53", "--resolver", "quad9=9.9.9.9:53", "--domain", "github.com", "--domain", "microsoft.com", "--domain", "azure.microsoft.com", "--attempts", "3", "--ip-family", "ipv4-only", "--timeout-ms", "900" },
            dnsOnly.CommandArguments);

        var systemDns = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 2,
            RecordFamilyIndex: 2,
            ResolverFamilyIndex: 1,
            Attempts: 1,
            DnsTimeoutMs: 700,
            TcpTimeoutMs: 1_100,
            TcpTargetsPerDomain: 2));
        Assert.Equal(BenchmarkMode.SystemDnsValidation, systemDns.Mode);
        Assert.SequenceEqual(
            new[] { "system-benchmark", "--platform", "windows-store", "--domain", "github.com", "--domain", "microsoft.com", "--domain", "azure.microsoft.com", "--attempts", "1", "--ip-family", "ipv6-only", "--timeout-ms", "700" },
            systemDns.CommandArguments);

        var ipv6Resolvers = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 1,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 2,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4));
        Assert.Contains("--resolver cloudflare=[2606:4700:4700::1111]:53", string.Join(" ", ipv6Resolvers.CommandArguments));

        var validation = shell.BuildSystemDnsValidationPlan(new BenchmarkControlSelection(
            ModeIndex: 1,
            RecordFamilyIndex: 2,
            ResolverFamilyIndex: 2,
            Attempts: 4,
            DnsTimeoutMs: 1_200,
            TcpTimeoutMs: 1_100,
            TcpTargetsPerDomain: 2));
        Assert.SequenceEqual(
            new[] { "system-benchmark", "--platform", "windows-store", "--domain", "github.com", "--domain", "microsoft.com", "--domain", "azure.microsoft.com", "--attempts", "4", "--ip-family", "ipv6-only", "--timeout-ms", "1200" },
            validation.CommandArguments);

        var quick = shell.BuildQuickBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 2,
            RecordFamilyIndex: 1,
            ResolverFamilyIndex: 1,
            Attempts: 5,
            DnsTimeoutMs: 900,
            TcpTimeoutMs: 1_400,
            TcpTargetsPerDomain: 6));
        Assert.Equal(BenchmarkMode.DnsAndTcp, quick.Mode);
        Assert.Contains("--ip-family ipv4-only", string.Join(" ", quick.CommandArguments));
        Assert.Contains("--max-connect-targets-per-domain 6", string.Join(" ", quick.CommandArguments));
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

    private static void CliPayloadDecodersMapCoreContracts()
    {
        var catalog = CatalogJsonDecoder.Decode(SampleJson.Catalog);
        var profile = catalog.Profiles.Single(profile => profile.Id == "cloudflare");
        var suite = catalog.TestSuites.Single(suite => suite.Id == "developer");

        Assert.Equal("Cloudflare", profile.Name);
        Assert.Equal(DnsProtocol.Plain, profile.Protocol);
        Assert.SequenceEqual(new[] { "1.1.1.1", "1.0.0.1" }, profile.Ipv4Servers);
        Assert.SequenceEqual(new[] { "github.com", "microsoft.com" }, suite.Domains);

        var capabilities = CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities);
        var store = capabilities.RequirePlatform("windows-store");
        var power = capabilities.RequirePlatform("windows-power");

        Assert.True(store.CanBenchmark, "Windows Store should benchmark.");
        Assert.True(store.StoreSafe, "Windows Store capability should be store-safe.");
        Assert.Equal("guided-settings", store.Apply);
        Assert.False(power.StoreSafe, "Power edition should not be store-safe.");
        Assert.Equal("desktop-admin-service", power.Apply);

        var applyPlan = ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan);
        Assert.Equal(ApplyDecision.Guide, applyPlan.Decision);
        Assert.Equal("windows-store", applyPlan.PlatformId);
        Assert.Equal("guided-settings", applyPlan.ApplyCapability);
        Assert.Equal("Cloudflare", applyPlan.ProfileName);
        Assert.Equal("1.1.1.1:53", applyPlan.TestedResolver);
        Assert.False(applyPlan.CanApply, "Store apply-plan must not allow direct mutation.");
        Assert.SequenceEqual(
            new[] { "1.1.1.1", "1.0.0.1", "2606:4700:4700::1111" },
            applyPlan.DnsServers.Take(3));

        Assert.Throws<InvalidOperationException>(() => CatalogJsonDecoder.Decode("{\"schema_version\":2,\"profiles\":[],\"testSuites\":[]}"));
    }

    private static void CliContractRunnersInvokeCommands()
    {
        var catalogRunnerProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.Catalog, ""));
        var catalog = new CatalogRunner("dnspilot-cli", catalogRunnerProcess).Load();
        Assert.Equal("cloudflare", catalog.Profiles.First().Id);
        Assert.SequenceEqual(new[] { "catalog" }, catalogRunnerProcess.LastArguments);

        var capabilityRunnerProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.Capabilities, ""));
        var capabilities = new CapabilityMatrixRunner("dnspilot-cli", capabilityRunnerProcess).Load();
        Assert.Equal("windows-store", capabilities.RequirePlatform("windows-store").Platform);
        Assert.SequenceEqual(new[] { "capabilities" }, capabilityRunnerProcess.LastArguments);

        var applyRunnerProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.ApplyPlan, ""));
        var applyPlan = new ApplyPlanRunner("dnspilot-cli", applyRunnerProcess).Load(
            new ApplyPlanRequest(
                profileId: "cloudflare",
                testedResolver: "1.1.1.1:53",
                confidence: ApplyPlanConfidence.High,
                gateHealth: ApplyPlanGateHealth.Healthy));

        Assert.Equal("Cloudflare", applyPlan.ProfileName);
        Assert.SequenceEqual(
            new[] { "apply-plan", "windows-store", "--confidence", "high", "--gate-health", "healthy", "--profile-id", "cloudflare", "--tested-resolver", "1.1.1.1:53" },
            applyRunnerProcess.LastArguments);

        var profileRunnerProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.ProfileList, ""));
        var profiles = new ProfileListRunner("dnspilot-cli", profileRunnerProcess).Load("profiles.sqlite");
        Assert.Equal(2, profiles.ProfileCount);
        Assert.SequenceEqual(new[] { "profile-list", "--db", "profiles.sqlite" }, profileRunnerProcess.LastArguments);

        var historyRunnerProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.HistoryList, ""));
        var history = new BenchmarkHistoryRunner("dnspilot-cli", historyRunnerProcess).Load("profiles.sqlite");
        Assert.Equal(1, history.BenchmarkHistoryCount);
        Assert.SequenceEqual(new[] { "history-list", "--db", "profiles.sqlite" }, historyRunnerProcess.LastArguments);

        var historyDeleteProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"deleted\":true}", ""));
        new BenchmarkHistoryRunner("dnspilot-cli", historyDeleteProcess).Delete("profiles.sqlite", "compare-run-1");
        Assert.SequenceEqual(new[] { "history-delete", "--db", "profiles.sqlite", "--id", "compare-run-1" }, historyDeleteProcess.LastArguments);

        var historyClearProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"cleared\":true}", ""));
        new BenchmarkHistoryRunner("dnspilot-cli", historyClearProcess).Clear("profiles.sqlite");
        Assert.SequenceEqual(new[] { "history-clear", "--db", "profiles.sqlite" }, historyClearProcess.LastArguments);

        var form = new CustomDnsProfileFormViewModel("Lab DNS", "1.1.1.1", "2606:4700:4700::1111");
        var profileAddProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"saved\":true}", ""));
        new CustomDnsProfileRunner("dnspilot-cli", profileAddProcess).Add("profiles.sqlite", form);
        Assert.SequenceEqual(form.AddCommandArguments("profiles.sqlite"), profileAddProcess.LastArguments);

        var profileUpdateProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"saved\":true}", ""));
        new CustomDnsProfileRunner("dnspilot-cli", profileUpdateProcess).Update("profiles.sqlite", "lab-dns", form);
        Assert.SequenceEqual(form.UpdateCommandArguments("profiles.sqlite", "lab-dns"), profileUpdateProcess.LastArguments);

        var profileDeleteProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"deleted\":true}", ""));
        new CustomDnsProfileRunner("dnspilot-cli", profileDeleteProcess).Delete("profiles.sqlite", "lab-dns");
        Assert.SequenceEqual(ProfileManagementCommands.Delete("profiles.sqlite", "lab-dns"), profileDeleteProcess.LastArguments);
    }

    private static void SuiteListDecoderAndRunnerMapPersistedSuites()
    {
        var payload = SuiteListJsonDecoder.Decode(SampleJson.SuiteList);
        var custom = payload.TestSuites.Single();

        Assert.Equal("/tmp/dnspilot.sqlite", payload.DatabasePath);
        Assert.Equal(1, payload.TestSuiteCount);
        Assert.Equal("custom-azure-lab", custom.Id);
        Assert.Equal("Azure Lab", custom.Name);
        Assert.Equal("Custom domain test suite.", custom.Description);
        Assert.SequenceEqual(new[] { "portal.azure.com", "login.microsoftonline.com" }, custom.Domains);
        Assert.SequenceEqual(new[] { "custom", "azure" }, custom.Tags);

        var listProcess = new RecordingProcessRunner(new CliProcessOutput(0, SampleJson.SuiteList, ""));
        var loaded = new SuiteListRunner("dnspilot-cli", listProcess).Load("profiles.sqlite");
        Assert.Equal("custom-azure-lab", loaded.TestSuites.Single().Id);
        Assert.SequenceEqual(new[] { "suite-list", "--db", "profiles.sqlite" }, listProcess.LastArguments);

        var form = new CustomDomainSuiteFormViewModel("Azure Lab", "portal.azure.com", tags: "custom");
        var addProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"saved\":true}", ""));
        new CustomDomainSuiteRunner("dnspilot-cli", addProcess).Add("profiles.sqlite", form);
        Assert.SequenceEqual(form.AddCommandArguments("profiles.sqlite"), addProcess.LastArguments);

        var updateProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"saved\":true}", ""));
        new CustomDomainSuiteRunner("dnspilot-cli", updateProcess).Update("profiles.sqlite", "custom-azure-lab", form);
        Assert.SequenceEqual(form.UpdateCommandArguments("profiles.sqlite", "custom-azure-lab"), updateProcess.LastArguments);

        var deleteProcess = new RecordingProcessRunner(new CliProcessOutput(0, "{\"deleted\":true}", ""));
        new CustomDomainSuiteRunner("dnspilot-cli", deleteProcess).Delete("profiles.sqlite", "custom-azure-lab");
        Assert.SequenceEqual(SuiteManagementCommands.Delete("profiles.sqlite", "custom-azure-lab"), deleteProcess.LastArguments);
    }

    private static void ProfileAndHistoryListDecodersMapRows()
    {
        var profiles = ProfileListJsonDecoder.Decode(SampleJson.ProfileList);
        var custom = profiles.Profiles.Single(profile => profile.Id == "lab-dns");

        Assert.Equal(2, profiles.ProfileCount);
        Assert.Equal("Lab DNS", custom.Name);
        Assert.SequenceEqual(new[] { "1.1.1.1" }, custom.Ipv4Servers);
        Assert.SequenceEqual(new[] { "2606:4700:4700::1111" }, custom.Ipv6Servers);

        var history = BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList);
        var record = history.Records.Single();
        var rows = new BenchmarkHistoryViewModel(history, TestData.Catalog).Rows;

        Assert.Equal("compare-run-1", record.Id);
        Assert.Equal("dns-only", record.Scope);
        Assert.Equal("cloudflare", record.RecommendationProfileId);
        Assert.Equal("Recommended: Cloudflare", rows.Single().RecommendationLabel);
        Assert.Equal("Retest before applying saved recommendation", rows.Single().ApplyGuidanceLabel);
    }

    private static void WindowsShellHydratesFromCliPayloads()
    {
        var catalog = CatalogJsonDecoder.Decode(SampleJson.Catalog);
        var capabilities = CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities);
        var applyPlan = ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan);
        var profiles = ProfileListJsonDecoder.Decode(SampleJson.ProfileList);
        var suites = SuiteListJsonDecoder.Decode(SampleJson.SuiteList);
        var history = BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList);

        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            catalog,
            capabilities,
            applyPlan,
            profiles,
            suites,
            history);

        Assert.Equal("Cloudflare", shell.Catalog.Profiles.First(profile => profile.Id == "cloudflare").Name);
        Assert.Equal("guided-settings", shell.StorePlatformCapability.Apply);
        Assert.Equal("desktop-admin-service", shell.PowerPlatformCapability.Apply);
        Assert.Equal("1.1.1.1\r\n1.0.0.1\r\n2606:4700:4700::1111\r\n2606:4700:4700::1001", shell.ApplyGuidance.CopyableDnsServers);
        Assert.Equal(2, shell.ProfileRows.Count);
        Assert.Equal("Lab DNS", shell.ProfileRows.Last().Name);
        Assert.Equal("Azure Lab", shell.SuiteRows.Single(row => row.Id == "custom-azure-lab").Name);
        Assert.Equal("Recommended: Cloudflare", shell.HistoryRows.Single().RecommendationLabel);
    }

    private static void WindowsShellMergesPersistedProfilesIntoBenchmarkCatalog()
    {
        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            CatalogJsonDecoder.Decode(SampleJson.Catalog),
            CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities),
            ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan),
            ProfileListJsonDecoder.Decode(SampleJson.ProfileList),
            SuiteListJsonDecoder.Decode(SampleJson.SuiteList),
            BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList));

        Assert.Equal(2, shell.Catalog.Profiles.Count);
        Assert.Equal("Lab DNS", shell.Catalog.Profiles.Single(profile => profile.Id == "lab-dns").Name);
        Assert.Equal("custom", shell.Catalog.Profiles.Single(profile => profile.Id == "lab-dns").UseCase);
        Assert.Equal(2, shell.BenchmarkProfileOptions.Count);
        Assert.True(shell.BenchmarkProfileOptions.Single(profile => profile.Id == "lab-dns").CanBenchmark);
    }

    private static void WindowsShellMergesPersistedSuitesIntoBenchmarkCatalog()
    {
        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            CatalogJsonDecoder.Decode(SampleJson.Catalog),
            CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities),
            ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan),
            ProfileListJsonDecoder.Decode(SampleJson.ProfileList),
            SuiteListJsonDecoder.Decode(SampleJson.SuiteList),
            BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList));

        Assert.Equal(2, shell.Catalog.TestSuites.Count);
        Assert.Equal("Azure Lab", shell.Catalog.TestSuites.Single(suite => suite.Id == "custom-azure-lab").Name);
        Assert.Equal("Custom domain test suite.", shell.Catalog.TestSuites.Single(suite => suite.Id == "custom-azure-lab").Description);
        Assert.Equal(2, shell.BenchmarkSuiteOptions.Count);
        Assert.Equal("Azure Lab", shell.BenchmarkSuiteOptions.Single(option => option.Id == "custom-azure-lab").Name);
        Assert.True(shell.SuiteRows.Single(row => row.Id == "custom-azure-lab").CanEdit);
    }

    private static void BenchmarkControlSelectionCanTargetCustomProfiles()
    {
        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            CatalogJsonDecoder.Decode(SampleJson.Catalog),
            CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities),
            ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan),
            ProfileListJsonDecoder.Decode(SampleJson.ProfileList),
            SuiteListJsonDecoder.Decode(SampleJson.SuiteList),
            BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList));

        var customOnly = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 0,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 0,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4,
            SelectedProfileIds: new[] { "lab-dns" }));

        Assert.SequenceEqual(
            new[] { "compare", "--resolver", "lab-dns=1.1.1.1:53", "--domain", "github.com", "--domain", "microsoft.com", "--attempts", "2", "--ip-family", "both", "--timeout-ms", "800" },
            customOnly.CommandArguments);

        var emptySelection = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 0,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 0,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4,
            SelectedProfileIds: Array.Empty<string>()));

        Assert.False(emptySelection.Validation.CanRun, "Expected an explicit empty resolver selection to block benchmark run.");
        Assert.Contains("Select at least one plain DNS profile.", string.Join("\n", emptySelection.Validation.Issues));
    }

    private static void BenchmarkControlSelectionCanTargetCustomSuites()
    {
        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            CatalogJsonDecoder.Decode(SampleJson.Catalog),
            CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities),
            ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan),
            ProfileListJsonDecoder.Decode(SampleJson.ProfileList),
            SuiteListJsonDecoder.Decode(SampleJson.SuiteList),
            BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList));

        var customSuite = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 0,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 0,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4,
            SelectedProfileIds: new[] { "cloudflare" },
            SelectedSuiteId: "custom-azure-lab"));

        Assert.SequenceEqual(
            new[] { "compare", "--resolver", "cloudflare=1.1.1.1:53", "--domain", "portal.azure.com", "--domain", "login.microsoftonline.com", "--attempts", "2", "--ip-family", "both", "--timeout-ms", "800" },
            customSuite.CommandArguments);
    }

    private static void BenchmarkControlSelectionFallsBackWhenSelectedSuiteIsMissing()
    {
        var shell = WindowsShellViewModel.CreateLoaded(
            "profiles.sqlite",
            CatalogJsonDecoder.Decode(SampleJson.Catalog),
            CapabilityMatrixJsonDecoder.Decode(SampleJson.Capabilities),
            ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan),
            ProfileListJsonDecoder.Decode(SampleJson.ProfileList),
            SuiteListJsonDecoder.Decode(SampleJson.SuiteList),
            BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList));

        var missingSuite = shell.BuildBenchmarkPlan(new BenchmarkControlSelection(
            ModeIndex: 0,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 0,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4,
            SelectedProfileIds: new[] { "cloudflare" },
            SelectedSuiteId: "missing-suite"));

        Assert.True(missingSuite.Validation.CanRun, "Missing UI suite selection should fall back to a known suite.");
        Assert.SequenceEqual(
            new[] { "compare", "--resolver", "cloudflare=1.1.1.1:53", "--domain", "github.com", "--domain", "microsoft.com", "--attempts", "2", "--ip-family", "both", "--timeout-ms", "800" },
            missingSuite.CommandArguments);
    }

    private static void ProfileManagementGuardsBuiltInMutationById()
    {
        var management = new ProfileManagementViewModel(ProfileListJsonDecoder.Decode(SampleJson.ProfileList));

        var updateBuiltIn = management.ValidateMutation(ProfileMutationKind.Update, "cloudflare");
        var deleteBuiltIn = management.ValidateMutation(ProfileMutationKind.Delete, "cloudflare");
        var updateCustom = management.ValidateMutation(ProfileMutationKind.Update, "lab-dns");
        var deleteMissing = management.ValidateMutation(ProfileMutationKind.Delete, "missing-profile");

        Assert.False(updateBuiltIn.CanMutate, "Built-in profile update must be blocked even when typed manually.");
        Assert.False(deleteBuiltIn.CanMutate, "Built-in profile delete must be blocked even when typed manually.");
        Assert.True(updateCustom.CanMutate, "Custom profile update should be allowed.");
        Assert.False(deleteMissing.CanMutate, "Unknown profile delete should be blocked.");
        Assert.Contains("Built-in profiles cannot be updated", string.Join("\n", updateBuiltIn.Issues));
        Assert.Contains("Profile not found: missing-profile", string.Join("\n", deleteMissing.Issues));
    }

    private static void SuiteManagementGuardsBuiltInMutationById()
    {
        var catalog = CatalogJsonDecoder.Decode(SampleJson.Catalog);
        var suites = SuiteListJsonDecoder.Decode(SampleJson.SuiteList);
        var management = new SuiteManagementViewModel(
            catalog.TestSuites.Concat(suites.TestSuites).ToArray());

        var updateBuiltIn = management.ValidateMutation(SuiteMutationKind.Update, "developer");
        var deleteBuiltIn = management.ValidateMutation(SuiteMutationKind.Delete, "developer");
        var updateCustom = management.ValidateMutation(SuiteMutationKind.Update, "custom-azure-lab");
        var deleteMissing = management.ValidateMutation(SuiteMutationKind.Delete, "missing-suite");

        Assert.False(updateBuiltIn.CanMutate, "Built-in suite update must be blocked even when typed manually.");
        Assert.False(deleteBuiltIn.CanMutate, "Built-in suite delete must be blocked even when typed manually.");
        Assert.True(updateCustom.CanMutate, "Custom suite update should be allowed.");
        Assert.False(deleteMissing.CanMutate, "Unknown suite delete should be blocked.");
        Assert.Contains("Built-in suites cannot be updated", string.Join("\n", updateBuiltIn.Issues));
        Assert.Contains("Suite not found: missing-suite", string.Join("\n", deleteMissing.Issues));
    }

    private static void SuiteOwnershipMatchesCoreCliMarkersExactly()
    {
        var suites = new[]
        {
            new CatalogTestSuite("custom-prefix-only", "Prefix only", new[] { "example.com" }),
            new CatalogTestSuite("case-mismatched-tag", "Case tag", new[] { "example.com" })
            {
                Tags = new[] { "Custom" },
            },
            new CatalogTestSuite("exact-tag", "Exact tag", new[] { "example.com" })
            {
                Tags = new[] { "custom" },
            },
            new CatalogTestSuite("exact-description", "Exact description", new[] { "example.com" })
            {
                Description = "Custom domain test suite.",
            },
        };

        var rows = new SuiteManagementViewModel(suites).Rows;

        Assert.False(rows.Single(row => row.Id == "custom-prefix-only").CanEdit, "An ID prefix is not a Core CLI ownership marker.");
        Assert.False(rows.Single(row => row.Id == "case-mismatched-tag").CanEdit, "Core CLI custom tags are case-sensitive.");
        Assert.True(rows.Single(row => row.Id == "exact-tag").CanEdit, "Exact custom tag should be editable.");
        Assert.True(rows.Single(row => row.Id == "exact-description").CanEdit, "Exact custom description should be editable.");
    }

    private static void BenchmarkResultDecoderBuildsApplyPlanRequest()
    {
        var result = BenchmarkResultJsonDecoder.Decode(SampleJson.BenchmarkResult);

        Assert.Equal("dns-tcp", result.Summary.MeasurementScope);
        Assert.Equal("healthy", result.Summary.Health);
        Assert.True(result.Summary.CanRecommend, "Benchmark should be recommendable.");
        Assert.Equal("cloudflare", result.Summary.RecommendedProfileId);
        Assert.Equal("cloudflare", result.Recommendation?.ProfileId);
        Assert.Equal("1.1.1.1:53", result.Runs.Single(run => run.ProfileId == "cloudflare").Resolver);
        Assert.Equal(12.5, result.Runs.Single(run => run.ProfileId == "cloudflare").Metrics.MedianDnsLatencyMs);

        var report = BenchmarkResultReportViewModel.FromResult(result);
        Assert.Equal("Recommendation: cloudflare (high, score 0.98)", report.RecommendationLine);
        Assert.Contains("Scope: dns-tcp; Mode: best-overall; Health: healthy; Can recommend: yes", report.CopyableReport);
        Assert.Contains("Recommended profile: cloudflare", report.CopyableReport);
        Assert.Contains("Saved history: windows-run-1", report.CopyableReport);
        Assert.Contains("cloudflare 1.1.1.1:53 - median DNS 12.5 ms; p95 DNS 16 ms; connect 31 ms; failure 0%; timeout 0%; IPv4 100%; IPv6 100%; priority fit 100%", report.CopyableReport);
        Assert.Contains("Reason: Best overall path.", report.CopyableReport);
        Assert.Contains("Warning: Path comparison estimates DNS plus TCP connect timing only.", report.CopyableReport);

        var request = BenchmarkApplyPlanRequestFactory.MakeRequest(result);
        Assert.SequenceEqual(
            new[] { "apply-plan", "windows-store", "--confidence", "high", "--gate-health", "healthy", "--profile-id", "cloudflare", "--tested-resolver", "1.1.1.1:53" },
            request.CommandArguments);

        var shell = WindowsShellViewModel
            .CreateDefault("profiles.sqlite")
            .WithApplyPlan(ApplyPlanJsonDecoder.Decode(SampleJson.ApplyPlan));

        Assert.Contains("2606:4700:4700::1001", shell.ApplyGuidance.CopyableDnsServers);
    }

    private static void ProfileAndHistoryRowsExposeManagementState()
    {
        var profiles = ProfileListJsonDecoder.Decode(SampleJson.ProfileList);
        var profileRows = new ProfileManagementViewModel(profiles).Rows;

        Assert.Equal(2, profileRows.Count);
        Assert.False(profileRows.First(row => row.Id == "cloudflare").CanEdit, "Built-in profiles should not be editable from Windows shell.");
        Assert.False(profileRows.First(row => row.Id == "cloudflare").CanDelete, "Built-in profiles should not be deletable from Windows shell.");
        var custom = profileRows.First(row => row.Id == "lab-dns");
        Assert.True(custom.CanEdit, "Custom profile should be editable.");
        Assert.True(custom.CanDelete, "Custom profile should be deletable.");
        Assert.Equal("Lab DNS (lab-dns) - custom", custom.ToString());
        Assert.SequenceEqual(new[] { "1.1.1.1" }, custom.Ipv4Servers);

        var history = BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList);
        var historyRows = new BenchmarkHistoryViewModel(history, TestData.Catalog).Rows;
        Assert.Equal("compare-run-1", historyRows.Single().Id);
        Assert.Equal("DNS only: Recommended: Cloudflare", historyRows.Single().ToString());
    }

    private static void CliExecutableLocatorFindsRuntime()
    {
        var root = Path.Combine(Path.GetTempPath(), "dnspilot-windows-locator-" + Guid.NewGuid().ToString("N"));
        try
        {
            var appBase = Path.Combine(root, "apps", "windows", "DNSPilotWindows", "app", "bin");
            var release = Path.Combine(root, "target", "release");
            var debug = Path.Combine(root, "target", "debug");
            Directory.CreateDirectory(appBase);
            Directory.CreateDirectory(release);
            Directory.CreateDirectory(debug);

            var envCli = Path.Combine(root, "env", "dnspilot-cli.exe");
            Directory.CreateDirectory(Path.GetDirectoryName(envCli)!);
            File.WriteAllText(envCli, "");
            var bundledCli = Path.Combine(appBase, "dnspilot-cli.exe");
            File.WriteAllText(bundledCli, "");
            var releaseCli = Path.Combine(release, "dnspilot-cli.exe");
            File.WriteAllText(releaseCli, "");
            var debugCli = Path.Combine(debug, "dnspilot-cli.exe");
            File.WriteAllText(debugCli, "");

            Assert.Equal(envCli, CliExecutableLocator.Locate(appBase, envCli));
            Assert.Equal(bundledCli, CliExecutableLocator.Locate(appBase, null));
            File.Delete(bundledCli);
            Assert.Equal(releaseCli, CliExecutableLocator.Locate(appBase, null));
            File.Delete(releaseCli);
            Assert.Equal(debugCli, CliExecutableLocator.Locate(appBase, ""));
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    private static void RuntimeReadinessBlocksMissingHelper()
    {
        var runner = new ScriptedProcessRunner(new Dictionary<string, CliProcessOutput>());
        var helperPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "dnspilot-cli.exe");

        var result = new RuntimeContractLoader(runner).Load(helperPath, "/tmp/dnspilot.sqlite");

        Assert.Equal(RuntimeReadinessState.Degraded, result.Readiness.State);
        Assert.False(result.Readiness.CanBenchmark);
        Assert.False(result.Readiness.CanApplyGuidance);
        Assert.False(result.Readiness.CanManageProfiles);
        Assert.False(result.Readiness.CanManageSuites);
        Assert.False(result.Readiness.CanReadHistory);
        Assert.Equal(RuntimeFailureKind.MissingHelper, result.Readiness.For(RuntimeSurface.Benchmark).FailureKind);
        Assert.Contains("bundle", result.Readiness.For(RuntimeSurface.Benchmark).RecoveryAction.ToLowerInvariant());
        Assert.Equal(0, runner.InvocationCount);
    }

    private static void RuntimeReadinessDegradesMalformedBenchmarkContract()
    {
        WithFakeCli((helperPath, databasePath) =>
        {
            var runner = RuntimeProcessRunner(
                catalog: "not-json",
                capabilities: SampleJson.Capabilities,
                profileList: SampleJson.ProfileList,
                suiteList: SampleJson.SuiteList,
                historyList: SampleJson.HistoryList,
                applyPlan: SampleJson.ApplyPlan);

            var result = new RuntimeContractLoader(runner).Load(helperPath, databasePath);

            Assert.Equal(RuntimeReadinessState.Degraded, result.Readiness.State);
            Assert.False(result.Readiness.CanBenchmark);
            Assert.False(result.Readiness.CanApplyGuidance);
            Assert.True(result.Readiness.CanManageProfiles);
            Assert.True(result.Readiness.CanManageSuites);
            Assert.True(result.Readiness.CanReadHistory);
            Assert.Equal(RuntimeFailureKind.MalformedPayload, result.Readiness.For(RuntimeSurface.Benchmark).FailureKind);
            Assert.Equal(RuntimeFailureKind.MalformedPayload, result.Readiness.For(RuntimeSurface.ApplyGuidance).FailureKind);
            Assert.True(result.ProfileList is not null);
        });
    }

    private static void RuntimeReadinessMarksUnsupportedSchemaIncompatible()
    {
        WithFakeCli((helperPath, databasePath) =>
        {
            var runner = RuntimeProcessRunner(
                catalog: "{\"schema_version\":2,\"profiles\":[],\"testSuites\":[]}",
                capabilities: SampleJson.Capabilities,
                profileList: SampleJson.ProfileList,
                suiteList: SampleJson.SuiteList,
                historyList: SampleJson.HistoryList,
                applyPlan: SampleJson.ApplyPlan);

            var result = new RuntimeContractLoader(runner).Load(helperPath, databasePath);

            Assert.Equal(RuntimeReadinessState.Incompatible, result.Readiness.State);
            Assert.Equal(RuntimeFailureKind.UnsupportedSchema, result.Readiness.For(RuntimeSurface.Benchmark).FailureKind);
            Assert.Contains("Update", result.Readiness.For(RuntimeSurface.Benchmark).RecoveryAction);
            Assert.Contains("Payload schema: 1", result.Readiness.CopyableReport("1.0.0"));
        });
    }

    private static void RuntimeReadinessPreservesHealthySurfacesWhenProfileStorageFails()
    {
        WithFakeCli((helperPath, databasePath) =>
        {
            var runner = RuntimeProcessRunner(
                catalog: SampleJson.Catalog,
                capabilities: SampleJson.Capabilities,
                profileList: SampleJson.ProfileList,
                suiteList: SampleJson.SuiteList,
                historyList: SampleJson.HistoryList,
                applyPlan: SampleJson.ApplyPlan,
                failedCommand: "profile-list");

            var result = new RuntimeContractLoader(runner).Load(helperPath, databasePath);
            var shell = WindowsShellViewModel.CreateFromRuntimeLoad(databasePath, result);

            Assert.Equal(RuntimeReadinessState.Degraded, result.Readiness.State);
            Assert.True(shell.RuntimeReadiness.CanBenchmark);
            Assert.True(shell.RuntimeReadiness.CanApplyGuidance);
            Assert.False(shell.RuntimeReadiness.CanManageProfiles);
            Assert.True(shell.RuntimeReadiness.CanManageSuites);
            Assert.True(shell.RuntimeReadiness.CanReadHistory);
            Assert.Equal(RuntimeFailureKind.StorageFailure, shell.RuntimeReadiness.For(RuntimeSurface.Profiles).FailureKind);
            Assert.True(shell.SuiteRows.Any(row => row.Id == "custom-azure-lab"));
            Assert.Equal(1, shell.HistoryRows.Count);
        });
    }

    private static void RuntimeReadinessCreatesStorageDirectory()
    {
        var root = Path.Combine(Path.GetTempPath(), "dnspilot-runtime-storage-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(root);
            var helperPath = Path.Combine(root, "dnspilot-cli.exe");
            File.WriteAllText(helperPath, "test helper");
            var databasePath = Path.Combine(root, "local", "DNSPilot", "dnspilot.sqlite");
            var runner = RuntimeProcessRunner(
                catalog: SampleJson.Catalog,
                capabilities: SampleJson.Capabilities,
                profileList: SampleJson.ProfileList,
                suiteList: SampleJson.SuiteList,
                historyList: SampleJson.HistoryList,
                applyPlan: SampleJson.ApplyPlan);

            var result = new RuntimeContractLoader(runner).Load(helperPath, databasePath);

            Assert.True(Directory.Exists(Path.GetDirectoryName(databasePath)!));
            Assert.True(result.Readiness.CanManageProfiles);
            Assert.True(result.Readiness.CanManageSuites);
            Assert.True(result.Readiness.CanReadHistory);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    private static ScriptedProcessRunner RuntimeProcessRunner(
        string catalog,
        string capabilities,
        string profileList,
        string suiteList,
        string historyList,
        string applyPlan,
        string? failedCommand = null)
    {
        var outputs = new Dictionary<string, CliProcessOutput>(StringComparer.Ordinal)
        {
            ["catalog"] = new CliProcessOutput(0, catalog, ""),
            ["capabilities"] = new CliProcessOutput(0, capabilities, ""),
            ["profile-list"] = new CliProcessOutput(0, profileList, ""),
            ["suite-list"] = new CliProcessOutput(0, suiteList, ""),
            ["history-list"] = new CliProcessOutput(0, historyList, ""),
            ["apply-plan"] = new CliProcessOutput(0, applyPlan, ""),
        };
        if (failedCommand is not null)
        {
            outputs[failedCommand] = new CliProcessOutput(9, "", $"{failedCommand} failed");
        }

        return new ScriptedProcessRunner(outputs);
    }

    private static void WithFakeCli(Action<string, string> action)
    {
        var root = Path.Combine(Path.GetTempPath(), "dnspilot-runtime-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(root);
            var helperPath = Path.Combine(root, "dnspilot-cli.exe");
            File.WriteAllText(helperPath, "test helper");
            action(helperPath, Path.Combine(root, "dnspilot.sqlite"));
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    private static void WindowsAppDeclaresLocalizationAndPackagingReadiness()
    {
        var repoRoot = FindRepoRoot();
        var appRoot = Path.Combine(repoRoot, "apps", "windows", "DNSPilotWindows", "app", "DNSPilotWindows.App");
        var xaml = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml"));
        var requiredUids = new[]
        {
            "AppTitle",
            "AppSubtitle",
            "RuntimeStatusBar",
            "RuntimeRetryText",
            "QuickBenchmarkText",
            "ValidateDnsText",
            "SettingsText",
            "NavCheckDns",
            "NavProfiles",
            "NavHistory",
            "BenchmarkHeader",
            "ModeCombo",
            "ModeDnsOnly",
            "ModeDnsTcp",
            "ModeSystemDns",
            "RecordFamilyCombo",
            "RecordFamilyBoth",
            "RecordFamilyIpv4",
            "RecordFamilyIpv6",
            "ResolverFamilyCombo",
            "ResolverFamilyAuto",
            "ResolverFamilyIpv4",
            "ResolverFamilyIpv6",
            "AttemptsBox",
            "DnsTimeoutBox",
            "TcpTimeoutBox",
            "TcpTargetsBox",
            "BenchmarkProfilesList",
            "SuiteCombo",
            "CommandPreviewHeader",
            "RunBenchmarkText",
            "CopyCommandText",
            "ProcessHeader",
            "StepsList",
            "ResolversList",
            "ApplyHeader",
            "DnsServersBox",
            "CopyDnsText",
            "OpenSettingsText",
            "CopyChecklistText",
            "ChecklistBox",
            "ProfilesHeader",
            "ProfilesList",
            "ProfileNameBox",
            "ProfileIdBox",
            "Ipv4Box",
            "Ipv6Box",
            "PreviewProfileText",
            "AddProfileText",
            "UpdateProfileText",
            "DeleteProfileText",
            "SuitesHeader",
            "SuitesList",
            "SuiteNameBox",
            "SuiteIdBox",
            "SuiteDomainsBox",
            "PreviewSuiteText",
            "AddSuiteText",
            "UpdateSuiteText",
            "DeleteSuiteText",
            "HistoryHeader",
            "AdvancedDiagnosticsExpander",
            "HistoryList",
            "RefreshStorageText",
            "ClearHistoryText",
            "DeleteSelectedHistoryText",
            "RecommendationReportHeader",
            "RecommendationResolversList",
            "RecommendationNotesList",
            "DiagnosticsBox",
            "CopyDiagnosticsText",
        };

        foreach (var uid in requiredUids)
        {
            Assert.Contains($"x:Uid=\"{uid}\"", xaml);
        }

        Assert.Contains("SelectionChanged=\"BenchmarkSelection_Changed\"", xaml);
        Assert.Contains("SelectionChanged=\"BenchmarkProfiles_SelectionChanged\"", xaml);
        Assert.Contains("ValueChanged=\"BenchmarkNumber_ValueChanged\"", xaml);
        Assert.Contains("Click=\"RunBenchmark_Click\"", xaml);
        Assert.Contains("x:Name=\"RecommendationSummaryText\"", xaml);
        Assert.Contains("x:Name=\"RecommendationLineText\"", xaml);

        var requiredResourceKeys = new[]
        {
            "AppDisplayName",
            "AppDescription",
            "AppTitle.Text",
            "AppSubtitle.Text",
            "RuntimeStatusBar.Title",
            "RuntimeRetryText.Text",
            "QuickBenchmarkText.Text",
            "ValidateDnsText.Text",
            "SettingsText.Text",
            "NavCheckDns.Content",
            "NavProfiles.Content",
            "NavHistory.Content",
            "BenchmarkHeader.Text",
            "ModeCombo.Header",
            "ModeDnsOnly.Content",
            "ModeDnsTcp.Content",
            "ModeSystemDns.Content",
            "RecordFamilyCombo.Header",
            "RecordFamilyBoth.Content",
            "RecordFamilyIpv4.Content",
            "RecordFamilyIpv6.Content",
            "ResolverFamilyCombo.Header",
            "ResolverFamilyAuto.Content",
            "ResolverFamilyIpv4.Content",
            "ResolverFamilyIpv6.Content",
            "AttemptsBox.Header",
            "DnsTimeoutBox.Header",
            "TcpTimeoutBox.Header",
            "TcpTargetsBox.Header",
            "BenchmarkProfilesList.Header",
            "SuiteCombo.Header",
            "CommandPreviewHeader.Text",
            "RunBenchmarkText.Text",
            "CopyCommandText.Text",
            "ProcessHeader.Text",
            "StepsList.Header",
            "ResolversList.Header",
            "ApplyHeader.Text",
            "DnsServersBox.Header",
            "CopyDnsText.Text",
            "OpenSettingsText.Text",
            "CopyChecklistText.Text",
            "ChecklistBox.Header",
            "ProfilesHeader.Text",
            "ProfilesList.Header",
            "ProfileNameBox.Header",
            "ProfileIdBox.Header",
            "Ipv4Box.Header",
            "Ipv6Box.Header",
            "PreviewProfileText.Text",
            "AddProfileText.Text",
            "UpdateProfileText.Text",
            "DeleteProfileText.Text",
            "SuitesHeader.Text",
            "SuitesList.Header",
            "SuiteNameBox.Header",
            "SuiteIdBox.Header",
            "SuiteDomainsBox.Header",
            "PreviewSuiteText.Text",
            "AddSuiteText.Text",
            "UpdateSuiteText.Text",
            "DeleteSuiteText.Text",
            "HistoryHeader.Text",
            "AdvancedDiagnosticsExpander.Header",
            "HistoryList.Header",
            "RefreshStorageText.Text",
            "ClearHistoryText.Text",
            "DeleteSelectedHistoryText.Text",
            "RecommendationReportHeader.Text",
            "RecommendationResolversList.Header",
            "RecommendationNotesList.Header",
            "DiagnosticsBox.Header",
            "CopyDiagnosticsText.Text",
        };

        foreach (var culture in new[] { "en-US", "vi-VN" })
        {
            var resourceKeys = LoadResourceKeys(Path.Combine(appRoot, "Strings", culture, "Resources.resw"));
            foreach (var key in requiredResourceKeys)
            {
                Assert.True(resourceKeys.Contains(key), $"Expected {culture} resources to include {key}.");
            }
        }

        var packageTemplate = File.ReadAllText(Path.Combine(appRoot, "Packaging", "Package.Store.appxmanifest.template"));
        Assert.Contains("ms-resource:AppDisplayName", packageTemplate);
        Assert.Contains("ms-resource:AppDescription", packageTemplate);
        Assert.Contains("Name=\"internetClient\"", packageTemplate);
        Assert.Contains("Name=\"runFullTrust\"", packageTemplate);
        Assert.Contains("Executable=\"DNSPilotWindows.App.exe\"", packageTemplate);
        Assert.DoesNotContain("requireAdministrator", packageTemplate);
        Assert.DoesNotContain("highestAvailable", packageTemplate);

        var packageManifest = File.ReadAllText(Path.Combine(appRoot, "Package.appxmanifest"));
        Assert.Contains("ms-resource:AppDisplayName", packageManifest);
        Assert.Contains("ms-resource:AppDescription", packageManifest);
        Assert.Contains("Name=\"DNSPilot.Windows.Store\"", packageManifest);
        Assert.Contains("Name=\"internetClient\"", packageManifest);
        Assert.Contains("Name=\"runFullTrust\"", packageManifest);
        Assert.Contains("Executable=\"DNSPilotWindows.App.exe\"", packageManifest);
        Assert.DoesNotContain("REPLACE_WITH_PARTNER_CENTER_PUBLISHER", packageManifest);
        Assert.DoesNotContain("requireAdministrator", packageManifest);
        Assert.DoesNotContain("highestAvailable", packageManifest);

        var projectFile = File.ReadAllText(Path.Combine(appRoot, "DNSPilotWindows.App.csproj"));
        Assert.Contains("PRIResource Include=\"Strings\\**\\*.resw\"", projectFile);
        Assert.Contains("Content Include=\"dnspilot-cli.exe\"", projectFile);
        Assert.Contains("CopyToOutputDirectory=\"PreserveNewest\"", projectFile);
        Assert.Contains("<EnableMsixTooling>true</EnableMsixTooling>", projectFile);
        Assert.Contains("<EnableDefaultPriItems>false</EnableDefaultPriItems>", projectFile);
        Assert.Contains("<PublishProfile>Properties\\PublishProfiles\\win10-$(Platform).pubxml</PublishProfile>", projectFile);

        var launchSettings = File.ReadAllText(Path.Combine(appRoot, "Properties", "launchSettings.json"));
        Assert.Contains("\"commandName\": \"MsixPackage\"", launchSettings);

        var publishProfile = File.ReadAllText(Path.Combine(appRoot, "Properties", "PublishProfiles", "win10-x64.pubxml"));
        Assert.Contains("<GenerateAppxPackageOnBuild>true</GenerateAppxPackageOnBuild>", publishProfile);
        Assert.Contains("<AppxBundle>Never</AppxBundle>", publishProfile);
        Assert.Contains("<AppxPackageSigningEnabled>false</AppxPackageSigningEnabled>", publishProfile);
        Assert.Contains("<AppxPackageDir>AppPackages\\</AppxPackageDir>", publishProfile);

        var assetsRoot = Path.Combine(appRoot, "Assets");
        AssertPngDimensions(Path.Combine(assetsRoot, "StoreLogo.png"), 50, 50);
        AssertPngDimensions(Path.Combine(assetsRoot, "Square44x44Logo.png"), 44, 44);
        AssertPngDimensions(Path.Combine(assetsRoot, "Square150x150Logo.png"), 150, 150);
        AssertPngDimensions(Path.Combine(assetsRoot, "Wide310x150Logo.png"), 310, 150);
        AssertPngDimensions(Path.Combine(assetsRoot, "SplashScreen.png"), 620, 300);
    }

    private static void WindowsShellConfirmsAndSerializesPersistentDeletionActions()
    {
        var repoRoot = FindRepoRoot();
        var mainWindow = File.ReadAllText(Path.Combine(
            repoRoot,
            "apps",
            "windows",
            "DNSPilotWindows",
            "app",
            "DNSPilotWindows.App",
            "MainWindow.xaml.cs"));

        Assert.Contains("Delete DNS profile?", mainWindow);
        Assert.Contains("Delete domain suite?", mainWindow);
        Assert.Contains("Delete benchmark history?", mainWindow);
        Assert.Contains("Clear benchmark history?", mainWindow);
        Assert.Contains("ConfirmDestructiveActionAsync", mainWindow);
        Assert.Contains("RunWithButtonDisabledAsync", mainWindow);
        Assert.Contains("DefaultButton = ContentDialogButton.Close", mainWindow);
    }

    private static void WindowsShellSerializesBenchmarkLaunches()
    {
        var repoRoot = FindRepoRoot();
        var appRoot = Path.Combine(repoRoot, "apps", "windows", "DNSPilotWindows", "app", "DNSPilotWindows.App");
        var mainWindow = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml.cs"));
        var xaml = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml"));

        Assert.Contains("private bool _benchmarkRunning;", mainWindow);
        Assert.Contains("if (_benchmarkRunning)", mainWindow);
        Assert.Contains("SetBenchmarkActionsEnabled(false)", mainWindow);
        Assert.Contains("SetBenchmarkActionsEnabled(true)", mainWindow);
        Assert.True(
            mainWindow.IndexOf("if (_benchmarkRunning)", StringComparison.Ordinal)
                < mainWindow.IndexOf("_progressEvents.Clear()", StringComparison.Ordinal),
            "The single-flight guard must run before benchmark UI/progress state is mutated.");
        Assert.Contains("x:Name=\"QuickBenchmarkButton\"", xaml);
        Assert.Contains("x:Name=\"ValidateSystemDnsButton\"", xaml);
        Assert.Contains("x:Name=\"RunBenchmarkButton\"", xaml);
    }

    private static void WindowsAppUsesRuntimeReadinessForStartupRecoveryAndGating()
    {
        var repoRoot = FindRepoRoot();
        var appRoot = Path.Combine(repoRoot, "apps", "windows", "DNSPilotWindows", "app", "DNSPilotWindows.App");
        var mainWindow = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml.cs"));
        var xaml = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml"));

        Assert.Contains("new RuntimeContractLoader().Load", mainWindow);
        Assert.Contains("WindowsShellViewModel.CreateFromRuntimeLoad", mainWindow);
        Assert.DoesNotContain("new CatalogRunner(executablePath).Load()", mainWindow);
        Assert.DoesNotContain("WindowsShellViewModel.CreateLoaded(", mainWindow);
        Assert.Contains("RenderRuntimeReadiness", mainWindow);
        Assert.Contains("SetRuntimeSurfaceAvailability", mainWindow);
        Assert.Contains("ViewModel.RuntimeReadiness.CanBenchmark", mainWindow);
        Assert.Contains("ViewModel.RuntimeReadiness.CanApplyGuidance", mainWindow);
        Assert.Contains("RetryRuntime_Click", mainWindow);
        Assert.Contains("x:Name=\"RuntimeStatusBar\"", xaml);
        Assert.Contains("Click=\"RetryRuntime_Click\"", xaml);
        Assert.Contains("x:Name=\"RetryRuntimeButton\"", xaml);
    }

    private static void WindowsAppFollowsConsumerNavigationContract()
    {
        var repoRoot = FindRepoRoot();
        var appRoot = Path.Combine(repoRoot, "apps", "windows", "DNSPilotWindows", "app", "DNSPilotWindows.App");
        var mainWindow = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml.cs"));
        var xaml = File.ReadAllText(Path.Combine(appRoot, "MainWindow.xaml"));

        Assert.Contains("x:Uid=\"NavCheckDns\"", xaml);
        Assert.Contains("x:Uid=\"NavProfiles\"", xaml);
        Assert.Contains("x:Uid=\"NavHistory\"", xaml);
        Assert.DoesNotContain("x:Uid=\"NavApply\"", xaml);
        Assert.DoesNotContain("x:Uid=\"NavSuites\"", xaml);
        Assert.DoesNotContain("x:Uid=\"NavDiagnostics\"", xaml);
        Assert.Contains("x:Name=\"HistorySection\"", xaml);
        Assert.Contains("x:Name=\"AdvancedDiagnosticsExpander\"", xaml);
        Assert.Contains("VisualState x:Name=\"CompactLayout\"", xaml);
        Assert.Contains("VisualState x:Name=\"WideLayout\"", xaml);
        Assert.Contains("AutomationProperties.LiveSetting=\"Polite\"", xaml);
        Assert.Contains("KeyboardAccelerator", xaml);
        Assert.Contains("ShowConsumerDestination", mainWindow);
        Assert.Contains("ApplyResponsiveLayout", mainWindow);
        Assert.Contains("QuickBenchmarkAccelerator_Invoked", mainWindow);
        Assert.Contains("SettingsAccelerator_Invoked", mainWindow);
        Assert.Contains("HelpAccelerator_Invoked", mainWindow);
    }

    private static void MacOsValidationOnlyToleratesWindowsXamlCompilerFailure()
    {
        var repoRoot = FindRepoRoot();
        var validationScript = File.ReadAllText(Path.Combine(repoRoot, "apps", "windows", "validate-windows-lane.sh"));

        Assert.Contains("winui_build_log", validationScript);
        Assert.Contains("if [[ \"$(uname -s)\" == \"Darwin\" ]] && rg -q", validationScript);
        Assert.Contains("XamlCompiler\\.exe: (cannot execute binary file|Bad CPU type in executable)", validationScript);
        Assert.Contains("WinUI build failed for a reason other than the Windows-only XAML compiler.", validationScript);
    }

    private static void AssertPngDimensions(string path, int expectedWidth, int expectedHeight)
    {
        Assert.True(File.Exists(path), $"Expected PNG asset to exist: {path}");

        var bytes = File.ReadAllBytes(path);
        Assert.True(bytes.Length >= 24, $"Expected PNG asset to include an IHDR chunk: {path}");
        Assert.SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }, bytes.Take(8));
        Assert.Equal(expectedWidth, ReadBigEndianInt32(bytes, 16));
        Assert.Equal(expectedHeight, ReadBigEndianInt32(bytes, 20));
    }

    private static int ReadBigEndianInt32(byte[] bytes, int offset)
    {
        return (bytes[offset] << 24)
            | (bytes[offset + 1] << 16)
            | (bytes[offset + 2] << 8)
            | bytes[offset + 3];
    }

    private static void WindowsPublishDocsIncludePrivacyListingAndCertificationCopy()
    {
        var repoRoot = FindRepoRoot();
        var windowsRoot = Path.Combine(repoRoot, "apps", "windows");
        var privacy = File.ReadAllText(Path.Combine(windowsRoot, "windows-privacy.md"));
        var listing = File.ReadAllText(Path.Combine(windowsRoot, "windows-store-listing.md"));
        var publish = File.ReadAllText(Path.Combine(windowsRoot, "windows-publish.md"));
        var packagePrep = File.ReadAllText(Path.Combine(windowsRoot, "Prepare-WindowsStorePackage.ps1"));

        Assert.Contains("Privacy Policy Draft", privacy);
        Assert.Contains("DNS queries", privacy);
        Assert.Contains("TCP connection probes", privacy);
        Assert.Contains("stored locally", privacy);
        Assert.Contains("does not sell", privacy);
        Assert.Contains("no silent DNS mutation", privacy);
        Assert.Contains("REPLACE_WITH_PRIVACY_POLICY_URL", privacy);
        Assert.Contains("REPLACE_WITH_SUPPORT_URL", privacy);

        Assert.Contains("Store Listing Draft", listing);
        Assert.Contains("DNS Pilot", listing);
        Assert.Contains("benchmark, copy guidance, open Windows settings, validate current DNS", listing);
        Assert.Contains("runFullTrust justification", listing);
        Assert.Contains("Privacy policy URL", listing);
        Assert.Contains("Support URL", listing);
        Assert.Contains("Notes for certification", listing);

        Assert.Contains("windows-privacy.md", publish);
        Assert.Contains("windows-store-listing.md", publish);
        Assert.Contains("Prepare-WindowsStorePackage.ps1", publish);
        Assert.Contains("-IdentityName", publish);
        Assert.Contains("-Publisher", publish);
        Assert.Contains("-Version", publish);
        Assert.Contains("Partner Center Properties", publish);

        Assert.Contains("[Parameter(Mandatory = $true)]", packagePrep);
        Assert.Contains("$IdentityName", packagePrep);
        Assert.Contains("$Publisher", packagePrep);
        Assert.Contains("$Version", packagePrep);
        Assert.Contains("Package.Store.appxmanifest.template", packagePrep);
        Assert.Contains("Package.appxmanifest", packagePrep);
        Assert.Contains("REPLACE_WITH_PARTNER_CENTER_PUBLISHER", packagePrep);
        Assert.Contains("Version must use four numeric parts", packagePrep);
        Assert.Contains("IsPathRooted", packagePrep);
        Assert.Contains("Get-Content -Raw -Path $resolvedOutputPath", packagePrep);
        Assert.Contains("Generated Store package manifest", packagePrep);
        Assert.Contains("Package.appxmanifest", publish);
        Assert.Contains("GenerateAppxPackageOnBuild=true", publish);
    }

    private static void WindowsReadmeDocumentsInstallRunValidationAndPackageSteps()
    {
        var repoRoot = FindRepoRoot();
        var readme = File.ReadAllText(Path.Combine(repoRoot, "apps", "windows", "README.md"));

        Assert.Contains("# DNS Pilot Windows", readme);
        Assert.Contains("## Requirements", readme);
        Assert.Contains("## Install Dependencies", readme);
        Assert.Contains("dotnet restore apps\\windows\\DNSPilotWindows\\DNSPilotWindows.slnx", readme);
        Assert.Contains("cargo build --release -p dnspilot-cli", readme);
        Assert.Contains("DNSPILOT_CLI_PATH", readme);
        Assert.Contains("## Validate", readme);
        Assert.Contains("Validate-WindowsLane.ps1 -Configuration Release", readme);
        Assert.Contains("bash apps/windows/validate-windows-lane.sh", readme);
        Assert.Contains("## Run The App", readme);
        Assert.Contains("dotnet run --project apps\\windows\\DNSPilotWindows\\app\\DNSPilotWindows.App\\DNSPilotWindows.App.csproj", readme);
        Assert.Contains("MsixPackage", readme);
        Assert.Contains("## Build Store Package", readme);
        Assert.Contains("Prepare-WindowsStorePackage.ps1", readme);
        Assert.Contains("GenerateAppxPackageOnBuild=true", readme);
        Assert.Contains("## Package Updates", readme);
        Assert.Contains("dotnet list apps\\windows\\DNSPilotWindows\\app\\DNSPilotWindows.App\\DNSPilotWindows.App.csproj package --outdated", readme);
        Assert.Contains("no UAC prompt", readme);
        Assert.Contains("no silent DNS mutation", readme);
    }

    private static string FindRepoRoot()
    {
        var current = new DirectoryInfo(Environment.CurrentDirectory);
        while (current is not null)
        {
            var marker = Path.Combine(current.FullName, "apps", "windows", "DNSPilotWindows", "app", "DNSPilotWindows.App", "MainWindow.xaml");
            if (File.Exists(marker))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root from test working directory.");
    }

    private static IReadOnlySet<string> LoadResourceKeys(string path)
    {
        var document = XDocument.Load(path);
        return document.Descendants("data")
            .Select(element => element.Attribute("name")?.Value)
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Select(name => name!)
            .ToHashSet(StringComparer.Ordinal);
    }

    private static void WindowsDynamicShellTextFollowsCurrentUiCulture()
    {
        using var culture = new CultureScope("vi-VN");

        var failure = new BenchmarkExecutionFailure(
            BenchmarkFailureStep.MeasuringConnection,
            "TCP timeout",
            TimeSpan.FromMilliseconds(250),
            "debug log");
        var report = failure.CopyableReport(WindowsDisplayText.ModeLabel(BenchmarkMode.DnsAndTcp));
        Assert.Contains("Benchmark thất bại", report);
        Assert.Contains("Chế độ: DNS + TCP", report);
        Assert.Contains("Bước lỗi: Đo TCP", report);
        Assert.Contains("Gợi ý:", report);

        var progress = BenchmarkProgressViewModel.From(
            BenchmarkMode.DnsAndTcp,
            BenchmarkRunState.Running,
            TestData.Plan(mode: BenchmarkMode.DnsAndTcp).ProgressSummary);
        Assert.Contains("Đang phân giải DNS", string.Join("\n", progress.CurrentStepLines));
        Assert.Contains("Đang chạy", progress.ResolverStatuses.First().Detail);

        var guidance = ApplyGuidanceViewModel.FromPlan(new ApplyPlan(
            ApplyDecision.Guide,
            "Cloudflare",
            new[] { "1.1.1.1" },
            "1.1.1.1:53",
            "copy"));
        Assert.Equal("Sao chép DNS server", guidance.Actions.First().Label);
        Assert.Contains("Không có thay đổi DNS âm thầm", guidance.CopyableChecklist);

        var invalidProfile = new CustomDnsProfileFormViewModel("", "999.1.1.1", "not:ipv6");
        Assert.Contains("Tên hồ sơ là bắt buộc.", string.Join("\n", invalidProfile.Validation.Issues));
        Assert.Contains("DNS server IPv4 không hợp lệ: 999.1.1.1", string.Join("\n", invalidProfile.Validation.Issues));

        var history = new BenchmarkHistoryViewModel(BenchmarkHistoryJsonDecoder.Decode(SampleJson.HistoryList), TestData.Catalog);
        Assert.Equal("Khuyến nghị: Cloudflare", history.Rows.Single().RecommendationLabel);
        Assert.Equal("Kiểm tra lại trước khi áp dụng khuyến nghị đã lưu", history.Rows.Single().ApplyGuidanceLabel);

        var resultReport = BenchmarkResultReportViewModel.FromResult(BenchmarkResultJsonDecoder.Decode(SampleJson.BenchmarkResult));
        Assert.Contains("Kết quả benchmark", resultReport.CopyableReport);
        Assert.Contains("Sức khỏe: Tốt", resultReport.CopyableReport);
        Assert.Contains("Hồ sơ khuyến nghị: cloudflare", resultReport.CopyableReport);
        Assert.Contains("Khuyến nghị: cloudflare (cao, điểm 0.98)", resultReport.RecommendationLine);
        Assert.Contains("Lý do: Best overall path.", resultReport.CopyableReport);
        Assert.Contains("Cảnh báo: Path comparison estimates DNS plus TCP connect timing only.", resultReport.CopyableReport);

        var tray = TrayQuickActionsViewModel.CreateDefault(TestData.Catalog);
        Assert.Equal("Benchmark nhanh", tray.Actions.First().Label);
        Assert.Equal("Kiểm tra DNS hiện tại", tray.Actions.Skip(1).First().Label);
    }

    private sealed class CultureScope : IDisposable
    {
        private readonly CultureInfo _currentCulture;
        private readonly CultureInfo _currentUiCulture;

        public CultureScope(string cultureName)
        {
            _currentCulture = CultureInfo.CurrentCulture;
            _currentUiCulture = CultureInfo.CurrentUICulture;
            var culture = new CultureInfo(cultureName);
            CultureInfo.CurrentCulture = culture;
            CultureInfo.CurrentUICulture = culture;
        }

        public void Dispose()
        {
            CultureInfo.CurrentCulture = _currentCulture;
            CultureInfo.CurrentUICulture = _currentUiCulture;
        }
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

internal static class SampleJson
{
    public const string Catalog = """
    {
      "schema_version": 1,
      "profiles": [
        {
          "id": "cloudflare",
          "name": "Cloudflare",
          "description": "Fast unfiltered public DNS.",
          "ipv4_servers": ["1.1.1.1", "1.0.0.1"],
          "ipv6_servers": ["2606:4700:4700::1111", "2606:4700:4700::1001"],
          "protocol": "plain",
          "doh_url": null,
          "dot_hostname": null,
          "tags": ["general", "unfiltered"],
          "use_case": "performance",
          "filtering_type": "none",
          "security_notes": [],
          "provider_metadata": {},
          "created_at": null,
          "updated_at": null
        }
      ],
      "testSuites": [
        {
          "id": "developer",
          "name": "Developer",
          "description": "Developer workflow checks.",
          "domains": ["github.com", "microsoft.com"],
          "tags": ["developer"]
        }
      ]
    }
    """;

    public const string Capabilities = """
    {
      "schema_version": 1,
      "capabilities": [
        {
          "platform": "windows-store",
          "can_benchmark": true,
          "apply": "guided-settings",
          "flush": "guided-user-action",
          "store_safe": true,
          "notes": ["Store builds must not depend on administrator elevation."]
        },
        {
          "platform": "windows-power",
          "can_benchmark": true,
          "apply": "desktop-admin-service",
          "flush": "desktop-admin-service",
          "store_safe": false,
          "notes": ["Power edition is separate from store-safe builds."]
        }
      ]
    }
    """;

    public const string ApplyPlan = """
    {
      "schema_version": 1,
      "platform": "windows-store",
      "apply_capability": "guided-settings",
      "disposition": "guide-only",
      "profile_id": "cloudflare",
      "profile_name": "Cloudflare",
      "tested_resolver": "1.1.1.1:53",
      "dns_servers": ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"],
      "can_apply": false,
      "notes": [
        "Platform requires guided settings; do not perform hidden DNS changes.",
        "Store-safe build must guide plain DNS changes through OS settings."
      ]
    }
    """;

    public const string ProtectedApplyPlan = """
    {
      "schema_version": 1,
      "platform": "windows-store",
      "apply_capability": "guided-settings",
      "disposition": "protect-current-dns",
      "profile_id": null,
      "profile_name": null,
      "tested_resolver": "1.1.1.1:53",
      "dns_servers": [],
      "can_apply": false,
      "notes": [
        "VPN is active; protect current DNS and avoid apply prompts."
      ]
    }
    """;

    public const string ProfileList = """
    {
      "db": "/tmp/dnspilot.sqlite",
      "profile_count": 2,
      "schema_version": 1,
      "profiles": [
        {
          "id": "cloudflare",
          "name": "Cloudflare",
          "description": "Fast unfiltered public DNS.",
          "ipv4_servers": ["1.1.1.1", "1.0.0.1"],
          "ipv6_servers": ["2606:4700:4700::1111"],
          "protocol": "plain",
          "doh_url": null,
          "dot_hostname": null,
          "tags": ["general"],
          "use_case": "performance",
          "filtering_type": "none",
          "security_notes": [],
          "provider_metadata": {},
          "created_at": null,
          "updated_at": null
        },
        {
          "id": "lab-dns",
          "name": "Lab DNS",
          "description": "Custom DNS profile.",
          "ipv4_servers": ["1.1.1.1"],
          "ipv6_servers": ["2606:4700:4700::1111"],
          "protocol": "plain",
          "doh_url": null,
          "dot_hostname": null,
          "tags": [],
          "use_case": "custom",
          "filtering_type": "none",
          "security_notes": [],
          "provider_metadata": {},
          "created_at": null,
          "updated_at": null
        }
      ]
    }
    """;

    public const string SuiteList = """
    {
      "db": "/tmp/dnspilot.sqlite",
      "test_suite_count": 1,
      "schema_version": 1,
      "test_suites": [
        {
          "id": "custom-azure-lab",
          "name": "Azure Lab",
          "description": "Custom domain test suite.",
          "domains": ["portal.azure.com", "login.microsoftonline.com"],
          "tags": ["custom", "azure"]
        }
      ]
    }
    """;

    public const string HistoryList = """
    {
      "db": "/tmp/dnspilot.sqlite",
      "schema_version": 1,
      "benchmark_history_count": 1,
      "benchmark_history": [
        {
          "id": "compare-run-1",
          "started_at": "started-1",
          "scope": "dns-only",
          "mode": "fastest-raw-dns",
          "domains": ["github.com", "azure.microsoft.com"],
          "resolver_profile_ids": ["cloudflare", "google"],
          "metrics": [
            {
              "profile_id": "cloudflare",
              "median_dns_latency_ms": 12.0,
              "p95_dns_latency_ms": 20.0,
              "failure_rate": 0.0,
              "timeout_rate": 0.0,
              "median_connect_latency_ms": 0.0,
              "ipv4_health": 1.0,
              "ipv6_health": 1.0,
              "priority_fit": 1.0
            }
          ],
          "gate": {
            "can_recommend": true,
            "health": "healthy",
            "primary_issue": "none",
            "notes": []
          },
          "recommendation_profile_id": "cloudflare",
          "notes": ["Saved by compare CLI."]
        }
      ]
    }
    """;

    public const string BenchmarkResult = """
    {
      "summary": {
        "measurement_scope": "dns-tcp",
        "mode": "best-overall",
        "health": "healthy",
        "primary_issue": "none",
        "can_recommend": true,
        "safety_notes": [],
        "resolver_count": 2,
        "domain_count": 1,
        "attempts_per_record": 1,
        "dns_timeout_ms": 500,
        "connect_timeout_ms": 500,
        "connect_port": 443,
        "max_connect_targets_per_domain": 2,
        "recommended_profile_id": "cloudflare"
      },
      "runs": [
        {
          "profile_id": "google",
          "resolver": "8.8.8.8:53",
          "metrics": {
            "profile_id": "google",
            "median_dns_latency_ms": 18.0,
            "p95_dns_latency_ms": 22.0,
            "failure_rate": 0.0,
            "timeout_rate": 0.0,
            "median_connect_latency_ms": 44.0,
            "ipv4_health": 1.0,
            "ipv6_health": 1.0,
            "priority_fit": 1.0
          },
          "caveats": []
        },
        {
          "profile_id": "cloudflare",
          "resolver": "1.1.1.1:53",
          "metrics": {
            "profile_id": "cloudflare",
            "median_dns_latency_ms": 12.5,
            "p95_dns_latency_ms": 16.0,
            "failure_rate": 0.0,
            "timeout_rate": 0.0,
            "median_connect_latency_ms": 31.0,
            "ipv4_health": 1.0,
            "ipv6_health": 1.0,
            "priority_fit": 1.0
          },
          "caveats": []
        }
      ],
      "recommendation": {
        "decision": { "apply-profile": "cloudflare" },
        "profile_id": "cloudflare",
        "score": 0.98,
        "confidence": "high",
        "reasons": ["Best overall path."],
        "caveats": []
      },
      "saved_history_id": "windows-run-1",
      "warning": "Path comparison estimates DNS plus TCP connect timing only."
    }
    """;
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

    public static void Throws<TException>(Action action)
        where TException : Exception
    {
        try
        {
            action();
        }
        catch (TException)
        {
            return;
        }

        throw new InvalidOperationException($"Expected exception {typeof(TException).Name}.");
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

internal sealed class ScriptedProcessRunner : ICliProcessRunner
{
    private readonly IReadOnlyDictionary<string, CliProcessOutput> _outputs;

    public ScriptedProcessRunner(IReadOnlyDictionary<string, CliProcessOutput> outputs)
    {
        _outputs = outputs;
    }

    public int InvocationCount { get; private set; }

    public CliProcessOutput Run(string executablePath, IReadOnlyList<string> arguments, Action<BenchmarkProgressEvent>? progressHandler)
    {
        InvocationCount++;
        var command = arguments.FirstOrDefault() ?? "";
        return _outputs.TryGetValue(command, out var output)
            ? output
            : new CliProcessOutput(127, "", $"No scripted output for {command}.");
    }
}
