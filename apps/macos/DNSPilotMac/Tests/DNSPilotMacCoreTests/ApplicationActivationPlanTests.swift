import XCTest
@testable import DNSPilotMacCore

final class ApplicationActivationPlanTests: XCTestCase {
    func testLaunchPlanPromotesSwiftPMExecutableToForegroundApplication() {
        XCTAssertEqual(
            DNSPilotApplicationActivationPlan.launch.actions,
            [.setRegularActivationPolicy, .activateIgnoringOtherApps]
        )
    }
}
