using DNSPilotWindows.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.System;
using System.Reflection;

namespace DNSPilotWindows.App;

public sealed partial class MainWindow : Window
{
    private const string TutorialSeenKey = "dnspilot.setupTutorialSeen";
    private readonly List<BenchmarkProgressEvent> _progressEvents = [];
    private bool _benchmarkRunning;
    private CancellationTokenSource? _benchmarkCancellation;
    private BenchmarkResultPayload? _lastBenchmarkResult;
    private bool _hasShownFirstRunTutorial;
    private bool _tutorialOpen;
    private bool _runtimeContractsLoaded;
    private bool _preferencesRestored;
    private bool _restoringPreferences;
    private WindowsPreferenceState? _storedPreferences;
    private string _lastDiagnostics = "";

    public MainWindow()
    {
        ViewModel = WindowsShellViewModel.CreateDefault(DefaultDatabasePath());
        InitializeComponent();
        _storedPreferences = AppPreferenceStore.Load();
        RenderStaticState();
        RenderRuntimeReadiness();
        RenderProgress(BenchmarkRunState.Idle, ViewModel.BenchmarkPlan.Mode, ViewModel.BenchmarkPlan.ProgressSummary);
        CommandPreviewBox.Text = FormatCommand(ViewModel.BenchmarkPlan.CommandArguments);
        RootGrid.SizeChanged += RootGrid_SizeChanged;
        ShowConsumerDestination("CheckDns");
        _ = LoadRuntimeContractsAsync();
        Activated += MainWindow_Activated;
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
        await StartBenchmarkAsync(ViewModel.BuildQuickBenchmarkPlan(CurrentBenchmarkSelection()));
    }

    private async void QuickBenchmarkAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        await StartBenchmarkAsync(ViewModel.BuildQuickBenchmarkPlan(CurrentBenchmarkSelection()));
    }

    private void CancelBenchmarkAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        CancelBenchmark();
    }

    private async void SettingsAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        await OpenSettingsAsync();
    }

    private async void HelpAccelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        await ShowTutorialAsync();
    }

    private async void RunBenchmark_Click(object sender, RoutedEventArgs e)
    {
        await StartBenchmarkAsync(BuildSelectedBenchmarkPlan());
    }

    private void CancelBenchmark_Click(object sender, RoutedEventArgs e)
    {
        CancelBenchmark();
    }

    private async void ValidateSystemDns_Click(object sender, RoutedEventArgs e)
    {
        await StartBenchmarkAsync(ViewModel.BuildSystemDnsValidationPlan(CurrentBenchmarkSelection()));
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

    private async void ApplyInWindowsSettings_Click(object sender, RoutedEventArgs e)
    {
        await RunWithButtonDisabledAsync(sender, async () =>
        {
            if (!ViewModel.ApplyGuidance.CanStartGuidedApply || !await ConfirmGuidedApplyAsync())
            {
                return;
            }

            await CopyTextAsync(ViewModel.ApplyGuidance.CopyableDnsServers);
            await OpenSettingsAsync();
            RetestSystemDnsButton.Visibility = Visibility.Visible;
        });
    }

    private async void RetestSystemDns_Click(object sender, RoutedEventArgs e)
    {
        await StartBenchmarkAsync(ViewModel.BuildSystemDnsValidationPlan(CurrentBenchmarkSelection()));
    }

    private async void NetworkSignal_Changed(object sender, RoutedEventArgs e)
    {
        if (_lastBenchmarkResult is not null)
        {
            await TryRefreshApplyGuidanceFromBenchmarkAsync(_lastBenchmarkResult);
        }
    }

    private async void MainWindow_Activated(object sender, WindowActivatedEventArgs args)
    {
        if (_hasShownFirstRunTutorial
            || HasSeenSetupTutorial()
            || args.WindowActivationState == WindowActivationState.Deactivated)
        {
            return;
        }

        _hasShownFirstRunTutorial = true;
        if (await ShowTutorialAsync())
        {
            MarkSetupTutorialSeen();
        }
    }

    private async void ShowTutorial_Click(object sender, RoutedEventArgs e)
    {
        await ShowTutorialAsync();
    }

    private async void RetryRuntime_Click(object sender, RoutedEventArgs e)
    {
        await LoadRuntimeContractsAsync();
    }

    private async Task<bool> ShowTutorialAsync()
    {
        if (_tutorialOpen || RootGrid.XamlRoot is null)
        {
            return false;
        }

        var content = new StackPanel { Spacing = 8 };
        foreach (var line in new[]
        {
            WindowsDisplayText.Text("1. Run a benchmark.", "1. Chạy benchmark."),
            WindowsDisplayText.Text("2. Copy/open Windows DNS settings.", "2. Copy/mở Windows DNS settings."),
            WindowsDisplayText.Text("3. Retest System DNS.", "3. Retest DNS hệ thống."),
            WindowsDisplayText.Text("Store build never changes DNS silently.", "Bản Store không âm thầm đổi DNS."),
            WindowsDisplayText.Text("Partner Center trust is handled at release time.", "Chứng thực Partner Center xử lý khi release."),
        })
        {
            content.Children.Add(new TextBlock
            {
                Text = line,
                TextWrapping = TextWrapping.Wrap,
            });
        }

        var dialog = new ContentDialog
        {
            XamlRoot = RootGrid.XamlRoot,
            Title = WindowsDisplayText.Text("DNSPilot Setup", "Thiết lập DNSPilot"),
            Content = content,
            PrimaryButtonText = WindowsDisplayText.Text("OK", "OK"),
        };

        _tutorialOpen = true;
        try
        {
            await dialog.ShowAsync();
            return true;
        }
        finally
        {
            _tutorialOpen = false;
        }
    }

    private static bool HasSeenSetupTutorial()
    {
        try
        {
            return ApplicationData.Current.LocalSettings.Values[TutorialSeenKey] is bool seen && seen;
        }
        catch
        {
            return false;
        }
    }

    private static void MarkSetupTutorialSeen()
    {
        try
        {
            ApplicationData.Current.LocalSettings.Values[TutorialSeenKey] = true;
        }
        catch
        {
            // Unpackaged/dev launch can lack app data; session guard still prevents repeats.
        }
    }

    private void BenchmarkSelection_Changed(object sender, SelectionChangedEventArgs e)
    {
        RefreshBenchmarkDraft();
        PersistPreferences();
    }

    private void BenchmarkNumber_ValueChanged(NumberBox sender, NumberBoxValueChangedEventArgs args)
    {
        RefreshBenchmarkDraft();
        PersistPreferences();
    }

    private void BenchmarkProfiles_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        RefreshBenchmarkDraft();
        PersistPreferences();
    }

    private void Language_Changed(object sender, SelectionChangedEventArgs e)
    {
        PersistPreferences();
    }

    private void DefaultSuiteQuickPick_Click(object sender, RoutedEventArgs e)
    {
        SelectSuiteQuickPick(DefaultSuiteQuickPickButton.Tag as string);
    }

    private void VietnamSuiteQuickPick_Click(object sender, RoutedEventArgs e)
    {
        SelectSuiteQuickPick(VietnamSuiteQuickPickButton.Tag as string);
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
        var form = BuildProfileForm();
        var profileId = selected?.Id ?? ProfileIdOrDefault(form);
        var validation = ProfileManagementViewModel.ValidateMutation(
            ViewModel.ProfileRows,
            ProfileMutationKind.Update,
            profileId);
        if (!validation.CanMutate)
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Profile update blocked", "Đã chặn cập nhật hồ sơ"),
                new InvalidOperationException(string.Join(Environment.NewLine, validation.Issues)));
            return;
        }

        await MutateProfileAsync(WindowsDisplayText.Text("Profile update", "Cập nhật hồ sơ"), runner => runner.Update(ViewModel.DatabasePath, profileId, form));
    }

    private async void DeleteProfile_Click(object sender, RoutedEventArgs e)
    {
        var selected = ProfilesList.SelectedItem as ProfileManagementRow;
        var form = BuildProfileForm();
        var profileId = selected?.Id ?? ProfileIdOrDefault(form);
        var validation = ProfileManagementViewModel.ValidateMutation(
            ViewModel.ProfileRows,
            ProfileMutationKind.Delete,
            profileId);
        if (!validation.CanMutate)
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Profile delete blocked", "Đã chặn xóa hồ sơ"),
                new InvalidOperationException(string.Join(Environment.NewLine, validation.Issues)));
            return;
        }

        if (!await ConfirmDestructiveActionAsync(
                WindowsDisplayText.Text("Delete DNS profile?", "Xóa hồ sơ DNS?"),
                WindowsDisplayText.Text(
                    $"Delete {selected?.Name ?? profileId} ({profileId})? This cannot be undone.",
                    $"Xóa {selected?.Name ?? profileId} ({profileId})? Không thể hoàn tác."),
                WindowsDisplayText.Text("Delete", "Xóa")))
        {
            return;
        }

        await RunWithButtonDisabledAsync(
            sender,
            () => MutateProfileAsync(
                WindowsDisplayText.Text("Profile delete", "Xóa hồ sơ"),
                runner => runner.Delete(ViewModel.DatabasePath, profileId)));
    }

    private void PreviewSuiteSave_Click(object sender, RoutedEventArgs e)
    {
        var form = BuildSuiteForm();

        if (!form.Validation.CanSave)
        {
            DiagnosticsBox.Text = string.Join(Environment.NewLine, form.Validation.Issues);
            return;
        }

        DiagnosticsBox.Text = FormatCommand(form.AddCommandArguments(ViewModel.DatabasePath));
    }

    private async void SaveSuite_Click(object sender, RoutedEventArgs e)
    {
        var form = BuildSuiteForm();
        await MutateSuiteAsync(WindowsDisplayText.Text("Suite add", "Thêm suite"), runner => runner.Add(ViewModel.DatabasePath, form));
    }

    private async void UpdateSuite_Click(object sender, RoutedEventArgs e)
    {
        var selected = SuitesList.SelectedItem as SuiteManagementRow;
        var form = BuildSuiteForm();
        var suiteId = selected?.Id ?? SuiteIdOrDefault(form);
        var validation = SuiteManagementViewModel.ValidateMutation(
            ViewModel.SuiteRows,
            SuiteMutationKind.Update,
            suiteId);
        if (!validation.CanMutate)
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Suite update blocked", "Đã chặn cập nhật suite"),
                new InvalidOperationException(string.Join(Environment.NewLine, validation.Issues)));
            return;
        }

        await MutateSuiteAsync(WindowsDisplayText.Text("Suite update", "Cập nhật suite"), runner => runner.Update(ViewModel.DatabasePath, suiteId, form));
    }

    private async void DeleteSuite_Click(object sender, RoutedEventArgs e)
    {
        var selected = SuitesList.SelectedItem as SuiteManagementRow;
        var form = BuildSuiteForm();
        var suiteId = selected?.Id ?? SuiteIdOrDefault(form);
        var validation = SuiteManagementViewModel.ValidateMutation(
            ViewModel.SuiteRows,
            SuiteMutationKind.Delete,
            suiteId);
        if (!validation.CanMutate)
        {
            ShowDiagnostics(
                WindowsDisplayText.Text("Suite delete blocked", "Đã chặn xóa suite"),
                new InvalidOperationException(string.Join(Environment.NewLine, validation.Issues)));
            return;
        }

        if (!await ConfirmDestructiveActionAsync(
                WindowsDisplayText.Text("Delete domain suite?", "Xóa suite domain?"),
                WindowsDisplayText.Text(
                    $"Delete {selected?.Name ?? suiteId} ({suiteId})? This cannot be undone.",
                    $"Xóa {selected?.Name ?? suiteId} ({suiteId})? Không thể hoàn tác."),
                WindowsDisplayText.Text("Delete", "Xóa")))
        {
            return;
        }

        await RunWithButtonDisabledAsync(
            sender,
            () => MutateSuiteAsync(
                WindowsDisplayText.Text("Suite delete", "Xóa suite"),
                runner => runner.Delete(ViewModel.DatabasePath, suiteId)));
    }

    private async void RefreshStorage_Click(object sender, RoutedEventArgs e)
    {
        await LoadRuntimeContractsAsync();
    }

    private async void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmDestructiveActionAsync(
                WindowsDisplayText.Text("Clear benchmark history?", "Xóa toàn bộ lịch sử benchmark?"),
                WindowsDisplayText.Text(
                    "Delete all saved benchmark history? This cannot be undone.",
                    "Xóa toàn bộ lịch sử benchmark đã lưu? Không thể hoàn tác."),
                WindowsDisplayText.Text("Clear", "Xóa hết")))
        {
            return;
        }

        await RunWithButtonDisabledAsync(sender, async () =>
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
        });
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

        if (!await ConfirmDestructiveActionAsync(
                WindowsDisplayText.Text("Delete benchmark history?", "Xóa lịch sử benchmark?"),
                WindowsDisplayText.Text(
                    $"Delete saved benchmark {row.Id}? This cannot be undone.",
                    $"Xóa benchmark đã lưu {row.Id}? Không thể hoàn tác."),
                WindowsDisplayText.Text("Delete", "Xóa")))
        {
            return;
        }

        await RunWithButtonDisabledAsync(sender, async () =>
        {
            try
            {
                await Task.Run(() => new BenchmarkHistoryRunner(DefaultCliPath()).Delete(ViewModel.DatabasePath, row.Id));
                await LoadRuntimeContractsAsync();
            }
            catch (Exception ex)
            {
                ShowDiagnostics(WindowsDisplayText.Text("Delete history failed", "Xóa lịch sử thất bại"), ex);
            }
        });
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

    private void SuitesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (SuitesList.SelectedItem is not SuiteManagementRow row)
        {
            return;
        }

        SuiteNameBox.Text = row.Name;
        SuiteIdBox.Text = row.Id;
        SuiteDomainsBox.Text = string.Join(", ", row.Domains);
    }

    private void SectionNav_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item || item.Tag is not string tag)
        {
            return;
        }

        ShowConsumerDestination(tag);
    }

    private void ShowConsumerDestination(string tag)
    {
        var showCheckDns = tag == "CheckDns";
        var showProfiles = tag == "Profiles";
        var showHistory = tag == "History";

        BenchmarkSection.Visibility = showCheckDns ? Visibility.Visible : Visibility.Collapsed;
        ProcessSection.Visibility = showCheckDns ? Visibility.Visible : Visibility.Collapsed;
        ApplySection.Visibility = showCheckDns ? Visibility.Visible : Visibility.Collapsed;
        ProfilesSection.Visibility = showProfiles ? Visibility.Visible : Visibility.Collapsed;
        HistorySection.Visibility = showHistory ? Visibility.Visible : Visibility.Collapsed;

        var target = showProfiles
            ? ProfilesSection
            : showHistory
                ? HistorySection
                : BenchmarkSection;
        target.StartBringIntoView();
    }

    private void RootGrid_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        ApplyResponsiveLayout(e.NewSize.Width);
    }

    private void ApplyResponsiveLayout(double width)
    {
        var compact = width < 960;
        ContentPrimaryColumn.Width = compact ? new GridLength(1, GridUnitType.Star) : new GridLength(1.1, GridUnitType.Star);
        ContentSecondaryColumn.Width = compact ? new GridLength(0) : new GridLength(0.9, GridUnitType.Star);
        ProcessSection.SetValue(Grid.ColumnProperty, compact ? 0 : 1);
        ProcessSection.SetValue(Grid.RowProperty, compact ? 1 : 0);
        ApplySection.SetValue(Grid.ColumnProperty, 0);
        ApplySection.SetValue(Grid.RowProperty, compact ? 2 : 1);
        ProfilesSection.SetValue(Grid.ColumnProperty, compact ? 0 : 1);
        ProfilesSection.SetValue(Grid.RowProperty, compact ? 3 : 1);
        HistorySection.SetValue(Grid.ColumnProperty, compact ? 0 : 1);
        HistorySection.SetValue(Grid.RowProperty, compact ? 3 : 1);
        VisualStateManager.GoToElementState(RootGrid, compact ? "CompactLayout" : "WideLayout", useTransitions: false);
    }

    private async Task StartBenchmarkAsync(BenchmarkPlanViewModel plan)
    {
        if (!ViewModel.RuntimeReadiness.CanBenchmark)
        {
            _lastDiagnostics = ViewModel.RuntimeReadiness.CopyableReport(AppVersion());
            DiagnosticsBox.Text = _lastDiagnostics;
            return;
        }

        if (_benchmarkRunning)
        {
            return;
        }

        _progressEvents.Clear();
        ClearApplyGuidanceForNewBenchmark();
        CommandPreviewBox.Text = FormatCommand(plan.CommandArguments);
        if (!plan.Validation.CanRun)
        {
            var failure = new BenchmarkExecutionFailure(
                BenchmarkFailureStep.PreparingBenchmark,
                string.Join(Environment.NewLine, plan.Validation.Issues),
                elapsed: TimeSpan.Zero,
                debugLog: CommandPreviewBox.Text);
            RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, failure: failure);
            _lastDiagnostics = failure.CopyableReport(WindowsDisplayText.ModeLabel(plan.Mode));
            DiagnosticsBox.Text = _lastDiagnostics;
            return;
        }

        _benchmarkRunning = true;
        var cancellation = new CancellationTokenSource();
        _benchmarkCancellation = cancellation;
        SetBenchmarkActionsEnabled(false);
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
                }, cancellationToken: cancellation.Token));

            if (result.WasCancelled)
            {
                var failure = new BenchmarkExecutionFailure(
                    FailureStepFor(plan.Mode),
                    WindowsDisplayText.Text("Benchmark cancelled.", "Benchmark đã hủy."),
                    DateTimeOffset.UtcNow - startedAt,
                    result.StandardError);
                RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, failure: failure);
                _lastDiagnostics = failure.CopyableReport(WindowsDisplayText.ModeLabel(plan.Mode));
                DiagnosticsBox.Text = _lastDiagnostics;
                return;
            }

            if (result.Succeeded)
            {
                _lastBenchmarkResult = TryDecodeBenchmarkResult(result.StandardOutput);
                var benchmarkReport = _lastBenchmarkResult is null
                    ? null
                    : BenchmarkResultReportViewModel.FromResult(_lastBenchmarkResult);
                var applyPlanMessage = _lastBenchmarkResult is null
                    ? WindowsDisplayText.Text(
                        "Apply-plan refresh skipped: benchmark output did not match the supported result schema.",
                        "Bỏ qua cập nhật apply-plan: kết quả benchmark không khớp schema được hỗ trợ.")
                    : await TryRefreshApplyGuidanceFromBenchmarkAsync(_lastBenchmarkResult);
                RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, historySaved: result.HistoryWasSaved);
                RenderRecommendationReport(benchmarkReport);
                _lastDiagnostics = FormatBenchmarkSuccessDiagnostics(result, applyPlanMessage, benchmarkReport);
                DiagnosticsBox.Text = _lastDiagnostics;
                _ = LoadRuntimeContractsAsync(resetDiagnostics: false);
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
        finally
        {
            if (ReferenceEquals(_benchmarkCancellation, cancellation))
            {
                _benchmarkCancellation = null;
            }
            cancellation.Dispose();
            _benchmarkRunning = false;
            SetBenchmarkActionsEnabled(true);
        }
    }

    private void SetBenchmarkActionsEnabled(bool isEnabled)
    {
        var canBenchmark = isEnabled && ViewModel.RuntimeReadiness.CanBenchmark;
        QuickBenchmarkButton.IsEnabled = canBenchmark;
        ValidateSystemDnsButton.IsEnabled = canBenchmark;
        RunBenchmarkButton.IsEnabled = canBenchmark;
        CancelBenchmarkButton.Visibility = _benchmarkRunning ? Visibility.Visible : Visibility.Collapsed;
        CancelBenchmarkButton.IsEnabled = _benchmarkRunning && _benchmarkCancellation is { IsCancellationRequested: false };
    }

    private void RenderStaticState(bool resetDiagnostics = true)
    {
        var selectedProfileIds = SelectedBenchmarkProfileIds() ?? Array.Empty<string>();
        var selectedSuiteId = SelectedBenchmarkSuiteId();
        DnsServersBox.Text = ViewModel.ApplyGuidance.CopyableDnsServers;
        ChecklistBox.Text = ViewModel.ApplyGuidance.CopyableChecklist;
        CopyDnsButton.Visibility = ViewModel.ApplyGuidance.Actions.Any(action => action.Kind == ApplyActionKind.CopyDnsServers)
            ? Visibility.Visible
            : Visibility.Collapsed;
        ApplyInSettingsButton.Visibility = ViewModel.ApplyGuidance.CanStartGuidedApply
            ? Visibility.Visible
            : Visibility.Collapsed;
        var canApplyGuidance = ViewModel.RuntimeReadiness.CanApplyGuidance && !_benchmarkRunning;
        CopyDnsButton.IsEnabled = canApplyGuidance;
        ApplyInSettingsButton.IsEnabled = canApplyGuidance && ViewModel.ApplyGuidance.CanStartGuidedApply;
        CopyChecklistButton.IsEnabled = canApplyGuidance;
        var benchmarkProfileOptions = ViewModel.BenchmarkProfileOptions;
        BenchmarkProfilesList.ItemsSource = benchmarkProfileOptions;
        SelectBenchmarkProfiles(
            benchmarkProfileOptions,
            selectedProfileIds,
            selectDefaultsWhenEmpty: !_runtimeContractsLoaded || !_preferencesRestored);
        var benchmarkSuiteOptions = ViewModel.BenchmarkSuiteOptions;
        SuiteCombo.ItemsSource = benchmarkSuiteOptions;
        SelectBenchmarkSuite(benchmarkSuiteOptions, selectedSuiteId);
        RenderCatalogQuickPicks();
        RestorePreferencesIfReady();
        ProfilesList.ItemsSource = ViewModel.ProfileRows;
        SuitesList.ItemsSource = ViewModel.SuiteRows;
        HistoryList.ItemsSource = ViewModel.HistoryRows.Count == 0
            ? Array.Empty<BenchmarkHistoryRow>()
            : ViewModel.HistoryRows;
        CapabilityRowsList.ItemsSource = WindowsCapabilityStatusRows.From(
            ViewModel.StorePlatformCapability,
            ViewModel.PowerPlatformCapability,
            ViewModel.RuntimeReadiness);
        SetRuntimeSurfaceAvailability();

        if (!resetDiagnostics)
        {
            return;
        }

        DiagnosticsBox.Text = string.Join(
            Environment.NewLine,
            WindowsDisplayText.Text("Profile list:", "Danh sách hồ sơ:"),
            FormatCommand(ViewModel.ProfileListCommand),
            "",
            WindowsDisplayText.Text("Suite list:", "Danh sách suite:"),
            FormatCommand(ViewModel.SuiteListCommand),
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
        RenderRecommendationReport(null);
    }

    private void RenderRuntimeReadiness(bool replaceDiagnostics = false)
    {
        var readiness = ViewModel.RuntimeReadiness;
        RuntimeStatusBar.Title = readiness.Title;
        RuntimeStatusBar.Message = readiness.Summary;
        RuntimeStatusBar.Severity = readiness.State switch
        {
            RuntimeReadinessState.Ready => InfoBarSeverity.Success,
            RuntimeReadinessState.Incompatible => InfoBarSeverity.Error,
            RuntimeReadinessState.Degraded => InfoBarSeverity.Warning,
            _ => InfoBarSeverity.Informational,
        };
        RetryRuntimeButton.Visibility = readiness.State == RuntimeReadinessState.Checking
            ? Visibility.Collapsed
            : Visibility.Visible;
        SetRuntimeSurfaceAvailability();

        if (replaceDiagnostics || readiness.State is RuntimeReadinessState.Degraded or RuntimeReadinessState.Incompatible)
        {
            _lastDiagnostics = readiness.CopyableReport(AppVersion());
            DiagnosticsBox.Text = _lastDiagnostics;
        }
    }

    private void SetRuntimeSurfaceAvailability()
    {
        var readiness = ViewModel.RuntimeReadiness;
        SetBenchmarkActionsEnabled(!_benchmarkRunning);
        ProfilesSection.IsEnabled = readiness.CanManageProfiles;
        SuitesSection.IsEnabled = readiness.CanManageSuites;
        HistoryList.IsEnabled = readiness.CanReadHistory;
        RefreshStorageButton.IsEnabled = readiness.CanReadHistory;
        ClearHistoryButton.IsEnabled = readiness.CanReadHistory;
        DeleteHistoryButton.IsEnabled = readiness.CanReadHistory;
        var canApplyGuidance = readiness.CanApplyGuidance && !_benchmarkRunning;
        CopyDnsButton.IsEnabled = canApplyGuidance;
        ApplyInSettingsButton.IsEnabled = canApplyGuidance && ViewModel.ApplyGuidance.CanStartGuidedApply;
        CopyChecklistButton.IsEnabled = canApplyGuidance;
    }

    private async Task LoadRuntimeContractsAsync(bool resetDiagnostics = true)
    {
        ViewModel = ViewModel.WithRuntimeReadiness(RuntimeReadinessViewModel.Checking(DefaultCliPath()));
        RenderRuntimeReadiness();

        try
        {
            var databasePath = ViewModel.DatabasePath;
            var loaded = await Task.Run(() => new RuntimeContractLoader().Load(DefaultCliPath(), databasePath));

            ViewModel = WindowsShellViewModel.CreateFromRuntimeLoad(databasePath, loaded);
            _runtimeContractsLoaded = true;
            RenderStaticState(resetDiagnostics);
            RenderRuntimeReadiness(replaceDiagnostics: !ViewModel.RuntimeReadiness.CanBenchmark || !ViewModel.RuntimeReadiness.CanApplyGuidance);
            RefreshBenchmarkDraft();
        }
        catch (Exception ex)
        {
            ShowDiagnostics(WindowsDisplayText.Text("CLI contract load failed", "Tải contract CLI thất bại"), ex);
        }
    }

    private async Task<string> TryRefreshApplyGuidanceFromBenchmarkAsync(BenchmarkResultPayload result)
    {
        try
        {
            var request = BenchmarkApplyPlanRequestFactory.MakeRequest(
                result,
                vpnActive: VpnActiveCheckBox.IsChecked == true,
                mdmProfileActive: ManagedDnsCheckBox.IsChecked == true,
                corporateDnsDetected: CorporateDnsCheckBox.IsChecked == true,
                captivePortalDetected: CaptivePortalCheckBox.IsChecked == true);
            var applyPlan = await Task.Run(() => new ApplyPlanRunner(DefaultCliPath()).Load(request));
            ViewModel = ViewModel.WithApplyPlan(applyPlan);
            RenderStaticState(resetDiagnostics: false);
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

    private void ClearApplyGuidanceForNewBenchmark()
    {
        _lastBenchmarkResult = null;
        ViewModel = ViewModel.WithApplyPlan(
            new ApplyPlan(
                ApplyDecision.Block,
                WindowsDisplayText.Text("Benchmark in progress", "Benchmark đang chạy"),
                Array.Empty<string>(),
                TestedResolver: null,
                WindowsDisplayText.Text(
                    "Apply guidance stays blocked until this benchmark completes and Core returns a new plan.",
                    "Hướng dẫn apply bị chặn cho đến khi benchmark hoàn tất và Core trả về kế hoạch mới."))
            {
                Disposition = "benchmark-in-progress",
            });
        RenderStaticState(resetDiagnostics: false);
    }

    private void RenderRecommendationReport(BenchmarkResultReportViewModel? report)
    {
        if (report is null)
        {
            RecommendationSummaryText.Text = WindowsDisplayText.Text(
                "Run a benchmark to populate recommendation diagnostics.",
                "Chạy benchmark để hiển thị chẩn đoán khuyến nghị.");
            RecommendationLineText.Text = "";
            RecommendationResolversList.ItemsSource = Array.Empty<string>();
            RecommendationNotesList.ItemsSource = Array.Empty<string>();
            return;
        }

        RecommendationSummaryText.Text = string.Join(Environment.NewLine, report.SummaryLine, report.Safety.FastestObservedLine);
        RecommendationLineText.Text = report.RecommendationLine;
        RecommendationResolversList.ItemsSource = report.ResolverLines;
        RecommendationNotesList.ItemsSource = report.NoteLines;
    }

    private static string FormatBenchmarkSuccessDiagnostics(
        BenchmarkRunResult result,
        string applyPlanMessage,
        BenchmarkResultReportViewModel? benchmarkReport)
    {
        return WindowsDiagnosticRedactor.Redact(string.Join(
            Environment.NewLine,
            WindowsDisplayText.Text("Benchmark succeeded", "Benchmark thành công"),
            $"{WindowsDisplayText.Text("Command", "Lệnh")}: {FormatCommand(result.CommandArguments)}",
            applyPlanMessage,
            benchmarkReport?.CopyableReport
                ?? (string.IsNullOrWhiteSpace(result.StandardOutput) ? "stdout: <empty>" : result.StandardOutput.Trim()),
            string.IsNullOrWhiteSpace(result.StandardError) ? "stderr: <empty>" : result.StandardError.Trim()));
    }

    private static BenchmarkResultPayload? TryDecodeBenchmarkResult(string standardOutput)
    {
        try
        {
            return BenchmarkResultJsonDecoder.Decode(standardOutput);
        }
        catch
        {
            return null;
        }
    }

    private async Task<bool> ConfirmGuidedApplyAsync()
    {
        if (RootGrid.XamlRoot is null)
        {
            return false;
        }

        var dialog = new ContentDialog
        {
            XamlRoot = RootGrid.XamlRoot,
            Title = WindowsDisplayText.Text("Apply in Windows Settings", "Áp dụng trong Windows Settings"),
            Content = WindowsDisplayText.Text(
                "DNS Pilot will copy the recommended DNS servers and open Windows Settings. You make and save the DNS change yourself.",
                "DNS Pilot sẽ sao chép DNS server được khuyến nghị và mở Windows Settings. Bạn tự thực hiện và lưu thay đổi DNS."),
            PrimaryButtonText = WindowsDisplayText.Text("Copy and open Settings", "Sao chép và mở Settings"),
            CloseButtonText = WindowsDisplayText.Text("Cancel", "Hủy"),
            DefaultButton = ContentDialogButton.Close,
        };

        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private async Task<bool> ConfirmDestructiveActionAsync(
        string title,
        string content,
        string primaryButtonText)
    {
        if (RootGrid.XamlRoot is null)
        {
            return false;
        }

        var dialog = new ContentDialog
        {
            XamlRoot = RootGrid.XamlRoot,
            Title = title,
            Content = content,
            PrimaryButtonText = primaryButtonText,
            CloseButtonText = WindowsDisplayText.Text("Cancel", "Hủy"),
            DefaultButton = ContentDialogButton.Close,
        };

        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private static async Task RunWithButtonDisabledAsync(object sender, Func<Task> action)
    {
        if (sender is not Button button)
        {
            await action();
            return;
        }

        if (!button.IsEnabled)
        {
            return;
        }

        button.IsEnabled = false;
        try
        {
            await action();
        }
        finally
        {
            button.IsEnabled = true;
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

    private async Task MutateSuiteAsync(string title, Action<CustomDomainSuiteRunner> mutate)
    {
        try
        {
            await Task.Run(() => mutate(new CustomDomainSuiteRunner(DefaultCliPath())));
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

    private CustomDomainSuiteFormViewModel BuildSuiteForm()
    {
        return new CustomDomainSuiteFormViewModel(
            SuiteNameBox.Text,
            SuiteDomainsBox.Text);
    }

    private string ProfileIdOrDefault(CustomDnsProfileFormViewModel form)
    {
        return string.IsNullOrWhiteSpace(ProfileIdBox.Text)
            ? form.ProfileId
            : ProfileIdBox.Text.Trim();
    }

    private string SuiteIdOrDefault(CustomDomainSuiteFormViewModel form)
    {
        return string.IsNullOrWhiteSpace(SuiteIdBox.Text)
            ? form.SuiteId
            : SuiteIdBox.Text.Trim();
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
            SafeNumberValue(TcpTargetsBox, 4),
            SelectedBenchmarkProfileIds(),
            SelectedBenchmarkSuiteId());
    }

    private IReadOnlyList<string>? SelectedBenchmarkProfileIds()
    {
        if (BenchmarkProfilesList is null)
        {
            return null;
        }

        return BenchmarkProfilesList.SelectedItems
            .OfType<BenchmarkProfileOptionRow>()
            .Where(row => row.CanBenchmark)
            .Select(row => row.Id)
            .ToArray();
    }

    private string? SelectedBenchmarkSuiteId()
    {
        return SuiteCombo?.SelectedItem is BenchmarkSuiteOptionRow row
            ? row.Id
            : null;
    }

    private void SelectBenchmarkProfiles(
        IReadOnlyList<BenchmarkProfileOptionRow> options,
        IReadOnlyList<string> preferredProfileIds,
        bool selectDefaultsWhenEmpty = true)
    {
        if (BenchmarkProfilesList is null)
        {
            return;
        }

        var selection = BenchmarkProfilePreferenceSelection.Resolve(
            options,
            preferredProfileIds,
            selectDefaultsWhenEmpty);
        var selectedIds = selection.ToHashSet(StringComparer.Ordinal);

        BenchmarkProfilesList.SelectedItems.Clear();
        foreach (var option in options.Where(option => option.CanBenchmark && selectedIds.Contains(option.Id)))
        {
            BenchmarkProfilesList.SelectedItems.Add(option);
        }
    }

    private void SelectBenchmarkSuite(
        IReadOnlyList<BenchmarkSuiteOptionRow> options,
        string? preferredSuiteId)
    {
        if (SuiteCombo is null)
        {
            return;
        }

        var selection = preferredSuiteId is null
            ? options.FirstOrDefault()
            : options.FirstOrDefault(option => option.Id == preferredSuiteId) ?? options.FirstOrDefault();
        SuiteCombo.SelectedItem = selection;
    }

    private void RenderCatalogQuickPicks()
    {
        var quickPicks = CatalogQuickPicks.FromCatalog(ViewModel.Catalog);
        ConfigureSuiteQuickPick(DefaultSuiteQuickPickButton, quickPicks.DefaultSuiteId);
        ConfigureSuiteQuickPick(VietnamSuiteQuickPickButton, quickPicks.VietnamSuiteId);
    }

    private static void ConfigureSuiteQuickPick(Button button, string? suiteId)
    {
        button.Tag = suiteId;
        button.Visibility = string.IsNullOrWhiteSpace(suiteId)
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    private void SelectSuiteQuickPick(string? suiteId)
    {
        if (string.IsNullOrWhiteSpace(suiteId))
        {
            return;
        }

        SelectBenchmarkSuite(ViewModel.BenchmarkSuiteOptions, suiteId);
        RefreshBenchmarkDraft();
        PersistPreferences();
    }

    private void RestorePreferencesIfReady()
    {
        if (!_runtimeContractsLoaded || _preferencesRestored)
        {
            return;
        }

        var preference = WindowsPreferenceState.Normalize(_storedPreferences, ViewModel.Catalog);
        _restoringPreferences = true;
        try
        {
            ModeCombo.SelectedIndex = preference.ModeIndex;
            RecordFamilyCombo.SelectedIndex = preference.RecordFamilyIndex;
            ResolverFamilyCombo.SelectedIndex = preference.ResolverFamilyIndex;
            AttemptsBox.Value = preference.Attempts;
            DnsTimeoutBox.Value = preference.DnsTimeoutMs;
            TcpTimeoutBox.Value = preference.TcpTimeoutMs;
            TcpTargetsBox.Value = preference.TcpTargetsPerDomain;
            SelectBenchmarkProfiles(
                ViewModel.BenchmarkProfileOptions,
                preference.SelectedProfileIds,
                selectDefaultsWhenEmpty: false);
            SelectBenchmarkSuite(ViewModel.BenchmarkSuiteOptions, preference.SelectedSuiteId);
            LanguageCombo.SelectedIndex = preference.LanguageTag == "vi-VN" ? 1 : 0;
        }
        finally
        {
            _restoringPreferences = false;
            _preferencesRestored = true;
        }

        PersistPreferences();
    }

    private void PersistPreferences()
    {
        if (!_runtimeContractsLoaded || _restoringPreferences)
        {
            return;
        }

        var selection = CurrentBenchmarkSelection();
        var preference = WindowsPreferenceState.Normalize(
            new WindowsPreferenceState(
                WindowsPreferenceState.CurrentSchemaVersion,
                selection.ModeIndex,
                selection.RecordFamilyIndex,
                selection.ResolverFamilyIndex,
                selection.Attempts,
                selection.DnsTimeoutMs,
                selection.TcpTimeoutMs,
                selection.TcpTargetsPerDomain,
                selection.SelectedProfileIds ?? Array.Empty<string>(),
                selection.SelectedSuiteId,
                SelectedLanguageTag()),
            ViewModel.Catalog);
        _storedPreferences = preference;
        AppPreferenceStore.Save(preference);
    }

    private string SelectedLanguageTag()
    {
        return (LanguageCombo.SelectedItem as ComboBoxItem)?.Tag as string is "vi-VN"
            ? "vi-VN"
            : "en-US";
    }

    private void RefreshBenchmarkDraft()
    {
        if (CommandPreviewBox is null || StepsList is null || ResolversList is null)
        {
            return;
        }

        var plan = BuildSelectedBenchmarkPlan();
        SuiteLimitationNoticeText.Text = plan.SuiteLimitationNotice ?? "";
        SuiteLimitationNoticeText.Visibility = plan.ModeWasForcedBySuite
            ? Visibility.Visible
            : Visibility.Collapsed;
        if (plan.ModeWasForcedBySuite && ModeCombo.SelectedIndex != 1)
        {
            ModeCombo.SelectedIndex = 1;
        }
        CommandPreviewBox.Text = plan.Validation.CanRun
            ? FormatCommand(plan.CommandArguments)
            : string.Join(Environment.NewLine, plan.Validation.Issues);
        RenderProgress(BenchmarkRunState.Idle, plan.Mode, plan.ProgressSummary);
    }

    private void CancelBenchmark()
    {
        if (!_benchmarkRunning || _benchmarkCancellation is not { IsCancellationRequested: false } cancellation)
        {
            return;
        }

        cancellation.Cancel();
        CancelBenchmarkButton.IsEnabled = false;
        var plan = BuildSelectedBenchmarkPlan();
        RenderProgress(BenchmarkRunState.Cancelling, plan.Mode, plan.ProgressSummary);
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

    private static string AppVersion()
    {
        return Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "unavailable";
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
