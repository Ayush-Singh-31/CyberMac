import Foundation

public struct OfficialArchiveMergeStageRequest: Equatable, Sendable {
    public let relativeArchivePath: String
    public let modArchiveURL: URL
    public let workDirectoryURL: URL
    public let outputArchiveURL: URL
    public let cp77toolsURL: URL

    public init(
        relativeArchivePath: String,
        modArchiveURL: URL,
        workDirectoryURL: URL,
        outputArchiveURL: URL,
        cp77toolsURL: URL
    ) {
        self.relativeArchivePath = relativeArchivePath
        self.modArchiveURL = modArchiveURL
        self.workDirectoryURL = workDirectoryURL
        self.outputArchiveURL = outputArchiveURL
        self.cp77toolsURL = cp77toolsURL
    }
}

public struct OfficialArchiveMergeReplacement: Equatable, Sendable {
    public let assetPath: String
    public let originalSHA256: String
    public let replacementSHA256: String

    public init(assetPath: String, originalSHA256: String, replacementSHA256: String) {
        self.assetPath = assetPath
        self.originalSHA256 = originalSHA256
        self.replacementSHA256 = replacementSHA256
    }
}

public struct OfficialArchiveMergeStageResult: Equatable, Sendable {
    public let relativeArchivePath: String
    public let officialArchivePath: String
    public let modArchivePath: String
    public let modFileCount: Int
    public let replacements: [OfficialArchiveMergeReplacement]
    public let unmatchedModAssetPaths: [String]
    public let outputArchivePath: String
    public let outputArchiveSHA256: String
    public let manualInstallCommand: String
    public let statusCommand: String
    public let preflightCommand: String

    public var exactMatchCount: Int { replacements.count }

    public init(
        relativeArchivePath: String,
        officialArchivePath: String,
        modArchivePath: String,
        modFileCount: Int,
        replacements: [OfficialArchiveMergeReplacement],
        unmatchedModAssetPaths: [String],
        outputArchivePath: String,
        outputArchiveSHA256: String,
        manualInstallCommand: String,
        statusCommand: String,
        preflightCommand: String
    ) {
        self.relativeArchivePath = relativeArchivePath
        self.officialArchivePath = officialArchivePath
        self.modArchivePath = modArchivePath
        self.modFileCount = modFileCount
        self.replacements = replacements
        self.unmatchedModAssetPaths = unmatchedModAssetPaths
        self.outputArchivePath = outputArchivePath
        self.outputArchiveSHA256 = outputArchiveSHA256
        self.manualInstallCommand = manualInstallCommand
        self.statusCommand = statusCommand
        self.preflightCommand = preflightCommand
    }
}

public struct OfficialArchiveMergeStager {
    private struct ExtractedFile {
        let assetPath: String
        let url: URL
    }

    private let home: CyberMacHomeManager
    private let tooling: any OfficialArchiveSwapTooling

    public init(
        home: CyberMacHomeManager,
        tooling: any OfficialArchiveSwapTooling = CP77ToolsArchiveSwapTooling()
    ) {
        self.home = home
        self.tooling = tooling
    }

    public func stage(
        request: OfficialArchiveMergeStageRequest,
        gameInstall: GameInstall
    ) throws -> OfficialArchiveMergeStageResult {
        let relativeArchivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(request.relativeArchivePath)
        let manager = OfficialArchiveBackupManager(home: home)
        let preflight = manager.preflight(relativeArchivePath: relativeArchivePath, gameInstall: gameInstall)
        switch preflight.status {
        case .pristine:
            break
        case .noBackup:
            throw CyberMacError.invalidInput("No matching CyberMac official archive backup exists. Run backup-official before staging a merge.")
        case .modified:
            throw CyberMacError.invalidInput("Current official archive is MODIFIED. Restore or verify the baseline before staging a new merge.")
        case .missing:
            throw CyberMacError.notFound("Official archive is missing from the game bundle: \(relativeArchivePath)")
        case .blocked:
            throw CyberMacError.invalidInput(preflight.reason ?? "Official archive preflight was blocked.")
        }

        guard let officialArchivePath = preflight.destinationPath else {
            throw CyberMacError.fileSystem("Official archive preflight did not resolve a source path.")
        }

        let officialArchiveURL = URL(fileURLWithPath: officialArchivePath).standardizedFileURL
        let modArchiveURL = request.modArchiveURL.standardizedFileURL
        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        let outputArchiveURL = request.outputArchiveURL.standardizedFileURL

        try validateModArchiveURL(modArchiveURL)
        try validateCP77ToolsURL(request.cp77toolsURL)
        try validateWorkDirectoryURL(workDirectoryURL, gameInstall: gameInstall)
        try validateOutputArchiveURL(outputArchiveURL, gameInstall: gameInstall)

        let officialDirectory = workDirectoryURL.appendingPathComponent("official", isDirectory: true)
        let modDirectory = workDirectoryURL.appendingPathComponent("mod", isDirectory: true)
        let packedDirectory = workDirectoryURL.appendingPathComponent("packed", isDirectory: true)
        for directory in [officialDirectory, modDirectory, packedDirectory] {
            guard !FileManager.default.fileExists(atPath: directory.path) else {
                throw CyberMacError.invalidInput("Stage directory already exists: \(directory.path). Use a clean work directory for stage-merge.")
            }
        }

        try tooling.extractArchive(
            cp77toolsURL: request.cp77toolsURL,
            sourceArchiveURL: officialArchiveURL,
            outputDirectoryURL: officialDirectory
        )
        try tooling.extractArchive(
            cp77toolsURL: request.cp77toolsURL,
            sourceArchiveURL: modArchiveURL,
            outputDirectoryURL: modDirectory
        )

        let officialFiles = try extractedFileMap(under: officialDirectory, description: "Official extraction")
        let modFiles = try extractedFileMap(under: modDirectory, description: "Mod extraction")
        let modAssetPaths = modFiles.keys.sorted()
        let exactMatchPaths = modAssetPaths.filter { officialFiles[$0] != nil }
        let unmatchedModAssetPaths = modAssetPaths.filter { officialFiles[$0] == nil }

        guard !exactMatchPaths.isEmpty else {
            throw CyberMacError.invalidInput("No exact path matches found between mod archive and official archive extraction.")
        }

        var replacements: [OfficialArchiveMergeReplacement] = []
        for assetPath in exactMatchPaths {
            guard let officialFileURL = officialFiles[assetPath],
                  let modFileURL = modFiles[assetPath]
            else {
                throw CyberMacError.fileSystem("Exact match disappeared while staging: \(assetPath)")
            }

            let originalSHA256 = try PathSafety.sha256(url: officialFileURL)
            let replacementSHA256 = try PathSafety.sha256(url: modFileURL)
            try FileManager.default.removeItem(at: officialFileURL)
            try FileManager.default.copyItem(at: modFileURL, to: officialFileURL)
            replacements.append(OfficialArchiveMergeReplacement(
                assetPath: assetPath,
                originalSHA256: originalSHA256,
                replacementSHA256: replacementSHA256
            ))
        }

        let generatedArchiveURL = packedDirectory.appendingPathComponent(officialArchiveURL.lastPathComponent)
        try tooling.packArchive(
            cp77toolsURL: request.cp77toolsURL,
            extractedDirectoryURL: officialDirectory,
            outputArchiveURL: generatedArchiveURL
        )
        try validateRegularFile(generatedArchiveURL, description: "Generated packed archive")
        guard !FileManager.default.fileExists(atPath: outputArchiveURL.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(outputArchiveURL.path)")
        }
        try FileManager.default.copyItem(at: generatedArchiveURL, to: outputArchiveURL)
        let outputArchiveSHA256 = try PathSafety.sha256(url: outputArchiveURL)

        return OfficialArchiveMergeStageResult(
            relativeArchivePath: relativeArchivePath,
            officialArchivePath: officialArchiveURL.path,
            modArchivePath: modArchiveURL.path,
            modFileCount: modFiles.count,
            replacements: replacements,
            unmatchedModAssetPaths: unmatchedModAssetPaths,
            outputArchivePath: outputArchiveURL.path,
            outputArchiveSHA256: outputArchiveSHA256,
            manualInstallCommand: "sudo cp \(PathSafety.shellQuoted(outputArchiveURL.path)) \(PathSafety.shellQuoted(officialArchiveURL.path))",
            statusCommand: "swift run cybermac archive-patch status \(relativeArchivePath)",
            preflightCommand: "swift run cybermac archive-patch preflight \(relativeArchivePath)"
        )
    }

    private func extractedFileMap(under rootURL: URL, description: String) throws -> [String: URL] {
        let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) root is a symlink: \(rootURL.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("\(description) root does not exist: \(rootURL.path)")
        }
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return [:]
        }

        var files: [ExtractedFile] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("\(description) contains a symlink: \(url.path)")
            }
            guard values.isRegularFile == true else { continue }

            try validateContainedPath(url, in: rootURL, description: description)
            let rawRelativePath = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            let normalizedPath = try Self.validatedExtractedAssetPath(
                rawRelativePath.replacingOccurrences(of: "\\", with: "/"),
                label: description
            )
            files.append(ExtractedFile(assetPath: normalizedPath, url: url.standardizedFileURL))
        }

        var map: [String: URL] = [:]
        for file in files.sorted(by: { $0.assetPath < $1.assetPath }) {
            guard map[file.assetPath] == nil else {
                throw CyberMacError.invalidInput("\(description) contains duplicate asset path after normalization: \(file.assetPath)")
            }
            map[file.assetPath] = file.url
        }
        return map
    }

    private func validateModArchiveURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "Mod archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Mod archive path must end in .archive: \(url.path)")
        }
        try validateRegularFile(url, description: "Mod archive")
    }

    private func validateOutputArchiveURL(_ url: URL, gameInstall: GameInstall) throws {
        try validateLocalTargetURL(url, description: "Output archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Output archive path must end in .archive: \(url.path)")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(url.path)")
        }
        try validateOutsideGameBundle(url, gameInstall: gameInstall, description: "Output archive")
        let parentURL = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parentURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CyberMacError.notFound("Output archive parent directory does not exist: \(parentURL.path)")
        }
        try validateOutsideGameBundle(parentURL, gameInstall: gameInstall, description: "Output archive parent directory")
    }

    private func validateWorkDirectoryURL(_ url: URL, gameInstall: GameInstall) throws {
        try validateLocalTargetURL(url, description: "Work directory")
        try validateOutsideGameBundle(url, gameInstall: gameInstall, description: "Work directory")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Work directory must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.invalidInput("Work directory is not a directory: \(url.path)")
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

    private func validateOutsideGameBundle(_ url: URL, gameInstall: GameInstall, description: String) throws {
        let gameRoot = gameInstall.appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = gameRoot.hasSuffix("/") ? gameRoot : gameRoot + "/"
        guard targetPath != gameRoot, !targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) must not be inside the game bundle: \(targetPath)")
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

    private func validateRegularFile(_ url: URL, description: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("\(description) does not exist: \(url.path)")
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) is a symlink, not a regular file: \(url.path)")
        }
        guard values.isRegularFile == true else {
            throw CyberMacError.invalidInput("\(description) is not a regular file: \(url.path)")
        }
    }

    private static func validatedExtractedAssetPath(_ rawPath: String, label: String) throws -> String {
        guard !rawPath.isEmpty else {
            throw CyberMacError.unsafePath("\(label) asset path is empty.")
        }
        guard !rawPath.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(label) asset path must be relative: \(rawPath)")
        }
        guard !rawPath.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(label) asset path contains control characters: \(rawPath)")
        }
        let components = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains(where: { $0.isEmpty }) else {
            throw CyberMacError.unsafePath("\(label) asset path contains an empty component: \(rawPath)")
        }
        guard !components.contains("."), !components.contains("..") else {
            throw CyberMacError.unsafePath("\(label) asset path contains traversal: \(rawPath)")
        }
        return components.joined(separator: "/")
    }
}

public enum OfficialArchiveMergeStageFormatter {
    public static func format(_ result: OfficialArchiveMergeStageResult) -> String {
        var lines: [String] = [
            "Official archive staged merge",
            "Official archive path: \(result.officialArchivePath)",
            "Relative archive path: \(result.relativeArchivePath)",
            "Mod archive path: \(result.modArchivePath)",
            "Mod files: \(result.modFileCount)",
            "Exact matches: \(result.exactMatchCount)",
            "",
            "Replaced assets:"
        ]

        for replacement in result.replacements {
            lines.append("- \(replacement.assetPath)")
            lines.append("  Original SHA-256: \(replacement.originalSHA256)")
            lines.append("  Replacement SHA-256: \(replacement.replacementSHA256)")
        }

        if !result.unmatchedModAssetPaths.isEmpty {
            lines.append("")
            lines.append("Unmatched mod files:")
            for assetPath in result.unmatchedModAssetPaths {
                lines.append("- \(assetPath)")
            }
        }

        lines.append("")
        lines.append("Output archive: \(result.outputArchivePath)")
        lines.append("Output archive SHA-256: \(result.outputArchiveSHA256)")
        lines.append("")
        lines.append("Manual install command:")
        lines.append(result.manualInstallCommand)
        lines.append("")
        lines.append("CyberMac verification commands:")
        lines.append(result.statusCommand)
        lines.append(result.preflightCommand)

        return lines.joined(separator: "\n")
    }
}
