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

    public var guidedApplySteps: [ApplyPlanStep] {
        guard plan.disposition == .guideOnly, !plan.dnsServers.isEmpty else {
            return []
        }
        return [
            ApplyPlanStep(
                id: "copy-dns",
                title: "Copy DNS servers",
                detail: "Copy the measured DNS server list: \(dnsServerText.replacingOccurrences(of: "\n", with: ", ")).",
                systemImage: "doc.on.doc"
            ),
            ApplyPlanStep(
                id: "open-network-settings",
                title: "Open macOS Network Settings",
                detail: "DNS Pilot opens Settings only; it does not change system DNS in the store-safe build.",
                systemImage: "gearshape"
            ),
            ApplyPlanStep(
                id: "paste-active-service",
                title: "Paste into the active network service",
                detail: "Select the network service currently carrying traffic, then paste the DNS servers into its DNS list.",
                systemImage: "network"
            ),
            ApplyPlanStep(
                id: "flush-cache",
                title: "Flush cache or reconnect",
                detail: "Use the copied checklist commands if allowed, or reconnect Wi-Fi/Ethernet before validating.",
                systemImage: "arrow.triangle.2.circlepath"
            ),
            ApplyPlanStep(
                id: "validate-system-dns",
                title: "Validate System DNS",
                detail: "Run System DNS validation to confirm macOS is using the intended resolver path.",
                systemImage: "checkmark.seal"
            ),
        ]
    }

    public var guidedApplyChecklistText: String? {
        guidedApplyChecklistTextWithRestore(nil)
    }

    public func guidedApplyChecklistTextWithRestore(_ restoreSnapshot: SystemDNSResolverSnapshot?) -> String? {
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
        if let restoreSnapshot {
            lines.append(contentsOf: restoreSectionLines(for: GuidedApplyRestoreViewModel(snapshot: restoreSnapshot)))
        }
        lines.append("Steps:")
        lines.append("1. Open macOS Network Settings.")
        lines.append("2. Select the active network service.")
        lines.append("3. Paste these DNS servers into the DNS server list.")
        lines.append("4. Apply the network changes.")
        lines.append("5. If allowed, flush local DNS cache before validating:")
        lines.append("   sudo dscacheutil -flushcache")
        lines.append("   sudo killall -HUP mDNSResponder")
        lines.append("6. Run System DNS validation in DNS Pilot.")
        lines.append("7. Retest DNS Pilot after applying DNS.")
        return lines.joined(separator: "\n")
    }

    private func restoreSectionLines(for restoreViewModel: GuidedApplyRestoreViewModel) -> [String] {
        guard restoreViewModel.hasRestorableDNS else {
            return [
                "Current DNS before apply:",
                "Current DNS unavailable",
                "Capture the current macOS DNS settings manually before changing DNS.",
            ]
        }

        var lines = [
            "Current DNS before apply:",
            restoreViewModel.dnsServerText,
        ]
        if !restoreViewModel.snapshot.searchDomains.isEmpty {
            lines.append("Search domains before apply:")
            lines.append(contentsOf: restoreViewModel.snapshot.searchDomains)
        }
        lines.append("If validation fails, paste the previous DNS servers back into the active network service.")
        if restoreViewModel.snapshot.supplementalResolverCount > 0 {
            lines.append("Scoped resolvers were present; restore may need VPN/MDM/service-specific settings.")
        }
        return lines
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

public struct ApplyPlanStep: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let systemImage: String

    public init(id: String, title: String, detail: String, systemImage: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

public struct BenchmarkApplyPlanPresentation: Equatable {
    public let showsApplyPlanState: Bool
    public let showsLocalNextStep: Bool
    public let reportIncludesLocalNextStep: Bool

    public init(outcome: BenchmarkApplyPlanLoadOutcome?, isLoading: Bool) {
        showsApplyPlanState = isLoading || outcome != nil
        switch outcome {
        case .failed:
            showsLocalNextStep = !isLoading
        case .loaded:
            showsLocalNextStep = false
        case nil:
            showsLocalNextStep = !isLoading
        }
        reportIncludesLocalNextStep = showsLocalNextStep
    }
}
