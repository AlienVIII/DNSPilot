import XCTest
@testable import DNSPilotMacCore

final class MenuBarQuickActionsViewModelTests: XCTestCase {
    func testQuickActionsExposeBenchmarkAndHistoryDestinations() {
        let viewModel = MenuBarQuickActionsViewModel()

        let destinations = viewModel.actions.compactMap { action -> MenuBarQuickDestination? in
            if case .destination(let destination) = action.kind {
                return destination
            }
            return nil
        }

        XCTAssertEqual(destinations, [.openApp, .benchmark, .quickBenchmark, .flushDNS, .systemDNSValidation, .history, .networkSettings])
    }

    func testQuickActionsExposeStoreSafeLastDNSActionsWhenAvailable() {
        let viewModel = MenuBarQuickActionsViewModel(
            lastGuidedApplyPlan: GuidedApplyPlanSnapshot(
                profileID: "cloudflare",
                profileName: "Cloudflare",
                testedResolver: "1.1.1.1:53",
                dnsServers: ["1.1.1.1", "1.0.0.1"],
                notes: [],
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        let destinations = viewModel.actions.compactMap { action -> MenuBarQuickDestination? in
            if case .destination(let destination) = action.kind {
                return destination
            }
            return nil
        }

        XCTAssertEqual(destinations, [
            .openApp,
            .benchmark,
            .quickBenchmark,
            .guidedApplyLastDNS,
            .copyLastDNS,
            .flushDNS,
            .systemDNSValidation,
            .history,
            .networkSettings,
        ])
        XCTAssertEqual(viewModel.actions.first { $0.id == "guided-apply-last-dns" }?.title, "Apply Last DNS")
        XCTAssertEqual(viewModel.actions.first { $0.id == "copy-last-dns" }?.title, "Copy Last DNS")
    }

    func testQuickActionTitlesStayShortForMenuBar() {
        let viewModel = MenuBarQuickActionsViewModel()

        XCTAssertTrue(viewModel.actions.allSatisfy { $0.title.count <= 30 })
    }

    func testQuickActionsExposeFlushDNSGuidance() {
        let viewModel = MenuBarQuickActionsViewModel()

        let action = viewModel.actions.first { $0.id == "flush-dns" }

        XCTAssertEqual(action?.title, "Flush DNS...")
        XCTAssertEqual(action?.systemImage, "arrow.triangle.2.circlepath")
        XCTAssertEqual(action?.kind, .destination(.flushDNS))
    }

    func testQuickActionsExposeStoreSafeSettingsFallback() {
        let viewModel = MenuBarQuickActionsViewModel()

        let action = viewModel.actions.first { $0.id == "network-settings" }

        XCTAssertEqual(action?.title, "Open Network Settings")
        XCTAssertEqual(action?.systemImage, "gearshape")
        XCTAssertEqual(action?.kind, .destination(.networkSettings))
    }

    func testQuickActionsExposeSystemDNSValidation() {
        let viewModel = MenuBarQuickActionsViewModel()

        let action = viewModel.actions.first { $0.id == "validate-system-dns" }

        XCTAssertEqual(action?.title, "Validate System DNS")
        XCTAssertEqual(action?.systemImage, "checkmark.seal")
        XCTAssertEqual(action?.kind, .destination(.systemDNSValidation))
    }
}
