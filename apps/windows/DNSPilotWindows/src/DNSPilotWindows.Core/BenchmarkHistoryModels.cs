using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record BenchmarkHistoryPayload(
    string DatabasePath,
    int BenchmarkHistoryCount,
    IReadOnlyList<BenchmarkHistoryRecord> Records);

public sealed record BenchmarkHistoryRecord(
    string Id,
    string StartedAt,
    string Scope,
    string Mode,
    IReadOnlyList<string> Domains,
    IReadOnlyList<string> ResolverProfileIds,
    IReadOnlyList<BenchmarkHistoryMetric> Metrics,
    BenchmarkHistoryGate Gate,
    string? RecommendationProfileId,
    IReadOnlyList<string> Notes);

public sealed record BenchmarkHistoryMetric(
    string ProfileId,
    double FailureRate,
    double TimeoutRate);

public sealed record BenchmarkHistoryGate(
    bool CanRecommend,
    string Health,
    string PrimaryIssue,
    IReadOnlyList<string> Notes);

public static class BenchmarkHistoryJsonDecoder
{
    public static BenchmarkHistoryPayload Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<BenchmarkHistoryJsonPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("History payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);

        return new BenchmarkHistoryPayload(
            payload.DatabasePath,
            payload.BenchmarkHistoryCount,
            payload.Records.Select(record => new BenchmarkHistoryRecord(
                record.Id,
                record.StartedAt,
                record.Scope,
                record.Mode,
                record.Domains,
                record.ResolverProfileIds,
                record.Metrics.Select(metric => new BenchmarkHistoryMetric(metric.ProfileId, metric.FailureRate, metric.TimeoutRate)).ToArray(),
                new BenchmarkHistoryGate(
                    record.Gate.CanRecommend,
                    record.Gate.Health,
                    record.Gate.PrimaryIssue,
                    record.Gate.Notes),
                record.RecommendationProfileId,
                record.Notes)).ToArray());
    }

    private sealed record BenchmarkHistoryJsonPayload(
        [property: JsonPropertyName("db")] string DatabasePath,
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("benchmark_history_count")] int BenchmarkHistoryCount,
        [property: JsonPropertyName("benchmark_history")] IReadOnlyList<BenchmarkHistoryRecordPayload> Records);

    private sealed record BenchmarkHistoryRecordPayload(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("started_at")] string StartedAt,
        [property: JsonPropertyName("scope")] string Scope,
        [property: JsonPropertyName("mode")] string Mode,
        [property: JsonPropertyName("domains")] IReadOnlyList<string> Domains,
        [property: JsonPropertyName("resolver_profile_ids")] IReadOnlyList<string> ResolverProfileIds,
        [property: JsonPropertyName("metrics")] IReadOnlyList<BenchmarkHistoryMetricPayload> Metrics,
        [property: JsonPropertyName("gate")] BenchmarkHistoryGatePayload Gate,
        [property: JsonPropertyName("recommendation_profile_id")] string? RecommendationProfileId,
        [property: JsonPropertyName("notes")] IReadOnlyList<string> Notes);

    private sealed record BenchmarkHistoryMetricPayload(
        [property: JsonPropertyName("profile_id")] string ProfileId,
        [property: JsonPropertyName("failure_rate")] double FailureRate,
        [property: JsonPropertyName("timeout_rate")] double TimeoutRate);

    private sealed record BenchmarkHistoryGatePayload(
        [property: JsonPropertyName("can_recommend")] bool CanRecommend,
        [property: JsonPropertyName("health")] string Health,
        [property: JsonPropertyName("primary_issue")] string PrimaryIssue,
        [property: JsonPropertyName("notes")] IReadOnlyList<string> Notes);
}

public sealed record BenchmarkHistoryRow(
    string Id,
    string Title,
    string DomainSummary,
    string ResolverSummary,
    string HealthLabel,
    string RecommendationLabel,
    string ApplyGuidanceLabel);

public sealed class BenchmarkHistoryViewModel
{
    public BenchmarkHistoryViewModel(BenchmarkHistoryPayload payload, CatalogSnapshot catalog)
    {
        var profileNames = catalog.Profiles.ToDictionary(profile => profile.Id, profile => profile.Name, StringComparer.Ordinal);
        Rows = payload.Records
            .Reverse()
            .Select(record => BuildRow(record, profileNames))
            .ToArray();
    }

    public IReadOnlyList<BenchmarkHistoryRow> Rows { get; }

    private static BenchmarkHistoryRow BuildRow(BenchmarkHistoryRecord record, IReadOnlyDictionary<string, string> profileNames)
    {
        var recommendation = RecommendationLabel(record, profileNames);
        return new BenchmarkHistoryRow(
            record.Id,
            record.Scope == "dns-tcp" ? "DNS + TCP" : "DNS only",
            Summary(record.Domains, "No domains"),
            $"{record.ResolverProfileIds.Count} resolver{(record.ResolverProfileIds.Count == 1 ? "" : "s")}",
            HealthLabel(record.Gate.Health),
            recommendation,
            recommendation.StartsWith("Recommended:", StringComparison.Ordinal) || recommendation.StartsWith("Best measured:", StringComparison.Ordinal)
                ? "Retest before applying saved recommendation"
                : "Run a fresh benchmark before applying DNS");
    }

    private static string RecommendationLabel(BenchmarkHistoryRecord record, IReadOnlyDictionary<string, string> profileNames)
    {
        if (record.Gate.PrimaryIssue == "all-resolvers-low-reliability")
        {
            return "Keep current DNS";
        }

        if (!record.Gate.CanRecommend || record.RecommendationProfileId is null)
        {
            return "No recommendation";
        }

        var profileName = profileNames.TryGetValue(record.RecommendationProfileId, out var resolved)
            ? resolved
            : record.RecommendationProfileId;
        return record.Gate.Health == "healthy"
            ? $"Recommended: {profileName}"
            : $"Best measured: {profileName}";
    }

    private static string Summary(IReadOnlyList<string> values, string empty)
    {
        if (values.Count == 0)
        {
            return empty;
        }

        return values.Count == 1 ? values[0] : $"{values[0]} + {values.Count - 1} more";
    }

    private static string HealthLabel(string health)
    {
        return health switch
        {
            "healthy" => "Healthy",
            "degraded" => "Degraded",
            "failed" => "Failed",
            _ => "Inconclusive",
        };
    }
}

public sealed class BenchmarkHistoryRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public BenchmarkHistoryRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public BenchmarkHistoryPayload Load(string databasePath)
    {
        var output = _processRunner.Run(_executablePath, HistoryManagementCommands.List(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("History list", output);
        return BenchmarkHistoryJsonDecoder.Decode(output.StandardOutput);
    }

    public void Delete(string databasePath, string historyId)
    {
        var output = _processRunner.Run(_executablePath, HistoryManagementCommands.Delete(databasePath, historyId), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("History delete", output);
    }

    public void Clear(string databasePath)
    {
        var output = _processRunner.Run(_executablePath, HistoryManagementCommands.Clear(databasePath), progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("History clear", output);
    }
}
