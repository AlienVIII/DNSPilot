import Foundation

public struct CatalogProfileListPayload: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let profiles: [CatalogProfile]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case profiles
    }
}

public struct CatalogSuiteListPayload: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let testSuites: [CatalogTestSuite]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case testSuites = "test_suites"
    }
}

public enum CatalogProfileListJSONDecoder {
    public static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> CatalogProfileListPayload {
        let payload = try decoder.decode(CatalogProfileListPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return payload
    }
}

public enum CatalogSuiteListJSONDecoder {
    public static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> CatalogSuiteListPayload {
        let payload = try decoder.decode(CatalogSuiteListPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return payload
    }
}

public struct CatalogStorageSnapshot: Equatable, Sendable {
    public let profiles: [CatalogProfile]
    public let testSuites: [CatalogTestSuite]

    public init(profiles: [CatalogProfile], testSuites: [CatalogTestSuite]) {
        self.profiles = profiles
        self.testSuites = testSuites
    }
}

public enum CatalogStorageRunnerError: Error, Equatable {
    case processFailed(String)
}

public struct CatalogStorageRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func loadSnapshot(databaseURL: URL) throws -> CatalogStorageSnapshot {
        CatalogStorageSnapshot(
            profiles: try loadProfiles(databaseURL: databaseURL),
            testSuites: try loadTestSuites(databaseURL: databaseURL)
        )
    }

    public func loadProfiles(databaseURL: URL) throws -> [CatalogProfile] {
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: ["profile-list", "--db", databaseURL.path],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw CatalogStorageRunnerError.processFailed(Self.failureMessage(from: output))
        }
        return try CatalogProfileListJSONDecoder.decode(Data(output.standardOutput.utf8)).profiles
    }

    public func loadTestSuites(databaseURL: URL) throws -> [CatalogTestSuite] {
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: ["suite-list", "--db", databaseURL.path],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw CatalogStorageRunnerError.processFailed(Self.failureMessage(from: output))
        }
        return try CatalogSuiteListJSONDecoder.decode(Data(output.standardOutput.utf8)).testSuites
    }

    private static func failureMessage(from output: BenchmarkProcessOutput) -> String {
        let standardError = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardError.isEmpty {
            return standardError
        }

        let standardOutput = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardOutput.isEmpty {
            return standardOutput
        }

        return "Catalog storage command exited with code \(output.exitCode)."
    }
}

public struct StorageBackedCatalogBridge: DNSPilotCatalogBridge {
    private let baseBridge: any DNSPilotCatalogBridge
    private let storageRunner: CatalogStorageRunner
    private let databaseURL: URL

    public init(
        baseBridge: any DNSPilotCatalogBridge,
        storageRunner: CatalogStorageRunner,
        databaseURL: URL
    ) {
        self.baseBridge = baseBridge
        self.storageRunner = storageRunner
        self.databaseURL = databaseURL
    }

    public func loadCatalog() throws -> CatalogSnapshot {
        let baseCatalog = try baseBridge.loadCatalog()
        do {
            let storageSnapshot = try storageRunner.loadSnapshot(databaseURL: databaseURL)
            return baseCatalog.merging(storageSnapshot: storageSnapshot)
        } catch {
            return baseCatalog
        }
    }
}

public extension CatalogSnapshot {
    func merging(storageSnapshot: CatalogStorageSnapshot) -> CatalogSnapshot {
        CatalogSnapshot(
            schemaVersion: schemaVersion,
            profiles: Self.merge(base: profiles, stored: storageSnapshot.profiles),
            testSuites: Self.merge(base: testSuites, stored: storageSnapshot.testSuites)
        )
    }

    private static func merge<Item: Identifiable>(base: [Item], stored: [Item]) -> [Item] where Item.ID == String {
        var merged = base
        for item in stored {
            if !merged.contains(where: { $0.id == item.id }) {
                merged.append(item)
            }
        }
        return merged
    }
}
