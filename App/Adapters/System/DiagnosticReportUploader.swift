import Foundation
import CloudifiedCore

struct DiagnosticReportMetadata: Codable, Sendable {
    let version: String
    let build: String
    let revision: String
    let osMajor: Int
    let osMinor: Int
    let osPatch: Int
    let providerClientsAvailable: Bool
    let googleCredentialAvailable: Bool
    let network: DiagnosticDetail
}
struct DiagnosticReportFallback: Codable, Sendable {
    let timestamp: Date
    let failure: SafeFailure
}

/// Explicit user action only. One bounded public text report; no credentials or
/// raw account/service data are accepted by this interface. No automatic retries.
actor DiagnosticReportUploader {
    private var busy = false
    private let byteLimit = 256 * 1024
    func upload(ledger: Ledger?, metadata: DiagnosticReportMetadata,
                fallback: [DiagnosticReportFallback]) async throws -> URL {
        guard !busy else { throw CoreError.invalidTransition }
        busy = true; defer { busy = false }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var events = Data(), count = 0, truncated = false
        var ledgerReadFailure: SafeFailure?
        var cursor: Int64?
        // Recent context is more useful than the first events of an old install.
        // At most five pages/1,000 events and 256 KiB, including report envelope.
        if let ledger {
          do {
            for _ in 0..<5 {
                try Task.checkCancellation()
                let page = try await ledger.logPage(beforeSequence: cursor, limit: 200)
                for event in page.events {
                    let line = try encoder.encode(event) + Data([10])
                    if events.count + line.count > byteLimit - 32 * 1024 { truncated = true; break }
                    events.append(line); count += 1
                }
                if truncated || page.events.count < 200 { break }
                cursor = page.nextBeforeSequence
                if count == 1000 { truncated = true }
            }
          } catch is CancellationError { throw CancellationError() }
          catch { ledgerReadFailure = ProviderSupport.safe(error, domain: .sqlite); truncated = true }
        }
        struct Header: Encodable {
            let format: Int
            let metadata: DiagnosticReportMetadata
            let newestEvents: Int
            let truncated: Bool
            let ledgerUnavailable: Bool
            let ledgerReadFailure: SafeFailure?
            let fallback: [DiagnosticReportFallback]
        }
        var body = try encoder.encode(Header(format: 2, metadata: metadata, newestEvents: count,
            truncated: truncated, ledgerUnavailable: ledger == nil, ledgerReadFailure: ledgerReadFailure,
            fallback: Array(fallback.suffix(50)))) + Data([10])
        body.append(events)
        guard body.count <= byteLimit else { throw CoreError.invalidContract }
        try Task.checkCancellation()
        var request = URLRequest(url: URL(string: "https://paste.rs/")!)
        request.httpMethod = "POST"; request.httpBody = body; request.timeoutInterval = 30
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await ForegroundFileUploadTransport().requestData(request)
        guard let http = response as? HTTPURLResponse else { throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected) }
        // 206 is a partial paste, never a successful diagnostic report.
        guard http.statusCode == 201 else {
            throw SafeFailure(.transfer, domain: .urlSession, code: http.statusCode, cause: .providerRejected)
        }
        guard data.count <= 256, let raw = String(data: data, encoding: .utf8),
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "paste.rs", url.port == nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.hasPrefix("/"), (1...64).contains(url.path.dropFirst().utf8.count),
              url.path.dropFirst().utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else {
            throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected)
        }
        return url
    }
}
