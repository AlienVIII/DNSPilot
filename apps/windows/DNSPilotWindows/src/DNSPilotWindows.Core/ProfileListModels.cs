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

public sealed record ProfileManagementRow(
    string Id,
    string Name,
    bool CanEdit,
    bool CanDelete,
    IReadOnlyList<string> Ipv4Servers,
    IReadOnlyList<string> Ipv6Servers,
    string UseCase)
{
    public override string ToString()
    {
        var label = string.IsNullOrWhiteSpace(UseCase) ? "built-in" : UseCase;
        return $"{Name} ({Id}) - {label}";
    }
}

public enum ProfileMutationKind
{
    Update,
    Delete,
}

public sealed record ProfileMutationValidation(IReadOnlyList<string> Issues)
{
    public bool CanMutate => Issues.Count == 0;
}

public sealed class ProfileManagementViewModel
{
    public ProfileManagementViewModel(ProfileListPayload payload)
    {
        Rows = payload.Profiles.Select(profile =>
        {
            var isCustom = profile.UseCase == "custom";
            return new ProfileManagementRow(
                profile.Id,
                profile.Name,
                CanEdit: isCustom,
                CanDelete: isCustom,
                profile.Ipv4Servers,
                profile.Ipv6Servers,
                string.IsNullOrWhiteSpace(profile.UseCase) ? "built-in" : profile.UseCase);
        }).ToArray();
    }

    public IReadOnlyList<ProfileManagementRow> Rows { get; }

    public ProfileMutationValidation ValidateMutation(ProfileMutationKind kind, string profileId)
    {
        return ValidateMutation(Rows, kind, profileId);
    }

    public static ProfileMutationValidation ValidateMutation(
        IReadOnlyList<ProfileManagementRow> rows,
        ProfileMutationKind kind,
        string profileId)
    {
        var normalizedId = profileId.Trim();
        if (normalizedId.Length == 0)
        {
            return new ProfileMutationValidation(new[]
            {
                WindowsDisplayText.Text("Profile ID is required.", "Profile ID là bắt buộc."),
            });
        }

        var row = rows.FirstOrDefault(row => string.Equals(row.Id, normalizedId, StringComparison.Ordinal));
        if (row is null)
        {
            return new ProfileMutationValidation(new[]
            {
                WindowsDisplayText.Text($"Profile not found: {normalizedId}", $"Không tìm thấy hồ sơ: {normalizedId}"),
            });
        }

        if (kind == ProfileMutationKind.Update && !row.CanEdit)
        {
            return new ProfileMutationValidation(new[]
            {
                WindowsDisplayText.Text(
                    "Built-in profiles cannot be updated from the Store-safe shell.",
                    "Không thể cập nhật hồ sơ built-in từ Store-safe shell."),
            });
        }

        if (kind == ProfileMutationKind.Delete && !row.CanDelete)
        {
            return new ProfileMutationValidation(new[]
            {
                WindowsDisplayText.Text(
                    "Built-in profiles cannot be deleted from the Store-safe shell.",
                    "Không thể xóa hồ sơ built-in từ Store-safe shell."),
            });
        }

        return new ProfileMutationValidation(Array.Empty<string>());
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
            throw new InvalidOperationException(
                WindowsDisplayText.Text("Invalid custom DNS profile: ", "Hồ sơ DNS tùy chỉnh không hợp lệ: ")
                + string.Join("; ", form.Validation.Issues));
        }
    }
}
