import Foundation

public struct ArchiveMatchAnalysisRequest: Equatable, Sendable {
    public static let defaultUnmatchedLimit = 50

    public let modArchiveURL: URL
    public let workDirectoryURL: URL
    public let cp77toolsURL: URL
    public let databaseURL: URL
    public let unmatchedLimit: Int

    public init(
        modArchiveURL: URL,
        workDirectoryURL: URL,
        cp77toolsURL: URL,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        unmatchedLimit: Int = ArchiveMatchAnalysisRequest.defaultUnmatchedLimit
    ) {
        self.modArchiveURL = modArchiveURL
        self.workDirectoryURL = workDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.databaseURL = databaseURL
        self.unmatchedLimit = unmatchedLimit
    }
}

public enum ArchiveMatchReadinessStatus: String, Equatable, Sendable {
    case readySingleArchive = "READY_SINGLE_ARCHIVE"
    case readyMultiArchive = "READY_MULTI_ARCHIVE"
    case partialMatch = "PARTIAL_MATCH"
    case noMatch = "NO_MATCH"
}

public struct ArchiveMatchOfficialArchiveGroup: Equatable, Sendable {
    public let officialArchivePath: String
    public let matchedAssetPaths: [String]

    public var matchedFileCount: Int { matchedAssetPaths.count }

    public init(officialArchivePath: String, matchedAssetPaths: [String]) {
        self.officialArchivePath = officialArchivePath
        self.matchedAssetPaths = matchedAssetPaths
    }
}

public struct ArchiveMatchAnalysisResult: Equatable, Sendable {
    public let modArchivePath: String
    public let databasePath: String
    public let workDirectoryPath: String
    public let cp77toolsPath: String
    public let unmatchedLimit: Int
    public let modFileCount: Int
    public let exactMatchCount: Int
    public let unmatchedCount: Int
    public let matchesByOfficialArchive: [ArchiveMatchOfficialArchiveGroup]
    public let unmatchedModAssetPaths: [String]
    public let unmatchedSampleCount: Int
    public let readinessStatus: ArchiveMatchReadinessStatus
    public let suggestedStageMergeCommand: String?
    public let requiredOfficialArchives: [String]

    public init(
        modArchivePath: String,
        databasePath: String,
        workDirectoryPath: String,
        cp77toolsPath: String,
        unmatchedLimit: Int,
        modFileCount: Int,
        exactMatchCount: Int,
        unmatchedCount: Int,
        matchesByOfficialArchive: [ArchiveMatchOfficialArchiveGroup],
        unmatchedModAssetPaths: [String],
        unmatchedSampleCount: Int,
        readinessStatus: ArchiveMatchReadinessStatus,
        suggestedStageMergeCommand: String?,
        requiredOfficialArchives: [String]
    ) {
        self.modArchivePath = modArchivePath
        self.databasePath = databasePath
        self.workDirectoryPath = workDirectoryPath
        self.cp77toolsPath = cp77toolsPath
        self.unmatchedLimit = unmatchedLimit
        self.modFileCount = modFileCount
        self.exactMatchCount = exactMatchCount
        self.unmatchedCount = unmatchedCount
        self.matchesByOfficialArchive = matchesByOfficialArchive
        self.unmatchedModAssetPaths = unmatchedModAssetPaths
        self.unmatchedSampleCount = unmatchedSampleCount
        self.readinessStatus = readinessStatus
        self.suggestedStageMergeCommand = suggestedStageMergeCommand
        self.requiredOfficialArchives = requiredOfficialArchives
    }
}

public struct ArchiveMatchAnalyzer {
    private let tooling: any OfficialArchiveSwapTooling
    private let indexStore: ArchiveCatalogIndexStore

    public init(
        tooling: any OfficialArchiveSwapTooling = CP77ToolsArchiveSwapTooling(),
        indexStore: ArchiveCatalogIndexStore = ArchiveCatalogIndexStore()
    ) {
        self.tooling = tooling
        self.indexStore = indexStore
    }

    public func analyze(request: ArchiveMatchAnalysisRequest) throws -> ArchiveMatchAnalysisResult {
        guard request.unmatchedLimit >= 0 else {
            throw CyberMacError.invalidInput("Unmatched limit must be zero or positive.")
        }

        let modArchiveURL = request.modArchiveURL.standardizedFileURL
        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        let databaseURL = request.databaseURL.standardizedFileURL

        try validateModArchiveURL(modArchiveURL)
        try validateCP77ToolsURL(cp77toolsURL)
        try validateDatabaseURL(databaseURL)
        try validateWorkDirectoryURL(workDirectoryURL)

        let modExtractionDirectory = workDirectoryURL.appendingPathComponent("mod", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: modExtractionDirectory.path) else {
            throw CyberMacError.invalidInput("Stage directory already exists: \(modExtractionDirectory.path). Use a clean work directory for match-mod.")
        }

        try tooling.extractArchive(
            cp77toolsURL: cp77toolsURL,
            sourceArchiveURL: modArchiveURL,
            outputDirectoryURL: modExtractionDirectory
        )

        let modAssetPaths = try collectExtractedAssetPaths(under: modExtractionDirectory)
        let modFileCount = modAssetPaths.count

        let matchMap = try indexStore.findExactAssetPathMatches(
            databaseURL: databaseURL,
            assetPaths: modAssetPaths
        )

        let matchedModPaths = matchMap.keys
        let exactMatchCount = matchedModPaths.count
        let unmatchedCount = modFileCount - exactMatchCount

        var groupsByArchive: [String: [String]] = [:]
        for (modPath, archives) in matchMap {
            for archivePath in archives {
                groupsByArchive[archivePath, default: []].append(modPath)
            }
        }
        let matchesByOfficialArchive = groupsByArchive
            .map { ArchiveMatchOfficialArchiveGroup(officialArchivePath: $0.key, matchedAssetPaths: $0.value.sorted()) }
            .sorted { $0.officialArchivePath < $1.officialArchivePath }

        let unmatchedAll = modAssetPaths.filter { matchMap[$0] == nil }
        let unmatchedSample = Array(unmatchedAll.prefix(request.unmatchedLimit))

        let readinessStatus: ArchiveMatchReadinessStatus
        var suggestedStageMergeCommand: String?
        var requiredOfficialArchives: [String] = []

        if modFileCount == 0 {
            readinessStatus = .noMatch
        } else if exactMatchCount == 0 {
            readinessStatus = .noMatch
        } else if exactMatchCount < modFileCount {
            readinessStatus = .partialMatch
        } else {
            let coveringArchives = singleArchivesCoveringAll(
                matchMap: matchMap,
                modAssetPaths: modAssetPaths
            )
            if let chosen = coveringArchives.first {
                readinessStatus = .readySingleArchive
                requiredOfficialArchives = [chosen]
                suggestedStageMergeCommand = Self.makeStageMergeCommand(
                    officialArchive: chosen,
                    modArchiveURL: modArchiveURL,
                    workDirectoryURL: workDirectoryURL,
                    cp77toolsURL: cp77toolsURL
                )
            } else {
                readinessStatus = .readyMultiArchive
                requiredOfficialArchives = minimumCoveringArchives(
                    matchMap: matchMap,
                    modAssetPaths: modAssetPaths
                )
            }
        }

        return ArchiveMatchAnalysisResult(
            modArchivePath: modArchiveURL.path,
            databasePath: databaseURL.path,
            workDirectoryPath: workDirectoryURL.path,
            cp77toolsPath: cp77toolsURL.path,
            unmatchedLimit: request.unmatchedLimit,
            modFileCount: modFileCount,
            exactMatchCount: exactMatchCount,
            unmatchedCount: unmatchedCount,
            matchesByOfficialArchive: matchesByOfficialArchive,
            unmatchedModAssetPaths: unmatchedSample,
            unmatchedSampleCount: unmatchedSample.count,
            readinessStatus: readinessStatus,
            suggestedStageMergeCommand: suggestedStageMergeCommand,
            requiredOfficialArchives: requiredOfficialArchives
        )
    }

    private func collectExtractedAssetPaths(under rootURL: URL) throws -> [String] {
        let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Mod extraction root is a symlink: \(rootURL.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("Mod extraction root does not exist: \(rootURL.path)")
        }
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return []
        }

        var paths: [String] = []
        var seen = Set<String>()
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard resource.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("Mod extraction contains a symlink: \(url.path)")
            }
            guard resource.isRegularFile == true else { continue }

            try validateContainedPath(url, in: rootURL, description: "Mod extraction")
            let raw = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            let normalized = try Self.validatedAssetPath(raw.replacingOccurrences(of: "\\", with: "/"))
            guard seen.insert(normalized).inserted else {
                throw CyberMacError.invalidInput("Mod extraction contains duplicate asset path after normalization: \(normalized)")
            }
            paths.append(normalized)
        }
        paths.sort()
        return paths
    }

    private static func validatedAssetPath(_ rawPath: String) throws -> String {
        guard !rawPath.isEmpty else {
            throw CyberMacError.unsafePath("Mod extraction asset path is empty.")
        }
        guard !rawPath.hasPrefix("/") else {
            throw CyberMacError.unsafePath("Mod extraction asset path must be relative: \(rawPath)")
        }
        guard !rawPath.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("Mod extraction asset path contains control characters: \(rawPath)")
        }
        let components = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains(where: { $0.isEmpty }) else {
            throw CyberMacError.unsafePath("Mod extraction asset path contains an empty component: \(rawPath)")
        }
        guard !components.contains("."), !components.contains("..") else {
            throw CyberMacError.unsafePath("Mod extraction asset path contains traversal: \(rawPath)")
        }
        return components.joined(separator: "/")
    }

    private func singleArchivesCoveringAll(
        matchMap: [String: [String]],
        modAssetPaths: [String]
    ) -> [String] {
        guard !modAssetPaths.isEmpty else { return [] }
        var intersection: Set<String>?
        for path in modAssetPaths {
            let archives = Set(matchMap[path] ?? [])
            if archives.isEmpty { return [] }
            if let current = intersection {
                intersection = current.intersection(archives)
            } else {
                intersection = archives
            }
            if intersection?.isEmpty == true { return [] }
        }
        return (intersection ?? []).sorted()
    }

    private func minimumCoveringArchives(
        matchMap: [String: [String]],
        modAssetPaths: [String]
    ) -> [String] {
        var uncovered = Set(modAssetPaths.filter { matchMap[$0] != nil })
        var archiveToPaths: [String: Set<String>] = [:]
        for (path, archives) in matchMap {
            for archive in archives {
                archiveToPaths[archive, default: []].insert(path)
            }
        }

        var chosen: [String] = []
        while !uncovered.isEmpty {
            let candidates = archiveToPaths.map { (archive, paths) -> (String, Int) in
                (archive, paths.intersection(uncovered).count)
            }
            let best = candidates
                .filter { $0.1 > 0 }
                .sorted { lhs, rhs in
                    if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                    return lhs.0 < rhs.0
                }
                .first
            guard let pick = best else { break }
            chosen.append(pick.0)
            let pickedPaths = archiveToPaths[pick.0] ?? []
            uncovered.subtract(pickedPaths)
            archiveToPaths.removeValue(forKey: pick.0)
        }
        return chosen.sorted()
    }

    private static func makeStageMergeCommand(
        officialArchive: String,
        modArchiveURL: URL,
        workDirectoryURL: URL,
        cp77toolsURL: URL
    ) -> String {
        let stageWorkDir = workDirectoryURL.appendingPathComponent("stage-merge", isDirectory: true).path
        let outArchive = workDirectoryURL.appendingPathComponent("patched.archive").path
        return [
            "cybermac archive-patch stage-merge \(officialArchive)",
            "  --mod-archive \(modArchiveURL.path)",
            "  --work-dir \(stageWorkDir)",
            "  --out \(outArchive)",
            "  --cp77tools \(cp77toolsURL.path)"
        ].joined(separator: " \\\n")
    }

    private func validateModArchiveURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "Mod archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Mod archive path must end in .archive: \(url.path)")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Mod archive does not exist: \(url.path)")
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Mod archive is a symlink: \(url.path)")
        }
        guard values.isRegularFile == true else {
            throw CyberMacError.invalidInput("Mod archive is not a regular file: \(url.path)")
        }
    }

    private func validateCP77ToolsURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "cp77tools path")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw CyberMacError.notFound("cp77tools executable not found: \(url.path)")
        }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CyberMacError.invalidInput("cp77tools path is not executable: \(url.path)")
        }
    }

    private func validateDatabaseURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "Archive catalog index database")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("Archive catalog index database does not exist: \(url.path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("Archive catalog index database path is a directory: \(url.path)")
        }
    }

    private func validateWorkDirectoryURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "Work directory")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Work directory must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.invalidInput("Work directory is not a directory: \(url.path)")
        }
    }

    private func validateLocalTargetURL(_ url: URL, description: String) throws {
        guard url.isFileURL else {
            throw CyberMacError.unsafePath("\(description) must be a file URL: \(url.absoluteString)")
        }
        let path = url.path
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.unsafePath("\(description) path is empty.")
        }
        guard path.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(description) path must be absolute: \(path)")
        }
        guard !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(description) path contains control characters.")
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.contains("..") else {
            throw CyberMacError.unsafePath("\(description) path contains traversal: \(path)")
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

public enum ArchiveMatchAnalysisFormatter {
    public static func format(_ result: ArchiveMatchAnalysisResult) -> String {
        var lines: [String] = [
            "Archive mod match analysis",
            "Mod archive: \(result.modArchivePath)",
            "Database: \(PathSafety.redactUserPath(result.databasePath))",
            "Mod files: \(result.modFileCount)",
            "Exact matches: \(result.exactMatchCount)",
            "Unmatched: \(result.unmatchedCount)",
            "Readiness: \(result.readinessStatus.rawValue)"
        ]

        lines.append("")
        if result.matchesByOfficialArchive.isEmpty {
            lines.append("Matches grouped by official archive: (none)")
        } else {
            lines.append("Matches grouped by official archive:")
            for group in result.matchesByOfficialArchive {
                lines.append("- \(group.officialArchivePath)")
                lines.append("  Matched files: \(group.matchedFileCount)")
                for assetPath in group.matchedAssetPaths {
                    lines.append("  - \(assetPath)")
                }
            }
        }

        if result.unmatchedCount > 0 {
            lines.append("")
            if result.unmatchedSampleCount < result.unmatchedCount {
                lines.append("Unmatched mod asset paths (showing \(result.unmatchedSampleCount) of \(result.unmatchedCount), limit \(result.unmatchedLimit)):")
            } else {
                lines.append("Unmatched mod asset paths (\(result.unmatchedCount)):")
            }
            for path in result.unmatchedModAssetPaths {
                lines.append("- \(path)")
            }
        }

        lines.append("")
        switch result.readinessStatus {
        case .readySingleArchive:
            lines.append("Suggested stage-merge command:")
            if let command = result.suggestedStageMergeCommand {
                lines.append(command)
            }
        case .readyMultiArchive:
            lines.append("Automatic single-archive staging is not enough yet.")
            lines.append("Required official archives:")
            for archive in result.requiredOfficialArchives {
                lines.append("- \(archive)")
            }
        case .partialMatch:
            lines.append("Partial match only. Loose archive loading remains blocked.")
            lines.append("This mod is not a clean exact-path conversion. Do not install.")
        case .noMatch:
            lines.append("No exact-path matches against the indexed Mac official archives.")
            lines.append("Loose archive loading remains blocked. This mod is not a clean exact-path conversion. Do not install.")
        }

        return lines.joined(separator: "\n")
    }
}
