namespace DNSPilotWindows.Core;

public sealed record BenchmarkValidation(IReadOnlyList<string> Issues)
{
    public static BenchmarkValidation Valid { get; } = new(Array.Empty<string>());

    public bool CanRun => Issues.Count == 0;
}

public sealed record BenchmarkProgressResolverTarget(
    string Id,
    string Name,
    string Resolver);

public sealed record BenchmarkProgressPlanSummary(
    int ResolverCount,
    int DomainCount,
    int Attempts,
    int DnsTimeoutMs,
    int ConnectTimeoutMs,
    int MaxConnectTargetsPerDomain,
    DnsRecordFamily RecordFamily,
    IReadOnlyList<BenchmarkProgressResolverTarget> ResolverTargets);

public sealed class BenchmarkPlanViewModel
{
    public const string WindowsStorePlatformId = "windows-store";

    public BenchmarkPlanViewModel(
        CatalogSnapshot catalog,
        IReadOnlyList<string> selectedProfileIds,
        string? selectedSuiteId,
        IReadOnlyList<string> customDomains,
        int attempts,
        int dnsTimeoutMs,
        int connectTimeoutMs,
        int maxConnectTargetsPerDomain,
        DnsRecordFamily recordFamily,
        ResolverAddressFamily resolverAddressFamily,
        BenchmarkMode mode)
    {
        Catalog = catalog;
        SelectedProfileIds = selectedProfileIds;
        SelectedSuiteId = selectedSuiteId;
        CustomDomains = customDomains;
        Attempts = attempts;
        DnsTimeoutMs = dnsTimeoutMs;
        ConnectTimeoutMs = connectTimeoutMs;
        MaxConnectTargetsPerDomain = maxConnectTargetsPerDomain;
        RecordFamily = recordFamily;
        ResolverAddressFamily = resolverAddressFamily;
        Mode = mode;
    }

    public CatalogSnapshot Catalog { get; }
    public IReadOnlyList<string> SelectedProfileIds { get; }
    public string? SelectedSuiteId { get; }
    public IReadOnlyList<string> CustomDomains { get; }
    public int Attempts { get; }
    public int DnsTimeoutMs { get; }
    public int ConnectTimeoutMs { get; }
    public int MaxConnectTargetsPerDomain { get; }
    public DnsRecordFamily RecordFamily { get; }
    public ResolverAddressFamily ResolverAddressFamily { get; }
    public BenchmarkMode Mode { get; }
    public bool SupportsHistoryPersistence => Mode != BenchmarkMode.SystemDnsValidation;

    public IReadOnlyList<string> Domains
    {
        get
        {
            var suiteDomains = SelectedSuiteId is { } selectedSuiteId
                ? Catalog.TestSuites.FirstOrDefault(suite => suite.Id == selectedSuiteId)?.Domains ?? Array.Empty<string>()
                : Array.Empty<string>();

            return UniquePreservingOrder(suiteDomains.Concat(SanitizedCustomDomains));
        }
    }

    public IReadOnlyList<string> CommandArguments
    {
        get
        {
            if (Mode == BenchmarkMode.SystemDnsValidation)
            {
                return SystemDnsCommandArguments();
            }

            var arguments = new List<string> { Mode.CommandName };
            foreach (var resolver in PlainResolvers)
            {
                arguments.Add("--resolver");
                arguments.Add($"{resolver.Id}={resolver.SocketAddress}");
            }

            AppendSharedDomainArguments(arguments);
            arguments.Add("--attempts");
            arguments.Add(Attempts.ToStringInvariant());
            arguments.Add("--ip-family");
            arguments.Add(RecordFamily.CliValue);

            if (Mode == BenchmarkMode.DnsAndTcp)
            {
                arguments.Add("--dns-timeout-ms");
                arguments.Add(DnsTimeoutMs.ToStringInvariant());
                arguments.Add("--connect-timeout-ms");
                arguments.Add(ConnectTimeoutMs.ToStringInvariant());
                arguments.Add("--max-connect-targets-per-domain");
                arguments.Add(MaxConnectTargetsPerDomain.ToStringInvariant());
            }
            else
            {
                arguments.Add("--timeout-ms");
                arguments.Add(DnsTimeoutMs.ToStringInvariant());
            }

            return arguments;
        }
    }

    public BenchmarkValidation Validation
    {
        get
        {
            var issues = new List<string>();

            if (Mode != BenchmarkMode.SystemDnsValidation && PlainResolvers.Count == 0)
            {
                issues.Add(ResolverAddressFamily.SummaryLabel is { }
                    ? WindowsDisplayText.Text(
                        $"Select at least one plain DNS profile with {ResolverAddressFamily.SummaryLabel}.",
                        $"Chọn ít nhất một hồ sơ DNS plain có {WindowsDisplayText.ResolverSummaryLabel(ResolverAddressFamily)}.")
                    : WindowsDisplayText.Text(
                        "Select at least one plain DNS profile.",
                        "Chọn ít nhất một hồ sơ DNS plain."));
            }

            if (Domains.Count == 0)
            {
                issues.Add(WindowsDisplayText.Text(
                    "Select a test suite or add custom domains.",
                    "Chọn test suite hoặc thêm domain tùy chỉnh."));
            }

            if (Attempts < 1)
            {
                issues.Add(WindowsDisplayText.Text(
                    "Attempts must be at least 1.",
                    "Số lần thử phải ít nhất là 1."));
            }

            if (DnsTimeoutMs < 1)
            {
                issues.Add(WindowsDisplayText.Text(
                    "DNS timeout must be at least 1 ms.",
                    "DNS timeout phải ít nhất là 1 ms."));
            }

            if (Mode == BenchmarkMode.DnsAndTcp && ConnectTimeoutMs < 1)
            {
                issues.Add(WindowsDisplayText.Text(
                    "TCP timeout must be at least 1 ms.",
                    "TCP timeout phải ít nhất là 1 ms."));
            }

            if (Mode == BenchmarkMode.DnsAndTcp && MaxConnectTargetsPerDomain < 1)
            {
                issues.Add(WindowsDisplayText.Text(
                    "Max TCP targets per domain must be at least 1.",
                    "Số TCP target tối đa mỗi domain phải ít nhất là 1."));
            }

            foreach (var domain in SanitizedCustomDomains.Where(domain => !DomainNameValidator.IsValid(domain)))
            {
                issues.Add(WindowsDisplayText.Text(
                    $"Invalid custom domain: {domain}",
                    $"Domain tùy chỉnh không hợp lệ: {domain}"));
            }

            return issues.Count == 0 ? BenchmarkValidation.Valid : new BenchmarkValidation(issues);
        }
    }

    public BenchmarkProgressPlanSummary ProgressSummary => new(
        ResolverCount: PlainResolvers.Count,
        DomainCount: Domains.Count,
        Attempts: Attempts,
        DnsTimeoutMs: DnsTimeoutMs,
        ConnectTimeoutMs: ConnectTimeoutMs,
        MaxConnectTargetsPerDomain: MaxConnectTargetsPerDomain,
        RecordFamily: RecordFamily,
        ResolverTargets: PlainResolvers.Select(resolver => new BenchmarkProgressResolverTarget(resolver.Id, resolver.Name, resolver.SocketAddress)).ToArray());

    private IReadOnlyList<PlainResolver> PlainResolvers
    {
        get
        {
            return SelectedProfileIds
                .Select(id => Catalog.Profiles.FirstOrDefault(profile => profile.Id == id && profile.Protocol == DnsProtocol.Plain))
                .WhereNotNull()
                .Select(profile => new { Profile = profile, SocketAddress = ResolverAddressFamily.SocketAddressFor(profile) })
                .Where(item => item.SocketAddress is not null)
                .Select(item => new PlainResolver(item.Profile.Id, item.Profile.Name, item.SocketAddress!))
                .ToArray();
        }
    }

    private IReadOnlyList<string> SanitizedCustomDomains =>
        CustomDomains
            .Select(domain => domain.Trim())
            .Where(domain => domain.Length > 0)
            .ToArray();

    private IReadOnlyList<string> SystemDnsCommandArguments()
    {
        var arguments = new List<string>
        {
            Mode.CommandName,
            "--platform",
            WindowsStorePlatformId,
        };

        AppendSharedDomainArguments(arguments);
        arguments.Add("--attempts");
        arguments.Add(Attempts.ToStringInvariant());
        arguments.Add("--ip-family");
        arguments.Add(RecordFamily.CliValue);
        arguments.Add("--timeout-ms");
        arguments.Add(DnsTimeoutMs.ToStringInvariant());
        return arguments;
    }

    private void AppendSharedDomainArguments(List<string> arguments)
    {
        foreach (var domain in Domains)
        {
            arguments.Add("--domain");
            arguments.Add(domain);
        }
    }

    private static IReadOnlyList<string> UniquePreservingOrder(IEnumerable<string> values)
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var result = new List<string>();
        foreach (var value in values)
        {
            if (seen.Add(value))
            {
                result.Add(value);
            }
        }

        return result;
    }

    private sealed record PlainResolver(string Id, string Name, string SocketAddress);
}
