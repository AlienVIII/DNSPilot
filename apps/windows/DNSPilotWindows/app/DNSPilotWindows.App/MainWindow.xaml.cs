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
    }

    public WindowsShellViewModel ViewModel { get; }

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

    private void PreviewProfileSave_Click(object sender, RoutedEventArgs e)
    {
        var form = new CustomDnsProfileFormViewModel(
            ProfileNameBox.Text,
            Ipv4Box.Text,
            Ipv6Box.Text);

        if (!form.Validation.CanSave)
        {
            DiagnosticsBox.Text = string.Join(Environment.NewLine, form.Validation.Issues);
            return;
        }

        DiagnosticsBox.Text = FormatCommand(form.AddCommandArguments(ViewModel.DatabasePath));
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
                RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, historySaved: history is not null);
                _lastDiagnostics = string.Join(
                    Environment.NewLine,
                    "Benchmark succeeded",
                    $"Command: {FormatCommand(result.CommandArguments)}",
                    string.IsNullOrWhiteSpace(result.StandardOutput) ? "stdout: <empty>" : result.StandardOutput.Trim(),
                    string.IsNullOrWhiteSpace(result.StandardError) ? "stderr: <empty>" : result.StandardError.Trim());
                DiagnosticsBox.Text = _lastDiagnostics;
                return;
            }

            var failure = result.ToFailure(FailureStepFor(plan.Mode), DateTimeOffset.UtcNow - startedAt);
            RenderProgress(BenchmarkRunState.Completed, plan.Mode, plan.ProgressSummary, failure: failure);
            _lastDiagnostics = failure.CopyableReport(plan.Mode.DisplayLabel);
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
            _lastDiagnostics = failure.CopyableReport(plan.Mode.DisplayLabel);
            DiagnosticsBox.Text = _lastDiagnostics;
        }
    }

    private void RenderStaticState()
    {
        DnsServersBox.Text = ViewModel.ApplyGuidance.CopyableDnsServers;
        ChecklistBox.Text = ViewModel.ApplyGuidance.CopyableChecklist;
        DiagnosticsBox.Text = string.Join(
            Environment.NewLine,
            "Profile list:",
            FormatCommand(ViewModel.ProfileListCommand),
            "",
            "History list:",
            FormatCommand(ViewModel.HistoryListCommand),
            "",
            "Store policy:",
            ViewModel.StorePolicy.Notes);
        _lastDiagnostics = DiagnosticsBox.Text;
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
            .Select(step => $"{step.Title}: {step.Status}")
            .ToArray();
        ResolversList.ItemsSource = progress.ResolverStatuses.Count == 0
            ? summary.ResolverTargets.Select(target => $"{target.Name} ({target.Resolver}): idle").ToArray()
            : progress.ResolverStatuses.Select(row => $"{row.Name} ({row.Resolver}): {row.Status} - {row.Detail}").ToArray();
    }

    private BenchmarkPlanViewModel BuildSelectedBenchmarkPlan()
    {
        var mode = ModeCombo.SelectedIndex switch
        {
            0 => BenchmarkMode.DnsOnly,
            2 => BenchmarkMode.SystemDnsValidation,
            _ => BenchmarkMode.DnsAndTcp,
        };
        var recordFamily = RecordFamilyCombo.SelectedIndex switch
        {
            1 => DnsRecordFamily.Ipv4Only,
            2 => DnsRecordFamily.Ipv6Only,
            _ => DnsRecordFamily.Both,
        };
        var resolverFamily = ResolverFamilyCombo.SelectedIndex switch
        {
            1 => ResolverAddressFamily.Ipv4Only,
            2 => ResolverAddressFamily.Ipv6Only,
            _ => ResolverAddressFamily.Automatic,
        };
        var selectedProfiles = mode == BenchmarkMode.SystemDnsValidation
            ? Array.Empty<string>()
            : ViewModel.Catalog.Profiles.Where(profile => profile.Protocol == DnsProtocol.Plain).Take(3).Select(profile => profile.Id).ToArray();

        return new BenchmarkPlanViewModel(
            ViewModel.Catalog,
            selectedProfiles,
            selectedSuiteId: ViewModel.Catalog.TestSuites.FirstOrDefault()?.Id,
            customDomains: Array.Empty<string>(),
            attempts: Math.Max(1, (int)AttemptsBox.Value),
            dnsTimeoutMs: Math.Max(1, (int)DnsTimeoutBox.Value),
            connectTimeoutMs: Math.Max(1, (int)TcpTimeoutBox.Value),
            maxConnectTargetsPerDomain: Math.Max(1, (int)TcpTargetsBox.Value),
            recordFamily: recordFamily,
            resolverAddressFamily: resolverFamily,
            mode: mode);
    }

    private static BenchmarkFailureStep FailureStepFor(BenchmarkMode mode)
    {
        return mode == BenchmarkMode.DnsAndTcp
            ? BenchmarkFailureStep.MeasuringConnection
            : BenchmarkFailureStep.ResolvingDns;
    }

    private static string DefaultCliPath()
    {
        return Environment.GetEnvironmentVariable("DNSPILOT_CLI_PATH")
            ?? Path.Combine(AppContext.BaseDirectory, "dnspilot-cli.exe");
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
