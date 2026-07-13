namespace DNSPilotWindows.Core;

public sealed class WindowsShellViewModel
{
    private WindowsShellViewModel(
        string databasePath,
        CatalogSnapshot catalog,
        BenchmarkPlanViewModel benchmarkPlan,
        BenchmarkPlanViewModel systemDnsValidationPlan,
        ApplyGuidanceViewModel applyGuidance,
        TrayQuickActionsViewModel trayQuickActions,
        PlatformCapability storePlatformCapability,
        PlatformCapability powerPlatformCapability,
        IReadOnlyList<ProfileManagementRow> profileRows,
        IReadOnlyList<SuiteManagementRow> suiteRows,
        IReadOnlyList<BenchmarkHistoryRow> historyRows)
    {
        DatabasePath = databasePath;
        Catalog = catalog;
        BenchmarkPlan = benchmarkPlan;
        SystemDnsValidationPlan = systemDnsValidationPlan;
        ApplyGuidance = applyGuidance;
        TrayQuickActions = trayQuickActions;
        StorePlatformCapability = storePlatformCapability;
        PowerPlatformCapability = powerPlatformCapability;
        ProfileRows = profileRows;
        SuiteRows = suiteRows;
        HistoryRows = historyRows;
    }

    public string DatabasePath { get; }
    public CatalogSnapshot Catalog { get; }
    public BenchmarkPlanViewModel BenchmarkPlan { get; }
    public BenchmarkPlanViewModel SystemDnsValidationPlan { get; }
    public ApplyGuidanceViewModel ApplyGuidance { get; }
    public TrayQuickActionsViewModel TrayQuickActions { get; }
    public PlatformCapability StorePlatformCapability { get; }
    public PlatformCapability PowerPlatformCapability { get; }
    public IReadOnlyList<ProfileManagementRow> ProfileRows { get; }
    public IReadOnlyList<SuiteManagementRow> SuiteRows { get; }
    public IReadOnlyList<BenchmarkHistoryRow> HistoryRows { get; }
    public IReadOnlyList<BenchmarkProfileOptionRow> BenchmarkProfileOptions =>
        Catalog.Profiles
            .Select(profile => new BenchmarkProfileOptionRow(
                profile.Id,
                profile.Name,
                profile.Protocol,
                CanBenchmark: profile.Protocol == DnsProtocol.Plain && (profile.Ipv4Servers.Count > 0 || profile.Ipv6Servers.Count > 0),
                Detail: BenchmarkProfileDetail(profile)))
            .ToArray();
    public IReadOnlyList<BenchmarkSuiteOptionRow> BenchmarkSuiteOptions =>
        Catalog.TestSuites
            .Select(suite => new BenchmarkSuiteOptionRow(
                suite.Id,
                suite.Name,
                DomainCount: suite.Domains.Count,
                Detail: BenchmarkSuiteDetail(suite)))
            .ToArray();

    public IReadOnlyList<BenchmarkMode> AvailableBenchmarkModes { get; } = new[]
    {
        BenchmarkMode.DnsOnly,
        BenchmarkMode.DnsAndTcp,
        BenchmarkMode.SystemDnsValidation,
    };

    public IReadOnlyList<DnsRecordFamily> AvailableRecordFamilies { get; } = new[]
    {
        DnsRecordFamily.Both,
        DnsRecordFamily.Ipv4Only,
        DnsRecordFamily.Ipv6Only,
    };

    public IReadOnlyList<ResolverAddressFamily> AvailableResolverAddressFamilies { get; } = new[]
    {
        ResolverAddressFamily.Automatic,
        ResolverAddressFamily.Ipv4Only,
        ResolverAddressFamily.Ipv6Only,
    };

    public IReadOnlyList<string> ProfileListCommand => ProfileManagementCommands.List(DatabasePath);
    public IReadOnlyList<string> SuiteListCommand => SuiteManagementCommands.List(DatabasePath);
    public IReadOnlyList<string> HistoryListCommand => HistoryManagementCommands.List(DatabasePath);
    public WindowsCapabilityPolicy StorePolicy => WindowsCapabilityPolicy.StoreSafe;
    public WindowsCapabilityPolicy PowerPolicy => WindowsCapabilityPolicy.PowerEdition;

    public string BenchmarkControlHelpText => string.Join(
        Environment.NewLine,
        AvailableRecordFamilies.Select(family => $"{family.DisplayLabel}: {family.HelpText}")
            .Concat(AvailableResolverAddressFamilies.Select(family => $"{family.DisplayLabel}: {family.HelpText}")));

    public BenchmarkPlanViewModel BuildBenchmarkPlan(BenchmarkControlSelection selection)
    {
        return BenchmarkControlPlanFactory.Build(Catalog, selection);
    }

    public BenchmarkPlanViewModel BuildQuickBenchmarkPlan(BenchmarkControlSelection selection)
    {
        return BenchmarkControlPlanFactory.BuildQuickBenchmark(Catalog, selection);
    }

    public BenchmarkPlanViewModel BuildSystemDnsValidationPlan(BenchmarkControlSelection selection)
    {
        return BenchmarkControlPlanFactory.BuildSystemDnsValidation(Catalog, selection);
    }

    public static WindowsShellViewModel CreateDefault(string databasePath)
    {
        var catalog = WindowsDefaultCatalog.Create();
        var selectedProfiles = catalog.Profiles
            .Where(profile => profile.Protocol == DnsProtocol.Plain && profile.Ipv4Servers.Count > 0)
            .Take(3)
            .Select(profile => profile.Id)
            .ToArray();
        var selectedSuiteId = catalog.TestSuites.FirstOrDefault()?.Id;

        var benchmarkPlan = new BenchmarkPlanViewModel(
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

        var systemDnsValidationPlan = new BenchmarkPlanViewModel(
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

        var applyGuidance = ApplyGuidanceViewModel.FromPlan(
            new ApplyPlan(
                ApplyDecision.Block,
                WindowsDisplayText.Text("Apply guidance unavailable", "Hướng dẫn apply chưa sẵn sàng"),
                Array.Empty<string>(),
                TestedResolver: null,
                WindowsDisplayText.Text(
                    "Loading DNS Pilot safety policy; apply actions stay disabled.",
                    "Đang tải chính sách an toàn DNS Pilot; các thao tác apply vẫn bị tắt."))
            {
                Disposition = "loading-runtime-policy",
            });

        return new WindowsShellViewModel(
            databasePath,
            catalog,
            benchmarkPlan,
            systemDnsValidationPlan,
            applyGuidance,
            TrayQuickActionsViewModel.CreateDefault(catalog),
            DefaultStoreCapability(),
            DefaultPowerCapability(),
            catalog.Profiles.Select(profile => new ProfileManagementRow(
                profile.Id,
                profile.Name,
                CanEdit: profile.UseCase == "custom",
                CanDelete: profile.UseCase == "custom",
                profile.Ipv4Servers,
                profile.Ipv6Servers,
                string.IsNullOrWhiteSpace(profile.UseCase) ? "built-in" : profile.UseCase)).ToArray(),
            new SuiteManagementViewModel(catalog.TestSuites).Rows,
            Array.Empty<BenchmarkHistoryRow>());
    }

    public static WindowsShellViewModel CreateLoaded(
        string databasePath,
        CatalogSnapshot catalog,
        CapabilityMatrix capabilities,
        ApplyPlan applyPlan,
        ProfileListPayload profileList,
        SuiteListPayload suiteList,
        BenchmarkHistoryPayload history)
    {
        var benchmarkCatalog = MergeSuitesForBenchmark(MergeProfilesForBenchmark(catalog, profileList), suiteList);
        var selectedProfiles = benchmarkCatalog.Profiles
            .Where(profile => profile.Protocol == DnsProtocol.Plain && profile.Ipv4Servers.Count > 0)
            .Take(3)
            .Select(profile => profile.Id)
            .ToArray();
        var selectedSuiteId = benchmarkCatalog.TestSuites.FirstOrDefault()?.Id;
        var benchmarkPlan = new BenchmarkPlanViewModel(
            benchmarkCatalog,
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
        var systemDnsValidationPlan = new BenchmarkPlanViewModel(
            benchmarkCatalog,
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

        return new WindowsShellViewModel(
            databasePath,
            benchmarkCatalog,
            benchmarkPlan,
            systemDnsValidationPlan,
            ApplyGuidanceViewModel.FromPlan(applyPlan),
            TrayQuickActionsViewModel.CreateDefault(benchmarkCatalog),
            capabilities.RequirePlatform(BenchmarkPlanViewModel.WindowsStorePlatformId),
            capabilities.RequirePlatform("windows-power"),
            new ProfileManagementViewModel(profileList).Rows,
            new SuiteManagementViewModel(benchmarkCatalog.TestSuites).Rows,
            new BenchmarkHistoryViewModel(history, benchmarkCatalog).Rows);
    }

    public WindowsShellViewModel WithApplyPlan(ApplyPlan applyPlan)
    {
        return new WindowsShellViewModel(
            DatabasePath,
            Catalog,
            BenchmarkPlan,
            SystemDnsValidationPlan,
            ApplyGuidanceViewModel.FromPlan(applyPlan),
            TrayQuickActions,
            StorePlatformCapability,
            PowerPlatformCapability,
            ProfileRows,
            SuiteRows,
            HistoryRows);
    }

    private static PlatformCapability DefaultStoreCapability()
    {
        return new PlatformCapability(
            BenchmarkPlanViewModel.WindowsStorePlatformId,
            CanBenchmark: true,
            Apply: "guided-settings",
            Flush: "guided-user-action",
            StoreSafe: true,
            Notes: new[] { WindowsCapabilityPolicy.StoreSafe.Notes });
    }

    private static PlatformCapability DefaultPowerCapability()
    {
        return new PlatformCapability(
            "windows-power",
            CanBenchmark: true,
            Apply: "desktop-admin-service",
            Flush: "desktop-admin-service",
            StoreSafe: false,
            Notes: new[] { WindowsCapabilityPolicy.PowerEdition.Notes });
    }

    private static CatalogSnapshot MergeProfilesForBenchmark(
        CatalogSnapshot catalog,
        ProfileListPayload profileList)
    {
        var profiles = new List<CatalogProfile>();
        var indexById = new Dictionary<string, int>(StringComparer.Ordinal);

        void AddOrReplace(CatalogProfile profile)
        {
            if (indexById.TryGetValue(profile.Id, out var index))
            {
                profiles[index] = profile;
                return;
            }

            indexById[profile.Id] = profiles.Count;
            profiles.Add(profile);
        }

        foreach (var profile in catalog.Profiles)
        {
            AddOrReplace(profile);
        }

        foreach (var profile in profileList.Profiles)
        {
            AddOrReplace(profile);
        }

        return new CatalogSnapshot(profiles, catalog.TestSuites);
    }

    private static CatalogSnapshot MergeSuitesForBenchmark(
        CatalogSnapshot catalog,
        SuiteListPayload suiteList)
    {
        var suites = new List<CatalogTestSuite>();
        var indexById = new Dictionary<string, int>(StringComparer.Ordinal);

        void AddOrReplace(CatalogTestSuite suite)
        {
            if (indexById.TryGetValue(suite.Id, out var index))
            {
                suites[index] = suite;
                return;
            }

            indexById[suite.Id] = suites.Count;
            suites.Add(suite);
        }

        foreach (var suite in catalog.TestSuites)
        {
            AddOrReplace(suite);
        }

        foreach (var suite in suiteList.TestSuites)
        {
            AddOrReplace(suite);
        }

        return new CatalogSnapshot(catalog.Profiles, suites);
    }

    private static string BenchmarkProfileDetail(CatalogProfile profile)
    {
        var serverCount = profile.Ipv4Servers.Count + profile.Ipv6Servers.Count;
        var protocol = profile.Protocol == DnsProtocol.Plain
            ? "plain"
            : profile.Protocol.ToString().ToLowerInvariant();
        var source = string.IsNullOrWhiteSpace(profile.UseCase)
            ? WindowsDisplayText.Text("built-in", "built-in")
            : profile.UseCase;
        return WindowsDisplayText.Text(
            $"{protocol}, {serverCount} server(s), {source}",
            $"{protocol}, {serverCount} server, {source}");
    }

    private static string BenchmarkSuiteDetail(CatalogTestSuite suite)
    {
        var source = SuiteOwnershipPolicy.IsCustom(suite)
                ? "custom"
                : "built-in";
        return WindowsDisplayText.Text(
            $"{suite.Domains.Count} domain(s), {source}",
            $"{suite.Domains.Count} domain, {source}");
    }
}

public sealed record BenchmarkProfileOptionRow(
    string Id,
    string Name,
    DnsProtocol Protocol,
    bool CanBenchmark,
    string Detail)
{
    public override string ToString()
    {
        var availability = CanBenchmark
            ? Detail
            : WindowsDisplayText.Text("not benchmarkable in Store shell", "không benchmark được trong Store shell");
        return $"{Name} ({Id}) - {availability}";
    }
}

public sealed record BenchmarkSuiteOptionRow(
    string Id,
    string Name,
    int DomainCount,
    string Detail)
{
    public override string ToString()
    {
        return $"{Name} ({Id}) - {Detail}";
    }
}

public static class WindowsDefaultCatalog
{
    public static CatalogSnapshot Create()
    {
        return new CatalogSnapshot(
            Profiles: new[]
            {
                new CatalogProfile("cloudflare", "Cloudflare", DnsProtocol.Plain, new[] { "1.1.1.1", "1.0.0.1" }, new[] { "2606:4700:4700::1111", "2606:4700:4700::1001" }),
                new CatalogProfile("google", "Google", DnsProtocol.Plain, new[] { "8.8.8.8", "8.8.4.4" }, new[] { "2001:4860:4860::8888", "2001:4860:4860::8844" }),
                new CatalogProfile("quad9", "Quad9", DnsProtocol.Plain, new[] { "9.9.9.9", "149.112.112.112" }, new[] { "2620:fe::fe", "2620:fe::9" }),
            },
            TestSuites: new[]
            {
                new CatalogTestSuite("developer", "Developer", new[] { "github.com", "microsoft.com", "azure.microsoft.com" }),
                new CatalogTestSuite("daily", "Daily", new[] { "example.com", "cloudflare.com", "google.com" }),
            });
    }
}
