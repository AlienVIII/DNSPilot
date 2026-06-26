namespace DNSPilotWindows.Core;

public enum DnsProtocol
{
    Plain,
    Doh,
    Dot,
}

public sealed record CatalogProfile(
    string Id,
    string Name,
    DnsProtocol Protocol,
    IReadOnlyList<string> Ipv4Servers,
    IReadOnlyList<string> Ipv6Servers)
{
    public string UseCase { get; init; } = "";
    public string FilteringType { get; init; } = "";
    public IReadOnlyList<string> Tags { get; init; } = Array.Empty<string>();
}

public sealed record CatalogTestSuite(
    string Id,
    string Name,
    IReadOnlyList<string> Domains);

public sealed record CatalogSnapshot(
    IReadOnlyList<CatalogProfile> Profiles,
    IReadOnlyList<CatalogTestSuite> TestSuites);
