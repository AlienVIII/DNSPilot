using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record BenchmarkResultPayload(
    BenchmarkResultSummary Summary,
    IReadOnlyList<BenchmarkResultRun> Runs,
    BenchmarkRecommendation? Recommendation,
    string? SavedHistoryId,
    string Warning);

public sealed record BenchmarkResultSummary(
    string MeasurementScope,
    string Mode,
    string Health,
    string PrimaryIssue,
    bool CanRecommend,
    IReadOnlyList<string> SafetyNotes,
    int ResolverCount,
    int DomainCount,
    int AttemptsPerRecord,
    string? RecommendedProfileId);

public sealed record BenchmarkResultRun(
    string ProfileId,
    string Resolver,
    BenchmarkResultMetrics Metrics,
    IReadOnlyList<string> Caveats);

public sealed record BenchmarkResultMetrics(
    string ProfileId,
    double? MedianDnsLatencyMs,
    double? P95DnsLatencyMs,
    double FailureRate,
    double TimeoutRate,
    double? MedianConnectLatencyMs,
    double Ipv4Health,
    double Ipv6Health,
    double PriorityFit);

public sealed record BenchmarkRecommendation(
    string ProfileId,
    double Score,
    string Confidence,
    IReadOnlyList<string> Reasons,
    IReadOnlyList<string> Caveats);

public static class BenchmarkResultJsonDecoder
{
    public static BenchmarkResultPayload Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<BenchmarkResultJsonPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Benchmark result payload is empty.");

        return new BenchmarkResultPayload(
            new BenchmarkResultSummary(
                payload.Summary.MeasurementScope,
                payload.Summary.Mode,
                payload.Summary.Health,
                payload.Summary.PrimaryIssue,
                payload.Summary.CanRecommend,
                payload.Summary.SafetyNotes,
                payload.Summary.ResolverCount,
                payload.Summary.DomainCount,
                payload.Summary.AttemptsPerRecord,
                payload.Summary.RecommendedProfileId),
            payload.Runs.Select(run => new BenchmarkResultRun(
                run.ProfileId,
                run.Resolver,
                new BenchmarkResultMetrics(
                    run.Metrics.ProfileId,
                    run.Metrics.MedianDnsLatencyMs,
                    run.Metrics.P95DnsLatencyMs,
                    run.Metrics.FailureRate,
                    run.Metrics.TimeoutRate,
                    run.Metrics.MedianConnectLatencyMs,
                    run.Metrics.Ipv4Health,
                    run.Metrics.Ipv6Health,
                    run.Metrics.PriorityFit),
                run.Caveats ?? Array.Empty<string>())).ToArray(),
            payload.Recommendation is null
                ? null
                : new BenchmarkRecommendation(
                    payload.Recommendation.ProfileId,
                    payload.Recommendation.Score,
                    payload.Recommendation.Confidence,
                    payload.Recommendation.Reasons,
                    payload.Recommendation.Caveats),
            payload.SavedHistoryId,
            payload.Warning);
    }

    private sealed record BenchmarkResultJsonPayload(
        [property: JsonPropertyName("summary")] BenchmarkResultSummaryPayload Summary,
        [property: JsonPropertyName("runs")] IReadOnlyList<BenchmarkResultRunPayload> Runs,
        [property: JsonPropertyName("recommendation")] BenchmarkRecommendationPayload? Recommendation,
        [property: JsonPropertyName("saved_history_id")] string? SavedHistoryId,
        [property: JsonPropertyName("warning")] string Warning);

    private sealed record BenchmarkResultSummaryPayload(
        [property: JsonPropertyName("measurement_scope")] string MeasurementScope,
        [property: JsonPropertyName("mode")] string Mode,
        [property: JsonPropertyName("health")] string Health,
        [property: JsonPropertyName("primary_issue")] string PrimaryIssue,
        [property: JsonPropertyName("can_recommend")] bool CanRecommend,
        [property: JsonPropertyName("safety_notes")] IReadOnlyList<string> SafetyNotes,
        [property: JsonPropertyName("resolver_count")] int ResolverCount,
        [property: JsonPropertyName("domain_count")] int DomainCount,
        [property: JsonPropertyName("attempts_per_record")] int AttemptsPerRecord,
        [property: JsonPropertyName("recommended_profile_id")] string? RecommendedProfileId);

    private sealed record BenchmarkResultRunPayload(
        [property: JsonPropertyName("profile_id")] string ProfileId,
        [property: JsonPropertyName("resolver")] string Resolver,
        [property: JsonPropertyName("metrics")] BenchmarkResultMetricsPayload Metrics,
        [property: JsonPropertyName("caveats")] IReadOnlyList<string>? Caveats);

    private sealed record BenchmarkResultMetricsPayload(
        [property: JsonPropertyName("profile_id")] string ProfileId,
        [property: JsonPropertyName("median_dns_latency_ms")] double? MedianDnsLatencyMs,
        [property: JsonPropertyName("p95_dns_latency_ms")] double? P95DnsLatencyMs,
        [property: JsonPropertyName("failure_rate")] double FailureRate,
        [property: JsonPropertyName("timeout_rate")] double TimeoutRate,
        [property: JsonPropertyName("median_connect_latency_ms")] double? MedianConnectLatencyMs,
        [property: JsonPropertyName("ipv4_health")] double Ipv4Health,
        [property: JsonPropertyName("ipv6_health")] double Ipv6Health,
        [property: JsonPropertyName("priority_fit")] double PriorityFit);

    private sealed record BenchmarkRecommendationPayload(
        [property: JsonPropertyName("profile_id")] string ProfileId,
        [property: JsonPropertyName("score")] double Score,
        [property: JsonPropertyName("confidence")] string Confidence,
        [property: JsonPropertyName("reasons")] IReadOnlyList<string> Reasons,
        [property: JsonPropertyName("caveats")] IReadOnlyList<string> Caveats);
}

public static class BenchmarkApplyPlanRequestFactory
{
    public static ApplyPlanRequest MakeRequest(BenchmarkResultPayload result)
    {
        var profileId = result.Summary.CanRecommend
            ? result.Summary.RecommendedProfileId ?? result.Recommendation?.ProfileId
            : null;
        var testedResolver = profileId is null
            ? null
            : result.Runs.FirstOrDefault(run => run.ProfileId == profileId)?.Resolver;

        return new ApplyPlanRequest(
            profileId,
            testedResolver,
            ConfidenceFor(result.Recommendation?.Confidence),
            GateHealthFor(result.Summary.Health));
    }

    private static ApplyPlanConfidence ConfidenceFor(string? confidence)
    {
        return confidence switch
        {
            "medium" => ApplyPlanConfidence.Medium,
            "low" => ApplyPlanConfidence.Low,
            "inconclusive" => ApplyPlanConfidence.Inconclusive,
            "high" => ApplyPlanConfidence.High,
            _ => ApplyPlanConfidence.Inconclusive,
        };
    }

    private static ApplyPlanGateHealth GateHealthFor(string health)
    {
        return health switch
        {
            "healthy" => ApplyPlanGateHealth.Healthy,
            "degraded" => ApplyPlanGateHealth.Degraded,
            "failed" => ApplyPlanGateHealth.Failed,
            _ => ApplyPlanGateHealth.Inconclusive,
        };
    }
}
