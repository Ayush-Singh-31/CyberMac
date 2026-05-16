import Foundation

public struct ArchiveCatalogSearchOptions: Equatable, Sendable {
    public let query: String
    public let catalogDirectory: URL
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let limit: Int

    public init(
        query: String,
        catalogDirectory: URL,
        extensionFilter: String? = nil,
        archiveFilter: String? = nil,
        limit: Int = 50
    ) {
        self.query = query
        self.catalogDirectory = catalogDirectory
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.limit = limit
    }
}

public struct ArchiveCatalogSearchMatch: Equatable, Sendable {
    public let archivePath: String?
    public let assetPath: String
    public let assetExtension: String
    public let sourceCatalogFile: String

    public init(
        archivePath: String?,
        assetPath: String,
        assetExtension: String,
        sourceCatalogFile: String
    ) {
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.assetExtension = assetExtension
        self.sourceCatalogFile = sourceCatalogFile
    }
}

public struct ArchiveCatalogSearchReport: Equatable, Sendable {
    public let query: String
    public let catalogDirectoryPath: String
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let limit: Int
    public let totalMatchCount: Int
    public let matches: [ArchiveCatalogSearchMatch]

    public init(
        query: String,
        catalogDirectoryPath: String,
        extensionFilter: String?,
        archiveFilter: String?,
        limit: Int,
        totalMatchCount: Int,
        matches: [ArchiveCatalogSearchMatch]
    ) {
        self.query = query
        self.catalogDirectoryPath = catalogDirectoryPath
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.limit = limit
        self.totalMatchCount = totalMatchCount
        self.matches = matches
    }
}

public struct ArchiveCatalogSearcher: Sendable {
    private struct MatchKey: Hashable {
        let archivePath: String
        let assetPath: String
        let sourceCatalogFile: String
    }

    public init() {}

    public func search(options: ArchiveCatalogSearchOptions) throws -> ArchiveCatalogSearchReport {
        let query = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw CyberMacError.invalidInput("Archive catalog query cannot be empty.")
        }
        guard options.limit > 0 else {
            throw CyberMacError.invalidInput("Archive catalog limit must be greater than zero.")
        }

        let extensionFilter = try ArchiveCatalogParser.normalizedExtensionFilter(options.extensionFilter)
        let archiveFilter = try options.archiveFilter.map {
            try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath($0)
        }
        let catalogDirectory = options.catalogDirectory.resolvingSymlinksInPath().standardizedFileURL
        try ArchiveCatalogParser.validateCatalogDirectory(catalogDirectory)

        var matches: [ArchiveCatalogSearchMatch] = []
        var seenKeys = Set<MatchKey>()

        for catalogFile in try ArchiveCatalogParser.catalogFiles(under: catalogDirectory) {
            let sourceCatalogFile = try PathSafety.relativePath(of: catalogFile, in: catalogDirectory)
            let text = try ArchiveCatalogParser.readCatalogText(catalogFile)
            let archivePath = ArchiveCatalogParser.inferArchivePath(sourceCatalogFile: sourceCatalogFile, text: text)

            if let archiveFilter, archivePath != archiveFilter {
                continue
            }

            for line in text.split(whereSeparator: \.isNewline) {
                for assetPath in ArchiveCatalogParser.assetPathCandidates(in: String(line)) {
                    guard assetPath.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
                        continue
                    }
                    guard let assetExtension = ArchiveCatalogParser.assetExtension(assetPath) else {
                        continue
                    }
                    if let extensionFilter, assetExtension != extensionFilter {
                        continue
                    }

                    let key = MatchKey(
                        archivePath: archivePath ?? "",
                        assetPath: assetPath,
                        sourceCatalogFile: sourceCatalogFile
                    )
                    guard seenKeys.insert(key).inserted else { continue }
                    matches.append(ArchiveCatalogSearchMatch(
                        archivePath: archivePath,
                        assetPath: assetPath,
                        assetExtension: assetExtension,
                        sourceCatalogFile: sourceCatalogFile
                    ))
                }
            }
        }

        matches.sort { lhs, rhs in
            let leftArchive = lhs.archivePath ?? ""
            let rightArchive = rhs.archivePath ?? ""
            if leftArchive != rightArchive {
                return leftArchive < rightArchive
            }
            if lhs.assetPath != rhs.assetPath {
                return lhs.assetPath < rhs.assetPath
            }
            return lhs.sourceCatalogFile < rhs.sourceCatalogFile
        }

        return ArchiveCatalogSearchReport(
            query: query,
            catalogDirectoryPath: catalogDirectory.path,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            limit: options.limit,
            totalMatchCount: matches.count,
            matches: Array(matches.prefix(options.limit))
        )
    }
}

public enum ArchiveCatalogSearchFormatter {
    public static func format(_ report: ArchiveCatalogSearchReport) -> String {
        var lines = [
            "Archive catalog search",
            "Query: \(report.query)",
            "Catalog dir: \(PathSafety.redactUserPath(report.catalogDirectoryPath))"
        ]
        if let extensionFilter = report.extensionFilter {
            lines.append("Extension: \(extensionFilter)")
        }
        if let archiveFilter = report.archiveFilter {
            lines.append("Archive: \(archiveFilter)")
        }

        guard !report.matches.isEmpty else {
            lines.append("No archive catalog matches found for query: \(report.query)")
            return lines.joined(separator: "\n")
        }

        lines.append("Matches: \(report.matches.count)")
        if report.totalMatchCount > report.matches.count {
            lines.append("Showing: \(report.matches.count) of \(report.totalMatchCount)")
        }
        for match in report.matches {
            lines.append([
                match.archivePath ?? "unknown",
                match.assetPath,
                match.assetExtension,
                match.sourceCatalogFile
            ].joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }
}
