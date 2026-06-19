using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSPilotWindows.Core;

public enum ApplyPlanConfidence
{
    High,
    Medium,
    Low,
    Inconclusive,
}

public enum ApplyPlanGateHealth
{
    Healthy,
    Degraded,
    Failed,
    Inconclusive,
}

public sealed record ApplyPlanRequest(
    string? profileId,
    string? testedResolver,
    ApplyPlanConfidence confidence,
    ApplyPlanGateHealth gateHealth,
    bool vpnActive = false,
    bool mdmProfileActive = false,
    bool corporateDnsDetected = false,
    bool captivePortalDetected = false,
    string platformId = BenchmarkPlanViewModel.WindowsStorePlatformId)
{
    public IReadOnlyList<string> CommandArguments
    {
        get
        {
            var arguments = new List<string>
            {
                "apply-plan",
                platformId,
                "--confidence",
                confidence.CliValue(),
                "--gate-health",
                gateHealth.CliValue(),
            };

            if (profileId is not null)
            {
                arguments.Add("--profile-id");
                arguments.Add(profileId);
            }

            if (testedResolver is not null)
            {
                arguments.Add("--tested-resolver");
                arguments.Add(testedResolver);
            }

            if (vpnActive)
            {
                arguments.Add("--vpn-active");
            }

            if (mdmProfileActive)
            {
                arguments.Add("--mdm-profile-active");
            }

            if (corporateDnsDetected)
            {
                arguments.Add("--corporate-dns-detected");
            }

            if (captivePortalDetected)
            {
                arguments.Add("--captive-portal-detected");
            }

            return arguments;
        }
    }
}

public static class ApplyPlanJsonDecoder
{
    public static ApplyPlan Decode(string json)
    {
        var payload = JsonSerializer.Deserialize<ApplyPlanPayload>(json, JsonOptions.Default)
            ?? throw new InvalidOperationException("Apply-plan payload is empty.");
        ShellPayloadSchema.Validate(payload.SchemaVersion);

        return new ApplyPlan(
            DecisionFor(payload.Disposition),
            payload.ProfileName ?? "DNS profile",
            payload.DnsServers,
            payload.TestedResolver,
            string.Join(Environment.NewLine, payload.Notes))
        {
            PlatformId = payload.Platform,
            ApplyCapability = payload.ApplyCapability,
            Disposition = payload.Disposition,
            ProfileId = payload.ProfileId,
            CanApply = payload.CanApply,
            Notes = payload.Notes,
        };
    }

    private static ApplyDecision DecisionFor(string disposition)
    {
        return disposition switch
        {
            "guide-only" => ApplyDecision.Guide,
            "apply-with-user-approval" => ApplyDecision.Guide,
            "protect-current-dns" => ApplyDecision.Protect,
            "not-recommended" => ApplyDecision.Protect,
            "unsupported" => ApplyDecision.Block,
            _ => throw new InvalidOperationException($"Unknown apply-plan disposition '{disposition}'."),
        };
    }

    private sealed record ApplyPlanPayload(
        [property: JsonPropertyName("schema_version")] int SchemaVersion,
        [property: JsonPropertyName("platform")] string Platform,
        [property: JsonPropertyName("apply_capability")] string ApplyCapability,
        [property: JsonPropertyName("disposition")] string Disposition,
        [property: JsonPropertyName("profile_id")] string? ProfileId,
        [property: JsonPropertyName("profile_name")] string? ProfileName,
        [property: JsonPropertyName("tested_resolver")] string? TestedResolver,
        [property: JsonPropertyName("dns_servers")] IReadOnlyList<string> DnsServers,
        [property: JsonPropertyName("can_apply")] bool CanApply,
        [property: JsonPropertyName("notes")] IReadOnlyList<string> Notes);
}

public sealed class ApplyPlanRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public ApplyPlanRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public ApplyPlan Load(ApplyPlanRequest request)
    {
        var output = _processRunner.Run(_executablePath, request.CommandArguments, progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Apply-plan", output);
        return ApplyPlanJsonDecoder.Decode(output.StandardOutput);
    }
}

internal static class ApplyPlanEnumExtensions
{
    public static string CliValue(this ApplyPlanConfidence confidence)
    {
        return confidence switch
        {
            ApplyPlanConfidence.Medium => "medium",
            ApplyPlanConfidence.Low => "low",
            ApplyPlanConfidence.Inconclusive => "inconclusive",
            _ => "high",
        };
    }

    public static string CliValue(this ApplyPlanGateHealth health)
    {
        return health switch
        {
            ApplyPlanGateHealth.Degraded => "degraded",
            ApplyPlanGateHealth.Failed => "failed",
            ApplyPlanGateHealth.Inconclusive => "inconclusive",
            _ => "healthy",
        };
    }
}
