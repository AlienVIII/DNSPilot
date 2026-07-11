import Foundation
import XCTest
@testable import DNSPilotMacCore

final class PowerDNSRollbackSnapshotTests: XCTestCase {
    func testAutomaticSnapshotIsFreshAndRestorable() {
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .automatic,
            servers: [],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertTrue(snapshot.isFresh(now: Date(timeIntervalSince1970: 1_100)))
        XCTAssertTrue(snapshot.isRestorable)
    }

    func testFutureDatedSnapshotIsNotFresh() {
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["1.1.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_100)
        )

        XCTAssertFalse(snapshot.isFresh(now: Date(timeIntervalSince1970: 1_000)))
    }

    func testStoreRoundTripsFreshSnapshot() {
        let defaults = makeDefaults()
        let store = PowerDNSRollbackStore(
            userDefaults: defaults,
            now: { Date(timeIntervalSince1970: 1_100) }
        )
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["1.1.1.1", "1.0.0.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        store.save(snapshot)

        XCTAssertEqual(store.load(), snapshot)
    }

    func testStoreClearsStaleAndCorruptSnapshots() {
        let defaults = makeDefaults()
        let store = PowerDNSRollbackStore(
            userDefaults: defaults,
            maxAge: 86_400,
            now: { Date(timeIntervalSince1970: 100_000) }
        )
        store.save(PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["1.1.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        ))

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: PowerDNSRollbackStore.defaultKey))

        defaults.set(Data("not json".utf8), forKey: PowerDNSRollbackStore.defaultKey)

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: PowerDNSRollbackStore.defaultKey))
    }

    private func makeDefaults() -> UserDefaults {
        let name = "PowerDNSRollbackSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
