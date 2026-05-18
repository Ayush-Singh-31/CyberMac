import Foundation

public struct OfficialArchiveBackupMetadata: Codable, Equatable, Sendable {
    public let backupID: String
    public let createdAt: Date
    public let gameAppPath: String
    public let relativeArchivePath: String
    public let originalArchivePath: String
    public let originalFileName: String
    public let originalSize: UInt64
    public let originalSHA256: String
    public let codeResourcesListed: Bool
    public let backupFilePath: String

    public init(
        backupID: String,
        createdAt: Date,
        gameAppPath: String,
        relativeArchivePath: String,
        originalArchivePath: String,
        originalFileName: String,
        originalSize: UInt64,
        originalSHA256: String,
        codeResourcesListed: Bool,
        backupFilePath: String
    ) {
        self.backupID = backupID
        self.createdAt = createdAt
        self.gameAppPath = gameAppPath
        self.relativeArchivePath = relativeArchivePath
        self.originalArchivePath = originalArchivePath
        self.originalFileName = originalFileName
        self.originalSize = originalSize
        self.originalSHA256 = originalSHA256
        self.codeResourcesListed = codeResourcesListed
        self.backupFilePath = backupFilePath
    }
}

public struct OfficialArchiveRestoreVerificationResult: Equatable, Sendable {
    public let backupID: String
    public let destinationPath: String
    public let expectedSHA256: String
    public let currentSHA256: String
    public let matched: Bool

    public init(
        backupID: String,
        destinationPath: String,
        expectedSHA256: String,
        currentSHA256: String,
        matched: Bool
    ) {
        self.backupID = backupID
        self.destinationPath = destinationPath
        self.expectedSHA256 = expectedSHA256
        self.currentSHA256 = currentSHA256
        self.matched = matched
    }
}

public enum OfficialArchivePreflightStatus: String, Equatable, Sendable {
    case pristine = "PRISTINE"
    case modified = "MODIFIED"
    case missing = "MISSING"
    case noBackup = "NO_BACKUP"
    case blocked = "BLOCKED"
}

public enum OfficialArchivePatchStatus: String, Equatable, Sendable {
    case pristine = "PRISTINE"
    case modified = "MODIFIED"
    case unknownBackup = "UNKNOWN_BACKUP"
    case missing = "MISSING"
}

public struct OfficialArchivePreflightResult: Equatable, Sendable {
    public let status: OfficialArchivePreflightStatus
    public let reason: String?
    public let relativeArchivePath: String
    public let gameAppPath: String?
    public let destinationPath: String?
    public let codeResourcesListed: Bool
    public let currentSize: UInt64?
    public let currentSHA256: String?
    public let newestBackupID: String?
    public let expectedOriginalSize: UInt64?
    public let expectedOriginalSHA256: String?
    public let manualRestoreCommand: String?
    public let suggestedBackupCommand: String?

    public init(
        status: OfficialArchivePreflightStatus,
        reason: String? = nil,
        relativeArchivePath: String,
        gameAppPath: String?,
        destinationPath: String?,
        codeResourcesListed: Bool,
        currentSize: UInt64? = nil,
        currentSHA256: String? = nil,
        newestBackupID: String? = nil,
        expectedOriginalSize: UInt64? = nil,
        expectedOriginalSHA256: String? = nil,
        manualRestoreCommand: String? = nil,
        suggestedBackupCommand: String? = nil
    ) {
        self.status = status
        self.reason = reason
        self.relativeArchivePath = relativeArchivePath
        self.gameAppPath = gameAppPath
        self.destinationPath = destinationPath
        self.codeResourcesListed = codeResourcesListed
        self.currentSize = currentSize
        self.currentSHA256 = currentSHA256
        self.newestBackupID = newestBackupID
        self.expectedOriginalSize = expectedOriginalSize
        self.expectedOriginalSHA256 = expectedOriginalSHA256
        self.manualRestoreCommand = manualRestoreCommand
        self.suggestedBackupCommand = suggestedBackupCommand
    }
}

public enum OfficialArchivePreflightFormatter {
    public static func format(_ result: OfficialArchivePreflightResult) -> String {
        var lines: [String] = [
            "Official archive preflight",
            "Status: \(result.status.rawValue)"
        ]
        if let reason = result.reason {
            lines.append("Reason: \(reason)")
        }
        lines.append("Relative path: \(result.relativeArchivePath)")
        lines.append("Game app: \(result.gameAppPath ?? "unresolved")")
        lines.append("Destination: \(result.destinationPath ?? "unresolved")")
        lines.append("CodeResources listed: \(result.codeResourcesListed ? "yes" : "no")")
        if let currentSize = result.currentSize {
            lines.append("Current size: \(currentSize) bytes")
        }
        if let currentSHA256 = result.currentSHA256 {
            lines.append("Current SHA-256: \(currentSHA256)")
        }
        lines.append("Newest backup: \(result.newestBackupID ?? "none")")
        if let expectedOriginalSize = result.expectedOriginalSize {
            lines.append("Expected size: \(expectedOriginalSize) bytes")
        }
        if let expectedOriginalSHA256 = result.expectedOriginalSHA256 {
            lines.append("Expected SHA-256: \(expectedOriginalSHA256)")
        }
        if let manualRestoreCommand = result.manualRestoreCommand {
            lines.append("")
            lines.append("Manual restore command:")
            lines.append(manualRestoreCommand)
        }
        if let suggestedBackupCommand = result.suggestedBackupCommand {
            lines.append("")
            lines.append("Suggested backup command:")
            lines.append(suggestedBackupCommand)
        }
        return lines.joined(separator: "\n")
    }
}

public enum OfficialArchiveManualPlanFormatter {
    public static func format(_ result: OfficialArchivePreflightResult) -> String {
        var lines: [String] = [
            "Official archive manual patch plan",
            "Status: \(result.status.rawValue)",
            "Relative path: \(result.relativeArchivePath)"
        ]
        lines.append("Destination: \(result.destinationPath ?? "unresolved")")
        if let currentSHA256 = result.currentSHA256 {
            lines.append("Current SHA-256: \(currentSHA256)")
        }
        if let backupID = result.newestBackupID {
            lines.append("Backup ID: \(backupID)")
        }
        if let backupSHA256 = result.expectedOriginalSHA256 {
            lines.append("Backup SHA-256: \(backupSHA256)")
        }

        switch result.status {
        case .pristine:
            appendPristinePlan(to: &lines, result: result)
        case .noBackup:
            appendNoBackupPlan(to: &lines, result: result)
        case .modified:
            appendModifiedPlan(to: &lines, result: result)
        case .missing:
            appendMissingPlan(to: &lines, result: result)
        case .blocked:
            appendBlockedPlan(to: &lines, result: result)
        }

        return lines.joined(separator: "\n")
    }

    private static func appendPristinePlan(to lines: inout [String], result: OfficialArchivePreflightResult) {
        lines.append("")
        lines.append("Archive is safe to use as a baseline.")
        lines.append("")
        lines.append("Manual experiment checklist:")
        lines.append("1. Run preflight and confirm PRISTINE:")
        lines.append("   \(preflightCommand(relativePath: result.relativeArchivePath))")
        lines.append("2. Export the archive externally with WolvenKit CLI or another trusted Cyberpunk archive tool.")
        lines.append("3. Make one tiny visible UI/menu change only.")
        lines.append("4. Repack the archive externally.")
        lines.append("5. Run preflight again before copying.")
        lines.append("6. Manually copy the repacked archive into the official path with sudo cp.")
        lines.append("7. Run preflight again and expect MODIFIED:")
        lines.append("   \(preflightCommand(relativePath: result.relativeArchivePath))")
        lines.append("8. Launch the game and check launch success plus visible change.")
        lines.append("9. Record the result manually.")
        lines.append("10. Restore the original archive using CyberMac restore dry-run output:")
        lines.append("    \(restoreCommand(backupID: result.newestBackupID, mode: "--dry-run"))")
        lines.append("11. Run restore --verify:")
        lines.append("    \(restoreCommand(backupID: result.newestBackupID, mode: "--verify"))")
        lines.append("12. Run preflight again and expect PRISTINE:")
        lines.append("    \(preflightCommand(relativePath: result.relativeArchivePath))")
        appendWarnings(to: &lines)
    }

    private static func appendNoBackupPlan(to lines: inout [String], result: OfficialArchivePreflightResult) {
        lines.append("")
        lines.append("Do not patch yet.")
        lines.append("No matching CyberMac official backup exists.")
        lines.append("")
        lines.append("Suggested backup command:")
        lines.append(result.suggestedBackupCommand ?? backupCommand(relativePath: result.relativeArchivePath))
        lines.append("")
        lines.append("Suggested preflight command after backup:")
        lines.append(preflightCommand(relativePath: result.relativeArchivePath))
    }

    private static func appendModifiedPlan(to lines: inout [String], result: OfficialArchivePreflightResult) {
        lines.append("")
        lines.append("Do not begin a new experiment.")
        lines.append("Current archive differs from the newest CyberMac official backup.")
        appendRestoreRecovery(to: &lines, result: result)
    }

    private static func appendMissingPlan(to lines: inout [String], result: OfficialArchivePreflightResult) {
        lines.append("")
        lines.append("Do not launch or patch.")
        lines.append("Official archive is missing.")
        appendRestoreRecovery(to: &lines, result: result)
    }

    private static func appendBlockedPlan(to lines: inout [String], result: OfficialArchivePreflightResult) {
        lines.append("")
        lines.append("Validation failed.")
        lines.append("Reason: \(result.reason ?? "unknown")")
        lines.append("No experiment plan printed.")
    }

    private static func appendRestoreRecovery(to lines: inout [String], result: OfficialArchivePreflightResult) {
        if let manualRestoreCommand = result.manualRestoreCommand {
            lines.append("")
            lines.append("Manual restore command:")
            lines.append(manualRestoreCommand)
        } else {
            lines.append("")
            lines.append("Manual restore command: unavailable")
        }

        lines.append("")
        lines.append("After manual restore:")
        lines.append(restoreCommand(backupID: result.newestBackupID, mode: "--verify"))
        lines.append(preflightCommand(relativePath: result.relativeArchivePath))
    }

    private static func appendWarnings(to lines: inout [String]) {
        lines.append("")
        lines.append("Warnings:")
        lines.append("- Do not test clothing yet.")
        lines.append("- Do not test large gameplay archives yet.")
        lines.append("- Do not patch basegame_4_appearance.archive or gamedata archives yet.")
        lines.append("- Keep this first experiment limited to basegame_2_mainmenu.archive.")
        lines.append("- CyberMac should not automate WolvenKit or sudo copy operations.")
    }

    private static func backupCommand(relativePath: String) -> String {
        "swift run cybermac archive-patch backup-official \(relativePath)"
    }

    private static func preflightCommand(relativePath: String) -> String {
        "swift run cybermac archive-patch preflight \(relativePath)"
    }

    private static func restoreCommand(backupID: String?, mode: String) -> String {
        guard let backupID else {
            return "swift run cybermac archive-patch restore-official <backup-id> \(mode)"
        }
        return "swift run cybermac archive-patch restore-official \(backupID) \(mode)"
    }
}

public struct OfficialArchiveBackupManager: Sendable {
    private static let metadataFileName = "metadata.json"

    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func backup(relativeArchivePath rawRelativeArchivePath: String, gameInstall: GameInstall) throws -> OfficialArchiveBackupMetadata {
        let relativeArchivePath = try Self.validatedOfficialRelativeArchivePath(rawRelativeArchivePath)
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        let sourceURL = appending(relativePath: relativeArchivePath, to: contentsURL)

        try validateResolvedContainedPath(sourceURL, in: contentsURL, description: "Official archive source")
        try validateRegularFile(sourceURL, description: "Official archive source")
        try validateAllowedOfficialArchiveLocation(sourceURL, contentsURL: contentsURL, relativeArchivePath: relativeArchivePath)

        let codeResourcesListed = try codeResourcesLists(relativeArchivePath: relativeArchivePath, contentsURL: contentsURL)
        guard codeResourcesListed else {
            throw CyberMacError.unsupported("Official archive is not listed in _CodeSignature/CodeResources: \(relativeArchivePath)")
        }

        try home.bootstrap()

        let createdAt = Date()
        let originalSHA256 = try PathSafety.sha256(url: sourceURL)
        let originalSize = try PathSafety.fileSize(url: sourceURL)
        let backupID = try uniqueBackupID(createdAt: createdAt, sha256: originalSHA256)
        let directory = backupDirectory(backupID: backupID)
        let backupFileURL = directory.appendingPathComponent(sourceURL.lastPathComponent)
        try validateResolvedContainedPath(backupFileURL, in: home.officialArchiveBackupsURL, description: "Official archive backup file")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceURL, to: backupFileURL)

            let metadata = OfficialArchiveBackupMetadata(
                backupID: backupID,
                createdAt: createdAt,
                gameAppPath: gameInstall.appURL.path,
                relativeArchivePath: relativeArchivePath,
                originalArchivePath: sourceURL.path,
                originalFileName: sourceURL.lastPathComponent,
                originalSize: originalSize,
                originalSHA256: originalSHA256,
                codeResourcesListed: codeResourcesListed,
                backupFilePath: backupFileURL.path
            )
            try save(metadata)
            return metadata
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    public func list() throws -> [OfficialArchiveBackupMetadata] {
        guard FileManager.default.fileExists(atPath: home.officialArchiveBackupsURL.path) else { return [] }
        let directories = try FileManager.default.contentsOfDirectory(
            at: home.officialArchiveBackupsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try directories.compactMap { directory in
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            let metadataURL = directory.appendingPathComponent(Self.metadataFileName)
            guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
            return try JSONDecoder.cybermac.decode(OfficialArchiveBackupMetadata.self, from: Data(contentsOf: metadataURL))
        }
        .sorted { lhs, rhs in
            lhs.createdAt == rhs.createdAt ? lhs.backupID > rhs.backupID : lhs.createdAt > rhs.createdAt
        }
    }

    public func load(backupID: String) throws -> OfficialArchiveBackupMetadata {
        let url = backupDirectory(backupID: backupID).appendingPathComponent(Self.metadataFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Official archive backup not found: \(backupID)")
        }
        let metadata = try JSONDecoder.cybermac.decode(OfficialArchiveBackupMetadata.self, from: Data(contentsOf: url))
        guard metadata.backupID == backupID else {
            throw CyberMacError.fileSystem("Official archive backup metadata id mismatch. Expected \(backupID), found \(metadata.backupID).")
        }
        return metadata
    }

    public func backupFileURL(backupID: String) throws -> URL {
        let metadata = try load(backupID: backupID)
        let relativeArchivePath = try Self.validatedOfficialRelativeArchivePath(metadata.relativeArchivePath)
        try validateMetadata(metadata, relativeArchivePath: relativeArchivePath)
        return try validatedBackupFileURL(from: metadata)
    }

    public func restoreDryRunCommand(backupID: String, preferredGameAppPath: String? = nil) throws -> String {
        let context = try validatedRestoreContext(backupID: backupID, preferredGameAppPath: preferredGameAppPath)
        return "sudo cp \(PathSafety.shellQuoted(context.backupFileURL.path)) \(PathSafety.shellQuoted(context.destinationURL.path))"
    }

    public func verifyRestore(backupID: String, preferredGameAppPath: String? = nil) throws -> OfficialArchiveRestoreVerificationResult {
        let context = try validatedRestoreContext(backupID: backupID, preferredGameAppPath: preferredGameAppPath)
        try validateRegularFile(context.destinationURL, description: "Official archive destination")
        let currentSHA256 = try PathSafety.sha256(url: context.destinationURL)
        return OfficialArchiveRestoreVerificationResult(
            backupID: context.metadata.backupID,
            destinationPath: context.destinationURL.path,
            expectedSHA256: context.metadata.originalSHA256,
            currentSHA256: currentSHA256,
            matched: currentSHA256 == context.metadata.originalSHA256
        )
    }

    public func preflight(
        relativeArchivePath rawRelativeArchivePath: String,
        preferredGameAppPath: String? = nil
    ) -> OfficialArchivePreflightResult {
        do {
            let gameInstall = try GameInstallDetector().detect(preferredAppPath: preferredGameAppPath)
            return preflight(relativeArchivePath: rawRelativeArchivePath, gameInstall: gameInstall)
        } catch {
            let trimmedGameAppPath = preferredGameAppPath?.trimmingCharacters(in: .whitespacesAndNewlines)
            return OfficialArchivePreflightResult(
                status: .blocked,
                reason: String(describing: error),
                relativeArchivePath: rawRelativeArchivePath,
                gameAppPath: trimmedGameAppPath?.isEmpty == false ? preferredGameAppPath : nil,
                destinationPath: nil,
                codeResourcesListed: false
            )
        }
    }

    public func preflight(
        relativeArchivePath rawRelativeArchivePath: String,
        gameInstall: GameInstall
    ) -> OfficialArchivePreflightResult {
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        var relativeArchivePath = rawRelativeArchivePath
        var destinationPath: String?
        var codeResourcesListed = false
        var currentSize: UInt64?
        var currentSHA256: String?
        var newestBackup: OfficialArchiveBackupMetadata?

        func makeResult(
            status: OfficialArchivePreflightStatus,
            reason: String? = nil,
            manualRestoreCommand: String? = nil,
            suggestedBackupCommand: String? = nil
        ) -> OfficialArchivePreflightResult {
            OfficialArchivePreflightResult(
                status: status,
                reason: reason,
                relativeArchivePath: relativeArchivePath,
                gameAppPath: gameInstall.appURL.path,
                destinationPath: destinationPath,
                codeResourcesListed: codeResourcesListed,
                currentSize: currentSize,
                currentSHA256: currentSHA256,
                newestBackupID: newestBackup?.backupID,
                expectedOriginalSize: newestBackup?.originalSize,
                expectedOriginalSHA256: newestBackup?.originalSHA256,
                manualRestoreCommand: manualRestoreCommand,
                suggestedBackupCommand: suggestedBackupCommand
            )
        }

        do {
            relativeArchivePath = try Self.validatedOfficialRelativeArchivePath(rawRelativeArchivePath)
            let destinationURL = appending(relativePath: relativeArchivePath, to: contentsURL)
            destinationPath = destinationURL.path

            try validateResolvedContainedPath(destinationURL, in: contentsURL, description: "Official archive destination")
            try validateAllowedOfficialArchiveLocation(destinationURL, contentsURL: contentsURL, relativeArchivePath: relativeArchivePath)

            codeResourcesListed = try codeResourcesLists(relativeArchivePath: relativeArchivePath, contentsURL: contentsURL)
            guard codeResourcesListed else {
                return makeResult(
                    status: .blocked,
                    reason: CyberMacError.unsupported("Official archive destination is not listed in _CodeSignature/CodeResources: \(relativeArchivePath)").description
                )
            }

            let archiveExists = FileManager.default.fileExists(atPath: destinationURL.path)
            if archiveExists {
                try validateRegularFile(destinationURL, description: "Official archive destination")
                currentSize = try PathSafety.fileSize(url: destinationURL)
                currentSHA256 = try PathSafety.sha256(url: destinationURL)
            }

            newestBackup = try list()
                .filter { $0.relativeArchivePath == relativeArchivePath }
                .sorted { lhs, rhs in
                    lhs.createdAt == rhs.createdAt ? lhs.backupID > rhs.backupID : lhs.createdAt > rhs.createdAt
                }
                .first

            guard let newestBackup else {
                if archiveExists {
                    return makeResult(
                        status: .noBackup,
                        suggestedBackupCommand: "swift run cybermac archive-patch backup-official \(relativeArchivePath)"
                    )
                }
                return makeResult(status: .missing)
            }

            try validateMetadata(newestBackup, relativeArchivePath: relativeArchivePath)
            let backupFileURL = try validatedBackupFileURL(from: newestBackup)
            let manualRestoreCommand = "sudo cp \(PathSafety.shellQuoted(backupFileURL.path)) \(PathSafety.shellQuoted(destinationURL.path))"

            guard archiveExists else {
                return makeResult(status: .missing, manualRestoreCommand: manualRestoreCommand)
            }

            if currentSHA256 == newestBackup.originalSHA256 {
                return makeResult(status: .pristine)
            }
            return makeResult(status: .modified, manualRestoreCommand: manualRestoreCommand)
        } catch {
            return makeResult(status: .blocked, reason: String(describing: error))
        }
    }

    public func status(
        relativeArchivePath rawRelativeArchivePath: String,
        preferredGameAppPath: String? = nil
    ) throws -> OfficialArchivePatchStatus {
        let gameInstall = try GameInstallDetector().detect(preferredAppPath: preferredGameAppPath)
        return try status(relativeArchivePath: rawRelativeArchivePath, gameInstall: gameInstall)
    }

    public func status(
        relativeArchivePath rawRelativeArchivePath: String,
        gameInstall: GameInstall
    ) throws -> OfficialArchivePatchStatus {
        let result = preflight(relativeArchivePath: rawRelativeArchivePath, gameInstall: gameInstall)
        switch result.status {
        case .pristine:
            return .pristine
        case .modified:
            return .modified
        case .missing:
            return .missing
        case .noBackup:
            return .unknownBackup
        case .blocked:
            throw CyberMacError.invalidInput(result.reason ?? "Official archive status check was blocked.")
        }
    }

    public static func validateOfficialRelativeArchivePath(_ rawPath: String) throws -> String {
        try validatedOfficialRelativeArchivePath(rawPath)
    }

    public func backupDirectory(backupID: String) -> URL {
        home.officialArchiveBackupsURL.appendingPathComponent(backupID, isDirectory: true)
    }

    private struct RestoreContext {
        let metadata: OfficialArchiveBackupMetadata
        let backupFileURL: URL
        let destinationURL: URL
    }

    private func validatedRestoreContext(backupID: String, preferredGameAppPath: String?) throws -> RestoreContext {
        let metadata = try load(backupID: backupID)
        let relativeArchivePath = try Self.validatedOfficialRelativeArchivePath(metadata.relativeArchivePath)
        try validateMetadata(metadata, relativeArchivePath: relativeArchivePath)

        let backupFileURL = try validatedBackupFileURL(from: metadata)
        let gameAppPath = preferredGameAppPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? preferredGameAppPath
            : metadata.gameAppPath
        guard let gameAppPath, !gameAppPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("Official archive backup metadata does not contain a game app path.")
        }

        let gameInstall = try GameInstallDetector().detect(preferredAppPath: gameAppPath)
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        let destinationURL = appending(relativePath: relativeArchivePath, to: contentsURL)
        try validateResolvedContainedPath(destinationURL, in: contentsURL, description: "Official archive destination")
        try validateAllowedOfficialArchiveLocation(destinationURL, contentsURL: contentsURL, relativeArchivePath: relativeArchivePath)

        guard try codeResourcesLists(relativeArchivePath: relativeArchivePath, contentsURL: contentsURL) else {
            throw CyberMacError.unsupported("Official archive destination is not listed in _CodeSignature/CodeResources: \(relativeArchivePath)")
        }

        return RestoreContext(metadata: metadata, backupFileURL: backupFileURL, destinationURL: destinationURL)
    }

    private static func validatedOfficialRelativeArchivePath(_ rawPath: String) throws -> String {
        guard !rawPath.isEmpty else {
            throw CyberMacError.unsafePath("Official archive path is empty.")
        }
        guard !rawPath.hasPrefix("/") else {
            throw CyberMacError.unsafePath("Official archive path must be relative to Contents, not absolute: \(rawPath)")
        }
        guard !rawPath.contains("\\") else {
            throw CyberMacError.unsafePath("Official archive path must use forward slashes: \(rawPath)")
        }
        guard !rawPath.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("Official archive path contains control characters.")
        }

        let components = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 5, !components.contains(where: { $0.isEmpty }) else {
            throw CyberMacError.unsafePath("Official archive path must be Data/archive/Mac/content/*.archive or Data/archive/Mac/ep1/*.archive: \(rawPath)")
        }
        guard !components.contains(".."), !components.contains(".") else {
            throw CyberMacError.unsafePath("Official archive path contains traversal: \(rawPath)")
        }
        guard Array(components.prefix(3)) == ["Data", "archive", "Mac"],
              ["content", "ep1"].contains(components[3])
        else {
            throw CyberMacError.unsafePath("Official archive path is outside supported Mac official archive directories: \(rawPath)")
        }

        let fileName = components[4]
        guard fileName.lowercased().hasSuffix(".archive") else {
            throw CyberMacError.unsafePath("Official archive path must end in .archive: \(rawPath)")
        }
        guard URL(fileURLWithPath: fileName).lastPathComponent == fileName,
              fileName != ".",
              fileName != ".."
        else {
            throw CyberMacError.unsafePath("Official archive file name is invalid: \(fileName)")
        }

        return components.joined(separator: "/")
    }

    private func validateMetadata(_ metadata: OfficialArchiveBackupMetadata, relativeArchivePath: String) throws {
        guard !metadata.originalSHA256.isEmpty else {
            throw CyberMacError.fileSystem("Official archive backup metadata has an empty original SHA-256.")
        }
        guard metadata.codeResourcesListed else {
            throw CyberMacError.fileSystem("Official archive backup metadata does not record CodeResources membership.")
        }
        let expectedFileName = URL(fileURLWithPath: relativeArchivePath).lastPathComponent
        guard metadata.originalFileName == expectedFileName else {
            throw CyberMacError.fileSystem("Official archive backup metadata file name mismatch. Expected \(expectedFileName), found \(metadata.originalFileName).")
        }
    }

    private func validatedBackupFileURL(from metadata: OfficialArchiveBackupMetadata) throws -> URL {
        try validateAbsolutePersistedPath(metadata.backupFilePath, description: "Official archive backup file path")
        let backupFileURL = URL(fileURLWithPath: metadata.backupFilePath)
        try validateResolvedContainedPath(backupFileURL, in: home.officialArchiveBackupsURL, description: "Official archive backup file")
        try validateRegularFile(backupFileURL, description: "Official archive backup file")
        return backupFileURL
    }

    private func validateAbsolutePersistedPath(_ path: String, description: String) throws {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.unsafePath("\(description) is empty.")
        }
        guard path.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(description) must be absolute: \(path)")
        }
        guard !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(description) contains control characters.")
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.contains("..") else {
            throw CyberMacError.unsafePath("\(description) contains traversal: \(path)")
        }
    }

    private func validateAllowedOfficialArchiveLocation(_ url: URL, contentsURL: URL, relativeArchivePath: String) throws {
        let components = relativeArchivePath.split(separator: "/").map(String.init)
        let allowedDirectory = components[3]
        let allowedRoot = contentsURL
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("archive", isDirectory: true)
            .appendingPathComponent("Mac", isDirectory: true)
            .appendingPathComponent(allowedDirectory, isDirectory: true)
        try validateResolvedContainedPath(url, in: allowedRoot, description: "Official archive path")
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

    private func codeResourcesLists(relativeArchivePath: String, contentsURL: URL) throws -> Bool {
        let codeResourcesURL = contentsURL
            .appendingPathComponent("_CodeSignature", isDirectory: true)
            .appendingPathComponent("CodeResources")
        guard FileManager.default.fileExists(atPath: codeResourcesURL.path) else {
            throw CyberMacError.notFound("CodeResources file missing: \(codeResourcesURL.path)")
        }

        let data = try Data(contentsOf: codeResourcesURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw CyberMacError.invalidInput("CodeResources is not a property-list dictionary: \(codeResourcesURL.path)")
        }

        for key in ["files", "files2"] {
            guard let files = dictionary[key] as? [String: Any] else { continue }
            if files.keys.contains(relativeArchivePath) {
                return true
            }
        }
        return false
    }

    private func validateResolvedContainedPath(_ targetURL: URL, in rootURL: URL, description: String) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath == rootPath || targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) escapes expected root: \(targetPath)")
        }
    }

    private func appending(relativePath: String, to rootURL: URL) -> URL {
        relativePath.split(separator: "/").reduce(rootURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }

    private func save(_ metadata: OfficialArchiveBackupMetadata) throws {
        let directory = backupDirectory(backupID: metadata.backupID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.cybermac.encode(metadata)
        try data.write(to: directory.appendingPathComponent(Self.metadataFileName), options: [.atomic])
    }

    private func uniqueBackupID(createdAt: Date, sha256: String) throws -> String {
        let base = Self.makeBackupID(date: createdAt, sha256: sha256)
        if !FileManager.default.fileExists(atPath: backupDirectory(backupID: base).path) {
            return base
        }
        return "\(base)-\(UUID().uuidString.prefix(8))"
    }

    private static func makeBackupID(date: Date = Date(), sha256: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return "official-archive-\(formatter.string(from: date))-\(sha256.prefix(12))"
    }
}
