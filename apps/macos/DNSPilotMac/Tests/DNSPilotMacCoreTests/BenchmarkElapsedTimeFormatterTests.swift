import XCTest
@testable import DNSPilotMacCore

final class BenchmarkElapsedTimeFormatterTests: XCTestCase {
    func testFormatterUsesMillisecondsForSubsecondDurations() {
        XCTAssertEqual(BenchmarkElapsedTimeFormatter.label(milliseconds: 250), "250 ms")
    }

    func testFormatterUsesSecondsForLongerDurations() {
        XCTAssertEqual(BenchmarkElapsedTimeFormatter.label(milliseconds: 1_240), "1.2 s")
    }
}
