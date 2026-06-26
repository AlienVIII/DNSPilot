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
                new TrayActionDescriptor(
                    TrayActionKind.QuickBenchmark,
                    WindowsDisplayText.Text("Quick benchmark", "Benchmark nhanh"),
                    WindowsDisplayText.Text("Run the default DNS + TCP benchmark.", "Chạy benchmark DNS + TCP mặc định.")),
                new TrayActionDescriptor(
                    TrayActionKind.ValidateSystemDns,
                    WindowsDisplayText.Text("Validate current DNS", "Kiểm tra DNS hiện tại"),
                    WindowsDisplayText.Text("Benchmark the current Windows resolver path.", "Benchmark đường DNS hiện tại của Windows.")),
                new TrayActionDescriptor(
                    TrayActionKind.OpenSettings,
                    WindowsDisplayText.Text("Open Network Settings", "Mở cài đặt mạng"),
                    WindowsDisplayText.Text("Open Windows Network & internet settings.", "Mở Windows Network & internet settings.")),
            },
            quickBenchmarkPlan,
            validateSystemDnsPlan,
            WindowsSettingsUri.NetworkAdvancedSettings);
    }
}
