using System.Globalization;
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

public enum BenchmarkResultSafetyState
{
    Recommended,
    FastestObserved,
    KeepCurrent,
}

public sealed record BenchmarkResultSafetyViewModel(
    BenchmarkResultSafetyState State,
    string DecisionLine,
    string FastestObservedLine,
    bool CanPresentApplyRecommendation)
{
    public static BenchmarkResultSafetyViewModel FromResult(BenchmarkResultPayload result)
    {
        var fastestObservedLine = FastestObservedLineFor(result.Runs);
        var profileId = result.Summary.RecommendedProfileId ?? result.Recommendation?.ProfileId;
        var confidence = result.Recommendation?.Confidence;
        var canRecommend = result.Summary.CanRecommend
            && string.Equals(result.Summary.Health, "healthy", StringComparison.OrdinalIgnoreCase)
            && string.Equals(confidence, "high", StringComparison.OrdinalIgnoreCase)
            && !string.IsNullOrWhiteSpace(profileId);

        if (canRecommend)
        {
            return new BenchmarkResultSafetyViewModel(
                BenchmarkResultSafetyState.Recommended,
                WindowsDisplayText.Text(
                    $"Recommended: {profileId}",
                    $"Khuyến nghị: {profileId}"),
                fastestObservedLine,
                CanPresentApplyRecommendation: true);
        }

        if (ShouldKeepCurrent(result.Summary))
        {
            return new BenchmarkResultSafetyViewModel(
                BenchmarkResultSafetyState.KeepCurrent,
                WindowsDisplayText.Text("Keep current DNS", "Giữ DNS hiện tại"),
                fastestObservedLine,
                CanPresentApplyRecommendation: false);
        }

        return new BenchmarkResultSafetyViewModel(
            BenchmarkResultSafetyState.FastestObserved,
            WindowsDisplayText.Text("Fastest observed", "Nhanh nhất đã đo"),
            fastestObservedLine,
            CanPresentApplyRecommendation: false);
    }

    private static bool ShouldKeepCurrent(BenchmarkResultSummary summary)
    {
        return !summary.CanRecommend
            || string.Equals(summary.PrimaryIssue, "all-resolvers-low-reliability", StringComparison.OrdinalIgnoreCase)
            || string.Equals(summary.Health, "failed", StringComparison.OrdinalIgnoreCase)
            || string.Equals(summary.Health, "inconclusive", StringComparison.OrdinalIgnoreCase);
    }

    private static string FastestObservedLineFor(IReadOnlyList<BenchmarkResultRun> runs)
    {
        var fastest = runs
            .Where(run => run.Metrics.MedianDnsLatencyMs is not null)
            .OrderBy(run => run.Metrics.MedianDnsLatencyMs)
            .ThenBy(run => run.Metrics.FailureRate)
            .FirstOrDefault();

        if (fastest is null)
        {
            return WindowsDisplayText.Text("Fastest observed DNS: unavailable", "DNS nhanh nhất đã đo: không có");
        }

        return WindowsDisplayText.Text(
            $"Fastest observed DNS: {fastest.ProfileId} ({FormatNumber(fastest.Metrics.MedianDnsLatencyMs!.Value)} ms median)",
            $"DNS nhanh nhất đã đo: {fastest.ProfileId} (trung vị {FormatNumber(fastest.Metrics.MedianDnsLatencyMs!.Value)} ms)");
    }

    private static string FormatNumber(double value)
    {
        return value.ToString("0.##", CultureInfo.InvariantCulture);
    }
}

public sealed record BenchmarkResultReportViewModel(
    string Title,
    string SummaryLine,
    string RecommendationLine,
    BenchmarkResultSafetyViewModel Safety,
    IReadOnlyList<string> ResolverLines,
    IReadOnlyList<string> NoteLines,
    string CopyableReport)
{
    public static BenchmarkResultReportViewModel FromResult(BenchmarkResultPayload result)
    {
        var title = WindowsDisplayText.Text("Benchmark result", "Kết quả benchmark");
        var summaryLine = SummaryLineFor(result.Summary);
        var safety = BenchmarkResultSafetyViewModel.FromResult(result);
        var recommendationLine = RecommendationLineFor(result, safety);
        var resolverLines = result.Runs.Select(ResolverLineFor).ToArray();
        var noteLines = NoteLinesFor(result).ToArray();

        var lines = new List<string>
        {
            title,
            summaryLine,
        };

        if (!string.IsNullOrWhiteSpace(result.Summary.PrimaryIssue)
            && !string.Equals(result.Summary.PrimaryIssue, "none", StringComparison.OrdinalIgnoreCase))
        {
            lines.Add($"{WindowsDisplayText.Text("Primary issue", "Vấn đề chính")}: {result.Summary.PrimaryIssue}");
        }

        if (!string.IsNullOrWhiteSpace(result.Summary.RecommendedProfileId))
        {
            lines.Add($"{WindowsDisplayText.Text("Recommended profile", "Hồ sơ khuyến nghị")}: {result.Summary.RecommendedProfileId}");
        }

        lines.Add(recommendationLine);
        lines.Add(safety.FastestObservedLine);

        foreach (var reason in result.Recommendation?.Reasons ?? Array.Empty<string>())
        {
            lines.Add($"{WindowsDisplayText.Text("Reason", "Lý do")}: {reason}");
        }

        if (resolverLines.Length > 0)
        {
            lines.Add(WindowsDisplayText.Text("Resolvers:", "Resolver:"));
            lines.AddRange(resolverLines.Select(line => "- " + line));
        }

        foreach (var note in noteLines)
        {
            lines.Add(note);
        }

        if (!string.IsNullOrWhiteSpace(result.SavedHistoryId))
        {
            lines.Add($"{WindowsDisplayText.Text("Saved history", "Lịch sử đã lưu")}: {result.SavedHistoryId}");
        }

        if (!string.IsNullOrWhiteSpace(result.Warning))
        {
            lines.Add($"{WindowsDisplayText.Text("Warning", "Cảnh báo")}: {result.Warning}");
        }

        return new BenchmarkResultReportViewModel(
            title,
            summaryLine,
            recommendationLine,
            safety,
            resolverLines,
            noteLines,
            string.Join(Environment.NewLine, lines));
    }

    private static string SummaryLineFor(BenchmarkResultSummary summary)
    {
        if (WindowsDisplayText.IsVietnamese)
        {
            var canRecommend = summary.CanRecommend ? "có" : "không";
            return $"Phạm vi: {summary.MeasurementScope}; Chế độ: {summary.Mode}; Sức khỏe: {WindowsDisplayText.HealthLabel(summary.Health)}; Có khuyến nghị: {canRecommend}";
        }

        return $"Scope: {summary.MeasurementScope}; Mode: {summary.Mode}; Health: {summary.Health}; Can recommend: {(summary.CanRecommend ? "yes" : "no")}";
    }

    private static string RecommendationLineFor(BenchmarkResultPayload result, BenchmarkResultSafetyViewModel safety)
    {
        if (safety.State != BenchmarkResultSafetyState.Recommended || result.Recommendation is null)
        {
            return safety.DecisionLine;
        }

        return WindowsDisplayText.Text(
            $"{safety.DecisionLine} ({result.Recommendation.Confidence}, score {FormatNumber(result.Recommendation.Score)})",
            $"{safety.DecisionLine} ({ConfidenceLabel(result.Recommendation.Confidence)}, điểm {FormatNumber(result.Recommendation.Score)})");
    }

    private static string ResolverLineFor(BenchmarkResultRun run)
    {
        var metrics = run.Metrics;
        var parts = new List<string>
        {
            $"{WindowsDisplayText.Text("median DNS", "DNS trung vị")} {FormatDuration(metrics.MedianDnsLatencyMs)}",
            $"{WindowsDisplayText.Text("p95 DNS", "DNS p95")} {FormatDuration(metrics.P95DnsLatencyMs)}",
        };

        if (metrics.MedianConnectLatencyMs is not null)
        {
            parts.Add($"{WindowsDisplayText.Text("connect", "kết nối")} {FormatDuration(metrics.MedianConnectLatencyMs)}");
        }

        parts.Add($"{WindowsDisplayText.Text("failure", "lỗi")} {FormatPercent(metrics.FailureRate)}");
        parts.Add($"timeout {FormatPercent(metrics.TimeoutRate)}");
        parts.Add($"IPv4 {FormatPercent(metrics.Ipv4Health)}");
        parts.Add($"IPv6 {FormatPercent(metrics.Ipv6Health)}");
        parts.Add($"{WindowsDisplayText.Text("priority fit", "độ khớp ưu tiên")} {FormatPercent(metrics.PriorityFit)}");

        return $"{run.ProfileId} {run.Resolver} - {string.Join("; ", parts)}";
    }

    private static IEnumerable<string> NoteLinesFor(BenchmarkResultPayload result)
    {
        foreach (var note in result.Summary.SafetyNotes)
        {
            yield return $"{WindowsDisplayText.Text("Safety note", "Lưu ý an toàn")}: {note}";
        }

        foreach (var caveat in result.Recommendation?.Caveats ?? Array.Empty<string>())
        {
            yield return $"{WindowsDisplayText.Text("Caveat", "Lưu ý")}: {caveat}";
        }

        foreach (var run in result.Runs)
        {
            foreach (var caveat in run.Caveats)
            {
                yield return $"{WindowsDisplayText.Text("Resolver caveat", "Lưu ý resolver")} ({run.ProfileId}): {caveat}";
            }
        }
    }

    private static string ConfidenceLabel(string confidence)
    {
        return confidence switch
        {
            "high" => WindowsDisplayText.Text("high", "cao"),
            "medium" => WindowsDisplayText.Text("medium", "trung bình"),
            "low" => WindowsDisplayText.Text("low", "thấp"),
            "inconclusive" => WindowsDisplayText.Text("inconclusive", "chưa kết luận"),
            _ => confidence,
        };
    }

    private static string FormatDuration(double? milliseconds)
    {
        return milliseconds is null ? "n/a" : $"{FormatNumber(milliseconds.Value)} ms";
    }

    private static string FormatNumber(double value)
    {
        return value.ToString("0.##", CultureInfo.InvariantCulture);
    }

    private static string FormatPercent(double value)
    {
        return (value * 100).ToString("0.##", CultureInfo.InvariantCulture) + "%";
    }
}

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
    public static ApplyPlanRequest MakeRequest(
        BenchmarkResultPayload result,
        bool vpnActive = false,
        bool mdmProfileActive = false,
        bool corporateDnsDetected = false,
        bool captivePortalDetected = false)
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
            GateHealthFor(result.Summary.Health),
            vpnActive,
            mdmProfileActive,
            corporateDnsDetected,
            captivePortalDetected);
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
