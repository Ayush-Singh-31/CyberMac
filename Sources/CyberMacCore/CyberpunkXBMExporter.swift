import Foundation

// MARK: - Compression mapping

public enum CyberpunkXBMCompression: String, Sendable, Codable, Equatable {
    case none = "TCM_None"
    case dxtAlpha = "TCM_DXTAlpha"           // BC3 / DXT5
    case dxtNoAlpha = "TCM_DXTNoAlpha"       // BC1 / DXT1
    case qualityColor = "TCM_QualityColor"   // BC7
    case qualityR = "TCM_QualityR"           // BC4
    case normals = "TCM_Normals"             // BC5
    case normalsHigh = "TCM_NormalsHigh"     // BC5
    case normalsGloss = "TCM_NormalsGloss"   // BC5
    case alphaCompressed = "TCM_AlphaCompressed" // BC4
    case unknown

    public init(rawName: String?) {
        guard let raw = rawName, let value = CyberpunkXBMCompression(rawValue: raw) else {
            self = .unknown
            return
        }
        self = value
    }

    public var decoderName: String? {
        switch self {
        case .dxtAlpha: return "BC3"
        case .dxtNoAlpha: return "BC1"
        default: return nil
        }
    }
}

// MARK: - Metadata recovered from CBitmapTexture chunk

public struct CyberpunkXBMTextureMetadata: Sendable, Codable, Equatable {
    public enum Confidence: String, Sendable, Codable {
        case exact      // structured property record decoded cleanly
        case inferred   // heuristic / payload-math fallback
        case unknown
    }

    public let width: UInt32?
    public let height: UInt32?
    public let mipCount: UInt32?
    public let compressionName: String?
    public let compression: CyberpunkXBMCompression
    public let textureGroup: String?
    public let isStreamable: Bool?
    public let hasMipchain: Bool?
    public let isGamma: Bool?
    public let widthConfidence: Confidence
    public let heightConfidence: Confidence
    public let mipCountConfidence: Confidence
    public let compressionConfidence: Confidence

    public init(
        width: UInt32?,
        height: UInt32?,
        mipCount: UInt32?,
        compressionName: String?,
        compression: CyberpunkXBMCompression,
        textureGroup: String?,
        widthConfidence: Confidence,
        heightConfidence: Confidence,
        mipCountConfidence: Confidence,
        compressionConfidence: Confidence,
        isStreamable: Bool? = nil,
        hasMipchain: Bool? = nil,
        isGamma: Bool? = nil
    ) {
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.compressionName = compressionName
        self.compression = compression
        self.textureGroup = textureGroup
        self.isStreamable = isStreamable
        self.hasMipchain = hasMipchain
        self.isGamma = isGamma
        self.widthConfidence = widthConfidence
        self.heightConfidence = heightConfidence
        self.mipCountConfidence = mipCountConfidence
        self.compressionConfidence = compressionConfidence
    }
}

// MARK: - Export options & result

public struct CyberpunkXBMExportOptions: Sendable {
    public let outputURL: URL
    public let debug: Bool
    public let register: Bool
    public let archivePath: String?
    public let assetPath: String?
    public let databaseURL: URL?
    public let sourceTool: String

    public static let defaultSourceTool = "cybermac-xbm-preview-export"

    public init(
        outputURL: URL,
        debug: Bool = false,
        register: Bool = false,
        archivePath: String? = nil,
        assetPath: String? = nil,
        databaseURL: URL? = nil,
        sourceTool: String = CyberpunkXBMExportOptions.defaultSourceTool
    ) {
        self.outputURL = outputURL
        self.debug = debug
        self.register = register
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.databaseURL = databaseURL
        self.sourceTool = sourceTool
    }
}

public struct CyberpunkXBMExportResult: Sendable {
    public let inputPath: String
    public let outputPath: String
    public let width: UInt32
    public let height: UInt32
    public let mipCount: UInt32?
    public let compressionName: String?
    public let decoderUsed: String
    public let payloadOffset: UInt64
    public let payloadSize: UInt64
    public let topMipBytesDecoded: UInt64
    public let registered: Bool
    public let registerReport: AssetPreviewRegisterReport?
    public let metadata: CyberpunkXBMTextureMetadata
    public let debugNotes: [String]

    public init(
        inputPath: String,
        outputPath: String,
        width: UInt32,
        height: UInt32,
        mipCount: UInt32?,
        compressionName: String?,
        decoderUsed: String,
        payloadOffset: UInt64,
        payloadSize: UInt64,
        topMipBytesDecoded: UInt64,
        registered: Bool,
        registerReport: AssetPreviewRegisterReport?,
        metadata: CyberpunkXBMTextureMetadata,
        debugNotes: [String]
    ) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.compressionName = compressionName
        self.decoderUsed = decoderUsed
        self.payloadOffset = payloadOffset
        self.payloadSize = payloadSize
        self.topMipBytesDecoded = topMipBytesDecoded
        self.registered = registered
        self.registerReport = registerReport
        self.metadata = metadata
        self.debugNotes = debugNotes
    }
}

public struct CyberpunkXBMExportFailure: Error, CustomStringConvertible {
    public let inputPath: String
    public let outputPath: String?
    public let detectedCompressionName: String?
    public let detectedCompression: CyberpunkXBMCompression
    public let metadata: CyberpunkXBMTextureMetadata?
    public let reason: String
    public let debugNotes: [String]

    public var description: String { reason }
}

// MARK: - Exporter

public struct CyberpunkXBMExporter {
    public init() {}

    public func export(fileURL: URL, options: CyberpunkXBMExportOptions) throws -> CyberpunkXBMExportResult {
        let inspection = try CyberpunkXBMInspector().inspect(fileURL: fileURL)
        var debugNotes: [String] = []

        guard inspection.isCyberpunkXBM else {
            throw CyberpunkXBMExportFailure(
                inputPath: inspection.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: nil,
                detectedCompression: .unknown,
                metadata: nil,
                reason: "Not a Cyberpunk CR2W .xbm asset (classification=\(inspection.probeClassification.rawValue)).",
                debugNotes: debugNotes
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw CyberMacError.fileSystem("Unable to read .xbm for export: \(fileURL.path): \(error)")
        }
        let reader = CyberpunkCR2WReader(data: data)

        let metadata = Self.recoverMetadata(
            reader: reader,
            inspection: inspection,
            debug: options.debug,
            debugNotes: &debugNotes
        )

        if options.debug {
            debugNotes.append("Recovered metadata: width=\(metadata.width.map(String.init) ?? "?")(\(metadata.widthConfidence.rawValue)) height=\(metadata.height.map(String.init) ?? "?")(\(metadata.heightConfidence.rawValue)) mipCount=\(metadata.mipCount.map(String.init) ?? "?")(\(metadata.mipCountConfidence.rawValue)) compression=\(metadata.compressionName ?? "?")(\(metadata.compressionConfidence.rawValue))")
        }

        guard let width = metadata.width, let height = metadata.height, width > 0, height > 0 else {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: metadata.compression,
                metadata: metadata,
                reason: "Could not recover width/height from CBitmapTexture chunk. Re-run with --debug for chunk dump.",
                debugNotes: debugNotes
            )
        }

        let compression = metadata.compression
        guard let decoderName = compression.decoderName else {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: compression,
                metadata: metadata,
                reason: "Unsupported compression: \(metadata.compressionName ?? "<unknown>"). This exporter currently handles only TCM_DXTAlpha (BC3) and TCM_DXTNoAlpha (BC1).",
                debugNotes: debugNotes
            )
        }

        guard let payloadRegion = inspection.candidatePayloadRegions.first(where: { $0.size > 0 }) else {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: compression,
                metadata: metadata,
                reason: "No candidate payload region detected.",
                debugNotes: debugNotes
            )
        }
        let payloadOffset = payloadRegion.offset
        let payloadSize = payloadRegion.size
        let payloadStart = Int(payloadOffset)
        let payloadEnd = payloadStart + Int(payloadSize)
        guard payloadEnd <= data.count else {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: compression,
                metadata: metadata,
                reason: "Payload region out of bounds: end=\(payloadEnd) > file=\(data.count).",
                debugNotes: debugNotes
            )
        }
        let payload = data.subdata(in: payloadStart..<payloadEnd)

        if options.debug {
            let head = payload.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " ")
            debugNotes.append("Payload offset=\(payloadOffset) size=\(payloadSize) first64=\(head)")
        }

        let blocksWide = (Int(width) + 3) / 4
        let blocksHigh = (Int(height) + 3) / 4
        let topMipBytes: Int
        let rgba: Data
        do {
            switch decoderName {
            case "BC3":
                topMipBytes = blocksWide * blocksHigh * CyberpunkXBMBC3Decoder.blockByteSize
                if options.debug {
                    debugNotes.append("BC3 top-mip math: \(blocksWide)x\(blocksHigh) blocks * 16 = \(topMipBytes) bytes; payload=\(payload.count)")
                }
                guard payload.count >= topMipBytes else {
                    throw CyberpunkXBMExportFailure(
                        inputPath: fileURL.path,
                        outputPath: options.outputURL.path,
                        detectedCompressionName: metadata.compressionName,
                        detectedCompression: compression,
                        metadata: metadata,
                        reason: "Payload smaller than uncompressed BC3 top mip (needed \(topMipBytes), have \(payload.count)). The buffer is probably compressed (zlib/oodle/kraken). This exporter doesn't decompress buffers yet.",
                        debugNotes: debugNotes
                    )
                }
                rgba = try CyberpunkXBMBC3Decoder.decode(
                    blockData: payload.prefix(topMipBytes),
                    width: Int(width),
                    height: Int(height)
                )
            case "BC1":
                topMipBytes = blocksWide * blocksHigh * CyberpunkXBMBC1Decoder.blockByteSize
                if options.debug {
                    debugNotes.append("BC1 top-mip math: \(blocksWide)x\(blocksHigh) blocks * 8 = \(topMipBytes) bytes; payload=\(payload.count)")
                }
                guard payload.count >= topMipBytes else {
                    throw CyberpunkXBMExportFailure(
                        inputPath: fileURL.path,
                        outputPath: options.outputURL.path,
                        detectedCompressionName: metadata.compressionName,
                        detectedCompression: compression,
                        metadata: metadata,
                        reason: "Payload smaller than uncompressed BC1 top mip (needed \(topMipBytes), have \(payload.count)). The buffer is probably compressed.",
                        debugNotes: debugNotes
                    )
                }
                rgba = try CyberpunkXBMBC1Decoder.decode(
                    blockData: payload.prefix(topMipBytes),
                    width: Int(width),
                    height: Int(height)
                )
            default:
                throw CyberpunkXBMExportFailure(
                    inputPath: fileURL.path,
                    outputPath: options.outputURL.path,
                    detectedCompressionName: metadata.compressionName,
                    detectedCompression: compression,
                    metadata: metadata,
                    reason: "Internal: decoder \(decoderName) not wired up.",
                    debugNotes: debugNotes
                )
            }
        } catch let failure as CyberpunkXBMExportFailure {
            throw failure
        } catch {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: compression,
                metadata: metadata,
                reason: "Block decode failed: \(error)",
                debugNotes: debugNotes
            )
        }

        do {
            try CyberpunkXBMPNGWriter.writePNG(
                rgba: rgba,
                width: Int(width),
                height: Int(height),
                to: options.outputURL
            )
        } catch {
            throw CyberpunkXBMExportFailure(
                inputPath: fileURL.path,
                outputPath: options.outputURL.path,
                detectedCompressionName: metadata.compressionName,
                detectedCompression: compression,
                metadata: metadata,
                reason: "PNG write failed: \(error)",
                debugNotes: debugNotes
            )
        }

        var registerReport: AssetPreviewRegisterReport?
        if options.register {
            guard let archivePath = options.archivePath, let assetPath = options.assetPath else {
                throw CyberMacError.invalidInput("--register requires --archive and --asset-path.")
            }
            let registry = AssetPreviewRegistry()
            registerReport = try registry.register(options: AssetPreviewRegisterOptions(
                databaseURL: options.databaseURL ?? ArchiveCatalogIndexDefaults.databaseURL,
                archivePath: archivePath,
                assetPath: assetPath,
                previewURL: options.outputURL,
                kind: AssetPreviewKind.textureThumbnail,
                sourceTool: options.sourceTool
            ))
        }

        return CyberpunkXBMExportResult(
            inputPath: fileURL.path,
            outputPath: options.outputURL.path,
            width: width,
            height: height,
            mipCount: metadata.mipCount,
            compressionName: metadata.compressionName,
            decoderUsed: decoderName,
            payloadOffset: payloadOffset,
            payloadSize: payloadSize,
            topMipBytesDecoded: UInt64(topMipBytes),
            registered: registerReport != nil,
            registerReport: registerReport,
            metadata: metadata,
            debugNotes: debugNotes
        )
    }

    // MARK: - Metadata recovery

    static func recoverMetadata(
        reader: CyberpunkCR2WReader,
        inspection: CyberpunkXBMInspectionResult,
        debug: Bool,
        debugNotes: inout [String]
    ) -> CyberpunkXBMTextureMetadata {
        let nameLookup: [Int: String]
        if let table = inspection.nameTable {
            nameLookup = Dictionary(uniqueKeysWithValues: table.entries.compactMap { entry -> (Int, String)? in
                guard let value = entry.value else { return nil }
                return (entry.index, value)
            })
        } else {
            nameLookup = [:]
        }
        let chunk = inspection.chunks.first {
            ($0.className ?? "") == "CBitmapTexture"
        } ?? inspection.chunks.first

        guard let chunk = chunk else {
            debugNotes.append("No chunks present; metadata recovery skipped.")
            return CyberpunkXBMTextureMetadata(
                width: nil, height: nil, mipCount: nil,
                compressionName: nil, compression: .unknown, textureGroup: nil,
                widthConfidence: .unknown, heightConfidence: .unknown,
                mipCountConfidence: .unknown, compressionConfidence: .unknown
            )
        }

        // Read the chunk's raw bytes.
        let chunkOffset = Int(chunk.dataOffset)
        let chunkSize = Int(chunk.dataSize)
        guard let chunkBytes = reader.slice(at: chunkOffset, length: chunkSize) else {
            debugNotes.append("Chunk bytes out of bounds at offset=\(chunkOffset) size=\(chunkSize).")
            return CyberpunkXBMTextureMetadata(
                width: nil, height: nil, mipCount: nil,
                compressionName: nil, compression: .unknown, textureGroup: nil,
                widthConfidence: .unknown, heightConfidence: .unknown,
                mipCountConfidence: .unknown, compressionConfidence: .unknown
            )
        }

        if debug {
            let head = chunkBytes.prefix(96).map { String(format: "%02x", $0) }.joined(separator: " ")
            debugNotes.append("Chunk[\(chunk.index)] class=\(chunk.className ?? "?") dataOffset=\(chunk.dataOffset) dataSize=\(chunk.dataSize) head=\(head)")
        }

        let properties = parsePropertyRecords(
            chunkBytes: chunkBytes,
            nameLookup: nameLookup,
            debug: debug,
            debugNotes: &debugNotes
        )

        var width: UInt32?
        var height: UInt32?
        var mipCount: UInt32?
        var compressionName: String?
        var textureGroup: String?
        var isStreamable: Bool?
        var hasMipchain: Bool?
        var isGamma: Bool?
        var widthConfidence: CyberpunkXBMTextureMetadata.Confidence = .unknown
        var heightConfidence: CyberpunkXBMTextureMetadata.Confidence = .unknown
        var mipCountConfidence: CyberpunkXBMTextureMetadata.Confidence = .unknown
        var compressionConfidence: CyberpunkXBMTextureMetadata.Confidence = .unknown

        func absorb(_ property: ParsedProperty) {
            switch property.name {
            case "width" where width == nil:
                width = property.uint32Value
                if width != nil { widthConfidence = .exact }
            case "height" where height == nil:
                height = property.uint32Value
                if height != nil { heightConfidence = .exact }
            case "mipCount" where mipCount == nil:
                mipCount = property.uintValue
                if mipCount != nil { mipCountConfidence = .exact }
            case "compression" where compressionName == nil:
                if let nameID = property.uint16Value, let resolved = nameLookup[Int(nameID)] {
                    compressionName = resolved
                    compressionConfidence = .exact
                }
            case "textureGroup" where textureGroup == nil,
                 "group" where textureGroup == nil:
                if let nameID = property.uint16Value, let resolved = nameLookup[Int(nameID)] {
                    textureGroup = resolved
                }
            case "isStreamable" where isStreamable == nil:
                isStreamable = property.boolValue
            case "hasMipchain" where hasMipchain == nil:
                hasMipchain = property.boolValue
            case "isGamma" where isGamma == nil:
                isGamma = property.boolValue
            default:
                break
            }

            for child in property.children {
                absorb(child)
            }
        }

        for property in properties {
            absorb(property)
        }

        return CyberpunkXBMTextureMetadata(
            width: width,
            height: height,
            mipCount: mipCount,
            compressionName: compressionName,
            compression: CyberpunkXBMCompression(rawName: compressionName),
            textureGroup: textureGroup,
            widthConfidence: widthConfidence,
            heightConfidence: heightConfidence,
            mipCountConfidence: mipCountConfidence,
            compressionConfidence: compressionConfidence,
            isStreamable: isStreamable,
            hasMipchain: hasMipchain,
            isGamma: isGamma
        )
    }

    struct ParsedProperty {
        let name: String
        let typeName: String
        let valueBytes: Data
        let children: [ParsedProperty]

        var uint32Value: UInt32? {
            guard valueBytes.count == 4 else { return nil }
            let start = valueBytes.startIndex
            let b0 = UInt32(valueBytes[start])
            let b1 = UInt32(valueBytes[start + 1])
            let b2 = UInt32(valueBytes[start + 2])
            let b3 = UInt32(valueBytes[start + 3])
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }

        var uint16Value: UInt16? {
            guard valueBytes.count == 2 else { return nil }
            let start = valueBytes.startIndex
            return UInt16(valueBytes[start]) | (UInt16(valueBytes[start + 1]) << 8)
        }

        var boolValue: Bool? {
            guard valueBytes.count == 1 else { return nil }
            return valueBytes[valueBytes.startIndex] != 0
        }

        /// Best-effort small-unsigned-int interpretation for legacy integer fields.
        var uintValue: UInt32? {
            switch valueBytes.count {
            case 1: return UInt32(valueBytes[valueBytes.startIndex])
            case 2: return uint16Value.map(UInt32.init)
            case 4: return uint32Value
            default:
                return nil
            }
        }
    }

    /// Walks a chunk-data buffer expecting CP77 CR2W property records:
    /// `{u16 nameId; u16 typeId; u32 size}` followed by `size - 4` value bytes.
    /// CBitmapTexture structs may start with a single 0x00 object marker before records.
    /// Defensive: any malformed record stops iteration.
    static func parsePropertyRecords(
        chunkBytes: Data,
        nameLookup: [Int: String],
        debug: Bool,
        debugNotes: inout [String],
        depth: Int = 0
    ) -> [ParsedProperty] {
        var results: [ParsedProperty] = []
        let reader = CyberpunkCR2WReader(data: chunkBytes)
        var localCursor = reader.u8(at: 0) == 0 ? 1 : 0
        if debug && localCursor == 1 {
            debugNotes.append("Skipping leading CBitmapTexture struct/object marker at offset 0 before property scan.")
        }
        while localCursor + 8 <= chunkBytes.count {
            guard
                let nameID = reader.u16LE(at: localCursor),
                let typeID = reader.u16LE(at: localCursor + 2),
                let size = reader.u32LE(at: localCursor + 4)
            else { break }
            if nameID == 0 {
                break
            }
            if size < 4 {
                if debug { debugNotes.append("Property record at offset \(localCursor) has impossible size=\(size); aborting record scan.") }
                break
            }
            let valueByteCount = Int(size) - 4
            let valueOffset = localCursor + 8
            guard valueByteCount <= chunkBytes.count - valueOffset else {
                if debug { debugNotes.append("Property record at offset \(localCursor) overruns chunk (size=\(size), remaining=\(chunkBytes.count - valueOffset)); aborting.") }
                break
            }
            let valueBytes = chunkBytes.subdata(in: (chunkBytes.startIndex + valueOffset)..<(chunkBytes.startIndex + valueOffset + valueByteCount))
            let name = nameLookup[Int(nameID)] ?? "<id:\(nameID)>"
            let typeName = nameLookup[Int(typeID)] ?? "<id:\(typeID)>"
            let isNestedStruct = name == "setup"
                || typeName.localizedCaseInsensitiveContains("setup")
                || typeName.localizedCaseInsensitiveContains("struct")
            let children: [ParsedProperty]
            if depth < 8, isNestedStruct, valueBytes.first == 0, valueBytes.count >= 9 {
                children = parsePropertyRecords(
                    chunkBytes: valueBytes,
                    nameLookup: nameLookup,
                    debug: debug,
                    debugNotes: &debugNotes,
                    depth: depth + 1
                )
            } else {
                children = []
            }
            results.append(ParsedProperty(name: name, typeName: typeName, valueBytes: valueBytes, children: children))
            localCursor = valueOffset + valueByteCount
        }
        return results
    }
}

// MARK: - Formatter

public enum CyberpunkXBMExportFormatter {
    public static func formatSuccess(_ result: CyberpunkXBMExportResult, debug: Bool) -> String {
        var lines = [
            "Cyberpunk XBM export",
            "Input: \(PathSafety.redactUserPath(result.inputPath))",
            "Output: \(PathSafety.redactUserPath(result.outputPath))",
            "Width: \(result.width)",
            "Height: \(result.height)",
            "Mip count: \(result.mipCount.map(String.init) ?? "?")",
            "Compression: \(result.compressionName ?? "?")",
            "Decoder: \(result.decoderUsed)",
            "Payload offset: \(result.payloadOffset)",
            "Payload size: \(result.payloadSize)",
            "Top mip bytes decoded: \(result.topMipBytesDecoded)",
            "Registered: \(result.registered ? "yes" : "no")"
        ]
        if let report = result.registerReport {
            lines.append("Register status: \(report.status) (inserted=\(report.inserted), updated=\(report.updated))")
        }
        if debug && !result.debugNotes.isEmpty {
            lines.append("")
            lines.append("Debug notes:")
            for note in result.debugNotes {
                lines.append("  - \(note)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatFailure(_ failure: CyberpunkXBMExportFailure, debug: Bool) -> String {
        var lines = [
            "Cyberpunk XBM export FAILED",
            "Input: \(PathSafety.redactUserPath(failure.inputPath))"
        ]
        if let output = failure.outputPath {
            lines.append("Intended output: \(PathSafety.redactUserPath(output))")
        }
        lines.append("Detected compression: \(failure.detectedCompressionName ?? failure.detectedCompression.rawValue)")
        if let metadata = failure.metadata {
            lines.append("Width: \(metadata.width.map(String.init) ?? "?") (\(metadata.widthConfidence.rawValue))")
            lines.append("Height: \(metadata.height.map(String.init) ?? "?") (\(metadata.heightConfidence.rawValue))")
            lines.append("Mip count: \(metadata.mipCount.map(String.init) ?? "?") (\(metadata.mipCountConfidence.rawValue))")
            if let group = metadata.textureGroup {
                lines.append("Texture group: \(group)")
            }
        }
        lines.append("")
        lines.append("Reason: \(failure.reason)")
        if debug && !failure.debugNotes.isEmpty {
            lines.append("")
            lines.append("Debug notes:")
            for note in failure.debugNotes {
                lines.append("  - \(note)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
