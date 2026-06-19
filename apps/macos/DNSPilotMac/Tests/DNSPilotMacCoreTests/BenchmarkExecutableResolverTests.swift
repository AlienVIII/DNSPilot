import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkExecutableResolverTests: XCTestCase {
    func testResolverReturnsReadyForExecutableFile() {
        let resolver = BenchmarkExecutableResolver(
            locator: BenchmarkExecutableLocator(environment: ["DNSPILOT_CLI_PATH": "/tmp/dnspilot-cli"]),
            fileSystem: FakeExecutableFileSystem(
                kinds: ["/tmp/dnspilot-cli": .file],
                executablePaths: ["/tmp/dnspilot-cli"]
            )
        )

        XCTAssertEqual(resolver.resolve(), .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")))
        XCTAssertTrue(resolver.resolve().isReady)
    }

    func testResolverReturnsUnavailableWhenLocatedPathIsMissing() {
        let resolver = BenchmarkExecutableResolver(
            locator: BenchmarkExecutableLocator(environment: ["DNSPILOT_CLI_PATH": "/tmp/missing-cli"]),
            fileSystem: FakeExecutableFileSystem(kinds: [:], executablePaths: [])
        )

        XCTAssertEqual(
            resolver.resolve(),
            .unavailable("DNS Pilot CLI executable was not found at /tmp/missing-cli.")
        )
        XCTAssertFalse(resolver.resolve().isReady)
    }

    func testResolverReturnsUnavailableWhenLocatedPathIsDirectory() {
        let resolver = BenchmarkExecutableResolver(
            locator: BenchmarkExecutableLocator(environment: ["DNSPILOT_CLI_PATH": "/tmp/dnspilot-cli"]),
            fileSystem: FakeExecutableFileSystem(
                kinds: ["/tmp/dnspilot-cli": .directory],
                executablePaths: ["/tmp/dnspilot-cli"]
            )
        )

        XCTAssertEqual(
            resolver.resolve(),
            .unavailable("DNS Pilot CLI executable path is a directory: /tmp/dnspilot-cli.")
        )
    }

    func testResolverReturnsUnavailableWhenLocatedPathIsNotExecutable() {
        let resolver = BenchmarkExecutableResolver(
            locator: BenchmarkExecutableLocator(environment: ["DNSPILOT_CLI_PATH": "/tmp/dnspilot-cli"]),
            fileSystem: FakeExecutableFileSystem(
                kinds: ["/tmp/dnspilot-cli": .file],
                executablePaths: []
            )
        )

        XCTAssertEqual(
            resolver.resolve(),
            .unavailable("DNS Pilot CLI executable is not executable: /tmp/dnspilot-cli.")
        )
    }
}

private struct FakeExecutableFileSystem: BenchmarkExecutableFileSystem {
    let kinds: [String: BenchmarkExecutableFileKind]
    let executablePaths: Set<String>

    init(kinds: [String: BenchmarkExecutableFileKind], executablePaths: Set<String>) {
        self.kinds = kinds
        self.executablePaths = executablePaths
    }

    func kind(atPath path: String) -> BenchmarkExecutableFileKind {
        kinds[path] ?? .missing
    }

    func isExecutableFile(atPath path: String) -> Bool {
        executablePaths.contains(path)
    }
}
