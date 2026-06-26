namespace DNSPilotWindows.Core;

public sealed record WindowsCapabilityPolicy(
    string Edition,
    bool CanMutateSystemDns,
    bool RequiresAdministrator,
    bool CanCopyDnsServers,
    bool CanOpenNetworkSettings,
    string Notes)
{
    public static WindowsCapabilityPolicy StoreSafe { get; } = new(
        "windows-store",
        CanMutateSystemDns: false,
        RequiresAdministrator: false,
        CanCopyDnsServers: true,
        CanOpenNetworkSettings: true,
        Notes: "Microsoft Store lane uses copy/open-settings guidance only.");

    public static WindowsCapabilityPolicy PowerEdition { get; } = new(
        "windows-power",
        CanMutateSystemDns: true,
        RequiresAdministrator: true,
        CanCopyDnsServers: true,
        CanOpenNetworkSettings: true,
        Notes: "Power edition may use an explicit admin/service boundary later.");
}
