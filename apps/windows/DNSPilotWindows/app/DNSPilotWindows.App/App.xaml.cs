using Microsoft.UI.Xaml;

namespace DNSPilotWindows.App;

public partial class App : Application
{
    private Window? _window;
    private WindowsTrayHost? _trayHost;

    public App()
    {
        AppPreferenceStore.ApplyPreferredLanguage();
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var mainWindow = new MainWindow();
        _window = mainWindow;
        _trayHost = new WindowsTrayHost(mainWindow.ViewModel.TrayQuickActions.Actions);
        _trayHost.ActionRequested += (_, action) => mainWindow.HandleTrayAction(action);
        _window.Activate();
    }
}
