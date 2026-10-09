import Foundation
import CloudifiedCore

extension AppEnvironment {
    func trace(_ stage: DiagnosticStage, _ status: DiagnosticStatus, provider: Provider? = nil,
               id: UUID = UUID(), started: TimeInterval? = nil, failure: SafeFailure? = nil) async {
        let detail = DiagnosticDetail(stage: stage, status: status, correlationID: id,
            available: network?.available, wifi: network?.wifi,
            expensive: network?.expensive, constrained: network?.constrained)
        do {
            try await diagnosticSink(.setupTrace,
                EventContext(origin: provider?.origin ?? .system, diagnostic: detail),
                failure == nil ? .proceed : .wait, failure == nil ? .info : .error, failure,
                started.map { max(0, ProcessInfo.processInfo.systemUptime - $0) }, nil, nil)
        } catch { /* Existing sink already records safe persistence failure. */ }
    }
    var connectionNetworkFailure: SafeFailure? {
        if network?.available != true { return SafeFailure(.connectivity, domain: .core, cause: .offline) }
        if network?.constrained == true { return SafeFailure(.connectivity, domain: .core, cause: .lowDataMode) }
        if !allowedNetwork { return SafeFailure(.connectivity, domain: .core, cause: .wifiRequired) }
        return nil
    }
    func diagnosticMessage(_ event: DiagnosticEvent) -> String {
        var text = event.failure.map(explain) ?? event.decision.rawValue
        if let detail = event.context.diagnostic {
            text += "\nStage: \(detail.stage.rawValue) · \(detail.status.rawValue)"
            text += "\nOperation: \(detail.correlationID.uuidString)"
            if let method = detail.nativeMethod { text += "\nNative request: \(method.rawValue)" }
            if let state = detail.authState { text += "\nAuthorization: \(state.rawValue)" }
            if let reason = detail.googleError { text += "\nGoogle response classification: \(reason.rawValue)" }
            if let code = detail.httpStatus { text += "\nHTTP status: \(code)" }
            if let bytes = detail.responseBytes { text += "\nResponse bytes: \(bytes)" }
            if let value = detail.available { text += "\nNetwork path: \(value ? "available" : "unavailable")" }
            if let value = detail.wifi { text += " · Wi-Fi: \(value)" }
            if let value = detail.expensive { text += " · Expensive: \(value)" }
            if let value = detail.constrained { text += " · Low Data: \(value)" }
        }
        if let duration = event.duration { text += "\nElapsed seconds: \(String(format: "%.3f", duration))" }
        return text
    }
    public var canRetryGoogleVerification: Bool { hasPendingGoogleCredential && !settingsState.isGoogleConnected }
    public func retryGoogleVerification() async throws { try await connectGoogle(oauthToken: nil) }
    public func uploadDiagnosticReport() async throws -> URL {
        let id = UUID(), started = ProcessInfo.processInfo.systemUptime
        await trace(.diagnosticUpload, .started, id: id)
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let metadata = DiagnosticReportMetadata(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unavailable",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unavailable",
            revision: Bundle.main.object(forInfoDictionaryKey: "CloudifiedRevision") as? String ?? "unavailable",
            osMajor: os.majorVersion, osMinor: os.minorVersion, osPatch: os.patchVersion,
            providerClientsAvailable: googleSession != nil && tdlibClient != nil,
            googleCredentialAvailable: hasPendingGoogleCredential,
            network: DiagnosticDetail(stage: .networkPolicy, status: .changed, correlationID: id,
                available: network?.available, wifi: network?.wifi, expensive: network?.expensive,
                constrained: network?.constrained))
        do {
            let url = try await reportUploader.upload(ledger: ledger, metadata: metadata,
                fallback: fallback.snapshot().map { DiagnosticReportFallback(timestamp: $0.timestamp, failure: $0.failure) })
            await trace(.diagnosticUpload, .succeeded, id: id, started: started)
            return url
        } catch {
            await trace(.diagnosticUpload, .failed, id: id, started: started, failure: ProviderSupport.safe(error, domain: .urlSession))
            throw error
        }
    }
}
