using System.Text.RegularExpressions;

namespace DNSPilotWindows.Core;

public sealed record WindowsPreferenceState(
    int SchemaVersion,
    int ModeIndex,
    int RecordFamilyIndex,
    int ResolverFamilyIndex,
    int Attempts,
    int DnsTimeoutMs,
    int TcpTimeoutMs,
    int TcpTargetsPerDomain,
    IReadOnlyList<string> SelectedProfileIds,
    string? SelectedSuiteId,
    string LanguageTag)
{
    public const int CurrentSchemaVersion = 1;

    public static WindowsPreferenceState Default(CatalogSnapshot catalog)
    {
        return new WindowsPreferenceState(
            CurrentSchemaVersion,
            ModeIndex: 1,
            RecordFamilyIndex: 0,
            ResolverFamilyIndex: 0,
            Attempts: 2,
            DnsTimeoutMs: 800,
            TcpTimeoutMs: 1_000,
            TcpTargetsPerDomain: 4,
            SelectedProfileIds: catalog.Profiles.Where(profile => profile.Protocol == DnsProtocol.Plain).Take(3).Select(profile => profile.Id).ToArray(),
            SelectedSuiteId: catalog.TestSuites.FirstOrDefault()?.Id,
            LanguageTag: "en-US");
    }

    public static WindowsPreferenceState Normalize(WindowsPreferenceState? stored, CatalogSnapshot catalog)
    {
        var defaults = Default(catalog);
        if (stored is null)
        {
            return defaults;
        }

        var plainIds = catalog.Profiles.Where(profile => profile.Protocol == DnsProtocol.Plain).Select(profile => profile.Id).ToHashSet(StringComparer.Ordinal);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var selectedProfiles = (stored.SelectedProfileIds ?? Array.Empty<string>())
            .Where(plainIds.Contains)
            .Where(seen.Add)
            .ToArray();
        var selectedSuite = catalog.TestSuites.Any(suite => suite.Id == stored.SelectedSuiteId)
            ? stored.SelectedSuiteId
            : defaults.SelectedSuiteId;

        return new WindowsPreferenceState(
            CurrentSchemaVersion,
            ModeIndex: NormalizeIndex(stored.ModeIndex, 0, 2, defaults.ModeIndex),
            RecordFamilyIndex: NormalizeIndex(stored.RecordFamilyIndex, 0, 2, defaults.RecordFamilyIndex),
            ResolverFamilyIndex: NormalizeIndex(stored.ResolverFamilyIndex, 0, 2, defaults.ResolverFamilyIndex),
            Attempts: Math.Max(1, stored.Attempts),
            DnsTimeoutMs: stored.DnsTimeoutMs > 0 ? stored.DnsTimeoutMs : defaults.DnsTimeoutMs,
            TcpTimeoutMs: stored.TcpTimeoutMs > 0 ? stored.TcpTimeoutMs : defaults.TcpTimeoutMs,
            TcpTargetsPerDomain: stored.TcpTargetsPerDomain > 0 ? stored.TcpTargetsPerDomain : defaults.TcpTargetsPerDomain,
            SelectedProfileIds: selectedProfiles,
            SelectedSuiteId: selectedSuite,
            LanguageTag: stored.LanguageTag is "en-US" or "vi-VN" ? stored.LanguageTag : defaults.LanguageTag);
    }

    private static int NormalizeIndex(int value, int minimum, int maximum, int fallback)
    {
        return value >= minimum && value <= maximum ? value : fallback;
    }
}

public sealed record WindowsCapabilityStatusRow(string Id, string Title, string State, string Detail)
{
    public override string ToString() => $"{Title}: {State} - {Detail}";
}

public static class WindowsCapabilityStatusRows
{
    public static IReadOnlyList<WindowsCapabilityStatusRow> From(
        PlatformCapability store,
        PlatformCapability power,
        RuntimeReadinessViewModel readiness)
    {
        return new[]
        {
            SurfaceRow("store-benchmark", "Store benchmark", store.CanBenchmark, readiness.For(RuntimeSurface.Benchmark), store.Notes),
            SurfaceRow("store-apply", "Store apply guidance", store.Apply != "none", readiness.For(RuntimeSurface.ApplyGuidance), store.Notes),
            new WindowsCapabilityStatusRow(
                "power-benchmark",
                "Power benchmark",
                power.CanBenchmark ? "OS-gated" : "Unsupported",
                power.Notes.FirstOrDefault() ?? "Power edition is separate from this Store package."),
            new WindowsCapabilityStatusRow(
                "power-apply",
                "Power apply",
                power.StoreSafe ? "Ready" : "OS-gated",
                power.Notes.FirstOrDefault() ?? "Power edition requires explicit OS/admin consent."),
        };
    }

    private static WindowsCapabilityStatusRow SurfaceRow(
        string id,
        string title,
        bool supported,
        RuntimeSurfaceReadiness runtime,
        IReadOnlyList<string> notes)
    {
        if (!supported)
        {
            return new WindowsCapabilityStatusRow(id, title, "Unsupported", notes.FirstOrDefault() ?? "Not supported by this package.");
        }

        return runtime.IsReady
            ? new WindowsCapabilityStatusRow(id, title, "Ready", notes.FirstOrDefault() ?? runtime.Summary)
            : new WindowsCapabilityStatusRow(id, title, "Recovery needed", runtime.Summary);
    }
}

public sealed record CatalogQuickPicks(string? DefaultSuiteId, string? VietnamSuiteId)
{
    public static CatalogQuickPicks FromCatalog(CatalogSnapshot catalog)
    {
        return new CatalogQuickPicks(
            FindSuite(catalog, "default", "daily"),
            FindSuite(catalog, "vietnam", "vn"));
    }

    private static string? FindSuite(CatalogSnapshot catalog, params string[] tags)
    {
        return catalog.TestSuites.FirstOrDefault(suite => suite.Tags.Any(tag => tags.Contains(tag, StringComparer.OrdinalIgnoreCase)))?.Id;
    }
}

public static class WindowsDiagnosticRedactor
{
    private static readonly Regex WindowsUserPath = new(@"[A-Za-z]:\\Users\\[^\\\s]+(?:\\[^\s]*)?", RegexOptions.Compiled);
    private static readonly Regex UnixUserPath = new(@"/(?:Users|home)/[^/\s]+(?:/[^\s]*)?", RegexOptions.Compiled);
    private static readonly Regex EnvironmentValue = new(@"\b(?:HOME|USERPROFILE|APPDATA|LOCALAPPDATA)=\S+", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public static string Redact(string value)
    {
        var redacted = EnvironmentValue.Replace(value, match => match.Value[..(match.Value.IndexOf('=') + 1)] + "<redacted>");
        redacted = WindowsUserPath.Replace(redacted, "<user-path>");
        return UnixUserPath.Replace(redacted, "<user-path>");
    }
}
