import Foundation
import CryptoKit
import CloudifiedCore

/// Deterministic lossless video part calculation and on-demand streaming extraction.
public enum LosslessVideoPartSplitter {
    /// Conservative 1.9 billion bytes; P4 still verifies actual TDLib limits.
    public static let defaultTargetPartSize: Int64 = 1_900_000_000

    /// Generates a deterministic split recipe for a master video file with exact measured hashes.
    public static func planSplit(
        fileURL: URL,
        totalBytes: Int64,
        role: ResourceRole = .video,
        originalSha256: String? = nil,
        targetPartSize: Int64 = defaultTargetPartSize,
        chunkSize: Int = 1_048_576
    ) throws -> VideoSplitRecipe {
        guard totalBytes > 0, targetPartSize > 0, (1...1_048_576).contains(chunkSize) else {
            throw CoreError.invalidContract
        }
        let sizeHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? sizeHandle.close() }
        guard try sizeHandle.seekToEnd() == UInt64(totalBytes) else { throw CoreError.invalidContract }

        guard totalBytes > targetPartSize else {
            // No split required
            let hashes = try StreamingFileHasher.hash(fileURL: fileURL, chunkSize: chunkSize)
            let single = VideoPartDescriptor(
                role: role,
                partIndex: 0,
                partCount: 1,
                offset: 0,
                byteCount: totalBytes,
                sha256: hashes.sha256,
                sha1: hashes.sha1
            )
            return VideoSplitRecipe(
                role: role,
                originalSha256: originalSha256 ?? hashes.sha256,
                targetPartSize: targetPartSize,
                totalByteCount: totalBytes,
                parts: [single]
            )
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var parts: [VideoPartDescriptor] = []
        let count = totalBytes / targetPartSize + (totalBytes % targetPartSize == 0 ? 0 : 1)
        guard count <= 255 else { throw SafeFailure(.unsupportedOriginal, domain: .core, cause: .formatRejected) }
        let partCount = Int(count)

        for i in 0..<partCount {
            try Task.checkCancellation()
            let offset = Int64(i) * targetPartSize
            let length = min(targetPartSize, totalBytes - offset)

            try handle.seek(toOffset: UInt64(offset))
            var sha256 = SHA256()
            var sha1 = Insecure.SHA1()
            var remaining = length

            while remaining > 0 {
                try Task.checkCancellation()
                let toRead = min(Int(remaining), chunkSize)
                let chunk = try handle.read(upToCount: toRead) ?? Data()
                guard !chunk.isEmpty else { throw SafeFailure(.transfer, domain: .fileSystem, cause: .contentChanged) }
                sha256.update(data: chunk)
                sha1.update(data: chunk)
                remaining -= Int64(chunk.count)
            }

            let sha256Hex = sha256.finalize().map { String(format: "%02x", $0) }.joined()
            let sha1Hex = sha1.finalize().map { String(format: "%02x", $0) }.joined()

            parts.append(VideoPartDescriptor(
                role: role,
                partIndex: i,
                partCount: partCount,
                offset: offset,
                byteCount: length,
                sha256: sha256Hex,
                sha1: sha1Hex
            ))
        }

        return VideoSplitRecipe(
            role: role,
            originalSha256: originalSha256 ?? "",
            targetPartSize: targetPartSize,
            totalByteCount: totalBytes,
            parts: parts
        )
    }

    /// Extracts a single part slice from a master video file to a destination partial file.
    public static func extractPart(
        from sourceURL: URL,
        descriptor: VideoPartDescriptor,
        to destinationURL: URL,
        chunkSize: Int = 1_048_576,
        beforeWrite: (@Sendable (Int64) throws -> Void)? = nil
    ) throws -> (sha256: String, sha1: String, byteCount: Int64) {
        guard descriptor.offset >= 0, descriptor.byteCount > 0,
              descriptor.partCount > 0, (0..<descriptor.partCount).contains(descriptor.partIndex),
              (1...1_048_576).contains(chunkSize) else { throw CoreError.invalidContract }
        let handle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? handle.close() }

        try handle.seek(toOffset: UInt64(descriptor.offset))

        let writer = try StreamingFileWriter(fileURL: destinationURL, beforeWrite: beforeWrite)
        defer { writer.abort() }
        var remaining = descriptor.byteCount

        while remaining > 0 {
            try Task.checkCancellation()
            let toRead = min(Int(remaining), chunkSize)
            let chunk = try handle.read(upToCount: toRead) ?? Data()
            guard !chunk.isEmpty else { throw SafeFailure(.transfer, domain: .fileSystem, cause: .contentChanged) }
            try writer.write(chunk: chunk)
            remaining -= Int64(chunk.count)
        }

        let result = try writer.finalize()

        guard result.byteCount == descriptor.byteCount,
              result.sha256 == descriptor.sha256,
              result.sha1 == descriptor.sha1 else {
            throw SafeFailure(.invariant, domain: .fileSystem, cause: .contentChanged)
        }

        return result
    }
}
