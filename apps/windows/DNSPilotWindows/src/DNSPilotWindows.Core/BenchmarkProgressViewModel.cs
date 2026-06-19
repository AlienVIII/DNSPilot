namespace DNSPilotWindows.Core;

public enum BenchmarkRunState
{
    Idle,
    Running,
    Cancelling,
    Completed,
}

public enum ProgressStatus
{
    Idle,
    Running,
    Success,
    Degraded,
    Failed,
}

public readonly record struct BenchmarkFailureStep(string Id, string Label, int Order)
{
    public static BenchmarkFailureStep PreparingBenchmark { get; } = new("preparingBenchmark", "Preparing benchmark", 0);
    public static BenchmarkFailureStep ResolvingDns { get; } = new("resolvingDNS", "Resolving DNS", 1);
    public static BenchmarkFailureStep MeasuringConnection { get; } = new("measuringConnection", "Measuring TCP", 2);
    public static BenchmarkFailureStep ParsingResult { get; } = new("parsingResult", "Parsing result", 3);
    public static BenchmarkFailureStep SavingHistory { get; } = new("savingHistory", "Saving history", 4);
}

public sealed record BenchmarkProgressStepViewModel(
    string Id,
    string Title,
    ProgressStatus Status);

public sealed record BenchmarkResolverStatusViewModel(
    string Id,
    string Name,
    string Resolver,
    ProgressStatus Status,
    string Detail);

public enum ProgressEventType
{
    ResolverStarted,
    ResolverFinished,
}

public enum ProgressEventStatus
{
    Success,
    Degraded,
    Failed,
}

public sealed record BenchmarkProgressEvent(
    ProgressEventType Type,
    string ProfileId,
    string Resolver,
    int Index,
    int Total,
    ProgressEventStatus? Status = null,
    double? FailureRate = null,
    double? ElapsedMs = null);

public sealed class BenchmarkExecutionFailure
{
    public BenchmarkExecutionFailure(
        BenchmarkFailureStep failedStep,
        string reason,
        TimeSpan? elapsed,
        string debugLog,
        string? suggestion = null)
    {
        FailedStep = failedStep;
        Reason = reason;
        Elapsed = elapsed;
        DebugLog = debugLog;
        Suggestion = suggestion;
    }

    public BenchmarkFailureStep FailedStep { get; }
    public string Reason { get; }
    public TimeSpan? Elapsed { get; }
    public string DebugLog { get; }
    public string? Suggestion { get; }

    public string CopyableReport(string modeLabel)
    {
        var lines = new List<string>
        {
            "Benchmark failed",
            $"Mode: {modeLabel}",
            $"Failed at: {FailedStep.Label}",
            $"Reason: {Reason}",
            $"Suggestion: {Suggestion ?? DefaultSuggestion(FailedStep)}",
        };

        if (Elapsed is { } elapsed)
        {
            lines.Add($"Elapsed: {Math.Round(elapsed.TotalMilliseconds):0} ms");
        }

        lines.Add(string.Empty);
        lines.Add("Debug log:");
        lines.Add(DebugLog);
        return string.Join(Environment.NewLine, lines);
    }

    private static string DefaultSuggestion(BenchmarkFailureStep step)
    {
        if (step == BenchmarkFailureStep.MeasuringConnection)
        {
            return "Check network reachability, firewall, VPN, captive portal, or try DNS only.";
        }

        if (step == BenchmarkFailureStep.ParsingResult)
        {
            return "Keep the debug log and verify the CLI output schema matches the app version.";
        }

        if (step == BenchmarkFailureStep.SavingHistory)
        {
            return "Check local DNS Pilot storage permissions and available disk space.";
        }

        return "Check selected profiles, target domains, CLI availability, and network configuration.";
    }
}

public sealed class BenchmarkProgressViewModel
{
    private BenchmarkProgressViewModel(
        IReadOnlyList<BenchmarkProgressStepViewModel> steps,
        IReadOnlyList<string> currentStepLines,
        IReadOnlyList<BenchmarkResolverStatusViewModel> resolverStatuses)
    {
        Steps = steps;
        CurrentStepLines = currentStepLines;
        ResolverStatuses = resolverStatuses;
    }

    public IReadOnlyList<BenchmarkProgressStepViewModel> Steps { get; }
    public IReadOnlyList<string> CurrentStepLines { get; }
    public IReadOnlyList<BenchmarkResolverStatusViewModel> ResolverStatuses { get; }

    public static BenchmarkProgressViewModel From(
        BenchmarkMode mode,
        BenchmarkRunState state,
        BenchmarkProgressPlanSummary summary,
        IReadOnlyList<BenchmarkProgressEvent>? progressEvents = null,
        BenchmarkExecutionFailure? failure = null,
        bool historySaved = false)
    {
        progressEvents ??= Array.Empty<BenchmarkProgressEvent>();
        var running = state is BenchmarkRunState.Running or BenchmarkRunState.Cancelling;
        var completed = state == BenchmarkRunState.Completed && failure is null;
        var steps = StepSequence(mode)
            .Select(step => new BenchmarkProgressStepViewModel(step.Id, step.Label, StepStatus(step, failure, running, completed, historySaved)))
            .ToArray();

        return new BenchmarkProgressViewModel(
            steps,
            BuildCurrentStepLines(mode, running, state == BenchmarkRunState.Cancelling, summary, progressEvents),
            BuildResolverStatuses(running, state == BenchmarkRunState.Cancelling, summary, progressEvents, failure));
    }

    private static IReadOnlyList<BenchmarkFailureStep> StepSequence(BenchmarkMode mode)
    {
        var steps = new List<BenchmarkFailureStep>
        {
            BenchmarkFailureStep.PreparingBenchmark,
            BenchmarkFailureStep.ResolvingDns,
        };

        if (mode == BenchmarkMode.DnsAndTcp)
        {
            steps.Add(BenchmarkFailureStep.MeasuringConnection);
        }

        steps.Add(BenchmarkFailureStep.ParsingResult);
        steps.Add(BenchmarkFailureStep.SavingHistory);
        return steps;
    }

    private static ProgressStatus StepStatus(
        BenchmarkFailureStep step,
        BenchmarkExecutionFailure? failure,
        bool running,
        bool completed,
        bool historySaved)
    {
        if (failure is not null)
        {
            if (failure.FailedStep == step)
            {
                return ProgressStatus.Failed;
            }

            return step.Order < failure.FailedStep.Order ? ProgressStatus.Success : ProgressStatus.Idle;
        }

        if (step == BenchmarkFailureStep.SavingHistory)
        {
            return completed && historySaved ? ProgressStatus.Success : ProgressStatus.Idle;
        }

        if (completed)
        {
            return ProgressStatus.Success;
        }

        if (!running)
        {
            return ProgressStatus.Idle;
        }

        if (step == BenchmarkFailureStep.PreparingBenchmark)
        {
            return ProgressStatus.Success;
        }

        return step == BenchmarkFailureStep.ResolvingDns || step == BenchmarkFailureStep.MeasuringConnection
            ? ProgressStatus.Running
            : ProgressStatus.Idle;
    }

    private static IReadOnlyList<string> BuildCurrentStepLines(
        BenchmarkMode mode,
        bool running,
        bool cancelling,
        BenchmarkProgressPlanSummary summary,
        IReadOnlyList<BenchmarkProgressEvent> progressEvents)
    {
        if (!running)
        {
            return Array.Empty<string>();
        }

        if (cancelling)
        {
            return new[]
            {
                "Cancellation requested; waiting for the CLI process to stop.",
                "Output is still drained so the final state and debug log stay consistent.",
            };
        }

        if (progressEvents.LastOrDefault() is { } latest)
        {
            return new[]
            {
                $"Current resolver event: {latest.ProfileId} ({latest.Resolver}), {latest.Index}/{latest.Total}.",
                latest.Type == ProgressEventType.ResolverFinished
                    ? $"Last result: {EventDetail(latest)}."
                    : "Waiting for this resolver to finish.",
            };
        }

        return mode == BenchmarkMode.DnsAndTcp
            ? new[]
            {
                "Resolving DNS, then probing TCP :443 for returned endpoints.",
                $"Planned input: {summary.DomainCount} domain(s), {summary.ResolverCount} resolver(s), {summary.Attempts} attempt(s).",
            }
            : new[]
            {
                $"Resolving {summary.DomainCount} domain(s) with {summary.ResolverCount} resolver(s), {summary.Attempts} attempt(s), {summary.RecordFamily.DisplayLabel}.",
                "CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            };
    }

    private static IReadOnlyList<BenchmarkResolverStatusViewModel> BuildResolverStatuses(
        bool running,
        bool cancelling,
        BenchmarkProgressPlanSummary summary,
        IReadOnlyList<BenchmarkProgressEvent> progressEvents,
        BenchmarkExecutionFailure? failure)
    {
        if (running)
        {
            var latestEventsByProfile = progressEvents
                .GroupBy(progressEvent => progressEvent.ProfileId)
                .ToDictionary(group => group.Key, group => group.Last(), StringComparer.Ordinal);

            if (latestEventsByProfile.Count > 0)
            {
                return summary.ResolverTargets
                    .Select(target => latestEventsByProfile.TryGetValue(target.Id, out var latest)
                        ? new BenchmarkResolverStatusViewModel(target.Id, target.Name, target.Resolver, EventStatus(latest), EventDetail(latest))
                        : new BenchmarkResolverStatusViewModel(target.Id, target.Name, target.Resolver, ProgressStatus.Idle, "Pending"))
                    .ToArray();
            }

            return summary.ResolverTargets
                .Select((target, index) => new BenchmarkResolverStatusViewModel(
                    target.Id,
                    target.Name,
                    target.Resolver,
                    index == 0 ? ProgressStatus.Running : ProgressStatus.Idle,
                    cancelling && index == 0 ? "Cancelling" : index == 0 ? $"Running 1/{summary.ResolverTargets.Count}" : "Pending"))
                .ToArray();
        }

        if (failure is not null)
        {
            return summary.ResolverTargets
                .Select(target => new BenchmarkResolverStatusViewModel(
                    target.Id,
                    target.Name,
                    target.Resolver,
                    failure.FailedStep == BenchmarkFailureStep.PreparingBenchmark ? ProgressStatus.Idle : ProgressStatus.Failed,
                    failure.FailedStep == BenchmarkFailureStep.ParsingResult ? "Result parsing failed" : "Benchmark failed"))
                .ToArray();
        }

        return Array.Empty<BenchmarkResolverStatusViewModel>();
    }

    private static ProgressStatus EventStatus(BenchmarkProgressEvent progressEvent)
    {
        if (progressEvent.Type == ProgressEventType.ResolverStarted)
        {
            return ProgressStatus.Running;
        }

        return progressEvent.Status switch
        {
            ProgressEventStatus.Degraded => ProgressStatus.Degraded,
            ProgressEventStatus.Failed => ProgressStatus.Failed,
            _ => ProgressStatus.Success,
        };
    }

    private static string EventDetail(BenchmarkProgressEvent progressEvent)
    {
        if (progressEvent.Type == ProgressEventType.ResolverStarted)
        {
            return $"Running {progressEvent.Index}/{progressEvent.Total}";
        }

        var summary = progressEvent.FailureRate is { } failureRate
            ? $"{Math.Round(Math.Clamp(failureRate, 0, 1) * 100):0}% failed"
            : "Finished";

        return progressEvent.ElapsedMs is { } elapsedMs
            ? $"{summary} - {Math.Round(Math.Max(elapsedMs, 0)):0} ms"
            : summary;
    }
}
