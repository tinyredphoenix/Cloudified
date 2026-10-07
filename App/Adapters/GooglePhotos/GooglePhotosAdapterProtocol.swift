import Foundation

/// Protocol placeholder for Google Photos upload transport and receipt management.
/// Reuses pinned PhotosBackup implementation in Phase 4 (Builder) with critical protocol review by Architect.
public protocol GooglePhotosAdapterProtocol: Sendable {
    /// Current authentication status with Google Photos.
    var isConnected: Bool { get }
}
