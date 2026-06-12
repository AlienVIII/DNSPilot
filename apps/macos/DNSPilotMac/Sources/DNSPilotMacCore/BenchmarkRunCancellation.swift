import Foundation

public final class BenchmarkRunCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var handlers: [UUID: () -> Void] = [:]

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    @discardableResult
    public func register(_ handler: @escaping () -> Void) -> BenchmarkRunCancellationRegistration {
        let id = UUID()
        var shouldRunImmediately = false

        lock.lock()
        if cancelled {
            shouldRunImmediately = true
        } else {
            handlers[id] = handler
        }
        lock.unlock()

        if shouldRunImmediately {
            handler()
        }

        return BenchmarkRunCancellationRegistration { [weak self] in
            self?.unregister(id)
        }
    }

    public func cancel() {
        let callbacks: [() -> Void]

        lock.lock()
        if cancelled {
            lock.unlock()
            return
        }
        cancelled = true
        callbacks = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()

        callbacks.forEach { $0() }
    }

    private func unregister(_ id: UUID) {
        lock.lock()
        handlers[id] = nil
        lock.unlock()
    }
}

public final class BenchmarkRunCancellationRegistration: @unchecked Sendable {
    private let lock = NSLock()
    private var unregister: (() -> Void)?

    fileprivate init(unregister: @escaping () -> Void) {
        self.unregister = unregister
    }

    public func cancel() {
        let action: (() -> Void)?

        lock.lock()
        action = unregister
        unregister = nil
        lock.unlock()

        action?()
    }
}
