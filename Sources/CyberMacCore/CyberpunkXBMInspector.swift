import Foundation

// MARK: - Low-level CR2W reader

public struct CyberpunkCR2WReader: Sendable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public var count: Int { data.count }

    public func u8(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }

    public func u16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, data.count >= offset + 2 else { return nil }
        let start = data.startIndex + offset
        return UInt16(data[start]) | (UInt16(data[start + 1]) << 8)
    }

    public func u32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, data.count >= offset + 4 else { return nil }
        let start = data.startIndex + offset
        let b0 = UInt32(data[start])
        let b1 = UInt32(data[start + 1])
        let b2 = UInt32(data[start + 2])
        let b3 = UInt32(data[start + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    public func u64LE(at offset: Int) -> UInt64? {
        guard offset >= 0, data.count >= offset + 8 else { return nil }
        let lo = UInt64(u32LE(at: offset) ?? 0)
        let hi = UInt64(u32LE(at: offset + 4) ?? 0)
        return lo | (hi << 32)
    }

    public func slice(at offset: Int, length: Int) -> Data? {
        guard offset >= 0, length >= 0, data.count >= offset + length else { return nil }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + length))
    }
}

// MARK: - Table directory

public enum CyberpunkCR2WTableKind: String, Sendable, Codable, Equatable {
    case strings
    case names
    case imports
    case properties
    case chunks
    case buffers
    case embedded
    case unknown

    static func guess(forIndex index: Int) -> CyberpunkCR2WTableKind {
        // WolvenKit-style CR2W table ordering for Cyberpunk 2077.
        // Verified against extracted .xbm files where table[0] holds a string pool
        // and table[1] holds 8-byte name entries pointing into it.
        switch index {
        case 0: return .strings
        case 1: return .names
        case 2: return .imports
        case 3: return .properties
        case 4: return .chunks
        case 5: return .buffers
        case 6: return .embedded
        default: return .unknown
        }
    }
}

public struct CyberpunkCR2WTableDescriptor: Sendable, Codable, Equatable {
    public let index: Int
    public let kindGuess: CyberpunkCR2WTableKind
    public let offset: UInt32
    public let count: UInt32
    public let crc32: UInt32
    public let computedByteSize: UInt32?

    public init(
        index: Int,
        kindGuess: CyberpunkCR2WTableKind,
        offset: UInt32,
        count: UInt32,
        crc32: UInt32,
        computedByteSize: UInt32?
    ) {
        self.index = index
        self.kindGuess = kindGuess
        self.offset = offset
        self.count = count
        self.crc32 = crc32
        self.computedByteSize = computedByteSize
    }

    public var isEmpty: Bool { offset == 0 && count == 0 }
}

public struct CyberpunkCR2WTableDirectory: Sendable, Codable, Equatable {
    public let tables: [CyberpunkCR2WTableDescriptor]
    public let lastNonEmptyEnd: UInt32?

    public init(tables: [CyberpunkCR2WTableDescriptor], lastNonEmptyEnd: UInt32?) {
        self.tables = tables
        self.lastNonEmptyEnd = lastNonEmptyEnd
    }
}

// MARK: - String / name tables

public struct CyberpunkCR2WStringEntry: Sendable, Codable, Equatable {
    public let stringOffset: UInt32
    public let value: String

    public init(stringOffset: UInt32, value: String) {
        self.stringOffset = stringOffset
        self.value = value
    }
}

public struct CyberpunkCR2WStringTable: Sendable, Codable, Equatable {
    public let regionOffset: UInt32
    public let regionByteLength: UInt32
    public let totalStrings: Int
    public let strings: [CyberpunkCR2WStringEntry]

    public init(
        regionOffset: UInt32,
        regionByteLength: UInt32,
        totalStrings: Int,
        strings: [CyberpunkCR2WStringEntry]
    ) {
        self.regionOffset = regionOffset
        self.regionByteLength = regionByteLength
        self.totalStrings = totalStrings
        self.strings = strings
    }
}

public struct CyberpunkCR2WNameEntry: Sendable, Codable, Equatable {
    public let index: Int
    public let stringOffset: UInt32
    public let hash: UInt32
    public let value: String?

    public init(index: Int, stringOffset: UInt32, hash: UInt32, value: String?) {
        self.index = index
        self.stringOffset = stringOffset
        self.hash = hash
        self.value = value
    }
}

public struct CyberpunkCR2WNameTable: Sendable, Codable, Equatable {
    public let totalEntries: Int
    public let entries: [CyberpunkCR2WNameEntry]

    public init(totalEntries: Int, entries: [CyberpunkCR2WNameEntry]) {
        self.totalEntries = totalEntries
        self.entries = entries
    }
}

// MARK: - Chunks

public struct CyberpunkCR2WChunkSummary: Sendable, Codable, Equatable {
    public let index: Int
    public let classNameID: UInt16
    public let className: String?
    public let objectFlags: UInt16
    public let parentID: UInt32
    public let dataSize: UInt32
    public let dataOffset: UInt32
    public let templateField: UInt32
    public let crc32: UInt32

    public init(
        index: Int,
        classNameID: UInt16,
        className: String?,
        objectFlags: UInt16,
        parentID: UInt32,
        dataSize: UInt32,
        dataOffset: UInt32,
        templateField: UInt32,
        crc32: UInt32
    ) {
        self.index = index
        self.classNameID = classNameID
        self.className = className
        self.objectFlags = objectFlags
        self.parentID = parentID
        self.dataSize = dataSize
        self.dataOffset = dataOffset
        self.templateField = templateField
        self.crc32 = crc32
    }
}

// MARK: - Candidate findings

public struct CyberpunkXBMCandidateMetadataField: Sendable, Codable, Equatable {
    public let name: String
    public let foundInStrings: Bool
    public let foundInNames: Bool

    public init(name: String, foundInStrings: Bool, foundInNames: Bool) {
        self.name = name
        self.foundInStrings = foundInStrings
        self.foundInNames = foundInNames
    }
}

public struct CyberpunkXBMCandidatePayloadRegion: Sendable, Codable, Equatable {
    public let label: String
    public let source: String
    public let offset: UInt64
    public let size: UInt64

    public init(label: String, source: String, offset: UInt64, size: UInt64) {
        self.label = label
        self.source = source
        self.offset = offset
        self.size = size
    }
}

// MARK: - Inspection result

public struct CyberpunkXBMInspectionResult: Sendable, Codable, Equatable {
    public let path: String
    public let fileSize: UInt64
    public let probeClassification: CyberpunkXBMClassification
    public let isCyberpunkXBM: Bool
    public let cr2wHeader: CyberpunkXBMCR2WHeader?
    public let tableDirectory: CyberpunkCR2WTableDirectory?
    public let stringTable: CyberpunkCR2WStringTable?
    public let nameTable: CyberpunkCR2WNameTable?
    public let chunks: [CyberpunkCR2WChunkSummary]
    public let textureMarkersFound: [String]
    public let candidateMetadataFields: [CyberpunkXBMCandidateMetadataField]
    public let candidatePayloadRegions: [CyberpunkXBMCandidatePayloadRegion]
    public let notes: [String]

    public init(
        path: String,
        fileSize: UInt64,
        probeClassification: CyberpunkXBMClassification,
        isCyberpunkXBM: Bool,
        cr2wHeader: CyberpunkXBMCR2WHeader?,
        tableDirectory: CyberpunkCR2WTableDirectory?,
        stringTable: CyberpunkCR2WStringTable?,
        nameTable: CyberpunkCR2WNameTable?,
        chunks: [CyberpunkCR2WChunkSummary],
        textureMarkersFound: [String],
        candidateMetadataFields: [CyberpunkXBMCandidateMetadataField],
        candidatePayloadRegions: [CyberpunkXBMCandidatePayloadRegion],
        notes: [String]
    ) {
        self.path = path
        self.fileSize = fileSize
        self.probeClassification = probeClassification
        self.isCyberpunkXBM = isCyberpunkXBM
        self.cr2wHeader = cr2wHeader
        self.tableDirectory = tableDirectory
        self.stringTable = stringTable
        self.nameTable = nameTable
        self.chunks = chunks
        self.textureMarkersFound = textureMarkersFound
        self.candidateMetadataFields = candidateMetadataFields
        self.candidatePayloadRegions = candidatePayloadRegions
        self.notes = notes
    }
}

// MARK: - Inspector

public struct CyberpunkXBMInspector {
    public static let candidateMetadataFieldNames: [String] = [
        "width",
        "height",
        "mipCount",
        "compression",
        "rawFormat",
        "rawGamma",
        "textureGroup",
        "setup"
    ]

    /// Conventional CP77 CR2W chunk-entry layout: u16 + u16 + u32 + u32 + u32 + u32 + u32 = 24 bytes.
    public static let chunkEntrySize = 24
    /// CP77 CR2W name-entry layout: u32 offset + u32 hash = 8 bytes.
    public static let nameEntrySize = 8

    public init() {}

    public func inspect(fileURL: URL) throws -> CyberpunkXBMInspectionResult {
        let probe = try CyberpunkXBMProbe().probe(fileURL: fileURL)

        // If the probe couldn't read a CR2W file, just surface what we have.
        guard probe.isCyberpunkXBM, let header = probe.cr2wHeader else {
            return CyberpunkXBMInspectionResult(
                path: probe.path,
                fileSize: probe.fileSize,
                probeClassification: probe.classification,
                isCyberpunkXBM: probe.isCyberpunkXBM,
                cr2wHeader: probe.cr2wHeader,
                tableDirectory: nil,
                stringTable: nil,
                nameTable: nil,
                chunks: [],
                textureMarkersFound: probe.discoveredMarkers,
                candidateMetadataFields: [],
                candidatePayloadRegions: [],
                notes: probe.notes + ["Inspector skipped CR2W parsing: file is not a Cyberpunk CR2W XBM."]
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: probe.path))
        } catch {
            throw CyberMacError.fileSystem("Unable to re-read XBM file for inspection: \(probe.path): \(error)")
        }
        let reader = CyberpunkCR2WReader(data: data)

        var notes: [String] = []

        let directory = Self.buildTableDirectory(header: header, fileSize: probe.fileSize)

        let stringTable = Self.parseStringTable(reader: reader, directory: directory, notes: &notes)
        let nameTable = Self.parseNameTable(
            reader: reader,
            directory: directory,
            stringTable: stringTable,
            notes: &notes
        )
        let chunks = Self.parseChunks(
            reader: reader,
            directory: directory,
            nameTable: nameTable,
            notes: &notes
        )

        let stringValues = stringTable?.strings.map(\.value) ?? []
        let nameValues = nameTable?.entries.compactMap(\.value) ?? []

        var markers = Set(probe.discoveredMarkers)
        for marker in CyberpunkXBMProbe.knownTextureMarkers {
            if stringValues.contains(marker) || nameValues.contains(marker) {
                markers.insert(marker)
            }
        }
        let sortedMarkers = markers.sorted()

        let candidateFields = Self.candidateMetadataFieldNames.map { fieldName in
            CyberpunkXBMCandidateMetadataField(
                name: fieldName,
                foundInStrings: stringValues.contains(fieldName),
                foundInNames: nameValues.contains(fieldName)
            )
        }

        let payloadRegions = Self.candidatePayloadRegions(
            header: header,
            fileSize: probe.fileSize,
            notes: &notes
        )

        if (stringTable?.strings.isEmpty ?? true) && (nameTable?.entries.isEmpty ?? true) {
            notes.append("String and name tables could not be decoded; CR2W table layout may differ for this file.")
        }
        if chunks.isEmpty {
            notes.append("Chunk table not decoded yet; CR2W chunk parsing returned no entries.")
        }
        notes.append("Typed property decoding (width/height/format values) is not implemented yet.")

        return CyberpunkXBMInspectionResult(
            path: probe.path,
            fileSize: probe.fileSize,
            probeClassification: probe.classification,
            isCyberpunkXBM: probe.isCyberpunkXBM,
            cr2wHeader: header,
            tableDirectory: directory,
            stringTable: stringTable,
            nameTable: nameTable,
            chunks: chunks,
            textureMarkersFound: sortedMarkers,
            candidateMetadataFields: candidateFields,
            candidatePayloadRegions: payloadRegions,
            notes: notes
        )
    }

    // MARK: - Table directory

    static func buildTableDirectory(header: CyberpunkXBMCR2WHeader, fileSize: UInt64) -> CyberpunkCR2WTableDirectory {
        let nonEmptyOffsets = header.tableEntries
            .filter { !($0.offset == 0 && $0.count == 0) }
            .map { $0.offset }
            .sorted()
        let endOfMetadata: UInt32? = header.fileSize.map { min($0, UInt32(clamping: fileSize)) } ?? nil

        let descriptors: [CyberpunkCR2WTableDescriptor] = header.tableEntries.map { entry in
            let kind = CyberpunkCR2WTableKind.guess(forIndex: entry.index)
            let byteSize: UInt32?
            if entry.offset == 0 && entry.count == 0 {
                byteSize = 0
            } else if let next = nonEmptyOffsets.first(where: { $0 > entry.offset }) {
                byteSize = next - entry.offset
            } else if let end = endOfMetadata, end > entry.offset {
                byteSize = end - entry.offset
            } else {
                byteSize = nil
            }
            return CyberpunkCR2WTableDescriptor(
                index: entry.index,
                kindGuess: kind,
                offset: entry.offset,
                count: entry.count,
                crc32: entry.crc32,
                computedByteSize: byteSize
            )
        }

        let lastEnd: UInt32?
        if let last = nonEmptyOffsets.last {
            if let descriptor = descriptors.first(where: { $0.offset == last }),
               let size = descriptor.computedByteSize {
                lastEnd = last + size
            } else {
                lastEnd = last
            }
        } else {
            lastEnd = nil
        }

        return CyberpunkCR2WTableDirectory(tables: descriptors, lastNonEmptyEnd: lastEnd)
    }

    // MARK: - String table

    static func parseStringTable(
        reader: CyberpunkCR2WReader,
        directory: CyberpunkCR2WTableDirectory,
        notes: inout [String]
    ) -> CyberpunkCR2WStringTable? {
        guard let table = directory.tables.first(where: { $0.index == 0 }),
              !table.isEmpty
        else { return nil }

        // CR2W table[0] count is the byte length of the raw string pool.
        let byteLength = table.count
        guard let region = reader.slice(at: Int(table.offset), length: Int(byteLength)) else {
            notes.append("String table region out of bounds: offset=\(table.offset) length=\(byteLength)")
            return nil
        }

        var entries: [CyberpunkCR2WStringEntry] = []
        var start = 0
        let bytes = [UInt8](region)
        while start < bytes.count {
            var end = start
            while end < bytes.count && bytes[end] != 0 {
                end += 1
            }
            if end > start {
                let slice = Data(bytes[start..<end])
                if let value = String(data: slice, encoding: .utf8) {
                    entries.append(CyberpunkCR2WStringEntry(
                        stringOffset: UInt32(start),
                        value: value
                    ))
                } else {
                    entries.append(CyberpunkCR2WStringEntry(
                        stringOffset: UInt32(start),
                        value: "<non-utf8:\(end - start) bytes>"
                    ))
                }
            }
            // Advance past terminator (or out of pool).
            start = end + 1
        }

        return CyberpunkCR2WStringTable(
            regionOffset: table.offset,
            regionByteLength: byteLength,
            totalStrings: entries.count,
            strings: entries
        )
    }

    // MARK: - Name table

    static func parseNameTable(
        reader: CyberpunkCR2WReader,
        directory: CyberpunkCR2WTableDirectory,
        stringTable: CyberpunkCR2WStringTable?,
        notes: inout [String]
    ) -> CyberpunkCR2WNameTable? {
        guard let table = directory.tables.first(where: { $0.index == 1 }),
              !table.isEmpty
        else { return nil }

        let entriesCount = Int(table.count)
        let totalSize = entriesCount * nameEntrySize
        guard reader.slice(at: Int(table.offset), length: totalSize) != nil else {
            notes.append("Name table region out of bounds: offset=\(table.offset) entries=\(entriesCount)")
            return CyberpunkCR2WNameTable(totalEntries: entriesCount, entries: [])
        }

        let stringLookup: [UInt32: String] = stringTable.map { table in
            Dictionary(uniqueKeysWithValues: table.strings.map { ($0.stringOffset, $0.value) })
        } ?? [:]

        var entries: [CyberpunkCR2WNameEntry] = []
        for i in 0..<entriesCount {
            let base = Int(table.offset) + i * nameEntrySize
            guard let stringOffset = reader.u32LE(at: base),
                  let hash = reader.u32LE(at: base + 4)
            else { break }
            let resolved = stringLookup[stringOffset]
            entries.append(CyberpunkCR2WNameEntry(
                index: i,
                stringOffset: stringOffset,
                hash: hash,
                value: resolved
            ))
        }

        return CyberpunkCR2WNameTable(totalEntries: entriesCount, entries: entries)
    }

    // MARK: - Chunks

    static func parseChunks(
        reader: CyberpunkCR2WReader,
        directory: CyberpunkCR2WTableDirectory,
        nameTable: CyberpunkCR2WNameTable?,
        notes: inout [String]
    ) -> [CyberpunkCR2WChunkSummary] {
        guard let table = directory.tables.first(where: { $0.index == 4 }),
              !table.isEmpty
        else { return [] }

        let entriesCount = Int(table.count)
        let totalSize = entriesCount * chunkEntrySize
        guard reader.slice(at: Int(table.offset), length: totalSize) != nil else {
            notes.append("Chunk table region out of bounds: offset=\(table.offset) entries=\(entriesCount)")
            return []
        }

        var chunks: [CyberpunkCR2WChunkSummary] = []
        for i in 0..<entriesCount {
            let base = Int(table.offset) + i * chunkEntrySize
            guard let classNameID = reader.u16LE(at: base),
                  let objectFlags = reader.u16LE(at: base + 2),
                  let parentID = reader.u32LE(at: base + 4),
                  let dataSize = reader.u32LE(at: base + 8),
                  let dataOffset = reader.u32LE(at: base + 12),
                  let templateField = reader.u32LE(at: base + 16),
                  let crc32 = reader.u32LE(at: base + 20)
            else { break }

            let resolvedClassName: String? = {
                guard let nameTable = nameTable else { return nil }
                let idx = Int(classNameID)
                if idx >= 0 && idx < nameTable.entries.count {
                    return nameTable.entries[idx].value
                }
                return nil
            }()

            chunks.append(CyberpunkCR2WChunkSummary(
                index: i,
                classNameID: classNameID,
                className: resolvedClassName,
                objectFlags: objectFlags,
                parentID: parentID,
                dataSize: dataSize,
                dataOffset: dataOffset,
                templateField: templateField,
                crc32: crc32
            ))
        }
        return chunks
    }

    // MARK: - Payload regions

    static func candidatePayloadRegions(
        header: CyberpunkXBMCR2WHeader,
        fileSize: UInt64,
        notes: inout [String]
    ) -> [CyberpunkXBMCandidatePayloadRegion] {
        var regions: [CyberpunkXBMCandidatePayloadRegion] = []

        if let headerFileSize = header.fileSize {
            let headerEnd = UInt64(headerFileSize)
            if headerEnd < fileSize {
                regions.append(CyberpunkXBMCandidatePayloadRegion(
                    label: "Trailing buffer (after CR2W metadata)",
                    source: "trailing-after-cr2w-fileSize",
                    offset: headerEnd,
                    size: fileSize - headerEnd
                ))
            } else if headerEnd > fileSize {
                notes.append("CR2W fileSize field (\(headerFileSize)) exceeds actual file size (\(fileSize)).")
            }
        }

        if let bufferSize = header.bufferSize, bufferSize > 0 {
            notes.append("CR2W bufferSize field reports \(bufferSize) bytes of buffer payload.")
        }

        return regions
    }
}

// MARK: - Formatter

public struct CyberpunkXBMInspectionFormatOptions: Sendable, Equatable {
    public let dumpStrings: Bool
    public let dumpNames: Bool
    public let dumpChunks: Bool
    public let limit: Int

    public static let defaultLimit = 50

    public init(
        dumpStrings: Bool = false,
        dumpNames: Bool = false,
        dumpChunks: Bool = false,
        limit: Int = CyberpunkXBMInspectionFormatOptions.defaultLimit
    ) {
        self.dumpStrings = dumpStrings
        self.dumpNames = dumpNames
        self.dumpChunks = dumpChunks
        self.limit = max(0, limit)
    }
}

public enum CyberpunkXBMInspectionFormatter {
    public static func format(
        _ result: CyberpunkXBMInspectionResult,
        options: CyberpunkXBMInspectionFormatOptions = CyberpunkXBMInspectionFormatOptions()
    ) -> String {
        var lines = [
            "Cyberpunk XBM inspect",
            "Path: \(PathSafety.redactUserPath(result.path))",
            "File size: \(result.fileSize) bytes",
            "Classification: \(result.probeClassification.rawValue)",
            "Is Cyberpunk XBM: \(result.isCyberpunkXBM ? "yes" : "no")"
        ]

        if let header = result.cr2wHeader {
            lines.append("")
            lines.append("CR2W header:")
            lines.append("  Magic present: \(header.magicPresent ? "yes" : "no")")
            if let value = header.version { lines.append("  Version: \(value)") }
            if let value = header.flags { lines.append("  Flags: 0x\(String(value, radix: 16))") }
            if let value = header.buildVersion { lines.append("  Build version: \(value)") }
            if let value = header.fileSize { lines.append("  File size (header): \(value)") }
            if let value = header.bufferSize { lines.append("  Buffer size (header): \(value)") }
            if let value = header.crc32 { lines.append("  CRC32: 0x\(String(value, radix: 16))") }
            if let value = header.numChunks { lines.append("  Chunk count (header): \(value)") }
        }

        if let directory = result.tableDirectory {
            lines.append("")
            lines.append("Table directory:")
            for table in directory.tables {
                let sizeStr = table.computedByteSize.map { "\($0) bytes" } ?? "?"
                lines.append("  [\(table.index)] \(table.kindGuess.rawValue) offset=\(table.offset) count=\(table.count) crc32=0x\(String(table.crc32, radix: 16)) size=\(sizeStr)")
            }
            if let end = directory.lastNonEmptyEnd {
                lines.append("  End of last non-empty table: \(end)")
            }
        }

        if let table = result.stringTable {
            lines.append("")
            lines.append("Strings: decoded=\(table.totalStrings) region=\(table.regionByteLength) bytes @\(table.regionOffset)")
            if options.dumpStrings {
                let dumped = table.strings.prefix(options.limit)
                for entry in dumped {
                    lines.append("  [@\(entry.stringOffset)] \(entry.value)")
                }
                if table.strings.count > dumped.count {
                    lines.append("  ... (\(table.strings.count - dumped.count) more)")
                }
            }
        } else {
            lines.append("")
            lines.append("Strings: not decoded")
        }

        if let table = result.nameTable {
            lines.append("")
            lines.append("Names: decoded=\(table.entries.count)/\(table.totalEntries)")
            if options.dumpNames {
                let dumped = table.entries.prefix(options.limit)
                for entry in dumped {
                    let value = entry.value ?? "<unresolved>"
                    lines.append("  [\(entry.index)] stringOffset=\(entry.stringOffset) hash=0x\(String(entry.hash, radix: 16)) name=\(value)")
                }
                if table.entries.count > dumped.count {
                    lines.append("  ... (\(table.entries.count - dumped.count) more)")
                }
            }
        } else {
            lines.append("")
            lines.append("Names: not decoded")
        }

        lines.append("")
        lines.append("Chunks: decoded=\(result.chunks.count)")
        if options.dumpChunks {
            let dumped = result.chunks.prefix(options.limit)
            for chunk in dumped {
                let className = chunk.className ?? "<id:\(chunk.classNameID)>"
                lines.append("  [\(chunk.index)] class=\(className) parent=\(chunk.parentID) dataOffset=\(chunk.dataOffset) dataSize=\(chunk.dataSize) crc32=0x\(String(chunk.crc32, radix: 16))")
            }
            if result.chunks.count > dumped.count {
                lines.append("  ... (\(result.chunks.count - dumped.count) more)")
            }
        }

        if !result.textureMarkersFound.isEmpty {
            lines.append("")
            lines.append("Texture markers (\(result.textureMarkersFound.count)):")
            for marker in result.textureMarkersFound {
                lines.append("  - \(marker)")
            }
        }

        if !result.candidateMetadataFields.isEmpty {
            lines.append("")
            lines.append("Candidate metadata fields:")
            for field in result.candidateMetadataFields {
                let stringMark = field.foundInStrings ? "S" : "-"
                let nameMark = field.foundInNames ? "N" : "-"
                lines.append("  [\(stringMark)\(nameMark)] \(field.name)")
            }
            lines.append("  (S=present in string pool, N=present in name table; typed values not yet decoded)")
        }

        if !result.candidatePayloadRegions.isEmpty {
            lines.append("")
            lines.append("Candidate payload regions:")
            for region in result.candidatePayloadRegions {
                lines.append("  - \(region.label): offset=\(region.offset) size=\(region.size) source=\(region.source)")
            }
        } else if result.isCyberpunkXBM {
            lines.append("")
            lines.append("Candidate payload regions: none detected")
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

    public static func formatJSON(_ result: CyberpunkXBMInspectionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
