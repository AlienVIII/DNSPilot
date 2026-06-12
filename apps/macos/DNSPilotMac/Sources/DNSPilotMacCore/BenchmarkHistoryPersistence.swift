import Foundation

public struct BenchmarkHistoryPersistence: Equatable, Sendable {
    public let databaseURL: URL
    public let historyID: String

    public init(databaseURL: URL, historyID: String) {
        self.databaseURL = databaseURL
        self.historyID = historyID
    }

    public var commandArguments: [String] {
        ["--save-db", databaseURL.path, "--history-id", historyID]
    }
}

public enum BenchmarkHistoryIDFactory {
    public static func makeID(mode: BenchmarkPlanMode, uuid: UUID = UUID()) -> String {
        "\(prefix(for: mode))-\(uuid.uuidString.lowercased())"
    }

    private static func prefix(for mode: BenchmarkPlanMode) -> String {
        switch mode {
        case .dnsOnlyCompare:
            "compare"
        case .connectionPathCompare:
            "path-compare"
        }
    }
}
