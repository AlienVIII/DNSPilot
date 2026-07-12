public enum DNSPilotLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case vietnamese = "vi"

    public var id: String {
        rawValue
    }

    public init(code: String) {
        self = DNSPilotLanguage(rawValue: code) ?? .system
    }

    public var displayName: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .vietnamese:
            "Tiếng Việt"
        }
    }
}

public enum DNSPilotLanguagePreferences {
    public static let storageKey = "dnspilot.language"
}

public enum DNSPilotTextKey: String, CaseIterable, Sendable {
    case overview
    case platforms
    case capabilities
    case permissions
    case publish
    case benchmark
    case gamePing
    case customDNS
    case history
    case catalog
    case settingsTitle
    case language
    case languageSubtitle
    case permissionsSubtitle
    case publishSubtitle
    case copyChecklist
    case openNetworkSettings
    case powerActions
    case powerActionsEnabled
    case powerActionsDisabled
    case run
    case running
    case cancel
    case refresh
    case clearAll
    case delete
    case edit
    case result
    case process
    case status
    case profile
    case resolver
    case medianDNS
    case p95DNS
    case medianTCP
    case failure
    case diagnosis
    case providers
    case suites
    case filtered
    case testSuites
    case savedRuns
    case noSavedRuns
    case capabilityMatrix
    case productGoals
    case apply
    case flush
    case platform
    case mode
    case networkSafeguards
    case profiles
    case targets
    case attempts
    case preset
    case dnsCandidates
    case probe
    case all
    case vietnam
    case global
    case game
    case gameCheckDisclaimer
    case dnsRecords
    case savedProfiles
    case noCustomPlainDNSProfiles
    case servers
    case name
    case newProfile
    case saveProfile
    case updateProfile
    case deleteCustomDNSProfile
    case historyNotLoaded
    case deleteSavedRun
    case clearHistory
    case customOnly
    case suiteName
    case savedSuites
    case newSuite
    case saveSuite
    case updateSuite
    case azureExample
    case deleteCustomSuite
    case copyResultReport
    case copyGamePingReport
    case copyRunID
    case validateSystemDNS
    case refreshCurrentDNS
    case copyCurrentDNS
    case benchmarkFailed
    case failedAt
    case reason
    case suggestion
    case elapsed
    case debugLog
    case copyIssueReport
    case copyNextStep
    case copyDNSServers
    case copyApplyChecklist
    case entryPoint
    case validationEvidence
}

public struct DNSPilotLocalizer: Equatable, Sendable {
    public let language: DNSPilotLanguage

    public init(language: DNSPilotLanguage) {
        self.language = language
    }

    public init(languageCode: String) {
        self.language = DNSPilotLanguage(code: languageCode)
    }

    public func text(_ key: DNSPilotTextKey) -> String {
        switch language {
        case .vietnamese:
            Self.vietnamese[key] ?? Self.english[key] ?? key.rawValue
        case .system, .english:
            Self.english[key] ?? key.rawValue
        }
    }

    private static let english: [DNSPilotTextKey: String] = [
        .overview: "Overview",
        .platforms: "Platforms",
        .capabilities: "Capabilities",
        .permissions: "Permissions",
        .publish: "Publish",
        .benchmark: "Benchmark",
        .gamePing: "Game Ping",
        .customDNS: "Custom DNS",
        .history: "History",
        .catalog: "Catalog",
        .settingsTitle: "Settings",
        .language: "Language",
        .languageSubtitle: "Choose the app language for supported DNS Pilot surfaces.",
        .permissionsSubtitle: "DNS Pilot asks for access only when a flow needs it.",
        .publishSubtitle: "Store-safe and Power distribution stay separate.",
        .copyChecklist: "Copy Checklist",
        .openNetworkSettings: "Open Network Settings",
        .powerActions: "Power Actions",
        .powerActionsEnabled: "Enabled for this launch",
        .powerActionsDisabled: "Disabled by default",
        .run: "Run",
        .running: "Running",
        .cancel: "Cancel",
        .refresh: "Refresh",
        .clearAll: "Clear All",
        .delete: "Delete",
        .edit: "Edit",
        .result: "Result",
        .process: "Process",
        .status: "Status",
        .profile: "Profile",
        .resolver: "Resolver",
        .medianDNS: "Median DNS",
        .p95DNS: "P95 DNS",
        .medianTCP: "Median TCP",
        .failure: "Failure",
        .diagnosis: "Diagnosis",
        .providers: "Providers",
        .suites: "Suites",
        .filtered: "Filtered",
        .testSuites: "Test Suites",
        .savedRuns: "Saved Runs",
        .noSavedRuns: "No saved runs yet.",
        .capabilityMatrix: "Capability Matrix",
        .productGoals: "Product Goals",
        .apply: "Apply",
        .flush: "Flush",
        .platform: "Platform",
        .mode: "Mode",
        .networkSafeguards: "Network Safeguards",
        .profiles: "Profiles",
        .targets: "Targets",
        .attempts: "Attempts",
        .preset: "Preset",
        .dnsCandidates: "DNS Candidates",
        .probe: "Probe",
        .all: "All",
        .vietnam: "Vietnam",
        .global: "Global",
        .game: "Game",
        .gameCheckDisclaimer: "Game check estimates DNS and TCP connection timing. It is not ICMP ping or in-match UDP latency.",
        .dnsRecords: "DNS records",
        .savedProfiles: "Saved Profiles",
        .noCustomPlainDNSProfiles: "No custom plain DNS profiles.",
        .servers: "Servers",
        .name: "Name",
        .newProfile: "New Profile",
        .saveProfile: "Save Profile",
        .updateProfile: "Update Profile",
        .deleteCustomDNSProfile: "Delete Custom DNS Profile?",
        .historyNotLoaded: "History has not been loaded.",
        .deleteSavedRun: "Delete Saved Run?",
        .clearHistory: "Clear History?",
        .customOnly: "Custom only",
        .suiteName: "Suite name",
        .savedSuites: "Saved suites",
        .newSuite: "New Suite",
        .saveSuite: "Save Suite",
        .updateSuite: "Update Suite",
        .azureExample: "Azure Example",
        .deleteCustomSuite: "Delete Custom Suite?",
        .copyResultReport: "Copy Result Report",
        .copyGamePingReport: "Copy Game Ping Report",
        .copyRunID: "Copy Run ID",
        .validateSystemDNS: "Validate System DNS",
        .refreshCurrentDNS: "Refresh Current DNS",
        .copyCurrentDNS: "Copy Current DNS",
        .benchmarkFailed: "Benchmark failed",
        .failedAt: "Failed at",
        .reason: "Reason",
        .suggestion: "Suggestion",
        .elapsed: "Elapsed",
        .debugLog: "Debug log",
        .copyIssueReport: "Copy Issue Report",
        .copyNextStep: "Copy Next Step",
        .copyDNSServers: "Copy DNS Servers",
        .copyApplyChecklist: "Copy Apply Checklist",
        .entryPoint: "Entry point",
        .validationEvidence: "Validation",
    ]

    private static let vietnamese: [DNSPilotTextKey: String] = [
        .overview: "Tổng quan",
        .platforms: "Nền tảng",
        .capabilities: "Khả năng",
        .permissions: "Quyền",
        .publish: "Phát hành",
        .benchmark: "Benchmark",
        .gamePing: "Game Ping",
        .customDNS: "DNS tùy chỉnh",
        .history: "Lịch sử",
        .catalog: "Danh mục",
        .settingsTitle: "Cài đặt",
        .language: "Ngôn ngữ",
        .languageSubtitle: "Chọn ngôn ngữ ứng dụng cho các bề mặt đã hỗ trợ của DNS Pilot.",
        .permissionsSubtitle: "DNS Pilot chỉ hỏi quyền khi luồng thao tác cần quyền đó.",
        .publishSubtitle: "Bản Store-safe và bản Power được tách riêng.",
        .copyChecklist: "Copy checklist",
        .openNetworkSettings: "Mở Network Settings",
        .powerActions: "Power Actions",
        .powerActionsEnabled: "Đã bật cho lần chạy này",
        .powerActionsDisabled: "Mặc định tắt",
        .run: "Chạy",
        .running: "Đang chạy",
        .cancel: "Hủy",
        .refresh: "Làm mới",
        .clearAll: "Xóa tất cả",
        .delete: "Xóa",
        .edit: "Sửa",
        .result: "Kết quả",
        .process: "Tiến trình",
        .status: "Trạng thái",
        .profile: "Profile",
        .resolver: "Resolver",
        .medianDNS: "DNS trung vị",
        .p95DNS: "DNS P95",
        .medianTCP: "TCP trung vị",
        .failure: "Lỗi",
        .diagnosis: "Chẩn đoán",
        .providers: "Nhà cung cấp",
        .suites: "Bộ test",
        .filtered: "Có lọc",
        .testSuites: "Bộ test domain",
        .savedRuns: "Run đã lưu",
        .noSavedRuns: "Chưa có run đã lưu.",
        .capabilityMatrix: "Ma trận khả năng",
        .productGoals: "Mục tiêu sản phẩm",
        .apply: "Áp dụng",
        .flush: "Flush",
        .platform: "Nền tảng",
        .mode: "Mode",
        .networkSafeguards: "Bảo vệ mạng",
        .profiles: "Profiles",
        .targets: "Targets",
        .attempts: "Số lần thử",
        .preset: "Preset",
        .dnsCandidates: "DNS ứng viên",
        .probe: "Probe",
        .all: "Tất cả",
        .vietnam: "Việt Nam",
        .global: "Global",
        .game: "Game",
        .gameCheckDisclaimer: "Kiểm tra game ước tính thời gian DNS và kết nối TCP. Đây không phải ICMP ping hoặc độ trễ UDP trong trận.",
        .dnsRecords: "DNS records",
        .savedProfiles: "Profile đã lưu",
        .noCustomPlainDNSProfiles: "Chưa có profile DNS thường tùy chỉnh.",
        .servers: "Servers",
        .name: "Tên",
        .newProfile: "Profile mới",
        .saveProfile: "Lưu profile",
        .updateProfile: "Cập nhật profile",
        .deleteCustomDNSProfile: "Xóa profile DNS tùy chỉnh?",
        .historyNotLoaded: "Lịch sử chưa được tải.",
        .deleteSavedRun: "Xóa run đã lưu?",
        .clearHistory: "Xóa lịch sử?",
        .customOnly: "Chỉ tùy chỉnh",
        .suiteName: "Tên bộ test",
        .savedSuites: "Bộ test đã lưu",
        .newSuite: "Bộ test mới",
        .saveSuite: "Lưu bộ test",
        .updateSuite: "Cập nhật bộ test",
        .azureExample: "Ví dụ Azure",
        .deleteCustomSuite: "Xóa bộ test tùy chỉnh?",
        .copyResultReport: "Copy báo cáo kết quả",
        .copyGamePingReport: "Copy báo cáo Game Ping",
        .copyRunID: "Copy Run ID",
        .validateSystemDNS: "Kiểm tra System DNS",
        .refreshCurrentDNS: "Làm mới DNS hiện tại",
        .copyCurrentDNS: "Copy DNS hiện tại",
        .benchmarkFailed: "Benchmark thất bại",
        .failedAt: "Lỗi tại",
        .reason: "Lý do",
        .suggestion: "Gợi ý",
        .elapsed: "Thời gian",
        .debugLog: "Debug log",
        .copyIssueReport: "Copy issue report",
        .copyNextStep: "Copy bước tiếp theo",
        .copyDNSServers: "Copy DNS servers",
        .copyApplyChecklist: "Copy checklist áp dụng",
        .entryPoint: "Điểm thao tác",
        .validationEvidence: "Bằng chứng kiểm tra",
    ]
}
