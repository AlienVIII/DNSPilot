namespace DNSPilotWindows.Core;

public static class CliExecutableLocator
{
    public const string EnvironmentVariableName = "DNSPILOT_CLI_PATH";
    public const string ExecutableName = "dnspilot-cli.exe";

    public static string Locate(string appBaseDirectory, string? environmentOverride)
    {
        if (!string.IsNullOrWhiteSpace(environmentOverride) && File.Exists(environmentOverride))
        {
            return environmentOverride;
        }

        var bundled = Path.Combine(appBaseDirectory, ExecutableName);
        if (File.Exists(bundled))
        {
            return bundled;
        }

        var current = new DirectoryInfo(appBaseDirectory);
        while (current is not null)
        {
            var release = Path.Combine(current.FullName, "target", "release", ExecutableName);
            if (File.Exists(release))
            {
                return release;
            }

            var debug = Path.Combine(current.FullName, "target", "debug", ExecutableName);
            if (File.Exists(debug))
            {
                return debug;
            }

            current = current.Parent;
        }

        return bundled;
    }

    public static string LocateFromCurrentProcess()
    {
        return Locate(
            AppContext.BaseDirectory,
            Environment.GetEnvironmentVariable(EnvironmentVariableName));
    }
}
