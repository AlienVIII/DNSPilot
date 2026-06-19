namespace DNSPilotWindows.Core;

public enum TrayActionKind
{
    QuickBenchmark,
    ValidateSystemDns,
    OpenSettings,
}

public sealed record TrayActionDescriptor(
    TrayActionKind Kind,
    string Label,
    string Detail);

public sealed class TrayQuickActionsViewModel
{
    private TrayQuickActionsViewModel(
        IReadOnlyList<TrayActionDescriptor> actions,
        BenchmarkPlanViewModel quickBenchmarkPlan,
        BenchmarkPlanViewModel validateSystemDnsPlan,
        WindowsSettingsUri openSettingsUri)
    {
        Actions = actions;
        QuickBenchmarkPlan = quickBenchmarkPlan;
        ValidateSystemDnsPlan = validateSystemDnsPlan;
        OpenSettingsUri = openSettingsUri;
    }

    public IReadOnlyList<TrayActionDescriptor> Actions { get; }
    public BenchmarkPlanViewModel QuickBenchmarkPlan { get; }
    public BenchmarkPlanViewModel ValidateSystemDnsPlan { get; }
    public WindowsSettingsUri OpenSettingsUri { get; }

    public static TrayQuickActionsViewModel CreateDefault(CatalogSnapshot catalog)
    {
        var selectedProfiles = catalog.Profiles
            .Where(profile => profile.Protocol == DnsProtocol.Plain && profile.Ipv4Servers.Count > 0)
            .Take(3)
            .Select(profile => profile.Id)
            .ToArray();
        var selectedSuiteId = catalog.TestSuites.FirstOrDefault()?.Id;

        var quickBenchmarkPlan = new BenchmarkPlanViewModel(
            catalog,
            selectedProfiles,
            selectedSuiteId,
            customDomains: Array.Empty<string>(),
            attempts: 2,
            dnsTimeoutMs: 800,
            connectTimeoutMs: 1_000,
            maxConnectTargetsPerDomain: 4,
            recordFamily: DnsRecordFamily.Both,
            resolverAddressFamily: ResolverAddressFamily.Automatic,
            mode: BenchmarkMode.DnsAndTcp);

        var validateSystemDnsPlan = new BenchmarkPlanViewModel(
            catalog,
            selectedProfileIds: Array.Empty<string>(),
            selectedSuiteId: selectedSuiteId,
            customDomains: Array.Empty<string>(),
            attempts: 2,
            dnsTimeoutMs: 800,
            connectTimeoutMs: 1_000,
            maxConnectTargetsPerDomain: 4,
            recordFamily: DnsRecordFamily.Both,
            resolverAddressFamily: ResolverAddressFamily.Automatic,
            mode: BenchmarkMode.SystemDnsValidation);

        return new TrayQuickActionsViewModel(
            new[]
            {
                new TrayActionDescriptor(TrayActionKind.QuickBenchmark, "Quick benchmark", "Run the default DNS + TCP benchmark."),
                new TrayActionDescriptor(TrayActionKind.ValidateSystemDns, "Validate current DNS", "Benchmark the current Windows resolver path."),
                new TrayActionDescriptor(TrayActionKind.OpenSettings, "Open Network Settings", "Open Windows Network & internet settings."),
            },
            quickBenchmarkPlan,
            validateSystemDnsPlan,
            WindowsSettingsUri.NetworkAdvancedSettings);
    }
}
