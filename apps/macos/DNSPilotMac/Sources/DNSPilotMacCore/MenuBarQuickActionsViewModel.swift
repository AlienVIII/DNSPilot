import Foundation

public enum MenuBarQuickActionKind: Equatable {
    case destination(MenuBarQuickDestination)
    case quit
}

public enum MenuBarQuickDestination: String, Equatable {
    case openApp
    case benchmark
    case quickBenchmark
    case guidedApplyLastDNS
    case copyLastDNS
    case flushDNS
    case systemDNSValidation
    case history
    case networkSettings
}

public struct MenuBarQuickAction: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let kind: MenuBarQuickActionKind

    public init(
        id: String,
        title: String,
        systemImage: String,
        kind: MenuBarQuickActionKind
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
    }
}

public struct MenuBarQuickActionsViewModel: Equatable {
    public let actions: [MenuBarQuickAction]

    public init(lastGuidedApplyPlan: GuidedApplyPlanSnapshot? = nil) {
        var actions = [
            MenuBarQuickAction(
                id: "open-app",
                title: "Open DNS Pilot",
                systemImage: "macwindow",
                kind: .destination(.openApp)
            ),
            MenuBarQuickAction(
                id: "benchmark",
                title: "Benchmark",
                systemImage: "speedometer",
                kind: .destination(.benchmark)
            ),
            MenuBarQuickAction(
                id: "quick-benchmark",
                title: "Run Quick Test",
                systemImage: "play.fill",
                kind: .destination(.quickBenchmark)
            ),
        ]

        if lastGuidedApplyPlan != nil {
            actions += [
                MenuBarQuickAction(
                    id: "guided-apply-last-dns",
                    title: "Apply Last DNS",
                    systemImage: "gearshape",
                    kind: .destination(.guidedApplyLastDNS)
                ),
                MenuBarQuickAction(
                    id: "copy-last-dns",
                    title: "Copy Last DNS",
                    systemImage: "doc.on.doc",
                    kind: .destination(.copyLastDNS)
                ),
            ]
        }

        actions += [
            MenuBarQuickAction(
                id: "flush-dns",
                title: StoreSafeDNSFlushGuidanceViewModel().buttonLabel,
                systemImage: "arrow.triangle.2.circlepath",
                kind: .destination(.flushDNS)
            ),
            MenuBarQuickAction(
                id: "validate-system-dns",
                title: "Validate System DNS",
                systemImage: "checkmark.seal",
                kind: .destination(.systemDNSValidation)
            ),
            MenuBarQuickAction(
                id: "history",
                title: "History",
                systemImage: "clock.arrow.circlepath",
                kind: .destination(.history)
            ),
            MenuBarQuickAction(
                id: "network-settings",
                title: "Open Network Settings",
                systemImage: "gearshape",
                kind: .destination(.networkSettings)
            ),
            MenuBarQuickAction(
                id: "quit",
                title: "Quit DNS Pilot",
                systemImage: "power",
                kind: .quit
            ),
        ]
        self.actions = actions
    }
}
