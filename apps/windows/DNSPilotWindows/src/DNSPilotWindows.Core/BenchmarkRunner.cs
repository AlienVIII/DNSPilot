using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public sealed record CliProcessOutput(
    int ExitCode,
    string StandardOutput,
    string StandardError,
    bool WasCancelled = false);

public interface ICliProcessRunner
{
    CliProcessOutput Run(
        string executablePath,
        IReadOnlyList<string> arguments,
        Action<BenchmarkProgressEvent>? progressHandler,
        CancellationToken cancellationToken = default);
}

public sealed record BenchmarkRunResult(
    int ExitCode,
    string StandardOutput,
    string StandardError,
    string ExecutablePath,
    IReadOnlyList<string> CommandArguments,
    bool WasCancelled = false)
{
    public bool Succeeded => !WasCancelled && ExitCode == 0;

    public bool HistoryWasSaved => !WasCancelled && TryReadSavedHistoryId(StandardOutput) is not null;

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

    private static string? TryReadSavedHistoryId(string standardOutput)
    {
        try
        {
            return BenchmarkResultJsonDecoder.Decode(standardOutput).SavedHistoryId;
        }
        catch (Exception)
        {
            return null;
        }
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
        Action<BenchmarkProgressEvent>? progressHandler = null,
        CancellationToken cancellationToken = default)
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

        if (cancellationToken.IsCancellationRequested)
        {
            return new BenchmarkRunResult(
                ExitCode: -1,
                StandardOutput: "",
                StandardError: WindowsDisplayText.Text("Benchmark cancelled before launch.", "Benchmark đã hủy trước khi chạy."),
                ExecutablePath: _executablePath,
                CommandArguments: arguments,
                WasCancelled: true);
        }

        if (persistence is not null)
        {
            arguments.AddRange(persistence.CommandArguments);
        }

        var output = _processRunner.Run(_executablePath, arguments, progressHandler, cancellationToken);
        return new BenchmarkRunResult(
            output.ExitCode,
            output.StandardOutput,
            output.StandardError,
            _executablePath,
            arguments,
            output.WasCancelled);
    }
}

public sealed class SystemCliProcessRunner : ICliProcessRunner
{
    private const int CancellationExitTimeoutMilliseconds = 5_000;

    public CliProcessOutput Run(
        string executablePath,
        IReadOnlyList<string> arguments,
        Action<BenchmarkProgressEvent>? progressHandler,
        CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested)
        {
            return CancelledOutput();
        }

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

        var outputLock = new object();
        var stdout = new List<string>();
        var stderr = new List<string>();
        process.OutputDataReceived += (_, args) =>
        {
            if (args.Data is not null)
            {
                lock (outputLock)
                {
                    stdout.Add(args.Data);
                }
            }
        };
        process.ErrorDataReceived += (_, args) =>
        {
            if (args.Data is null)
            {
                return;
            }

            lock (outputLock)
            {
                stderr.Add(args.Data);
            }
            if (progressHandler is not null && BenchmarkProgressEventJsonDecoder.TryDecode(args.Data, out var progressEvent))
            {
                progressHandler(progressEvent);
            }
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var cancellationRequestedWhileRunning = 0;
        using var cancellationRegistration = cancellationToken.Register(() =>
        {
            if (!process.HasExited)
            {
                Interlocked.Exchange(ref cancellationRequestedWhileRunning, 1);
                StopProcessTree(process);
            }
        });
        var exitedNormally = false;
        while (!cancellationToken.IsCancellationRequested && !(exitedNormally = process.WaitForExit(100)))
        {
        }

        var wasCancelled = Volatile.Read(ref cancellationRequestedWhileRunning) == 1;
        var exited = exitedNormally || !wasCancelled;
        if (wasCancelled)
        {
            StopProcessTree(process);
            exited = process.WaitForExit(CancellationExitTimeoutMilliseconds);
        }
        else
        {
            process.WaitForExit();
        }

        if (exited)
        {
            process.WaitForExit();
        }

        string standardOutput;
        string standardError;
        lock (outputLock)
        {
            standardOutput = string.Join(Environment.NewLine, stdout);
            standardError = string.Join(Environment.NewLine, stderr);
        }

        if (wasCancelled)
        {
            if (!exited)
            {
                standardError = string.Join(
                    Environment.NewLine,
                    new[] { standardError, $"Cancellation exceeded {CancellationExitTimeoutMilliseconds} ms after process-tree termination." }
                        .Where(line => !string.IsNullOrWhiteSpace(line)));
            }

            return new CliProcessOutput(-1, standardOutput, standardError, WasCancelled: true);
        }

        return new CliProcessOutput(
            process.ExitCode,
            standardOutput,
            standardError);
    }

    private static CliProcessOutput CancelledOutput()
    {
        return new CliProcessOutput(
            -1,
            "",
            WindowsDisplayText.Text("Benchmark cancelled before launch.", "Benchmark đã hủy trước khi chạy."),
            WasCancelled: true);
    }

    private static void StopProcessTree(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch (InvalidOperationException)
        {
            // The process exited between the state check and termination request.
        }
        catch (System.ComponentModel.Win32Exception)
        {
            // Cancellation still returns a bounded cancelled result with the safe stderr detail.
        }
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
