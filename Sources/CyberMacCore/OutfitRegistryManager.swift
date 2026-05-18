import Foundation

public struct OutfitProfileCreateRequest: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let targetArchiveRelativePath: String
    public let backupID: String

    public init(id: String, displayName: String, targetArchiveRelativePath: String, backupID: String) {
        self.id = id
        self.displayName = displayName
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.backupID = backupID
    }
}

public struct OutfitPieceAddRequest: Equatable, Sendable {
    public let profileID: String
    public let pieceID: String
    public let displayName: String
    public let sourceArchiveURLs: [URL]
    public let itemIDs: [String]
    public let tags: [String]
    public let cp77toolsURL: URL
    public let workDirectoryURL: URL?
    public let databaseURL: URL

    public init(
        profileID: String,
        pieceID: String,
        displayName: String,
        sourceArchiveURLs: [URL],
        itemIDs: [String] = [],
        tags: [String] = [],
        cp77toolsURL: URL,
        workDirectoryURL: URL? = nil,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) {
        self.profileID = profileID
        self.pieceID = pieceID
        self.displayName = displayName
        self.sourceArchiveURLs = sourceArchiveURLs
        self.itemIDs = itemIDs
        self.tags = tags
        self.cp77toolsURL = cp77toolsURL
        self.workDirectoryURL = workDirectoryURL
        self.databaseURL = databaseURL
    }
}

public struct OutfitProfileBuildRequest: Equatable, Sendable {
    public let profileID: String
    public let outputArchiveURL: URL
    public let workDirectoryURL: URL
    public let cp77toolsURL: URL

    public init(profileID: String, outputArchiveURL: URL, workDirectoryURL: URL, cp77toolsURL: URL) {
        self.profileID = profileID
        self.outputArchiveURL = outputArchiveURL
        self.workDirectoryURL = workDirectoryURL
        self.cp77toolsURL = cp77toolsURL
    }
}

public struct OutfitGrantItemsRequest: Equatable, Sendable {
    public let profileID: String
    public let outputZipURL: URL
    public let modName: String?

    public init(profileID: String, outputZipURL: URL, modName: String?) {
        self.profileID = profileID
        self.outputZipURL = outputZipURL
        self.modName = modName
    }
}

public struct OutfitProfileSummary: Equatable, Sendable {
    public let profile: OutfitProfile
    public let enabledPieces: [OutfitPiece]
    public let disabledPieces: [OutfitPiece]
    public let conflictWarnings: [OutfitBuildConflict]

    public init(
        profile: OutfitProfile,
        enabledPieces: [OutfitPiece],
        disabledPieces: [OutfitPiece],
        conflictWarnings: [OutfitBuildConflict]
    ) {
        self.profile = profile
        self.enabledPieces = enabledPieces
        self.disabledPieces = disabledPieces
        self.conflictWarnings = conflictWarnings
    }
}

public struct OutfitRegistryManager: Sendable {
    private struct ExtractedFile: Equatable {
        let assetPath: String
        let url: URL
    }

    private let home: CyberMacHomeManager
    private let backupManager: OfficialArchiveBackupManager
    private let tooling: any OfficialArchiveSwapTooling
    private let dateProvider: @Sendable () -> Date
    private let idProvider: @Sendable () -> String

    public init(
        home: CyberMacHomeManager,
        tooling: any OfficialArchiveSwapTooling = CP77ToolsArchiveSwapTooling(),
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        idProvider: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.home = home
        self.backupManager = OfficialArchiveBackupManager(home: home)
        self.tooling = tooling
        self.dateProvider = dateProvider
        self.idProvider = idProvider
    }

    public func createProfile(request: OutfitProfileCreateRequest) throws -> OutfitProfile {
        try home.bootstrap()
        let id = try Self.validatedID(request.id, label: "Profile id")
        let displayName = try Self.validatedDisplayName(request.displayName, label: "--name")
        let targetArchive = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(request.targetArchiveRelativePath)
        let backupID = try Self.validatedID(request.backupID, label: "Backup id")

        guard !FileManager.default.fileExists(atPath: profileURL(id: id).path) else {
            throw CyberMacError.invalidInput("Outfit profile already exists: \(id)")
        }

        let backup = try backupManager.load(backupID: backupID)
        guard backup.relativeArchivePath == targetArchive else {
            throw CyberMacError.invalidInput("Backup \(backupID) belongs to \(backup.relativeArchivePath), not \(targetArchive)")
        }
        let pristineArchiveURL = try backupManager.backupFileURL(backupID: backupID)

        let now = dateProvider()
        let profile = OutfitProfile(
            id: id,
            displayName: displayName,
            targetArchiveRelativePath: targetArchive,
            pristineBackupId: backupID,
            pristineArchivePath: pristineArchiveURL.path,
            createdAt: now,
            updatedAt: now
        )

        try save(profile)
        try upsertRegistryEntry(for: profile)
        return profile
    }

    public func loadProfile(id rawID: String) throws -> OutfitProfile {
        try home.bootstrap()
        let id = try Self.validatedID(rawID, label: "Profile id")
        let url = profileURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Outfit profile not found: \(id)")
        }
        do {
            var profile = try JSONDecoder.cybermac.decode(OutfitProfile.self, from: Data(contentsOf: url))
            try validateLoadedProfile(profile)
            normalize(profile: &profile)
            return profile
        } catch let error as CyberMacError {
            throw error
        } catch {
            throw CyberMacError.invalidInput("Outfit profile JSON could not be decoded: \(url.path): \(error.localizedDescription)")
        }
    }

    public func listProfiles() throws -> [OutfitProfile] {
        try home.bootstrap()
        let registry = try loadRegistry()
        var profiles: [OutfitProfile] = []
        for entry in registry.profiles {
            if let profile = try? loadProfile(id: entry.id) {
                profiles.append(profile)
            }
        }
        return profiles.sorted { lhs, rhs in
            lhs.updatedAt == rhs.updatedAt ? lhs.id < rhs.id : lhs.updatedAt > rhs.updatedAt
        }
    }

    public func showProfile(id: String) throws -> OutfitProfileSummary {
        let profile = try loadProfile(id: id)
        return summary(for: profile)
    }

    public func addPiece(request: OutfitPieceAddRequest) throws -> OutfitPiece {
        try home.bootstrap()
        var profile = try loadProfile(id: request.profileID)
        let pieceID = try Self.validatedID(request.pieceID, label: "Piece id")
        let displayName = try Self.validatedDisplayName(request.displayName, label: "--name")
        guard profile.pieces.first(where: { $0.id == pieceID }) == nil else {
            throw CyberMacError.invalidInput("Outfit piece already exists in profile \(profile.id): \(pieceID)")
        }
        guard !request.sourceArchiveURLs.isEmpty else {
            throw CyberMacError.invalidInput("At least one --source-archive <path> is required")
        }

        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try Self.validateCP77ToolsURL(cp77toolsURL)
        let databaseURL = request.databaseURL.standardizedFileURL
        try Self.validateExistingRegularFile(databaseURL, description: "Archive catalog index database")

        let sourceArchiveURLs = try request.sourceArchiveURLs.map { try Self.validatedSourceArchiveURL($0.standardizedFileURL) }
        guard Set(sourceArchiveURLs.map(\.path)).count == sourceArchiveURLs.count else {
            throw CyberMacError.invalidInput("Duplicate --source-archive paths are not allowed")
        }
        let sourceArchivePaths = sourceArchiveURLs.map(\.path)
        let sourceArchiveSHA256 = try Dictionary(uniqueKeysWithValues: sourceArchiveURLs.map { ($0.path, try PathSafety.sha256(url: $0)) })
        let normalizedItemIDs = try Self.normalizeItemIDs(request.itemIDs, allowEmpty: true)
        let tags = try Self.normalizeTags(request.tags)

        let workRoot = try pieceAddWorkRoot(request.workDirectoryURL)
        let stageRoot = workRoot.appendingPathComponent("cybermac-outfit-piece-add-\(idProvider())", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("Outfit piece add work directory already exists: \(stageRoot.path)")
        }
        try FileManager.default.createDirectory(at: stageRoot, withIntermediateDirectories: true)

        var extractedFiles: [ExtractedFile] = []
        for (index, sourceURL) in sourceArchiveURLs.enumerated() {
            let extractionURL = stageRoot.appendingPathComponent("source-\(index)", isDirectory: true)
            try tooling.extractArchive(
                cp77toolsURL: cp77toolsURL,
                sourceArchiveURL: sourceURL,
                outputDirectoryURL: extractionURL
            )
            extractedFiles.append(contentsOf: try Self.collectExtractedFiles(under: extractionURL, description: "Source archive extraction"))
        }

        let sourceAssetPaths = Array(Set(extractedFiles.map(\.assetPath))).sorted()
        guard !sourceAssetPaths.isEmpty else {
            throw CyberMacError.invalidInput("Source archive extraction produced no regular asset files.")
        }

        let matchMap = try ArchiveCatalogIndexStore().findExactAssetPathMatches(
            databaseURL: databaseURL,
            assetPaths: sourceAssetPaths
        )
        let replacedAssets = sourceAssetPaths.filter {
            matchMap[$0]?.contains(profile.targetArchiveRelativePath) == true
        }
        let addedAssets = sourceAssetPaths.filter {
            matchMap[$0]?.contains(profile.targetArchiveRelativePath) != true
        }
        guard !replacedAssets.isEmpty else {
            throw CyberMacError.invalidInput("Piece \(pieceID) has no exact asset paths in target archive \(profile.targetArchiveRelativePath). At least one replacement is required.")
        }

        let now = dateProvider()
        let piece = OutfitPiece(
            id: pieceID,
            displayName: displayName,
            sourceArchives: sourceArchivePaths,
            sourceArchiveSHA256: sourceArchiveSHA256,
            targetArchiveRelativePath: profile.targetArchiveRelativePath,
            itemIds: normalizedItemIDs,
            enabled: true,
            installOrder: (profile.pieces.map(\.installOrder).max() ?? 0) + 1,
            affectedAssets: OutfitAffectedAssets(
                replacedAssets: replacedAssets,
                addedAssets: addedAssets
            ),
            tags: tags,
            createdAt: now,
            updatedAt: now
        )

        profile.pieces.append(piece)
        profile.updatedAt = now
        normalize(profile: &profile)
        try save(profile)
        try upsertRegistryEntry(for: profile)
        return piece
    }

    public func listPieces(profileID: String) throws -> [OutfitPiece] {
        try loadProfile(id: profileID).pieces.sorted(by: Self.pieceSort)
    }

    public func enablePiece(profileID: String, pieceID rawPieceID: String) throws -> OutfitProfile {
        try setPieceEnabled(profileID: profileID, pieceID: rawPieceID, enabled: true)
    }

    public func disablePiece(profileID: String, pieceID rawPieceID: String) throws -> OutfitProfile {
        try setPieceEnabled(profileID: profileID, pieceID: rawPieceID, enabled: false)
    }

    public func buildProfile(request: OutfitProfileBuildRequest) throws -> OutfitBuildResult {
        try home.bootstrap()
        var profile = try loadProfile(id: request.profileID)
        let backup = try backupManager.load(backupID: profile.pristineBackupId)
        guard backup.relativeArchivePath == profile.targetArchiveRelativePath else {
            throw CyberMacError.invalidInput("Profile backup \(backup.backupID) belongs to \(backup.relativeArchivePath), not \(profile.targetArchiveRelativePath)")
        }
        let pristineArchiveURL = try backupManager.backupFileURL(backupID: backup.backupID)

        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try Self.validateCP77ToolsURL(cp77toolsURL)
        let outputArchiveURL = request.outputArchiveURL.standardizedFileURL
        try Self.validateOutputArchiveURL(outputArchiveURL, backup: backup)
        let workDirectoryURL = request.workDirectoryURL.standardizedFileURL
        try Self.validateWorkDirectoryURL(workDirectoryURL, backup: backup)

        let buildID = Self.buildID(date: dateProvider(), uniqueSuffix: idProvider())
        let stageRoot = workDirectoryURL.appendingPathComponent("cybermac-outfit-build-\(buildID)", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("Outfit build work directory already exists: \(stageRoot.path)")
        }
        let officialDirectory = stageRoot.appendingPathComponent("official", isDirectory: true)
        let sourceDirectory = stageRoot.appendingPathComponent("sources", isDirectory: true)
        let packedDirectory = stageRoot.appendingPathComponent("packed", isDirectory: true)
        try FileManager.default.createDirectory(at: officialDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packedDirectory, withIntermediateDirectories: true)

        try tooling.extractArchive(
            cp77toolsURL: cp77toolsURL,
            sourceArchiveURL: pristineArchiveURL,
            outputDirectoryURL: officialDirectory
        )

        let enabledPieces = enabledPieces(in: profile)
        var writerByAsset: [String: String] = [:]
        var conflicts: [OutfitBuildConflict] = []

        for piece in enabledPieces {
            try validateSourceArchivesUnchanged(piece)
            for (index, sourceArchivePath) in piece.sourceArchives.enumerated() {
                let sourceURL = URL(fileURLWithPath: sourceArchivePath).standardizedFileURL
                let extractionURL = sourceDirectory
                    .appendingPathComponent(piece.id, isDirectory: true)
                    .appendingPathComponent("source-\(index)", isDirectory: true)
                try tooling.extractArchive(
                    cp77toolsURL: cp77toolsURL,
                    sourceArchiveURL: sourceURL,
                    outputDirectoryURL: extractionURL
                )
                let files = try Self.collectExtractedFiles(under: extractionURL, description: "Piece \(piece.id) extraction")
                for file in files.sorted(by: { $0.assetPath < $1.assetPath }) {
                    if let previousPiece = writerByAsset[file.assetPath], previousPiece != piece.id {
                        conflicts.append(OutfitBuildConflict(
                            assetPath: file.assetPath,
                            previousPieceId: previousPiece,
                            winningPieceId: piece.id
                        ))
                    }
                    writerByAsset[file.assetPath] = piece.id
                    let destinationURL = try Self.assetURL(assetPath: file.assetPath, rootURL: officialDirectory, label: "Build destination")
                    try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: file.url, to: destinationURL)
                }
            }
        }

        let requestedPackedURL = packedDirectory.appendingPathComponent(URL(fileURLWithPath: profile.targetArchiveRelativePath).lastPathComponent)
        try tooling.packArchive(
            cp77toolsURL: cp77toolsURL,
            extractedDirectoryURL: officialDirectory,
            outputArchiveURL: requestedPackedURL
        )
        let generatedArchiveURL = try Self.singleGeneratedArchive(in: packedDirectory)

        guard !FileManager.default.fileExists(atPath: outputArchiveURL.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(outputArchiveURL.path)")
        }
        try FileManager.default.copyItem(at: generatedArchiveURL, to: outputArchiveURL)
        let outputSHA = try PathSafety.sha256(url: outputArchiveURL)

        let buildRecordURL = home.outfitBuildsURL
            .appendingPathComponent(profile.id, isDirectory: true)
            .appendingPathComponent(buildID, isDirectory: true)
            .appendingPathComponent("build.json")
        try FileManager.default.createDirectory(at: buildRecordURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let result = OutfitBuildResult(
            profileId: profile.id,
            targetArchiveRelativePath: profile.targetArchiveRelativePath,
            pristineBackupId: profile.pristineBackupId,
            pristineArchivePath: pristineArchiveURL.path,
            enabledPieceIds: enabledPieces.map(\.id),
            conflictWarnings: conflicts,
            outputArchivePath: outputArchiveURL.path,
            outputArchiveSHA256: outputSHA,
            buildRecordPath: buildRecordURL.path,
            manualInstallCommand: Self.manualInstallCommand(sourcePath: outputArchiveURL.path, destinationPath: backup.originalArchivePath),
            statusCommand: Self.statusCommand(relativeArchivePath: profile.targetArchiveRelativePath),
            preflightCommand: Self.preflightCommand(relativeArchivePath: profile.targetArchiveRelativePath),
            createdAt: dateProvider()
        )
        try JSONEncoder.cybermac.encode(result).write(to: buildRecordURL, options: [.atomic])

        profile.pristineArchivePath = pristineArchiveURL.path
        profile.lastBuiltArchivePath = outputArchiveURL.path
        profile.lastBuiltArchiveSHA256 = outputSHA
        profile.lastInstalledSHA256 = nil
        profile.updatedAt = dateProvider()
        normalize(profile: &profile)
        try save(profile)
        try upsertRegistryEntry(for: profile)
        return result
    }

    public func installPlan(profileID: String) throws -> OutfitInstallPlan {
        let profile = try loadProfile(id: profileID)
        let backup = try backupManager.load(backupID: profile.pristineBackupId)
        guard backup.relativeArchivePath == profile.targetArchiveRelativePath else {
            throw CyberMacError.invalidInput("Profile backup \(backup.backupID) belongs to \(backup.relativeArchivePath), not \(profile.targetArchiveRelativePath)")
        }
        guard let builtArchivePath = profile.lastBuiltArchivePath,
              let builtArchiveSHA = profile.lastBuiltArchiveSHA256
        else {
            throw CyberMacError.invalidInput("Profile \(profile.id) has no last built archive. Run `cybermac outfit profile build --profile \(profile.id) ...` first.")
        }
        let builtURL = URL(fileURLWithPath: builtArchivePath).standardizedFileURL
        try Self.validateExistingRegularFile(builtURL, description: "Last built archive")
        let currentSHA = try PathSafety.sha256(url: builtURL)
        guard currentSHA == builtArchiveSHA else {
            throw CyberMacError.invalidInput("Last built archive SHA-256 changed. Expected \(builtArchiveSHA), found \(currentSHA): \(builtArchivePath)")
        }
        return OutfitInstallPlan(
            profile: profile,
            destinationArchivePath: backup.originalArchivePath,
            builtArchivePath: builtArchivePath,
            builtArchiveSHA256: builtArchiveSHA,
            manualInstallCommand: Self.manualInstallCommand(sourcePath: builtArchivePath, destinationPath: backup.originalArchivePath),
            statusCommand: Self.statusCommand(relativeArchivePath: profile.targetArchiveRelativePath),
            preflightCommand: Self.preflightCommand(relativeArchivePath: profile.targetArchiveRelativePath)
        )
    }

    public func grantItems(request: OutfitGrantItemsRequest) throws -> OutfitGrantItemsResult {
        let profile = try loadProfile(id: request.profileID)
        let enabledItems = try Self.normalizeItemIDs(enabledPieces(in: profile).flatMap(\.itemIds), allowEmpty: false)
        let grant = try RedscriptItemGrantGenerator().generate(request: RedscriptItemGrantRequest(
            itemIDs: enabledItems,
            outputZipURL: request.outputZipURL,
            modName: request.modName
        ))
        return OutfitGrantItemsResult(profile: profile, enabledItemIds: enabledItems, grantResult: grant)
    }

    public func restoreOfficialCommand(profileID: String) throws -> String {
        let profile = try loadProfile(id: profileID)
        return try backupManager.restoreDryRunCommand(backupID: profile.pristineBackupId)
    }

    private func setPieceEnabled(profileID: String, pieceID rawPieceID: String, enabled: Bool) throws -> OutfitProfile {
        var profile = try loadProfile(id: profileID)
        let pieceID = try Self.validatedID(rawPieceID, label: "Piece id")
        guard let index = profile.pieces.firstIndex(where: { $0.id == pieceID }) else {
            throw CyberMacError.notFound("Outfit piece not found in profile \(profile.id): \(pieceID)")
        }
        profile.pieces[index].enabled = enabled
        profile.pieces[index].updatedAt = dateProvider()
        profile.updatedAt = dateProvider()
        normalize(profile: &profile)
        try save(profile)
        try upsertRegistryEntry(for: profile)
        return profile
    }

    private func summary(for profile: OutfitProfile) -> OutfitProfileSummary {
        let enabled = enabledPieces(in: profile)
        let disabled = profile.pieces.filter { !$0.enabled }.sorted(by: Self.pieceSort)
        return OutfitProfileSummary(
            profile: profile,
            enabledPieces: enabled,
            disabledPieces: disabled,
            conflictWarnings: Self.conflicts(for: enabled)
        )
    }

    private func enabledPieces(in profile: OutfitProfile) -> [OutfitPiece] {
        profile.pieces.filter(\.enabled).sorted(by: Self.pieceSort)
    }

    private func validateLoadedProfile(_ profile: OutfitProfile) throws {
        guard profile.schemaVersion == OutfitProfile.currentSchemaVersion else {
            throw CyberMacError.unsupported("Unsupported outfit profile schema version: \(profile.schemaVersion)")
        }
        _ = try Self.validatedID(profile.id, label: "Profile id")
        _ = try Self.validatedDisplayName(profile.displayName, label: "Profile name")
        _ = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(profile.targetArchiveRelativePath)
        _ = try Self.validatedID(profile.pristineBackupId, label: "Backup id")
        var seen = Set<String>()
        for piece in profile.pieces {
            _ = try Self.validatedID(piece.id, label: "Piece id")
            guard seen.insert(piece.id).inserted else {
                throw CyberMacError.invalidInput("Duplicate outfit piece id in profile \(profile.id): \(piece.id)")
            }
            guard piece.targetArchiveRelativePath == profile.targetArchiveRelativePath else {
                throw CyberMacError.invalidInput("Piece \(piece.id) targets \(piece.targetArchiveRelativePath), not profile target \(profile.targetArchiveRelativePath)")
            }
        }
    }

    private func normalize(profile: inout OutfitProfile) {
        profile.pieces.sort(by: Self.pieceSort)
        profile.enabledPieceIds = profile.pieces.filter(\.enabled).sorted(by: Self.pieceSort).map(\.id)
        profile.disabledPieceIds = profile.pieces.filter { !$0.enabled }.sorted(by: Self.pieceSort).map(\.id)
        for index in profile.pieces.indices {
            profile.pieces[index].sourceArchives = profile.pieces[index].sourceArchives.sorted()
            profile.pieces[index].itemIds = Array(Set(profile.pieces[index].itemIds)).sorted()
            profile.pieces[index].tags = Array(Set(profile.pieces[index].tags)).sorted()
            profile.pieces[index].affectedAssets.replacedAssets = Array(Set(profile.pieces[index].affectedAssets.replacedAssets)).sorted()
            profile.pieces[index].affectedAssets.addedAssets = Array(Set(profile.pieces[index].affectedAssets.addedAssets)).sorted()
        }
    }

    private static func pieceSort(_ lhs: OutfitPiece, _ rhs: OutfitPiece) -> Bool {
        lhs.installOrder == rhs.installOrder ? lhs.id < rhs.id : lhs.installOrder < rhs.installOrder
    }

    private func validateSourceArchivesUnchanged(_ piece: OutfitPiece) throws {
        for path in piece.sourceArchives {
            guard let expectedSHA = piece.sourceArchiveSHA256[path] else {
                throw CyberMacError.invalidInput("Piece \(piece.id) is missing recorded SHA-256 for source archive: \(path)")
            }
            let url = try Self.validatedSourceArchiveURL(URL(fileURLWithPath: path).standardizedFileURL)
            let currentSHA = try PathSafety.sha256(url: url)
            guard currentSHA == expectedSHA else {
                throw CyberMacError.invalidInput("Source archive changed for piece \(piece.id). Expected \(expectedSHA), found \(currentSHA): \(path)")
            }
        }
    }

    private func loadRegistry() throws -> OutfitRegistry {
        try home.bootstrap()
        guard FileManager.default.fileExists(atPath: home.outfitRegistryURL.path) else {
            return OutfitRegistry(updatedAt: dateProvider())
        }
        do {
            let registry = try JSONDecoder.cybermac.decode(OutfitRegistry.self, from: Data(contentsOf: home.outfitRegistryURL))
            guard registry.schemaVersion == OutfitRegistry.currentSchemaVersion else {
                throw CyberMacError.unsupported("Unsupported outfit registry schema version: \(registry.schemaVersion)")
            }
            return registry
        } catch let error as CyberMacError {
            throw error
        } catch {
            throw CyberMacError.invalidInput("Outfit registry JSON could not be decoded: \(home.outfitRegistryURL.path): \(error.localizedDescription)")
        }
    }

    private func saveRegistry(_ registry: OutfitRegistry) throws {
        try FileManager.default.createDirectory(at: home.outfitsURL, withIntermediateDirectories: true)
        try JSONEncoder.cybermac.encode(registry).write(to: home.outfitRegistryURL, options: [.atomic])
    }

    private func upsertRegistryEntry(for profile: OutfitProfile) throws {
        var registry = try loadRegistry()
        let entry = OutfitRegistryProfileEntry(
            id: profile.id,
            displayName: profile.displayName,
            targetArchiveRelativePath: profile.targetArchiveRelativePath,
            profilePath: profileURL(id: profile.id).path,
            updatedAt: profile.updatedAt
        )
        if let index = registry.profiles.firstIndex(where: { $0.id == profile.id }) {
            registry.profiles[index] = entry
        } else {
            registry.profiles.append(entry)
        }
        registry.profiles.sort { $0.id < $1.id }
        registry.updatedAt = dateProvider()
        try saveRegistry(registry)
    }

    private func save(_ profile: OutfitProfile) throws {
        try FileManager.default.createDirectory(at: home.outfitProfilesURL, withIntermediateDirectories: true)
        var normalized = profile
        normalize(profile: &normalized)
        try JSONEncoder.cybermac.encode(normalized).write(to: profileURL(id: normalized.id), options: [.atomic])
    }

    private func profileURL(id: String) -> URL {
        home.outfitProfilesURL.appendingPathComponent("\(id).json")
    }

    private func pieceAddWorkRoot(_ requested: URL?) throws -> URL {
        let root = (requested?.standardizedFileURL ?? home.tmpURL.appendingPathComponent("outfit-piece-add", isDirectory: true))
        try Self.validateWorkDirectoryRoot(root, description: "Piece add work directory")
        return root
    }

    private static func conflicts(for pieces: [OutfitPiece]) -> [OutfitBuildConflict] {
        var writerByAsset: [String: String] = [:]
        var conflicts: [OutfitBuildConflict] = []
        for piece in pieces.sorted(by: pieceSort) {
            let assets = Set(piece.affectedAssets.replacedAssets + piece.affectedAssets.addedAssets)
            for asset in assets.sorted() {
                if let previous = writerByAsset[asset], previous != piece.id {
                    conflicts.append(OutfitBuildConflict(
                        assetPath: asset,
                        previousPieceId: previous,
                        winningPieceId: piece.id
                    ))
                }
                writerByAsset[asset] = piece.id
            }
        }
        return conflicts
    }

    private static func collectExtractedFiles(under rootURL: URL, description: String) throws -> [ExtractedFile] {
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
            return []
        }

        var files: [ExtractedFile] = []
        var seen = Set<String>()
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard resource.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("\(description) contains a symlink: \(url.path)")
            }
            guard resource.isRegularFile == true else { continue }
            try validateContainedPath(url, in: rootURL, description: description)
            let raw = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            let assetPath = try validatedAssetPath(raw.replacingOccurrences(of: "\\", with: "/"), label: description)
            guard seen.insert(assetPath).inserted else {
                throw CyberMacError.invalidInput("\(description) contains duplicate asset path after normalization: \(assetPath)")
            }
            files.append(ExtractedFile(assetPath: assetPath, url: url.standardizedFileURL))
        }
        return files.sorted { $0.assetPath < $1.assetPath }
    }

    private static func assetURL(assetPath: String, rootURL: URL, label: String) throws -> URL {
        let validated = try validatedAssetPath(assetPath, label: label)
        let url = validated
            .split(separator: "/")
            .reduce(rootURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
        try validateContainedPath(url, in: rootURL, description: label)
        return url.standardizedFileURL
    }

    private static func singleGeneratedArchive(in packedDirectory: URL) throws -> URL {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: packedDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "archive" }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        guard !candidates.isEmpty else {
            throw CyberMacError.notFound("No generated .archive files were found in packed output directory: \(packedDirectory.path)")
        }
        guard candidates.count == 1 else {
            let candidateList = candidates.map { "- \($0.path)" }.joined(separator: "\n")
            throw CyberMacError.invalidInput("cp77tools generated more than one .archive in packed output directory \(packedDirectory.path):\n\(candidateList)")
        }
        let archive = candidates[0].standardizedFileURL
        try validateExistingRegularFile(archive, description: "Generated packed archive")
        return archive
    }

    private static func validatedID(_ raw: String, label: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("\(label) must not be empty")
        }
        guard trimmed.allSatisfy(isAllowedIDCharacter) else {
            throw CyberMacError.invalidInput("\(label) may only contain A-Z, a-z, 0-9, '_', '-'. Got: \(raw)")
        }
        guard trimmed != "." && trimmed != ".." else {
            throw CyberMacError.unsafePath("\(label) is not a safe path component: \(raw)")
        }
        return trimmed
    }

    private static func isAllowedIDCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            let isPunct = scalar == "_" || scalar == "-"
            if !(isUpper || isLower || isDigit || isPunct) {
                return false
            }
        }
        return true
    }

    private static func validatedDisplayName(_ raw: String, label: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("\(label) must not be empty")
        }
        guard !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.invalidInput("\(label) contains control characters")
        }
        return trimmed
    }

    private static func normalizeItemIDs(_ raw: [String], allowEmpty: Bool) throws -> [String] {
        if raw.isEmpty {
            if allowEmpty { return [] }
            throw CyberMacError.invalidInput("At least one enabled outfit piece must include an item ID")
        }
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CyberMacError.invalidInput("Item ID must not be empty")
            }
            guard trimmed.hasPrefix("Items.") else {
                throw CyberMacError.invalidInput("Item ID must start with 'Items.': \(value)")
            }
            let suffix = trimmed.dropFirst("Items.".count)
            guard !suffix.isEmpty else {
                throw CyberMacError.invalidInput("Item ID is missing the part after 'Items.': \(value)")
            }
            guard suffix.allSatisfy(isAllowedItemIDCharacter) else {
                throw CyberMacError.invalidInput("Item ID contains unsupported characters: \(value). Allowed after 'Items.': A-Z, a-z, 0-9, '_', '-', '.'")
            }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result.sorted()
    }

    private static func isAllowedItemIDCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            let isPunct = scalar == "_" || scalar == "-" || scalar == "."
            if !(isUpper || isLower || isDigit || isPunct) {
                return false
            }
        }
        return true
    }

    private static func normalizeTags(_ raw: [String]) throws -> [String] {
        var seen = Set<String>()
        var tags: [String] = []
        for value in raw {
            let tag = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !tag.isEmpty else {
                throw CyberMacError.invalidInput("Tag must not be empty")
            }
            guard tag.allSatisfy(isAllowedIDCharacter) else {
                throw CyberMacError.invalidInput("Tag may only contain A-Z, a-z, 0-9, '_', '-'. Got: \(value)")
            }
            if seen.insert(tag).inserted {
                tags.append(tag)
            }
        }
        return tags.sorted()
    }

    private static func validatedSourceArchiveURL(_ url: URL) throws -> URL {
        try validateExistingRegularFile(url, description: "Source archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Source archive path must end in .archive: \(url.path)")
        }
        return url.standardizedFileURL
    }

    private static func validateOutputArchiveURL(_ url: URL, backup: OfficialArchiveBackupMetadata) throws {
        try validateLocalTargetURL(url, description: "Output archive")
        try validateNotInsideGameBundle(url, backup: backup, description: "Output archive")
        guard url.pathExtension.lowercased() == "archive" else {
            throw CyberMacError.invalidInput("Output archive path must end in .archive: \(url.path)")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.invalidInput("Output archive already exists: \(url.path)")
        }
        let parent = url.deletingLastPathComponent()
        try validateExistingDirectory(parent, description: "Output archive parent directory")
        try validateNotInsideGameBundle(parent, backup: backup, description: "Output archive parent directory")
    }

    private static func validateWorkDirectoryURL(_ url: URL, backup: OfficialArchiveBackupMetadata) throws {
        try validateWorkDirectoryRoot(url, description: "Work directory")
        try validateNotInsideGameBundle(url, backup: backup, description: "Work directory")
    }

    private static func validateWorkDirectoryRoot(_ url: URL, description: String) throws {
        try validateLocalTargetURL(url, description: description)
        try validateNotInsideAppBundle(url, description: description)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try validateExistingDirectory(url, description: description)
    }

    private static func validateCP77ToolsURL(_ url: URL) throws {
        try validateExistingRegularFile(url, description: "cp77tools path")
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CyberMacError.invalidInput("cp77tools path is not executable: \(url.path)")
        }
    }

    private static func validateExistingRegularFile(_ url: URL, description: String) throws {
        try validateLocalTargetURL(url, description: description)
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

    private static func validateExistingDirectory(_ url: URL, description: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("\(description) does not exist: \(url.path)")
        }
        guard isDirectory.boolValue else {
            throw CyberMacError.invalidInput("\(description) is not a directory: \(url.path)")
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) must not be a symlink: \(url.path)")
        }
    }

    private static func validateLocalTargetURL(_ url: URL, description: String) throws {
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

    private static func validateNotInsideGameBundle(_ url: URL, backup: OfficialArchiveBackupMetadata, description: String) throws {
        guard !backup.gameAppPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let gameRoot = URL(fileURLWithPath: backup.gameAppPath).resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = gameRoot.hasSuffix("/") ? gameRoot : gameRoot + "/"
        guard targetPath != gameRoot, !targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) must not be inside the game bundle: \(targetPath)")
        }
    }

    private static func validateNotInsideAppBundle(_ url: URL, description: String) throws {
        let components = url.standardizedFileURL.path.split(separator: "/").map(String.init)
        guard !components.contains(where: { $0.hasSuffix(".app") }) else {
            throw CyberMacError.unsafePath("\(description) must not be inside an app bundle: \(url.path)")
        }
    }

    private static func validateContainedPath(_ targetURL: URL, in rootURL: URL, description: String) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath == rootPath || targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) escapes expected root: \(targetPath)")
        }
    }

    private static func validatedAssetPath(_ rawPath: String, label: String) throws -> String {
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

    private static func manualInstallCommand(sourcePath: String, destinationPath: String) -> String {
        "sudo cp \(PathSafety.shellQuoted(sourcePath)) \(PathSafety.shellQuoted(destinationPath))"
    }

    private static func statusCommand(relativeArchivePath: String) -> String {
        "swift run cybermac archive-patch status \(relativeArchivePath)"
    }

    private static func preflightCommand(relativeArchivePath: String) -> String {
        "swift run cybermac archive-patch preflight \(relativeArchivePath)"
    }

    private static func buildID(date: Date, uniqueSuffix: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let suffix = uniqueSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        if suffix.isEmpty {
            return formatter.string(from: date)
        }
        return "\(formatter.string(from: date))-\(suffix.prefix(8))"
    }
}

public enum OutfitProfileFormatter {
    public static func formatList(_ profiles: [OutfitProfile]) -> String {
        guard !profiles.isEmpty else {
            return "No outfit profiles found."
        }
        return profiles
            .map { "\($0.id) | \($0.displayName) | \($0.targetArchiveRelativePath) | enabled: \($0.enabledPieceIds.count) | disabled: \($0.disabledPieceIds.count)" }
            .joined(separator: "\n")
    }

    public static func formatShow(_ summary: OutfitProfileSummary) -> String {
        let profile = summary.profile
        var lines: [String] = [
            "Outfit profile",
            "ID: \(profile.id)",
            "Name: \(profile.displayName)",
            "Target archive: \(profile.targetArchiveRelativePath)",
            "Pristine backup: \(profile.pristineBackupId)"
        ]
        if let pristineArchivePath = profile.pristineArchivePath {
            lines.append("Pristine archive path: \(pristineArchivePath)")
        }
        lines.append("Enabled pieces: \(summary.enabledPieces.count)")
        lines.append("Disabled pieces: \(summary.disabledPieces.count)")
        if let path = profile.lastBuiltArchivePath, let sha = profile.lastBuiltArchiveSHA256 {
            lines.append("Last build: \(path)")
            lines.append("Last build SHA-256: \(sha)")
        }
        lines.append("")
        appendPieces(summary.enabledPieces, title: "Enabled", to: &lines)
        lines.append("")
        appendPieces(summary.disabledPieces, title: "Disabled", to: &lines)
        if !summary.conflictWarnings.isEmpty {
            lines.append("")
            lines.append("Conflict warnings:")
            for conflict in summary.conflictWarnings {
                lines.append("  - \(conflict.assetPath): \(conflict.previousPieceId) overwritten by \(conflict.winningPieceId)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatPieces(_ pieces: [OutfitPiece]) -> String {
        guard !pieces.isEmpty else {
            return "No outfit pieces found."
        }
        return pieces.map { piece in
            let state = piece.enabled ? "enabled" : "disabled"
            return "\(piece.installOrder) | \(piece.id) | \(piece.displayName) | \(state) | replaced: \(piece.affectedAssets.replacedAssets.count) | added: \(piece.affectedAssets.addedAssets.count) | items: \(piece.itemIds.count)"
        }
        .joined(separator: "\n")
    }

    public static func formatPieceAdded(_ piece: OutfitPiece, profileID: String) -> String {
        var lines: [String] = [
            "Outfit piece added.",
            "Profile: \(profileID)",
            "Piece ID: \(piece.id)",
            "Name: \(piece.displayName)",
            "Install order: \(piece.installOrder)",
            "Enabled: \(piece.enabled ? "yes" : "no")",
            "Replaced assets: \(piece.affectedAssets.replacedAssets.count)",
            "Added assets: \(piece.affectedAssets.addedAssets.count)"
        ]
        if !piece.itemIds.isEmpty {
            lines.append("Item IDs:")
            for item in piece.itemIds {
                lines.append("  - \(item)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatBuild(_ result: OutfitBuildResult) -> String {
        var lines: [String] = [
            "Outfit profile archive built.",
            "Profile: \(result.profileId)",
            "Target archive: \(result.targetArchiveRelativePath)",
            "Pristine backup: \(result.pristineBackupId)",
            "Enabled pieces: \(result.enabledPieceIds.joined(separator: ", "))",
            "Output archive: \(result.outputArchivePath)",
            "Output archive SHA-256: \(result.outputArchiveSHA256)",
            "Build record: \(result.buildRecordPath)"
        ]
        if !result.conflictWarnings.isEmpty {
            lines.append("")
            lines.append("Conflict warnings:")
            for conflict in result.conflictWarnings {
                lines.append("  - \(conflict.assetPath): \(conflict.previousPieceId) overwritten by \(conflict.winningPieceId)")
            }
        }
        lines.append("")
        lines.append("Manual install command:")
        lines.append(result.manualInstallCommand)
        lines.append("")
        lines.append("CyberMac verification commands:")
        lines.append(result.statusCommand)
        lines.append(result.preflightCommand)
        return lines.joined(separator: "\n")
    }

    public static func formatInstall(_ plan: OutfitInstallPlan) -> String {
        [
            "Outfit profile install command",
            "Profile: \(plan.profile.displayName) (\(plan.profile.id))",
            "Target archive: \(plan.profile.targetArchiveRelativePath)",
            "Destination: \(plan.destinationArchivePath)",
            "Built archive: \(plan.builtArchivePath)",
            "Built SHA-256: \(plan.builtArchiveSHA256)",
            "",
            "Run this manually:",
            plan.manualInstallCommand,
            "",
            "Then verify:",
            plan.statusCommand,
            plan.preflightCommand
        ].joined(separator: "\n")
    }

    public static func formatGrantItems(_ result: OutfitGrantItemsResult) -> String {
        var lines: [String] = [
            "Generated outfit item-grant helper.",
            "Profile: \(result.profile.displayName) (\(result.profile.id))",
            "Output zip: \(result.grantResult.outputZipURL.path)",
            "Mod name: \(result.grantResult.modName)",
            "Item IDs (\(result.enabledItemIds.count)):"
        ]
        for item in result.enabledItemIds {
            lines.append("  - \(item)")
        }
        lines.append("")
        lines.append("Recommended one-shot workflow:")
        lines.append("  1. Install + activate the grant helper.")
        lines.append("     swift run cybermac install \(PathSafety.shellQuoted(result.grantResult.outputZipURL.path)) --game-app /path/to/Cyberpunk.app")
        lines.append("     swift run cybermac activate --bundle-mode --game-app /path/to/Cyberpunk.app")
        lines.append("     # Run the printed sudo cp command(s) to copy the generated final.redscripts into the game bundle.")
        lines.append("     swift run cybermac activate --verify --game-app /path/to/Cyberpunk.app")
        lines.append("")
        lines.append("  2. Launch Cyberpunk 2077 once. Confirm the items appeared in your inventory.")
        lines.append("     swift run cybermac launch-game --game-app /path/to/Cyberpunk.app")
        lines.append("")
        lines.append("  3. Quit the game and disable the grant helper so the next launch does not re-grant.")
        lines.append("     swift run cybermac list-mods")
        lines.append("     swift run cybermac disable <mod-id>")
        lines.append("")
        lines.append("  4. Re-activate without the grant helper, then verify.")
        lines.append("     swift run cybermac activate --bundle-mode --game-app /path/to/Cyberpunk.app")
        lines.append("     # Re-run the printed sudo cp command(s).")
        lines.append("     swift run cybermac activate --verify --game-app /path/to/Cyberpunk.app")
        lines.append("")
        lines.append("Uses vanilla redscript APIs only. Does not mutate the game bundle.")
        return lines.joined(separator: "\n")
    }

    private static func appendPieces(_ pieces: [OutfitPiece], title: String, to lines: inout [String]) {
        lines.append("\(title) pieces:")
        if pieces.isEmpty {
            lines.append("  (none)")
            return
        }
        for piece in pieces {
            lines.append("  - \(piece.id) | \(piece.displayName) | order \(piece.installOrder)")
            lines.append("    Item IDs: \(piece.itemIds.isEmpty ? "none" : piece.itemIds.joined(separator: ", "))")
            lines.append("    Replaced assets: \(piece.affectedAssets.replacedAssets.count)")
            lines.append("    Added assets: \(piece.affectedAssets.addedAssets.count)")
        }
    }
}
