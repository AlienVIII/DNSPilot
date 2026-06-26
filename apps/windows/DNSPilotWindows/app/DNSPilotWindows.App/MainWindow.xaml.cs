using DNSPilotWindows.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.ApplicationModel.DataTransfer;
using Windows.System;

namespace DNSPilotWindows.App;

public sealed partial class MainWindow : Window
{
    private readonly List<BenchmarkProgressEvent> _progressEvents = [];
    private string _lastDiagnostics = "";

    public MainWindow()
    {
        ViewModel = WindowsShellViewModel.CreateDefault(DefaultDatabasePath());
        InitializeComponent();
        RenderStaticState();
        RenderProgress(BenchmarkRunState.Idle, ViewModel.BenchmarkPlan.Mode, ViewModel.BenchmarkPlan.ProgressSummary);
        CommandPreviewBox.Text = FormatCommand(ViewModel.BenchmarkPlan.CommandArguments);
        _ = LoadRuntimeContractsAsync();
    }

    public WindowsShellViewModel ViewModel { get; private set; }

    public void HandleTrayAction(TrayActionKind action)
    {
        DispatcherQueue.TryEnqueue(async () =>
        {
            switch (action)
            {
                case TrayActionKind.QuickBenchmark:
                    await StartBenchmarkAsync(ViewModel.TrayQuickActions.QuickBenchmarkPlan);
                    break;
                case TrayActionKind.ValidateSystemDns:
                    await StartBenchmarkAsync(ViewModel.TrayQuickActions.ValidateSystemDnsPlan);
                    break;
                case TrayActionKind.OpenSettings:
                    await OpenSettingsAsync();
                    break;
            }
        });
    }

    private async void QuickBenchmark_Click(object sender, RoutedEventArgs e)
    {
        await StartBenchmarkAsync(BuildSelectedBenchmarkPlan());
    }

    private async void ValidateSystemDns_Click(object sender, RoutedEventArgs e)
    {
        await StartBenchmarkAsync(ViewModel.SystemDnsValidationPlan);
    }

    private async void CopyCommand_Click(object sender, RoutedEventArgs e)
    {
        await CopyTextAsync(CommandPreviewBox.Text);
    }

    private async void CopyDnsServers_Click(object sender, RoutedEventArgs e)
    {
        await CopyTextAsync(ViewModel.ApplyGuidance.CopyableDnsServers);
    }

    private async void CopyChecklist_Click(object sender, RoutedEventArgs e)
    {
        await CopyTextAsync(ViewModel.ApplyGuidance.CopyableChecklist);
    }

    private async void CopyDiagnostics_Click(object sender, RoutedEventArgs e)
    {
        await CopyTextAsync(_lastDiagnostics);
    }

    private async void OpenSettings_Click(object sender, RoutedEventArgs e)
    {
        await OpenSettingsAsync();
    }

    private void BenchmarkSelection_Changed(object sender, SelectionChangedEventArgs e)
    {
        RefreshBenchmarkDraft();
    }

    private void BenchmarkNumber_ValueChanged(NumberBox sender, NumberBoxValueChangedEventArgs args)
    {
        RefreshBenchmarkDraft();
    }

    private void PreviewProfileSave_Click(object sender, RoutedEventArgs e)
    {
        var form = BuildProfileForm();

        if (!form.Validation.CanSave)
        {
            DiagnosticsBox.Text = string.Join(Environment.NewLine, form.Validation.Issues);
            return;
        }

        DiagnosticsBox.Text = FormatCommand(form.AddCommandArguments(ViewModel.DatabasePath));
    }

    private async void SaveProfile_Click(object sender, RoutedEventArgs e)
    {
        var form = BuildProfileForm();
        await MutateProfileAsync(WindowsDisplayText.Text("Profile add", "Thêm hồ sơ"), runner => runner.Add(ViewModel.DatabasePath, form));
    }

    private async void UpdateProfile_Click(object sender, RoutedEventArgs e)
    {
        var selected = ProfilesList.SelectedItem as ProfileManagementRow;
        if (selected is { CanEdit: false })
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Profile update blocked", "Đã chặn cập nhật hồ sơ"),
                new InvalidOperationException(WindowsDisplayText.Text(
                    "Built-in profiles cannot be edited from the Store-safe shell.",
                    "Không thể sửa hồ sơ built-in từ Store-safe shell.")));
            return;
        }

        var form = BuildProfileForm();
        var profileId = selected?.Id ?? ProfileIdOrDefault(form);
        await MutateProfileAsync(WindowsDisplayText.Text("Profile update", "Cập nhật hồ sơ"), runner => runner.Update(ViewModel.DatabasePath, profileId, form));
    }

    private async void DeleteProfile_Click(object sender, RoutedEventArgs e)
    {
        var selected = ProfilesList.SelectedItem as ProfileManagementRow;
        var form = BuildProfileForm();
        var profileId = selected?.Id ?? ProfileIdOrDefault(form);
        if (selected is { CanDelete: false })
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Profile delete blocked", "Đã chặn xóa hồ sơ"),
                new InvalidOperationException(WindowsDisplayText.Text(
                    "Built-in profiles cannot be deleted from the Store-safe shell.",
                    "Không thể xóa hồ sơ built-in từ Store-safe shell.")));
            return;
        }
        await MutateProfileAsync(WindowsDisplayText.Text("Profile delete", "Xóa hồ sơ"), runner => runner.Delete(ViewModel.DatabasePath, profileId));
    }

    private async void RefreshStorage_Click(object sender, RoutedEventArgs e)
    {
        await LoadRuntimeContractsAsync();
    }

    private async void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await Task.Run(() => new BenchmarkHistoryRunner(DefaultCliPath()).Clear(ViewModel.DatabasePath));
            await LoadRuntimeContractsAsync();
        }
        catch (Exception ex)
        {
            ShowDiagnostics(WindowsDisplayText.Text("Clear history failed", "Xóa lịch sử thất bại"), ex);
        }
    }

    private async void DeleteHistory_Click(object sender, RoutedEventArgs e)
    {
        if (HistoryList.SelectedItem is not BenchmarkHistoryRow row)
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Delete history skipped", "Bỏ qua xóa lịch sử"),
                new InvalidOperationException(WindowsDisplayText.Text(
                    "Select a history row first.",
                    "Chọn một dòng lịch sử trước.")));
            return;
        }

        try
        {
            await Task.Run(() => new BenchmarkHistoryRunner(DefaultCliPath()).Delete(ViewModel.DatabasePath, row.Id));
            await LoadRuntimeContractsAsync();
        }
        catch (Exception ex)
        {
            ShowDiagnostics(WindowsDisplayText.Text("Delete history failed", "Xóa lịch sử thất bại"), ex);
        }
    }

    private void ProfilesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ProfilesList.SelectedItem is not ProfileManagementRow row)
        {
            return;
        }

        ProfileNameBox.Text = row.Name;
        ProfileIdBox.Text = row.Id;
        Ipv4Box.Text = string.Join(", ", row.Ipv4Servers);
        Ipv6Box.Text = string.Join(", ", row.Ipv6Servers);
    }

    private void SectionNav_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item || item.Tag is not string tag)
        {
            return;
        }

        var target = tag switch
        {
            "Benchmark" => BenchmarkSection,
            "Apply" => ApplySection,
            "Profiles" => ProfilesSection,
            "History" => DiagnosticsSection,
            "Diagnostics" => DiagnosticsSection,
            _ => BenchmarkSection,
        };
        target.StartBringIntoView();
    }

    private async Task StartBenchmarkAsync(BenchmarkPlanViewModel plan)
    {
        _progressEvents.Clear();
        CommandPreviewBox.Text = FormatCommand(plan.CommandArguments);
        RenderProgress(BenchmarkRunState.Running, plan.Mode, plan.ProgressSummary);

        var startedAt = DateTimeOffset.UtcNow;
        try
        {
            var runner = new BenchmarkRunner(DefaultCliPath());
            var history = !plan.SupportsHistoryPersistence
                ? null
                : new BenchmarkHistoryPersistence(ViewModel.DatabasePath, $"windows-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}");
            var result = await Task.Run(() => runner.Run(
                plan,
                history,
                progressEvent =>
                {
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        _progressEvents.Add(progressEvent);
                        RenderProgress(BenchmarkRunState.Running, plan.Mode, plan.ProgressSummary);
                    });
                }));

            if (result.Succeeded)
            {
                var applyPlanMessage = await TryRefreshApplyGuidanceFromBenchmarkAsync(result.StandardOutput);
                RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, historySaved: history is not null);
                _lastDiagnostics = string.Join(
                    Environment.NewLine,
                    WindowsDisplayText.Text("Benchmark succeeded", "Benchmark thành công"),
                    $"{WindowsDisplayText.Text("Command", "Lệnh")}: {FormatCommand(result.CommandArguments)}",
                    applyPlanMessage,
                    string.IsNullOrWhiteSpace(result.StandardOutput) ? "stdout: <empty>" : result.StandardOutput.Trim(),
                    string.IsNullOrWhiteSpace(result.StandardError) ? "stderr: <empty>" : result.StandardError.Trim());
                DiagnosticsBox.Text = _lastDiagnostics;
                _ = LoadRuntimeContractsAsync();
                return;
            }

            var failure = result.ToFailure(FailureStepFor(plan.Mode), DateTimeOffset.UtcNow - startedAt);
            RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, failure: failure);
            _lastDiagnostics = failure.CopyableReport(WindowsDisplayText.ModeLabel(plan.Mode));
            DiagnosticsBox.Text = _lastDiagnostics;
        }
        catch (Exception ex)
        {
            var failure = new BenchmarkExecutionFailure(
                BenchmarkFailureStep.PreparingBenchmark,
                ex.Message,
                DateTimeOffset.UtcNow - startedAt,
                ex.ToString());
            RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, failure: failure);
            _lastDiagnostics = failure.CopyableReport(WindowsDisplayText.ModeLabel(plan.Mode));
            DiagnosticsBox.Text = _lastDiagnostics;
        }
    }

    private void RenderStaticState()
    {
        DnsServersBox.Text = ViewModel.ApplyGuidance.CopyableDnsServers;
        ChecklistBox.Text = ViewModel.ApplyGuidance.CopyableChecklist;
        ProfilesList.ItemsSource = ViewModel.ProfileRows;
        HistoryList.ItemsSource = ViewModel.HistoryRows.Count == 0
            ? Array.Empty<BenchmarkHistoryRow>()
            : ViewModel.HistoryRows;
        DiagnosticsBox.Text = string.Join(
            Environment.NewLine,
            WindowsDisplayText.Text("Profile list:", "Danh sách hồ sơ:"),
            FormatCommand(ViewModel.ProfileListCommand),
            "",
            WindowsDisplayText.Text("History list:", "Danh sách lịch sử:"),
            FormatCommand(ViewModel.HistoryListCommand),
            "",
            WindowsDisplayText.Text("Store policy:", "Chính sách Store:"),
            ViewModel.StorePlatformCapability.Notes.FirstOrDefault() ?? ViewModel.StorePolicy.Notes,
            "",
            WindowsDisplayText.Text("Power edition:", "Bản Power:"),
            ViewModel.PowerPlatformCapability.Notes.FirstOrDefault() ?? ViewModel.PowerPolicy.Notes);
        _lastDiagnostics = DiagnosticsBox.Text;
    }

    private async Task LoadRuntimeContractsAsync()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ViewModel.DatabasePath) ?? ".");
            var loaded = await Task.Run(() =>
            {
                var executablePath = DefaultCliPath();
                var catalog = new CatalogRunner(executablePath).Load();
                var capabilities = new CapabilityMatrixRunner(executablePath).Load();
                var profiles = new ProfileListRunner(executablePath).Load(ViewModel.DatabasePath);
                var history = new BenchmarkHistoryRunner(executablePath).Load(ViewModel.DatabasePath);
                var firstProfile = catalog.Profiles.FirstOrDefault(profile => profile.Protocol == DnsProtocol.Plain);
                var testedResolver = firstProfile?.Ipv4Servers.FirstOrDefault() is { } ipv4 ? $"{ipv4}:53" : null;
                var applyPlan = new ApplyPlanRunner(executablePath).Load(
                    new ApplyPlanRequest(
                        firstProfile?.Id,
                        testedResolver,
                        ApplyPlanConfidence.High,
                        ApplyPlanGateHealth.Healthy));

                return WindowsShellViewModel.CreateLoaded(
                    ViewModel.DatabasePath,
                    catalog,
                    capabilities,
                    applyPlan,
                    profiles,
                    history);
            });

            ViewModel = loaded;
            RenderStaticState();
            RefreshBenchmarkDraft();
        }
        catch (Exception ex)
        {
            ShowDiagnostics(WindowsDisplayText.Text("CLI contract load failed", "Tải contract CLI thất bại"), ex);
        }
    }

    private async Task<string> TryRefreshApplyGuidanceFromBenchmarkAsync(string standardOutput)
    {
        try
        {
            var result = BenchmarkResultJsonDecoder.Decode(standardOutput);
            var request = BenchmarkApplyPlanRequestFactory.MakeRequest(result);
            var applyPlan = await Task.Run(() => new ApplyPlanRunner(DefaultCliPath()).Load(request));
            ViewModel = ViewModel.WithApplyPlan(applyPlan);
            RenderStaticState();
            return result.Summary.CanRecommend
                ? WindowsDisplayText.Text(
                    $"Apply-plan refreshed for {request.profileId ?? "current DNS"}.",
                    $"Apply-plan đã cập nhật cho {request.profileId ?? "DNS hiện tại"}.")
                : WindowsDisplayText.Text(
                    "Apply-plan refreshed with protection guidance; benchmark did not produce a recommendation.",
                    "Apply-plan đã cập nhật với hướng dẫn bảo vệ; benchmark không tạo khuyến nghị.");
        }
        catch (Exception ex)
        {
            return WindowsDisplayText.Text("Apply-plan refresh skipped: ", "Bỏ qua cập nhật apply-plan: ") + ex.Message;
        }
    }

    private async Task MutateProfileAsync(string title, Action<CustomDnsProfileRunner> mutate)
    {
        try
        {
            await Task.Run(() => mutate(new CustomDnsProfileRunner(DefaultCliPath())));
            await LoadRuntimeContractsAsync();
        }
        catch (Exception ex)
        {
            ShowDiagnostics(title + WindowsDisplayText.Text(" failed", " thất bại"), ex);
        }
    }

    private CustomDnsProfileFormViewModel BuildProfileForm()
    {
        return new CustomDnsProfileFormViewModel(
            ProfileNameBox.Text,
            Ipv4Box.Text,
            Ipv6Box.Text);
    }

    private string ProfileIdOrDefault(CustomDnsProfileFormViewModel form)
    {
        return string.IsNullOrWhiteSpace(ProfileIdBox.Text)
            ? form.ProfileId
            : ProfileIdBox.Text.Trim();
    }

    private void ShowDiagnostics(string title, Exception ex)
    {
        _lastDiagnostics = string.Join(
            Environment.NewLine,
            title,
            ex.Message,
            "",
            ex.ToString());
        DiagnosticsBox.Text = _lastDiagnostics;
    }

    private void RenderProgress(
        BenchmarkRunState state,
        BenchmarkMode mode,
        BenchmarkProgressPlanSummary summary,
        BenchmarkExecutionFailure? failure = null,
        bool historySaved = false)
    {
        var progress = BenchmarkProgressViewModel.From(
            mode,
            state,
            summary,
            _progressEvents,
            failure,
            historySaved);

        StepsList.ItemsSource = progress.Steps
            .Select(step => $"{step.Title}: {WindowsDisplayText.StatusLabel(step.Status)}")
            .ToArray();
        ResolversList.ItemsSource = progress.ResolverStatuses.Count == 0
            ? summary.ResolverTargets.Select(target => $"{target.Name} ({target.Resolver}): {WindowsDisplayText.StatusLabel(ProgressStatus.Idle)}").ToArray()
            : progress.ResolverStatuses.Select(row => $"{row.Name} ({row.Resolver}): {WindowsDisplayText.StatusLabel(row.Status)} - {row.Detail}").ToArray();
    }

    private BenchmarkPlanViewModel BuildSelectedBenchmarkPlan()
    {
        return ViewModel.BuildBenchmarkPlan(CurrentBenchmarkSelection());
    }

    private BenchmarkControlSelection CurrentBenchmarkSelection()
    {
        return new BenchmarkControlSelection(
            ModeCombo?.SelectedIndex ?? 1,
            RecordFamilyCombo?.SelectedIndex ?? 0,
            ResolverFamilyCombo?.SelectedIndex ?? 0,
            SafeNumberValue(AttemptsBox, 2),
            SafeNumberValue(DnsTimeoutBox, 800),
            SafeNumberValue(TcpTimeoutBox, 1_000),
            SafeNumberValue(TcpTargetsBox, 4));
    }

    private void RefreshBenchmarkDraft()
    {
        if (CommandPreviewBox is null || StepsList is null || ResolversList is null)
        {
            return;
        }

        var plan = BuildSelectedBenchmarkPlan();
        CommandPreviewBox.Text = plan.Validation.CanRun
            ? FormatCommand(plan.CommandArguments)
            : string.Join(Environment.NewLine, plan.Validation.Issues);
        RenderProgress(BenchmarkRunState.Idle, plan.Mode, plan.ProgressSummary);
    }

    private static int SafeNumberValue(NumberBox? box, int fallback)
    {
        if (box is null || double.IsNaN(box.Value) || double.IsInfinity(box.Value))
        {
            return fallback;
        }

        return Math.Max(1, (int)box.Value);
    }

    private static BenchmarkFailureStep FailureStepFor(BenchmarkMode mode)
    {
        return mode == BenchmarkMode.DnsAndTcp
            ? BenchmarkFailureStep.MeasuringConnection
            : BenchmarkFailureStep.ResolvingDns;
    }

    private static string DefaultCliPath()
    {
        return CliExecutableLocator.LocateFromCurrentProcess();
    }

    private static string DefaultDatabasePath()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(localAppData, "DNSPilot", "dnspilot.sqlite");
    }

    private static async Task CopyTextAsync(string text)
    {
        var package = new DataPackage();
        package.SetText(text);
        Clipboard.SetContent(package);
        await Task.CompletedTask;
    }

    private static async Task OpenSettingsAsync()
    {
        var primary = new Uri(WindowsSettingsUri.NetworkAdvancedSettings.PrimaryUri);
        var launched = await Launcher.LaunchUriAsync(primary);
        if (!launched)
        {
            await Launcher.LaunchUriAsync(new Uri(WindowsSettingsUri.NetworkAdvancedSettings.FallbackUri));
        }
    }

    private static string FormatCommand(IReadOnlyList<string> arguments)
    {
        return string.Join(" ", arguments.Select(Quote));
    }

    private static string Quote(string value)
    {
        return value.Contains(' ', StringComparison.Ordinal) ? $"\"{value}\"" : value;
    }
}
