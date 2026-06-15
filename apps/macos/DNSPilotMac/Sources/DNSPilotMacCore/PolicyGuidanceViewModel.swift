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

public struct ApplyPlanViewModel: Equatable {
    public let plan: ApplyPlan

    public var statusLabel: String {
        switch plan.disposition {
        case .applyWithUserApproval:
            "Ready"
        case .guideOnly:
            "Guided"
        case .protectCurrentDNS:
            "Protected"
        case .unsupported:
            "Unsupported"
        case .notRecommended:
            "Retest"
        }
    }

    public var actionLabel: String {
        switch plan.disposition {
        case .applyWithUserApproval:
            "Apply with Approval"
        case .guideOnly:
            "Copy DNS + Open Settings"
        case .protectCurrentDNS:
            "Keep current DNS"
        case .unsupported:
            "Unsupported"
        case .notRecommended:
            "Retest"
        }
    }

    public var canOfferPrimaryAction: Bool {
        switch plan.disposition {
        case .applyWithUserApproval:
            plan.canApply
        case .guideOnly:
            !plan.dnsServers.isEmpty
        case .protectCurrentDNS, .unsupported, .notRecommended:
            false
        }
    }

    public var dnsServerText: String {
        plan.dnsServers.joined(separator: "\n")
    }

    public var copyText: String {
        var lines = [
            "Apply plan: \(statusLabel)",
            "Action: \(actionLabel)",
        ]
        if let profileName = plan.profileName {
            lines.append("Profile: \(profileName)")
        }
        if !plan.dnsServers.isEmpty {
            lines.append("DNS servers:")
            lines.append(dnsServerText)
        }
        if !plan.notes.isEmpty {
            lines.append("Notes:")
            lines.append(contentsOf: plan.notes)
        }
        return lines.joined(separator: "\n")
    }

    public init(plan: ApplyPlan) {
        self.plan = plan
    }
}
