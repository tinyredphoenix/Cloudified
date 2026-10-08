import Foundation

/// One file reader per Google lane. Response bytes are bounded; cancellation
/// completes only through didCompleteWithError, after URLSession releases input.
final class ForegroundFileUploadTransport: NSObject, FileUploadTransport, URLSessionDataDelegate, @unchecked Sendable {
    let continuesAfterProcessExit = false
    private struct Operation {
        let id: UUID
        let task: URLSessionTask
        let continuation: CheckedContinuation<FileUploadResult, any Error>
        let progress: @Sendable (Int64, Int64) -> Void
        var data = Data()
        var overflow = false
    }
    private let lock = NSLock()
    private var operation: Operation?
    private let configuration: URLSessionConfiguration
    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration.copy() as! URLSessionConfiguration
        super.init()
    }
    // The session retains its delegate. Break that ownership after each operation;
    // this transport is reused by recreating the session on the next operation.
    private var activeSession: URLSession?

    func upload(_ request: URLRequest, fromFile file: URL, transferID: UUID,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws -> FileUploadResult {
        try await perform(request, file: file, transferID: transferID, progress: progress)
    }
    func requestData(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let result = try await perform(request, file: nil, transferID: UUID(), progress: { _, _ in })
        return (result.data, result.response)
    }
    private func perform(_ request: URLRequest, file: URL?, transferID: UUID,
                         progress: @escaping @Sendable (Int64, Int64) -> Void) async throws -> FileUploadResult {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard operation == nil else { lock.unlock(); continuation.resume(throwing: GPMCError(kind: .transport, message: "Upload already active.")); return }
                let config = configuration.copy() as! URLSessionConfiguration
                config.waitsForConnectivity = true; config.urlCache = nil
                config.timeoutIntervalForRequest = min(request.timeoutInterval, 120)
                config.timeoutIntervalForResource = file == nil ? 120 : 3600
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let owned = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                let task: URLSessionTask = file.map { owned.uploadTask(with: request, fromFile: $0) } ?? owned.dataTask(with: request)
                operation = Operation(id: transferID, task: task, continuation: continuation, progress: progress)
                activeSession = owned
                task.resume()
                if Task.isCancelled { task.cancel() }
                lock.unlock()
            }
        } onCancel: { self.cancelNow(transferID) }
    }
    private func cancelNow(_ id: UUID) {
        lock.lock(); let task = operation?.id == id ? operation?.task : nil; lock.unlock(); task?.cancel()
    }
    func cancel(transferID: UUID) async { cancelNow(transferID) }
    func forget(transferID: UUID) async {} // No terminal associations are retained.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        lock.lock(); let report = operation?.task === task ? operation?.progress : nil; lock.unlock()
        report?(totalBytesSent, max(totalBytesSent, totalBytesExpectedToSend))
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard operation?.task === dataTask else { lock.unlock(); return }
        if operation!.data.count + data.count > 1_048_576 { operation!.overflow = true; dataTask.cancel() }
        else { operation!.data.append(data) }
        lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        lock.lock()
        guard let completed = operation, completed.task === task else { lock.unlock(); return }
        operation = nil; activeSession = nil
        lock.unlock()
        session.finishTasksAndInvalidate()
        if completed.overflow { completed.continuation.resume(throwing: GPMCError(kind: .malformed, message: "Upload response exceeded limit.")) }
        else if let error {
            if (error as? URLError)?.code == .cancelled { completed.continuation.resume(throwing: CancellationError()) }
            else { completed.continuation.resume(throwing: GPMCError(kind: .transport, message: "Upload transport failed.")) }
        } else if let response = task.response as? HTTPURLResponse {
            completed.continuation.resume(returning: FileUploadResult(data: completed.data, response: response))
        } else { completed.continuation.resume(throwing: GPMCError(kind: .malformed, message: "Upload response missing.")) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Resumable uploads have a pinned Google endpoint. Do not follow an
        // arbitrary redirect with private original bytes or credentials.
        completionHandler(nil)
    }
}
