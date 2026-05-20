import Foundation

public struct AddonProbeTweakDBReferenceTableAnalysisRequest: Sendable {
    public let fileURL: URL
    public let stringsAnalysisURL: URL
    public let outputDirectoryURL: URL
    public let queries: [String]
    public let aroundOffsets: [Int]

    public init(
        fileURL: URL,
        stringsAnalysisURL: URL,
        outputDirectoryURL: URL,
        queries: [String] = [],
        aroundOffsets: [Int] = []
    ) {
        self.fileURL = fileURL
        self.stringsAnalysisURL = stringsAnalysisURL
        self.outputDirectoryURL = outputDirectoryURL
        self.queries = queries
        self.aroundOffsets = aroundOffsets
    }
}

public enum AddonProbeTweakDBReferenceTableKind: String, Codable, Equatable, Sendable {
    case stringOffsetTable
    case tagOffsetTable
    case mixedOffsetTable
    case unknownReferenceTable
}

public enum AddonProbeTweakDBReferenceTableConclusion: String, Codable, Equatable, Sendable {
    case referenceTablesFound
    case queryReferenceTablesMapped
    case likelyStringOffsetTable
    case likelyTagOffsetTable
    case unresolved
}

public struct AddonProbeTweakDBReferenceTableField: Codable, Equatable, Sendable {
    public let index: Int
    public let rawUInt32: UInt32
    public let pointsToKind: String?
    public let pointsToOffset: Int?
    public let string: String?
}

public struct AddonProbeTweakDBReferenceTableRow: Codable, Equatable, Sendable {
    public let offset: Int
    public let rowIndex: Int?
    public let fields: [AddonProbeTweakDBReferenceTableField]
}

public struct AddonProbeTweakDBReferenceTableCandidate: Codable, Equatable, Sendable {
    public let tableIndex: Int
    public let startOffset: Int
    public let endOffset: Int
    public let rowWidth: Int
    public let rowCount: Int
    public let pointingFieldIndexes: [Int]
    public let hitCount: Int
    public let hitDensity: Double
    public let kind: AddonProbeTweakDBReferenceTableKind
    public let sampleRows: [AddonProbeTweakDBReferenceTableRow]
}

public struct AddonProbeTweakDBReferenceAroundOffsetAnalysis: Codable, Equatable, Sendable {
    public let aroundOffset: Int
    public let candidateTableIndexes: [Int]
}

public struct AddonProbeTweakDBQueryReferenceNeighborhood: Codable, Equatable, Sendable {
    public let query: String
    public let stringOffset: Int
    public let tagOffset: Int
    public let referenceOffset: Int
    public let referenceKind: AddonProbeTweakDBStringReferenceKind
    public let candidateTableIndexes: [Int]
    public let rowOffset: Int?
    public let rowIndex: Int?
    public let previousRows: [AddonProbeTweakDBReferenceTableRow]
    public let nextRows: [AddonProbeTweakDBReferenceTableRow]
}

public struct AddonProbeTweakDBReferenceTableAnalysisReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let stringsAnalysisPath: String
    public let size: Int
    public let packedStringCount: Int
    public let queries: [String]
    public let aroundOffsets: [Int]
    public let tableReportPath: String
    public let queryNeighborhoodsPath: String
    public let reportPath: String
    public let candidateTables: [AddonProbeTweakDBReferenceTableCandidate]
    public let aroundOffsetAnalyses: [AddonProbeTweakDBReferenceAroundOffsetAnalysis]
    public let queryNeighborhoods: [AddonProbeTweakDBQueryReferenceNeighborhood]
    public let conclusions: [AddonProbeTweakDBReferenceTableConclusion]
    public let warnings: [String]
}

public struct TweakDBReferenceTableAnalyzer: Sendable {
    private static let rowWidths = [8, 12, 16, 20, 24]
    private static let minCandidateRows = 3
    private static let maxSampleRows = 8
    private static let queryNeighborRows = 10

    public init() {}

    public func analyze(request: AddonProbeTweakDBReferenceTableAnalysisRequest) throws -> AddonProbeTweakDBReferenceTableAnalysisReport {
        let fileURL = request.fileURL.standardizedFileURL
        let stringsAnalysisURL = request.stringsAnalysisURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let bytes = [UInt8](data)
        let stringsAnalysis = try Self.loadStringsAnalysis(stringsAnalysisURL)
        let packed = stringsAnalysis.packedStrings
        let offsetLookup = Self.offsetLookup(packed)
        let hitOffsets = Self.u32HitOffsets(bytes: bytes, offsetLookup: offsetLookup)
        let queries = Self.normalizedQueries(request.queries, fallback: stringsAnalysis.queries)
        let knownReferenceOffsets = Self.knownReferenceOffsets(queries: queries, stringsAnalysis: stringsAnalysis)
        let requestedAroundOffsets = Self.orderedUniqueInts(request.aroundOffsets)
        let allAroundOffsets = Self.orderedUniqueInts(knownReferenceOffsets + requestedAroundOffsets)

        var candidates = Self.detectCandidateTables(bytes: bytes, hitOffsets: hitOffsets, offsetLookup: offsetLookup)
        let aroundCandidatesByOffset = allAroundOffsets.map { offset in
            (offset, Self.inferCandidatesAroundOffset(offset, bytes: bytes, hitOffsets: hitOffsets, offsetLookup: offsetLookup))
        }
        for (_, aroundCandidates) in aroundCandidatesByOffset {
            candidates.append(contentsOf: aroundCandidates)
        }
        candidates = Self.deduplicatedCandidates(candidates)
        candidates = Self.assignTableIndexes(candidates)

        let aroundOffsetAnalyses = aroundCandidatesByOffset.map { offset, inferred in
            AddonProbeTweakDBReferenceAroundOffsetAnalysis(
                aroundOffset: offset,
                candidateTableIndexes: Self.matchingTableIndexes(for: inferred, in: candidates)
            )
        }
        let queryNeighborhoods = Self.queryNeighborhoods(
            queries: queries,
            stringsAnalysis: stringsAnalysis,
            candidates: candidates,
            bytes: bytes,
            offsetLookup: offsetLookup
        )
        let conclusions = Self.conclusions(candidates: candidates, queryNeighborhoods: queryNeighborhoods)

        let tableReportURL = outputDirectoryURL.appendingPathComponent("tweakdb-reference-tables.txt")
        let queryNeighborhoodsURL = outputDirectoryURL.appendingPathComponent("tweakdb-query-reference-neighborhoods.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-reference-table-analysis.json")

        let report = AddonProbeTweakDBReferenceTableAnalysisReport(
            filePath: fileURL.path,
            stringsAnalysisPath: stringsAnalysisURL.path,
            size: bytes.count,
            packedStringCount: packed.count,
            queries: queries,
            aroundOffsets: requestedAroundOffsets,
            tableReportPath: tableReportURL.path,
            queryNeighborhoodsPath: queryNeighborhoodsURL.path,
            reportPath: reportURL.path,
            candidateTables: candidates,
            aroundOffsetAnalyses: aroundOffsetAnalyses,
            queryNeighborhoods: queryNeighborhoods,
            conclusions: conclusions,
            warnings: [
                "Read-only analysis only. No game files were modified.",
                "Reference-table detection is heuristic and does not patch TweakDB.",
                "Rows are decoded as little-endian u32 fields for candidate widths 8, 12, 16, 20, and 24."
            ]
        )

        try Self.writeTableReport(candidates, to: tableReportURL)
        try Self.writeQueryNeighborhoods(queryNeighborhoods, to: queryNeighborhoodsURL)
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    private enum PackedOffsetKind: String {
        case stringOffset
        case tagOffset
    }

    private struct PackedOffsetTarget {
        let kind: PackedOffsetKind
        let packed: AddonProbeTweakDBPackedString
    }

    private struct CandidateDraft: Hashable {
        let startOffset: Int
        let endOffset: Int
        let rowWidth: Int
    }

    private static func offsetLookup(_ packed: [AddonProbeTweakDBPackedString]) -> [UInt32: [PackedOffsetTarget]] {
        var lookup: [UInt32: [PackedOffsetTarget]] = [:]
        for entry in packed {
            if entry.stringOffset >= 0 && entry.stringOffset <= Int(UInt32.max) {
                lookup[UInt32(entry.stringOffset), default: []].append(PackedOffsetTarget(kind: .stringOffset, packed: entry))
            }
            if entry.tagOffset >= 0 && entry.tagOffset <= Int(UInt32.max) {
                lookup[UInt32(entry.tagOffset), default: []].append(PackedOffsetTarget(kind: .tagOffset, packed: entry))
            }
        }
        return lookup
    }

    private static func u32HitOffsets(bytes: [UInt8], offsetLookup: [UInt32: [PackedOffsetTarget]]) -> Set<Int> {
        guard bytes.count >= 4, !offsetLookup.isEmpty else { return [] }
        var hits = Set<Int>()
        hits.reserveCapacity(min(bytes.count / 32, 200_000))
        var offset = 0
        while offset <= bytes.count - 4 {
            if offsetLookup[readUInt32LE(bytes: bytes, offset: offset)] != nil {
                hits.insert(offset)
            }
            offset += 1
        }
        return hits
    }

    private static func detectCandidateTables(
        bytes: [UInt8],
        hitOffsets: Set<Int>,
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> [AddonProbeTweakDBReferenceTableCandidate] {
        guard !hitOffsets.isEmpty else { return [] }
        var seen = Set<CandidateDraft>()
        var candidates: [AddonProbeTweakDBReferenceTableCandidate] = []
        for rowWidth in rowWidths {
            let fieldCount = rowWidth / 4
            for hitOffset in hitOffsets.sorted() {
                for fieldIndex in 0..<fieldCount {
                    let rowStart = hitOffset - fieldIndex * 4
                    guard rowStart >= 0, rowStart + rowWidth <= bytes.count else { continue }
                    let start = rewindTableStart(rowStart: rowStart, rowWidth: rowWidth, bytes: bytes, hitOffsets: hitOffsets)
                    let end = advanceTableEnd(rowStart: start, rowWidth: rowWidth, bytes: bytes, hitOffsets: hitOffsets)
                    let rowCount = (end - start) / rowWidth
                    guard rowCount >= minCandidateRows else { continue }
                    let draft = CandidateDraft(startOffset: start, endOffset: end, rowWidth: rowWidth)
                    guard seen.insert(draft).inserted else { continue }
                    candidates.append(makeCandidate(
                        tableIndex: -1,
                        startOffset: start,
                        endOffset: end,
                        rowWidth: rowWidth,
                        bytes: bytes,
                        offsetLookup: offsetLookup
                    ))
                }
            }
        }
        return candidates.sorted(by: candidateSort)
    }

    private static func inferCandidatesAroundOffset(
        _ aroundOffset: Int,
        bytes: [UInt8],
        hitOffsets: Set<Int>,
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> [AddonProbeTweakDBReferenceTableCandidate] {
        guard aroundOffset >= 0, aroundOffset + 4 <= bytes.count, hitOffsets.contains(aroundOffset) else { return [] }
        var candidates: [AddonProbeTweakDBReferenceTableCandidate] = []
        var seen = Set<CandidateDraft>()
        for rowWidth in rowWidths {
            let fieldCount = rowWidth / 4
            for fieldIndex in 0..<fieldCount {
                let rowStart = aroundOffset - fieldIndex * 4
                guard rowStart >= 0, rowStart + rowWidth <= bytes.count else { continue }
                let start = rewindTableStart(rowStart: rowStart, rowWidth: rowWidth, bytes: bytes, hitOffsets: hitOffsets)
                let end = advanceTableEnd(rowStart: start, rowWidth: rowWidth, bytes: bytes, hitOffsets: hitOffsets)
                let rowCount = (end - start) / rowWidth
                guard rowCount >= 1 else { continue }
                let draft = CandidateDraft(startOffset: start, endOffset: end, rowWidth: rowWidth)
                guard seen.insert(draft).inserted else { continue }
                candidates.append(makeCandidate(
                    tableIndex: -1,
                    startOffset: start,
                    endOffset: end,
                    rowWidth: rowWidth,
                    bytes: bytes,
                    offsetLookup: offsetLookup
                ))
            }
        }
        return candidates.sorted(by: candidateSort)
    }

    private static func rewindTableStart(rowStart: Int, rowWidth: Int, bytes: [UInt8], hitOffsets: Set<Int>) -> Int {
        var start = rowStart
        while start - rowWidth >= 0, rowHasHit(rowOffset: start - rowWidth, rowWidth: rowWidth, bytesCount: bytes.count, hitOffsets: hitOffsets) {
            start -= rowWidth
        }
        return start
    }

    private static func advanceTableEnd(rowStart: Int, rowWidth: Int, bytes: [UInt8], hitOffsets: Set<Int>) -> Int {
        var end = rowStart
        while end + rowWidth <= bytes.count, rowHasHit(rowOffset: end, rowWidth: rowWidth, bytesCount: bytes.count, hitOffsets: hitOffsets) {
            end += rowWidth
        }
        return end
    }

    private static func rowHasHit(rowOffset: Int, rowWidth: Int, bytesCount: Int, hitOffsets: Set<Int>) -> Bool {
        guard rowOffset >= 0, rowOffset + rowWidth <= bytesCount else { return false }
        for fieldOffset in stride(from: rowOffset, to: rowOffset + rowWidth, by: 4) where hitOffsets.contains(fieldOffset) {
            return true
        }
        return false
    }

    private static func makeCandidate(
        tableIndex: Int,
        startOffset: Int,
        endOffset: Int,
        rowWidth: Int,
        bytes: [UInt8],
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> AddonProbeTweakDBReferenceTableCandidate {
        let rowCount = max(0, (endOffset - startOffset) / rowWidth)
        var hitCount = 0
        var hitRows = 0
        var pointingFields = Set<Int>()
        var kinds = Set<PackedOffsetKind>()
        for rowIndex in 0..<rowCount {
            let rowOffset = startOffset + rowIndex * rowWidth
            var rowHadHit = false
            for fieldIndex in 0..<(rowWidth / 4) {
                let fieldOffset = rowOffset + fieldIndex * 4
                guard fieldOffset + 4 <= bytes.count else { continue }
                let value = readUInt32LE(bytes: bytes, offset: fieldOffset)
                guard let targets = offsetLookup[value] else { continue }
                rowHadHit = true
                hitCount += targets.count
                pointingFields.insert(fieldIndex)
                for target in targets {
                    kinds.insert(target.kind)
                }
            }
            if rowHadHit { hitRows += 1 }
        }
        let kind: AddonProbeTweakDBReferenceTableKind
        if kinds == [.stringOffset] {
            kind = .stringOffsetTable
        } else if kinds == [.tagOffset] {
            kind = .tagOffsetTable
        } else if !kinds.isEmpty {
            kind = .mixedOffsetTable
        } else {
            kind = .unknownReferenceTable
        }
        return AddonProbeTweakDBReferenceTableCandidate(
            tableIndex: tableIndex,
            startOffset: startOffset,
            endOffset: endOffset,
            rowWidth: rowWidth,
            rowCount: rowCount,
            pointingFieldIndexes: pointingFields.sorted(),
            hitCount: hitCount,
            hitDensity: rowCount == 0 ? 0 : Double(hitRows) / Double(rowCount),
            kind: kind,
            sampleRows: sampleRows(
                startOffset: startOffset,
                rowWidth: rowWidth,
                rowCount: rowCount,
                bytes: bytes,
                offsetLookup: offsetLookup
            )
        )
    }

    private static func sampleRows(
        startOffset: Int,
        rowWidth: Int,
        rowCount: Int,
        bytes: [UInt8],
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> [AddonProbeTweakDBReferenceTableRow] {
        guard rowCount > 0 else { return [] }
        var indexes = Array(0..<min(rowCount, maxSampleRows))
        if rowCount > maxSampleRows {
            indexes.append(rowCount / 2)
            indexes.append(rowCount - 1)
        }
        return orderedUniqueInts(indexes).prefix(maxSampleRows).map { rowIndex in
            resolvedRow(
                offset: startOffset + rowIndex * rowWidth,
                rowIndex: rowIndex,
                rowWidth: rowWidth,
                bytes: bytes,
                offsetLookup: offsetLookup
            )
        }
    }

    private static func resolvedRow(
        offset: Int,
        rowIndex: Int?,
        rowWidth: Int,
        bytes: [UInt8],
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> AddonProbeTweakDBReferenceTableRow {
        let fieldCount = rowWidth / 4
        let fields = (0..<fieldCount).map { fieldIndex in
            let fieldOffset = offset + fieldIndex * 4
            let value = fieldOffset >= 0 && fieldOffset + 4 <= bytes.count ? readUInt32LE(bytes: bytes, offset: fieldOffset) : 0
            let targets = offsetLookup[value] ?? []
            return AddonProbeTweakDBReferenceTableField(
                index: fieldIndex,
                rawUInt32: value,
                pointsToKind: Self.targetKindDescription(targets),
                pointsToOffset: targets.isEmpty ? nil : Int(value),
                string: targets.first?.packed.string
            )
        }
        return AddonProbeTweakDBReferenceTableRow(offset: offset, rowIndex: rowIndex, fields: fields)
    }

    private static func targetKindDescription(_ targets: [PackedOffsetTarget]) -> String? {
        let kinds = Set(targets.map(\.kind))
        if kinds == [.stringOffset] { return PackedOffsetKind.stringOffset.rawValue }
        if kinds == [.tagOffset] { return PackedOffsetKind.tagOffset.rawValue }
        return kinds.isEmpty ? nil : "mixed"
    }

    private static func deduplicatedCandidates(_ candidates: [AddonProbeTweakDBReferenceTableCandidate]) -> [AddonProbeTweakDBReferenceTableCandidate] {
        var seen = Set<CandidateDraft>()
        var result: [AddonProbeTweakDBReferenceTableCandidate] = []
        for candidate in candidates.sorted(by: candidateSort) {
            let draft = CandidateDraft(startOffset: candidate.startOffset, endOffset: candidate.endOffset, rowWidth: candidate.rowWidth)
            if seen.insert(draft).inserted {
                result.append(candidate)
            }
        }
        return result
    }

    private static func assignTableIndexes(_ candidates: [AddonProbeTweakDBReferenceTableCandidate]) -> [AddonProbeTweakDBReferenceTableCandidate] {
        candidates.enumerated().map { index, candidate in
            AddonProbeTweakDBReferenceTableCandidate(
                tableIndex: index,
                startOffset: candidate.startOffset,
                endOffset: candidate.endOffset,
                rowWidth: candidate.rowWidth,
                rowCount: candidate.rowCount,
                pointingFieldIndexes: candidate.pointingFieldIndexes,
                hitCount: candidate.hitCount,
                hitDensity: candidate.hitDensity,
                kind: candidate.kind,
                sampleRows: candidate.sampleRows
            )
        }
    }

    private static func matchingTableIndexes(
        for inferred: [AddonProbeTweakDBReferenceTableCandidate],
        in candidates: [AddonProbeTweakDBReferenceTableCandidate]
    ) -> [Int] {
        let drafts = Set(inferred.map { CandidateDraft(startOffset: $0.startOffset, endOffset: $0.endOffset, rowWidth: $0.rowWidth) })
        return candidates.filter { drafts.contains(CandidateDraft(startOffset: $0.startOffset, endOffset: $0.endOffset, rowWidth: $0.rowWidth)) }
            .map(\.tableIndex)
            .sorted()
    }

    private static func queryNeighborhoods(
        queries: [String],
        stringsAnalysis: AddonProbeTweakDBPackedStringAnalysisReport,
        candidates: [AddonProbeTweakDBReferenceTableCandidate],
        bytes: [UInt8],
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> [AddonProbeTweakDBQueryReferenceNeighborhood] {
        let packedByString = Dictionary(grouping: stringsAnalysis.packedStrings, by: \.string)
        var neighborhoods: [AddonProbeTweakDBQueryReferenceNeighborhood] = []
        for query in queries {
            let packedMatches = packedByString[query] ?? []
            let references = stringsAnalysis.queryReports.first { $0.query == query }?.references ?? []
            for entry in packedMatches {
                for reference in references {
                    let containing = candidates.filter { reference.offset >= $0.startOffset && reference.offset < $0.endOffset }
                    let best = containing.first
                    let rowOffset = best.map { $0.startOffset + ((reference.offset - $0.startOffset) / $0.rowWidth) * $0.rowWidth }
                    let rowIndex = best.flatMap { table -> Int? in
                        guard let rowOffset else { return nil }
                        return (rowOffset - table.startOffset) / table.rowWidth
                    }
                    let previousRows: [AddonProbeTweakDBReferenceTableRow]
                    let nextRows: [AddonProbeTweakDBReferenceTableRow]
                    if let best, let rowIndex {
                        previousRows = Self.neighborRows(
                            table: best,
                            centerRowIndex: rowIndex,
                            range: max(0, rowIndex - queryNeighborRows)..<rowIndex,
                            bytes: bytes,
                            offsetLookup: offsetLookup
                        )
                        nextRows = Self.neighborRows(
                            table: best,
                            centerRowIndex: rowIndex,
                            range: (rowIndex + 1)..<min(best.rowCount, rowIndex + 1 + queryNeighborRows),
                            bytes: bytes,
                            offsetLookup: offsetLookup
                        )
                    } else {
                        previousRows = []
                        nextRows = []
                    }
                    neighborhoods.append(AddonProbeTweakDBQueryReferenceNeighborhood(
                        query: query,
                        stringOffset: entry.stringOffset,
                        tagOffset: entry.tagOffset,
                        referenceOffset: reference.offset,
                        referenceKind: reference.kind,
                        candidateTableIndexes: containing.map(\.tableIndex).sorted(),
                        rowOffset: rowOffset,
                        rowIndex: rowIndex,
                        previousRows: previousRows,
                        nextRows: nextRows
                    ))
                }
            }
        }
        return neighborhoods
    }

    private static func neighborRows(
        table: AddonProbeTweakDBReferenceTableCandidate,
        centerRowIndex: Int,
        range: Range<Int>,
        bytes: [UInt8],
        offsetLookup: [UInt32: [PackedOffsetTarget]]
    ) -> [AddonProbeTweakDBReferenceTableRow] {
        range.map { rowIndex in
            resolvedRow(
                offset: table.startOffset + rowIndex * table.rowWidth,
                rowIndex: rowIndex,
                rowWidth: table.rowWidth,
                bytes: bytes,
                offsetLookup: offsetLookup
            )
        }
    }

    private static func knownReferenceOffsets(
        queries: [String],
        stringsAnalysis: AddonProbeTweakDBPackedStringAnalysisReport
    ) -> [Int] {
        var offsets: [Int] = []
        for report in stringsAnalysis.queryReports where queries.contains(report.query) {
            offsets.append(contentsOf: report.references.map(\.offset))
        }
        return orderedUniqueInts(offsets)
    }

    private static func conclusions(
        candidates: [AddonProbeTweakDBReferenceTableCandidate],
        queryNeighborhoods: [AddonProbeTweakDBQueryReferenceNeighborhood]
    ) -> [AddonProbeTweakDBReferenceTableConclusion] {
        var conclusions: [AddonProbeTweakDBReferenceTableConclusion] = []
        if !candidates.isEmpty { conclusions.append(.referenceTablesFound) }
        if queryNeighborhoods.contains(where: { !$0.candidateTableIndexes.isEmpty }) {
            conclusions.append(.queryReferenceTablesMapped)
        }
        if candidates.contains(where: { $0.kind == .stringOffsetTable || $0.kind == .mixedOffsetTable }) {
            conclusions.append(.likelyStringOffsetTable)
        }
        if candidates.contains(where: { $0.kind == .tagOffsetTable || $0.kind == .mixedOffsetTable }) {
            conclusions.append(.likelyTagOffsetTable)
        }
        if conclusions.isEmpty { conclusions.append(.unresolved) }
        return conclusions
    }

    private static func candidateSort(_ lhs: AddonProbeTweakDBReferenceTableCandidate, _ rhs: AddonProbeTweakDBReferenceTableCandidate) -> Bool {
        if lhs.hitCount != rhs.hitCount { return lhs.hitCount > rhs.hitCount }
        if lhs.hitDensity != rhs.hitDensity { return lhs.hitDensity > rhs.hitDensity }
        if lhs.rowWidth != rhs.rowWidth { return lhs.rowWidth < rhs.rowWidth }
        if (lhs.pointingFieldIndexes.first ?? Int.max) != (rhs.pointingFieldIndexes.first ?? Int.max) {
            return (lhs.pointingFieldIndexes.first ?? Int.max) < (rhs.pointingFieldIndexes.first ?? Int.max)
        }
        return lhs.startOffset < rhs.startOffset
    }

    private static func normalizedQueries(_ queries: [String], fallback: [String]) -> [String] {
        let cleaned = orderedUniqueStrings(queries)
        return cleaned.isEmpty ? orderedUniqueStrings(fallback) : cleaned
    }

    private static func orderedUniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    private static func orderedUniqueInts(_ values: [Int]) -> [Int] {
        var seen = Set<Int>()
        var result: [Int] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
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

    private static func loadStringsAnalysis(_ url: URL) throws -> AddonProbeTweakDBPackedStringAnalysisReport {
        let data = try Data(contentsOf: url)
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
            throw CyberMacError.invalidInput("Refusing to write reference-table analysis output inside the game app: \(outputPath)")
        }
    }

    private static func readUInt32LE(bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }

    private static func writeTableReport(_ candidates: [AddonProbeTweakDBReferenceTableCandidate], to url: URL) throws {
        var lines: [String] = ["CyberMac TweakDB reference table candidates", "Status: read-only; no game files were modified.", ""]
        for table in candidates {
            lines.append("[table \(table.tableIndex)] \(table.kind.rawValue) \(table.startOffset)..<\(table.endOffset) width=\(table.rowWidth) rows=\(table.rowCount) hits=\(table.hitCount) density=\(String(format: "%.3f", table.hitDensity)) fields=\(table.pointingFieldIndexes.map(String.init).joined(separator: ","))")
            for row in table.sampleRows {
                lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.offset): \(Self.rowSummary(row))")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeQueryNeighborhoods(_ neighborhoods: [AddonProbeTweakDBQueryReferenceNeighborhood], to url: URL) throws {
        var lines: [String] = ["CyberMac TweakDB query reference neighborhoods", "Status: read-only; no game files were modified.", ""]
        for neighborhood in neighborhoods {
            lines.append("[query] \(neighborhood.query) ref=\(neighborhood.referenceOffset) kind=\(neighborhood.referenceKind.rawValue) stringOffset=\(neighborhood.stringOffset) tagOffset=\(neighborhood.tagOffset)")
            lines.append("tables: \(neighborhood.candidateTableIndexes.map(String.init).joined(separator: ",")) rowOffset=\(neighborhood.rowOffset.map(String.init) ?? "?") rowIndex=\(neighborhood.rowIndex.map(String.init) ?? "?")")
            if !neighborhood.previousRows.isEmpty {
                lines.append("previous rows:")
                for row in neighborhood.previousRows {
                    lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.offset): \(Self.rowSummary(row))")
                }
            }
            if !neighborhood.nextRows.isEmpty {
                lines.append("next rows:")
                for row in neighborhood.nextRows {
                    lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.offset): \(Self.rowSummary(row))")
                }
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func rowSummary(_ row: AddonProbeTweakDBReferenceTableRow) -> String {
        row.fields.map { field in
            var text = "f\(field.index)=\(field.rawUInt32)"
            if let pointsToKind = field.pointsToKind, let string = field.string {
                text += "->\(pointsToKind):\(string)"
            }
            return text
        }.joined(separator: " | ")
    }
}

public enum AddonProbeTweakDBReferenceTableAnalysisFormatter {
    public static func format(_ report: AddonProbeTweakDBReferenceTableAnalysisReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB reference-table analysis",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Strings analysis: \(PathSafety.redactUserPath(report.stringsAnalysisPath))",
            "Size: \(report.size)",
            "Packed strings: \(report.packedStringCount)",
            "Candidate tables: \(report.candidateTables.count)",
            "Query neighborhoods: \(report.queryNeighborhoods.count)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Tables: \(PathSafety.redactUserPath(report.tableReportPath))",
            "Neighborhoods: \(PathSafety.redactUserPath(report.queryNeighborhoodsPath))"
        ]
        appendList("Queries", report.queries, to: &lines)
        if !report.aroundOffsets.isEmpty {
            appendList("Manual around offsets", report.aroundOffsets.map(String.init), to: &lines)
        }
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBReferenceTableAnalysisReport) throws -> String {
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
