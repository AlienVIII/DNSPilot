import Foundation
import XCTest
@testable import DNSPilotMacCore

final class SystemDNSResolverViewModelTests: XCTestCase {
    func testViewModelShowsCurrentServersWhenAvailable() {
        let viewModel = SystemDNSResolverViewModel(
            snapshot: SystemDNSResolverSnapshot(
                servers: ["1.1.1.1", "2606:4700:4700::1111"],
                searchDomains: ["corp.example"],
                supplementalResolverCount: 2,
                loadedAt: Date(timeIntervalSince1970: 10)
            )
        )

        XCTAssertEqual(viewModel.resolverLabel, "Resolver: 1.1.1.1, 2606:4700:4700::1111")
        XCTAssertTrue(viewModel.detailLines.contains("Search domains: corp.example"))
        XCTAssertTrue(viewModel.detailLines.contains("Supplemental/scoped resolvers: 2"))
        XCTAssertTrue(viewModel.copyText.contains("DNS servers:\n1.1.1.1\n2606:4700:4700::1111"))
    }

    func testViewModelFallsBackWhenServersAreUnavailable() {
        let viewModel = SystemDNSResolverViewModel(snapshot: .unavailable)

        XCTAssertEqual(viewModel.resolverLabel, "Resolver: current macOS system resolver")
        XCTAssertEqual(
            viewModel.detailLines,
            ["DNS server addresses are unavailable; System DNS validation still uses the current macOS resolver path."]
        )
        XCTAssertTrue(viewModel.copyText.contains("DNS servers unavailable"))
    }
}
