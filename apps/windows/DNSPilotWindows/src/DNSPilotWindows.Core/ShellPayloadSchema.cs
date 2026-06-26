namespace DNSPilotWindows.Core;

internal static class ShellPayloadSchema
{
    public const int SupportedVersion = 1;

    public static void Validate(int schemaVersion)
    {
        if (schemaVersion != SupportedVersion)
        {
            throw new InvalidOperationException($"Unsupported DNS Pilot payload schema version {schemaVersion}.");
        }
    }
}
