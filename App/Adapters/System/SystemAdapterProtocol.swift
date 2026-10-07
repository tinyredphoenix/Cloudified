import Foundation

/// Protocol placeholder for network path monitoring, Keychain access, and iOS background task coordination.
/// Detailed implementation is assigned in Phase 3/6 (Builder) and reviewed by Architect.
public protocol SystemAdapterProtocol: Sendable {
    /// True if the device is currently connected to an unmetered Wi-Fi network.
    var isWiFiAvailable: Bool { get }
}
