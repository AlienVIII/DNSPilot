using System.Globalization;

namespace DNSPilotWindows.Core;

internal static class CoreUtilities
{
    public static string ToStringInvariant(this int value)
    {
        return value.ToString(CultureInfo.InvariantCulture);
    }

    public static IEnumerable<T> WhereNotNull<T>(this IEnumerable<T?> values)
        where T : class
    {
        foreach (var value in values)
        {
            if (value is not null)
            {
                yield return value;
            }
        }
    }
}

internal static class DomainNameValidator
{
    public static bool IsValid(string domain)
    {
        var trimmed = domain.Trim().TrimEnd('.');
        if (trimmed.Length == 0)
        {
            return false;
        }

        return trimmed.Split('.').All(IsValidLabel);
    }

    private static bool IsValidLabel(string label)
    {
        if (label.Length == 0 || label.Length > 63 || label.StartsWith('-') || label.EndsWith('-'))
        {
            return false;
        }

        return label.All(character =>
            character is >= 'a' and <= 'z'
            || character is >= 'A' and <= 'Z'
            || character is >= '0' and <= '9'
            || character == '-');
    }
}

internal static class DnsFilteringExtensions
{
    public static string CliValue(this DnsFiltering filtering)
    {
        return filtering switch
        {
            DnsFiltering.Malware => "malware",
            DnsFiltering.Family => "family",
            DnsFiltering.Ads => "ads",
            DnsFiltering.Security => "security",
            _ => "none",
        };
    }
}
