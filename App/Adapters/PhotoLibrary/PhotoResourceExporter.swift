import Foundation
@preconcurrency import Photos
import CloudifiedCore

/// Only PhotoKit's terminal completion closes the writer/resumes its owner.
public final class PhotoResourceExporter: Sendable {
    public static let shared = PhotoResourceExporter()
    public init() {}
    public func exportResource(_ resource: PHAssetResource, to destinationURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil,
        beforeWrite: (@Sendable (Int64) throws -> Void)? = nil
    ) async throws -> (sha256: String, sha1: String, byteCount: Int64) {
        let request = ExportRequest(writer: try StreamingFileWriter(fileURL: destinationURL, beforeWrite: beforeWrite))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard request.begin(continuation) else { return }
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                if let onProgress { options.progressHandler = { onProgress($0) } }
                let id = PHAssetResourceManager.default().requestData(for: resource, options: options,
                    dataReceivedHandler: { request.receive($0) }, completionHandler: { request.complete($0) })
                request.install(id)
            }
        } onCancel: { request.cancel() }
    }
}

/// Every field is lock-protected, including cancellation before request-ID publication.
/// No per-chunk Task, additional callback queue or unbounded media buffer.
private final class ExportRequest: @unchecked Sendable {
    typealias Output = (sha256: String, sha1: String, byteCount: Int64)
    private let lock = NSLock()
    private let writer: StreamingFileWriter
    private var continuation: CheckedContinuation<Output, any Error>?
    private var requestID: PHAssetResourceDataRequestID?
    private var cancelRequested = false
    private var finished = false
    private var firstError: (any Error)?
    init(writer: StreamingFileWriter) { self.writer = writer }
    func begin(_ continuation: CheckedContinuation<Output, any Error>) -> Bool {
        lock.lock()
        if cancelRequested {
            finished = true; writer.abort(); lock.unlock()
            continuation.resume(throwing: CancellationError()); return false
        }
        self.continuation = continuation; lock.unlock(); return true
    }
    func install(_ id: PHAssetResourceDataRequestID) {
        lock.lock(); requestID = id
        let shouldCancel = !finished && cancelRequested; lock.unlock()
        if shouldCancel { PHAssetResourceManager.default().cancelDataRequest(id) }
    }
    func cancel() {
        lock.lock(); cancelRequested = true
        let id = finished ? nil : requestID; lock.unlock()
        if let id { PHAssetResourceManager.default().cancelDataRequest(id) }
        // A cancellation request is not terminal callback/file-ownership proof.
    }
    func receive(_ data: Data) {
        lock.lock()
        guard !finished, !cancelRequested, firstError == nil else { lock.unlock(); return }
        do { try writer.write(chunk: data); lock.unlock() }
        catch {
            firstError = error; cancelRequested = true
            let id = requestID; lock.unlock()
            if let id { PHAssetResourceManager.default().cancelDataRequest(id) }
            // Preserve the error; await terminal completion before releasing bytes.
        }
    }
    func complete(_ error: (any Error)?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = self.continuation; self.continuation = nil
        let result: Result<Output, any Error>
        if let firstError { writer.abort(); result = .failure(firstError) }
        else if cancelRequested { writer.abort(); result = .failure(CancellationError()) }
        else if let error {
            writer.abort()
            // An arbitrary iCloud/network error is not evidence of source deletion.
            result = .failure(SafeFailure(.transfer, domain: .photos, code: (error as NSError).code, cause: .unknown))
        } else {
            do { result = .success(try writer.finalize()) }
            catch { writer.abort(); result = .failure(error) }
        }
        lock.unlock(); continuation?.resume(with: result)
    }
}
