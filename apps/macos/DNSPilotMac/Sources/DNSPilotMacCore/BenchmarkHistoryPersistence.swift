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

public struct BenchmarkHistoryPersistenceFactory: Equatable, Sendable {
    public let applicationSupportDirectory: URL
    public let appDirectoryName: String
    public let databaseFilename: String

    public init(
        applicationSupportDirectory: URL,
        appDirectoryName: String = "DNSPilot",
        databaseFilename: String = "history.sqlite"
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.appDirectoryName = appDirectoryName
        self.databaseFilename = databaseFilename
    }

    public var directoryURL: URL {
        applicationSupportDirectory.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    public var databaseURL: URL {
        directoryURL.appendingPathComponent(databaseFilename, isDirectory: false)
    }

    public func makePersistence(
        mode: BenchmarkPlanMode,
        uuid: UUID = UUID()
    ) -> BenchmarkHistoryPersistence {
        BenchmarkHistoryPersistence(
            databaseURL: databaseURL,
            historyID: BenchmarkHistoryIDFactory.makeID(mode: mode, uuid: uuid)
        )
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
