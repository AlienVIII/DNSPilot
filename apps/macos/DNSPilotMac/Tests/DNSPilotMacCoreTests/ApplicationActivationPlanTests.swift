import XCTest
@testable import DNSPilotMacCore

final class ApplicationActivationPlanTests: XCTestCase {
    func testLaunchPlanPromotesSwiftPMExecutableToForegroundApplication() {
        XCTAssertEqual(
            DNSPilotApplicationActivationPlan.launch.actions,
            [.setRegularActivationPolicy, .activateIgnoringOtherApps]
        )
    }

    func testReopenDoesNotAskAppKitForAnotherWindowWhenOneIsVisible() {
        XCTAssertFalse(
            DNSPilotApplicationActivationPlan.shouldDeferReopenToSystem(
                hasVisibleWindows: true
            )
        )
    }

    func testReopenDefersToAppKitWhenNoWindowIsVisible() {
        XCTAssertTrue(
            DNSPilotApplicationActivationPlan.shouldDeferReopenToSystem(
                hasVisibleWindows: false
            )
        )
    }
}
