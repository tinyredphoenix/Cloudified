import Foundation

/// Filter options for provider destination in Not Uploaded screen.
public enum DestinationFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case google = "Google Photos"
    case telegram = "Telegram"

    public var id: String { rawValue }
}

/// Filter options for media type.
public enum MediaTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"

    public var id: String { rawValue }
}

/// Filter options for upload failure status.
public enum FailureStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case failed = "Failed"
    case waiting = "Waiting"
    case pending = "Pending"
    case all = "All"

    public var id: String { rawValue }
}

/// Detailed record representing an asset that is failed, waiting, or pending.
public struct NotUploadedItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let jobID: UUID?
    public let localIdentifier: String
    public let filename: String
    public let captureDate: Date
    public let mediaType: String
    public let durationSeconds: TimeInterval?
    public let provider: String
    public let status: String
    public let attemptCount: Int
    public let maxAttempts: Int
    public let stage: String
    public let errorCategory: String
    public let technicalCode: String?
    public let plainLanguageReason: String
    public let suggestedRemedy: String?
    public let confirmedComponents: [String]
    public let missingObligations: [String]
    public let nextRetryDate: Date?

    public init(
        id: String,
        jobID: UUID? = nil,
        localIdentifier: String = "",
        filename: String,
        captureDate: Date,
        mediaType: String,
        durationSeconds: TimeInterval? = nil,
        provider: String,
        status: String = "Failed",
        attemptCount: Int = 3,
        maxAttempts: Int = 3,
        stage: String = "Transfer",
        errorCategory: String = "Network error",
        technicalCode: String? = nil,
        plainLanguageReason: String,
        suggestedRemedy: String? = nil,
        confirmedComponents: [String] = [],
        missingObligations: [String] = [],
        nextRetryDate: Date? = nil
    ) {
        self.id = id
        self.jobID = jobID
        self.localIdentifier = localIdentifier
        self.filename = filename
        self.captureDate = captureDate
        self.mediaType = mediaType
        self.durationSeconds = durationSeconds
        self.provider = provider
        self.status = status
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.stage = stage
        self.errorCategory = errorCategory
        self.technicalCode = technicalCode
        self.plainLanguageReason = plainLanguageReason
        self.suggestedRemedy = suggestedRemedy
        self.confirmedComponents = confirmedComponents
        self.missingObligations = missingObligations
        self.nextRetryDate = nextRetryDate
    }


    public var attemptText: String {
        return "\(attemptCount)/\(maxAttempts)"
    }
}

/// State representation for Not Uploaded screen.
public struct NotUploadedViewState: Equatable, Sendable {
    public var destinationFilter: DestinationFilter
    public var mediaTypeFilter: MediaTypeFilter
    public var statusFilter: FailureStatusFilter
    public var items: [NotUploadedItem]

    public init(
        destinationFilter: DestinationFilter = .all,
        mediaTypeFilter: MediaTypeFilter = .all,
        statusFilter: FailureStatusFilter = .failed,
        items: [NotUploadedItem] = []
    ) {
        self.destinationFilter = destinationFilter
        self.mediaTypeFilter = mediaTypeFilter
        self.statusFilter = statusFilter
        self.items = items
    }

    public var filteredItems: [NotUploadedItem] {
        return items.filter { item in
            // Filter by provider
            switch destinationFilter {
            case .all:
                break
            case .google:
                guard item.provider.localizedCaseInsensitiveContains("Google") else { return false }
            case .telegram:
                guard item.provider.localizedCaseInsensitiveContains("Telegram") else { return false }
            }

            // Filter by media type
            switch mediaTypeFilter {
            case .all:
                break
            case .photos:
                guard item.mediaType.localizedCaseInsensitiveContains("Photo") else { return false }
            case .videos:
                guard item.mediaType.localizedCaseInsensitiveContains("Video") else { return false }
            }

            // Filter by status
            switch statusFilter {
            case .all:
                break
            case .failed:
                guard item.status.localizedCaseInsensitiveContains("Fail") else { return false }
            case .waiting:
                guard item.status.localizedCaseInsensitiveContains("Wait") else { return false }
            case .pending:
                guard item.status.localizedCaseInsensitiveContains("Pend") else { return false }
            }

            return true
        }
    }
}
