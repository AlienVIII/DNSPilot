namespace DNSPilotWindows.Core;

public enum ApplyDecision
{
    Guide,
    Protect,
    Block,
}

public enum ApplyActionKind
{
    CopyDnsServers,
    OpenWindowsSettings,
    CopyChecklist,
    MutateSystemDns,
}

public sealed record ApplyPlan(
    ApplyDecision Decision,
    string ProfileName,
    IReadOnlyList<string> DnsServers,
    string? TestedResolver,
    string Guidance);

public sealed record WindowsSettingsUri(string PrimaryUri, string FallbackUri)
{
    public static WindowsSettingsUri NetworkAdvancedSettings { get; } = new(
        "ms-settings:network-advancedsettings",
        "ms-settings:network-status");
}

public sealed record ApplyActionDescriptor(
    ApplyActionKind Kind,
    string Label,
    string Detail);

public sealed class ApplyGuidanceViewModel
{
    private ApplyGuidanceViewModel(
        ApplyPlan plan,
        WindowsSettingsUri openSettingsUri,
        IReadOnlyList<ApplyActionDescriptor> actions,
        string copyableDnsServers,
        string copyableChecklist)
    {
        Plan = plan;
        OpenSettingsUri = openSettingsUri;
        Actions = actions;
        CopyableDnsServers = copyableDnsServers;
        CopyableChecklist = copyableChecklist;
    }

    public ApplyPlan Plan { get; }
    public WindowsSettingsUri OpenSettingsUri { get; }
    public IReadOnlyList<ApplyActionDescriptor> Actions { get; }
    public string CopyableDnsServers { get; }
    public string CopyableChecklist { get; }

    public static ApplyGuidanceViewModel FromPlan(ApplyPlan plan)
    {
        var copyableDnsServers = string.Join("\r\n", plan.DnsServers);
        var checklist = string.Join(
            Environment.NewLine,
            new[]
            {
                $"DNS Pilot recommendation: {plan.ProfileName}",
                plan.TestedResolver is null ? "Tested resolver: not available" : $"Tested resolver: {plan.TestedResolver}",
                "No silent DNS mutation is performed by the Store build.",
                "Copy the DNS servers.",
                "Open Windows Settings > Network & internet > Advanced network settings.",
                "Pick the active adapter, edit DNS server assignment, paste the copied servers, save, then run System DNS validation.",
            });

        return new ApplyGuidanceViewModel(
            plan,
            WindowsSettingsUri.NetworkAdvancedSettings,
            new[]
            {
                new ApplyActionDescriptor(ApplyActionKind.CopyDnsServers, "Copy DNS servers", "Copy the recommended DNS servers to the clipboard."),
                new ApplyActionDescriptor(ApplyActionKind.OpenWindowsSettings, "Open Windows settings", "Open Network & internet advanced settings without changing DNS."),
                new ApplyActionDescriptor(ApplyActionKind.CopyChecklist, "Copy checklist", "Copy the manual apply and retest checklist."),
            },
            copyableDnsServers,
            checklist);
    }
}
