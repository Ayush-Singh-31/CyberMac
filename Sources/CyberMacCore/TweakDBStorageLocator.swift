import Foundation

public struct AddonProbeTweakDBStorageLocatorRequest: Sendable {
    public let outputDirectoryURL: URL
    public let gameInstall: GameInstall
    public let cp77toolsURL: URL?
    public let archiveIndexDatabaseURL: URL

    public init(
        outputDirectoryURL: URL,
        gameInstall: GameInstall,
        cp77toolsURL: URL? = nil,
        archiveIndexDatabaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) {
        self.outputDirectoryURL = outputDirectoryURL
        self.gameInstall = gameInstall
        self.cp77toolsURL = cp77toolsURL
        self.archiveIndexDatabaseURL = archiveIndexDatabaseURL
    }
}

public struct AddonProbeRedscriptTweakDBAPIScanRequest: Sendable {
    public let outputDirectoryURL: URL

    public init(outputDirectoryURL: URL) {
        self.outputDirectoryURL = outputDirectoryURL
    }
}

public struct AddonProbeTweakDBPathMatch: Codable, Equatable, Sendable {
    public let path: String
    public let relativePath: String
    public let rootLabel: String
    public let fileSize: UInt64
    public let matchedFragments: [String]

    public init(path: String, relativePath: String, rootLabel: String, fileSize: UInt64, matchedFragments: [String]) {
        self.path = path
        self.relativePath = relativePath
        self.rootLabel = rootLabel
        self.fileSize = fileSize
        self.matchedFragments = matchedFragments
    }
}

public enum AddonProbeTweakDBMatchPriority: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
    case incidental
}

public struct AddonProbeTweakDBStringMatch: Codable, Equatable, Sendable {
    public let term: String
    public let path: String
    public let relativePath: String
    public let rootLabel: String
    public let fileSize: UInt64
    public let fileKind: String
    public let offsets: [UInt64]
    public let sample: String
    public let priority: AddonProbeTweakDBMatchPriority
    public let storageLike: Bool

    public init(
        term: String,
        path: String,
        relativePath: String,
        rootLabel: String,
        fileSize: UInt64,
        fileKind: String,
        offsets: [UInt64],
        sample: String,
        priority: AddonProbeTweakDBMatchPriority,
        storageLike: Bool
    ) {
        self.term = term
        self.path = path
        self.relativePath = relativePath
        self.rootLabel = rootLabel
        self.fileSize = fileSize
        self.fileKind = fileKind
        self.offsets = offsets
        self.sample = sample
        self.priority = priority
        self.storageLike = storageLike
    }
}

public struct AddonProbeTweakDBSkippedFile: Codable, Equatable, Sendable {
    public let path: String
    public let relativePath: String
    public let rootLabel: String
    public let fileSize: UInt64
    public let reason: String

    public init(path: String, relativePath: String, rootLabel: String, fileSize: UInt64, reason: String) {
        self.path = path
        self.relativePath = relativePath
        self.rootLabel = rootLabel
        self.fileSize = fileSize
        self.reason = reason
    }
}

public struct AddonProbeTweakDBStorageCandidate: Codable, Equatable, Sendable {
    public let path: String
    public let relativePath: String
    public let rootLabel: String
    public let fileSize: UInt64
    public let fileKind: String
    public let priority: AddonProbeTweakDBMatchPriority
    public let reasons: [String]
    public let matchedTerms: [String]

    public init(
        path: String,
        relativePath: String,
        rootLabel: String,
        fileSize: UInt64,
        fileKind: String,
        priority: AddonProbeTweakDBMatchPriority,
        reasons: [String],
        matchedTerms: [String]
    ) {
        self.path = path
        self.relativePath = relativePath
        self.rootLabel = rootLabel
        self.fileSize = fileSize
        self.fileKind = fileKind
        self.priority = priority
        self.reasons = reasons
        self.matchedTerms = matchedTerms
    }
}

public struct AddonProbeTweakDBRuntimeAPIMatch: Codable, Equatable, Sendable {
    public let symbol: String
    public let path: String
    public let relativePath: String
    public let rootLabel: String
    public let offsets: [UInt64]
    public let sample: String

    public init(symbol: String, path: String, relativePath: String, rootLabel: String, offsets: [UInt64], sample: String) {
        self.symbol = symbol
        self.path = path
        self.relativePath = relativePath
        self.rootLabel = rootLabel
        self.offsets = offsets
        self.sample = sample
    }

    public func withSymbol(_ symbol: String) -> AddonProbeTweakDBRuntimeAPIMatch {
        AddonProbeTweakDBRuntimeAPIMatch(
            symbol: symbol,
            path: path,
            relativePath: relativePath,
            rootLabel: rootLabel,
            offsets: offsets,
            sample: sample
        )
    }
}

public struct AddonProbeTweakDBRuntimeAPIAvailability: Codable, Equatable, Sendable {
    public let symbol: String
    public let available: Bool
    public let matchCount: Int

    public init(symbol: String, available: Bool, matchCount: Int) {
        self.symbol = symbol
        self.available = available
        self.matchCount = matchCount
    }
}

public enum AddonProbeTweakDBStorageConclusion: String, Codable, Equatable, Sendable {
    case patchableArchiveRecordStoreFound
    case probableBinaryEmbeddedTweakDB
    case runtimeAPIsOnly
    case noStorageFound
    case unresolved
}

public struct AddonProbeTweakDBStorageLocatorReport: Codable, Equatable, Sendable {
    public let gameAppPath: String
    public let outputDirectoryPath: String
    public let pathMatches: [AddonProbeTweakDBPathMatch]
    public let stringMatches: [AddonProbeTweakDBStringMatch]
    public let archiveIndexMatches: [AddonProbeFactoryIndexSearchReport]
    public let runtimeDefinitionMatches: [AddonProbeTweakDBRuntimeAPIMatch]
    public let skippedLargeFiles: [AddonProbeTweakDBSkippedFile]
    public let candidateStorageFiles: [AddonProbeTweakDBStorageCandidate]
    public let candidateRuntimeAPIs: [AddonProbeTweakDBRuntimeAPIAvailability]
    public let conclusion: AddonProbeTweakDBStorageConclusion
    public let warnings: [String]
    public let reportPath: String
    public let pathMatchesPath: String
    public let stringMatchesPath: String
    public let runtimeAPIMatchesPath: String
    public let skippedFilesPath: String

    public init(
        gameAppPath: String,
        outputDirectoryPath: String,
        pathMatches: [AddonProbeTweakDBPathMatch],
        stringMatches: [AddonProbeTweakDBStringMatch],
        archiveIndexMatches: [AddonProbeFactoryIndexSearchReport],
        runtimeDefinitionMatches: [AddonProbeTweakDBRuntimeAPIMatch],
        skippedLargeFiles: [AddonProbeTweakDBSkippedFile],
        candidateStorageFiles: [AddonProbeTweakDBStorageCandidate],
        candidateRuntimeAPIs: [AddonProbeTweakDBRuntimeAPIAvailability],
        conclusion: AddonProbeTweakDBStorageConclusion,
        warnings: [String],
        reportPath: String,
        pathMatchesPath: String,
        stringMatchesPath: String,
        runtimeAPIMatchesPath: String,
        skippedFilesPath: String
    ) {
        self.gameAppPath = gameAppPath
        self.outputDirectoryPath = outputDirectoryPath
        self.pathMatches = pathMatches
        self.stringMatches = stringMatches
        self.archiveIndexMatches = archiveIndexMatches
        self.runtimeDefinitionMatches = runtimeDefinitionMatches
        self.skippedLargeFiles = skippedLargeFiles
        self.candidateStorageFiles = candidateStorageFiles
        self.candidateRuntimeAPIs = candidateRuntimeAPIs
        self.conclusion = conclusion
        self.warnings = warnings
        self.reportPath = reportPath
        self.pathMatchesPath = pathMatchesPath
        self.stringMatchesPath = stringMatchesPath
        self.runtimeAPIMatchesPath = runtimeAPIMatchesPath
        self.skippedFilesPath = skippedFilesPath
    }
}

public struct AddonProbeRedscriptTweakDBAPIScanReport: Codable, Equatable, Sendable {
    public let outputDirectoryPath: String
    public let scannedRoots: [String]
    public let runtimeDefinitionMatches: [AddonProbeTweakDBRuntimeAPIMatch]
    public let availableSymbols: [String]
    public let missingSymbols: [String]
    public let candidateRuntimeAPIs: [AddonProbeTweakDBRuntimeAPIAvailability]
    public let skippedLargeFiles: [AddonProbeTweakDBSkippedFile]
    public let warnings: [String]
    public let reportPath: String
    public let runtimeAPIMatchesPath: String
    public let skippedFilesPath: String

    public init(
        outputDirectoryPath: String,
        scannedRoots: [String],
        runtimeDefinitionMatches: [AddonProbeTweakDBRuntimeAPIMatch],
        availableSymbols: [String],
        missingSymbols: [String],
        candidateRuntimeAPIs: [AddonProbeTweakDBRuntimeAPIAvailability],
        skippedLargeFiles: [AddonProbeTweakDBSkippedFile],
        warnings: [String],
        reportPath: String,
        runtimeAPIMatchesPath: String,
        skippedFilesPath: String
    ) {
        self.outputDirectoryPath = outputDirectoryPath
        self.scannedRoots = scannedRoots
        self.runtimeDefinitionMatches = runtimeDefinitionMatches
        self.availableSymbols = availableSymbols
        self.missingSymbols = missingSymbols
        self.candidateRuntimeAPIs = candidateRuntimeAPIs
        self.skippedLargeFiles = skippedLargeFiles
        self.warnings = warnings
        self.reportPath = reportPath
        self.runtimeAPIMatchesPath = runtimeAPIMatchesPath
        self.skippedFilesPath = skippedFilesPath
    }
}

public struct TweakDBStorageLocator: Sendable {
    public static let pathFragments = [
        "tweakdb",
        "TweakDB",
        "tdb",
        ".tdb",
        ".tweak",
        "gamedata",
        "static_data",
        "database",
        "records",
        "record",
        "items",
        "item"
    ]

    public static let stringTerms = [
        "Items.GenericInnerChestClothing",
        "GenericInnerChestClothing",
        "Items.Skirt",
        "OutfitSlots.TorsoInner",
        "OutfitSlots.LegsOuter",
        "gamedataItem_Record",
        "TweakDBID",
        "TweakDBInterface",
        "GetItemRecord",
        "GetRecord",
        "CreateRecord",
        "CloneRecord",
        "Item_Record",
        "Item_Record_inline",
        "ItemID"
    ]

    public static let runtimeSymbols = [
        "gamedataItem_Record",
        "gamedataClothing_Record",
        "gamedataItem_Record_inline",
        "TweakDBInterface.GetItemRecord",
        "TweakDBInterface.GetRecord",
        "TweakDBInterface.Get*",
        "TDBID.Create",
        "ItemID.FromTDBID"
    ]

    private static let fullScanLimitBytes: UInt64 = 32 * 1024 * 1024
    private static let sampleBytes: UInt64 = 2 * 1024 * 1024
    private static let maxMatchesPerTermPerFile = 20

    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func locate(request: AddonProbeTweakDBStorageLocatorRequest) throws -> AddonProbeTweakDBStorageLocatorReport {
        try home.bootstrap()
        let outputURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputURL, description: "TweakDB storage locator output directory")
        try validateOutsideGameBundle(outputURL, gameInstall: request.gameInstall, description: "TweakDB storage locator output directory")
        if let cp77toolsURL = request.cp77toolsURL {
            try validateExecutableFile(cp77toolsURL.standardizedFileURL, description: "cp77tools path")
        }

        let gameRoot = request.gameInstall.appURL.standardizedFileURL
        try validateReadableDirectory(gameRoot, description: "Game app bundle")
        let roots = gameScanRoots(gameRoot: gameRoot)

        var pathMatches: [AddonProbeTweakDBPathMatch] = []
        var stringMatches: [AddonProbeTweakDBStringMatch] = []
        var skipped: [AddonProbeTweakDBSkippedFile] = []
        var warnings: [String] = [
            "TweakDB storage locator is read-only. It does not mutate the game app and does not use sudo.",
            "Large archives are not unbundled by default; archive contents are checked through the CyberMac archive index when available."
        ]

        for root in roots {
            guard FileManager.default.fileExists(atPath: root.url.path) else { continue }
            let files = try regularFiles(
                under: root.url,
                rootLabel: root.label,
                skipDescendantRelativePaths: root.skipDescendantRelativePaths
            )
            for file in files {
                let lowerRelative = file.relativePath.lowercased()
                let matchedPathTerms = Self.pathFragments.filter { lowerRelative.contains($0.lowercased()) }
                if !matchedPathTerms.isEmpty {
                    pathMatches.append(AddonProbeTweakDBPathMatch(
                        path: file.url.path,
                        relativePath: file.relativePath,
                        rootLabel: file.rootLabel,
                        fileSize: file.size,
                        matchedFragments: matchedPathTerms
                    ))
                }

                let scan = try scanFile(file, terms: Self.stringTerms, runtimeMode: false)
                stringMatches.append(contentsOf: scan.matches.compactMap { $0.stringMatch })
                skipped.append(contentsOf: scan.skipped.map { [$0] } ?? [])
            }
        }

        let archiveIndexMatches = archiveIndexSearches(databaseURL: request.archiveIndexDatabaseURL.standardizedFileURL, warnings: &warnings)
        let apiReport = try scanRuntimeAPIs(outputDirectoryURL: outputURL, writeArtifacts: false)
        warnings.append(contentsOf: apiReport.warnings)
        skipped.append(contentsOf: apiReport.skippedLargeFiles)

        let candidates = storageCandidates(pathMatches: pathMatches, stringMatches: stringMatches)
        let conclusion = concludeStorage(
            candidates: candidates,
            stringMatches: stringMatches,
            runtimeMatches: apiReport.runtimeDefinitionMatches
        )
        if candidates.isEmpty {
            warnings.append("No file exposed exact vanilla base item records as a data-like storage candidate.")
        }
        if conclusion == .probableBinaryEmbeddedTweakDB {
            warnings.append("TweakDB-related strings appear in Mach-O executable/library files, but no patchable data-file record store was found.")
        }
        if conclusion == .runtimeAPIsOnly {
            warnings.append("Only runtime API definitions were found; storage was not exposed as a patchable file.")
        }

        let reportURL = outputURL.appendingPathComponent("tweakdb-storage-locator.json")
        let pathURL = outputURL.appendingPathComponent("tweakdb-path-matches.txt")
        let stringURL = outputURL.appendingPathComponent("tweakdb-string-matches.txt")
        let apiURL = outputURL.appendingPathComponent("tweakdb-runtime-api-matches.txt")
        let skippedURL = outputURL.appendingPathComponent("skipped-files.txt")

        try writePathMatches(pathMatches, to: pathURL)
        try writeStringMatches(stringMatches, to: stringURL)
        try writeRuntimeMatches(apiReport.runtimeDefinitionMatches, availability: apiReport.candidateRuntimeAPIs, to: apiURL)
        try writeSkipped(skipped, to: skippedURL)

        let report = AddonProbeTweakDBStorageLocatorReport(
            gameAppPath: gameRoot.path,
            outputDirectoryPath: outputURL.path,
            pathMatches: sortedPathMatches(pathMatches),
            stringMatches: sortedStringMatches(stringMatches),
            archiveIndexMatches: archiveIndexMatches,
            runtimeDefinitionMatches: apiReport.runtimeDefinitionMatches,
            skippedLargeFiles: sortedSkipped(skipped),
            candidateStorageFiles: candidates,
            candidateRuntimeAPIs: apiReport.candidateRuntimeAPIs,
            conclusion: conclusion,
            warnings: orderedUnique(warnings),
            reportPath: reportURL.path,
            pathMatchesPath: pathURL.path,
            stringMatchesPath: stringURL.path,
            runtimeAPIMatchesPath: apiURL.path,
            skippedFilesPath: skippedURL.path
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func redscriptAPIScan(request: AddonProbeRedscriptTweakDBAPIScanRequest) throws -> AddonProbeRedscriptTweakDBAPIScanReport {
        try home.bootstrap()
        let outputURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputURL, description: "redscript TweakDB API scan output directory")
        return try scanRuntimeAPIs(outputDirectoryURL: outputURL, writeArtifacts: true)
    }

    private func scanRuntimeAPIs(outputDirectoryURL: URL, writeArtifacts: Bool) throws -> AddonProbeRedscriptTweakDBAPIScanReport {
        let roots = runtimeScanRoots()
        var matches: [AddonProbeTweakDBRuntimeAPIMatch] = []
        var skipped: [AddonProbeTweakDBSkippedFile] = []
        var warnings: [String] = []
        var scannedRoots: [String] = []

        for root in roots {
            guard FileManager.default.fileExists(atPath: root.url.path) else {
                warnings.append("Runtime/API scan root does not exist and was skipped: \(root.url.path)")
                continue
            }
            scannedRoots.append(root.url.path)
            let files = try regularFiles(
                under: root.url,
                rootLabel: root.label,
                skipDescendantRelativePaths: root.skipDescendantRelativePaths
            )
            for file in files {
                let scan = try scanFile(file, terms: runtimeSearchTerms(), runtimeMode: true)
                matches.append(contentsOf: scan.matches.compactMap { $0.runtimeMatch })
                skipped.append(contentsOf: scan.skipped.map { [$0] } ?? [])
            }
        }

        matches.append(contentsOf: synthesizedRuntimeAPIMatches(from: matches))
        matches = dedupeRuntimeMatches(matches)
        let availability = runtimeAvailability(matches)
        let available = availability.filter(\.available).map(\.symbol)
        let missing = availability.filter { !$0.available }.map(\.symbol)
        if missing.contains("gamedataItem_Record") {
            warnings.append("gamedataItem_Record was not found in local runtime/overlay definitions; hard-typed redscript probes using it may fail to compile.")
        }

        let reportURL = outputDirectoryURL.appendingPathComponent("redscript-tweakdb-api-scan.json")
        let apiURL = outputDirectoryURL.appendingPathComponent("redscript-tweakdb-api-matches.txt")
        let skippedURL = outputDirectoryURL.appendingPathComponent("skipped-files.txt")
        if writeArtifacts {
            try writeRuntimeMatches(matches, availability: availability, to: apiURL)
            try writeSkipped(skipped, to: skippedURL)
        }

        let report = AddonProbeRedscriptTweakDBAPIScanReport(
            outputDirectoryPath: outputDirectoryURL.path,
            scannedRoots: scannedRoots,
            runtimeDefinitionMatches: matches,
            availableSymbols: available,
            missingSymbols: missing,
            candidateRuntimeAPIs: availability,
            skippedLargeFiles: sortedSkipped(skipped),
            warnings: orderedUnique(warnings),
            reportPath: reportURL.path,
            runtimeAPIMatchesPath: apiURL.path,
            skippedFilesPath: skippedURL.path
        )
        if writeArtifacts {
            try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        }
        return report
    }

    private struct ScanRoot {
        let label: String
        let url: URL
        let skipDescendantRelativePaths: Set<String>

        init(label: String, url: URL, skipDescendantRelativePaths: Set<String> = []) {
            self.label = label
            self.url = url
            self.skipDescendantRelativePaths = skipDescendantRelativePaths
        }
    }

    private struct RegularFile {
        let rootLabel: String
        let relativePath: String
        let url: URL
        let size: UInt64
    }

    private struct RawScanMatch {
        let stringMatch: AddonProbeTweakDBStringMatch?
        let runtimeMatch: AddonProbeTweakDBRuntimeAPIMatch?
    }

    private func gameScanRoots(gameRoot: URL) -> [ScanRoot] {
        let contentsURL = gameRoot.appendingPathComponent("Contents", isDirectory: true)
        let requested: [ScanRoot] = [
            ScanRoot(label: "Contents/Data/archive", url: contentsURL.appendingPathComponent("Data/archive", isDirectory: true)),
            ScanRoot(label: "Contents/Data/r6", url: contentsURL.appendingPathComponent("Data/r6", isDirectory: true)),
            ScanRoot(
                label: "Contents/Data",
                url: contentsURL.appendingPathComponent("Data", isDirectory: true),
                skipDescendantRelativePaths: ["archive", "r6"]
            ),
            ScanRoot(label: "Contents/Resources", url: contentsURL.appendingPathComponent("Resources", isDirectory: true)),
            ScanRoot(label: "Contents/MacOS", url: contentsURL.appendingPathComponent("MacOS", isDirectory: true)),
            ScanRoot(label: "Contents/Frameworks", url: contentsURL.appendingPathComponent("Frameworks", isDirectory: true)),
            ScanRoot(
                label: "Contents",
                url: contentsURL,
                skipDescendantRelativePaths: ["Data", "Resources", "MacOS", "Frameworks"]
            )
        ]
        var seen = Set<String>()
        var roots: [ScanRoot] = []
        for root in requested {
            let path = root.url.standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            roots.append(ScanRoot(
                label: root.label,
                url: root.url.standardizedFileURL,
                skipDescendantRelativePaths: root.skipDescendantRelativePaths
            ))
        }
        return roots
    }

    private func runtimeScanRoots() -> [ScanRoot] {
        [
            ScanRoot(label: "CyberMac runtime", url: home.runtimeURL.standardizedFileURL),
            ScanRoot(label: "CyberMac game-overlay", url: home.overlayURL.standardizedFileURL)
        ]
    }

    private func regularFiles(under rootURL: URL, rootLabel: String, skipDescendantRelativePaths: Set<String> = []) throws -> [RegularFile] {
        let root = rootURL.standardizedFileURL
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(rootLabel) root is a symlink: \(root.path)")
        }
        guard values.isDirectory == true else {
            return []
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [RegularFile] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard resource.isSymbolicLink != true else { continue }
            let relative = try PathSafety.relativePath(of: url.standardizedFileURL, in: root)
                .replacingOccurrences(of: "\\", with: "/")
            if skipDescendantRelativePaths.contains(relative) {
                enumerator.skipDescendants()
                continue
            }
            guard resource.isRegularFile == true else { continue }
            try validateContainedPath(url, in: root, description: rootLabel)
            files.append(RegularFile(
                rootLabel: rootLabel,
                relativePath: relative,
                url: url.standardizedFileURL,
                size: UInt64(resource.fileSize ?? 0)
            ))
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func scanFile(_ file: RegularFile, terms: [String], runtimeMode: Bool) throws -> (matches: [RawScanMatch], skipped: AddonProbeTweakDBSkippedFile?) {
        if file.size == 0 {
            return ([], nil)
        }

        let lowerPath = file.relativePath.lowercased()
        let isArchive = lowerPath.hasSuffix(".archive")
        if isArchive && file.size > Self.fullScanLimitBytes {
            return ([], AddonProbeTweakDBSkippedFile(
                path: file.url.path,
                relativePath: file.relativePath,
                rootLabel: file.rootLabel,
                fileSize: file.size,
                reason: "archive larger than \(Self.fullScanLimitBytes) bytes; raw scan skipped, use archive index"
            ))
        }

        let fileKind = try detectFileKind(file.url)
        let sample = try sampledData(file)
        var rawMatches: [RawScanMatch] = []
        for term in terms {
            let offsets = byteOffsets(of: Array(term.utf8), in: sample.data, baseOffset: sample.baseOffset, limit: Self.maxMatchesPerTermPerFile)
            guard !offsets.isEmpty else { continue }
            let sampleText = printableSample(containing: Array(term.utf8), in: sample.data)
            if runtimeMode {
                rawMatches.append(RawScanMatch(
                    stringMatch: nil,
                    runtimeMatch: AddonProbeTweakDBRuntimeAPIMatch(
                        symbol: term,
                        path: file.url.path,
                        relativePath: file.relativePath,
                        rootLabel: file.rootLabel,
                        offsets: offsets,
                        sample: sampleText
                    )
                ))
            } else {
                let priority = priorityForStringTerm(
                    term: term,
                    fileKind: fileKind,
                    relativePath: file.relativePath,
                    rootLabel: file.rootLabel
                )
                rawMatches.append(RawScanMatch(
                    stringMatch: AddonProbeTweakDBStringMatch(
                        term: term,
                        path: file.url.path,
                        relativePath: file.relativePath,
                        rootLabel: file.rootLabel,
                        fileSize: file.size,
                        fileKind: fileKind,
                        offsets: offsets,
                        sample: sampleText,
                        priority: priority,
                        storageLike: priority == .high || priority == .medium
                    ),
                    runtimeMatch: nil
                ))
            }
        }

        let skipped: AddonProbeTweakDBSkippedFile?
        if sample.sampled {
            skipped = AddonProbeTweakDBSkippedFile(
                path: file.url.path,
                relativePath: file.relativePath,
                rootLabel: file.rootLabel,
                fileSize: file.size,
                reason: "file larger than \(Self.fullScanLimitBytes) bytes; sampled first \(Self.sampleBytes) bytes"
            )
        } else {
            skipped = nil
        }
        return (rawMatches, skipped)
    }

    private func sampledData(_ file: RegularFile) throws -> (data: Data, baseOffset: UInt64, sampled: Bool) {
        if file.size <= Self.fullScanLimitBytes {
            return (try Data(contentsOf: file.url), 0, false)
        }
        let handle = try FileHandle(forReadingFrom: file.url)
        defer { try? handle.close() }
        let count = Int(min(Self.sampleBytes, file.size))
        let data = try handle.read(upToCount: count) ?? Data()
        return (data, 0, true)
    }

    private func detectFileKind(_ url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        let data = try readPrefix(url, count: 4096)
        if data.count >= 4 {
            let prefix = Array(data.prefix(4))
            if prefix == [0xFE, 0xED, 0xFA, 0xCF] ||
                prefix == [0xCF, 0xFA, 0xED, 0xFE] ||
                prefix == [0xFE, 0xED, 0xFA, 0xCE] ||
                prefix == [0xCE, 0xFA, 0xED, 0xFE] ||
                prefix == [0xCA, 0xFE, 0xBA, 0xBE] ||
                prefix == [0xCA, 0xFE, 0xBA, 0xBF] ||
                prefix == [0xBE, 0xBA, 0xFE, 0xCA] ||
                prefix == [0xBF, 0xBA, 0xFE, 0xCA] {
                return "mach-o"
            }
        }
        if ext == "archive" { return "archive" }
        if ext == "dylib" || ext == "so" || ext == "bundle" { return "binary" }
        if let text = String(data: data.prefix(4096), encoding: .utf8),
           !text.unicodeScalars.contains(where: { $0.value < 0x20 && !["\n", "\r", "\t"].contains(Character($0)) }) {
            return "text"
        }
        return "binary"
    }

    private func readPrefix(_ url: URL, count: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: count) ?? Data()
    }

    private func byteOffsets(of needle: [UInt8], in data: Data, baseOffset: UInt64, limit: Int) -> [UInt64] {
        guard !needle.isEmpty, !data.isEmpty else { return [] }
        let haystack = [UInt8](data)
        guard haystack.count >= needle.count else { return [] }
        var offsets: [UInt64] = []
        var index = 0
        while index <= haystack.count - needle.count, offsets.count < limit {
            if Array(haystack[index..<(index + needle.count)]) == needle {
                offsets.append(baseOffset + UInt64(index))
                index += needle.count
            } else {
                index += 1
            }
        }
        return offsets
    }

    private func printableSample(containing needle: [UInt8], in data: Data, limit: Int = 220) -> String {
        let bytes = [UInt8](data)
        guard !needle.isEmpty, let index = firstIndex(of: needle, in: bytes) else {
            return ""
        }
        var start = index
        while start > 0, isPrintableStringByte(bytes[start - 1]) {
            start -= 1
        }
        var end = index + needle.count
        while end < bytes.count, isPrintableStringByte(bytes[end]) {
            end += 1
        }
        let slice = Array(bytes[start..<end])
        let text = String(bytes: slice, encoding: .utf8) ?? String(bytes: slice, encoding: .ascii) ?? ""
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        guard oneLine.count > limit else { return oneLine }
        return String(oneLine.prefix(limit - 13)) + "... truncated"
    }

    private func firstIndex(of needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        for index in 0...(haystack.count - needle.count) {
            if Array(haystack[index..<(index + needle.count)]) == needle {
                return index
            }
        }
        return nil
    }

    private func isPrintableStringByte(_ byte: UInt8) -> Bool {
        byte == 0x09 || byte == 0x0A || byte == 0x0D || (0x20...0x7E).contains(byte)
    }

    private func priorityForStringTerm(term: String, fileKind: String, relativePath: String, rootLabel: String) -> AddonProbeTweakDBMatchPriority {
        let lowerPath = relativePath.lowercased()
        let executableLike = isExecutableOrLibrary(fileKind: fileKind, relativePath: relativePath, rootLabel: rootLabel)
        let exactBaseTerms = ["Items.GenericInnerChestClothing", "GenericInnerChestClothing", "Items.Skirt"]
        if exactBaseTerms.contains(term) {
            return .high
        }
        if term.hasPrefix("OutfitSlots.") || term == "gamedataItem_Record" || term.contains("Item_Record") {
            return executableLike ? .low : .medium
        }
        if term == "TweakDBID" || term == "TweakDBInterface" || term == "ItemID" {
            if lowerPath.contains(".ent") || lowerPath.contains("streaming") || lowerPath.contains("sector") {
                return .incidental
            }
            return executableLike ? .low : .incidental
        }
        if term.contains("Record") {
            return executableLike ? .low : .medium
        }
        return .incidental
    }

    private func isExecutableOrLibrary(fileKind: String, relativePath: String, rootLabel: String) -> Bool {
        if fileKind == "mach-o" { return true }
        let lowerRoot = rootLabel.lowercased()
        let lowerPath = relativePath.lowercased()
        if lowerRoot.contains("contents/macos") || lowerRoot.contains("contents/frameworks") {
            return true
        }
        return lowerPath.hasSuffix(".dylib") || lowerPath.hasSuffix(".framework") || lowerPath.hasSuffix(".bundle")
    }

    private func archiveIndexSearches(databaseURL: URL, warnings: inout [String]) -> [AddonProbeFactoryIndexSearchReport] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            warnings.append("Archive catalog index database was not found: \(databaseURL.path)")
            return []
        }
        let terms = AddonProbeManager.orderedUnique(Self.pathFragments + Self.stringTerms)
        let store = ArchiveCatalogIndexStore()
        var reports: [AddonProbeFactoryIndexSearchReport] = []
        for term in terms {
            do {
                let search = try store.search(options: ArchiveCatalogIndexSearchOptions(
                    query: term,
                    databaseURL: databaseURL,
                    limit: 50
                ))
                reports.append(AddonProbeFactoryIndexSearchReport(
                    term: term,
                    exactResource: false,
                    totalMatchCount: search.totalMatchCount,
                    shownMatchCount: search.matches.count,
                    matches: search.matches
                ))
            } catch {
                warnings.append("Archive index search failed for \(term): \(error.localizedDescription)")
            }
        }
        return reports
    }

    private func storageCandidates(
        pathMatches: [AddonProbeTweakDBPathMatch],
        stringMatches: [AddonProbeTweakDBStringMatch]
    ) -> [AddonProbeTweakDBStorageCandidate] {
        var byPath: [String: (path: String, relativePath: String, rootLabel: String, size: UInt64, kind: String, terms: Set<String>, reasons: Set<String>, priority: AddonProbeTweakDBMatchPriority)] = [:]
        let pathLookup = Dictionary(uniqueKeysWithValues: pathMatches.map { ($0.path, $0) })
        for match in stringMatches where match.storageLike {
            let existing = byPath[match.path]
            var terms = existing?.terms ?? []
            terms.insert(match.term)
            var reasons = existing?.reasons ?? []
            if match.priority == .high {
                reasons.insert("exact vanilla base item record string found")
            } else if match.priority == .medium {
                reasons.insert("record or slot-like TweakDB string found")
            }
            if let pathMatch = pathLookup[match.path] {
                reasons.insert("filename/path matched: \(pathMatch.matchedFragments.joined(separator: ", "))")
            }
            let priority = higherPriority(existing?.priority ?? .incidental, match.priority)
            byPath[match.path] = (
                path: match.path,
                relativePath: match.relativePath,
                rootLabel: match.rootLabel,
                size: match.fileSize,
                kind: match.fileKind,
                terms: terms,
                reasons: reasons,
                priority: priority
            )
        }
        return byPath.values.map { entry in
            AddonProbeTweakDBStorageCandidate(
                path: entry.path,
                relativePath: entry.relativePath,
                rootLabel: entry.rootLabel,
                fileSize: entry.size,
                fileKind: entry.kind,
                priority: entry.priority,
                reasons: entry.reasons.sorted(),
                matchedTerms: entry.terms.sorted()
            )
        }.sorted {
            if priorityRank($0.priority) != priorityRank($1.priority) { return priorityRank($0.priority) > priorityRank($1.priority) }
            return $0.path < $1.path
        }
    }

    private func concludeStorage(
        candidates: [AddonProbeTweakDBStorageCandidate],
        stringMatches: [AddonProbeTweakDBStringMatch],
        runtimeMatches: [AddonProbeTweakDBRuntimeAPIMatch]
    ) -> AddonProbeTweakDBStorageConclusion {
        let patchableDataCandidate = candidates.contains { candidate in
            candidate.priority == .high &&
                !isExecutableOrLibrary(
                    fileKind: candidate.fileKind,
                    relativePath: candidate.relativePath,
                    rootLabel: candidate.rootLabel
                )
        }
        if patchableDataCandidate {
            return .patchableArchiveRecordStoreFound
        }
        let gameBinaryMatches = stringMatches.contains { match in
            isExecutableOrLibrary(
                fileKind: match.fileKind,
                relativePath: match.relativePath,
                rootLabel: match.rootLabel
            ) && match.priority != .incidental
        }
        let nonExecutableCandidates = candidates.contains { candidate in
            !isExecutableOrLibrary(
                fileKind: candidate.fileKind,
                relativePath: candidate.relativePath,
                rootLabel: candidate.rootLabel
            )
        }
        if gameBinaryMatches && !nonExecutableCandidates {
            return .probableBinaryEmbeddedTweakDB
        }
        if !runtimeMatches.isEmpty && stringMatches.allSatisfy({ $0.priority == .incidental }) && candidates.isEmpty {
            return .runtimeAPIsOnly
        }
        if candidates.isEmpty {
            return .noStorageFound
        }
        return .unresolved
    }

    private func runtimeSearchTerms() -> [String] {
        [
            "gamedataItem_Record",
            "gamedataClothing_Record",
            "gamedataItem_Record_inline",
            "TweakDBInterface.GetItemRecord",
            "TweakDBInterface.GetRecord",
            "TweakDBInterface.Get",
            "TweakDBInterface",
            "GetItemRecord",
            "GetRecord",
            "TDBID.Create",
            "TDBID",
            "Create",
            "ItemID.FromTDBID",
            "ItemID",
            "FromTDBID"
        ]
    }

    private func synthesizedRuntimeAPIMatches(from matches: [AddonProbeTweakDBRuntimeAPIMatch]) -> [AddonProbeTweakDBRuntimeAPIMatch] {
        var synthesized: [AddonProbeTweakDBRuntimeAPIMatch] = []
        let byPath = Dictionary(grouping: matches, by: \.path)
        for fileMatches in byPath.values {
            guard fileMatches.contains(where: { $0.symbol == "TweakDBInterface" || $0.symbol.hasPrefix("TweakDBInterface.") }) else {
                continue
            }
            if let match = firstMatch(in: fileMatches, exact: "GetItemRecord") ?? firstMatch(in: fileMatches, exact: "TweakDBInterface.GetItemRecord") {
                synthesized.append(match.withSymbol("TweakDBInterface.GetItemRecord"))
            }
            if let match = firstMatch(in: fileMatches, exact: "GetRecord") ?? firstMatch(in: fileMatches, exact: "TweakDBInterface.GetRecord") {
                synthesized.append(match.withSymbol("TweakDBInterface.GetRecord"))
            }
            if let match = firstMatch(in: fileMatches, exact: "TweakDBInterface.Get")
                ?? firstMatch(in: fileMatches, exact: "GetItemRecord")
                ?? firstMatch(in: fileMatches, exact: "GetRecord") {
                synthesized.append(match.withSymbol("TweakDBInterface.Get*"))
            }
        }

        for fileMatches in byPath.values {
            if let match = firstMatch(in: fileMatches, exact: "TDBID.Create") {
                synthesized.append(match)
            } else if fileMatches.contains(where: { $0.symbol == "TDBID" }),
                      let create = firstMatch(in: fileMatches, exact: "Create") {
                synthesized.append(create.withSymbol("TDBID.Create"))
            }

            if let match = firstMatch(in: fileMatches, exact: "ItemID.FromTDBID") {
                synthesized.append(match)
            } else if fileMatches.contains(where: { $0.symbol == "ItemID" }),
                      let from = firstMatch(in: fileMatches, exact: "FromTDBID") {
                synthesized.append(from.withSymbol("ItemID.FromTDBID"))
            }
        }
        return synthesized
    }

    private func firstMatch(in matches: [AddonProbeTweakDBRuntimeAPIMatch], exact symbol: String) -> AddonProbeTweakDBRuntimeAPIMatch? {
        matches.first { $0.symbol == symbol }
    }

    private func runtimeAvailability(_ matches: [AddonProbeTweakDBRuntimeAPIMatch]) -> [AddonProbeTweakDBRuntimeAPIAvailability] {
        Self.runtimeSymbols.map { symbol in
            let count = matches.filter { $0.symbol == symbol }.count
            return AddonProbeTweakDBRuntimeAPIAvailability(symbol: symbol, available: count > 0, matchCount: count)
        }
    }

    private func higherPriority(_ left: AddonProbeTweakDBMatchPriority, _ right: AddonProbeTweakDBMatchPriority) -> AddonProbeTweakDBMatchPriority {
        priorityRank(left) >= priorityRank(right) ? left : right
    }

    private func priorityRank(_ priority: AddonProbeTweakDBMatchPriority) -> Int {
        switch priority {
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        case .incidental: return 1
        }
    }

    private func sortedPathMatches(_ matches: [AddonProbeTweakDBPathMatch]) -> [AddonProbeTweakDBPathMatch] {
        matches.sorted { $0.path < $1.path }
    }

    private func sortedStringMatches(_ matches: [AddonProbeTweakDBStringMatch]) -> [AddonProbeTweakDBStringMatch] {
        matches.sorted {
            if priorityRank($0.priority) != priorityRank($1.priority) { return priorityRank($0.priority) > priorityRank($1.priority) }
            if $0.path != $1.path { return $0.path < $1.path }
            return $0.term < $1.term
        }
    }

    private func sortedSkipped(_ skipped: [AddonProbeTweakDBSkippedFile]) -> [AddonProbeTweakDBSkippedFile] {
        skipped.sorted { $0.path < $1.path }
    }

    private func dedupeRuntimeMatches(_ matches: [AddonProbeTweakDBRuntimeAPIMatch]) -> [AddonProbeTweakDBRuntimeAPIMatch] {
        var seen = Set<String>()
        var result: [AddonProbeTweakDBRuntimeAPIMatch] = []
        for match in matches.sorted(by: { $0.path == $1.path ? $0.symbol < $1.symbol : $0.path < $1.path }) {
            let key = "\(match.symbol)\u{0}\(match.path)\u{0}\(match.offsets)"
            guard seen.insert(key).inserted else { continue }
            result.append(match)
        }
        return result
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        AddonProbeManager.orderedUnique(values)
    }

    private func writePathMatches(_ matches: [AddonProbeTweakDBPathMatch], to url: URL) throws {
        let lines = sortedPathMatches(matches).map {
            "\($0.rootLabel) | \($0.relativePath) | \($0.fileSize) bytes | \($0.matchedFragments.joined(separator: ", "))"
        }
        try (lines.isEmpty ? "(none)\n" : lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeStringMatches(_ matches: [AddonProbeTweakDBStringMatch], to url: URL) throws {
        let lines = sortedStringMatches(matches).map {
            "\($0.priority.rawValue) | \($0.fileKind) | \($0.rootLabel) | \($0.relativePath) | \($0.term) | offsets=\($0.offsets.map(String.init).joined(separator: ",")) | \($0.sample)"
        }
        try (lines.isEmpty ? "(none)\n" : lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeRuntimeMatches(
        _ matches: [AddonProbeTweakDBRuntimeAPIMatch],
        availability: [AddonProbeTweakDBRuntimeAPIAvailability],
        to url: URL
    ) throws {
        var lines: [String] = ["Availability:"]
        for item in availability {
            lines.append("- \(item.symbol): \(item.available ? "available" : "missing") (\(item.matchCount) match(es))")
        }
        lines.append("")
        lines.append("Matches:")
        for match in matches {
            lines.append("- \(match.symbol) | \(match.rootLabel) | \(match.relativePath) | offsets=\(match.offsets.map(String.init).joined(separator: ",")) | \(match.sample)")
        }
        if matches.isEmpty {
            lines.append("(none)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeSkipped(_ skipped: [AddonProbeTweakDBSkippedFile], to url: URL) throws {
        let lines = sortedSkipped(skipped).map {
            "\($0.rootLabel) | \($0.relativePath) | \($0.fileSize) bytes | \($0.reason)"
        }
        try (lines.isEmpty ? "(none)\n" : lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func validateOutputDirectory(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.invalidInput("\(description) is not a directory: \(url.path)")
        }
    }

    private func validateReadableDirectory(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("\(description) is not a directory: \(url.path)")
        }
    }

    private func validateExecutableFile(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) is a symlink: \(url.path)")
        }
        guard values.isRegularFile == true else {
            throw CyberMacError.invalidInput("\(description) is not a regular file: \(url.path)")
        }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CyberMacError.invalidInput("\(description) is not executable: \(url.path)")
        }
    }

    private func validateOutsideGameBundle(_ url: URL, gameInstall: GameInstall, description: String) throws {
        let gameRoot = gameInstall.appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = gameRoot.hasSuffix("/") ? gameRoot : gameRoot + "/"
        guard targetPath != gameRoot, !targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) must not be inside the game bundle: \(targetPath)")
        }
    }

    private func validateLocalURL(_ url: URL, description: String) throws {
        guard url.isFileURL else {
            throw CyberMacError.unsafePath("\(description) must be a file URL: \(url.absoluteString)")
        }
        guard url.path.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(description) path must be absolute: \(url.path)")
        }
        guard !url.path.split(separator: "/", omittingEmptySubsequences: true).contains("..") else {
            throw CyberMacError.unsafePath("\(description) path contains traversal: \(url.path)")
        }
    }

    private func validateContainedPath(_ targetURL: URL, in rootURL: URL, description: String) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath == rootPath || targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) escapes expected root: \(targetPath)")
        }
    }
}

public enum AddonProbeTweakDBStorageLocatorFormatter {
    public static func format(_ report: AddonProbeTweakDBStorageLocatorReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB storage locator",
            "Status: read-only probe; true add-on clothing support is not claimed.",
            "Conclusion: \(report.conclusion.rawValue)",
            "Game app: \(PathSafety.redactUserPath(report.gameAppPath))",
            "Path matches: \(report.pathMatches.count)",
            "String matches: \(report.stringMatches.count)",
            "Archive index queries: \(report.archiveIndexMatches.count)",
            "Runtime API matches: \(report.runtimeDefinitionMatches.count)",
            "Candidate storage files: \(report.candidateStorageFiles.count)",
            "Skipped/sample-limited files: \(report.skippedLargeFiles.count)",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]

        if !report.candidateStorageFiles.isEmpty {
            lines.append("")
            lines.append("Top storage candidates:")
            for candidate in report.candidateStorageFiles.prefix(10) {
                lines.append("- \(candidate.priority.rawValue) | \(candidate.fileKind) | \(PathSafety.redactUserPath(candidate.path))")
                lines.append("  terms: \(candidate.matchedTerms.joined(separator: ", "))")
                lines.append("  reasons: \(candidate.reasons.joined(separator: "; "))")
            }
        }

        let binaryMatches = report.stringMatches.filter { $0.fileKind == "mach-o" || $0.fileKind == "binary" }
        if !binaryMatches.isEmpty {
            lines.append("")
            lines.append("Top binary/API string matches:")
            for match in binaryMatches.prefix(10) {
                lines.append("- \(match.term) | \(match.fileKind) | \(PathSafety.redactUserPath(match.path)) | offsets \(match.offsets.map(String.init).joined(separator: ","))")
            }
        }

        if !report.candidateRuntimeAPIs.isEmpty {
            lines.append("")
            lines.append("Runtime API availability:")
            for api in report.candidateRuntimeAPIs {
                lines.append("- \(api.symbol): \(api.available ? "available" : "missing")")
            }
        }

        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBStorageLocatorReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(25) {
            lines.append("- \(value)")
        }
        if values.count > 25 {
            lines.append("- ... \(values.count - 25) more")
        }
    }
}

public enum AddonProbeRedscriptTweakDBAPIScanFormatter {
    public static func format(_ report: AddonProbeRedscriptTweakDBAPIScanReport) -> String {
        var lines: [String] = [
            "CyberMac redscript TweakDB API scan",
            "Status: local runtime/overlay definition scan only.",
            "Scanned roots: \(report.scannedRoots.count)",
            "Available symbols: \(report.availableSymbols.count)",
            "Missing symbols: \(report.missingSymbols.count)",
            "Matches: \(report.runtimeDefinitionMatches.count)",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]
        appendList("Available", report.availableSymbols, to: &lines)
        appendList("Missing", report.missingSymbols, to: &lines)
        if !report.runtimeDefinitionMatches.isEmpty {
            lines.append("")
            lines.append("Top matches:")
            for match in report.runtimeDefinitionMatches.prefix(25) {
                lines.append("- \(match.symbol) | \(PathSafety.redactUserPath(match.path)) | offsets \(match.offsets.map(String.init).joined(separator: ","))")
            }
        }
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeRedscriptTweakDBAPIScanReport) throws -> String {
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
