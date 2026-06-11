import Foundation

public enum BenchmarkExecutableFileKind: Equatable {
    case file
    case directory
    case missing
}

public protocol BenchmarkExecutableFileSystem {
    func kind(atPath path: String) -> BenchmarkExecutableFileKind
    func isExecutableFile(atPath path: String) -> Bool
}

public enum BenchmarkExecutableAvailability: Equatable {
    case ready(URL)
    case unavailable(String)
}

public struct BenchmarkExecutableResolver {
    private let locator: BenchmarkExecutableLocator
    private let fileSystem: any BenchmarkExecutableFileSystem

    public init(
        locator: BenchmarkExecutableLocator = BenchmarkExecutableLocator(),
        fileSystem: any BenchmarkExecutableFileSystem = FileManagerBenchmarkExecutableFileSystem()
    ) {
        self.locator = locator
        self.fileSystem = fileSystem
    }

    public func resolve() -> BenchmarkExecutableAvailability {
        switch locator.locate() {
        case .missing(let message):
            return .unavailable(message)
        case .found(let url, source: _):
            return availability(for: url)
        }
    }

    private func availability(for url: URL) -> BenchmarkExecutableAvailability {
        switch fileSystem.kind(atPath: url.path) {
        case .missing:
            return .unavailable("DNS Pilot CLI executable was not found at \(url.path).")
        case .directory:
            return .unavailable("DNS Pilot CLI executable path is a directory: \(url.path).")
        case .file:
            guard fileSystem.isExecutableFile(atPath: url.path) else {
                return .unavailable("DNS Pilot CLI executable is not executable: \(url.path).")
            }
            return .ready(url)
        }
    }
}

public struct FileManagerBenchmarkExecutableFileSystem: BenchmarkExecutableFileSystem {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func kind(atPath path: String) -> BenchmarkExecutableFileKind {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .directory : .file
    }

    public func isExecutableFile(atPath path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }
}
