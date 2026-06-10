import XCTest
@testable import DNSPilotMacCore

final class CapabilityMatrixViewModelTests: XCTestCase {
    func testDefaultMatrixIncludesPlatformFlushAndApplyPolicy() {
        let viewModel = CapabilityMatrixViewModel()

        XCTAssertEqual(viewModel.rows.first?.platformName, "macOS Store")
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "macos-store"
                && row.flush == .guidedUserAction
                && row.applyDisposition == .allow
        })
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "windows-store"
                && row.applyDisposition == .guideOnly
        })
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "ios"
                && row.flush == .unsupported
        })
    }

    func testDesignTokensStayWithinCompactControlRules() {
        XCTAssertLessThanOrEqual(DNSPilotDesign.Radius.card, 8)
        XCTAssertLessThanOrEqual(DNSPilotDesign.Radius.control, 8)
        XCTAssertGreaterThan(DNSPilotDesign.Spacing.panel, DNSPilotDesign.Spacing.controlGap)
    }
}
