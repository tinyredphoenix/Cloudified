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
    private var lastRequestCompleted: TimeInterval?
    func upload(ledger: Ledger?, metadata: DiagnosticReportMetadata,
                fallback: [DiagnosticReportFallback],
                responseObserved: @Sendable (Int, Int) async -> Void) async throws -> URL {
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
        var request = URLRequest(url: URL(string: "https://dpaste.com/api/v2/")!)
        request.httpMethod = "POST"; request.httpBody = Self.formBody(body); request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Cloudified/\(metadata.version) (https://github.com/tinyredphoenix/Cloudified)", forHTTPHeaderField: "User-Agent")
        let transport = ForegroundFileUploadTransport()
        let (data, response) = try await requestData(request, transport: transport)
        guard let http = response as? HTTPURLResponse else { throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected) }
        await responseObserved(http.statusCode, data.count)
        // A partial response, redirect or uncertain result is never success.
        guard http.statusCode == 201 else {
            throw SafeFailure(.transfer, domain: .urlSession, code: http.statusCode, cause: .providerRejected)
        }
        guard data.count <= 256, let raw = String(data: data, encoding: .utf8),
              let returned = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              returned.scheme == "https", returned.host == "dpaste.com", returned.port == nil,
              returned.user == nil, returned.password == nil, returned.query == nil, returned.fragment == nil,
              returned.path.hasPrefix("/"), returned.path.split(separator: "/").count == 1 else {
            throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected)
        }
        let id = returned.path.split(separator: "/")[0]
        guard (1...64).contains(id.utf8.count), id.utf8.allSatisfy({ Self.isAlphanumeric($0) }) else {
            throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected)
        }
        let url = URL(string: "https://dpaste.com/\(id)")!
        var verify = URLRequest(url: URL(string: "https://dpaste.com/\(id).txt")!)
        verify.timeoutInterval = 30
        verify.setValue("Cloudified/\(metadata.version) (https://github.com/tinyredphoenix/Cloudified)", forHTTPHeaderField: "User-Agent")
        let (stored, verificationResponse) = try await requestData(verify, transport: transport)
        guard let verificationHTTP = verificationResponse as? HTTPURLResponse else {
            throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected)
        }
        await responseObserved(verificationHTTP.statusCode, stored.count)
        guard verificationHTTP.statusCode == 200 else {
            throw SafeFailure(.transfer, domain: .urlSession, code: verificationHTTP.statusCode, cause: .providerRejected)
        }
        // HTTP success alone does not establish completeness. Verify raw content.
        guard stored == body else { throw SafeFailure(.transfer, domain: .urlSession, cause: .formatRejected) }
        return url
    }
    private func requestData(_ request: URLRequest, transport: ForegroundFileUploadTransport) async throws -> (Data, URLResponse) {
        // dpaste permits one request/second. Space even verification reads and
        // successive explicit taps; never automatically retry a rejected POST.
        if let lastRequestCompleted {
            let remaining = 1.1 - (ProcessInfo.processInfo.systemUptime - lastRequestCompleted)
            if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
        }
        try Task.checkCancellation()
        defer { lastRequestCompleted = ProcessInfo.processInfo.systemUptime }
        return try await transport.requestData(request)
    }
    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
    }
    private static func formBody(_ body: Data) -> Data {
        let hex = Array("0123456789ABCDEF".utf8)
        var form = Data("content=".utf8); form.reserveCapacity(body.count * 3 + 16)
        for byte in body {
            if isAlphanumeric(byte) || [42, 45, 46, 95].contains(byte) { form.append(byte) }
            else if byte == 32 { form.append(43) }
            else { form.append(37); form.append(hex[Int(byte >> 4)]); form.append(hex[Int(byte & 15)]) }
        }
        form.append(Data("&expiry_days=7".utf8)); return form
    }
}
