import Foundation
import Photos
import CloudifiedCore

/// Low-level PhotoKit exporter handling cancellable streaming requests directly to disk.
public final class PhotoResourceExporter: Sendable {
    public static let shared = PhotoResourceExporter()

    public init() {}

    /// Exports a specific PHAssetResource directly to destination file URL.
    /// Streams chunks into disk and calculates dual SHA-256 and SHA-1 in a single pass.
    public func exportResource(
        _ resource: PHAssetResource,
        to destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (sha256: String, sha1: String, byteCount: Int64) {
        let writer = try StreamingFileWriter(fileURL: destinationURL)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                if let onProgress {
                    options.progressHandler = { progress in
                        onProgress(progress)
                    }
                }

                // Guard against multiple resumes from asynchronous callbacks
                final class CompletionGate: @unchecked Sendable {
                    var isCompleted = false
                    var requestID: PHAssetResourceDataRequestID?
                }
                let gate = CompletionGate()

                let reqID = PHAssetResourceManager.default().requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: { data in
                        do {
                            try writer.write(chunk: data)
                        } catch {
                            // If writing failed, cancel the resource request
                            if let id = gate.requestID {
                                PHAssetResourceManager.default().cancelDataRequest(id)
                            }
                            synchronized(gate) {
                                if !gate.isCompleted {
                                    gate.isCompleted = true
                                    writer.abort()
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    },
                    completionHandler: { error in
                        synchronized(gate) {
                            if gate.isCompleted { return }
                            gate.isCompleted = true

                            if let error {
                                writer.abort()
                                let nsError = error as NSError
                                let safeError: SafeFailure
                                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                                    safeError = SafeFailure(.sourceUnavailable, domain: .photos, code: nsError.code, cause: .interrupted)
                                } else {
                                    safeError = SafeFailure(.sourceUnavailable, domain: .photos, code: nsError.code, cause: .sourceMissing)
                                }
                                continuation.resume(throwing: safeError)
                            } else {
                                do {
                                    let result = try writer.finalize()
                                    continuation.resume(returning: result)
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                )
                gate.requestID = reqID
            }
        } onCancel: {
            // Task cancellation fences PhotoKit request
            writer.abort()
        }
    }
}

private func synchronized<T>(_ lock: AnyObject, _ body: () -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return body()
}
