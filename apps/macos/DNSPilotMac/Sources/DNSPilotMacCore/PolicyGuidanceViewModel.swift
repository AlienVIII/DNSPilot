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

    public var recommendedProfileLabel: String? {
        guard let profileLabel = plan.profileName ?? plan.profileID else {
            return nil
        }
        return "Recommended: \(profileLabel)"
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

    public var guidedPrimaryActionLabel: String? {
        guard plan.disposition == .guideOnly, canOfferPrimaryAction else {
            return nil
        }
        return actionLabel
    }

    public var guidedPrimaryActionCopyText: String? {
        guard guidedPrimaryActionLabel != nil else {
            return nil
        }
        return dnsServerText
    }

    public var opensNetworkSettingsAfterGuidedPrimaryAction: Bool {
        guidedPrimaryActionLabel != nil
    }

    public var guidedApplyChecklistText: String? {
        guard plan.disposition == .guideOnly, !plan.dnsServers.isEmpty else {
            return nil
        }
        var lines = [
            "DNS Pilot guided apply",
            "DNS Pilot has not changed system DNS.",
        ]
        if let recommendedProfileLabel {
            lines.append(recommendedProfileLabel)
        }
        if let testedResolver = plan.testedResolver {
            lines.append("Tested resolver: \(testedResolver)")
        }
        lines.append("DNS servers:")
        lines.append(dnsServerText)
        lines.append("Steps:")
        lines.append("1. Open macOS Network Settings.")
        lines.append("2. Select the active network service.")
        lines.append("3. Paste these DNS servers into the DNS server list.")
        lines.append("4. Apply the network changes.")
        lines.append("5. Retest DNS Pilot after applying DNS.")
        return lines.joined(separator: "\n")
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
        if let testedResolver = plan.testedResolver {
            lines.append("Tested resolver: \(testedResolver)")
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
