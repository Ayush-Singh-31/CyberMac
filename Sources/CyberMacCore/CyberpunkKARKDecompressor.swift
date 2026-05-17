import Foundation

/// Decompresses a Cyberpunk 2077 KARK-wrapped Kraken payload using
/// `CyberpunkKrakenLibrary`. KARK is an 8-byte header CD Projekt RED prepends
/// to Kraken-compressed buffers in CR2W files:
///
///   bytes  0..3  : ASCII "KARK" (0x4B 0x41 0x52 0x4B)
///   bytes  4..7  : decompressed size (uint32 little-endian)
///   bytes  8..   : raw Kraken stream
public enum CyberpunkKARKDecompressor {
    public static let magicASCII = "KARK"
    public static let magicBytes: [UInt8] = [0x4B, 0x41, 0x52, 0x4B]
    public static let headerSize = 8

    public struct Header: Equatable, Sendable {
        public let decompressedSize: UInt32

        public init(decompressedSize: UInt32) {
            self.decompressedSize = decompressedSize
        }
    }

    public struct DecompressionResult: Sendable {
        public let header: Header
        public let decompressed: Data
        public let compressedByteCount: Int

        public init(header: Header, decompressed: Data, compressedByteCount: Int) {
            self.header = header
            self.decompressed = decompressed
            self.compressedByteCount = compressedByteCount
        }
    }

    public static func payloadHasKARKMagic(_ payload: Data) -> Bool {
        guard payload.count >= 4 else { return false }
        let start = payload.startIndex
        return payload[start] == magicBytes[0]
            && payload[start + 1] == magicBytes[1]
            && payload[start + 2] == magicBytes[2]
            && payload[start + 3] == magicBytes[3]
    }

    public static func parseHeader(_ payload: Data) throws -> Header {
        guard payload.count >= headerSize else {
            throw CyberMacError.invalidInput(
                "KARK payload too small for header: have \(payload.count), need \(headerSize)."
            )
        }
        guard payloadHasKARKMagic(payload) else {
            let start = payload.startIndex
            let head = payload[start..<(start + min(4, payload.count))]
                .map { String(format: "%02x", $0) }
                .joined(separator: " ")
            throw CyberMacError.invalidInput(
                "Payload does not start with 'KARK' magic; got bytes \(head)."
            )
        }
        let start = payload.startIndex
        let size = UInt32(payload[start + 4])
                 | (UInt32(payload[start + 5]) << 8)
                 | (UInt32(payload[start + 6]) << 16)
                 | (UInt32(payload[start + 7]) << 24)
        return Header(decompressedSize: size)
    }

    /// Splits the payload into header + compressed Kraken stream and runs
    /// `Kraken_Decompress` into a buffer sized by the header.
    ///
    /// - Parameter minimumDecompressedSize: optional caller-side floor — if the
    ///   header reports a smaller decompressed size than this, the call fails
    ///   loudly rather than truncating. Useful when the caller knows the BC3
    ///   top-mip byte count and wants to be sure the buffer is big enough.
    public static func decompress(
        payload: Data,
        library: CyberpunkKrakenLibrary,
        minimumDecompressedSize: Int? = nil
    ) throws -> DecompressionResult {
        let header = try parseHeader(payload)
        let dstCapacity = Int(header.decompressedSize)
        guard dstCapacity > 0 else {
            throw CyberMacError.fileSystem(
                "KARK header reports decompressed size of 0 bytes; refusing to call Kraken_Decompress."
            )
        }
        if let floor = minimumDecompressedSize, dstCapacity < floor {
            throw CyberMacError.fileSystem(
                "KARK header decompressed size (\(dstCapacity)) is smaller than the caller's required minimum (\(floor))."
            )
        }

        let compressedStart = payload.startIndex + headerSize
        let compressed = payload.subdata(in: compressedStart..<payload.endIndex)
        guard !compressed.isEmpty else {
            throw CyberMacError.fileSystem(
                "KARK payload has no compressed bytes after the 8-byte header (payload size=\(payload.count))."
            )
        }

        let decompressed = try library.decompress(
            source: compressed,
            destinationCapacity: dstCapacity
        )

        return DecompressionResult(
            header: header,
            decompressed: decompressed,
            compressedByteCount: compressed.count
        )
    }
}
