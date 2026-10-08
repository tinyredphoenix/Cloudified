import Foundation

public enum EventOrigin: String, Codable, Sendable { case google, telegram, source, system }
public enum EventSeverity: String, Codable, Sendable { case info, warning, error }
public enum EventOperation: String, Codable, Sendable {
    case appStart, scanStart, scanPage, scanComplete, batchStart, batchEnd, pause, resume
    case mappingChanged, enabledChanged, recovery, remoteCheck, preparation, export, hashing
    case laneStart, laneEnd, attemptStart, transferStart, progress, finalization, confirmation
    case failure, retryScheduled, exhausted, explicitRetry, network, backgroundExpiration
    case leaseAcquire, leaseRelease, cleanup, databaseFailure, diagnosticsPruned
}
public enum EventDecision: String, Codable, Sendable { case proceed, retry, wait, skip, reconcile, confirmed }
public enum FailureCategory: String, Codable, Sendable {
    case sourceUnavailable, accessDenied, diskFull, unsupportedOriginal, connectivity, timeout
    case rateLimit, authentication, quota, transfer, finalization, reconciliation, invariant
}
public enum ErrorDomain: String, Codable, Sendable { case photos, fileSystem, urlSession, google, tdlib, sqlite, core }
public enum KnownCause: String, Codable, Sendable {
    case unknown, permissionDenied, sourceMissing, insufficientSpace, formatRejected, offline
    case deadlineExceeded, serverRateLimit, loginRequired, quotaExceeded, providerRejected
    case incompleteHistory, outcomeUnknown, interrupted, disabled, paused, contentChanged
    case persistenceFailed, invalidContract, identityUnverified, pairingUnverified, pendingSendUnmatched
    case privateChannelRequired, accountChanged
    case lowDataMode, wifiRequired, thermalPressure, backgroundRestricted, backgroundExpired
    case storageUnavailable, storagePathConflict
}

/// Whitelisted values only. Never put raw response text, credentials, account names,
/// filenames, local paths, GPS, phone numbers or opaque receipts in diagnostic fields.
public struct SafeFailure: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    public let category: FailureCategory
    public let domain: ErrorDomain
    public let code: Int?
    public let cause: KnownCause
    public init(_ category: FailureCategory, domain: ErrorDomain, code: Int? = nil, cause: KnownCause = .unknown) {
        self.category = category; self.domain = domain; self.code = code; self.cause = cause
    }
    /// Only closed enums and a numeric code; never raw NSError/userInfo prose.
    public var description: String {
        "\(category.rawValue)/\(domain.rawValue)/\(cause.rawValue)" + (code.map { " (\($0))" } ?? "")
    }
}

public struct EventContext: Codable, Sendable {
    public let runID: UUID?
    public let origin: EventOrigin
    public let destinationID: UUID?
    public let jobID: UUID?
    public let assetID: UUID?
    public let resourceID: UUID?
    public let cycleID: UUID?
    public let attempt: Int?
    public init(runID: UUID? = nil, origin: EventOrigin = .system, destinationID: UUID? = nil,
                jobID: UUID? = nil, assetID: UUID? = nil, resourceID: UUID? = nil,
                cycleID: UUID? = nil, attempt: Int? = nil) {
        self.runID = runID; self.origin = origin; self.destinationID = destinationID
        self.jobID = jobID; self.assetID = assetID; self.resourceID = resourceID
        self.cycleID = cycleID; self.attempt = attempt
    }
}

public struct DiagnosticEvent: Codable, Sendable {
    public let sequence: Int64
    public let timestamp: Date
    public let version: String
    public let revision: String
    public let context: EventContext
    public let operation: EventOperation
    public let severity: EventSeverity
    public let decision: EventDecision
    public let fromState: String?
    public let toState: String?
    public let failure: SafeFailure?
    public let duration: TimeInterval?
    public let bytes: Int64?
    public let expectedBytes: Int64?
    public let part: Int?
    public init(sequence: Int64, timestamp: Date, version: String, revision: String,
                context: EventContext, operation: EventOperation, severity: EventSeverity,
                decision: EventDecision, fromState: String? = nil, toState: String? = nil,
                failure: SafeFailure? = nil, duration: TimeInterval? = nil, bytes: Int64? = nil,
                expectedBytes: Int64? = nil, part: Int? = nil) {
        self.sequence = sequence; self.timestamp = timestamp; self.version = version; self.revision = revision
        self.context = context; self.operation = operation; self.severity = severity; self.decision = decision
        self.fromState = fromState; self.toState = toState; self.failure = failure; self.duration = duration
        self.bytes = bytes; self.expectedBytes = expectedBytes; self.part = part
    }
}
