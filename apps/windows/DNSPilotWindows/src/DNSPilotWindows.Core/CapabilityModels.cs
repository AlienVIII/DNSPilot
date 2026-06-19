using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record PlatformCapability(
    string Platform,
    bool CanBenchmark,
    string Apply,
    string Flush,
    bool StoreSafe,
    IReadOnlyList<string> Notes);

public sealed record CapabilityMatrix(IReadOnlyList<PlatformCapability> Capabilities)
{
    public PlatformCapability RequirePlatform(string platform)
    {
        return Capabilities.FirstOrDefault(capability => capability.Platform == platform)
            ?? throw new InvalidOperationException($"Missing platform capability '{platform}'.");
    }
}

public static class CapabilityMatrixJsonDecoder
{
    public static CapabilityMatrix Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<CapabilityMatrixPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Capability payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);
        return new CapabilityMatrix(payload.Capabilities.Select(capability => new PlatformCapability(
            capability.Platform,
            capability.CanBenchmark,
            capability.Apply,
            capability.Flush,
            capability.StoreSafe,
            capability.Notes)).ToArray());
    }

    private sealed record CapabilityMatrixPayload(
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("capabilities")] IReadOnlyList<PlatformCapabilityPayload> Capabilities);

    private sealed record PlatformCapabilityPayload(
        [property: JsonPropertyName("platform")] string Platform,
        [property: JsonPropertyName("can_benchmark")] bool CanBenchmark,
        [property: JsonPropertyName("apply")] string Apply,
        [property: JsonPropertyName("flush")] string Flush,
        [property: JsonPropertyName("store_safe")] bool StoreSafe,
        [property: JsonPropertyName("notes")] IReadOnlyList<string> Notes);
}
