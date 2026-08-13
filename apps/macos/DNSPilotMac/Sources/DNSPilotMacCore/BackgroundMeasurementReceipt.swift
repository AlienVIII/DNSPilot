import Foundation

public enum BackgroundMeasurementKind: String, Codable, Equatable, Sendable {
    case dnsBenchmark = "dns_benchmark"
}

public enum BackgroundMeasurementStatus: String, Codable, Equatable, Sendable {
    case starting
    case running
    case completed
    case failed
    case cancelled
    case interrupted

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .interrupted:
            true
        case .starting, .running:
            false
        }
    }
}

public struct BackgroundMeasurementReceipt: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public let schemaVersion: Int
    public let runID: String
    public let kind: BackgroundMeasurementKind
    public let status: BackgroundMeasurementStatus
    public let startedAt: Date
    public let updatedAt: Date
    public let resultReference: String?

    public init(
        schemaVersion: Int = Self.schemaVersion,
        runID: String,
        kind: BackgroundMeasurementKind,
        status: BackgroundMeasurementStatus,
        startedAt: Date,
        updatedAt: Date,
        resultReference: String?
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.kind = kind
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.resultReference = resultReference
    }

    public static func starting(
        runID: String,
        kind: BackgroundMeasurementKind,
        at date: Date = Date()
    ) -> BackgroundMeasurementReceipt {
        BackgroundMeasurementReceipt(
            runID: runID,
            kind: kind,
            status: .starting,
            startedAt: date,
            updatedAt: date,
            resultReference: nil
        )
    }

    public func transitioned(
        to status: BackgroundMeasurementStatus,
        at date: Date = Date(),
        resultReference: String? = nil
    ) -> BackgroundMeasurementReceipt {
        BackgroundMeasurementReceipt(
            schemaVersion: schemaVersion,
            runID: runID,
            kind: kind,
            status: status,
            startedAt: startedAt,
            updatedAt: date,
            resultReference: resultReference
        )
    }

    public static func canStartNewMeasurement(existing: BackgroundMeasurementReceipt?) -> Bool {
        existing?.status.isTerminal ?? true
    }
}

public final class BackgroundMeasurementReceiptStore {
    public static let userDefaultsKey = "dnspilot.background-measurement-receipt.v1"

    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        key: String = BackgroundMeasurementReceiptStore.userDefaultsKey
    ) {
        self.defaults = defaults
        self.key = key
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func load() -> BackgroundMeasurementReceipt? {
        guard let data = defaults.data(forKey: key),
              let receipt = try? decoder.decode(BackgroundMeasurementReceipt.self, from: data),
              receipt.schemaVersion == BackgroundMeasurementReceipt.schemaVersion else {
            return nil
        }
        return receipt
    }

    public func save(_ receipt: BackgroundMeasurementReceipt) {
        guard let data = try? encoder.encode(receipt) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }

    @discardableResult
    public func reconcileInterruptedRun(at date: Date = Date()) -> BackgroundMeasurementReceipt? {
        guard let receipt = load(), !receipt.status.isTerminal else {
            return nil
        }
        let interrupted = receipt.transitioned(to: .interrupted, at: date)
        save(interrupted)
        return interrupted
    }
}

public enum BackgroundMeasurementNotificationPolicy {
    public static func shouldOfferOptIn(
        notificationsEnabled: Bool,
        promptHandled: Bool
    ) -> Bool {
        !notificationsEnabled && !promptHandled
    }

    public static func shouldScheduleCompletion(
        status: BackgroundMeasurementStatus,
        notificationsEnabled: Bool,
        applicationIsActive: Bool
    ) -> Bool {
        guard notificationsEnabled, !applicationIsActive else {
            return false
        }
        return status == .completed || status == .failed
    }
}

public enum BackgroundMeasurementNotificationPreferences {
    public static let enabledKey = "dnspilot.background-measurement-notifications-enabled"
    public static let promptHandledKey = "dnspilot.background-measurement-notification-prompt-handled"
}
