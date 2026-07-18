#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    English,
    Vietnamese,
}

impl Language {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "en" | "en-US" => Some(Self::English),
            "vi" | "vi-VN" => Some(Self::Vietnamese),
            _ => None,
        }
    }

    pub fn code(self) -> &'static str {
        match self {
            Self::English => "en",
            Self::Vietnamese => "vi",
        }
    }

    pub fn parse_system_locale(value: &str) -> Option<Self> {
        let locale = value.split('.').next().unwrap_or(value).replace('_', "-");
        let language = locale.split('-').next().unwrap_or_default();
        Self::parse(language)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TextKey {
    AppTitle,
    CheckDns,
    History,
    Benchmark,
    Profiles,
    Settings,
    Diagnostics,
    Permissions,
    GuidedSettings,
    NativeApply,
    CopyDebugReport,
    RunBenchmark,
    ManageProfiles,
    Process,
    Overall,
    Step,
    Resolver,
    Status,
    Detail,
}

pub fn localized_text(key: TextKey, language: Language) -> &'static str {
    match (key, language) {
        (TextKey::AppTitle, _) => "DNS Pilot",
        (TextKey::CheckDns, Language::English) => "Check DNS",
        (TextKey::CheckDns, Language::Vietnamese) => "Kiểm tra DNS",
        (TextKey::History, Language::English) => "History",
        (TextKey::History, Language::Vietnamese) => "Lịch sử",
        (TextKey::Benchmark, Language::English) => "Benchmark",
        (TextKey::Benchmark, Language::Vietnamese) => "Đo kiểm",
        (TextKey::Profiles, Language::English) => "Profiles",
        (TextKey::Profiles, Language::Vietnamese) => "Hồ sơ DNS",
        (TextKey::Settings, Language::English) => "Settings",
        (TextKey::Settings, Language::Vietnamese) => "Cài đặt",
        (TextKey::Diagnostics, Language::English) => "Diagnostics",
        (TextKey::Diagnostics, Language::Vietnamese) => "Chẩn đoán",
        (TextKey::Permissions, Language::English) => "Permissions",
        (TextKey::Permissions, Language::Vietnamese) => "Quyền",
        (TextKey::GuidedSettings, Language::English) => "Guided settings",
        (TextKey::GuidedSettings, Language::Vietnamese) => "Hướng dẫn cài đặt",
        (TextKey::NativeApply, Language::English) => "Apply with native helper",
        (TextKey::NativeApply, Language::Vietnamese) => "Áp dụng bằng helper native",
        (TextKey::CopyDebugReport, Language::English) => "Copy debug report",
        (TextKey::CopyDebugReport, Language::Vietnamese) => "Sao chép báo cáo debug",
        (TextKey::RunBenchmark, Language::English) => "Run benchmark",
        (TextKey::RunBenchmark, Language::Vietnamese) => "Chạy đo kiểm",
        (TextKey::ManageProfiles, Language::English) => "Manage DNS profiles",
        (TextKey::ManageProfiles, Language::Vietnamese) => "Quản lý hồ sơ DNS",
        (TextKey::Process, Language::English) => "Process",
        (TextKey::Process, Language::Vietnamese) => "Tiến trình",
        (TextKey::Overall, Language::English) => "Overall",
        (TextKey::Overall, Language::Vietnamese) => "Tổng quan",
        (TextKey::Step, Language::English) => "Step",
        (TextKey::Step, Language::Vietnamese) => "Bước",
        (TextKey::Resolver, Language::English) => "Resolver",
        (TextKey::Resolver, Language::Vietnamese) => "Resolver",
        (TextKey::Status, Language::English) => "Status",
        (TextKey::Status, Language::Vietnamese) => "Trạng thái",
        (TextKey::Detail, Language::English) => "Detail",
        (TextKey::Detail, Language::Vietnamese) => "Chi tiết",
    }
}
