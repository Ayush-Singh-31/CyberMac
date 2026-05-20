import Foundation

public struct AddonProbeTweakDBPackedStringAnalysisRequest: Sendable {
    public let fileURL: URL
    public let outputDirectoryURL: URL
    public let queries: [String]

    public init(fileURL: URL, outputDirectoryURL: URL, queries: [String] = []) {
        self.fileURL = fileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.queries = queries
    }
}

public struct AddonProbeTweakDBPackedStringComparisonRequest: Sendable {
    public let baseAnalysisURL: URL
    public let ep1AnalysisURL: URL
    public let outputDirectoryURL: URL

    public init(baseAnalysisURL: URL, ep1AnalysisURL: URL, outputDirectoryURL: URL) {
        self.baseAnalysisURL = baseAnalysisURL
        self.ep1AnalysisURL = ep1AnalysisURL
        self.outputDirectoryURL = outputDirectoryURL
    }
}

public enum AddonProbeTweakDBPackedStringEncoding: String, Codable, Equatable, Sendable {
    case fixstr
    case str8
    case str16
    case str32
}

public struct AddonProbeTweakDBPackedString: Codable, Equatable, Sendable {
    public let tagOffset: Int
    public let stringOffset: Int
    public let length: Int
    public let encoding: AddonProbeTweakDBPackedStringEncoding
    public let string: String
}

public enum AddonProbeTweakDBStringReferenceKind: String, Codable, Equatable, Sendable {
    case absoluteToString
    case absoluteToTag
    case relativeFromHereToString
    case relativeFromHereToTag
}

public struct AddonProbeTweakDBStringReference: Codable, Equatable, Sendable {
    public let offset: Int
    public let value: UInt32
    public let kind: AddonProbeTweakDBStringReferenceKind
    public let target: Int
    public let nearbyHex: String
}

public enum AddonProbeTweakDBHashAlgorithm: String, Codable, Equatable, Sendable {
    case fnv1a32
    case fnv1a64
    case crc32
}

public struct AddonProbeTweakDBHashReferenceCandidate: Codable, Equatable, Sendable {
    public let algorithm: AddonProbeTweakDBHashAlgorithm
    public let valueHex: String
    public let offsets: [Int]
}

public struct AddonProbeTweakDBPackedStringQueryReport: Codable, Equatable, Sendable {
    public let query: String
    public let packedMatches: [AddonProbeTweakDBPackedString]
    public let previousStrings: [AddonProbeTweakDBPackedString]
    public let nextStrings: [AddonProbeTweakDBPackedString]
    public let references: [AddonProbeTweakDBStringReference]
    public let hashCandidates: [AddonProbeTweakDBHashReferenceCandidate]
    public let contextHexStartOffset: Int
    public let contextHex: String
    public let contextASCIIStartOffset: Int
    public let contextASCII: String
}

public struct AddonProbeTweakDBPackedStringRegion: Codable, Equatable, Sendable {
    public let kind: String
    public let startOffset: Int
    public let endOffset: Int
    public let count: Int
    public let summary: String
    public let examples: [String]
}

public enum AddonProbeTweakDBPackedStringConclusion: String, Codable, Equatable, Sendable {
    case packedStringsConfirmed
    case queryPackedStringsFound
    case queryReferencesFound
    case noQueryReferencesFound
    case unresolved
}

public struct AddonProbeTweakDBPackedStringSetComparison: Codable, Equatable, Sendable {
    public let printableCount: Int
    public let packedCount: Int
    public let overlap: Int
    public let packedOnlyCount: Int
    public let printableOnlyCount: Int
}

public struct AddonProbeTweakDBPackedStringAnalysisReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let size: Int
    public let sha256: String
    public let queries: [String]
    public let packedStringCount: Int
    public let encodingCounts: [String: Int]
    public let packedStringsTablePath: String
    public let queryReportPath: String
    public let regionsPath: String
    public let reportPath: String
    public let packedStrings: [AddonProbeTweakDBPackedString]
    public let stringSetComparison: AddonProbeTweakDBPackedStringSetComparison
    public let queryReports: [AddonProbeTweakDBPackedStringQueryReport]
    public let regions: [AddonProbeTweakDBPackedStringRegion]
    public let conclusions: [AddonProbeTweakDBPackedStringConclusion]
    public let warnings: [String]
}

public struct AddonProbeTweakDBPackedStringQueryDiff: Codable, Equatable, Sendable {
    public let query: String
    public let baseMatchCount: Int
    public let ep1MatchCount: Int
    public let baseStringOffsets: [Int]
    public let ep1StringOffsets: [Int]
    public let baseReferenceCount: Int
    public let ep1ReferenceCount: Int
    public let neighborhoodsMatch: Bool
    public let baseNeighbors: [String]
    public let ep1Neighbors: [String]
}

public struct AddonProbeTweakDBPackedStringComparisonReport: Codable, Equatable, Sendable {
    public let basePath: String
    public let ep1Path: String
    public let basePackedCount: Int
    public let ep1PackedCount: Int
    public let sharedItemNames: [String]
    public let baseOnlyItemNames: [String]
    public let ep1OnlyItemNames: [String]
    public let queryDiffs: [AddonProbeTweakDBPackedStringQueryDiff]
    public let comparisonTSVPath: String
    public let reportPath: String
    public let warnings: [String]
}

public struct TweakDBPackedStringAnalyzer: Sendable {
    public static let defaultQueries: [String] = [
        "Items.Skirt",
        "Items.TShirt_04_old_01",
        "Items.FormalSkirt_01_basic_02",
        "Items.Pants_10_rich_01",
        "Items.GenericInnerChestClothing",
        "OutfitSlots.TorsoInner",
        "OutfitSlots.LegsOuter",
        "appearanceName",
        "entityName",
        "displayName",
        "localizedName",
        "atlasResourcePath",
        "atlasPartName",
        "BaseClothing",
        "Clothing",
        "FeetClothing"
    ]

    private static let minPackedStringLength = 1
    private static let contextHexRadius = 128
    private static let contextASCIIRadius = 256
    private static let neighborWindow = 3
    private static let maxReferencesPerQuery = 64
    private static let maxHashOffsetsPerAlgorithm = 64
    private static let denseRegionGap = 64
    private static let denseRegionMinCount = 8

    public init() {}

    public func analyze(request: AddonProbeTweakDBPackedStringAnalysisRequest) throws -> AddonProbeTweakDBPackedStringAnalysisReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let bytes = [UInt8](data)
        let packed = Self.extractPackedStrings(bytes: bytes)
        let printable = Self.extractPrintableStrings(bytes: bytes)
        let queries = Self.normalizedQueries(request.queries)
        let packedOffsetIndex = Self.indexByStringOffset(packed)
        let queryReports = queries.map { query in
            Self.buildQueryReport(
                query: query,
                bytes: bytes,
                packed: packed,
                packedOffsetIndex: packedOffsetIndex
            )
        }
        let regions = Self.regions(packed: packed, bytes: bytes)
        let printableSet = Set(printable.map(\.string))
        let packedSet = Set(packed.map(\.string))
        let setComparison = AddonProbeTweakDBPackedStringSetComparison(
            printableCount: printable.count,
            packedCount: packed.count,
            overlap: printableSet.intersection(packedSet).count,
            packedOnlyCount: packedSet.subtracting(printableSet).count,
            printableOnlyCount: printableSet.subtracting(packedSet).count
        )
        let conclusions = Self.conclusions(packed: packed, queryReports: queryReports, queries: queries)
        var encodingCounts: [String: Int] = [:]
        for entry in packed {
            encodingCounts[entry.encoding.rawValue, default: 0] += 1
        }

        let packedTableURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-strings.tsv")
        let queryReportURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-query-report.txt")
        let regionsURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-regions.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-string-analysis.json")

        try Self.writePackedStringsTSV(packed, to: packedTableURL)
        try Self.writeQueryReportText(queryReports, to: queryReportURL)
        try Self.writeRegionsText(regions, to: regionsURL)

        let report = AddonProbeTweakDBPackedStringAnalysisReport(
            filePath: fileURL.path,
            size: bytes.count,
            sha256: try PathSafety.sha256(url: fileURL),
            queries: queries,
            packedStringCount: packed.count,
            encodingCounts: encodingCounts,
            packedStringsTablePath: packedTableURL.path,
            queryReportPath: queryReportURL.path,
            regionsPath: regionsURL.path,
            reportPath: reportURL.path,
            packedStrings: packed,
            stringSetComparison: setComparison,
            queryReports: queryReports,
            regions: regions,
            conclusions: conclusions,
            warnings: [
                "Read-only analysis only. No game files were modified.",
                "Packed-string detection uses MessagePack-style fixstr/str8/str16/str32 heuristics; classification is experimental.",
                "Hash search uses experimental FNV-1a 32/64 and CRC32 candidates; matches do not prove the engine actually uses that algorithm."
            ]
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func compare(request: AddonProbeTweakDBPackedStringComparisonRequest) throws -> AddonProbeTweakDBPackedStringComparisonReport {
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let base = try Self.loadAnalysisReport(request.baseAnalysisURL)
        let ep1 = try Self.loadAnalysisReport(request.ep1AnalysisURL)

        let baseItemNames = Set(base.packedStrings.map(\.string).filter { $0.hasPrefix("Items.") })
        let ep1ItemNames = Set(ep1.packedStrings.map(\.string).filter { $0.hasPrefix("Items.") })
        let shared = baseItemNames.intersection(ep1ItemNames).sorted()
        let baseOnly = baseItemNames.subtracting(ep1ItemNames).sorted()
        let ep1Only = ep1ItemNames.subtracting(baseItemNames).sorted()

        let baseByString = Self.indexByString(base.packedStrings)
        let ep1ByString = Self.indexByString(ep1.packedStrings)

        let queries = Self.orderedUniqueQueries(base.queries + ep1.queries)
        let queryDiffs: [AddonProbeTweakDBPackedStringQueryDiff] = queries.map { query in
            let baseEntries = baseByString[query] ?? []
            let ep1Entries = ep1ByString[query] ?? []
            let baseQueryReport = base.queryReports.first { $0.query == query }
            let ep1QueryReport = ep1.queryReports.first { $0.query == query }
            let baseNeighbors = (baseQueryReport?.previousStrings ?? []).map(\.string)
                + (baseQueryReport?.nextStrings ?? []).map(\.string)
            let ep1Neighbors = (ep1QueryReport?.previousStrings ?? []).map(\.string)
                + (ep1QueryReport?.nextStrings ?? []).map(\.string)
            return AddonProbeTweakDBPackedStringQueryDiff(
                query: query,
                baseMatchCount: baseEntries.count,
                ep1MatchCount: ep1Entries.count,
                baseStringOffsets: baseEntries.map(\.stringOffset).sorted(),
                ep1StringOffsets: ep1Entries.map(\.stringOffset).sorted(),
                baseReferenceCount: baseQueryReport?.references.count ?? 0,
                ep1ReferenceCount: ep1QueryReport?.references.count ?? 0,
                neighborhoodsMatch: !baseNeighbors.isEmpty && baseNeighbors == ep1Neighbors,
                baseNeighbors: baseNeighbors,
                ep1Neighbors: ep1Neighbors
            )
        }

        let comparisonTSVURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-comparison.tsv")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-packed-string-comparison.json")
        try Self.writeComparisonTSV(shared: shared, baseOnly: baseOnly, ep1Only: ep1Only, to: comparisonTSVURL)

        let report = AddonProbeTweakDBPackedStringComparisonReport(
            basePath: base.filePath,
            ep1Path: ep1.filePath,
            basePackedCount: base.packedStringCount,
            ep1PackedCount: ep1.packedStringCount,
            sharedItemNames: shared,
            baseOnlyItemNames: baseOnly,
            ep1OnlyItemNames: ep1Only,
            queryDiffs: queryDiffs,
            comparisonTSVPath: comparisonTSVURL.path,
            reportPath: reportURL.path,
            warnings: [
                "Read-only comparison of two analyze-tweakdb-strings reports. No game files were modified."
            ]
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    // MARK: - Packed string extraction

    static func extractPackedStrings(bytes: [UInt8]) -> [AddonProbeTweakDBPackedString] {
        var results: [AddonProbeTweakDBPackedString] = []
        let count = bytes.count
        var index = 0
        while index < count {
            let tag = bytes[index]
            if (0x80...0xbf).contains(tag) {
                let length = Int(tag & 0x1f)
                if length >= Self.minPackedStringLength,
                   index + 1 + length <= count,
                   let value = printableString(bytes: bytes, start: index + 1, length: length) {
                    results.append(AddonProbeTweakDBPackedString(
                        tagOffset: index,
                        stringOffset: index + 1,
                        length: length,
                        encoding: .fixstr,
                        string: value
                    ))
                }
            } else if tag == 0xd9, index + 2 <= count {
                let length = Int(bytes[index + 1])
                if length >= Self.minPackedStringLength,
                   index + 2 + length <= count,
                   let value = printableString(bytes: bytes, start: index + 2, length: length) {
                    results.append(AddonProbeTweakDBPackedString(
                        tagOffset: index,
                        stringOffset: index + 2,
                        length: length,
                        encoding: .str8,
                        string: value
                    ))
                }
            } else if tag == 0xda, index + 3 <= count {
                let length = Int(bytes[index + 1]) | (Int(bytes[index + 2]) << 8)
                if length >= Self.minPackedStringLength,
                   index + 3 + length <= count,
                   let value = printableString(bytes: bytes, start: index + 3, length: length) {
                    results.append(AddonProbeTweakDBPackedString(
                        tagOffset: index,
                        stringOffset: index + 3,
                        length: length,
                        encoding: .str16,
                        string: value
                    ))
                }
            } else if tag == 0xdb, index + 5 <= count {
                let length = Int(bytes[index + 1]) |
                    (Int(bytes[index + 2]) << 8) |
                    (Int(bytes[index + 3]) << 16) |
                    (Int(bytes[index + 4]) << 24)
                if length >= Self.minPackedStringLength,
                   length <= count,
                   index + 5 + length <= count,
                   let value = printableString(bytes: bytes, start: index + 5, length: length) {
                    results.append(AddonProbeTweakDBPackedString(
                        tagOffset: index,
                        stringOffset: index + 5,
                        length: length,
                        encoding: .str32,
                        string: value
                    ))
                }
            }
            index += 1
        }
        return results
    }

    private static func printableString(bytes: [UInt8], start: Int, length: Int) -> String? {
        guard length > 0, start + length <= bytes.count else { return nil }
        var slice = [UInt8]()
        slice.reserveCapacity(length)
        for byte in bytes[start..<(start + length)] {
            guard Self.isPrintableStringByte(byte) else { return nil }
            slice.append(byte)
        }
        return String(bytes: slice, encoding: .utf8)
    }

    private static func isPrintableStringByte(_ byte: UInt8) -> Bool {
        (0x20...0x7E).contains(byte)
    }

    // MARK: - Printable strings (mirrors TweakDBBinaryInspector behaviour)

    private struct PrintableString {
        let string: String
        let offset: Int
        let length: Int
    }

    private static func extractPrintableStrings(bytes: [UInt8]) -> [PrintableString] {
        var strings: [PrintableString] = []
        var start: Int?
        var buffer: [UInt8] = []
        for (index, byte) in bytes.enumerated() {
            if isPrintableStringByte(byte) {
                if start == nil { start = index }
                buffer.append(byte)
            } else {
                flush(start: &start, buffer: &buffer, into: &strings)
            }
        }
        flush(start: &start, buffer: &buffer, into: &strings)
        return strings
    }

    private static func flush(
        start: inout Int?,
        buffer: inout [UInt8],
        into strings: inout [PrintableString]
    ) {
        defer {
            start = nil
            buffer.removeAll(keepingCapacity: true)
        }
        guard let stringStart = start, buffer.count >= 4 else { return }
        guard let value = String(bytes: buffer, encoding: .utf8), !value.isEmpty else { return }
        strings.append(PrintableString(string: value, offset: stringStart, length: buffer.count))
    }

    // MARK: - Query report

    private static func buildQueryReport(
        query: String,
        bytes: [UInt8],
        packed: [AddonProbeTweakDBPackedString],
        packedOffsetIndex: [Int: Int]
    ) -> AddonProbeTweakDBPackedStringQueryReport {
        let matches = packed.filter { $0.string == query }
        let firstMatch = matches.first
        let referenceTargets = Self.referenceTargets(for: matches)
        let references = Self.findReferences(bytes: bytes, targets: referenceTargets)
        let hashCandidates = Self.findHashCandidates(query: query, bytes: bytes)
        let centerOffset = firstMatch?.stringOffset ?? 0
        let centerLength = firstMatch?.length ?? 0
        let hexRange = Self.contextRange(offset: centerOffset, length: centerLength, radius: contextHexRadius, dataCount: bytes.count)
        let asciiRange = Self.contextRange(offset: centerOffset, length: centerLength, radius: contextASCIIRadius, dataCount: bytes.count)
        let neighbors = Self.neighbors(around: firstMatch, in: packed)
        return AddonProbeTweakDBPackedStringQueryReport(
            query: query,
            packedMatches: matches,
            previousStrings: neighbors.previous,
            nextStrings: neighbors.next,
            references: references,
            hashCandidates: hashCandidates,
            contextHexStartOffset: hexRange.lowerBound,
            contextHex: Self.hex(bytes: bytes, range: hexRange),
            contextASCIIStartOffset: asciiRange.lowerBound,
            contextASCII: Self.ascii(bytes: bytes, range: asciiRange)
        )
    }

    private static func neighbors(
        around match: AddonProbeTweakDBPackedString?,
        in packed: [AddonProbeTweakDBPackedString]
    ) -> (previous: [AddonProbeTweakDBPackedString], next: [AddonProbeTweakDBPackedString]) {
        guard let match else { return ([], []) }
        guard let position = packed.firstIndex(where: { $0.tagOffset == match.tagOffset }) else {
            return ([], [])
        }
        let previousStart = max(0, position - Self.neighborWindow)
        let previous = Array(packed[previousStart..<position])
        let nextEnd = min(packed.count, position + 1 + Self.neighborWindow)
        let next = Array(packed[(position + 1)..<nextEnd])
        return (previous, next)
    }

    private static func referenceTargets(for matches: [AddonProbeTweakDBPackedString]) -> [(kind: AddonProbeTweakDBStringReferenceKind, target: Int)] {
        var targets: [(AddonProbeTweakDBStringReferenceKind, Int)] = []
        for entry in matches {
            targets.append((.absoluteToString, entry.stringOffset))
            targets.append((.absoluteToTag, entry.tagOffset))
            targets.append((.relativeFromHereToString, entry.stringOffset))
            targets.append((.relativeFromHereToTag, entry.tagOffset))
        }
        return targets
    }

    private static func findReferences(
        bytes: [UInt8],
        targets: [(kind: AddonProbeTweakDBStringReferenceKind, target: Int)]
    ) -> [AddonProbeTweakDBStringReference] {
        guard !targets.isEmpty, bytes.count >= 4 else { return [] }
        let absoluteByValue = Self.absoluteTargetIndex(targets)
        let relativeTargets = targets.filter { $0.kind == .relativeFromHereToString || $0.kind == .relativeFromHereToTag }
        var references: [AddonProbeTweakDBStringReference] = []
        var counts: [AddonProbeTweakDBStringReferenceKind: Int] = [:]
        var offset = 0
        while offset <= bytes.count - 4 {
            let value = Self.readUInt32LE(bytes: bytes, offset: offset)
            if let kinds = absoluteByValue[Int(value)] {
                for kind in kinds where (counts[kind] ?? 0) < Self.maxReferencesPerQuery {
                    references.append(AddonProbeTweakDBStringReference(
                        offset: offset,
                        value: value,
                        kind: kind,
                        target: Int(value),
                        nearbyHex: Self.hex(bytes: bytes, range: Self.contextRange(offset: offset, length: 4, radius: 16, dataCount: bytes.count))
                    ))
                    counts[kind, default: 0] += 1
                }
            }
            for (kind, target) in relativeTargets {
                if (counts[kind] ?? 0) >= Self.maxReferencesPerQuery { continue }
                let computed = Int64(offset) + Int64(Int32(bitPattern: value))
                if computed == Int64(target) {
                    references.append(AddonProbeTweakDBStringReference(
                        offset: offset,
                        value: value,
                        kind: kind,
                        target: target,
                        nearbyHex: Self.hex(bytes: bytes, range: Self.contextRange(offset: offset, length: 4, radius: 16, dataCount: bytes.count))
                    ))
                    counts[kind, default: 0] += 1
                }
            }
            offset += 1
        }
        return references
    }

    private static func absoluteTargetIndex(
        _ targets: [(kind: AddonProbeTweakDBStringReferenceKind, target: Int)]
    ) -> [Int: [AddonProbeTweakDBStringReferenceKind]] {
        var index: [Int: [AddonProbeTweakDBStringReferenceKind]] = [:]
        for (kind, target) in targets {
            switch kind {
            case .absoluteToString, .absoluteToTag:
                index[target, default: []].append(kind)
            case .relativeFromHereToString, .relativeFromHereToTag:
                continue
            }
        }
        return index
    }

    // MARK: - Hash search

    static func findHashCandidates(query: String, bytes: [UInt8]) -> [AddonProbeTweakDBHashReferenceCandidate] {
        let queryBytes = Array(query.utf8)
        let fnv32 = Self.fnv1a32(queryBytes)
        let fnv64 = Self.fnv1a64(queryBytes)
        let crc = Self.crc32(queryBytes)
        let fnv32Offsets = Self.findUInt32LE(bytes: bytes, needle: fnv32, limit: Self.maxHashOffsetsPerAlgorithm)
        let fnv64Offsets = Self.findUInt64LE(bytes: bytes, needle: fnv64, limit: Self.maxHashOffsetsPerAlgorithm)
        let crcOffsets = Self.findUInt32LE(bytes: bytes, needle: crc, limit: Self.maxHashOffsetsPerAlgorithm)
        return [
            AddonProbeTweakDBHashReferenceCandidate(
                algorithm: .fnv1a32,
                valueHex: String(format: "%08x", fnv32),
                offsets: fnv32Offsets
            ),
            AddonProbeTweakDBHashReferenceCandidate(
                algorithm: .fnv1a64,
                valueHex: String(format: "%016llx", fnv64),
                offsets: fnv64Offsets
            ),
            AddonProbeTweakDBHashReferenceCandidate(
                algorithm: .crc32,
                valueHex: String(format: "%08x", crc),
                offsets: crcOffsets
            )
        ]
    }

    static func fnv1a32(_ bytes: [UInt8]) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for byte in bytes {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return hash
    }

    static func fnv1a64(_ bytes: [UInt8]) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(0) &- (crc & 1)
                crc = (crc >> 1) ^ (0xedb88320 & mask)
            }
        }
        return crc ^ 0xffffffff
    }

    private static func findUInt32LE(bytes: [UInt8], needle: UInt32, limit: Int) -> [Int] {
        guard bytes.count >= 4, limit > 0 else { return [] }
        var offsets: [Int] = []
        let target = needle
        var offset = 0
        while offset <= bytes.count - 4 && offsets.count < limit {
            let value = readUInt32LE(bytes: bytes, offset: offset)
            if value == target {
                offsets.append(offset)
            }
            offset += 1
        }
        return offsets
    }

    private static func findUInt64LE(bytes: [UInt8], needle: UInt64, limit: Int) -> [Int] {
        guard bytes.count >= 8, limit > 0 else { return [] }
        var offsets: [Int] = []
        var offset = 0
        while offset <= bytes.count - 8 && offsets.count < limit {
            let value = readUInt64LE(bytes: bytes, offset: offset)
            if value == needle {
                offsets.append(offset)
            }
            offset += 1
        }
        return offsets
    }

    // MARK: - Regions

    private static func regions(
        packed: [AddonProbeTweakDBPackedString],
        bytes: [UInt8]
    ) -> [AddonProbeTweakDBPackedStringRegion] {
        var regions = denseRegions(packed)
        if let referenceRegion = referenceTableRegion(packed: packed, bytes: bytes) {
            regions.append(referenceRegion)
        }
        if let recordRegion = repeatedRecordRegion(packed) {
            regions.append(recordRegion)
        }
        return regions
    }

    private static func denseRegions(_ packed: [AddonProbeTweakDBPackedString]) -> [AddonProbeTweakDBPackedStringRegion] {
        guard !packed.isEmpty else { return [] }
        let sorted = packed.sorted { $0.stringOffset < $1.stringOffset }
        var regions: [[AddonProbeTweakDBPackedString]] = []
        var current: [AddonProbeTweakDBPackedString] = []
        for entry in sorted {
            if let previous = current.last {
                let gap = entry.tagOffset - (previous.stringOffset + previous.length)
                if gap > Self.denseRegionGap {
                    if current.count >= Self.denseRegionMinCount { regions.append(current) }
                    current = [entry]
                    continue
                }
            }
            current.append(entry)
        }
        if current.count >= Self.denseRegionMinCount { regions.append(current) }

        return regions.prefix(50).map { region in
            let end = (region.last?.stringOffset ?? 0) + (region.last?.length ?? 0)
            return AddonProbeTweakDBPackedStringRegion(
                kind: "densePackedStringRegion",
                startOffset: region.first?.tagOffset ?? 0,
                endOffset: end,
                count: region.count,
                summary: "Cluster of adjacent packed strings; candidate string-table segment.",
                examples: region.prefix(8).map(\.string)
            )
        }
    }

    private static func referenceTableRegion(
        packed: [AddonProbeTweakDBPackedString],
        bytes: [UInt8]
    ) -> AddonProbeTweakDBPackedStringRegion? {
        guard bytes.count >= 4, !packed.isEmpty else { return nil }
        let targets = Set(packed.map(\.stringOffset) + packed.map(\.tagOffset))
        var hitOffsets: [Int] = []
        var offset = 0
        while offset <= bytes.count - 4 {
            let value = Int(readUInt32LE(bytes: bytes, offset: offset))
            if targets.contains(value) {
                hitOffsets.append(offset)
            }
            offset += 4
        }
        guard let first = hitOffsets.first, let last = hitOffsets.last, hitOffsets.count >= 8 else {
            return nil
        }
        return AddonProbeTweakDBPackedStringRegion(
            kind: "possibleReferenceTableRegion",
            startOffset: first,
            endOffset: last + 4,
            count: hitOffsets.count,
            summary: "u32 LE values pointing at packed string tag/string offsets; heuristic reference-table indication.",
            examples: hitOffsets.prefix(12).map { "u32@\($0)" }
        )
    }

    private static func repeatedRecordRegion(_ packed: [AddonProbeTweakDBPackedString]) -> AddonProbeTweakDBPackedStringRegion? {
        let records = packed.filter { $0.string.hasPrefix("Items.") }
        guard records.count >= 2 else { return nil }
        let start = records.map(\.tagOffset).min() ?? 0
        let end = records.map { $0.stringOffset + $0.length }.max() ?? start
        return AddonProbeTweakDBPackedStringRegion(
            kind: "possibleRecordTableRegion",
            startOffset: start,
            endOffset: end,
            count: records.count,
            summary: "Span covering Items.* packed names; candidate record-table area pending structural decode.",
            examples: records.prefix(20).map(\.string)
        )
    }

    // MARK: - Conclusions

    private static func conclusions(
        packed: [AddonProbeTweakDBPackedString],
        queryReports: [AddonProbeTweakDBPackedStringQueryReport],
        queries: [String]
    ) -> [AddonProbeTweakDBPackedStringConclusion] {
        var conclusions: [AddonProbeTweakDBPackedStringConclusion] = []
        if !packed.isEmpty { conclusions.append(.packedStringsConfirmed) }
        if !queries.isEmpty {
            if queryReports.contains(where: { !$0.packedMatches.isEmpty }) {
                conclusions.append(.queryPackedStringsFound)
            }
            if queryReports.contains(where: { !$0.references.isEmpty }) {
                conclusions.append(.queryReferencesFound)
            } else {
                conclusions.append(.noQueryReferencesFound)
            }
        }
        if conclusions.isEmpty {
            conclusions.append(.unresolved)
        }
        return conclusions
    }

    // MARK: - Helpers

    private static func normalizedQueries(_ queries: [String]) -> [String] {
        let cleaned = orderedUniqueQueries(queries)
        return cleaned.isEmpty ? defaultQueries : cleaned
    }

    private static func orderedUniqueQueries(_ queries: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in queries {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private static func indexByStringOffset(_ packed: [AddonProbeTweakDBPackedString]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for (index, entry) in packed.enumerated() {
            result[entry.stringOffset] = index
        }
        return result
    }

    private static func indexByString(_ packed: [AddonProbeTweakDBPackedString]) -> [String: [AddonProbeTweakDBPackedString]] {
        Dictionary(grouping: packed, by: \.string)
    }

    private static func readData(_ url: URL) throws -> Data {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("TweakDB binary file not found: \(url.path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("Expected a file, got directory: \(url.path)")
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private static func loadAnalysisReport(_ url: URL) throws -> AddonProbeTweakDBPackedStringAnalysisReport {
        let data = try Data(contentsOf: url.standardizedFileURL)
        return try JSONDecoder.cybermac.decode(AddonProbeTweakDBPackedStringAnalysisReport.self, from: data)
    }

    private static func ensureOutputIsNotInsideInspectedApp(inputFileURL: URL, outputDirectoryURL: URL) throws {
        let components = inputFileURL.standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return
        }
        let appPath = NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
        let outputPath = outputDirectoryURL.standardizedFileURL.path
        if outputPath == appPath || outputPath.hasPrefix(appPath + "/") {
            throw CyberMacError.invalidInput("Refusing to write packed-string analysis output inside the game app: \(outputPath)")
        }
    }

    private static func contextRange(offset: Int, length: Int, radius: Int, dataCount: Int) -> Range<Int> {
        let lower = max(0, offset - radius)
        let upper = min(dataCount, offset + max(length, 0) + radius)
        return lower..<upper
    }

    private static func readUInt32LE(bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }

    private static func readUInt64LE(bytes: [UInt8], offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[offset + index]) << UInt64(index * 8)
        }
        return value
    }

    private static func hex(bytes: [UInt8], range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        return bytes[range].map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func ascii(bytes: [UInt8], range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        let mapped = bytes[range].map { byte -> UInt8 in
            isPrintableStringByte(byte) ? byte : UInt8(ascii: ".")
        }
        return String(bytes: mapped, encoding: .utf8) ?? ""
    }

    private static func tsvEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    // MARK: - Writers

    private static func writePackedStringsTSV(_ packed: [AddonProbeTweakDBPackedString], to url: URL) throws {
        var lines = ["tagOffset\tstringOffset\tlength\tencoding\tstring"]
        for entry in packed {
            lines.append("\(entry.tagOffset)\t\(entry.stringOffset)\t\(entry.length)\t\(entry.encoding.rawValue)\t\(tsvEscape(entry.string))")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeQueryReportText(_ queryReports: [AddonProbeTweakDBPackedStringQueryReport], to url: URL) throws {
        var lines: [String] = []
        for report in queryReports {
            lines.append("[query] \(report.query) packedMatches=\(report.packedMatches.count) references=\(report.references.count)")
            for match in report.packedMatches {
                lines.append("packed tag=\(match.tagOffset) string=\(match.stringOffset) len=\(match.length) enc=\(match.encoding.rawValue) value=\(match.string)")
            }
            if !report.previousStrings.isEmpty {
                lines.append("previous: " + report.previousStrings.map { "\($0.stringOffset):\($0.string)" }.joined(separator: " | "))
            }
            if !report.nextStrings.isEmpty {
                lines.append("next: " + report.nextStrings.map { "\($0.stringOffset):\($0.string)" }.joined(separator: " | "))
            }
            for reference in report.references {
                lines.append("ref @ \(reference.offset) value=\(reference.value) kind=\(reference.kind.rawValue) target=\(reference.target)")
            }
            for candidate in report.hashCandidates {
                lines.append("hash \(candidate.algorithm.rawValue)=\(candidate.valueHex) offsets=\(candidate.offsets.count)")
            }
            if !report.contextHex.isEmpty {
                lines.append("hex @ \(report.contextHexStartOffset): \(report.contextHex)")
                lines.append("ascii @ \(report.contextASCIIStartOffset): \(report.contextASCII)")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeRegionsText(_ regions: [AddonProbeTweakDBPackedStringRegion], to url: URL) throws {
        var lines: [String] = []
        for region in regions {
            lines.append("[\(region.kind)] \(region.startOffset)..<\(region.endOffset) count=\(region.count)")
            lines.append(region.summary)
            for example in region.examples {
                lines.append("- \(example)")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeComparisonTSV(
        shared: [String],
        baseOnly: [String],
        ep1Only: [String],
        to url: URL
    ) throws {
        var lines = ["bucket\tstring"]
        for value in shared { lines.append("sharedItem\t\(tsvEscape(value))") }
        for value in baseOnly { lines.append("baseOnlyItem\t\(tsvEscape(value))") }
        for value in ep1Only { lines.append("ep1OnlyItem\t\(tsvEscape(value))") }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

public enum AddonProbeTweakDBPackedStringAnalysisFormatter {
    public static func format(_ report: AddonProbeTweakDBPackedStringAnalysisReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB packed-string analysis",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Size: \(report.size)",
            "SHA-256: \(report.sha256)",
            "Packed strings: \(report.packedStringCount)",
            "  fixstr=\(report.encodingCounts["fixstr"] ?? 0) str8=\(report.encodingCounts["str8"] ?? 0) str16=\(report.encodingCounts["str16"] ?? 0) str32=\(report.encodingCounts["str32"] ?? 0)",
            "Printable strings: \(report.stringSetComparison.printableCount) (overlap with packed: \(report.stringSetComparison.overlap))",
            "Packed only: \(report.stringSetComparison.packedOnlyCount) | Printable only: \(report.stringSetComparison.printableOnlyCount)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Packed strings TSV: \(PathSafety.redactUserPath(report.packedStringsTablePath))"
        ]
        appendList("Queries", report.queries, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBPackedStringAnalysisReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(50) {
            lines.append("- \(value)")
        }
        if values.count > 50 {
            lines.append("- ... \(values.count - 50) more")
        }
    }
}

public enum AddonProbeTweakDBPackedStringComparisonFormatter {
    public static func format(_ report: AddonProbeTweakDBPackedStringComparisonReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB packed-string comparison",
            "Status: read-only; no game files were modified.",
            "Base: \(PathSafety.redactUserPath(report.basePath)) packed=\(report.basePackedCount)",
            "EP1:  \(PathSafety.redactUserPath(report.ep1Path)) packed=\(report.ep1PackedCount)",
            "Shared Items.*: \(report.sharedItemNames.count)",
            "Base-only Items.*: \(report.baseOnlyItemNames.count)",
            "EP1-only Items.*: \(report.ep1OnlyItemNames.count)",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]
        if !report.queryDiffs.isEmpty {
            lines.append("")
            lines.append("Query diffs:")
            for diff in report.queryDiffs {
                lines.append("- \(diff.query): base=\(diff.baseMatchCount) ep1=\(diff.ep1MatchCount) baseRefs=\(diff.baseReferenceCount) ep1Refs=\(diff.ep1ReferenceCount) neighborhoodsMatch=\(diff.neighborhoodsMatch)")
            }
        }
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in report.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBPackedStringComparisonReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}
