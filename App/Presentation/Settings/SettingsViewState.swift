import Foundation

/// Fallback policy for Google Photos Live Photo uploads when native pairing is unavailable.
public enum LivePhotoFallbackOption: String, CaseIterable, Identifiable, Sendable {
    case bothSeparately = "Both originals separately"
    case keyImageOnly = "Key image only"
    case motionVideoOnly = "Motion video only"

    public var id: String { rawValue }

    public var summaryDescription: String {
        switch self {
        case .bothSeparately:
            return "Recommended for preservation. Uploads both the high-resolution photo and full video component as separate original assets."
        case .keyImageOnly:
            return "Uploads only the high-resolution photo component. Motion video is omitted."
        case .motionVideoOnly:
            return "Uploads only the motion video component. Still photo is omitted."
        }
    }
}

/// State representation for the Settings screen.
public struct SettingsViewState: Equatable, Sendable {
    public var isGoogleEnabled: Bool
    public var isTelegramEnabled: Bool
    public var isWiFiOnlyEnabled: Bool
    public var livePhotoFallback: LivePhotoFallbackOption

    public var isGoogleConnected: Bool
    public var googleAccountEmail: String?

    public var isTelegramConnected: Bool
    public var telegramAccountName: String?
    public var telegramChannelName: String?

    public init(
        isGoogleEnabled: Bool = true,
        isTelegramEnabled: Bool = true,
        isWiFiOnlyEnabled: Bool = true,
        livePhotoFallback: LivePhotoFallbackOption = .bothSeparately,
        isGoogleConnected: Bool = false,
        googleAccountEmail: String? = nil,
        isTelegramConnected: Bool = false,
        telegramAccountName: String? = nil,
        telegramChannelName: String? = nil
    ) {
        self.isGoogleEnabled = isGoogleEnabled
        self.isTelegramEnabled = isTelegramEnabled
        self.isWiFiOnlyEnabled = isWiFiOnlyEnabled
        self.livePhotoFallback = livePhotoFallback
        self.isGoogleConnected = isGoogleConnected
        self.googleAccountEmail = googleAccountEmail
        self.isTelegramConnected = isTelegramConnected
        self.telegramAccountName = telegramAccountName
        self.telegramChannelName = telegramChannelName
    }
}
