public struct PolicyGuidanceViewModel: Equatable {
    public let preflight: PreflightPolicy
    public let applyPolicy: ApplyPolicy

    public var flushStatusLabel: String {
        switch preflight.flushRequirement {
        case .notNeeded:
            "No flush needed"
        case .recommendedBeforeTest:
            "Flush recommended"
        case .recommendedButUnsupported:
            "Flush unsupported"
        }
    }

    public var applyActionLabel: String {
        switch applyPolicy.disposition {
        case .allow:
            "Enable profile"
        case .guideOnly:
            "Open Settings"
        case .protectCurrentDNS:
            "Keep current DNS"
        case .unsupported:
            "Unsupported"
        }
    }

    public var canPromptApply: Bool {
        applyPolicy.canPromptApply && applyPolicy.disposition != .protectCurrentDNS
    }

    public var notes: [String] {
        preflight.notes + applyPolicy.notes
    }

    public init(preflight: PreflightPolicy, applyPolicy: ApplyPolicy) {
        self.preflight = preflight
        self.applyPolicy = applyPolicy
    }
}
