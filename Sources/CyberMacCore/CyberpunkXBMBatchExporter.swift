import Foundation

// MARK: - Options & results

public struct CyberpunkXBMBatchExportOptions: Sendable {
    public let archivePath: String
    public let extractedRoot: URL
    public let outputDirectory: URL
    public let krakenLibraryPath: String?
    public let query: String?
    public let category: String?
    public let limit: Int
    public let register: Bool
    public let databaseURL: URL?
    public let skipExisting: Bool
    public let debug: Bool
    public let sourceTool: String

    public static let defaultLimit = 1000
    public static let defaultSourceTool = "cybermac-xbm-preview-batch-export"

    public init(
        archivePath: String,
        extractedRoot: URL,
        outputDirectory: URL,
        krakenLibraryPath: String? = nil,
        query: String? = nil,
        category: String? = nil,
        limit: Int = CyberpunkXBMBatchExportOptions.defaultLimit,
        register: Bool = false,
        databaseURL: URL? = nil,
        skipExisting: Bool = false,
        debug: Bool = false,
        sourceTool: String = CyberpunkXBMBatchExportOptions.defaultSourceTool
    ) {
        self.archivePath = archivePath
        self.extractedRoot = extractedRoot
        self.outputDirectory = outputDirectory
        self.krakenLibraryPath = krakenLibraryPath
        self.query = query
        self.category = category
        self.limit = limit
        self.register = register
        self.databaseURL = databaseURL
        self.skipExisting = skipExisting
        self.debug = debug
        self.sourceTool = sourceTool
    }
}

/// Per-asset outcome, kept neutral so callers (formatter, tests, future UI)
/// don't need to thread different result/error pairs through their code.
public struct CyberpunkXBMBatchExportEntry: Sendable {
    public enum Outcome: Sendable, Equatable {
        case exported
        case skippedExisting
        case failed(CyberpunkXBMBatchExportFailureKind, reason: String)
    }

    public let assetPath: String
    public let archivePath: String
    public let resolvedInputPath: String?
    public let previewPath: String
    public let outcome: Outcome
    public let width: UInt32?
    public let height: UInt32?
    public let compressionName: String?
    public let decoderUsed: String?
    public let krakenUsed: Bool
    public let registered: Bool

    public init(
        assetPath: String,
        archivePath: String,
        resolvedInputPath: String?,
        previewPath: String,
        outcome: Outcome,
        width: UInt32? = nil,
        height: UInt32? = nil,
        compressionName: String? = nil,
        decoderUsed: String? = nil,
        krakenUsed: Bool = false,
        registered: Bool = false
    ) {
        self.assetPath = assetPath
        self.archivePath = archivePath
        self.resolvedInputPath = resolvedInputPath
        self.previewPath = previewPath
        self.outcome = outcome
        self.width = width
        self.height = height
        self.compressionName = compressionName
        self.decoderUsed = decoderUsed
        self.krakenUsed = krakenUsed
        self.registered = registered
    }
}

/// Batch-level failure categorisation. Mirrors the per-asset
/// `CyberpunkXBMExportFailureKind` plus a "missing file" reason that only
/// the batch layer can detect (the single-file exporter assumes the input
/// already exists).
public enum CyberpunkXBMBatchExportFailureKind: String, Sendable, Equatable, CaseIterable {
    case missingFile = "missing_file"
    case unsupportedCompression = "unsupported_compression"
    case streamedTopMipMissing = "streamed_top_mip_missing"
    case missingKrakenLibrary = "missing_kraken_library"
    case decodeFailure = "decode_failure"
    case registrationFailure = "registration_failure"

    public var humanReadable: String {
        switch self {
        case .missingFile: return "missing file"
        case .unsupportedCompression: return "unsupported compression"
        case .streamedTopMipMissing: return "streamed top mip missing"
        case .missingKrakenLibrary: return "missing kraken library"
        case .decodeFailure: return "decode failure"
        case .registrationFailure: return "registration failure"
        }
    }

    static func from(_ kind: CyberpunkXBMExportFailureKind) -> CyberpunkXBMBatchExportFailureKind {
        switch kind {
        case .unsupportedCompression: return .unsupportedCompression
        case .streamedTopMipMissing: return .streamedTopMipMissing
        case .missingKrakenLibrary: return .missingKrakenLibrary
        case .decodeFailure: return .decodeFailure
        }
    }
}

public struct CyberpunkXBMBatchExportReport: Sendable {
    public let archivePath: String
    public let extractedRootPath: String
    public let outputDirectoryPath: String
    public let databasePath: String?
    public let query: String
    public let category: String?
    public let limit: Int
    public let totalMatched: Int
    public let totalProcessed: Int
    public let entries: [CyberpunkXBMBatchExportEntry]
    public let exportedCount: Int
    public let skippedCount: Int
    public let failureCountsByKind: [CyberpunkXBMBatchExportFailureKind: Int]
    public let registeredCount: Int

    public init(
        archivePath: String,
        extractedRootPath: String,
        outputDirectoryPath: String,
        databasePath: String?,
        query: String,
        category: String?,
        limit: Int,
        totalMatched: Int,
        totalProcessed: Int,
        entries: [CyberpunkXBMBatchExportEntry],
        exportedCount: Int,
        skippedCount: Int,
        failureCountsByKind: [CyberpunkXBMBatchExportFailureKind: Int],
        registeredCount: Int
    ) {
        self.archivePath = archivePath
        self.extractedRootPath = extractedRootPath
        self.outputDirectoryPath = outputDirectoryPath
        self.databasePath = databasePath
        self.query = query
        self.category = category
        self.limit = limit
        self.totalMatched = totalMatched
        self.totalProcessed = totalProcessed
        self.entries = entries
        self.exportedCount = exportedCount
        self.skippedCount = skippedCount
        self.failureCountsByKind = failureCountsByKind
        self.registeredCount = registeredCount
    }
}

// MARK: - Batch exporter

public struct CyberpunkXBMBatchExporter {
    public static let defaultListAllXBMQuery = ".xbm"
    public static let xbmExtensionFilter = "xbm"

    private let exporter: CyberpunkXBMExporter
    private let searcher: ArchiveCatalogIndexStore
    private let registry: AssetPreviewRegistry

    public init(
        exporter: CyberpunkXBMExporter = CyberpunkXBMExporter(),
        searcher: ArchiveCatalogIndexStore = ArchiveCatalogIndexStore(),
        registry: AssetPreviewRegistry = AssetPreviewRegistry()
    ) {
        self.exporter = exporter
        self.searcher = searcher
        self.registry = registry
    }

    public func run(options: CyberpunkXBMBatchExportOptions) throws -> CyberpunkXBMBatchExportReport {
        let archivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(options.archivePath)
        let extractedRoot = options.extractedRoot.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: extractedRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CyberMacError.notFound("Extracted-root directory does not exist: \(extractedRoot.path)")
        }
        guard options.limit > 0 else {
            throw CyberMacError.invalidInput("Batch export limit must be greater than zero.")
        }

        let outputDirectory = options.outputDirectory.standardizedFileURL
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let databaseURL = options.databaseURL ?? ArchiveCatalogIndexDefaults.databaseURL
        let query = options.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedQuery = (query?.isEmpty ?? true) ? Self.defaultListAllXBMQuery : query!

        let searchReport = try searcher.search(options: ArchiveCatalogIndexSearchOptions(
            query: resolvedQuery,
            databaseURL: databaseURL,
            extensionFilter: Self.xbmExtensionFilter,
            archiveFilter: archivePath,
            categoryFilter: options.category,
            limit: options.limit
        ))

        var entries: [CyberpunkXBMBatchExportEntry] = []
        var exportedCount = 0
        var skippedCount = 0
        var registeredCount = 0
        var failureCountsByKind: [CyberpunkXBMBatchExportFailureKind: Int] = [:]

        for match in searchReport.matches {
            let entry = exportOne(
                match: match,
                archivePath: archivePath,
                extractedRoot: extractedRoot,
                outputDirectory: outputDirectory,
                databaseURL: databaseURL,
                options: options
            )
            switch entry.outcome {
            case .exported:
                exportedCount += 1
                if entry.registered { registeredCount += 1 }
            case .skippedExisting:
                skippedCount += 1
            case .failed(let kind, _):
                failureCountsByKind[kind, default: 0] += 1
            }
            entries.append(entry)
        }

        return CyberpunkXBMBatchExportReport(
            archivePath: archivePath,
            extractedRootPath: extractedRoot.path,
            outputDirectoryPath: outputDirectory.path,
            databasePath: databaseURL.standardizedFileURL.path,
            query: resolvedQuery,
            category: options.category,
            limit: options.limit,
            totalMatched: searchReport.totalMatchCount,
            totalProcessed: searchReport.matches.count,
            entries: entries,
            exportedCount: exportedCount,
            skippedCount: skippedCount,
            failureCountsByKind: failureCountsByKind,
            registeredCount: registeredCount
        )
    }

    private func exportOne(
        match: ArchiveCatalogIndexSearchMatch,
        archivePath: String,
        extractedRoot: URL,
        outputDirectory: URL,
        databaseURL: URL,
        options: CyberpunkXBMBatchExportOptions
    ) -> CyberpunkXBMBatchExportEntry {
        let previewFileName = Self.encodedPreviewFileName(forAssetPath: match.assetPath)
        let previewURL = outputDirectory.appendingPathComponent(previewFileName)
        let inputURL = Self.resolveInputURL(extractedRoot: extractedRoot, assetPath: match.assetPath)

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            return CyberpunkXBMBatchExportEntry(
                assetPath: match.assetPath,
                archivePath: match.archivePath,
                resolvedInputPath: inputURL.path,
                previewPath: previewURL.path,
                outcome: .failed(.missingFile, reason: "Extracted .xbm not found at \(inputURL.path).")
            )
        }

        if options.skipExisting && FileManager.default.fileExists(atPath: previewURL.path) {
            return CyberpunkXBMBatchExportEntry(
                assetPath: match.assetPath,
                archivePath: match.archivePath,
                resolvedInputPath: inputURL.path,
                previewPath: previewURL.path,
                outcome: .skippedExisting
            )
        }

        let exportOptions = CyberpunkXBMExportOptions(
            outputURL: previewURL,
            debug: options.debug,
            register: false, // batch handles registration after the export succeeds
            archivePath: archivePath,
            assetPath: match.assetPath,
            databaseURL: databaseURL,
            sourceTool: options.sourceTool,
            krakenLibraryPath: options.krakenLibraryPath
        )

        let result: CyberpunkXBMExportResult
        do {
            result = try exporter.export(fileURL: inputURL, options: exportOptions)
        } catch let failure as CyberpunkXBMExportFailure {
            return CyberpunkXBMBatchExportEntry(
                assetPath: match.assetPath,
                archivePath: match.archivePath,
                resolvedInputPath: inputURL.path,
                previewPath: previewURL.path,
                outcome: .failed(.from(failure.kind), reason: failure.reason),
                compressionName: failure.detectedCompressionName
            )
        } catch {
            return CyberpunkXBMBatchExportEntry(
                assetPath: match.assetPath,
                archivePath: match.archivePath,
                resolvedInputPath: inputURL.path,
                previewPath: previewURL.path,
                outcome: .failed(.decodeFailure, reason: String(describing: error))
            )
        }

        var registered = false
        if options.register {
            do {
                _ = try registry.register(options: AssetPreviewRegisterOptions(
                    databaseURL: databaseURL,
                    archivePath: archivePath,
                    assetPath: match.assetPath,
                    previewURL: previewURL,
                    kind: AssetPreviewKind.textureThumbnail,
                    sourceTool: options.sourceTool
                ))
                registered = true
            } catch {
                return CyberpunkXBMBatchExportEntry(
                    assetPath: match.assetPath,
                    archivePath: match.archivePath,
                    resolvedInputPath: inputURL.path,
                    previewPath: previewURL.path,
                    outcome: .failed(.registrationFailure, reason: String(describing: error)),
                    width: result.width,
                    height: result.height,
                    compressionName: result.compressionName,
                    decoderUsed: result.decoderUsed,
                    krakenUsed: result.krakenUsed
                )
            }
        }

        return CyberpunkXBMBatchExportEntry(
            assetPath: match.assetPath,
            archivePath: match.archivePath,
            resolvedInputPath: inputURL.path,
            previewPath: previewURL.path,
            outcome: .exported,
            width: result.width,
            height: result.height,
            compressionName: result.compressionName,
            decoderUsed: result.decoderUsed,
            krakenUsed: result.krakenUsed,
            registered: registered
        )
    }

    /// Maps a CR2W asset path (e.g. `base\foo\bar.xbm`) to a path under the
    /// extracted root. Backslashes are converted to slashes so callers can
    /// pass either Windows-style or POSIX-style asset paths.
    public static func resolveInputURL(extractedRoot: URL, assetPath: String) -> URL {
        let normalized = assetPath.replacingOccurrences(of: "\\", with: "/")
        return extractedRoot.appendingPathComponent(normalized).standardizedFileURL
    }

    /// Encodes an asset path into a single safe filename for the flat
    /// output directory: `base\foo\bar.xbm` -> `base__foo__bar.xbm.png`.
    /// Backslashes/slashes become `__` so it's a single path component;
    /// `..` is stripped from the result for filesystem safety; `.png` is
    /// appended. The encoding is intentionally readable so the asset can
    /// be identified by eye.
    public static func encodedPreviewFileName(forAssetPath assetPath: String) -> String {
        var encoded = assetPath
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != ".." && $0 != "." }
            .joined(separator: "__")
        if encoded.isEmpty {
            encoded = "unnamed"
        }
        return encoded + ".png"
    }
}

// MARK: - Formatter

public enum CyberpunkXBMBatchExportFormatter {
    /// Default failure-example cap in compact (non-debug) mode. The first N
    /// failures are printed in full; remaining ones are summarised as a
    /// "... and X more" line. Debug mode prints every entry.
    public static let compactFailureExampleLimit = 20

    public static func format(_ report: CyberpunkXBMBatchExportReport, debug: Bool) -> String {
        var lines = [
            "Cyberpunk XBM batch export",
            "Archive: \(report.archivePath)",
            "Extracted root: \(PathSafety.redactUserPath(report.extractedRootPath))",
            "Output dir: \(PathSafety.redactUserPath(report.outputDirectoryPath))"
        ]
        if let databasePath = report.databasePath {
            lines.append("Database: \(PathSafety.redactUserPath(databasePath))")
        }
        lines.append("Query: \(report.query)")
        if let category = report.category {
            lines.append("Category: \(category)")
        }
        lines.append("Matched: \(report.totalMatched) (processed \(report.totalProcessed) of limit \(report.limit))")
        lines.append("")
        lines.append("Exported: \(report.exportedCount)")
        lines.append("Skipped (existing): \(report.skippedCount)")
        lines.append("Registered: \(report.registeredCount)")
        let totalFailed = report.failureCountsByKind.values.reduce(0, +)
        lines.append("Failed: \(totalFailed)")
        if !report.failureCountsByKind.isEmpty {
            lines.append("Failure breakdown:")
            for kind in CyberpunkXBMBatchExportFailureKind.allCases {
                if let count = report.failureCountsByKind[kind], count > 0 {
                    lines.append("  - \(kind.humanReadable): \(count)")
                }
            }
        }

        if debug {
            // Debug: dump every per-asset row (success, skip, failure).
            if !report.entries.isEmpty {
                lines.append("")
                lines.append("Per-asset detail:")
                for entry in report.entries {
                    lines.append(perAssetLine(entry))
                }
            }
        } else if totalFailed > 0 {
            // Compact: failures only, capped — successes are summarised by the counts above.
            let failureEntries = report.entries.compactMap { entry -> CyberpunkXBMBatchExportEntry? in
                if case .failed = entry.outcome { return entry }
                return nil
            }
            if !failureEntries.isEmpty {
                lines.append("")
                lines.append("Failures (showing \(min(failureEntries.count, compactFailureExampleLimit)) of \(failureEntries.count); re-run with --debug for full detail):")
                for entry in failureEntries.prefix(compactFailureExampleLimit) {
                    lines.append(perAssetLine(entry))
                }
                if failureEntries.count > compactFailureExampleLimit {
                    lines.append("  ... and \(failureEntries.count - compactFailureExampleLimit) more")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func perAssetLine(_ entry: CyberpunkXBMBatchExportEntry) -> String {
        switch entry.outcome {
        case .exported:
            var line = "  ✓ \(entry.assetPath) -> \(PathSafety.redactUserPath(entry.previewPath))"
            if let decoder = entry.decoderUsed,
               let width = entry.width,
               let height = entry.height {
                line += " [\(decoder) \(width)x\(height)\(entry.krakenUsed ? " kraken" : "")]"
            }
            if entry.registered { line += " [registered]" }
            return line
        case .skippedExisting:
            return "  · \(entry.assetPath) -> existing PNG, skipped"
        case .failed(let kind, let reason):
            return "  ✗ \(entry.assetPath) [\(kind.humanReadable)] \(reason)"
        }
    }
}
