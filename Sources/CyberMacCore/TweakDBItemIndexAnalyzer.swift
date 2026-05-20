import Foundation

public struct AddonProbeTweakDBItemIndexAnalysisRequest: Sendable {
    public let fileURL: URL
    public let stringsAnalysisURL: URL
    public let outputDirectoryURL: URL
    public let queries: [String]
    public let referenceLimit: Int

    public init(
        fileURL: URL,
        stringsAnalysisURL: URL,
        outputDirectoryURL: URL,
        queries: [String] = [],
        referenceLimit: Int = TweakDBItemIndexAnalyzer.defaultReferenceLimit
    ) {
        self.fileURL = fileURL
        self.stringsAnalysisURL = stringsAnalysisURL
        self.outputDirectoryURL = outputDirectoryURL
        self.queries = queries
        self.referenceLimit = referenceLimit
    }
}

public enum AddonProbeTweakDBItemReferenceKind: String, Codable, Equatable, Sendable {
    case stringOffset
    case tagOffset
}

public enum AddonProbeTweakDBItemIndexRegionKind: String, Codable, Equatable, Sendable {
    case mostlyStringOffset
    case mostlyTagOffset
    case mixedOffset
}

public enum AddonProbeTweakDBItemIndexConclusion: String, Codable, Equatable, Sendable {
    case itemPackedStringsFound
    case itemReferencesFound
    case itemIndexRegionsFound
    case queryItemsMapped
    case queryItemsUnmapped
    case unresolved
}

public struct AddonProbeTweakDBItemReferenceWindowValue: Codable, Equatable, Sendable {
    public let offset: Int
    public let rawUInt32: UInt32
    public let resolvedItem: String?
    public let resolvedKind: AddonProbeTweakDBItemReferenceKind?
}

public struct AddonProbeTweakDBItemReference: Codable, Equatable, Sendable {
    public let refOffset: Int
    public let item: String
    public let kind: AddonProbeTweakDBItemReferenceKind
    public let referencedOffset: Int
    public let localU32Window: [AddonProbeTweakDBItemReferenceWindowValue]
}

public struct AddonProbeTweakDBItemIndexField: Codable, Equatable, Sendable {
    public let index: Int
    public let rawUInt32: UInt32
    public let resolvedItem: String?
    public let resolvedKind: AddonProbeTweakDBItemReferenceKind?
}

public struct AddonProbeTweakDBItemIndexRow: Codable, Equatable, Sendable {
    public let rowOffset: Int
    public let rowIndex: Int?
    public let fields: [AddonProbeTweakDBItemIndexField]
}

public struct AddonProbeTweakDBItemIndexRegion: Codable, Equatable, Sendable {
    public let regionIndex: Int
    public let startOffset: Int
    public let endOffset: Int
    public let hitCount: Int
    public let uniqueItemCount: Int
    public let likelyRowWidth: Int
    public let likelyFieldIndex: Int
    public let kind: AddonProbeTweakDBItemIndexRegionKind
    public let hitDensity: Double
    public let sampleRows: [AddonProbeTweakDBItemIndexRow]
}

public struct AddonProbeTweakDBItemReferenceSummaryEntry: Codable, Equatable, Sendable {
    public let item: String
    public let totalReferenceCount: Int
    public let stringOffsetReferenceCount: Int
    public let tagOffsetReferenceCount: Int
}

public struct AddonProbeTweakDBItemReferenceSummary: Codable, Equatable, Sendable {
    public let itemPackedStringCount: Int
    public let itemsWithStringOffsetReferences: Int
    public let itemsWithTagOffsetReferences: Int
    public let totalReferences: Int
    public let topReferencedItems: [AddonProbeTweakDBItemReferenceSummaryEntry]
    public let recordsWithNoRefs: [String]
}

public struct AddonProbeTweakDBQueryItemReferenceNeighborhood: Codable, Equatable, Sendable {
    public let reference: AddonProbeTweakDBItemReference
    public let containingRegionIndex: Int?
    public let likelyRowWidth: Int?
    public let alignedRowStart: Int?
    public let rowIndex: Int?
    public let previousRows: [AddonProbeTweakDBItemIndexRow]
    public let currentRow: AddonProbeTweakDBItemIndexRow?
    public let nextRows: [AddonProbeTweakDBItemIndexRow]
}

public struct AddonProbeTweakDBQueryItemReport: Codable, Equatable, Sendable {
    public let query: String
    public let packedStrings: [AddonProbeTweakDBPackedString]
    public let totalReferenceCount: Int
    public let references: [AddonProbeTweakDBItemReference]
    public let referencesTruncated: Bool
    public let neighborhoods: [AddonProbeTweakDBQueryItemReferenceNeighborhood]
}

public struct AddonProbeTweakDBItemIndexAnalysisReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let stringsAnalysisPath: String
    public let size: Int
    public let queries: [String]
    public let referenceLimit: Int
    public let itemReferenceSummaryPath: String
    public let itemIndexRegionsPath: String
    public let queryItemNeighborhoodsPath: String
    public let itemReferencesTSVPath: String
    public let reportPath: String
    public let summary: AddonProbeTweakDBItemReferenceSummary
    public let itemReferences: [AddonProbeTweakDBItemReference]
    public let indexRegions: [AddonProbeTweakDBItemIndexRegion]
    public let queryReports: [AddonProbeTweakDBQueryItemReport]
    public let conclusions: [AddonProbeTweakDBItemIndexConclusion]
    public let warnings: [String]
}

public struct TweakDBItemIndexAnalyzer: Sendable {
    public static let defaultReferenceLimit = 100

    private static let rowWidths = [8, 12, 16, 20, 24]
    private static let regionGapLimit = 64
    private static let minRegionReferences = 5
    private static let sampleRowsPerRegion = 8
    private static let queryNeighborRows = 10
    private static let localWindowRadius = 3

    public init() {}

    public func analyze(request: AddonProbeTweakDBItemIndexAnalysisRequest) throws -> AddonProbeTweakDBItemIndexAnalysisReport {
        guard request.referenceLimit >= 0 else {
            throw CyberMacError.invalidInput("--reference-limit must be a non-negative integer: \(request.referenceLimit)")
        }

        let fileURL = request.fileURL.standardizedFileURL
        let stringsAnalysisURL = request.stringsAnalysisURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let bytes = [UInt8](data)
        let stringsAnalysis = try Self.loadStringsAnalysis(stringsAnalysisURL)
        let itemPackedStrings = stringsAnalysis.packedStrings.filter { $0.string.hasPrefix("Items.") }
        let itemLookup = Self.itemOffsetLookup(itemPackedStrings)
        let queries = Self.normalizedItemQueries(request.queries)
        let itemReferences = Self.scanItemReferences(bytes: bytes, itemLookup: itemLookup)
        let referencesByItem = Dictionary(grouping: itemReferences, by: \.item)
        let queryItems = Set(queries)
        let indexRegions = Self.itemIndexRegions(
            references: itemReferences,
            queryItems: queryItems,
            bytes: bytes,
            itemLookup: itemLookup
        )
        let queryReports = Self.queryReports(
            queries: queries,
            itemPackedStrings: itemPackedStrings,
            referencesByItem: referencesByItem,
            regions: indexRegions,
            bytes: bytes,
            itemLookup: itemLookup,
            referenceLimit: request.referenceLimit
        )
        let summary = Self.referenceSummary(
            itemPackedStrings: itemPackedStrings,
            referencesByItem: referencesByItem,
            referenceLimit: request.referenceLimit
        )
        let conclusions = Self.conclusions(
            itemPackedStrings: itemPackedStrings,
            itemReferences: itemReferences,
            indexRegions: indexRegions,
            queryReports: queryReports
        )

        let summaryURL = outputDirectoryURL.appendingPathComponent("tweakdb-item-reference-summary.txt")
        let regionsURL = outputDirectoryURL.appendingPathComponent("tweakdb-item-index-regions.txt")
        let neighborhoodsURL = outputDirectoryURL.appendingPathComponent("tweakdb-query-item-neighborhoods.txt")
        let referencesTSVURL = outputDirectoryURL.appendingPathComponent("tweakdb-item-references.tsv")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-item-index-analysis.json")

        let report = AddonProbeTweakDBItemIndexAnalysisReport(
            filePath: fileURL.path,
            stringsAnalysisPath: stringsAnalysisURL.path,
            size: bytes.count,
            queries: queries,
            referenceLimit: request.referenceLimit,
            itemReferenceSummaryPath: summaryURL.path,
            itemIndexRegionsPath: regionsURL.path,
            queryItemNeighborhoodsPath: neighborhoodsURL.path,
            itemReferencesTSVPath: referencesTSVURL.path,
            reportPath: reportURL.path,
            summary: summary,
            itemReferences: itemReferences,
            indexRegions: indexRegions,
            queryReports: queryReports,
            conclusions: conclusions,
            warnings: [
                "Read-only analysis only. No game files were modified.",
                "Item index detection only uses packed strings whose value starts with Items.",
                "Candidate regions are heuristic groupings of direct u32 references to item string/tag offsets."
            ]
        )

        try Self.writeSummary(report, to: summaryURL)
        try Self.writeRegions(indexRegions, to: regionsURL)
        try Self.writeQueryNeighborhoods(queryReports, to: neighborhoodsURL)
        try Self.writeReferencesTSV(itemReferences, to: referencesTSVURL)
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    private struct ItemOffsetTarget {
        let item: String
        let kind: AddonProbeTweakDBItemReferenceKind
    }

    private struct RegionInference {
        let rowWidth: Int
        let fieldIndex: Int
        let rowStartResidue: Int
        let alignedHitCount: Int
    }

    private struct RegionGroup {
        let references: [AddonProbeTweakDBItemReference]
        let containsQueryItem: Bool
    }

    private static func itemOffsetLookup(_ packed: [AddonProbeTweakDBPackedString]) -> [UInt32: [ItemOffsetTarget]] {
        var lookup: [UInt32: [ItemOffsetTarget]] = [:]
        for entry in packed {
            if entry.stringOffset >= 0 && entry.stringOffset <= Int(UInt32.max) {
                lookup[UInt32(entry.stringOffset), default: []].append(ItemOffsetTarget(item: entry.string, kind: .stringOffset))
            }
            if entry.tagOffset >= 0 && entry.tagOffset <= Int(UInt32.max) {
                lookup[UInt32(entry.tagOffset), default: []].append(ItemOffsetTarget(item: entry.string, kind: .tagOffset))
            }
        }
        return lookup
    }

    private static func scanItemReferences(
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> [AddonProbeTweakDBItemReference] {
        guard bytes.count >= 4, !itemLookup.isEmpty else { return [] }
        var references: [AddonProbeTweakDBItemReference] = []
        var offset = 0
        while offset <= bytes.count - 4 {
            let value = readUInt32LE(bytes: bytes, offset: offset)
            if let targets = itemLookup[value] {
                let window = localU32Window(centerOffset: offset, bytes: bytes, itemLookup: itemLookup)
                for target in targets {
                    references.append(AddonProbeTweakDBItemReference(
                        refOffset: offset,
                        item: target.item,
                        kind: target.kind,
                        referencedOffset: Int(value),
                        localU32Window: window
                    ))
                }
            }
            offset += 1
        }
        return references.sorted {
            if $0.refOffset != $1.refOffset { return $0.refOffset < $1.refOffset }
            if $0.item != $1.item { return $0.item < $1.item }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    private static func localU32Window(
        centerOffset: Int,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> [AddonProbeTweakDBItemReferenceWindowValue] {
        (-localWindowRadius...localWindowRadius).compactMap { index in
            let offset = centerOffset + index * 4
            guard offset >= 0, offset + 4 <= bytes.count else { return nil }
            let value = readUInt32LE(bytes: bytes, offset: offset)
            let target = itemLookup[value]?.first
            return AddonProbeTweakDBItemReferenceWindowValue(
                offset: offset,
                rawUInt32: value,
                resolvedItem: target?.item,
                resolvedKind: target?.kind
            )
        }
    }

    private static func itemIndexRegions(
        references: [AddonProbeTweakDBItemReference],
        queryItems: Set<String>,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> [AddonProbeTweakDBItemIndexRegion] {
        let groups = groupedReferences(references, queryItems: queryItems)
        let keptGroups = groups.filter {
            $0.references.count >= minRegionReferences || $0.containsQueryItem
        }
        let regions = keptGroups.enumerated().compactMap { index, group in
            makeRegion(index: index, group: group, bytes: bytes, itemLookup: itemLookup)
        }
        return regions.sorted {
            if $0.hitCount != $1.hitCount { return $0.hitCount > $1.hitCount }
            return $0.startOffset < $1.startOffset
        }.enumerated().map { index, region in
            AddonProbeTweakDBItemIndexRegion(
                regionIndex: index,
                startOffset: region.startOffset,
                endOffset: region.endOffset,
                hitCount: region.hitCount,
                uniqueItemCount: region.uniqueItemCount,
                likelyRowWidth: region.likelyRowWidth,
                likelyFieldIndex: region.likelyFieldIndex,
                kind: region.kind,
                hitDensity: region.hitDensity,
                sampleRows: region.sampleRows
            )
        }
    }

    private static func groupedReferences(
        _ references: [AddonProbeTweakDBItemReference],
        queryItems: Set<String>
    ) -> [RegionGroup] {
        guard !references.isEmpty else { return [] }
        var groups: [RegionGroup] = []
        var current: [AddonProbeTweakDBItemReference] = []
        var containsQuery = false
        var previousOffset: Int?
        for reference in references.sorted(by: { $0.refOffset < $1.refOffset }) {
            if let previousOffset, reference.refOffset - previousOffset > regionGapLimit {
                groups.append(RegionGroup(references: current, containsQueryItem: containsQuery))
                current = []
                containsQuery = false
            }
            current.append(reference)
            containsQuery = containsQuery || queryItems.contains(reference.item)
            previousOffset = reference.refOffset
        }
        if !current.isEmpty {
            groups.append(RegionGroup(references: current, containsQueryItem: containsQuery))
        }
        return groups
    }

    private static func makeRegion(
        index: Int,
        group: RegionGroup,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> AddonProbeTweakDBItemIndexRegion? {
        guard let inference = inferRowWidth(group.references) else { return nil }
        let rowStarts = group.references.map {
            alignedRowStart(
                refOffset: $0.refOffset,
                rowWidth: inference.rowWidth,
                rowStartResidue: inference.rowStartResidue
            )
        }
        guard let minRowStart = rowStarts.min(), let maxRowStart = rowStarts.max() else { return nil }
        let startOffset = max(0, minRowStart)
        let endOffset = min(bytes.count, maxRowStart + inference.rowWidth)
        let rowCount = max(1, (endOffset - startOffset + inference.rowWidth - 1) / inference.rowWidth)
        let rowStartsWithHits = Set(rowStarts)
        let hitDensity = Double(rowStartsWithHits.count) / Double(rowCount)
        let stringHits = group.references.filter { $0.kind == .stringOffset }.count
        let tagHits = group.references.filter { $0.kind == .tagOffset }.count
        let kind: AddonProbeTweakDBItemIndexRegionKind
        if stringHits > tagHits * 2 {
            kind = .mostlyStringOffset
        } else if tagHits > stringHits * 2 {
            kind = .mostlyTagOffset
        } else {
            kind = .mixedOffset
        }
        return AddonProbeTweakDBItemIndexRegion(
            regionIndex: index,
            startOffset: startOffset,
            endOffset: endOffset,
            hitCount: group.references.count,
            uniqueItemCount: Set(group.references.map(\.item)).count,
            likelyRowWidth: inference.rowWidth,
            likelyFieldIndex: inference.fieldIndex,
            kind: kind,
            hitDensity: hitDensity,
            sampleRows: sampleRows(
                startOffset: startOffset,
                rowWidth: inference.rowWidth,
                rowCount: rowCount,
                bytes: bytes,
                itemLookup: itemLookup
            )
        )
    }

    private static func inferRowWidth(_ references: [AddonProbeTweakDBItemReference]) -> RegionInference? {
        guard !references.isEmpty else { return nil }
        var best: RegionInference?
        for rowWidth in rowWidths {
            let fieldCount = rowWidth / 4
            for fieldIndex in 0..<fieldCount {
                var counts: [Int: Int] = [:]
                for reference in references {
                    let residue = positiveModulo(reference.refOffset - fieldIndex * 4, rowWidth)
                    counts[residue, default: 0] += 1
                }
                guard let (residue, count) = counts.max(by: { $0.value < $1.value }) else { continue }
                let candidate = RegionInference(
                    rowWidth: rowWidth,
                    fieldIndex: fieldIndex,
                    rowStartResidue: residue,
                    alignedHitCount: count
                )
                if isBetterInference(candidate, than: best) {
                    best = candidate
                }
            }
        }
        return best
    }

    private static func isBetterInference(_ candidate: RegionInference, than current: RegionInference?) -> Bool {
        guard let current else { return true }
        if candidate.alignedHitCount != current.alignedHitCount {
            return candidate.alignedHitCount > current.alignedHitCount
        }
        if candidate.rowWidth == 12 && current.rowWidth != 12 {
            return true
        }
        if candidate.rowWidth != current.rowWidth {
            return candidate.rowWidth < current.rowWidth
        }
        return candidate.fieldIndex < current.fieldIndex
    }

    private static func alignedRowStart(refOffset: Int, rowWidth: Int, rowStartResidue: Int) -> Int {
        refOffset - positiveModulo(refOffset - rowStartResidue, rowWidth)
    }

    private static func sampleRows(
        startOffset: Int,
        rowWidth: Int,
        rowCount: Int,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> [AddonProbeTweakDBItemIndexRow] {
        guard rowCount > 0 else { return [] }
        var indexes = Array(0..<min(rowCount, sampleRowsPerRegion))
        if rowCount > sampleRowsPerRegion {
            indexes.append(rowCount / 2)
            indexes.append(rowCount - 1)
        }
        return orderedUniqueInts(indexes).prefix(sampleRowsPerRegion).map { rowIndex in
            decodedRow(
                rowOffset: startOffset + rowIndex * rowWidth,
                rowIndex: rowIndex,
                rowWidth: rowWidth,
                bytes: bytes,
                itemLookup: itemLookup
            )
        }
    }

    private static func decodedRow(
        rowOffset: Int,
        rowIndex: Int?,
        rowWidth: Int,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> AddonProbeTweakDBItemIndexRow {
        let fields = (0..<(rowWidth / 4)).map { fieldIndex in
            let fieldOffset = rowOffset + fieldIndex * 4
            let value = fieldOffset >= 0 && fieldOffset + 4 <= bytes.count ? readUInt32LE(bytes: bytes, offset: fieldOffset) : 0
            let target = itemLookup[value]?.first
            return AddonProbeTweakDBItemIndexField(
                index: fieldIndex,
                rawUInt32: value,
                resolvedItem: target?.item,
                resolvedKind: target?.kind
            )
        }
        return AddonProbeTweakDBItemIndexRow(rowOffset: rowOffset, rowIndex: rowIndex, fields: fields)
    }

    private static func queryReports(
        queries: [String],
        itemPackedStrings: [AddonProbeTweakDBPackedString],
        referencesByItem: [String: [AddonProbeTweakDBItemReference]],
        regions: [AddonProbeTweakDBItemIndexRegion],
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]],
        referenceLimit: Int
    ) -> [AddonProbeTweakDBQueryItemReport] {
        let packedByString = Dictionary(grouping: itemPackedStrings, by: \.string)
        return queries.map { query in
            let allReferences = (referencesByItem[query] ?? []).sorted { $0.refOffset < $1.refOffset }
            let limitedReferences = referenceLimit == 0 ? [] : Array(allReferences.prefix(referenceLimit))
            let neighborhoods = limitedReferences.map { reference in
                queryNeighborhood(reference, regions: regions, bytes: bytes, itemLookup: itemLookup)
            }
            return AddonProbeTweakDBQueryItemReport(
                query: query,
                packedStrings: packedByString[query] ?? [],
                totalReferenceCount: allReferences.count,
                references: limitedReferences,
                referencesTruncated: allReferences.count > limitedReferences.count,
                neighborhoods: neighborhoods
            )
        }
    }

    private static func queryNeighborhood(
        _ reference: AddonProbeTweakDBItemReference,
        regions: [AddonProbeTweakDBItemIndexRegion],
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> AddonProbeTweakDBQueryItemReferenceNeighborhood {
        guard let region = regions.first(where: { reference.refOffset >= $0.startOffset && reference.refOffset < $0.endOffset }) else {
            return AddonProbeTweakDBQueryItemReferenceNeighborhood(
                reference: reference,
                containingRegionIndex: nil,
                likelyRowWidth: nil,
                alignedRowStart: nil,
                rowIndex: nil,
                previousRows: [],
                currentRow: nil,
                nextRows: []
            )
        }
        let rowIndex = max(0, (reference.refOffset - region.startOffset) / region.likelyRowWidth)
        let rowStart = region.startOffset + rowIndex * region.likelyRowWidth
        let previousRows = neighborRows(
            rowStart: rowStart,
            rowWidth: region.likelyRowWidth,
            deltas: Array((-queryNeighborRows)..<0),
            region: region,
            bytes: bytes,
            itemLookup: itemLookup
        )
        let nextRows = neighborRows(
            rowStart: rowStart,
            rowWidth: region.likelyRowWidth,
            deltas: Array(1...queryNeighborRows),
            region: region,
            bytes: bytes,
            itemLookup: itemLookup
        )
        return AddonProbeTweakDBQueryItemReferenceNeighborhood(
            reference: reference,
            containingRegionIndex: region.regionIndex,
            likelyRowWidth: region.likelyRowWidth,
            alignedRowStart: rowStart,
            rowIndex: rowIndex,
            previousRows: previousRows,
            currentRow: decodedRow(rowOffset: rowStart, rowIndex: rowIndex, rowWidth: region.likelyRowWidth, bytes: bytes, itemLookup: itemLookup),
            nextRows: nextRows
        )
    }

    private static func neighborRows(
        rowStart: Int,
        rowWidth: Int,
        deltas: [Int],
        region: AddonProbeTweakDBItemIndexRegion,
        bytes: [UInt8],
        itemLookup: [UInt32: [ItemOffsetTarget]]
    ) -> [AddonProbeTweakDBItemIndexRow] {
        deltas.compactMap { delta in
            let offset = rowStart + delta * rowWidth
            guard offset >= 0, offset + rowWidth <= bytes.count else { return nil }
            return decodedRow(
                rowOffset: offset,
                rowIndex: rowIndexInRegion(rowOffset: offset, region: region),
                rowWidth: rowWidth,
                bytes: bytes,
                itemLookup: itemLookup
            )
        }
    }

    private static func rowIndexInRegion(rowOffset: Int, region: AddonProbeTweakDBItemIndexRegion) -> Int? {
        guard rowOffset >= region.startOffset, rowOffset < region.endOffset else { return nil }
        return (rowOffset - region.startOffset) / region.likelyRowWidth
    }

    private static func referenceSummary(
        itemPackedStrings: [AddonProbeTweakDBPackedString],
        referencesByItem: [String: [AddonProbeTweakDBItemReference]],
        referenceLimit: Int
    ) -> AddonProbeTweakDBItemReferenceSummary {
        let itemNames = Set(itemPackedStrings.map(\.string))
        var entries: [AddonProbeTweakDBItemReferenceSummaryEntry] = []
        var stringRefItems = Set<String>()
        var tagRefItems = Set<String>()
        for item in itemNames {
            let references = referencesByItem[item] ?? []
            let stringCount = references.filter { $0.kind == .stringOffset }.count
            let tagCount = references.filter { $0.kind == .tagOffset }.count
            if stringCount > 0 { stringRefItems.insert(item) }
            if tagCount > 0 { tagRefItems.insert(item) }
            if !references.isEmpty {
                entries.append(AddonProbeTweakDBItemReferenceSummaryEntry(
                    item: item,
                    totalReferenceCount: references.count,
                    stringOffsetReferenceCount: stringCount,
                    tagOffsetReferenceCount: tagCount
                ))
            }
        }
        let sortedEntries = entries.sorted {
            if $0.totalReferenceCount != $1.totalReferenceCount { return $0.totalReferenceCount > $1.totalReferenceCount }
            return $0.item < $1.item
        }
        let recordsWithNoRefs = itemNames
            .filter { referencesByItem[$0]?.isEmpty ?? true }
            .sorted()
        let topLimit = referenceLimit == 0 ? defaultReferenceLimit : referenceLimit
        return AddonProbeTweakDBItemReferenceSummary(
            itemPackedStringCount: itemPackedStrings.count,
            itemsWithStringOffsetReferences: stringRefItems.count,
            itemsWithTagOffsetReferences: tagRefItems.count,
            totalReferences: referencesByItem.values.reduce(0) { $0 + $1.count },
            topReferencedItems: Array(sortedEntries.prefix(topLimit)),
            recordsWithNoRefs: recordsWithNoRefs
        )
    }

    private static func conclusions(
        itemPackedStrings: [AddonProbeTweakDBPackedString],
        itemReferences: [AddonProbeTweakDBItemReference],
        indexRegions: [AddonProbeTweakDBItemIndexRegion],
        queryReports: [AddonProbeTweakDBQueryItemReport]
    ) -> [AddonProbeTweakDBItemIndexConclusion] {
        var conclusions: [AddonProbeTweakDBItemIndexConclusion] = []
        if !itemPackedStrings.isEmpty { conclusions.append(.itemPackedStringsFound) }
        if !itemReferences.isEmpty { conclusions.append(.itemReferencesFound) }
        if !indexRegions.isEmpty { conclusions.append(.itemIndexRegionsFound) }
        if queryReports.contains(where: { !$0.neighborhoods.isEmpty && $0.neighborhoods.contains { $0.containingRegionIndex != nil } }) {
            conclusions.append(.queryItemsMapped)
        }
        if queryReports.contains(where: { $0.totalReferenceCount == 0 || $0.neighborhoods.allSatisfy { $0.containingRegionIndex == nil } }) {
            conclusions.append(.queryItemsUnmapped)
        }
        if conclusions.isEmpty { conclusions.append(.unresolved) }
        return conclusions
    }

    private static func normalizedItemQueries(_ queries: [String]) -> [String] {
        orderedUniqueStrings(queries).filter { $0.hasPrefix("Items.") }
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

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
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
            throw CyberMacError.invalidInput("Refusing to write item-index analysis output inside the game app: \(outputPath)")
        }
    }

    private static func readUInt32LE(bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }

    private static func writeSummary(_ report: AddonProbeTweakDBItemIndexAnalysisReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB item-reference summary",
            "Status: read-only; no game files were modified.",
            "Item packed strings: \(report.summary.itemPackedStringCount)",
            "Items with stringOffset refs: \(report.summary.itemsWithStringOffsetReferences)",
            "Items with tagOffset refs: \(report.summary.itemsWithTagOffsetReferences)",
            "Total item references: \(report.summary.totalReferences)",
            "Item index regions: \(report.indexRegions.count)",
            ""
        ]
        lines.append("Top referenced items:")
        for entry in report.summary.topReferencedItems.prefix(report.referenceLimit == 0 ? defaultReferenceLimit : report.referenceLimit) {
            lines.append("- \(entry.item): total=\(entry.totalReferenceCount) string=\(entry.stringOffsetReferenceCount) tag=\(entry.tagOffsetReferenceCount)")
        }
        lines.append("")
        lines.append("Records with no refs: \(report.summary.recordsWithNoRefs.count)")
        for item in report.summary.recordsWithNoRefs.prefix(report.referenceLimit == 0 ? defaultReferenceLimit : report.referenceLimit) {
            lines.append("- \(item)")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeRegions(_ regions: [AddonProbeTweakDBItemIndexRegion], to url: URL) throws {
        var lines: [String] = ["CyberMac TweakDB item index regions", "Status: read-only; no game files were modified.", ""]
        for region in regions {
            lines.append("[region \(region.regionIndex)] \(region.kind.rawValue) \(region.startOffset)..<\(region.endOffset) width=\(region.likelyRowWidth) field=\(region.likelyFieldIndex) hits=\(region.hitCount) uniqueItems=\(region.uniqueItemCount) density=\(String(format: "%.3f", region.hitDensity))")
            for row in region.sampleRows {
                lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.rowOffset): \(rowSummary(row))")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeQueryNeighborhoods(_ reports: [AddonProbeTweakDBQueryItemReport], to url: URL) throws {
        var lines: [String] = ["CyberMac TweakDB query item neighborhoods", "Status: read-only; no game files were modified.", ""]
        for report in reports {
            lines.append("[query] \(report.query) packed=\(report.packedStrings.count) refs=\(report.totalReferenceCount) shown=\(report.references.count) truncated=\(report.referencesTruncated)")
            for neighborhood in report.neighborhoods {
                lines.append("ref \(neighborhood.reference.refOffset) \(neighborhood.reference.kind.rawValue) region=\(neighborhood.containingRegionIndex.map(String.init) ?? "?") rowStart=\(neighborhood.alignedRowStart.map(String.init) ?? "?") rowIndex=\(neighborhood.rowIndex.map(String.init) ?? "?")")
                if !neighborhood.previousRows.isEmpty {
                    lines.append("previous rows:")
                    for row in neighborhood.previousRows {
                        lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.rowOffset): \(rowSummary(row))")
                    }
                }
                if let currentRow = neighborhood.currentRow {
                    lines.append("current row:")
                    lines.append("  row \(currentRow.rowIndex.map(String.init) ?? "?") @ \(currentRow.rowOffset): \(rowSummary(currentRow))")
                }
                if !neighborhood.nextRows.isEmpty {
                    lines.append("next rows:")
                    for row in neighborhood.nextRows {
                        lines.append("  row \(row.rowIndex.map(String.init) ?? "?") @ \(row.rowOffset): \(rowSummary(row))")
                    }
                }
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeReferencesTSV(_ references: [AddonProbeTweakDBItemReference], to url: URL) throws {
        var lines = ["refOffset\titem\tkind\treferencedOffset\twindow"]
        for reference in references {
            let window = reference.localU32Window.map { value in
                var text = "\(value.offset):\(value.rawUInt32)"
                if let item = value.resolvedItem, let kind = value.resolvedKind {
                    text += "->\(kind.rawValue):\(tsvEscape(item))"
                }
                return text
            }.joined(separator: "|")
            lines.append("\(reference.refOffset)\t\(tsvEscape(reference.item))\t\(reference.kind.rawValue)\t\(reference.referencedOffset)\t\(window)")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func rowSummary(_ row: AddonProbeTweakDBItemIndexRow) -> String {
        row.fields.map { field in
            var text = "f\(field.index)=\(field.rawUInt32)"
            if let item = field.resolvedItem, let kind = field.resolvedKind {
                text += "->\(kind.rawValue):\(item)"
            }
            return text
        }.joined(separator: " | ")
    }

    private static func tsvEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

public enum AddonProbeTweakDBItemIndexAnalysisFormatter {
    public static func format(_ report: AddonProbeTweakDBItemIndexAnalysisReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB item-index analysis",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Strings analysis: \(PathSafety.redactUserPath(report.stringsAnalysisPath))",
            "Size: \(report.size)",
            "Item packed strings: \(report.summary.itemPackedStringCount)",
            "Total item references: \(report.summary.totalReferences)",
            "Item index regions: \(report.indexRegions.count)",
            "Query reports: \(report.queryReports.count)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Summary: \(PathSafety.redactUserPath(report.itemReferenceSummaryPath))",
            "Regions: \(PathSafety.redactUserPath(report.itemIndexRegionsPath))",
            "Neighborhoods: \(PathSafety.redactUserPath(report.queryItemNeighborhoodsPath))",
            "References TSV: \(PathSafety.redactUserPath(report.itemReferencesTSVPath))"
        ]
        appendList("Queries", report.queries, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBItemIndexAnalysisReport) throws -> String {
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
