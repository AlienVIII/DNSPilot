import Foundation

public enum PowerDNSRollbackMode: String, Codable, Equatable, Sendable {
    case automatic
    case servers
}

public struct PowerDNSRollbackSnapshot: Codable, Equatable, Sendable {
    public let service: String
    public let mode: PowerDNSRollbackMode
    public let servers: [String]
    public let createdAt: Date

    public init(
        service: String,
        mode: PowerDNSRollbackMode,
        servers: [String],
        createdAt: Date
    ) {
        self.service = service
        self.mode = mode
        self.servers = servers
        self.createdAt = createdAt
    }

    public var isRestorable: Bool {
        !service.isEmpty && (mode == .automatic || !servers.isEmpty)
    }

    public func isFresh(now: Date = Date(), maxAge: TimeInterval = 86_400) -> Bool {
        now.timeIntervalSince(createdAt) <= maxAge
    }
}

public final class PowerDNSRollbackStore {
    public static let defaultKey = "DNSPilot.lastPowerDNSRollback"

    private let userDefaults: UserDefaults
    private let key: String
    private let maxAge: TimeInterval
    private let now: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = defaultKey,
        maxAge: TimeInterval = 86_400,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.maxAge = maxAge
        self.now = now
    }

    public func load() -> PowerDNSRollbackSnapshot? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            let snapshot = try decoder.decode(PowerDNSRollbackSnapshot.self, from: data)
            guard snapshot.isRestorable, snapshot.isFresh(now: now(), maxAge: maxAge) else {
                clear()
                return nil
            }
            return snapshot
        } catch {
            clear()
            return nil
        }
    }

    public func save(_ snapshot: PowerDNSRollbackSnapshot) {
        guard snapshot.isRestorable, let data = try? encoder.encode(snapshot) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }

    public func clear() {
        userDefaults.removeObject(forKey: key)
    }
}
