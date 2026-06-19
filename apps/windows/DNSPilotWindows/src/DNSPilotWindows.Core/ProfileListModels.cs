using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record ProfileListPayload(
    string DatabasePath,
    int ProfileCount,
    IReadOnlyList<CatalogProfile> Profiles);

public static class ProfileListJsonDecoder
{
    public static ProfileListPayload Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<ProfileListJsonPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Profile-list payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);
        return new ProfileListPayload(
            payload.DatabasePath,
            payload.ProfileCount,
            payload.Profiles.Select(CatalogJsonDecoder.ProfilePayload.ToCatalogProfile).ToArray());
    }

    private sealed record ProfileListJsonPayload(
        [property: JsonPropertyName("db")] string DatabasePath,
        [property: JsonPropertyName("profile_count")] int ProfileCount,
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("profiles")] IReadOnlyList<CatalogJsonDecoder.ProfilePayload> Profiles);
}

public sealed class ProfileListRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public ProfileListRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public ProfileListPayload Load(string databasePath)
    {
        var output = _processRunner.Run(_executablePath, ProfileManagementCommands.List(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Profile list", output);
        return ProfileListJsonDecoder.Decode(output.StandardOutput);
    }
}
