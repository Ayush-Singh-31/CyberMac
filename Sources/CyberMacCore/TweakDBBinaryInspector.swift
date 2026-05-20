import Foundation

public struct AddonProbeTweakDBBinaryInspectRequest: Sendable {
    public let fileURL: URL
    public let outputDirectoryURL: URL
    public let queries: [String]

    public init(fileURL: URL, outputDirectoryURL: URL, queries: [String] = []) {
        self.fileURL = fileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.queries = queries
    }
}

public struct AddonProbeTweakDBBinaryCompareRequest: Sendable {
    public let baseURL: URL
    public let ep1URL: URL
    public let outputDirectoryURL: URL

    public init(baseURL: URL, ep1URL: URL, outputDirectoryURL: URL) {
        self.baseURL = baseURL
        self.ep1URL = ep1URL
        self.outputDirectoryURL = outputDirectoryURL
    }
}

public struct AddonProbeTweakDBBinaryHeaderWord: Codable, Equatable, Sendable {
    public let offset: Int
    public let u32LE: UInt32?
    public let u64LE: UInt64?
}

public struct AddonProbeTweakDBBinaryString: Codable, Equatable, Sendable {
    public let string: String
    public let offset: Int
    public let length: Int
}

public enum AddonProbeTweakDBBinaryMatchKind: String, Codable, Equatable, Sendable {
    case exactString
    case substringString
    case rawBytes
}

public struct AddonProbeTweakDBBinaryQueryMatch: Codable, Equatable, Sendable {
    public let query: String
    public let kind: AddonProbeTweakDBBinaryMatchKind
    public let string: String?
    public let stringOffset: Int?
    public let rawByteOffset: Int
    public let length: Int
    public let previousStrings: [AddonProbeTweakDBBinaryString]
    public let nextStrings: [AddonProbeTweakDBBinaryString]
    public let contextHexStartOffset: Int
    public let contextHex: String
    public let contextASCIIStartOffset: Int
    public let contextASCII: String
}

public struct AddonProbeTweakDBBinarySectionHint: Codable, Equatable, Sendable {
    public let kind: String
    public let startOffset: Int
    public let endOffset: Int
    public let evidenceCount: Int
    public let summary: String
    public let examples: [String]
}

public enum AddonProbeTweakDBBinaryConclusion: String, Codable, Equatable, Sendable {
    case plaintextRecordNamesFound
    case queryRecordsFound
    case noQueryRecordsFound
    case likelyHashIndexed
    case unresolved
}

public struct AddonProbeTweakDBBinaryInspectReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let size: Int
    public let sha256: String
    public let first256BytesHex: String
    public let magicHeaderValue: String
    public let headerWords: [AddonProbeTweakDBBinaryHeaderWord]
    public let queries: [String]
    public let stringCount: Int
    public let stringsTablePath: String
    public let queryMatchesPath: String
    public let sectionHintsPath: String
    public let contextDumpsPath: String
    public let reportPath: String
    public let queryMatches: [AddonProbeTweakDBBinaryQueryMatch]
    public let sectionHints: [AddonProbeTweakDBBinarySectionHint]
    public let conclusions: [AddonProbeTweakDBBinaryConclusion]
    public let warnings: [String]
}

public struct AddonProbeTweakDBBinarySummary: Codable, Equatable, Sendable {
    public let filePath: String
    public let size: Int
    public let sha256: String
    public let magicHeaderValue: String
    public let stringCount: Int
}

public struct AddonProbeTweakDBBinarySharedContext: Codable, Equatable, Sendable {
    public let string: String
    public let baseOffset: Int
    public let ep1Offset: Int
    public let baseContextHex: String
    public let ep1ContextHex: String
    public let baseContextASCII: String
    public let ep1ContextASCII: String
}

public struct AddonProbeTweakDBBinaryCompareReport: Codable, Equatable, Sendable {
    public let base: AddonProbeTweakDBBinarySummary
    public let ep1: AddonProbeTweakDBBinarySummary
    public let headersMatch: Bool
    public let baseHeaderWords: [AddonProbeTweakDBBinaryHeaderWord]
    public let ep1HeaderWords: [AddonProbeTweakDBBinaryHeaderWord]
    public let sharedStrings: [String]
    public let uniqueToBase: [String]
    public let uniqueToEP1: [String]
    public let sharedRecordContexts: [AddonProbeTweakDBBinarySharedContext]
    public let reportPath: String
    public let stringsComparisonPath: String
    public let contextComparisonPath: String
    public let warnings: [String]
}

public struct TweakDBBinaryInspector: Sendable {
    public static let defaultQueries = [
        "Items.GenericInnerChestClothing",
        "GenericInnerChestClothing",
        "Items.Skirt",
        "Items.TShirt_04_old_01",
        "Items.FormalSkirt_01_basic_02",
        "Items.Pants_10_rich_01",
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

    private static let stringMinimumLength = 4
    private static let contextHexRadius = 128
    private static let contextASCIIRadius = 512
    private static let maxMatchesPerQueryKind = 100
    private static let sharedRecordContextLimit = 500

    public init() {}

    public func inspect(request: AddonProbeTweakDBBinaryInspectRequest) throws -> AddonProbeTweakDBBinaryInspectReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let strings = Self.extractPrintableStrings(from: data)
        let queries = Self.normalizedQueries(request.queries)
        let queryResult = Self.queryMatches(queries: queries, strings: strings, data: data)
        let matches = queryResult.matches
        let hints = Self.sectionHints(strings: strings, data: data)
        let conclusions = Self.conclusions(strings: strings, matches: matches, hints: hints, queries: queries)

        let stringsTableURL = outputDirectoryURL.appendingPathComponent("tweakdb-strings.tsv")
        let queryMatchesURL = outputDirectoryURL.appendingPathComponent("tweakdb-query-matches.txt")
        let sectionHintsURL = outputDirectoryURL.appendingPathComponent("tweakdb-section-hints.txt")
        let contextDumpsURL = outputDirectoryURL.appendingPathComponent("tweakdb-context-dumps.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-bin-inspect.json")

        try Self.writeStrings(strings, to: stringsTableURL)
        try Self.writeQueryMatches(matches, to: queryMatchesURL)
        try Self.writeSectionHints(hints, to: sectionHintsURL)
        try Self.writeContextDumps(matches, to: contextDumpsURL)

        let report = AddonProbeTweakDBBinaryInspectReport(
            filePath: fileURL.path,
            size: data.count,
            sha256: try PathSafety.sha256(url: fileURL),
            first256BytesHex: Self.hex(data, range: 0..<min(256, data.count)),
            magicHeaderValue: Self.magicHeaderValue(data),
            headerWords: Self.headerWords(data),
            queries: queries,
            stringCount: strings.count,
            stringsTablePath: stringsTableURL.path,
            queryMatchesPath: queryMatchesURL.path,
            sectionHintsPath: sectionHintsURL.path,
            contextDumpsPath: contextDumpsURL.path,
            reportPath: reportURL.path,
            queryMatches: matches,
            sectionHints: hints,
            conclusions: conclusions,
            warnings: [
                "Read-only inspection only. No game files were modified.",
                "Section hints are conservative binary heuristics, not a TweakDB parser or patch plan."
            ] + queryResult.warnings
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func compare(request: AddonProbeTweakDBBinaryCompareRequest) throws -> AddonProbeTweakDBBinaryCompareReport {
        let baseURL = request.baseURL.standardizedFileURL
        let ep1URL = request.ep1URL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: baseURL, outputDirectoryURL: outputDirectoryURL)
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: ep1URL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let baseData = try Self.readData(baseURL)
        let ep1Data = try Self.readData(ep1URL)
        let baseStrings = Self.extractPrintableStrings(from: baseData)
        let ep1Strings = Self.extractPrintableStrings(from: ep1Data)
        let baseHeaderWords = Self.headerWords(baseData)
        let ep1HeaderWords = Self.headerWords(ep1Data)

        let baseValues = Set(baseStrings.map(\.string))
        let ep1Values = Set(ep1Strings.map(\.string))
        let shared = baseValues.intersection(ep1Values).sorted()
        let uniqueToBase = baseValues.subtracting(ep1Values).sorted()
        let uniqueToEP1 = ep1Values.subtracting(baseValues).sorted()
        let sharedRecordContexts = Self.sharedRecordContexts(
            sharedStrings: shared,
            baseStrings: baseStrings,
            ep1Strings: ep1Strings,
            baseData: baseData,
            ep1Data: ep1Data
        )

        let stringsComparisonURL = outputDirectoryURL.appendingPathComponent("tweakdb-compare-strings.tsv")
        let contextComparisonURL = outputDirectoryURL.appendingPathComponent("tweakdb-compare-contexts.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-bin-compare.json")
        try Self.writeCompareStrings(shared: shared, uniqueToBase: uniqueToBase, uniqueToEP1: uniqueToEP1, to: stringsComparisonURL)
        try Self.writeSharedRecordContexts(sharedRecordContexts, to: contextComparisonURL)

        var warnings = [
            "Read-only comparison only. No game files were modified.",
            "Shared record contexts are conservative samples around plaintext strings, not decoded records."
        ]
        if shared.filter(Self.looksLikeRecordString).count > Self.sharedRecordContextLimit {
            warnings.append("Shared record context output was capped at \(Self.sharedRecordContextLimit) entries.")
        }

        let report = AddonProbeTweakDBBinaryCompareReport(
            base: AddonProbeTweakDBBinarySummary(
                filePath: baseURL.path,
                size: baseData.count,
                sha256: try PathSafety.sha256(url: baseURL),
                magicHeaderValue: Self.magicHeaderValue(baseData),
                stringCount: baseStrings.count
            ),
            ep1: AddonProbeTweakDBBinarySummary(
                filePath: ep1URL.path,
                size: ep1Data.count,
                sha256: try PathSafety.sha256(url: ep1URL),
                magicHeaderValue: Self.magicHeaderValue(ep1Data),
                stringCount: ep1Strings.count
            ),
            headersMatch: Self.firstBytes(baseData, count: 16) == Self.firstBytes(ep1Data, count: 16),
            baseHeaderWords: baseHeaderWords,
            ep1HeaderWords: ep1HeaderWords,
            sharedStrings: shared,
            uniqueToBase: uniqueToBase,
            uniqueToEP1: uniqueToEP1,
            sharedRecordContexts: sharedRecordContexts,
            reportPath: reportURL.path,
            stringsComparisonPath: stringsComparisonURL.path,
            contextComparisonPath: contextComparisonURL.path,
            warnings: warnings
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    private static func normalizedQueries(_ queries: [String]) -> [String] {
        let cleaned = queries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? defaultQueries : AddonProbeManager.orderedUnique(cleaned)
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

    private static func ensureOutputIsNotInsideInspectedApp(inputFileURL: URL, outputDirectoryURL: URL) throws {
        let components = inputFileURL.standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return
        }
        let appPath = NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
        let outputPath = outputDirectoryURL.standardizedFileURL.path
        if outputPath == appPath || outputPath.hasPrefix(appPath + "/") {
            throw CyberMacError.invalidInput("Refusing to write TweakDB inspection output inside the game app: \(outputPath)")
        }
    }

    private static func extractPrintableStrings(from data: Data) -> [AddonProbeTweakDBBinaryString] {
        var strings: [AddonProbeTweakDBBinaryString] = []
        var start: Int?
        var bytes: [UInt8] = []
        let rawBytes = [UInt8](data)

        for (index, byte) in rawBytes.enumerated() {
            if isPrintableStringByte(byte) {
                if start == nil {
                    start = index
                }
                bytes.append(byte)
            } else {
                flushString(start: &start, bytes: &bytes, into: &strings)
            }
        }
        flushString(start: &start, bytes: &bytes, into: &strings)
        return strings
    }

    private static func flushString(
        start: inout Int?,
        bytes: inout [UInt8],
        into strings: inout [AddonProbeTweakDBBinaryString]
    ) {
        defer {
            start = nil
            bytes.removeAll(keepingCapacity: true)
        }
        guard let stringStart = start, bytes.count >= stringMinimumLength else {
            return
        }
        guard let value = String(bytes: bytes, encoding: .utf8), !value.isEmpty else {
            return
        }
        strings.append(AddonProbeTweakDBBinaryString(string: value, offset: stringStart, length: bytes.count))
    }

    private static func isPrintableStringByte(_ byte: UInt8) -> Bool {
        (0x20...0x7E).contains(byte)
    }

    private static func queryMatches(
        queries: [String],
        strings: [AddonProbeTweakDBBinaryString],
        data: Data
    ) -> (matches: [AddonProbeTweakDBBinaryQueryMatch], warnings: [String]) {
        var matches: [AddonProbeTweakDBBinaryQueryMatch] = []
        let needles = queries.map { Array($0.utf8) }
        let candidatesByFirstByte = Dictionary(grouping: needles.indices, by: { needles[$0].first ?? 0 })
        var exactCounts = Array(repeating: 0, count: queries.count)
        var substringCounts = Array(repeating: 0, count: queries.count)
        var rawCounts = Array(repeating: 0, count: queries.count)
        var exactCapped = Array(repeating: false, count: queries.count)
        var substringCapped = Array(repeating: false, count: queries.count)
        var rawCapped = Array(repeating: false, count: queries.count)

        for string in strings {
            let bytes = Array(string.string.utf8)
            guard !bytes.isEmpty else { continue }
            for offsetInString in bytes.indices {
                guard let candidates = candidatesByFirstByte[bytes[offsetInString]] else {
                    continue
                }
                for queryIndex in candidates {
                    let needle = needles[queryIndex]
                    guard !needle.isEmpty,
                          offsetInString + needle.count <= bytes.count,
                          bytes[offsetInString..<(offsetInString + needle.count)].elementsEqual(needle)
                    else {
                        continue
                    }

                    let query = queries[queryIndex]
                    let rawByteOffset = string.offset + offsetInString
                    let exact = offsetInString == 0 && bytes.count == needle.count
                    if exact {
                        if exactCounts[queryIndex] < maxMatchesPerQueryKind {
                            matches.append(makeMatch(
                                query: query,
                                kind: .exactString,
                                string: string,
                                rawByteOffset: string.offset,
                                length: string.length,
                                strings: strings,
                                data: data
                            ))
                            exactCounts[queryIndex] += 1
                        } else {
                            exactCapped[queryIndex] = true
                        }
                    } else {
                        if substringCounts[queryIndex] < maxMatchesPerQueryKind {
                            matches.append(makeMatch(
                                query: query,
                                kind: .substringString,
                                string: string,
                                rawByteOffset: rawByteOffset,
                                length: needle.count,
                                strings: strings,
                                data: data
                            ))
                            substringCounts[queryIndex] += 1
                        } else {
                            substringCapped[queryIndex] = true
                        }
                    }

                    if rawCounts[queryIndex] < maxMatchesPerQueryKind {
                        matches.append(makeMatch(
                            query: query,
                            kind: .rawBytes,
                            string: string,
                            rawByteOffset: rawByteOffset,
                            length: needle.count,
                            strings: strings,
                            data: data
                        ))
                        rawCounts[queryIndex] += 1
                    } else {
                        rawCapped[queryIndex] = true
                    }
                }
            }
        }

        var warnings: [String] = []
        for (index, query) in queries.enumerated() {
            if exactCapped[index] {
                warnings.append("Exact string matches for query '\(query)' were capped at \(maxMatchesPerQueryKind).")
            }
            if substringCapped[index] {
                warnings.append("Substring string matches for query '\(query)' were capped at \(maxMatchesPerQueryKind).")
            }
            if rawCapped[index] {
                warnings.append("Raw byte matches for query '\(query)' were capped at \(maxMatchesPerQueryKind).")
            }
        }
        let sortedMatches = matches.sorted {
            if $0.query != $1.query { return $0.query < $1.query }
            if $0.rawByteOffset != $1.rawByteOffset { return $0.rawByteOffset < $1.rawByteOffset }
            return $0.kind.rawValue < $1.kind.rawValue
        }
        return (sortedMatches, warnings)
    }

    private static func makeMatch(
        query: String,
        kind: AddonProbeTweakDBBinaryMatchKind,
        string: AddonProbeTweakDBBinaryString?,
        rawByteOffset: Int,
        length: Int,
        strings: [AddonProbeTweakDBBinaryString],
        data: Data
    ) -> AddonProbeTweakDBBinaryQueryMatch {
        let nearest = nearestStrings(around: rawByteOffset, length: length, strings: strings, excluding: string)
        let hexRange = contextRange(offset: rawByteOffset, length: length, radius: contextHexRadius, dataCount: data.count)
        let asciiRange = contextRange(offset: rawByteOffset, length: length, radius: contextASCIIRadius, dataCount: data.count)
        return AddonProbeTweakDBBinaryQueryMatch(
            query: query,
            kind: kind,
            string: string?.string,
            stringOffset: string?.offset,
            rawByteOffset: rawByteOffset,
            length: length,
            previousStrings: nearest.previous,
            nextStrings: nearest.next,
            contextHexStartOffset: hexRange.lowerBound,
            contextHex: hex(data, range: hexRange),
            contextASCIIStartOffset: asciiRange.lowerBound,
            contextASCII: ascii(data, range: asciiRange)
        )
    }

    private static func nearestContainingString(
        offset: Int,
        length: Int,
        strings: [AddonProbeTweakDBBinaryString]
    ) -> AddonProbeTweakDBBinaryString? {
        var low = 0
        var high = strings.count
        while low < high {
            let mid = (low + high) / 2
            let string = strings[mid]
            if offset < string.offset {
                high = mid
            } else if offset >= string.offset + string.length {
                low = mid + 1
            } else {
                return offset + length <= string.offset + string.length ? string : nil
            }
        }
        return nil
    }

    private static func nearestStrings(
        around offset: Int,
        length: Int,
        strings: [AddonProbeTweakDBBinaryString],
        excluding excluded: AddonProbeTweakDBBinaryString?
    ) -> (previous: [AddonProbeTweakDBBinaryString], next: [AddonProbeTweakDBBinaryString]) {
        let previous = strings
            .filter { string in
                if let excluded, excluded == string { return false }
                return string.offset + string.length <= offset
            }
            .suffix(3)
        let next = strings
            .filter { string in
                if let excluded, excluded == string { return false }
                return string.offset >= offset + length
            }
            .prefix(3)
        return (Array(previous), Array(next))
    }

    private static func sectionHints(strings: [AddonProbeTweakDBBinaryString], data: Data) -> [AddonProbeTweakDBBinarySectionHint] {
        var hints: [AddonProbeTweakDBBinarySectionHint] = []
        hints.append(contentsOf: denseStringRegionHints(strings: strings))
        if let pointerHint = offsetLikePointerHint(strings: strings, data: data) {
            hints.append(pointerHint)
        }
        if let repeatedHint = repeatedItemRecordHint(strings: strings) {
            hints.append(repeatedHint)
        }
        return hints
    }

    private static func denseStringRegionHints(strings: [AddonProbeTweakDBBinaryString]) -> [AddonProbeTweakDBBinarySectionHint] {
        guard !strings.isEmpty else { return [] }
        var regions: [[AddonProbeTweakDBBinaryString]] = []
        var current: [AddonProbeTweakDBBinaryString] = []

        for string in strings {
            if let previous = current.last, string.offset - (previous.offset + previous.length) > 256 {
                if current.count >= 8 {
                    regions.append(current)
                }
                current = [string]
            } else {
                current.append(string)
            }
        }
        if current.count >= 8 {
            regions.append(current)
        }

        return regions.prefix(50).map { region in
            AddonProbeTweakDBBinarySectionHint(
                kind: "denseStringRegion",
                startOffset: region.first?.offset ?? 0,
                endOffset: (region.last?.offset ?? 0) + (region.last?.length ?? 0),
                evidenceCount: region.count,
                summary: "Dense printable string region; useful for record-name/string-table exploration.",
                examples: region.prefix(8).map(\.string)
            )
        }
    }

    private static func offsetLikePointerHint(
        strings: [AddonProbeTweakDBBinaryString],
        data: Data
    ) -> AddonProbeTweakDBBinarySectionHint? {
        guard !strings.isEmpty, data.count >= 4 else { return nil }
        let stringOffsets = Set(strings.map(\.offset))
        let regionRanges = denseStringRegionHints(strings: strings)
            .map { $0.startOffset..<$0.endOffset }
            .sorted { $0.lowerBound < $1.lowerBound }
        let bytes = [UInt8](data)
        var examples: [String] = []
        var count = 0

        var offset = 0
        while offset <= bytes.count - 4 {
            let value = Int(readUInt32LE(bytes, offset: offset))
            let pointsAtString = stringOffsets.contains(value)
            let pointsIntoStringRegion = valueInRanges(value, ranges: regionRanges)
            if pointsAtString || pointsIntoStringRegion {
                count += 1
                if examples.count < 12 {
                    examples.append("u32@\(offset)=\(value)")
                }
            }
            offset += 4
        }

        guard count > 0 else { return nil }
        return AddonProbeTweakDBBinarySectionHint(
            kind: "offsetLikeU32IntoStringRegion",
            startOffset: 0,
            endOffset: data.count,
            evidenceCount: count,
            summary: "Found little-endian u32 values that point at or inside printable string regions. This is a pointer/offset heuristic only.",
            examples: examples
        )
    }

    private static func valueInRanges(_ value: Int, ranges: [Range<Int>]) -> Bool {
        var low = 0
        var high = ranges.count
        while low < high {
            let mid = (low + high) / 2
            let range = ranges[mid]
            if value < range.lowerBound {
                high = mid
            } else if value >= range.upperBound {
                low = mid + 1
            } else {
                return true
            }
        }
        return false
    }

    private static func repeatedItemRecordHint(strings: [AddonProbeTweakDBBinaryString]) -> AddonProbeTweakDBBinarySectionHint? {
        let itemStrings = strings.filter { looksLikeRecordString($0.string) }
        guard itemStrings.count >= 2 else { return nil }
        let start = itemStrings.map(\.offset).min() ?? 0
        let end = itemStrings.map { $0.offset + $0.length }.max() ?? start
        return AddonProbeTweakDBBinarySectionHint(
            kind: "repeatedItemRecordNameStrings",
            startOffset: start,
            endOffset: end,
            evidenceCount: itemStrings.count,
            summary: "Found repeated item/clothing-like plaintext names. Treat nearby binary as candidate structures until decoded.",
            examples: itemStrings.prefix(20).map(\.string)
        )
    }

    private static func conclusions(
        strings: [AddonProbeTweakDBBinaryString],
        matches: [AddonProbeTweakDBBinaryQueryMatch],
        hints: [AddonProbeTweakDBBinarySectionHint],
        queries: [String]
    ) -> [AddonProbeTweakDBBinaryConclusion] {
        var conclusions: [AddonProbeTweakDBBinaryConclusion] = []
        if strings.contains(where: { looksLikeRecordString($0.string) }) {
            conclusions.append(.plaintextRecordNamesFound)
        }
        if !queries.isEmpty {
            conclusions.append(matches.isEmpty ? .noQueryRecordsFound : .queryRecordsFound)
        }
        if hints.contains(where: { $0.kind == "offsetLikeU32IntoStringRegion" }) {
            conclusions.append(.likelyHashIndexed)
        }
        if conclusions.isEmpty {
            conclusions.append(.unresolved)
        }
        return conclusions
    }

    private static func sharedRecordContexts(
        sharedStrings: [String],
        baseStrings: [AddonProbeTweakDBBinaryString],
        ep1Strings: [AddonProbeTweakDBBinaryString],
        baseData: Data,
        ep1Data: Data
    ) -> [AddonProbeTweakDBBinarySharedContext] {
        let baseByString = Dictionary(grouping: baseStrings, by: \.string)
        let ep1ByString = Dictionary(grouping: ep1Strings, by: \.string)
        return sharedStrings
            .filter(Self.looksLikeRecordString)
            .prefix(sharedRecordContextLimit)
            .compactMap { value in
                guard let base = baseByString[value]?.first,
                      let ep1 = ep1ByString[value]?.first
                else {
                    return nil
                }
                let baseRange = contextRange(offset: base.offset, length: base.length, radius: 64, dataCount: baseData.count)
                let ep1Range = contextRange(offset: ep1.offset, length: ep1.length, radius: 64, dataCount: ep1Data.count)
                return AddonProbeTweakDBBinarySharedContext(
                    string: value,
                    baseOffset: base.offset,
                    ep1Offset: ep1.offset,
                    baseContextHex: hex(baseData, range: baseRange),
                    ep1ContextHex: hex(ep1Data, range: ep1Range),
                    baseContextASCII: ascii(baseData, range: baseRange),
                    ep1ContextASCII: ascii(ep1Data, range: ep1Range)
                )
            }
    }

    private static func looksLikeRecordString(_ value: String) -> Bool {
        value.hasPrefix("Items.") ||
            value.contains("Clothing") ||
            value == "Items.Skirt" ||
            value == "BaseClothing"
    }

    private static func headerWords(_ data: Data) -> [AddonProbeTweakDBBinaryHeaderWord] {
        let limit = min(256, data.count)
        var words: [AddonProbeTweakDBBinaryHeaderWord] = []
        var offset = 0
        while offset < limit {
            let u32 = offset + 4 <= data.count ? readUInt32LE(data, offset: offset) : nil
            let u64 = offset + 8 <= data.count ? readUInt64LE(data, offset: offset) : nil
            words.append(AddonProbeTweakDBBinaryHeaderWord(offset: offset, u32LE: u32, u64LE: u64))
            offset += 4
        }
        return words
    }

    private static func magicHeaderValue(_ data: Data) -> String {
        guard data.count >= 4 else { return "" }
        return hex(data, range: 0..<4)
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        return UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
    }

    private static func readUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }

    private static func readUInt64LE(_ data: Data, offset: Int) -> UInt64 {
        let bytes = [UInt8](data[offset..<(offset + 8)])
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[index]) << UInt64(index * 8)
        }
        return value
    }

    private static func contextRange(offset: Int, length: Int, radius: Int, dataCount: Int) -> Range<Int> {
        let lower = max(0, offset - radius)
        let upper = min(dataCount, offset + max(length, 0) + radius)
        return lower..<upper
    }

    private static func firstBytes(_ data: Data, count: Int) -> Data {
        data.subdata(in: 0..<min(count, data.count))
    }

    private static func hex(_ data: Data, range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        return data[range].map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func ascii(_ data: Data, range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        return String(bytes: data[range].map { byte in
            isPrintableStringByte(byte) ? byte : UInt8(ascii: ".")
        }, encoding: .utf8) ?? ""
    }

    private static func writeStrings(_ strings: [AddonProbeTweakDBBinaryString], to url: URL) throws {
        var lines = ["offset\tlength\tstring"]
        lines.append(contentsOf: strings.map { "\($0.offset)\t\($0.length)\t\(tsvEscape($0.string))" })
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeQueryMatches(_ matches: [AddonProbeTweakDBBinaryQueryMatch], to url: URL) throws {
        var lines: [String] = []
        for match in matches {
            lines.append("[\(match.kind.rawValue)] query=\(match.query) rawByteOffset=\(match.rawByteOffset) stringOffset=\(match.stringOffset.map(String.init) ?? "-")")
            if let string = match.string {
                lines.append("string: \(string)")
            }
            lines.append("previous: \(match.previousStrings.map { "\($0.offset):\($0.string)" }.joined(separator: " | "))")
            lines.append("next: \(match.nextStrings.map { "\($0.offset):\($0.string)" }.joined(separator: " | "))")
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeSectionHints(_ hints: [AddonProbeTweakDBBinarySectionHint], to url: URL) throws {
        var lines: [String] = []
        for hint in hints {
            lines.append("[\(hint.kind)] \(hint.startOffset)..<\(hint.endOffset) evidence=\(hint.evidenceCount)")
            lines.append(hint.summary)
            for example in hint.examples {
                lines.append("- \(example)")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeContextDumps(_ matches: [AddonProbeTweakDBBinaryQueryMatch], to url: URL) throws {
        var lines: [String] = []
        for match in matches {
            lines.append("[\(match.kind.rawValue)] \(match.query) @ \(match.rawByteOffset)")
            lines.append("hex start \(match.contextHexStartOffset):")
            lines.append(match.contextHex)
            lines.append("ascii start \(match.contextASCIIStartOffset):")
            lines.append(match.contextASCII)
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeCompareStrings(
        shared: [String],
        uniqueToBase: [String],
        uniqueToEP1: [String],
        to url: URL
    ) throws {
        var lines = ["bucket\tstring"]
        lines.append(contentsOf: shared.map { "shared\t\(tsvEscape($0))" })
        lines.append(contentsOf: uniqueToBase.map { "uniqueToBase\t\(tsvEscape($0))" })
        lines.append(contentsOf: uniqueToEP1.map { "uniqueToEP1\t\(tsvEscape($0))" })
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeSharedRecordContexts(_ contexts: [AddonProbeTweakDBBinarySharedContext], to url: URL) throws {
        var lines: [String] = []
        for context in contexts {
            lines.append("[shared] \(context.string)")
            lines.append("base @ \(context.baseOffset): \(context.baseContextHex)")
            lines.append("base ascii: \(context.baseContextASCII)")
            lines.append("ep1 @ \(context.ep1Offset): \(context.ep1ContextHex)")
            lines.append("ep1 ascii: \(context.ep1ContextASCII)")
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func tsvEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

public enum AddonProbeTweakDBBinaryInspectFormatter {
    public static func format(_ report: AddonProbeTweakDBBinaryInspectReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB binary inspection",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Size: \(report.size)",
            "SHA-256: \(report.sha256)",
            "Magic/header: \(report.magicHeaderValue)",
            "Strings: \(report.stringCount)",
            "Query matches: \(report.queryMatches.count)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Strings TSV: \(PathSafety.redactUserPath(report.stringsTablePath))"
        ]
        appendList("Queries", report.queries, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBBinaryInspectReport) throws -> String {
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

public enum AddonProbeTweakDBBinaryCompareFormatter {
    public static func format(_ report: AddonProbeTweakDBBinaryCompareReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB binary comparison",
            "Status: read-only; no game files were modified.",
            "Base: \(PathSafety.redactUserPath(report.base.filePath))",
            "EP1: \(PathSafety.redactUserPath(report.ep1.filePath))",
            "Headers match: \(report.headersMatch ? "yes" : "no")",
            "Base strings: \(report.base.stringCount)",
            "EP1 strings: \(report.ep1.stringCount)",
            "Shared strings: \(report.sharedStrings.count)",
            "Unique to base: \(report.uniqueToBase.count)",
            "Unique to EP1: \(report.uniqueToEP1.count)",
            "Shared record contexts: \(report.sharedRecordContexts.count)",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBBinaryCompareReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values {
            lines.append("- \(value)")
        }
    }
}
