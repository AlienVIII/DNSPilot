import Foundation

public enum MenuBarQuickActionKind: Equatable {
    case destination(MenuBarQuickDestination)
    case quit
}

public enum MenuBarQuickDestination: String, Equatable {
    case openApp
    case benchmark
    case quickBenchmark
    case history
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

    public init() {
        actions = [
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
            MenuBarQuickAction(
                id: "history",
                title: "History",
                systemImage: "clock.arrow.circlepath",
                kind: .destination(.history)
            ),
            MenuBarQuickAction(
                id: "quit",
                title: "Quit DNS Pilot",
                systemImage: "power",
                kind: .quit
            ),
        ]
    }
}
