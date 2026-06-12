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
}
