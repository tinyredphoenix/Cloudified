import Foundation
import CloudifiedCore

/// Process-wide serialization gate for PhotoKit original exports.
/// Enforces that only one original export/hash operation is active at any time
/// across both metadata planning and OriginalPreparer tasks.
public actor SharedExportPermit {
    public static let shared = SharedExportPermit()

    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Acquires the single export permit, suspending until available.
    public func acquire() async {
        if !held {
            held = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Releases the permit to the next waiting export task in FIFO order.
    public func release() {
        if waiters.isEmpty {
            held = false
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    /// Executes a scoped asynchronous operation under the export permit.
    public func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }
}
