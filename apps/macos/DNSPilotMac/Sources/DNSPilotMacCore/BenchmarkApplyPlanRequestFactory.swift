import Foundation

public enum BenchmarkApplyPlanRequestFactory {
    public static func makeRequest(
        for result: BenchmarkResultPayload,
        platformID: String = "macos-store",
        profileDatabaseURL: URL? = nil,
        vpnActive: Bool = false,
        mdmProfileActive: Bool = false,
        corporateDNSDetected: Bool = false,
        captivePortalDetected: Bool = false
    ) -> ApplyPlanRequest {
        ApplyPlanRequest(
            platformID: platformID,
            profileDatabaseURL: profileDatabaseURL,
            profileID: recommendedProfileID(for: result),
            confidence: applyPlanConfidence(for: result.recommendation?.confidence),
            gateHealth: applyPlanGateHealth(for: result.summary.health),
            vpnActive: vpnActive,
            mdmProfileActive: mdmProfileActive,
            corporateDNSDetected: corporateDNSDetected,
            captivePortalDetected: captivePortalDetected
        )
    }

    private static func recommendedProfileID(for result: BenchmarkResultPayload) -> String? {
        guard result.summary.canRecommend else {
            return nil
        }
        return result.summary.recommendedProfileID ?? result.recommendation?.profileID
    }

    private static func applyPlanConfidence(for confidence: BenchmarkConfidence?) -> ApplyPlanConfidence {
        switch confidence {
        case .high:
            .high
        case .medium:
            .medium
        case .low:
            .low
        case .inconclusive, nil:
            .inconclusive
        }
    }

    private static func applyPlanGateHealth(for health: BenchmarkHealth) -> ApplyPlanGateHealth {
        switch health {
        case .healthy:
            .healthy
        case .degraded:
            .degraded
        case .failed:
            .failed
        case .inconclusive:
            .inconclusive
        }
    }
}
