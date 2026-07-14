using System.Text.Json;
using DNSPilotWindows.Core;
using Windows.Globalization;
using Windows.Storage;

namespace DNSPilotWindows.App;

internal static class AppPreferenceStore
{
    private const string PreferencesKey = "dnspilot.preferences.v1";

    public static WindowsPreferenceState? Load()
    {
        try
        {
            return ApplicationData.Current.LocalSettings.Values[PreferencesKey] is string json
                ? JsonSerializer.Deserialize<WindowsPreferenceState>(json)
                : null;
        }
        catch
        {
            return null;
        }
    }

    public static void Save(WindowsPreferenceState preference)
    {
        try
        {
            ApplicationData.Current.LocalSettings.Values[PreferencesKey] = JsonSerializer.Serialize(preference);
        }
        catch
        {
            // Dev/unpackaged launches can lack app data; benchmark behavior stays usable.
        }
    }

    public static void ApplyPreferredLanguage()
    {
        var language = Load()?.LanguageTag;
        if (language is "en-US" or "vi-VN")
        {
            ApplicationLanguages.PrimaryLanguageOverride = language;
        }
    }
}
