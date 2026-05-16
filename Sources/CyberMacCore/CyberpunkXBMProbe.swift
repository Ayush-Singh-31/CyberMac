import Foundation

public enum CyberpunkXBMClassification: String, Sendable, Codable, Equatable {
    case missing
    case empty
    case textXBM = "text-xbm"
    case text
    case cyberpunkXBM = "cyberpunk-xbm"
    case unknownBinary = "unknown-binary"
}

public struct CyberpunkXBMCR2WTableEntry: Sendable, Codable, Equatable {
    public let index: Int
    public let offset: UInt32
    public let count: UInt32
    public let crc32: UInt32

    public init(index: Int, offset: UInt32, count: UInt32, crc32: UInt32) {
        self.index = index
        self.offset = offset
        self.count = count
        self.crc32 = crc32
    }
}

public struct CyberpunkXBMCR2WHeader: Sendable, Codable, Equatable {
    public let magicPresent: Bool
    public let version: UInt32?
    public let flags: UInt32?
    public let timestamp: UInt64?
    public let buildVersion: UInt32?
    public let fileSize: UInt32?
    public let bufferSize: UInt32?
    public let crc32: UInt32?
    public let numChunks: UInt32?
    public let tableEntries: [CyberpunkXBMCR2WTableEntry]

    public init(
        magicPresent: Bool,
        version: UInt32?,
        flags: UInt32?,
        timestamp: UInt64?,
        buildVersion: UInt32?,
        fileSize: UInt32?,
        bufferSize: UInt32?,
        crc32: UInt32?,
        numChunks: UInt32?,
        tableEntries: [CyberpunkXBMCR2WTableEntry]
    ) {
        self.magicPresent = magicPresent
        self.version = version
        self.flags = flags
        self.timestamp = timestamp
        self.buildVersion = buildVersion
        self.fileSize = fileSize
        self.bufferSize = bufferSize
        self.crc32 = crc32
        self.numChunks = numChunks
        self.tableEntries = tableEntries
    }
}

public struct CyberpunkXBMTextureInfo: Sendable, Codable, Equatable {
    public let width: Int?
    public let height: Int?
    public let mipCount: Int?
    public let textureFormat: String?
    public let textureCompression: String?
    public let cookingPlatform: String?
    public let embeddedDataOffset: UInt64?
    public let embeddedDataSize: UInt64?

    public init(
        width: Int? = nil,
        height: Int? = nil,
        mipCount: Int? = nil,
        textureFormat: String? = nil,
        textureCompression: String? = nil,
        cookingPlatform: String? = nil,
        embeddedDataOffset: UInt64? = nil,
        embeddedDataSize: UInt64? = nil
    ) {
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.textureFormat = textureFormat
        self.textureCompression = textureCompression
        self.cookingPlatform = cookingPlatform
        self.embeddedDataOffset = embeddedDataOffset
        self.embeddedDataSize = embeddedDataSize
    }

    public var isEmpty: Bool {
        width == nil && height == nil && mipCount == nil
            && textureFormat == nil && textureCompression == nil
            && cookingPlatform == nil
            && embeddedDataOffset == nil && embeddedDataSize == nil
    }
}

public struct CyberpunkXBMDecodeResult: Sendable, Codable, Equatable {
    public let path: String
    public let fileExists: Bool
    public let fileSize: UInt64
    public let firstBytesHex: String
    public let classification: CyberpunkXBMClassification
    public let isCyberpunkXBM: Bool
    public let cr2wHeader: CyberpunkXBMCR2WHeader?
    public let discoveredMarkers: [String]
    public let textureInfo: CyberpunkXBMTextureInfo?
    public let metadataDecoded: Bool
    public let notes: [String]

    public init(
        path: String,
        fileExists: Bool,
        fileSize: UInt64,
        firstBytesHex: String,
        classification: CyberpunkXBMClassification,
        isCyberpunkXBM: Bool,
        cr2wHeader: CyberpunkXBMCR2WHeader?,
        discoveredMarkers: [String],
        textureInfo: CyberpunkXBMTextureInfo?,
        metadataDecoded: Bool,
        notes: [String]
    ) {
        self.path = path
        self.fileExists = fileExists
        self.fileSize = fileSize
        self.firstBytesHex = firstBytesHex
        self.classification = classification
        self.isCyberpunkXBM = isCyberpunkXBM
        self.cr2wHeader = cr2wHeader
        self.discoveredMarkers = discoveredMarkers
        self.textureInfo = textureInfo
        self.metadataDecoded = metadataDecoded
        self.notes = notes
    }
}

public struct CyberpunkXBMProbe {
    public static let firstBytesPreviewLength = 64
    public static let cr2wMagicBytes: [UInt8] = [0x43, 0x52, 0x32, 0x57] // "CR2W"
    public static let knownTextureMarkers: [String] = [
        "CBitmapTexture",
        "CTextureArray",
        "ITexture",
        "rendRenderTextureResource",
        "rendRenderTextureBlobPC",
        "rendRenderTextureBlobMobile",
        "ETextureRawFormat",
        "ETextureCompression",
        "GpuWrapApieTextureGroup",
        "setup",
        "width",
        "height",
        "rawFormat",
        "rawGamma",
        "compression",
        "mipCount",
        "platform"
    ]

    public init() {}

    public func probe(fileURL: URL) throws -> CyberpunkXBMDecodeResult {
        let url = fileURL.standardizedFileURL
        let path = url.path

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("XBM probe file does not exist: \(path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("XBM probe path is a directory, not a file: \(path)")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CyberMacError.fileSystem("Unable to read XBM file: \(path): \(error)")
        }

        let fileSize = UInt64(data.count)
        let firstBytesHex = Self.hexString(of: data, limit: Self.firstBytesPreviewLength)

        if data.isEmpty {
            return CyberpunkXBMDecodeResult(
                path: path,
                fileExists: true,
                fileSize: fileSize,
                firstBytesHex: firstBytesHex,
                classification: .empty,
                isCyberpunkXBM: false,
                cr2wHeader: nil,
                discoveredMarkers: [],
                textureInfo: nil,
                metadataDecoded: false,
                notes: ["File is empty."]
            )
        }

        let magicPresent = Self.hasCR2WMagic(data: data)
        let isTextLooking = Self.looksLikeText(data: data)
        let looksLikeX11XBM = Self.looksLikeX11XBM(data: data)

        if magicPresent {
            let header = Self.parseCR2WHeader(data: data)
            let markers = Self.findKnownMarkers(in: data)
            let texture = Self.deriveTextureInfo(markers: markers)
            var notes: [String] = []
            notes.append("REDengine CR2W magic detected.")
            if let fileSizeField = header.fileSize {
                notes.append("CR2W fileSize field: \(fileSizeField) (on-disk size: \(fileSize))")
            }
            if texture == nil || (texture?.isEmpty ?? true) {
                notes.append("Metadata not decoded yet: width/height/format extraction requires full CR2W chunk parsing.")
            }
            return CyberpunkXBMDecodeResult(
                path: path,
                fileExists: true,
                fileSize: fileSize,
                firstBytesHex: firstBytesHex,
                classification: .cyberpunkXBM,
                isCyberpunkXBM: true,
                cr2wHeader: header,
                discoveredMarkers: markers,
                textureInfo: texture,
                metadataDecoded: !(texture?.isEmpty ?? true),
                notes: notes
            )
        }

        if looksLikeX11XBM {
            return CyberpunkXBMDecodeResult(
                path: path,
                fileExists: true,
                fileSize: fileSize,
                firstBytesHex: firstBytesHex,
                classification: .textXBM,
                isCyberpunkXBM: false,
                cr2wHeader: nil,
                discoveredMarkers: [],
                textureInfo: nil,
                metadataDecoded: false,
                notes: [
                    "Looks like an X11 bitmap (#define ...). This is NOT a Cyberpunk 2077 .xbm asset.",
                    "Cyberpunk .xbm files are REDengine CR2W binary assets, not X11 XBM."
                ]
            )
        }

        if isTextLooking {
            return CyberpunkXBMDecodeResult(
                path: path,
                fileExists: true,
                fileSize: fileSize,
                firstBytesHex: firstBytesHex,
                classification: .text,
                isCyberpunkXBM: false,
                cr2wHeader: nil,
                discoveredMarkers: [],
                textureInfo: nil,
                metadataDecoded: false,
                notes: ["File looks like text. Not a Cyberpunk CR2W .xbm asset."]
            )
        }

        return CyberpunkXBMDecodeResult(
            path: path,
            fileExists: true,
            fileSize: fileSize,
            firstBytesHex: firstBytesHex,
            classification: .unknownBinary,
            isCyberpunkXBM: false,
            cr2wHeader: nil,
            discoveredMarkers: [],
            textureInfo: nil,
            metadataDecoded: false,
            notes: ["Binary file without CR2W magic. Not recognised as Cyberpunk .xbm."]
        )
    }

    // MARK: - Parsing helpers

    static func hexString(of data: Data, limit: Int) -> String {
        let slice = data.prefix(limit)
        return slice.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    static func hasCR2WMagic(data: Data) -> Bool {
        guard data.count >= cr2wMagicBytes.count else { return false }
        for (i, byte) in cr2wMagicBytes.enumerated() where data[data.startIndex + i] != byte {
            return false
        }
        return true
    }

    static func looksLikeText(data: Data) -> Bool {
        let sample = data.prefix(1024)
        guard !sample.isEmpty else { return false }
        var printable = 0
        for byte in sample {
            if byte == 0x00 { return false }
            if byte == 0x09 || byte == 0x0A || byte == 0x0D { printable += 1; continue }
            if byte >= 0x20 && byte < 0x7F { printable += 1 }
        }
        return Double(printable) / Double(sample.count) >= 0.95
    }

    static func looksLikeX11XBM(data: Data) -> Bool {
        let prefix = data.prefix(16)
        guard let text = String(data: Data(prefix), encoding: .utf8) else { return false }
        return text.hasPrefix("#define")
    }

    static func parseCR2WHeader(data: Data) -> CyberpunkXBMCR2WHeader {
        // Layout (WolvenKit-style CR2W header):
        //   0x00  u32  magic ("CR2W")
        //   0x04  u32  version
        //   0x08  u32  flags
        //   0x0C  u64  timestamp
        //   0x14  u32  buildVersion
        //   0x18  u32  fileSize
        //   0x1C  u32  bufferSize
        //   0x20  u32  crc32
        //   0x24  u32  numChunks
        //   0x28..  10 × { u32 offset, u32 count, u32 crc32 }  (120 bytes)
        let magicPresent = hasCR2WMagic(data: data)
        guard magicPresent, data.count >= 0x28 else {
            return CyberpunkXBMCR2WHeader(
                magicPresent: magicPresent,
                version: nil,
                flags: nil,
                timestamp: nil,
                buildVersion: nil,
                fileSize: nil,
                bufferSize: nil,
                crc32: nil,
                numChunks: nil,
                tableEntries: []
            )
        }

        let version = readU32LE(data, at: 0x04)
        let flags = readU32LE(data, at: 0x08)
        let timestamp = readU64LE(data, at: 0x0C)
        let buildVersion = readU32LE(data, at: 0x14)
        let fileSize = readU32LE(data, at: 0x18)
        let bufferSize = readU32LE(data, at: 0x1C)
        let crc32 = readU32LE(data, at: 0x20)
        let numChunks = readU32LE(data, at: 0x24)

        var entries: [CyberpunkXBMCR2WTableEntry] = []
        let tableBase = 0x28
        let entrySize = 12
        let maxEntries = 10
        if data.count >= tableBase + entrySize * maxEntries {
            for i in 0..<maxEntries {
                let base = tableBase + i * entrySize
                guard
                    let offset = readU32LE(data, at: base),
                    let count = readU32LE(data, at: base + 4),
                    let crc = readU32LE(data, at: base + 8)
                else { continue }
                entries.append(CyberpunkXBMCR2WTableEntry(
                    index: i,
                    offset: offset,
                    count: count,
                    crc32: crc
                ))
            }
        }

        return CyberpunkXBMCR2WHeader(
            magicPresent: true,
            version: version,
            flags: flags,
            timestamp: timestamp,
            buildVersion: buildVersion,
            fileSize: fileSize,
            bufferSize: bufferSize,
            crc32: crc32,
            numChunks: numChunks,
            tableEntries: entries
        )
    }

    static func findKnownMarkers(in data: Data) -> [String] {
        var found: [String] = []
        for marker in knownTextureMarkers {
            let needle = Data(marker.utf8)
            if data.range(of: needle) != nil {
                found.append(marker)
            }
        }
        return found
    }

    static func deriveTextureInfo(markers: [String]) -> CyberpunkXBMTextureInfo? {
        // Spike: we can confirm presence of texture-related fields by string match,
        // but we cannot reliably decode the typed property values yet.
        // Returning an empty TextureInfo signals "structure recognised, values not decoded".
        guard !markers.isEmpty else { return nil }
        return CyberpunkXBMTextureInfo()
    }

    static func readU32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count >= offset + 4 else { return nil }
        let start = data.startIndex + offset
        let b0 = UInt32(data[start])
        let b1 = UInt32(data[start + 1])
        let b2 = UInt32(data[start + 2])
        let b3 = UInt32(data[start + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    static func readU64LE(_ data: Data, at offset: Int) -> UInt64? {
        guard offset >= 0, data.count >= offset + 8 else { return nil }
        let lo = UInt64(readU32LE(data, at: offset) ?? 0)
        let hi = UInt64(readU32LE(data, at: offset + 4) ?? 0)
        return lo | (hi << 32)
    }
}

public enum CyberpunkXBMProbeFormatter {
    public static func format(_ result: CyberpunkXBMDecodeResult) -> String {
        var lines = [
            "Cyberpunk XBM probe",
            "Path: \(PathSafety.redactUserPath(result.path))",
            "File size: \(result.fileSize) bytes",
            "Classification: \(result.classification.rawValue)",
            "Is Cyberpunk XBM: \(result.isCyberpunkXBM ? "yes" : "no")",
            "Metadata decoded: \(result.metadataDecoded ? "yes" : "no")",
            "First \(CyberpunkXBMProbe.firstBytesPreviewLength) bytes (hex):",
            "  \(result.firstBytesHex.isEmpty ? "(none)" : result.firstBytesHex)"
        ]

        if let header = result.cr2wHeader {
            lines.append("")
            lines.append("CR2W header:")
            lines.append("  Magic present: \(header.magicPresent ? "yes" : "no")")
            if let value = header.version { lines.append("  Version: \(value)") }
            if let value = header.flags { lines.append("  Flags: 0x\(String(value, radix: 16))") }
            if let value = header.timestamp { lines.append("  Timestamp: \(value)") }
            if let value = header.buildVersion { lines.append("  Build version: \(value)") }
            if let value = header.fileSize { lines.append("  File size (header): \(value)") }
            if let value = header.bufferSize { lines.append("  Buffer size (header): \(value)") }
            if let value = header.crc32 { lines.append("  CRC32: 0x\(String(value, radix: 16))") }
            if let value = header.numChunks { lines.append("  Chunk count: \(value)") }
            if !header.tableEntries.isEmpty {
                lines.append("  Table entries (offset, count, crc32):")
                for entry in header.tableEntries {
                    lines.append("    [\(entry.index)] offset=\(entry.offset) count=\(entry.count) crc32=0x\(String(entry.crc32, radix: 16))")
                }
            }
        }

        if !result.discoveredMarkers.isEmpty {
            lines.append("")
            lines.append("Discovered markers:")
            for marker in result.discoveredMarkers {
                lines.append("  - \(marker)")
            }
        }

        if let texture = result.textureInfo, !texture.isEmpty {
            lines.append("")
            lines.append("Texture info:")
            if let value = texture.width { lines.append("  Width: \(value)") }
            if let value = texture.height { lines.append("  Height: \(value)") }
            if let value = texture.mipCount { lines.append("  Mip count: \(value)") }
            if let value = texture.textureFormat { lines.append("  Format: \(value)") }
            if let value = texture.textureCompression { lines.append("  Compression: \(value)") }
            if let value = texture.cookingPlatform { lines.append("  Cooking platform: \(value)") }
            if let value = texture.embeddedDataOffset { lines.append("  Embedded data offset: \(value)") }
            if let value = texture.embeddedDataSize { lines.append("  Embedded data size: \(value)") }
        }

        if !result.notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            for note in result.notes {
                lines.append("  - \(note)")
            }
        }

        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ result: CyberpunkXBMDecodeResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
