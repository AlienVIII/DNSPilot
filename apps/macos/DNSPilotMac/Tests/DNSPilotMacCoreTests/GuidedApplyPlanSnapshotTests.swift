import Foundation
import XCTest
@testable import DNSPilotMacCore

final class GuidedApplyPlanSnapshotTests: XCTestCase {
    func testSnapshotBuildsFromGuidedApplyPlan() {
        let viewModel = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .guideOnly,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                testedResolver: "1.1.1.1:53",
                dnsServers: ["1.1.1.1", "1.0.0.1"],
                canApply: false,
                notes: ["Store-safe guide only."]
            )
        )

        let snapshot = GuidedApplyPlanSnapshot.make(
            from: viewModel,
            currentDNSBeforeApply: SystemDNSResolverSnapshot(
                servers: ["192.168.1.1"],
                searchDomains: ["home.arpa"],
                supplementalResolverCount: 0,
                loadedAt: Date(timeIntervalSince1970: 40)
            ),
            createdAt: Date(timeIntervalSince1970: 42)
        )

        XCTAssertEqual(snapshot?.profileID, "cloudflare")
        XCTAssertEqual(snapshot?.profileName, "Cloudflare")
        XCTAssertEqual(snapshot?.testedResolver, "1.1.1.1:53")
        XCTAssertEqual(snapshot?.dnsServerText, "1.1.1.1\n1.0.0.1")
        XCTAssertEqual(snapshot?.restoreDNSServerText, "192.168.1.1")
        XCTAssertTrue(snapshot?.copyText.contains("DNS Pilot has not changed system DNS.") == true)
        XCTAssertTrue(snapshot?.copyText.contains("Current DNS before apply:\n192.168.1.1") == true)
        XCTAssertTrue(snapshot?.copyText.contains("Store-safe guide only.") == true)
    }

    func testSnapshotDecodesLegacyPayloadWithoutRestoreFields() throws {
        let json = """
        {
          "profileID": "cloudflare",
          "profileName": "Cloudflare",
          "testedResolver": "1.1.1.1:53",
          "dnsServers": ["1.1.1.1"],
          "notes": [],
          "createdAt": 42
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let snapshot = try decoder.decode(GuidedApplyPlanSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.profileID, "cloudflare")
        XCTAssertTrue(snapshot.restoreDNSServers.isEmpty)
        XCTAssertTrue(snapshot.restoreSearchDomains.isEmpty)
    }

    func testSnapshotRejectsNonGuidedOrEmptyPlans() {
        let protected = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .protectCurrentDNS,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                dnsServers: ["1.1.1.1"],
                canApply: false,
                notes: []
            )
        )
        let empty = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .guideOnly,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                dnsServers: [],
                canApply: false,
                notes: []
            )
        )

        XCTAssertNil(GuidedApplyPlanSnapshot.make(from: protected))
        XCTAssertNil(GuidedApplyPlanSnapshot.make(from: empty))
    }

    func testStoreRoundTripsAndClearsSnapshot() {
        let suiteName = "DNSPilotGuidedApplyPlanSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = GuidedApplyPlanStore(
            userDefaults: defaults,
            key: "last-plan",
            now: { Date(timeIntervalSince1970: 20) }
        )
        let snapshot = GuidedApplyPlanSnapshot(
            profileID: "cloudflare",
            profileName: "Cloudflare",
            testedResolver: "1.1.1.1:53",
            dnsServers: ["1.1.1.1"],
            restoreDNSServers: [],
            restoreSearchDomains: [],
            notes: [],
            createdAt: Date(timeIntervalSince1970: 10)
        )

        store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)

        store.clear()
        XCTAssertNil(store.load())
    }

    func testStoreClearsCorruptPayload() {
        let suiteName = "DNSPilotGuidedApplyPlanSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(Data("not-json".utf8), forKey: "last-plan")
        let store = GuidedApplyPlanStore(userDefaults: defaults, key: "last-plan")

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: "last-plan"))
    }

    func testStoreClearsStaleSnapshot() {
        let suiteName = "DNSPilotGuidedApplyPlanSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = GuidedApplyPlanStore(
            userDefaults: defaults,
            key: "last-plan",
            maxAge: 60,
            now: { Date(timeIntervalSince1970: 200) }
        )
        let snapshot = GuidedApplyPlanSnapshot(
            profileID: "cloudflare",
            profileName: "Cloudflare",
            testedResolver: "1.1.1.1:53",
            dnsServers: ["1.1.1.1"],
            restoreDNSServers: [],
            restoreSearchDomains: [],
            notes: [],
            createdAt: Date(timeIntervalSince1970: 100)
        )

        store.save(snapshot)

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: "last-plan"))
    }
}
