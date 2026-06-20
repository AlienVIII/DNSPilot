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

public enum DNSPilotTextKey: String, Sendable {
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
    ]
}
