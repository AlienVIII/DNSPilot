import Foundation

public enum ApplyPlanRunnerError: Error, Equatable {
    case processFailed(String)
}

public enum ApplyPlanConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
    case inconclusive
}

public enum ApplyPlanGateHealth: String, Equatable, Sendable {
    case healthy
    case degraded
    case failed
    case inconclusive
}

public struct ApplyPlanRequest: Equatable, Sendable {
    public let platformID: String
    public let profileDatabaseURL: URL?
    public let profileID: String?
    public let testedResolver: String?
    public let confidence: ApplyPlanConfidence
    public let gateHealth: ApplyPlanGateHealth
    public let vpnActive: Bool
    public let mdmProfileActive: Bool
    public let corporateDNSDetected: Bool
    public let captivePortalDetected: Bool

    public init(
        platformID: String = "macos-store",
        profileDatabaseURL: URL? = nil,
        profileID: String?,
        testedResolver: String? = nil,
        confidence: ApplyPlanConfidence = .high,
        gateHealth: ApplyPlanGateHealth = .healthy,
        vpnActive: Bool = false,
        mdmProfileActive: Bool = false,
        corporateDNSDetected: Bool = false,
        captivePortalDetected: Bool = false
    ) {
        self.platformID = platformID
        self.profileDatabaseURL = profileDatabaseURL
        self.profileID = profileID
        self.testedResolver = testedResolver
        self.confidence = confidence
        self.gateHealth = gateHealth
        self.vpnActive = vpnActive
        self.mdmProfileActive = mdmProfileActive
        self.corporateDNSDetected = corporateDNSDetected
        self.captivePortalDetected = captivePortalDetected
    }

    public var commandArguments: [String] {
        var arguments = [
            "apply-plan",
            platformID,
            "--confidence", confidence.rawValue,
            "--gate-health", gateHealth.rawValue,
        ]
        if let profileDatabaseURL {
            arguments += ["--profile-db", profileDatabaseURL.path]
        }
        if let profileID {
            arguments += ["--profile-id", profileID]
        }
        if let testedResolver {
            arguments += ["--tested-resolver", testedResolver]
        }
        if vpnActive {
            arguments.append("--vpn-active")
        }
        if mdmProfileActive {
            arguments.append("--mdm-profile-active")
        }
        if corporateDNSDetected {
            arguments.append("--corporate-dns-detected")
        }
        if captivePortalDetected {
            arguments.append("--captive-portal-detected")
        }
        return arguments
    }
}

public struct ApplyPlanRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning
    private let decoder: ApplyPlanJSONDecoder

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner(),
        decoder: ApplyPlanJSONDecoder = ApplyPlanJSONDecoder()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
        self.decoder = decoder
    }

    public func load(request: ApplyPlanRequest) throws -> ApplyPlan {
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: request.commandArguments,
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw ApplyPlanRunnerError.processFailed(Self.failureMessage(from: output))
        }
        return try decoder.decode(Data(output.standardOutput.utf8))
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

        return "Apply plan command exited with code \(output.exitCode)."
    }
}
