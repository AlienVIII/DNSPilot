namespace DNSPilotWindows.Core;

public sealed record BenchmarkControlSelection(
    int ModeIndex,
    int RecordFamilyIndex,
    int ResolverFamilyIndex,
    int Attempts,
    int DnsTimeoutMs,
    int TcpTimeoutMs,
    int TcpTargetsPerDomain);

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
        var selectedProfiles = mode == BenchmarkMode.SystemDnsValidation
            ? Array.Empty<string>()
            : catalog.Profiles
                .Where(profile => profile.Protocol == DnsProtocol.Plain)
                .Take(3)
                .Select(profile => profile.Id)
                .ToArray();

        return new BenchmarkPlanViewModel(
            catalog,
            selectedProfiles,
            selectedSuiteId: catalog.TestSuites.FirstOrDefault()?.Id,
            customDomains: Array.Empty<string>(),
            attempts: Math.Max(1, selection.Attempts),
            dnsTimeoutMs: Math.Max(1, selection.DnsTimeoutMs),
            connectTimeoutMs: Math.Max(1, selection.TcpTimeoutMs),
            maxConnectTargetsPerDomain: Math.Max(1, selection.TcpTargetsPerDomain),
            recordFamily: recordFamily,
            resolverAddressFamily: resolverFamily,
            mode: mode);
    }
}
