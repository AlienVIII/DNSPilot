using System.Diagnostics;
using System.Text.Json;

namespace DNSPilotWindows.Core;

public enum RuntimeReadinessState
{
    Checking,
    Ready,
    Degraded,
    Incompatible,
}

public enum RuntimeSurface
{
    Benchmark,
    ApplyGuidance,
    Profiles,
    Suites,
    History,
}

public enum RuntimeFailureKind
{
    MissingHelper,
    ProcessFailure,
    MalformedPayload,
    UnsupportedSchema,
    StorageFailure,
    Unknown,
}

public sealed record RuntimeSurfaceReadiness(
    RuntimeSurface Surface,
    bool IsReady,
    RuntimeFailureKind? FailureKind,
    string Summary,
    string RecoveryAction)
{
    public static RuntimeSurfaceReadiness Ready(RuntimeSurface surface)
    {
        return new RuntimeSurfaceReadiness(
            surface,
            IsReady: true,
            FailureKind: null,
            WindowsDisplayText.Text("Ready", "Sẵn sàng"),
            "");
    }
}

public sealed class RuntimeReadinessViewModel
{
    private readonly IReadOnlyDictionary<RuntimeSurface, RuntimeSurfaceReadiness> _surfaces;

    private RuntimeReadinessViewModel(
        RuntimeReadinessState state,
        string helperPath,
        string? cliVersion,
        IReadOnlyList<RuntimeSurfaceReadiness> surfaces)
    {
        State = state;
        HelperPath = helperPath;
        CliVersion = cliVersion;
        PayloadSchemaVersion = ShellPayloadSchema.SupportedVersion;
        _surfaces = surfaces.ToDictionary(surface => surface.Surface);
    }

    public RuntimeReadinessState State { get; }
    public string HelperPath { get; }
    public string? CliVersion { get; }
    public int PayloadSchemaVersion { get; }
    public bool CanBenchmark => For(RuntimeSurface.Benchmark).IsReady;
    public bool CanApplyGuidance => For(RuntimeSurface.ApplyGuidance).IsReady;
    public bool CanManageProfiles => For(RuntimeSurface.Profiles).IsReady;
    public bool CanManageSuites => For(RuntimeSurface.Suites).IsReady;
    public bool CanReadHistory => For(RuntimeSurface.History).IsReady;

    public string Title => State switch
    {
        RuntimeReadinessState.Ready => WindowsDisplayText.Text("DNS Pilot is ready", "DNS Pilot đã sẵn sàng"),
        RuntimeReadinessState.Incompatible => WindowsDisplayText.Text("Core update required", "Cần cập nhật Core"),
        RuntimeReadinessState.Degraded => WindowsDisplayText.Text("Some features are unavailable", "Một số tính năng chưa sẵn sàng"),
        _ => WindowsDisplayText.Text("Checking DNS Pilot runtime", "Đang kiểm tra DNS Pilot runtime"),
    };

    public string Summary
    {
        get
        {
            if (State == RuntimeReadinessState.Checking)
            {
                return WindowsDisplayText.Text(
                    "Checking the bundled helper and local contracts.",
                    "Đang kiểm tra helper đi kèm và contract cục bộ.");
            }

            var failed = _surfaces.Values.Where(surface => !surface.IsReady).ToArray();
            if (failed.Length == 0)
            {
                return WindowsDisplayText.Text(
                    "Benchmark, guided apply, profiles, suites, and history are available.",
                    "Benchmark, hướng dẫn apply, hồ sơ, suite và lịch sử đã sẵn sàng.");
            }

            return string.Join(" ", failed.Select(surface => surface.Summary).Distinct(StringComparer.Ordinal));
        }
    }

    public RuntimeSurfaceReadiness For(RuntimeSurface surface)
    {
        return _surfaces[surface];
    }

    public string CopyableReport(string appVersion)
    {
        var lines = new List<string>
        {
            "DNS Pilot runtime readiness",
            $"State: {State}",
            $"App version: {appVersion}",
            $"CLI version: {CliVersion ?? "unavailable (runtime-info pending)"}",
            $"Payload schema: {PayloadSchemaVersion}",
            $"Helper: {WindowsDiagnosticRedactor.Redact(HelperPath)}",
        };

        foreach (var surface in Enum.GetValues<RuntimeSurface>())
        {
            var status = For(surface);
            lines.Add($"{surface}: {(status.IsReady ? "ready" : status.FailureKind?.ToString() ?? "checking")} - {status.Summary}");
            if (!string.IsNullOrWhiteSpace(status.RecoveryAction))
            {
                lines.Add($"Recovery: {status.RecoveryAction}");
            }
        }

        return string.Join(Environment.NewLine, lines);
    }

    public static RuntimeReadinessViewModel Checking(string helperPath)
    {
        var surfaces = Enum.GetValues<RuntimeSurface>()
            .Select(surface => new RuntimeSurfaceReadiness(
                surface,
                IsReady: false,
                FailureKind: null,
                WindowsDisplayText.Text("Runtime check is in progress.", "Đang kiểm tra runtime."),
                ""))
            .ToArray();
        return new RuntimeReadinessViewModel(RuntimeReadinessState.Checking, helperPath, null, surfaces);
    }

    public static RuntimeReadinessViewModel Create(
        string helperPath,
        string? cliVersion,
        IReadOnlyList<RuntimeSurfaceReadiness> surfaces)
    {
        var state = surfaces.All(surface => surface.IsReady)
            ? RuntimeReadinessState.Ready
            : surfaces.Any(surface => surface.FailureKind == RuntimeFailureKind.UnsupportedSchema)
                ? RuntimeReadinessState.Incompatible
                : RuntimeReadinessState.Degraded;
        return new RuntimeReadinessViewModel(state, helperPath, cliVersion, surfaces);
    }
}

public sealed record RuntimeContractLoadResult(
    CatalogSnapshot? Catalog,
    CapabilityMatrix? Capabilities,
    ApplyPlan? ApplyPlan,
    ProfileListPayload? ProfileList,
    SuiteListPayload? SuiteList,
    BenchmarkHistoryPayload? History,
    RuntimeReadinessViewModel Readiness);

public sealed class RuntimeContractLoader
{
    private readonly ICliProcessRunner _processRunner;

    public RuntimeContractLoader(ICliProcessRunner? processRunner = null)
    {
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public RuntimeContractLoadResult Load(string helperPath, string databasePath)
    {
        if (!File.Exists(helperPath))
        {
            var missing = Enum.GetValues<RuntimeSurface>()
                .Select(surface => Failure(
                    surface,
                    RuntimeFailureKind.MissingHelper,
                    WindowsDisplayText.Text(
                        "The DNS Pilot helper is missing.",
                        "Thiếu DNS Pilot helper."),
                    WindowsDisplayText.Text(
                        "Install or bundle dnspilot-cli.exe, then retry.",
                        "Cài đặt hoặc đóng gói dnspilot-cli.exe, sau đó thử lại.")))
                .ToArray();
            return new RuntimeContractLoadResult(
                null,
                null,
                null,
                null,
                null,
                null,
                RuntimeReadinessViewModel.Create(helperPath, null, missing));
        }

        var catalog = AttemptLoad(
            RuntimeSurface.Benchmark,
            () => new CatalogRunner(helperPath, _processRunner).Load(),
            RuntimeFailureKind.ProcessFailure,
            WindowsDisplayText.Text("Catalog is unavailable.", "Catalog chưa sẵn sàng."));
        var capabilities = AttemptLoad(
            RuntimeSurface.Benchmark,
            () => new CapabilityMatrixRunner(helperPath, _processRunner).Load(),
            RuntimeFailureKind.ProcessFailure,
            WindowsDisplayText.Text("Capability policy is unavailable.", "Chính sách capability chưa sẵn sàng."));

        var benchmarkStatus = FirstFailure(catalog.Status, capabilities.Status)
            ?? RuntimeSurfaceReadiness.Ready(RuntimeSurface.Benchmark);

        var storageDirectoryError = EnsureStorageDirectory(databasePath);

        var profiles = storageDirectoryError is null
            ? AttemptLoad(
                RuntimeSurface.Profiles,
                () => new ProfileListRunner(helperPath, _processRunner).Load(databasePath),
                RuntimeFailureKind.StorageFailure,
                WindowsDisplayText.Text("Profiles are unavailable.", "Hồ sơ chưa sẵn sàng."))
            : StorageUnavailable<ProfileListPayload>(RuntimeSurface.Profiles, storageDirectoryError);
        var suites = storageDirectoryError is null
            ? AttemptLoad(
                RuntimeSurface.Suites,
                () => new SuiteListRunner(helperPath, _processRunner).Load(databasePath),
                RuntimeFailureKind.StorageFailure,
                WindowsDisplayText.Text("Suites are unavailable.", "Suite chưa sẵn sàng."))
            : StorageUnavailable<SuiteListPayload>(RuntimeSurface.Suites, storageDirectoryError);
        var history = storageDirectoryError is null
            ? AttemptLoad(
                RuntimeSurface.History,
                () => new BenchmarkHistoryRunner(helperPath, _processRunner).Load(databasePath),
                RuntimeFailureKind.StorageFailure,
                WindowsDisplayText.Text("History is unavailable.", "Lịch sử chưa sẵn sàng."))
            : StorageUnavailable<BenchmarkHistoryPayload>(RuntimeSurface.History, storageDirectoryError);

        Attempt<ApplyPlan> applyPlan;
        if (!benchmarkStatus.IsReady || catalog.Value is null || capabilities.Value is null)
        {
            applyPlan = new Attempt<ApplyPlan>(
                null,
                Failure(
                    RuntimeSurface.ApplyGuidance,
                    benchmarkStatus.FailureKind ?? RuntimeFailureKind.Unknown,
                    WindowsDisplayText.Text(
                        "Apply guidance is blocked until benchmark contracts are compatible.",
                        "Hướng dẫn apply bị chặn cho đến khi contract benchmark tương thích."),
                    benchmarkStatus.RecoveryAction));
        }
        else
        {
            var firstProfile = catalog.Value.Profiles.FirstOrDefault(profile => profile.Protocol == DnsProtocol.Plain);
            var testedResolver = firstProfile?.Ipv4Servers.FirstOrDefault() is { } ipv4 ? $"{ipv4}:53" : null;
            applyPlan = AttemptLoad(
                RuntimeSurface.ApplyGuidance,
                () => new ApplyPlanRunner(helperPath, _processRunner).Load(
                    new ApplyPlanRequest(
                        firstProfile?.Id,
                        testedResolver,
                        ApplyPlanConfidence.High,
                        ApplyPlanGateHealth.Healthy)),
                RuntimeFailureKind.ProcessFailure,
                WindowsDisplayText.Text("Apply guidance is unavailable.", "Hướng dẫn apply chưa sẵn sàng."));
        }

        var statuses = new[]
        {
            benchmarkStatus,
            applyPlan.Status,
            profiles.Status,
            suites.Status,
            history.Status,
        };
        return new RuntimeContractLoadResult(
            catalog.Value,
            capabilities.Value,
            applyPlan.Value,
            profiles.Value,
            suites.Value,
            history.Value,
            RuntimeReadinessViewModel.Create(helperPath, TryReadCliVersion(helperPath), statuses));
    }

    private static RuntimeSurfaceReadiness? FirstFailure(params RuntimeSurfaceReadiness[] statuses)
    {
        var failure = statuses.FirstOrDefault(status => !status.IsReady);
        return failure is null
            ? null
            : failure with { Surface = RuntimeSurface.Benchmark };
    }

    private static Exception? EnsureStorageDirectory(string databasePath)
    {
        var directoryPath = Path.GetDirectoryName(databasePath);
        if (string.IsNullOrWhiteSpace(directoryPath))
        {
            return null;
        }

        try
        {
            Directory.CreateDirectory(directoryPath);
            return null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return ex;
        }
    }

    private static Attempt<T> StorageUnavailable<T>(RuntimeSurface surface, Exception exception)
        where T : class
    {
        return new Attempt<T>(
            null,
            Failure(
                surface,
                RuntimeFailureKind.StorageFailure,
                WindowsDisplayText.Text("Local DNS Pilot storage is unavailable.", "Bộ nhớ cục bộ DNS Pilot chưa sẵn sàng.")
                + " " + SafeReason(exception),
                WindowsDisplayText.Text(
                    "Check local app-data access, then retry. Existing data is not modified.",
                    "Kiểm tra quyền truy cập dữ liệu cục bộ, sau đó thử lại. Dữ liệu hiện có không bị thay đổi.")));
    }

    private static Attempt<T> AttemptLoad<T>(
        RuntimeSurface surface,
        Func<T> load,
        RuntimeFailureKind fallbackKind,
        string summary)
        where T : class
    {
        try
        {
            return new Attempt<T>(load(), RuntimeSurfaceReadiness.Ready(surface));
        }
        catch (Exception ex)
        {
            var kind = FailureKind(ex, fallbackKind);
            var recovery = kind switch
            {
                RuntimeFailureKind.UnsupportedSchema => WindowsDisplayText.Text(
                    "Update DNS Pilot so the app and bundled helper use the same payload schema.",
                    "Cập nhật DNS Pilot để app và helper dùng cùng payload schema."),
                RuntimeFailureKind.MalformedPayload => WindowsDisplayText.Text(
                    "Retry. If the error continues, reinstall the matching DNS Pilot package.",
                    "Thử lại. Nếu lỗi tiếp tục, hãy cài lại đúng gói DNS Pilot."),
                RuntimeFailureKind.StorageFailure => WindowsDisplayText.Text(
                    "Check local app-data access, then retry. Existing data is not modified.",
                    "Kiểm tra quyền truy cập dữ liệu cục bộ, sau đó thử lại. Dữ liệu hiện có không bị thay đổi."),
                _ => WindowsDisplayText.Text(
                    "Retry the runtime check. Reinstall DNS Pilot if the helper keeps failing.",
                    "Thử kiểm tra runtime lại. Cài lại DNS Pilot nếu helper tiếp tục lỗi."),
            };
            return new Attempt<T>(
                null,
                Failure(surface, kind, $"{summary} {SafeReason(ex)}", recovery));
        }
    }

    private static RuntimeFailureKind FailureKind(Exception ex, RuntimeFailureKind fallbackKind)
    {
        return ex switch
        {
            UnsupportedPayloadSchemaException => RuntimeFailureKind.UnsupportedSchema,
            JsonException => RuntimeFailureKind.MalformedPayload,
            CliContractCommandException => fallbackKind,
            IOException when fallbackKind == RuntimeFailureKind.StorageFailure => RuntimeFailureKind.StorageFailure,
            UnauthorizedAccessException when fallbackKind == RuntimeFailureKind.StorageFailure => RuntimeFailureKind.StorageFailure,
            _ => fallbackKind,
        };
    }

    private static RuntimeSurfaceReadiness Failure(
        RuntimeSurface surface,
        RuntimeFailureKind kind,
        string summary,
        string recoveryAction)
    {
        return new RuntimeSurfaceReadiness(surface, false, kind, summary, recoveryAction);
    }

    private static string SafeReason(Exception ex)
    {
        var reason = ex.Message.Replace(Environment.NewLine, " ").Trim();
        return reason.Length <= 240 ? reason : reason[..240] + "...";
    }

    private static string? TryReadCliVersion(string helperPath)
    {
        try
        {
            var version = FileVersionInfo.GetVersionInfo(helperPath).ProductVersion;
            return string.IsNullOrWhiteSpace(version) ? null : version;
        }
        catch
        {
            return null;
        }
    }

    private sealed record Attempt<T>(T? Value, RuntimeSurfaceReadiness Status)
        where T : class;
}
