using System.Net;
using System.Net.Sockets;
using System.Text.RegularExpressions;

namespace DNSPilotWindows.Core;

public enum DnsFiltering
{
    None,
    Malware,
    Family,
    Ads,
    Security,
}

public sealed record ProfileFormValidation(IReadOnlyList<string> Issues)
{
    public bool CanSave => Issues.Count == 0;
}

public sealed class CustomDnsProfileFormViewModel
{
    public CustomDnsProfileFormViewModel(
        string name,
        string ipv4Servers,
        string ipv6Servers,
        DnsFiltering filtering = DnsFiltering.None,
        string tags = "")
    {
        Name = NormalizeName(name);
        Ipv4Servers = SplitValues(ipv4Servers);
        Ipv6Servers = SplitValues(ipv6Servers);
        Filtering = filtering;
        Tags = SplitValues(tags);
        Validation = Validate();
    }

    public string Name { get; }
    public IReadOnlyList<string> Ipv4Servers { get; }
    public IReadOnlyList<string> Ipv6Servers { get; }
    public DnsFiltering Filtering { get; }
    public IReadOnlyList<string> Tags { get; }
    public ProfileFormValidation Validation { get; }

    public string ProfileId => Slugify(Name);

    public IReadOnlyList<string> AddCommandArguments(string databasePath)
    {
        return CommandArguments("profile-add", databasePath, ProfileId);
    }

    public IReadOnlyList<string> UpdateCommandArguments(string databasePath, string profileId)
    {
        return CommandArguments("profile-update", databasePath, profileId);
    }

    private IReadOnlyList<string> CommandArguments(string command, string databasePath, string profileId)
    {
        var arguments = new List<string>
        {
            command,
            "--db",
            databasePath,
            "--id",
            profileId,
            "--name",
            Name,
            "--protocol",
            "plain",
        };

        foreach (var ipv4 in Ipv4Servers)
        {
            arguments.Add("--ipv4");
            arguments.Add(ipv4);
        }

        foreach (var ipv6 in Ipv6Servers)
        {
            arguments.Add("--ipv6");
            arguments.Add(ipv6);
        }

        arguments.Add("--filtering");
        arguments.Add(Filtering.CliValue());

        foreach (var tag in Tags)
        {
            arguments.Add("--tag");
            arguments.Add(tag);
        }

        return arguments;
    }

    private ProfileFormValidation Validate()
    {
        var issues = new List<string>();
        if (Name.Length == 0)
        {
            issues.Add("Profile name is required.");
        }

        if (Ipv4Servers.Count == 0 && Ipv6Servers.Count == 0)
        {
            issues.Add("Add at least one IPv4 or IPv6 DNS server.");
        }

        foreach (var ipv4 in Ipv4Servers.Where(ipv4 => !IsAddressFamily(ipv4, AddressFamily.InterNetwork)))
        {
            issues.Add($"Invalid IPv4 DNS server: {ipv4}");
        }

        foreach (var ipv6 in Ipv6Servers.Where(ipv6 => !IsAddressFamily(ipv6, AddressFamily.InterNetworkV6)))
        {
            issues.Add($"Invalid IPv6 DNS server: {ipv6}");
        }

        foreach (var duplicate in Ipv4Servers.Concat(Ipv6Servers).GroupBy(value => value, StringComparer.OrdinalIgnoreCase).Where(group => group.Count() > 1).Select(group => group.Key))
        {
            issues.Add($"Duplicate DNS server: {duplicate}");
        }

        return new ProfileFormValidation(issues);
    }

    private static bool IsAddressFamily(string value, AddressFamily addressFamily)
    {
        return IPAddress.TryParse(value, out var address) && address.AddressFamily == addressFamily;
    }

    private static IReadOnlyList<string> SplitValues(string values)
    {
        return values
            .Split(new[] { ',', '\r', '\n', '\t', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToArray();
    }

    private static string NormalizeName(string name)
    {
        return Regex.Replace(name.Trim(), @"\s+", " ");
    }

    private static string Slugify(string value)
    {
        var normalized = Regex.Replace(value.Trim().ToLowerInvariant(), @"[^a-z0-9]+", "-").Trim('-');
        return normalized.Length == 0 ? "custom-dns-profile" : normalized;
    }
}

public static class ProfileManagementCommands
{
    public static IReadOnlyList<string> List(string databasePath)
    {
        return new[] { "profile-list", "--db", databasePath };
    }

    public static IReadOnlyList<string> Delete(string databasePath, string profileId)
    {
        return new[] { "profile-delete", "--db", databasePath, "--id", profileId };
    }
}
