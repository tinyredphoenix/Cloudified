import Foundation

/// Protocol placeholder for PhotoKit library enumeration, resource export, and hashing.
/// Detailed implementation is assigned in Phase 3 (Builder) and reviewed by Architect.
public protocol PhotoLibraryAdapterProtocol: Sendable {
    /// Discovers accessible photo and video assets in the user's photo library.
    func scanLibrary() async throws -> Int
}
