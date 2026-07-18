namespace DNSPilotWindows.Core;

internal static class ShellPayloadSchema
{
    public const int SupportedVersion = 1;

    public static void Validate(int schemaVersion)
    {
        if (schemaVersion != SupportedVersion)
        {
            throw new UnsupportedPayloadSchemaException(schemaVersion, SupportedVersion);
        }
    }
}

public sealed class UnsupportedPayloadSchemaException : InvalidOperationException
{
    public UnsupportedPayloadSchemaException(int actualVersion, int supportedVersion)
        : base($"Unsupported DNS Pilot payload schema version {actualVersion}; this app supports version {supportedVersion}.")
    {
        ActualVersion = actualVersion;
        SupportedVersion = supportedVersion;
    }

    public int ActualVersion { get; }
    public int SupportedVersion { get; }
}
