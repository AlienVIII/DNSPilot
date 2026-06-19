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

public sealed class CustomDnsProfileRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public CustomDnsProfileRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public void Add(string databasePath, CustomDnsProfileFormViewModel form)
    {
        EnsureValid(form);
        var output = _processRunner.Run(_executablePath, form.AddCommandArguments(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Profile add", output);
    }

    public void Update(string databasePath, string profileId, CustomDnsProfileFormViewModel form)
    {
        EnsureValid(form);
        var output = _processRunner.Run(_executablePath, form.UpdateCommandArguments(databasePath, profileId), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Profile update", output);
    }

    public void Delete(string databasePath, string profileId)
    {
        var output = _processRunner.Run(_executablePath, ProfileManagementCommands.Delete(databasePath, profileId), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Profile delete", output);
    }

    private static void EnsureValid(CustomDnsProfileFormViewModel form)
    {
        if (!form.Validation.CanSave)
        {
            throw new InvalidOperationException("Invalid custom DNS profile: " + string.Join("; ", form.Validation.Issues));
        }
    }
}
