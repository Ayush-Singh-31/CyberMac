import Foundation

public struct OfficialArchiveSwapStageRequest: Equatable, Sendable {
    public let relativeArchivePath: String
    public let targetAssetPath: String
    public let donorAssetPath: String
    public let workDirectoryURL: URL
    public let outputArchiveURL: URL
    public let cp77toolsURL: URL

    public init(
        relativeArchivePath: String,
        targetAssetPath: String,
        donorAssetPath: String,
        workDirectoryURL: URL,
        outputArchiveURL: URL,
        cp77toolsURL: URL
    ) {
        self.relativeArchivePath = relativeArchivePath
        self.targetAssetPath = targetAssetPath
        self.donorAssetPath = donorAssetPath
        self.workDirectoryURL = workDirectoryURL
        self.outputArchiveURL = outputArchiveURL
        self.cp77toolsURL = cp77toolsURL
    }
}

public struct OfficialArchiveSwapStageResult: Equatable, Sendable {
    public let relativeArchivePath: String
    public let sourceArchivePath: String
    public let targetAssetPath: String
    public let donorAssetPath: String
    public let targetOriginalSHA256: String
    public let donorSHA256: String
    public let outputArchivePath: String
    public let outputArchiveSHA256: String
    public let manualInstallCommand: String
    public let verificationCommand: String

    public init(
        relativeArchivePath: String,
        sourceArchivePath: String,
        targetAssetPath: String,
        donorAssetPath: String,
        targetOriginalSHA256: String,
        donorSHA256: String,
        outputArchivePath: String,
        outputArchiveSHA256: String,
        manualInstallCommand: String,
        verificationCommand: String
    ) {
        self.relativeArchivePath = relativeArchivePath
        self.sourceArchivePath = sourceArchivePath
        self.targetAssetPath = targetAssetPath
        self.donorAssetPath = donorAssetPath
        self.targetOriginalSHA256 = targetOriginalSHA256
        self.donorSHA256 = donorSHA256
        self.outputArchivePath = outputArchivePath
        self.outputArchiveSHA256 = outputArchiveSHA256
        self.manualInstallCommand = manualInstallCommand
        self.verificationCommand = verificationCommand
    }
}

public protocol OfficialArchiveSwapTooling {
    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws
    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws
}

public struct CP77ToolsArchiveSwapTooling: OfficialArchiveSwapTooling, Sendable {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        try runner.run(
            executableURL: cp77toolsURL,
            arguments: ["archive", "-e", "-p", sourceArchiveURL.path, "-o", outputDirectoryURL.path],
            timeoutSeconds: 600
        )
    }

    public func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        try FileManager.default.createDirectory(at: outputArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try runner.run(
            executableURL: cp77toolsURL,
            arguments: ["archive", "-p", extractedDirectoryURL.path, "-o", outputArchiveURL.path],
            timeoutSeconds: 600
        )
    }
}

public struct OfficialArchiveSwapStager {
    private let home: CyberMacHomeManager
    private let tooling: any OfficialArchiveSwapTooling
    private let stageIDProvider: () -> String

    public init(
        home: CyberMacHomeManager,
        tooling: any OfficialArchiveSwapTooling = CP77ToolsArchiveSwapTooling(),
        stageIDProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.home = home
        self.tooling = tooling
        self.stageIDProvider = stageIDProvider
    }

    public func stage(
        request: OfficialArchiveSwapStageRequest,
        gameInstall: GameInstall
    ) throws -> OfficialArchiveSwapStageResult {
        let relativeArchivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(request.relativeArchivePath)
        let targetAssetPath = try Self.validatedAssetPath(request.targetAssetPath, label: "Target asset")
        let donorAssetPath = try Self.validatedAssetPath(request.donorAssetPath, label: "Donor asset")
        guard targetAssetPath != donorAssetPath else {
            throw CyberMacError.invalidInput("Target asset and donor asset must be different.")
        }
        guard Self.assetExtension(targetAssetPath) == Self.assetExtension(donorAssetPath) else {
            throw CyberMacError.invalidInput("Target and donor asset extensions must match.")
        }

        let manager = OfficialArchiveBackupManager(home: home)
        let preflight = manager.preflight(relativeArchivePath: relativeArchivePath, gameInstall: gameInstall)
        switch preflight.status {
        case .pristine:
            break
        case .noBackup:
            throw CyberMacError.invalidInput("No matching CyberMac official archive backup exists. Run backup-official before staging a swap.")
        case .modified:
            throw CyberMacError.invalidInput("Current official archive is MODIFIED. Restore or verify the baseline before staging a new swap.")
        case .missing:
            throw CyberMacError.notFound("Official archive is missing from the game bundle: \(relativeArchivePath)")
        case .blocked:
            throw CyberMacError.invalidInput(preflight.reason ?? "Official archive preflight was blocked.")
        }

        guard let sourceArchivePath = preflight.destinationPath else {
            throw CyberMacError.fileSystem("Official archive preflight did not resolve a source path.")
        }
        let sourceArchiveURL = URL(fileURLWithPath: sourceArchivePath)
        let outputArchiveURL = request.outputArchiveURL.standardizedFileURL
        try validateOutputArchiveURL(outputArchiveURL, gameInstall: gameInstall)
        try validateCP77ToolsURL(request.cp77toolsURL)

        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        try validateWorkDirectoryURL(workDirectoryURL, gameInstall: gameInstall)

        let stageRoot = workDirectoryURL.appendingPathComponent("cybermac-stage-swap-\(stageIDProvider())", isDirectory: true)
        let extractedDirectory = stageRoot.appendingPathComponent("extracted", isDirectory: true)
        let packedDirectory = stageRoot.appendingPathComponent("packed", isDirectory: true)
        let generatedArchiveURL = packedDirectory.appendingPathComponent(sourceArchiveURL.lastPathComponent)

        try FileManager.default.createDirectory(at: extractedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packedDirectory, withIntermediateDirectories: true)

        try tooling.extractArchive(
            cp77toolsURL: request.cp77toolsURL,
            sourceArchiveURL: sourceArchiveURL,
            outputDirectoryURL: extractedDirectory
        )

        let targetURL = try extractedAssetURL(assetPath: targetAssetPath, extractedDirectory: extractedDirectory, label: "Target asset")
        let donorURL = try extractedAssetURL(assetPath: donorAssetPath, extractedDirectory: extractedDirectory, label: "Donor asset")
        let targetOriginalSHA256 = try PathSafety.sha256(url: targetURL)
        let donorSHA256 = try PathSafety.sha256(url: donorURL)

        try FileManager.default.removeItem(at: targetURL)
        try FileManager.default.copyItem(at: donorURL, to: targetURL)

        try tooling.packArchive(
            cp77toolsURL: request.cp77toolsURL,
            extractedDirectoryURL: extractedDirectory,
            outputArchiveURL: generatedArchiveURL
        )
        try validateRegularFile(generatedArchiveURL, description: "Generated packed archive")

        guard !FileManager.default.fileExists(atPath: outputArchiveURL.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(outputArchiveURL.path)")
        }
        try FileManager.default.copyItem(at: generatedArchiveURL, to: outputArchiveURL)
        let outputArchiveSHA256 = try PathSafety.sha256(url: outputArchiveURL)

        let manualInstallCommand = "sudo cp \(PathSafety.shellQuoted(outputArchiveURL.path)) \(PathSafety.shellQuoted(sourceArchiveURL.path))"
        let verificationCommand = "swift run cybermac archive-patch status \(relativeArchivePath)"

        return OfficialArchiveSwapStageResult(
            relativeArchivePath: relativeArchivePath,
            sourceArchivePath: sourceArchiveURL.path,
            targetAssetPath: targetAssetPath,
            donorAssetPath: donorAssetPath,
            targetOriginalSHA256: targetOriginalSHA256,
            donorSHA256: donorSHA256,
            outputArchivePath: outputArchiveURL.path,
            outputArchiveSHA256: outputArchiveSHA256,
            manualInstallCommand: manualInstallCommand,
            verificationCommand: verificationCommand
        )
    }

    private func validateOutputArchiveURL(_ url: URL, gameInstall: GameInstall) throws {
        try validateLocalTargetURL(url, description: "Output archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Output archive path must end in .archive: \(url.path)")
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

    private func extractedAssetURL(assetPath: String, extractedDirectory: URL, label: String) throws -> URL {
        let url = assetPath
            .split(separator: "/")
            .reduce(extractedDirectory) { partial, component in
                partial.appendingPathComponent(String(component))
            }
        try validateContainedPath(url, in: extractedDirectory, description: label)
        try validateRegularFile(url, description: label)
        return url
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

    private static func validatedAssetPath(_ rawPath: String, label: String) throws -> String {
        let normalized = rawPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty else {
            throw CyberMacError.unsafePath("\(label) path is empty.")
        }
        guard !normalized.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(label) path must be relative inside the archive: \(rawPath)")
        }
        guard !normalized.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(label) path contains control characters.")
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains(where: { $0.isEmpty }) else {
            throw CyberMacError.unsafePath("\(label) path contains an empty component: \(rawPath)")
        }
        guard !components.contains("."), !components.contains("..") else {
            throw CyberMacError.unsafePath("\(label) path contains traversal: \(rawPath)")
        }
        guard assetExtension(normalized) != nil else {
            throw CyberMacError.invalidInput("\(label) path must include a file extension: \(rawPath)")
        }
        return normalized
    }

    private static func assetExtension(_ assetPath: String) -> String? {
        guard let fileName = assetPath.split(separator: "/").last,
              let dotIndex = fileName.lastIndex(of: "."),
              dotIndex != fileName.startIndex,
              dotIndex != fileName.index(before: fileName.endIndex)
        else {
            return nil
        }
        return String(fileName[fileName.index(after: dotIndex)...]).lowercased()
    }
}

public enum OfficialArchiveSwapStageFormatter {
    public static func format(_ result: OfficialArchiveSwapStageResult) -> String {
        [
            "Official archive staged swap",
            "Source official archive: \(result.sourceArchivePath)",
            "Relative archive path: \(result.relativeArchivePath)",
            "Target asset: \(result.targetAssetPath)",
            "Donor asset: \(result.donorAssetPath)",
            "Target original SHA-256: \(result.targetOriginalSHA256)",
            "Donor SHA-256: \(result.donorSHA256)",
            "Output archive: \(result.outputArchivePath)",
            "Output archive SHA-256: \(result.outputArchiveSHA256)",
            "",
            "Manual install command:",
            result.manualInstallCommand,
            "",
            "Verification command:",
            result.verificationCommand
        ].joined(separator: "\n")
    }
}
