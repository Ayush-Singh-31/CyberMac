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

        let extensionFilter = try Self.normalizedExtensionFilter(options.extensionFilter)
        let archiveFilter = try options.archiveFilter.map {
            try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath($0)
        }
        let catalogDirectory = options.catalogDirectory.resolvingSymlinksInPath().standardizedFileURL
        try Self.validateCatalogDirectory(catalogDirectory)

        var matches: [ArchiveCatalogSearchMatch] = []
        var seenKeys = Set<MatchKey>()

        for catalogFile in try Self.catalogFiles(under: catalogDirectory) {
            let sourceCatalogFile = try PathSafety.relativePath(of: catalogFile, in: catalogDirectory)
            let text = try Self.readCatalogText(catalogFile)
            let archivePath = Self.inferArchivePath(sourceCatalogFile: sourceCatalogFile, text: text)

            if let archiveFilter, archivePath != archiveFilter {
                continue
            }

            for line in text.split(whereSeparator: \.isNewline) {
                for assetPath in Self.assetPathCandidates(in: String(line)) {
                    guard assetPath.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
                        continue
                    }
                    guard let assetExtension = Self.assetExtension(assetPath) else {
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

    private static func validateCatalogDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Archive catalog directory must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("Archive catalog directory does not exist: \(url.path)")
        }
    }

    private static func catalogFiles(under catalogDirectory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: catalogDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                continue
            }
            files.append(url.standardizedFileURL)
        }

        return try files.sorted {
            try PathSafety.relativePath(of: $0, in: catalogDirectory) < PathSafety.relativePath(of: $1, in: catalogDirectory)
        }
    }

    private static func readCatalogText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CyberMacError.invalidInput("Archive catalog file is not UTF-8 text: \(url.path)")
        }
        return text
    }

    private static func normalizedExtensionFilter(_ rawExtension: String?) throws -> String? {
        guard let rawExtension else { return nil }
        let value = rawExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard !value.isEmpty else {
            throw CyberMacError.invalidInput("Archive catalog extension filter cannot be empty.")
        }
        guard !value.contains("/"), !value.contains("\\") else {
            throw CyberMacError.invalidInput("Archive catalog extension filter must not contain path separators: \(rawExtension)")
        }
        return value
    }

    private static func assetPathCandidates(in line: String) -> [String] {
        line.components(separatedBy: .whitespacesAndNewlines)
            .compactMap(cleanedToken)
            .filter(isAssetPath)
    }

    private static func cleanedToken(_ rawToken: String) -> String? {
        let trimCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'`[](){}<>:,;"))
        var token = rawToken.trimmingCharacters(in: trimCharacters)
        if let delimiterIndex = token.lastIndex(where: { $0 == "=" || $0 == ":" }) {
            let value = String(token[token.index(after: delimiterIndex)...])
                .trimmingCharacters(in: trimCharacters)
            if value.contains("/") || value.contains("\\") {
                token = value
            }
        }
        return token.isEmpty ? nil : token
    }

    private static func isAssetPath(_ token: String) -> Bool {
        let normalized = token.replacingOccurrences(of: "\\", with: "/")
        guard normalized.contains("/") else { return false }
        guard !normalized.hasPrefix("/") else { return false }
        guard !normalized.split(separator: "/").contains("..") else { return false }
        guard !normalized.lowercased().hasPrefix("data/archive/") else { return false }
        guard let assetExtension = assetExtension(token), assetExtension != "archive" else { return false }
        return true
    }

    private static func assetExtension(_ assetPath: String) -> String? {
        let normalized = assetPath.replacingOccurrences(of: "\\", with: "/")
        guard let fileName = normalized.split(separator: "/").last else { return nil }
        guard let dotIndex = fileName.lastIndex(of: "."),
              dotIndex != fileName.startIndex,
              dotIndex != fileName.index(before: fileName.endIndex)
        else {
            return nil
        }
        return String(fileName[fileName.index(after: dotIndex)...]).lowercased()
    }

    private static func inferArchivePath(sourceCatalogFile: String, text: String) -> String? {
        let headerText = text
            .split(whereSeparator: \.isNewline)
            .prefix(20)
            .joined(separator: "\n")
        let explicitCandidates = officialArchivePathCandidates(in: "\(sourceCatalogFile)\n\(headerText)")
        if explicitCandidates.count == 1 {
            return explicitCandidates.first
        }

        return inferArchivePathFromCatalogFileName(sourceCatalogFile)
    }

    private static func officialArchivePathCandidates(in text: String) -> Set<String> {
        let pattern = #"Data[/_\\-]archive[/_\\-]Mac[/_\\-](content|ep1)[/_\\-]([A-Za-z0-9._-]+?\.archive)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var candidates = Set<String>()
        for match in regex.matches(in: text, options: [], range: range) {
            guard match.numberOfRanges == 3,
                  let directoryRange = Range(match.range(at: 1), in: text),
                  let fileRange = Range(match.range(at: 2), in: text)
            else {
                continue
            }
            let directory = String(text[directoryRange]).lowercased()
            let fileName = String(text[fileRange])
            let relativePath = "Data/archive/Mac/\(directory)/\(fileName)"
            if let validated = try? OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(relativePath) {
                candidates.insert(validated)
            }
        }
        return candidates
    }

    private static func inferArchivePathFromCatalogFileName(_ sourceCatalogFile: String) -> String? {
        let pattern = #"([A-Za-z0-9._-]+?\.archive)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(sourceCatalogFile.startIndex..<sourceCatalogFile.endIndex, in: sourceCatalogFile)
        let matches = regex.matches(in: sourceCatalogFile, options: [], range: range)
        let names = Set(matches.compactMap { match -> String? in
            guard let matchRange = Range(match.range(at: 1), in: sourceCatalogFile) else { return nil }
            return String(sourceCatalogFile[matchRange])
        })
        guard names.count == 1, let archiveName = names.first else {
            return nil
        }

        let lowerSource = sourceCatalogFile.lowercased()
        let lowerArchiveName = archiveName.lowercased()
        let directory: String?
        if lowerSource.contains("/ep1/")
            || lowerSource.contains("_ep1_")
            || lowerArchiveName.hasPrefix("ep1_") {
            directory = "ep1"
        } else if lowerSource.contains("/content/")
                    || lowerSource.contains("_content_")
                    || lowerArchiveName.hasPrefix("basegame_")
                    || lowerArchiveName.hasPrefix("memoryresident_") {
            directory = "content"
        } else {
            directory = nil
        }

        guard let directory else { return nil }
        return try? OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(
            "Data/archive/Mac/\(directory)/\(archiveName)"
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
