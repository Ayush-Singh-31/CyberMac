import Foundation
import SQLite3

public struct VisualReplacementPlanRequest: Equatable, Sendable {
    public let targetArchivePath: String
    public let targetAssetPath: String
    public let replacementFileURL: URL
    public let workDirectoryURL: URL
    public let outputPlanURL: URL
    public let databaseURL: URL

    public init(
        targetArchivePath: String,
        targetAssetPath: String,
        replacementFileURL: URL,
        workDirectoryURL: URL,
        outputPlanURL: URL,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) {
        self.targetArchivePath = targetArchivePath
        self.targetAssetPath = targetAssetPath
        self.replacementFileURL = replacementFileURL
        self.workDirectoryURL = workDirectoryURL
        self.outputPlanURL = outputPlanURL
        self.databaseURL = databaseURL
    }
}

public struct VisualReplacementPlanTarget: Codable, Equatable, Sendable {
    public let archivePath: String
    public let assetPath: String
    public let assetExtension: String
    public let category: String
    public let previewCount: Int
    public let firstPreviewPath: String?

    public init(
        archivePath: String,
        assetPath: String,
        assetExtension: String,
        category: String,
        previewCount: Int,
        firstPreviewPath: String?
    ) {
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.assetExtension = assetExtension
        self.category = category
        self.previewCount = previewCount
        self.firstPreviewPath = firstPreviewPath
    }
}

public struct VisualReplacementPlanReplacement: Codable, Equatable, Sendable {
    public let filePath: String
    public let fileExtension: String
    public let sha256: String
    public let sizeBytes: UInt64

    public init(filePath: String, fileExtension: String, sha256: String, sizeBytes: UInt64) {
        self.filePath = filePath
        self.fileExtension = fileExtension
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

public struct VisualReplacementPlan: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let target: VisualReplacementPlanTarget
    public let replacement: VisualReplacementPlanReplacement
    public let workDirectoryPath: String
    public let databasePath: String

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        target: VisualReplacementPlanTarget,
        replacement: VisualReplacementPlanReplacement,
        workDirectoryPath: String,
        databasePath: String
    ) {
        self.schemaVersion = schemaVersion
        self.target = target
        self.replacement = replacement
        self.workDirectoryPath = workDirectoryPath
        self.databasePath = databasePath
    }
}

public struct VisualReplacementPlanReport: Equatable, Sendable {
    public let plan: VisualReplacementPlan
    public let planPath: String

    public init(plan: VisualReplacementPlan, planPath: String) {
        self.plan = plan
        self.planPath = planPath
    }
}

public struct VisualReplacementStageRequest: Equatable, Sendable {
    public let planURL: URL
    public let sourceArchiveURL: URL
    public let workDirectoryURL: URL
    public let outputArchiveURL: URL
    public let cp77toolsURL: URL

    public init(
        planURL: URL,
        sourceArchiveURL: URL,
        workDirectoryURL: URL,
        outputArchiveURL: URL,
        cp77toolsURL: URL
    ) {
        self.planURL = planURL
        self.sourceArchiveURL = sourceArchiveURL
        self.workDirectoryURL = workDirectoryURL
        self.outputArchiveURL = outputArchiveURL
        self.cp77toolsURL = cp77toolsURL
    }
}

public struct VisualReplacementStageResult: Equatable, Sendable {
    public let targetArchivePath: String
    public let sourceArchivePath: String
    public let targetAssetPath: String
    public let replacementFilePath: String
    public let originalAssetSHA256: String
    public let replacementSHA256: String
    public let generatedArchivePath: String
    public let outputArchivePath: String
    public let outputArchiveSHA256: String
    public let manualInstallCommand: String
    public let statusCommand: String
    public let preflightCommand: String
    public let restoreCommand: String?

    public init(
        targetArchivePath: String,
        sourceArchivePath: String,
        targetAssetPath: String,
        replacementFilePath: String,
        originalAssetSHA256: String,
        replacementSHA256: String,
        generatedArchivePath: String,
        outputArchivePath: String,
        outputArchiveSHA256: String,
        manualInstallCommand: String,
        statusCommand: String,
        preflightCommand: String,
        restoreCommand: String?
    ) {
        self.targetArchivePath = targetArchivePath
        self.sourceArchivePath = sourceArchivePath
        self.targetAssetPath = targetAssetPath
        self.replacementFilePath = replacementFilePath
        self.originalAssetSHA256 = originalAssetSHA256
        self.replacementSHA256 = replacementSHA256
        self.generatedArchivePath = generatedArchivePath
        self.outputArchivePath = outputArchivePath
        self.outputArchiveSHA256 = outputArchiveSHA256
        self.manualInstallCommand = manualInstallCommand
        self.statusCommand = statusCommand
        self.preflightCommand = preflightCommand
        self.restoreCommand = restoreCommand
    }
}

public struct VisualReplacementPlanner {
    public init() {}

    public func plan(request: VisualReplacementPlanRequest) throws -> VisualReplacementPlanReport {
        let targetArchivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(request.targetArchivePath)
        let targetAssetPath = try Self.validatedAssetPath(request.targetAssetPath, label: "Target asset")
        try Self.validateExistingRegularFile(request.databaseURL, description: "Archive catalog index database")
        try Self.validateExistingRegularFile(request.replacementFileURL, description: "Replacement file")
        try Self.validateLocalTargetURL(request.workDirectoryURL, description: "Work directory")
        try Self.validateNotInsideAppBundle(request.workDirectoryURL, description: "Work directory")
        try Self.validatePlanOutputURL(request.outputPlanURL)

        let databaseURL = request.databaseURL.standardizedFileURL
        let replacementFileURL = request.replacementFileURL.standardizedFileURL
        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        let outputPlanURL = request.outputPlanURL.standardizedFileURL

        let targetMetadata = try Self.lookupTargetMetadata(
            archivePath: targetArchivePath,
            assetPath: targetAssetPath,
            databaseURL: databaseURL
        )

        let replacementExtension = try Self.fileExtension(replacementFileURL.lastPathComponent, label: "Replacement file")
        guard targetMetadata.assetExtension == replacementExtension else {
            throw CyberMacError.invalidInput("Replacement extension must match target asset extension. Target: \(targetMetadata.assetExtension), replacement: \(replacementExtension)")
        }

        let replacement = VisualReplacementPlanReplacement(
            filePath: replacementFileURL.path,
            fileExtension: replacementExtension,
            sha256: try PathSafety.sha256(url: replacementFileURL),
            sizeBytes: try PathSafety.fileSize(url: replacementFileURL)
        )
        let plan = VisualReplacementPlan(
            target: targetMetadata,
            replacement: replacement,
            workDirectoryPath: workDirectoryURL.path,
            databasePath: databaseURL.path
        )
        let data = try JSONEncoder.cybermac.encode(plan)
        try data.write(to: outputPlanURL, options: [.atomic])
        return VisualReplacementPlanReport(plan: plan, planPath: outputPlanURL.path)
    }

    static func lookupTargetMetadata(
        archivePath: String,
        assetPath: String,
        databaseURL: URL
    ) throws -> VisualReplacementPlanTarget {
        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READONLY)
        defer { database.close() }

        let archiveExists = try database.prepare("""
            SELECT COUNT(*)
            FROM archives
            WHERE relative_archive_path = ?;
            """)
            .firstInt([.text(archivePath)]) > 0
        guard archiveExists else {
            throw CyberMacError.notFound("Target archive is not indexed: \(archivePath)")
        }

        let lookupAssetPath = ArchiveCatalogIndexStore.normalizedLookupAssetPath(assetPath)
        let statement = try database.prepare("""
            SELECT
                assets.id,
                assets.asset_path,
                assets.ext,
                assets.category,
                (SELECT COUNT(*) FROM asset_previews
                    WHERE asset_previews.asset_id = assets.id
                      AND asset_previews.status = '\(AssetPreviewStatus.available)') AS preview_count,
                (SELECT preview_path FROM asset_previews
                    WHERE asset_previews.asset_id = assets.id
                      AND asset_previews.status = '\(AssetPreviewStatus.available)'
                    ORDER BY \(AssetPreviewRegistry.preferredPreviewOrderingSQL) LIMIT 1) AS first_preview_path
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            WHERE archives.relative_archive_path = ?
              AND REPLACE(LOWER(assets.asset_path), '\\', '/') = ?
            ORDER BY assets.asset_path ASC, assets.id ASC
            LIMIT 2;
            """)
        try statement.bind([.text(archivePath), .text(lookupAssetPath)])

        var matches: [VisualReplacementPlanTarget] = []
        while try statement.step() == SQLITE_ROW {
            let indexedAssetPath = statement.columnString(1) ?? ""
            let normalizedAssetPath = try validatedAssetPath(
                indexedAssetPath.replacingOccurrences(of: "\\", with: "/"),
                label: "Indexed target asset"
            )
            matches.append(VisualReplacementPlanTarget(
                archivePath: archivePath,
                assetPath: normalizedAssetPath,
                assetExtension: (statement.columnString(2) ?? "").lowercased(),
                category: statement.columnString(3) ?? ArchiveCatalogIndexCategory.unknown.rawValue,
                previewCount: statement.columnInt(4),
                firstPreviewPath: statement.columnString(5)
            ))
        }

        guard !matches.isEmpty else {
            throw CyberMacError.notFound("Target asset is not indexed for archive \(archivePath): \(assetPath)")
        }
        guard matches.count == 1 else {
            throw CyberMacError.invalidInput("Target asset lookup is ambiguous after path normalization: \(assetPath)")
        }
        return matches[0]
    }

    static func validatedAssetPath(_ rawPath: String, label: String) throws -> String {
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
        _ = try fileExtension(normalized, label: label)
        return normalized
    }

    static func fileExtension(_ path: String, label: String) throws -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard let fileName = normalized.split(separator: "/").last,
              let dotIndex = fileName.lastIndex(of: "."),
              dotIndex != fileName.startIndex,
              dotIndex != fileName.index(before: fileName.endIndex)
        else {
            throw CyberMacError.invalidInput("\(label) path must include a file extension: \(path)")
        }
        return String(fileName[fileName.index(after: dotIndex)...]).lowercased()
    }

    static func validateLocalTargetURL(_ url: URL, description: String) throws {
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

    static func validateNotInsideAppBundle(_ url: URL, description: String) throws {
        let components = url.standardizedFileURL.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0).lowercased() }
        guard !components.contains(where: { $0.hasSuffix(".app") }) else {
            throw CyberMacError.unsafePath("\(description) must not be inside an app bundle: \(url.path)")
        }
    }

    static func validateExistingRegularFile(_ url: URL, description: String) throws {
        try validateLocalTargetURL(url, description: description)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("\(description) does not exist: \(url.path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("\(description) is a directory, not a file: \(url.path)")
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) is a symlink, not a regular file: \(url.path)")
        }
        guard values.isRegularFile == true else {
            throw CyberMacError.invalidInput("\(description) is not a regular file: \(url.path)")
        }
    }

    private static func validatePlanOutputURL(_ url: URL) throws {
        try validateLocalTargetURL(url, description: "Plan output")
        try validateNotInsideAppBundle(url, description: "Plan output")
        let parentURL = url.deletingLastPathComponent()
        let values = try parentURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Plan output parent directory must not be a symlink: \(parentURL.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("Plan output parent directory does not exist: \(parentURL.path)")
        }
        if FileManager.default.fileExists(atPath: url.path) {
            let outputValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard outputValues.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("Plan output must not be a symlink: \(url.path)")
            }
            guard outputValues.isRegularFile == true else {
                throw CyberMacError.invalidInput("Plan output is not a regular file: \(url.path)")
            }
        }
    }
}

public struct VisualReplacementStager {
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

    public func stage(request: VisualReplacementStageRequest) throws -> VisualReplacementStageResult {
        try VisualReplacementPlanner.validateExistingRegularFile(request.planURL, description: "Visual replacement plan")
        let planURL = request.planURL.standardizedFileURL
        let plan = try JSONDecoder.cybermac.decode(VisualReplacementPlan.self, from: Data(contentsOf: planURL))
        try validatePlan(plan)

        let replacementFileRawURL = URL(fileURLWithPath: plan.replacement.filePath)
        try validateSourceArchiveURL(request.sourceArchiveURL, targetArchivePath: plan.target.archivePath)
        try validateReplacementFile(replacementFileRawURL, plan: plan)
        try validateWorkDirectoryURL(request.workDirectoryURL)
        try validateOutputArchiveURL(request.outputArchiveURL, sourceArchiveURL: request.sourceArchiveURL)
        try validateCP77ToolsURL(request.cp77toolsURL)

        let sourceArchiveURL = request.sourceArchiveURL.standardizedFileURL
        let replacementFileURL = replacementFileRawURL.standardizedFileURL
        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        let outputArchiveURL = request.outputArchiveURL.standardizedFileURL
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL

        let stageRoot = workDirectoryURL.appendingPathComponent("cybermac-visual-replace-\(stageIDProvider())", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("Visual replacement stage directory already exists: \(stageRoot.path). Use a clean work directory.")
        }
        let extractedDirectory = stageRoot.appendingPathComponent("extracted", isDirectory: true)
        let packedDirectory = stageRoot.appendingPathComponent("packed", isDirectory: true)
        let requestedPackArchiveURL = packedDirectory.appendingPathComponent(sourceArchiveURL.lastPathComponent)

        try FileManager.default.createDirectory(at: extractedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packedDirectory, withIntermediateDirectories: true)

        try tooling.extractArchive(
            cp77toolsURL: cp77toolsURL,
            sourceArchiveURL: sourceArchiveURL,
            outputDirectoryURL: extractedDirectory
        )

        let targetURL = try extractedAssetURL(
            assetPath: plan.target.assetPath,
            extractedDirectory: extractedDirectory,
            label: "Target asset"
        )
        let originalAssetSHA256 = try PathSafety.sha256(url: targetURL)
        let replacementSHA256 = try PathSafety.sha256(url: replacementFileURL)

        try FileManager.default.removeItem(at: targetURL)
        try FileManager.default.copyItem(at: replacementFileURL, to: targetURL)

        try tooling.packArchive(
            cp77toolsURL: cp77toolsURL,
            extractedDirectoryURL: extractedDirectory,
            outputArchiveURL: requestedPackArchiveURL
        )
        let generatedArchiveURL = try generatedArchive(in: packedDirectory)
        guard !FileManager.default.fileExists(atPath: outputArchiveURL.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(outputArchiveURL.path)")
        }
        try FileManager.default.copyItem(at: generatedArchiveURL, to: outputArchiveURL)
        let outputArchiveSHA256 = try PathSafety.sha256(url: outputArchiveURL)

        let newestBackup = try newestBackup(relativeArchivePath: plan.target.archivePath)
        let installDestinationPath = installDestinationPath(
            relativeArchivePath: plan.target.archivePath,
            sourceArchiveURL: sourceArchiveURL,
            newestBackup: newestBackup
        )

        return VisualReplacementStageResult(
            targetArchivePath: plan.target.archivePath,
            sourceArchivePath: sourceArchiveURL.path,
            targetAssetPath: plan.target.assetPath,
            replacementFilePath: replacementFileURL.path,
            originalAssetSHA256: originalAssetSHA256,
            replacementSHA256: replacementSHA256,
            generatedArchivePath: generatedArchiveURL.path,
            outputArchivePath: outputArchiveURL.path,
            outputArchiveSHA256: outputArchiveSHA256,
            manualInstallCommand: "sudo cp \(PathSafety.shellQuoted(outputArchiveURL.path)) \(PathSafety.shellQuoted(installDestinationPath))",
            statusCommand: "swift run cybermac archive-patch status \(plan.target.archivePath)",
            preflightCommand: "swift run cybermac archive-patch preflight \(plan.target.archivePath)",
            restoreCommand: newestBackup.map { "swift run cybermac archive-patch restore-official \($0.backupID) --dry-run" }
        )
    }

    private func validatePlan(_ plan: VisualReplacementPlan) throws {
        guard plan.schemaVersion == VisualReplacementPlan.currentSchemaVersion else {
            throw CyberMacError.unsupported("Unsupported visual replacement plan schema version: \(plan.schemaVersion)")
        }
        let archivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(plan.target.archivePath)
        guard archivePath == plan.target.archivePath else {
            throw CyberMacError.invalidInput("Visual replacement plan target archive is not normalized: \(plan.target.archivePath)")
        }
        let assetPath = try VisualReplacementPlanner.validatedAssetPath(plan.target.assetPath, label: "Target asset")
        guard assetPath == plan.target.assetPath else {
            throw CyberMacError.invalidInput("Visual replacement plan target asset is not normalized: \(plan.target.assetPath)")
        }
        let targetExtension = try VisualReplacementPlanner.fileExtension(plan.target.assetPath, label: "Target asset")
        guard plan.target.assetExtension == targetExtension else {
            throw CyberMacError.invalidInput("Visual replacement plan target extension does not match target asset path.")
        }
        guard plan.replacement.fileExtension == targetExtension else {
            throw CyberMacError.invalidInput("Visual replacement plan replacement extension must match target asset extension.")
        }
        guard !plan.replacement.sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("Visual replacement plan replacement SHA-256 is empty.")
        }
        try VisualReplacementPlanner.validateLocalTargetURL(
            URL(fileURLWithPath: plan.workDirectoryPath),
            description: "Planned work directory"
        )
    }

    private func validateSourceArchiveURL(_ url: URL, targetArchivePath: String) throws {
        try VisualReplacementPlanner.validateExistingRegularFile(url, description: "Source archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Source archive path must end in .archive: \(url.path)")
        }
        let expectedFileName = String(targetArchivePath.split(separator: "/").last ?? "")
        guard url.lastPathComponent == expectedFileName else {
            throw CyberMacError.invalidInput("Source archive file name must match target archive. Expected \(expectedFileName), found \(url.lastPathComponent)")
        }
    }

    private func validateReplacementFile(_ url: URL, plan: VisualReplacementPlan) throws {
        try VisualReplacementPlanner.validateExistingRegularFile(url, description: "Replacement file")
        let extensionName = try VisualReplacementPlanner.fileExtension(url.lastPathComponent, label: "Replacement file")
        guard extensionName == plan.replacement.fileExtension,
              extensionName == plan.target.assetExtension
        else {
            throw CyberMacError.invalidInput("Replacement file extension changed after planning.")
        }
        let currentSHA256 = try PathSafety.sha256(url: url)
        let currentSize = try PathSafety.fileSize(url: url)
        guard currentSHA256 == plan.replacement.sha256, currentSize == plan.replacement.sizeBytes else {
            throw CyberMacError.invalidInput("Replacement file changed after planning: \(url.path)")
        }
    }

    private func validateWorkDirectoryURL(_ url: URL) throws {
        try VisualReplacementPlanner.validateLocalTargetURL(url, description: "Work directory")
        try VisualReplacementPlanner.validateNotInsideAppBundle(url, description: "Work directory")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Work directory must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.invalidInput("Work directory is not a directory: \(url.path)")
        }
    }

    private func validateOutputArchiveURL(_ url: URL, sourceArchiveURL: URL) throws {
        try VisualReplacementPlanner.validateLocalTargetURL(url, description: "Output archive")
        try VisualReplacementPlanner.validateNotInsideAppBundle(url, description: "Output archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Output archive path must end in .archive: \(url.path)")
        }
        guard url.standardizedFileURL.path != sourceArchiveURL.standardizedFileURL.path else {
            throw CyberMacError.unsafePath("Output archive must not overwrite the source archive: \(url.path)")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(url.path)")
        }
        let parentURL = url.deletingLastPathComponent()
        try VisualReplacementPlanner.validateNotInsideAppBundle(parentURL, description: "Output archive parent directory")
        let values = try parentURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Output archive parent directory must not be a symlink: \(parentURL.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("Output archive parent directory does not exist: \(parentURL.path)")
        }
    }

    private func validateCP77ToolsURL(_ url: URL) throws {
        try VisualReplacementPlanner.validateExistingRegularFile(url, description: "cp77tools path")
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CyberMacError.invalidInput("cp77tools path is not executable: \(url.path)")
        }
    }

    private func extractedAssetURL(assetPath: String, extractedDirectory: URL, label: String) throws -> URL {
        let validatedAssetPath = try VisualReplacementPlanner.validatedAssetPath(assetPath, label: label)
        let url = validatedAssetPath
            .split(separator: "/")
            .reduce(extractedDirectory) { partial, component in
                partial.appendingPathComponent(String(component))
            }
        try validateContainedPath(url, in: extractedDirectory, description: label)
        try VisualReplacementPlanner.validateExistingRegularFile(url, description: label)
        return url
    }

    private func generatedArchive(in packedDirectory: URL) throws -> URL {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: packedDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "archive" }
        .sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }

        guard !candidates.isEmpty else {
            throw CyberMacError.notFound("No generated .archive files were found in packed output directory: \(packedDirectory.path)")
        }
        guard candidates.count == 1 else {
            let candidateList = candidates.map { "- \($0.path)" }.joined(separator: "\n")
            throw CyberMacError.invalidInput("cp77tools generated more than one .archive in packed output directory \(packedDirectory.path):\n\(candidateList)")
        }

        let generatedArchiveURL = candidates[0].standardizedFileURL
        try VisualReplacementPlanner.validateExistingRegularFile(generatedArchiveURL, description: "Generated packed archive")
        return generatedArchiveURL
    }

    private func validateContainedPath(_ targetURL: URL, in rootURL: URL, description: String) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath == rootPath || targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) escapes expected root: \(targetPath)")
        }
    }

    private func newestBackup(relativeArchivePath: String) throws -> OfficialArchiveBackupMetadata? {
        try OfficialArchiveBackupManager(home: home)
            .list()
            .filter { $0.relativeArchivePath == relativeArchivePath }
            .sorted { lhs, rhs in
                lhs.createdAt == rhs.createdAt ? lhs.backupID > rhs.backupID : lhs.createdAt > rhs.createdAt
            }
            .first
    }

    private func installDestinationPath(
        relativeArchivePath: String,
        sourceArchiveURL: URL,
        newestBackup: OfficialArchiveBackupMetadata?
    ) -> String {
        if let newestBackup {
            return newestBackup.originalArchivePath
        }
        let sourcePath = sourceArchiveURL.standardizedFileURL.path
        let officialSuffix = "/Contents/" + relativeArchivePath
        if sourcePath.hasSuffix(officialSuffix) {
            return sourcePath
        }
        return "<Cyberpunk 2077.app>/Contents/\(relativeArchivePath)"
    }
}

public enum VisualReplacementPlanFormatter {
    public static func format(_ report: VisualReplacementPlanReport) -> String {
        let target = report.plan.target
        let replacement = report.plan.replacement
        var lines: [String] = [
            "Visual replacement plan",
            "Target archive: \(target.archivePath)",
            "Target asset: \(target.assetPath)",
            "Target extension: \(target.assetExtension)",
            "Target category: \(target.category)",
            "Target preview count: \(target.previewCount)"
        ]
        if let firstPreviewPath = target.firstPreviewPath {
            lines.append("First preview: \(firstPreviewPath)")
        } else {
            lines.append("First preview: none")
        }
        lines.append("")
        lines.append("Replacement file: \(replacement.filePath)")
        lines.append("Replacement extension: \(replacement.fileExtension)")
        lines.append("Replacement SHA-256: \(replacement.sha256)")
        lines.append("Replacement size: \(replacement.sizeBytes) bytes")
        lines.append("")
        lines.append("Plan JSON: \(report.planPath)")
        lines.append("No archive was patched or installed.")
        return lines.joined(separator: "\n")
    }
}

public enum VisualReplacementStageFormatter {
    public static func format(_ result: VisualReplacementStageResult) -> String {
        var lines: [String] = [
            "Visual replacement staged archive",
            "Target archive: \(result.targetArchivePath)",
            "Source archive: \(result.sourceArchivePath)",
            "Target asset: \(result.targetAssetPath)",
            "Replacement file: \(result.replacementFilePath)",
            "Original asset SHA-256: \(result.originalAssetSHA256)",
            "Replacement SHA-256: \(result.replacementSHA256)",
            "Generated archive: \(result.generatedArchivePath)",
            "Requested output archive: \(result.outputArchivePath)",
            "Output archive SHA-256: \(result.outputArchiveSHA256)",
            "",
            "Manual install command:",
            result.manualInstallCommand,
            "",
            "CyberMac status/preflight commands:",
            result.statusCommand,
            result.preflightCommand
        ]
        if let restoreCommand = result.restoreCommand {
            lines.append("")
            lines.append("Restore command:")
            lines.append(restoreCommand)
        }
        return lines.joined(separator: "\n")
    }
}
