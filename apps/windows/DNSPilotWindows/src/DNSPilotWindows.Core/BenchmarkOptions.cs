namespace DNSPilotWindows.Core;

public readonly record struct BenchmarkMode(string CommandName, string DisplayLabel, string HelpText)
{
    public static BenchmarkMode DnsOnly { get; } = new(
        "compare",
        "DNS only",
        "Measures DNS lookup latency and reliability only.");

    public static BenchmarkMode DnsAndTcp { get; } = new(
        "path-compare",
        "DNS + TCP",
        "Measures DNS lookup, then TCP connect to resolved endpoints.");

    public static BenchmarkMode SystemDnsValidation { get; } = new(
        "system-benchmark",
        "System DNS validation",
        "Measures the current Windows resolver path after a manual DNS change.");
}

public readonly record struct DnsRecordFamily(string CliValue, string DisplayLabel, string HelpText, int RecordTypeCount)
{
    public static DnsRecordFamily Both { get; } = new(
        "both",
        "A + AAAA",
        "Query both A and AAAA records. A returns IPv4 addresses; AAAA returns IPv6 addresses.",
        2);

    public static DnsRecordFamily Ipv4Only { get; } = new(
        "ipv4-only",
        "A only",
        "Query A records only, so the run tests IPv4 answers without IPv6 noise.",
        1);

    public static DnsRecordFamily Ipv6Only { get; } = new(
        "ipv6-only",
        "AAAA only",
        "Query AAAA records only, so the run tests IPv6 answers and IPv6 reachability.",
        1);
}

public readonly record struct ResolverAddressFamily(string DisplayLabel, string HelpText, string? SummaryLabel)
{
    public static ResolverAddressFamily Automatic { get; } = new(
        "Auto",
        "Use each profile's IPv4 DNS server first, then fall back to IPv6 if needed.",
        null);

    public static ResolverAddressFamily Ipv4Only { get; } = new(
        "IPv4",
        "Benchmark only IPv4 DNS server addresses, such as 1.1.1.1.",
        "IPv4 resolver");

    public static ResolverAddressFamily Ipv6Only { get; } = new(
        "IPv6",
        "Benchmark only IPv6 DNS server addresses, such as 2606:4700:4700::1111.",
        "IPv6 resolver");

    public string? SocketAddressFor(CatalogProfile profile)
    {
        if (this == Automatic)
        {
            return profile.Ipv4Servers.FirstOrDefault() is { } ipv4
                ? $"{ipv4}:53"
                : BracketIpv6(profile.Ipv6Servers.FirstOrDefault());
        }

        if (this == Ipv4Only)
        {
            return profile.Ipv4Servers.FirstOrDefault() is { } ipv4 ? $"{ipv4}:53" : null;
        }

        return BracketIpv6(profile.Ipv6Servers.FirstOrDefault());
    }

    private static string? BracketIpv6(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : $"[{value}]:53";
    }
}
