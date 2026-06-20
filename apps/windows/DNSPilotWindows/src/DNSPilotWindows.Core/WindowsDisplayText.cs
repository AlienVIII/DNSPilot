using System.Globalization;

namespace DNSPilotWindows.Core;

public static class WindowsDisplayText
{
    public static bool IsVietnamese =>
        CultureInfo.CurrentUICulture.TwoLetterISOLanguageName.Equals("vi", StringComparison.OrdinalIgnoreCase);

    public static string Text(string english, string vietnamese)
    {
        return IsVietnamese ? vietnamese : english;
    }

    public static string ModeLabel(BenchmarkMode mode)
    {
        if (mode == BenchmarkMode.DnsOnly)
        {
            return Text("DNS only", "Chỉ DNS");
        }

        if (mode == BenchmarkMode.SystemDnsValidation)
        {
            return Text("System DNS validation", "Kiểm tra DNS hệ thống");
        }

        return "DNS + TCP";
    }

    public static string RecordFamilyLabel(DnsRecordFamily family)
    {
        if (family == DnsRecordFamily.Ipv4Only)
        {
            return Text("A only", "Chỉ A");
        }

        if (family == DnsRecordFamily.Ipv6Only)
        {
            return Text("AAAA only", "Chỉ AAAA");
        }

        return "A + AAAA";
    }

    public static string ResolverSummaryLabel(ResolverAddressFamily family)
    {
        if (family == ResolverAddressFamily.Ipv4Only)
        {
            return Text("IPv4 resolver", "resolver IPv4");
        }

        if (family == ResolverAddressFamily.Ipv6Only)
        {
            return Text("IPv6 resolver", "resolver IPv6");
        }

        return Text("resolver", "resolver");
    }

    public static string StepLabel(BenchmarkFailureStep step)
    {
        return step.Id switch
        {
            "preparingBenchmark" => Text("Preparing benchmark", "Chuẩn bị benchmark"),
            "resolvingDNS" => Text("Resolving DNS", "Phân giải DNS"),
            "measuringConnection" => Text("Measuring TCP", "Đo TCP"),
            "parsingResult" => Text("Parsing result", "Đọc kết quả"),
            "savingHistory" => Text("Saving history", "Lưu lịch sử"),
            _ => step.Label,
        };
    }

    public static string HealthLabel(string health)
    {
        return health switch
        {
            "healthy" => Text("Healthy", "Tốt"),
            "degraded" => Text("Degraded", "Suy giảm"),
            "failed" => Text("Failed", "Lỗi"),
            _ => Text("Inconclusive", "Chưa kết luận"),
        };
    }

    public static string StatusLabel(ProgressStatus status)
    {
        return status switch
        {
            ProgressStatus.Running => Text("running", "đang chạy"),
            ProgressStatus.Success => Text("success", "thành công"),
            ProgressStatus.Degraded => Text("degraded", "suy giảm"),
            ProgressStatus.Failed => Text("failed", "thất bại"),
            _ => Text("idle", "chưa chạy"),
        };
    }
}
