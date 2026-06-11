import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkExecutableLocatorTests: XCTestCase {
    func testLocatorUsesEnvironmentOverrideWhenPresent() {
        let locator = BenchmarkExecutableLocator(
            environment: ["DNSPILOT_CLI_PATH": "/tmp/dnspilot-cli"],
            bundledExecutablePath: "/Applications/DNSPilot.app/Contents/Resources/dnspilot-cli"
        )

        let result = locator.locate()

        XCTAssertEqual(result, .found(URL(fileURLWithPath: "/tmp/dnspilot-cli"), source: .environmentOverride))
    }

    func testLocatorUsesBundledExecutableWhenOverrideIsMissing() {
        let locator = BenchmarkExecutableLocator(
            environment: [:],
            bundledExecutablePath: "/Applications/DNSPilot.app/Contents/Resources/dnspilot-cli"
        )

        let result = locator.locate()

        XCTAssertEqual(
            result,
            .found(
                URL(fileURLWithPath: "/Applications/DNSPilot.app/Contents/Resources/dnspilot-cli"),
                source: .bundleResource
            )
        )
    }

    func testLocatorReturnsMissingWhenNoPathIsAvailable() {
        let locator = BenchmarkExecutableLocator(environment: [:], bundledExecutablePath: nil)

        let result = locator.locate()

        XCTAssertEqual(
            result,
            .missing("DNS Pilot CLI executable is not bundled. Set DNSPILOT_CLI_PATH for development builds.")
        )
    }
}
