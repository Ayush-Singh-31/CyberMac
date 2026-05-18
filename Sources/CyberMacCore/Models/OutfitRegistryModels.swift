import Foundation

public struct OutfitRegistry: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var profiles: [OutfitRegistryProfileEntry]
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        profiles: [OutfitRegistryProfileEntry] = [],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.updatedAt = updatedAt
    }
}

public struct OutfitRegistryProfileEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var displayName: String
    public var targetArchiveRelativePath: String
    public var profilePath: String
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        targetArchiveRelativePath: String,
        profilePath: String,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.profilePath = profilePath
        self.updatedAt = updatedAt
    }
}

public struct OutfitProfile: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public var displayName: String
    public var targetArchiveRelativePath: String
    public var pristineBackupId: String
    public var pristineArchivePath: String?
    public var enabledPieceIds: [String]
    public var disabledPieceIds: [String]
    public var pieces: [OutfitPiece]
    public let createdAt: Date
    public var updatedAt: Date
    public var lastBuiltArchivePath: String?
    public var lastBuiltArchiveSHA256: String?
    public var lastInstalledSHA256: String?

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: String,
        displayName: String,
        targetArchiveRelativePath: String,
        pristineBackupId: String,
        pristineArchivePath: String? = nil,
        enabledPieceIds: [String] = [],
        disabledPieceIds: [String] = [],
        pieces: [OutfitPiece] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastBuiltArchivePath: String? = nil,
        lastBuiltArchiveSHA256: String? = nil,
        lastInstalledSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.pristineBackupId = pristineBackupId
        self.pristineArchivePath = pristineArchivePath
        self.enabledPieceIds = enabledPieceIds
        self.disabledPieceIds = disabledPieceIds
        self.pieces = pieces
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastBuiltArchivePath = lastBuiltArchivePath
        self.lastBuiltArchiveSHA256 = lastBuiltArchiveSHA256
        self.lastInstalledSHA256 = lastInstalledSHA256
    }
}

public struct OutfitPiece: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var displayName: String
    public var sourceArchives: [String]
    public var sourceArchiveSHA256: [String: String]
    public var targetArchiveRelativePath: String
    public var itemIds: [String]
    public var enabled: Bool
    public var installOrder: Int
    public var affectedAssets: OutfitAffectedAssets
    public var notes: String?
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        sourceArchives: [String],
        sourceArchiveSHA256: [String: String],
        targetArchiveRelativePath: String,
        itemIds: [String],
        enabled: Bool,
        installOrder: Int,
        affectedAssets: OutfitAffectedAssets,
        notes: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceArchives = sourceArchives
        self.sourceArchiveSHA256 = sourceArchiveSHA256
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.itemIds = itemIds
        self.enabled = enabled
        self.installOrder = installOrder
        self.affectedAssets = affectedAssets
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OutfitAffectedAssets: Codable, Equatable, Sendable {
    public var replacedAssets: [String]
    public var addedAssets: [String]

    public init(replacedAssets: [String], addedAssets: [String]) {
        self.replacedAssets = replacedAssets
        self.addedAssets = addedAssets
    }
}

public struct OutfitBuildConflict: Codable, Equatable, Sendable {
    public let assetPath: String
    public let previousPieceId: String
    public let winningPieceId: String

    public init(assetPath: String, previousPieceId: String, winningPieceId: String) {
        self.assetPath = assetPath
        self.previousPieceId = previousPieceId
        self.winningPieceId = winningPieceId
    }
}

public struct OutfitBuildResult: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let profileId: String
    public let targetArchiveRelativePath: String
    public let pristineBackupId: String
    public let pristineArchivePath: String
    public let enabledPieceIds: [String]
    public let conflictWarnings: [OutfitBuildConflict]
    public let outputArchivePath: String
    public let outputArchiveSHA256: String
    public let buildRecordPath: String
    public let manualInstallCommand: String
    public let statusCommand: String
    public let preflightCommand: String
    public let createdAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        profileId: String,
        targetArchiveRelativePath: String,
        pristineBackupId: String,
        pristineArchivePath: String,
        enabledPieceIds: [String],
        conflictWarnings: [OutfitBuildConflict],
        outputArchivePath: String,
        outputArchiveSHA256: String,
        buildRecordPath: String,
        manualInstallCommand: String,
        statusCommand: String,
        preflightCommand: String,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.profileId = profileId
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.pristineBackupId = pristineBackupId
        self.pristineArchivePath = pristineArchivePath
        self.enabledPieceIds = enabledPieceIds
        self.conflictWarnings = conflictWarnings
        self.outputArchivePath = outputArchivePath
        self.outputArchiveSHA256 = outputArchiveSHA256
        self.buildRecordPath = buildRecordPath
        self.manualInstallCommand = manualInstallCommand
        self.statusCommand = statusCommand
        self.preflightCommand = preflightCommand
        self.createdAt = createdAt
    }
}

public struct OutfitInstallPlan: Equatable, Sendable {
    public let profile: OutfitProfile
    public let destinationArchivePath: String
    public let builtArchivePath: String
    public let builtArchiveSHA256: String
    public let manualInstallCommand: String
    public let statusCommand: String
    public let preflightCommand: String

    public init(
        profile: OutfitProfile,
        destinationArchivePath: String,
        builtArchivePath: String,
        builtArchiveSHA256: String,
        manualInstallCommand: String,
        statusCommand: String,
        preflightCommand: String
    ) {
        self.profile = profile
        self.destinationArchivePath = destinationArchivePath
        self.builtArchivePath = builtArchivePath
        self.builtArchiveSHA256 = builtArchiveSHA256
        self.manualInstallCommand = manualInstallCommand
        self.statusCommand = statusCommand
        self.preflightCommand = preflightCommand
    }
}

public struct OutfitGrantItemsResult: Equatable, Sendable {
    public let profile: OutfitProfile
    public let enabledItemIds: [String]
    public let grantResult: RedscriptItemGrantResult

    public init(profile: OutfitProfile, enabledItemIds: [String], grantResult: RedscriptItemGrantResult) {
        self.profile = profile
        self.enabledItemIds = enabledItemIds
        self.grantResult = grantResult
    }
}
