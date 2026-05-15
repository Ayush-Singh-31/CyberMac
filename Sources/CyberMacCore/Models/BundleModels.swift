import Foundation

public enum ActivationState: String, Codable, Sendable {
    case requiresBundleActivation
    case outOfSync
    case active
}

public enum BundleCacheKind: String, Codable, Sendable {
    case vanilla
    case cyberMacActive
    case externallyChanged
    case missing
}

public struct BundleCacheClassification: Codable, Sendable {
    public let kind: BundleCacheKind
    public let targetPath: String
    public let currentSHA256: String?
    public let baseSnapshotSHA256: String?
    public let activeSHA256: String?
    public let pendingSHA256: String?
    public let baseSnapshotID: String?
    public let overlayMirrorPresent: Bool

    public init(
        kind: BundleCacheKind,
        targetPath: String,
        currentSHA256: String?,
        baseSnapshotSHA256: String?,
        activeSHA256: String?,
        pendingSHA256: String?,
        baseSnapshotID: String?,
        overlayMirrorPresent: Bool
    ) {
        self.kind = kind
        self.targetPath = targetPath
        self.currentSHA256 = currentSHA256
        self.baseSnapshotSHA256 = baseSnapshotSHA256
        self.activeSHA256 = activeSHA256
        self.pendingSHA256 = pendingSHA256
        self.baseSnapshotID = baseSnapshotID
        self.overlayMirrorPresent = overlayMirrorPresent
    }
}

public struct BundleStateSnapshot: Codable, Sendable {
    public let bundle: BundleCacheClassification
    public let activationState: ActivationState
    public let bundleChangedSinceLastActivation: Bool
    public let enabledMods: [InstalledModManifest]
    public let activeModIDs: [String]
    public let activationBlocked: Bool
    public let nextStep: String

    public init(
        bundle: BundleCacheClassification,
        activationState: ActivationState,
        bundleChangedSinceLastActivation: Bool,
        enabledMods: [InstalledModManifest],
        activeModIDs: [String],
        activationBlocked: Bool,
        nextStep: String
    ) {
        self.bundle = bundle
        self.activationState = activationState
        self.bundleChangedSinceLastActivation = bundleChangedSinceLastActivation
        self.enabledMods = enabledMods
        self.activeModIDs = activeModIDs
        self.activationBlocked = activationBlocked
        self.nextStep = nextStep
    }
}

public enum PriorFileState: String, Codable, Sendable {
    case present
    case absent
}

public struct GameBundleFingerprint: Codable, Equatable, Sendable {
    public let id: String
    public let bundleIdentifier: String
    public let bundleShortVersion: String
    public let bundleVersion: String
    public let appPath: String
    public let executableSHA256: String
    public let receiptSHA256: String

    public init(id: String, bundleIdentifier: String, bundleShortVersion: String, bundleVersion: String, appPath: String, executableSHA256: String, receiptSHA256: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.bundleShortVersion = bundleShortVersion
        self.bundleVersion = bundleVersion
        self.appPath = appPath
        self.executableSHA256 = executableSHA256
        self.receiptSHA256 = receiptSHA256
    }
}

public struct BaseCacheSnapshotMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let snapshotID: String
    public let createdAt: Date
    public let gameFingerprint: GameBundleFingerprint
    public let bundleCachePath: String
    public let bundleCacheSHA256: String
    public let sizeBytes: UInt64
    public let modificationDate: Date?

    public init(schemaVersion: Int = 1, snapshotID: String, createdAt: Date, gameFingerprint: GameBundleFingerprint, bundleCachePath: String, bundleCacheSHA256: String, sizeBytes: UInt64, modificationDate: Date?) {
        self.schemaVersion = schemaVersion
        self.snapshotID = snapshotID
        self.createdAt = createdAt
        self.gameFingerprint = gameFingerprint
        self.bundleCachePath = bundleCachePath
        self.bundleCacheSHA256 = bundleCacheSHA256
        self.sizeBytes = sizeBytes
        self.modificationDate = modificationDate
    }
}

public struct BundleBackupManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let createdAt: Date
    public let gameAppPath: String
    public let bundleTarget: String
    public let priorState: PriorFileState
    public let sha256: String?
    public let sizeBytes: UInt64?
    public let gameFingerprintID: String

    public init(schemaVersion: Int = 1, id: String, createdAt: Date, gameAppPath: String, bundleTarget: String, priorState: PriorFileState, sha256: String?, sizeBytes: UInt64?, gameFingerprintID: String) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.gameAppPath = gameAppPath
        self.bundleTarget = bundleTarget
        self.priorState = priorState
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.gameFingerprintID = gameFingerprintID
    }
}

public struct PendingActivation: Codable, Equatable, Sendable {
    public let createdAt: Date
    public let gameAppPath: String
    public let bundleTarget: String
    public let tempOutputPath: String
    public let backupID: String
    public let baseCacheSnapshotID: String
    public let activeModIDs: [String]
    public let expectedHashes: [String: String]

    public init(createdAt: Date, gameAppPath: String, bundleTarget: String, tempOutputPath: String, backupID: String, baseCacheSnapshotID: String, activeModIDs: [String], expectedHashes: [String: String]) {
        self.createdAt = createdAt
        self.gameAppPath = gameAppPath
        self.bundleTarget = bundleTarget
        self.tempOutputPath = tempOutputPath
        self.backupID = backupID
        self.baseCacheSnapshotID = baseCacheSnapshotID
        self.activeModIDs = activeModIDs
        self.expectedHashes = expectedHashes
    }
}
