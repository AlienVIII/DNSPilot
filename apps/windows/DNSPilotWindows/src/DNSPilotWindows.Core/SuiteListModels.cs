using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace DNSPilotWindows.Core;

public sealed record SuiteListPayload(
    string DatabasePath,
    int TestSuiteCount,
    IReadOnlyList<CatalogTestSuite> TestSuites);

public static class SuiteListJsonDecoder
{
    public static SuiteListPayload Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<SuiteListJsonPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Suite-list payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);
        return new SuiteListPayload(
            payload.DatabasePath,
            payload.TestSuiteCount,
            payload.TestSuites.Select(SuitePayload.ToCatalogTestSuite).ToArray());
    }

    private sealed record SuiteListJsonPayload(
        [property: JsonPropertyName("db")] string DatabasePath,
        [property: JsonPropertyName("test_suite_count")] int TestSuiteCount,
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("test_suites")] IReadOnlyList<SuitePayload> TestSuites);

    private sealed record SuitePayload(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("domains")] IReadOnlyList<string> Domains,
        [property: JsonPropertyName("tags")] IReadOnlyList<string>? Tags)
    {
        public static CatalogTestSuite ToCatalogTestSuite(SuitePayload payload)
        {
            return new CatalogTestSuite(payload.Id, payload.Name, payload.Domains)
            {
                Description = payload.Description ?? "",
                Tags = payload.Tags ?? Array.Empty<string>(),
            };
        }
    }
}

public sealed class SuiteListRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public SuiteListRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public SuiteListPayload Load(string databasePath)
    {
        var output = _processRunner.Run(_executablePath, SuiteManagementCommands.List(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Suite list", output);
        return SuiteListJsonDecoder.Decode(output.StandardOutput);
    }
}

public sealed record SuiteFormValidation(IReadOnlyList<string> Issues)
{
    public bool CanSave => Issues.Count == 0;
}

public sealed class CustomDomainSuiteFormViewModel
{
    public CustomDomainSuiteFormViewModel(
        string name,
        string domains,
        string tags = "")
    {
        Name = NormalizeName(name);
        Domains = SplitValues(domains);
        Tags = EnsureCustomTag(SplitValues(tags));
        Validation = Validate();
    }

    public string Name { get; }
    public IReadOnlyList<string> Domains { get; }
    public IReadOnlyList<string> Tags { get; }
    public SuiteFormValidation Validation { get; }
    public string SuiteId => Slugify(Name);

    public IReadOnlyList<string> AddCommandArguments(string databasePath)
    {
        return CommandArguments("suite-add", databasePath, SuiteId);
    }

    public IReadOnlyList<string> UpdateCommandArguments(string databasePath, string suiteId)
    {
        return CommandArguments("suite-update", databasePath, suiteId);
    }

    private IReadOnlyList<string> CommandArguments(string command, string databasePath, string suiteId)
    {
        var arguments = new List<string>
        {
            command,
            "--db",
            databasePath,
            "--id",
            suiteId,
            "--name",
            Name,
        };

        foreach (var domain in Domains)
        {
            arguments.Add("--domain");
            arguments.Add(domain);
        }

        foreach (var tag in Tags)
        {
            arguments.Add("--tag");
            arguments.Add(tag);
        }

        return arguments;
    }

    private SuiteFormValidation Validate()
    {
        var issues = new List<string>();
        if (Name.Length == 0)
        {
            issues.Add(WindowsDisplayText.Text("Suite name is required.", "Tên suite là bắt buộc."));
        }

        if (Domains.Count == 0)
        {
            issues.Add(WindowsDisplayText.Text("Add at least one domain.", "Thêm ít nhất một domain."));
        }

        foreach (var domain in Domains.Where(domain => !DomainNameValidator.IsValid(domain)))
        {
            issues.Add(WindowsDisplayText.Text($"Invalid domain: {domain}", $"Domain không hợp lệ: {domain}"));
        }

        var seenDomains = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var duplicate in Domains.Where(domain => !seenDomains.Add(domain.TrimEnd('.'))))
        {
            issues.Add(WindowsDisplayText.Text($"Duplicate domain: {duplicate}", $"Domain bị trùng: {duplicate}"));
        }

        return new SuiteFormValidation(issues);
    }

    private static IReadOnlyList<string> SplitValues(string values)
    {
        return values
            .Split(new[] { ',', ';', '\r', '\n', '\t', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToArray();
    }

    private static IReadOnlyList<string> EnsureCustomTag(IReadOnlyList<string> tags)
    {
        return tags.Count == 0
            ? new[] { "custom" }
            : tags;
    }

    private static string NormalizeName(string name)
    {
        return Regex.Replace(name.Trim(), @"\s+", " ");
    }

    private static string Slugify(string value)
    {
        var normalized = Regex.Replace(value.Trim().ToLowerInvariant(), @"[^a-z0-9]+", "-").Trim('-');
        if (normalized.Length == 0)
        {
            return "custom-suite";
        }

        return normalized.StartsWith("custom-", StringComparison.Ordinal) ? normalized : "custom-" + normalized;
    }
}

public static class SuiteManagementCommands
{
    public static IReadOnlyList<string> List(string databasePath)
    {
        return new[] { "suite-list", "--db", databasePath };
    }

    public static IReadOnlyList<string> Delete(string databasePath, string suiteId)
    {
        return new[] { "suite-delete", "--db", databasePath, "--id", suiteId };
    }
}

public enum SuiteMutationKind
{
    Update,
    Delete,
}

public sealed record SuiteMutationValidation(IReadOnlyList<string> Issues)
{
    public bool CanMutate => Issues.Count == 0;
}

public sealed record SuiteManagementRow(
    string Id,
    string Name,
    bool CanEdit,
    bool CanDelete,
    IReadOnlyList<string> Domains,
    string Detail)
{
    public override string ToString()
    {
        return $"{Name} ({Id}) - {Detail}";
    }
}

public static class SuiteOwnershipPolicy
{
    public static bool IsCustom(CatalogTestSuite suite)
    {
        return suite.Description == "Custom domain test suite."
            || suite.Tags.Any(tag => tag == "custom");
    }
}

public sealed class SuiteManagementViewModel
{
    public SuiteManagementViewModel(IReadOnlyList<CatalogTestSuite> testSuites)
    {
        Rows = testSuites
            .Select(suite =>
            {
                var isCustom = SuiteOwnershipPolicy.IsCustom(suite);
                return new SuiteManagementRow(
                    suite.Id,
                    suite.Name,
                    CanEdit: isCustom,
                    CanDelete: isCustom,
                    suite.Domains,
                    isCustom
                        ? WindowsDisplayText.Text($"{suite.Domains.Count} domain(s), custom", $"{suite.Domains.Count} domain, custom")
                        : WindowsDisplayText.Text($"{suite.Domains.Count} domain(s), built-in", $"{suite.Domains.Count} domain, built-in"));
            })
            .ToArray();
    }

    public IReadOnlyList<SuiteManagementRow> Rows { get; }

    public SuiteMutationValidation ValidateMutation(SuiteMutationKind kind, string suiteId)
    {
        return ValidateMutation(Rows, kind, suiteId);
    }

    public static SuiteMutationValidation ValidateMutation(
        IReadOnlyList<SuiteManagementRow> rows,
        SuiteMutationKind kind,
        string suiteId)
    {
        var normalizedId = suiteId.Trim();
        if (normalizedId.Length == 0)
        {
            return new SuiteMutationValidation(new[]
            {
                WindowsDisplayText.Text("Suite ID is required.", "Suite ID là bắt buộc."),
            });
        }

        var row = rows.FirstOrDefault(row => string.Equals(row.Id, normalizedId, StringComparison.Ordinal));
        if (row is null)
        {
            return new SuiteMutationValidation(new[]
            {
                WindowsDisplayText.Text($"Suite not found: {normalizedId}", $"Không tìm thấy suite: {normalizedId}"),
            });
        }

        if (kind == SuiteMutationKind.Update && !row.CanEdit)
        {
            return new SuiteMutationValidation(new[]
            {
                WindowsDisplayText.Text(
                    "Built-in suites cannot be updated from the Store-safe shell.",
                    "Không thể cập nhật suite built-in từ Store-safe shell."),
            });
        }

        if (kind == SuiteMutationKind.Delete && !row.CanDelete)
        {
            return new SuiteMutationValidation(new[]
            {
                WindowsDisplayText.Text(
                    "Built-in suites cannot be deleted from the Store-safe shell.",
                    "Không thể xóa suite built-in từ Store-safe shell."),
            });
        }

        return new SuiteMutationValidation(Array.Empty<string>());
    }
}

public sealed class CustomDomainSuiteRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public CustomDomainSuiteRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public void Add(string databasePath, CustomDomainSuiteFormViewModel form)
    {
        EnsureValid(form);
        var output = _processRunner.Run(_executablePath, form.AddCommandArguments(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Suite add", output);
    }

    public void Update(string databasePath, string suiteId, CustomDomainSuiteFormViewModel form)
    {
        EnsureValid(form);
        var output = _processRunner.Run(_executablePath, form.UpdateCommandArguments(databasePath, suiteId), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Suite update", output);
    }

    public void Delete(string databasePath, string suiteId)
    {
        var output = _processRunner.Run(_executablePath, SuiteManagementCommands.Delete(databasePath, suiteId), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Suite delete", output);
    }

    private static void EnsureValid(CustomDomainSuiteFormViewModel form)
    {
        if (!form.Validation.CanSave)
        {
            throw new InvalidOperationException(
                WindowsDisplayText.Text("Invalid custom domain suite: ", "Suite domain tùy chỉnh không hợp lệ: ")
                + string.Join("; ", form.Validation.Issues));
        }
    }
}
