import Foundation
import CryptoKit
import CloudifiedCore

/// Deterministic lossless video part calculation and on-demand streaming extraction.
public enum LosslessVideoPartSplitter {
    /// Safe default target part size (1,950 MiB), safely below Telegram's 2,000 MiB limit.
    public static let defaultTargetPartSize: Int64 = 1_950 * 1024 * 1024

    /// Generates a deterministic split recipe for a master video file.
    public static func planSplit(
        fileURL: URL,
        totalBytes: Int64,
        targetPartSize: Int64 = defaultTargetPartSize,
        chunkSize: Int = 1_048_576
    ) throws -> VideoSplitRecipe {
        guard totalBytes > targetPartSize else {
            // No split required
            let hashes = try StreamingFileHasher.hash(fileURL: fileURL, chunkSize: chunkSize)
            let single = VideoPartDescriptor(
                partIndex: 0,
                partCount: 1,
                offset: 0,
                byteCount: totalBytes,
                sha256: hashes.sha256,
                sha1: hashes.sha1
            )
            return VideoSplitRecipe(targetPartSize: targetPartSize, totalByteCount: totalBytes, parts: [single])
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var parts: [VideoPartDescriptor] = []
        let partCount = Int((totalBytes + targetPartSize - 1) / targetPartSize)

        for i in 0..<partCount {
            let offset = Int64(i) * targetPartSize
            let length = min(targetPartSize, totalBytes - offset)

            try handle.seek(toOffset: UInt64(offset))
            var sha256 = SHA256()
            var sha1 = Insecure.SHA1()
            var remaining = length

            while remaining > 0 {
                let toRead = min(Int(remaining), chunkSize)
                let chunk = try handle.read(upToCount: toRead) ?? Data()
                if chunk.isEmpty { break }
                sha256.update(data: chunk)
                sha1.update(data: chunk)
                remaining -= Int64(chunk.count)
            }

            let sha256Hex = sha256.finalize().map { String(format: "%02x", $0) }.joined()
            let sha1Hex = sha1.finalize().map { String(format: "%02x", $0) }.joined()

            parts.append(VideoPartDescriptor(
                partIndex: i,
                partCount: partCount,
                offset: offset,
                byteCount: length,
                sha256: sha256Hex,
                sha1: sha1Hex
            ))
        }

        return VideoSplitRecipe(targetPartSize: targetPartSize, totalByteCount: totalBytes, parts: parts)
    }

    /// Extracts a single part slice from a master video file to a destination partial file.
    public static func extractPart(
        from sourceURL: URL,
        descriptor: VideoPartDescriptor,
        to destinationURL: URL,
        chunkSize: Int = 1_048_576
    ) throws -> (sha256: String, sha1: String, byteCount: Int64) {
        let handle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? handle.close() }

        try handle.seek(toOffset: UInt64(descriptor.offset))

        let writer = try StreamingFileWriter(fileURL: destinationURL)
        var remaining = descriptor.byteCount

        while remaining > 0 {
            let toRead = min(Int(remaining), chunkSize)
            let chunk = try handle.read(upToCount: toRead) ?? Data()
            if chunk.isEmpty { break }
            try writer.write(chunk: chunk)
            remaining -= Int64(chunk.count)
        }

        let result = try writer.finalize()

        guard result.byteCount == descriptor.byteCount,
              result.sha256 == descriptor.sha256,
              result.sha1 == descriptor.sha1 else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw SafeFailure(.invariant, domain: .fileSystem, cause: .contentChanged)
        }

        return result
    }
}
