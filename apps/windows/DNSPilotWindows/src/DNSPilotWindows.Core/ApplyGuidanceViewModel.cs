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
    string Guidance)
{
    public string PlatformId { get; init; } = BenchmarkPlanViewModel.WindowsStorePlatformId;
    public string ApplyCapability { get; init; } = "guided-settings";
    public string Disposition { get; init; } = "guide-only";
    public string? ProfileId { get; init; }
    public bool CanApply { get; init; }
    public IReadOnlyList<string> Notes { get; init; } = Array.Empty<string>();
}

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
        if (plan.Decision is ApplyDecision.Protect or ApplyDecision.Block)
        {
            return ProtectedPlan(plan);
        }

        var copyableDnsServers = string.Join("\r\n", plan.DnsServers);
        var checklist = string.Join(
            Environment.NewLine,
            new[]
            {
                WindowsDisplayText.Text($"DNS Pilot recommendation: {plan.ProfileName}", $"Khuyến nghị DNS Pilot: {plan.ProfileName}"),
                plan.TestedResolver is null
                    ? WindowsDisplayText.Text("Tested resolver: not available", "Resolver đã test: chưa có")
                    : WindowsDisplayText.Text($"Tested resolver: {plan.TestedResolver}", $"Resolver đã test: {plan.TestedResolver}"),
                WindowsDisplayText.Text(
                    "No silent DNS mutation is performed by the Store build.",
                    "Không có thay đổi DNS âm thầm trong bản Store."),
                WindowsDisplayText.Text("Copy the DNS servers.", "Sao chép DNS server."),
                WindowsDisplayText.Text(
                    "Open Windows Settings > Network & internet > Advanced network settings.",
                    "Mở Windows Settings > Network & internet > Advanced network settings."),
                WindowsDisplayText.Text(
                    "Pick the active adapter, edit DNS server assignment, paste the copied servers, save, then run System DNS validation.",
                    "Chọn adapter đang dùng, sửa DNS server assignment, dán DNS server đã sao chép, lưu, rồi chạy kiểm tra DNS hệ thống."),
            });

        return new ApplyGuidanceViewModel(
            plan,
            WindowsSettingsUri.NetworkAdvancedSettings,
            new[]
            {
                new ApplyActionDescriptor(
                    ApplyActionKind.CopyDnsServers,
                    WindowsDisplayText.Text("Copy DNS servers", "Sao chép DNS server"),
                    WindowsDisplayText.Text("Copy the recommended DNS servers to the clipboard.", "Sao chép DNS server được khuyến nghị vào clipboard.")),
                new ApplyActionDescriptor(
                    ApplyActionKind.OpenWindowsSettings,
                    WindowsDisplayText.Text("Open Windows settings", "Mở cài đặt Windows"),
                    WindowsDisplayText.Text("Open Network & internet advanced settings without changing DNS.", "Mở Network & internet advanced settings mà không đổi DNS.")),
                new ApplyActionDescriptor(
                    ApplyActionKind.CopyChecklist,
                    WindowsDisplayText.Text("Copy checklist", "Sao chép checklist"),
                    WindowsDisplayText.Text("Copy the manual apply and retest checklist.", "Sao chép checklist áp dụng thủ công và kiểm tra lại.")),
            },
            copyableDnsServers,
            checklist);
    }

    private static ApplyGuidanceViewModel ProtectedPlan(ApplyPlan plan)
    {
        var reason = string.IsNullOrWhiteSpace(plan.Guidance)
            ? WindowsDisplayText.Text(
                "Protected network signals are active; avoid DNS apply prompts.",
                "Đang có tín hiệu protected network; tránh hiển thị apply DNS.")
            : plan.Guidance;
        var checklist = string.Join(
            Environment.NewLine,
            new[]
            {
                WindowsDisplayText.Text("Protected network guidance", "Hướng dẫn protected network"),
                WindowsDisplayText.Text("Keep current DNS settings.", "Giữ DNS hiện tại."),
                reason,
                WindowsDisplayText.Text(
                    "Do not copy DNS servers or open apply settings until protected-network signals clear.",
                    "Không sao chép DNS server hoặc mở cài đặt apply cho đến khi hết tín hiệu protected-network."),
                WindowsDisplayText.Text("Run System DNS validation only when the network is safe to retest.", "Chỉ chạy kiểm tra DNS hệ thống khi mạng an toàn để kiểm tra lại."),
            });

        return new ApplyGuidanceViewModel(
            plan,
            WindowsSettingsUri.NetworkAdvancedSettings,
            new[]
            {
                new ApplyActionDescriptor(
                    ApplyActionKind.CopyChecklist,
                    WindowsDisplayText.Text("Copy protected-network checklist", "Sao chép checklist protected-network"),
                    WindowsDisplayText.Text("Copy the reason DNS apply prompts are suppressed.", "Sao chép lý do prompt apply DNS đang bị ẩn.")),
            },
            "",
            checklist);
    }
}
