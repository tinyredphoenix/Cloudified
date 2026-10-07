import Foundation
import CryptoKit
import CloudifiedCore

/// Dual streaming hasher and bounded chunk file writer.
/// Computes SHA-256 and SHA-1 in a single pass without loading whole media into memory.
public final class StreamingFileWriter {
    private let fileURL: URL
    private let fileHandle: FileHandle
    private var sha256Hasher = SHA256()
    private var sha1Hasher = Insecure.SHA1()
    private var totalBytesWritten: Int64 = 0
    private var isClosed = false

    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        // Create empty file at path if not existing
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        do {
            self.fileHandle = try FileHandle(forWritingTo: fileURL)
        } catch {
            throw SafeFailure(.sourceUnavailable, domain: .fileSystem, code: (error as NSError).code, cause: .sourceMissing)
        }
    }

    /// Appends a chunk of bytes to the file and updates SHA-256 and SHA-1 hashes.
    public func write(chunk: Data) throws {
        guard !isClosed else {
            throw SafeFailure(.invariant, domain: .fileSystem, cause: .invalidContract)
        }
        guard !chunk.isEmpty else { return }

        do {
            try fileHandle.write(contentsOf: chunk)
            sha256Hasher.update(data: chunk)
            sha1Hasher.update(data: chunk)
            totalBytesWritten += Int64(chunk.count)
        } catch {
            throw SafeFailure(.diskFull, domain: .fileSystem, code: (error as NSError).code, cause: .insufficientSpace)
        }
    }

    /// Closes the file handle and finalizes the measured digest result.
    public func finalize() throws -> (sha256: String, sha1: String, byteCount: Int64) {
        guard !isClosed else {
            throw SafeFailure(.invariant, domain: .fileSystem, cause: .invalidContract)
        }
        isClosed = true

        do {
            try fileHandle.synchronize()
            try fileHandle.close()
        } catch {
            throw SafeFailure(.diskFull, domain: .fileSystem, code: (error as NSError).code, cause: .insufficientSpace)
        }

        let sha256Hex = sha256Hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let sha1Hex = sha1Hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (sha256Hex, sha1Hex, totalBytesWritten)
    }

    /// Aborts writing and closes the file handle.
    public func abort() {
        guard !isClosed else { return }
        isClosed = true
        try? fileHandle.close()
    }

    deinit {
        if !isClosed {
            try? fileHandle.close()
        }
    }
}

/// Helper for streaming hashing of existing on-disk files.
public enum StreamingFileHasher {
    public static func hash(fileURL: URL, chunkSize: Int = 1_048_576) throws -> (sha256: String, sha1: String, byteCount: Int64) {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var sha256 = SHA256()
        var sha1 = Insecure.SHA1()
        var totalBytes: Int64 = 0

        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            sha256.update(data: chunk)
            sha1.update(data: chunk)
            totalBytes += Int64(chunk.count)
        }

        let sha256Hex = sha256.finalize().map { String(format: "%02x", $0) }.joined()
        let sha1Hex = sha1.finalize().map { String(format: "%02x", $0) }.joined()
        return (sha256Hex, sha1Hex, totalBytes)
    }
}
