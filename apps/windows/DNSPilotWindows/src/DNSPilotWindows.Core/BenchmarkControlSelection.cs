namespace DNSPilotWindows.Core;

public sealed record BenchmarkControlSelection(
    int ModeIndex,
    int RecordFamilyIndex,
    int ResolverFamilyIndex,
    int Attempts,
    int DnsTimeoutMs,
    int TcpTimeoutMs,
    int TcpTargetsPerDomain,
    IReadOnlyList<string>? SelectedProfileIds = null,
    string? SelectedSuiteId = null);

public static class BenchmarkControlPlanFactory
{
    public static BenchmarkPlanViewModel Build(CatalogSnapshot catalog, BenchmarkControlSelection selection)
    {
        var mode = selection.ModeIndex switch
        {
            0 => BenchmarkMode.DnsOnly,
            2 => BenchmarkMode.SystemDnsValidation,
            _ => BenchmarkMode.DnsAndTcp,
        };

        return Build(catalog, selection, mode, forceGamingMode: true);
    }

    public static BenchmarkPlanViewModel BuildQuickBenchmark(CatalogSnapshot catalog, BenchmarkControlSelection selection)
    {
        var quickSelection = selection with
        {
            Attempts = 1,
            SelectedProfileIds = catalog.Profiles
                .Where(profile => profile.Protocol == DnsProtocol.Plain)
                .Take(2)
                .Select(profile => profile.Id)
                .ToArray(),
            SelectedSuiteId = catalog.TestSuites
                .FirstOrDefault(suite => !suite.Tags.Contains("gaming", StringComparer.OrdinalIgnoreCase))?.Id
                ?? catalog.TestSuites.FirstOrDefault()?.Id,
        };
        return Build(catalog, quickSelection, BenchmarkMode.DnsOnly, forceGamingMode: false);
    }

    public static BenchmarkPlanViewModel BuildSystemDnsValidation(CatalogSnapshot catalog, BenchmarkControlSelection selection)
    {
        return Build(catalog, selection, BenchmarkMode.SystemDnsValidation, forceGamingMode: false);
    }

    private static BenchmarkPlanViewModel Build(
        CatalogSnapshot catalog,
        BenchmarkControlSelection selection,
        BenchmarkMode mode,
        bool forceGamingMode)
    {
        var recordFamily = selection.RecordFamilyIndex switch
        {
            1 => DnsRecordFamily.Ipv4Only,
            2 => DnsRecordFamily.Ipv6Only,
            _ => DnsRecordFamily.Both,
        };
        var resolverFamily = selection.ResolverFamilyIndex switch
        {
            1 => ResolverAddressFamily.Ipv4Only,
            2 => ResolverAddressFamily.Ipv6Only,
            _ => ResolverAddressFamily.Automatic,
        };
        var selectedSuiteId = SelectedSuiteId(catalog, selection.SelectedSuiteId);
        var selectedSuite = selectedSuiteId is null
            ? null
            : catalog.TestSuites.FirstOrDefault(suite => suite.Id == selectedSuiteId);
        var modeWasForcedBySuite = forceGamingMode
            && selectedSuite?.Tags.Contains("gaming", StringComparer.OrdinalIgnoreCase) == true;
        var effectiveMode = modeWasForcedBySuite ? BenchmarkMode.DnsAndTcp : mode;
        var selectedProfiles = effectiveMode == BenchmarkMode.SystemDnsValidation
            ? Array.Empty<string>()
            : SelectedPlainProfileIds(catalog, selection.SelectedProfileIds);

        return new BenchmarkPlanViewModel(
            catalog,
            selectedProfiles,
            selectedSuiteId: selectedSuiteId,
            customDomains: Array.Empty<string>(),
            attempts: Math.Max(1, selection.Attempts),
            dnsTimeoutMs: Math.Max(1, selection.DnsTimeoutMs),
            connectTimeoutMs: Math.Max(1, selection.TcpTimeoutMs),
            maxConnectTargetsPerDomain: Math.Max(1, selection.TcpTargetsPerDomain),
            recordFamily: recordFamily,
            resolverAddressFamily: resolverFamily,
            mode: effectiveMode,
            modeWasForcedBySuite: modeWasForcedBySuite,
            suiteLimitationNotice: modeWasForcedBySuite ? selectedSuite?.Description : null);
    }

    private static IReadOnlyList<string> SelectedPlainProfileIds(
        CatalogSnapshot catalog,
        IReadOnlyList<string>? selectedProfileIds)
    {
        var plainProfileIds = catalog.Profiles
            .Where(profile => profile.Protocol == DnsProtocol.Plain)
            .Select(profile => profile.Id)
            .ToHashSet(StringComparer.Ordinal);

        if (selectedProfileIds is null)
        {
            return catalog.Profiles
                .Where(profile => plainProfileIds.Contains(profile.Id))
                .Take(3)
                .Select(profile => profile.Id)
                .ToArray();
        }

        var seen = new HashSet<string>(StringComparer.Ordinal);
        return selectedProfileIds
            .Where(profileId => plainProfileIds.Contains(profileId))
            .Where(profileId => seen.Add(profileId))
            .ToArray();
    }

    private static string? SelectedSuiteId(CatalogSnapshot catalog, string? selectedSuiteId)
    {
        if (selectedSuiteId is null)
        {
            return catalog.TestSuites.FirstOrDefault()?.Id;
        }

        return catalog.TestSuites.Any(suite => suite.Id == selectedSuiteId)
            ? selectedSuiteId
            : catalog.TestSuites.FirstOrDefault()?.Id;
    }
}
