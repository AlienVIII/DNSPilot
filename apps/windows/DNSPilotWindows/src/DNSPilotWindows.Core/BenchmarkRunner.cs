using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record CliProcessOutput(
    int ExitCode,
    string StandardOutput,
    string StandardError);

public interface ICliProcessRunner
{
    CliProcessOutput Run(
        string executablePath,
        IReadOnlyList<string> arguments,
        Action<BenchmarkProgressEvent>? progressHandler);
}

public sealed record BenchmarkRunResult(
    int ExitCode,
    string StandardOutput,
    string StandardError,
    string ExecutablePath,
    IReadOnlyList<string> CommandArguments)
{
    public bool Succeeded => ExitCode == 0;

    public BenchmarkExecutionFailure ToFailure(BenchmarkFailureStep failedStep, TimeSpan? elapsed = null)
    {
        var debugLines = new[]
        {
            $"Command: {CommandLineFormatter.Format(ExecutablePath, CommandArguments)}",
            WindowsDisplayText.Text(
                $"Process failed with exit code {ExitCode}.",
                $"Tiến trình thất bại với exit code {ExitCode}."),
            string.IsNullOrWhiteSpace(StandardOutput) ? "stdout: <empty>" : $"stdout: {StandardOutput.Trim()}",
            string.IsNullOrWhiteSpace(StandardError) ? "stderr: <empty>" : $"stderr: {StandardError.Trim()}",
        };

        var reason = string.IsNullOrWhiteSpace(StandardError)
            ? WindowsDisplayText.Text(
                $"CLI exited with code {ExitCode}.",
                $"CLI thoát với code {ExitCode}.")
            : StandardError.Trim();

        return new BenchmarkExecutionFailure(
            failedStep,
            reason,
            elapsed,
            string.Join(Environment.NewLine, debugLines));
    }
}

public sealed class BenchmarkRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public BenchmarkRunner(
        string executablePath,
        ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public BenchmarkRunResult Run(
        BenchmarkPlanViewModel plan,
        BenchmarkHistoryPersistence? persistence = null,
        Action<BenchmarkProgressEvent>? progressHandler = null)
    {
        if (!plan.Validation.CanRun)
        {
            throw new InvalidOperationException(
                WindowsDisplayText.Text("Invalid benchmark plan: ", "Kế hoạch benchmark không hợp lệ: ")
                + string.Join("; ", plan.Validation.Issues));
        }

        var arguments = plan.CommandArguments.ToList();
        if (progressHandler is not null)
        {
            arguments.Add("--progress-jsonl");
        }

        if (persistence is not null)
        {
            arguments.AddRange(persistence.CommandArguments);
        }

        var output = _processRunner.Run(_executablePath, arguments, progressHandler);
        return new BenchmarkRunResult(
            output.ExitCode,
            output.StandardOutput,
            output.StandardError,
            _executablePath,
            arguments);
    }
}

public sealed class SystemCliProcessRunner : ICliProcessRunner
{
    public CliProcessOutput Run(
        string executablePath,
        IReadOnlyList<string> arguments,
        Action<BenchmarkProgressEvent>? progressHandler)
    {
        using var process = new Process();
        process.StartInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        var stdout = new List<string>();
        var stderr = new List<string>();
        process.OutputDataReceived += (_, args) =>
        {
            if (args.Data is not null)
            {
                stdout.Add(args.Data);
            }
        };
        process.ErrorDataReceived += (_, args) =>
        {
            if (args.Data is null)
            {
                return;
            }

            stderr.Add(args.Data);
            if (progressHandler is not null && BenchmarkProgressEventJsonDecoder.TryDecode(args.Data, out var progressEvent))
            {
                progressHandler(progressEvent);
            }
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();
        process.WaitForExit();

        return new CliProcessOutput(
            process.ExitCode,
            string.Join(Environment.NewLine, stdout),
            string.Join(Environment.NewLine, stderr));
    }
}

public static class BenchmarkProgressEventJsonDecoder
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower) },
    };

    public static bool TryDecode(string line, out BenchmarkProgressEvent progressEvent)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<ProgressEventPayload>(line, Options);
            if (payload is null)
            {
                progressEvent = default!;
                return false;
            }

            progressEvent = new BenchmarkProgressEvent(
                payload.Type,
                payload.ProfileId,
                payload.Resolver,
                payload.Index,
                payload.Total,
                payload.Status,
                payload.FailureRate,
                payload.ElapsedMs);
            return true;
        }
        catch (JsonException)
        {
            progressEvent = default!;
            return false;
        }
    }

    private sealed record ProgressEventPayload(
        [property: JsonPropertyName("type")] ProgressEventType Type,
        [property: JsonPropertyName("profile_id")] string ProfileId,
        [property: JsonPropertyName("resolver")] string Resolver,
        [property: JsonPropertyName("index")] int Index,
        [property: JsonPropertyName("total")] int Total,
        [property: JsonPropertyName("status")] ProgressEventStatus? Status,
        [property: JsonPropertyName("failure_rate")] double? FailureRate,
        [property: JsonPropertyName("elapsed_ms")] double? ElapsedMs);
}

internal static class CommandLineFormatter
{
    public static string Format(string executablePath, IReadOnlyList<string> arguments)
    {
        return string.Join(" ", new[] { Quote(executablePath) }.Concat(arguments.Select(Quote)));
    }

    private static string Quote(string value)
    {
        return value.Contains(' ', StringComparison.Ordinal) ? $"\"{value}\"" : value;
    }
}
