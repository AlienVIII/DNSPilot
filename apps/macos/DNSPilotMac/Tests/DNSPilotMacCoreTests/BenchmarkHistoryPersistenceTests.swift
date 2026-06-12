import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkHistoryPersistenceTests: XCTestCase {
    func testPersistenceBuildsCLIArguments() {
        let persistence = BenchmarkHistoryPersistence(
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            historyID: "compare-run-1"
        )

        XCTAssertEqual(
            persistence.commandArguments,
            ["--save-db", "/tmp/dnspilot.sqlite", "--history-id", "compare-run-1"]
        )
    }

    func testHistoryIDFactoryUsesModePrefixAndLowercaseUUID() {
        let uuid = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        XCTAssertEqual(
            BenchmarkHistoryIDFactory.makeID(mode: .dnsOnlyCompare, uuid: uuid),
            "compare-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        )
        XCTAssertEqual(
            BenchmarkHistoryIDFactory.makeID(mode: .connectionPathCompare, uuid: uuid),
            "path-compare-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        )
    }

    func testPersistenceFactoryBuildsApplicationSupportDatabaseLocation() {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let factory = BenchmarkHistoryPersistenceFactory(
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/test/Library/Application Support")
        )

        let persistence = factory.makePersistence(mode: .dnsOnlyCompare, uuid: uuid)

        XCTAssertEqual(
            persistence.databaseURL.path,
            "/Users/test/Library/Application Support/DNSPilot/dnspilot.sqlite"
        )
        XCTAssertEqual(
            factory.directoryURL.path,
            "/Users/test/Library/Application Support/DNSPilot"
        )
        XCTAssertEqual(
            persistence.historyID,
            "compare-11111111-2222-3333-4444-555555555555"
        )
    }
}
