using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public static class CatalogJsonDecoder
{
    public static CatalogSnapshot Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<CatalogPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Catalog payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);

        return new CatalogSnapshot(
            payload.Profiles.Select(ProfilePayload.ToCatalogProfile).ToArray(),
            payload.TestSuites.Select(SuitePayload.ToCatalogTestSuite).ToArray());
    }

    private sealed record CatalogPayload(
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("profiles")] IReadOnlyList<ProfilePayload> Profiles,
        [property: JsonPropertyName("testSuites")] IReadOnlyList<SuitePayload> TestSuites);

    internal sealed record ProfilePayload(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("protocol")] string Protocol,
        [property: JsonPropertyName("ipv4_servers")] IReadOnlyList<string> Ipv4Servers,
        [property: JsonPropertyName("ipv6_servers")] IReadOnlyList<string> Ipv6Servers,
        [property: JsonPropertyName("use_case")] string? UseCase,
        [property: JsonPropertyName("filtering_type")] string? FilteringType,
        [property: JsonPropertyName("tags")] IReadOnlyList<string>? Tags)
    {
        public static CatalogProfile ToCatalogProfile(ProfilePayload payload)
        {
            return new CatalogProfile(
                payload.Id,
                payload.Name,
                ParseProtocol(payload.Protocol),
                payload.Ipv4Servers,
                payload.Ipv6Servers)
            {
                UseCase = payload.UseCase ?? "",
                FilteringType = payload.FilteringType ?? "",
                Tags = payload.Tags ?? Array.Empty<string>(),
            };
        }
    }

    private sealed record SuitePayload(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("domains")] IReadOnlyList<string> Domains)
    {
        public static CatalogTestSuite ToCatalogTestSuite(SuitePayload payload)
        {
            return new CatalogTestSuite(payload.Id, payload.Name, payload.Domains);
        }
    }

    internal static DnsProtocol ParseProtocol(string protocol)
    {
        return protocol switch
        {
            "plain" => DnsProtocol.Plain,
            "doh" => DnsProtocol.Doh,
            "dot" => DnsProtocol.Dot,
            _ => throw new InvalidOperationException($"Unknown DNS protocol '{protocol}'."),
        };
    }
}

internal static class JsonOptions
{
    public static JsonSerializerOptions Default { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
    };
}
