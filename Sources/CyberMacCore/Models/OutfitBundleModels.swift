import Foundation

public enum CyberMacOutfitBundleStatus: String, Codable, Equatable, Sendable {
    case staged
    case archiveInstalled
    case grantEnabled
    case active
    case restored
}

public struct CyberMacOutfitBundle: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public var displayName: String
    public let targetArchive: String
    public let patchedArchivePath: String
    public let patchedArchiveSHA256: String
    public let patchedArchiveSizeBytes: UInt64
    public let backupID: String
    public let affectedItemIDs: [String]
    public let affectedAssets: [String]
    public var optionalItemGrantModID: String?
    public var status: CyberMacOutfitBundleStatus
    public let createdAt: Date

    public init(
        schemaVersion: Int = CyberMacOutfitBundle.currentSchemaVersion,
        id: String,
        displayName: String,
        targetArchive: String,
        patchedArchivePath: String,
        patchedArchiveSHA256: String,
        patchedArchiveSizeBytes: UInt64,
        backupID: String,
        affectedItemIDs: [String],
        affectedAssets: [String],
        optionalItemGrantModID: String? = nil,
        status: CyberMacOutfitBundleStatus = .staged,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.targetArchive = targetArchive
        self.patchedArchivePath = patchedArchivePath
        self.patchedArchiveSHA256 = patchedArchiveSHA256
        self.patchedArchiveSizeBytes = patchedArchiveSizeBytes
        self.backupID = backupID
        self.affectedItemIDs = affectedItemIDs
        self.affectedAssets = affectedAssets
        self.optionalItemGrantModID = optionalItemGrantModID
        self.status = status
        self.createdAt = createdAt
    }
}
