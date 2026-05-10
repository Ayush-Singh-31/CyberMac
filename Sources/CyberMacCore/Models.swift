import Foundation

public enum Storefront: String, Codable, Sendable {
    case macAppStore = "Mac App Store"
    case unknown = "Unknown"
}

public struct GameInstall: Codable, Sendable {
    public let appURL: URL
    public let executableURL: URL
    public let dataURL: URL
    public let archiveMacURL: URL?
    public let r6URL: URL?
    public let storefront: Storefront
    public let displayName: String

    public init(appURL: URL, executableURL: URL, dataURL: URL, archiveMacURL: URL?, r6URL: URL?, storefront: Storefront, displayName: String) {
        self.appURL = appURL
        self.executableURL = executableURL
        self.dataURL = dataURL
        self.archiveMacURL = archiveMacURL
        self.r6URL = r6URL
        self.storefront = storefront
        self.displayName = displayName
    }
}

public enum RuntimeKind: String, Codable, Sendable {
    case redscript
    case inputLoader
}

public struct RuntimeStatus: Codable, Sendable {
    public let kind: RuntimeKind
    public let rootURL: URL
    public let installed: Bool
    public let toolURL: URL?
    public let version: String?
    public let quarantinedPaths: [URL]
    public let notes: [String]

    public init(kind: RuntimeKind, rootURL: URL, installed: Bool, toolURL: URL?, version: String? = nil, quarantinedPaths: [URL], notes: [String]) {
        self.kind = kind
        self.rootURL = rootURL
        self.installed = installed
        self.toolURL = toolURL
        self.version = version
        self.quarantinedPaths = quarantinedPaths
        self.notes = notes
    }
}

public enum CompatibilityStatus: String, Codable, Sendable {
    case supported = "Supported"
    case unsupported = "Unsupported"
    case untested = "Untested"
}

public enum InstalledModStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case uninstalled
}

public enum ModKind: String, Codable, Sendable {
    case redscript
    case archive
    case mixed
    case unknown
}

public struct ModScanFinding: Codable, Sendable {
    public let path: String
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct ModScanResult: Codable, Sendable {
    public let archiveURL: URL
    public let displayName: String
    public let compatibilityStatus: CompatibilityStatus
    public let sidecarInstallable: Bool
    public let installBlockReason: String?
    public let kind: ModKind
    public let reasons: [String]
    public let findings: [ModScanFinding]
    public let redscriptEntries: [String]
    public let archiveEntries: [String]
    public let allEntries: [String]

    public init(
        archiveURL: URL,
        displayName: String,
        compatibilityStatus: CompatibilityStatus,
        sidecarInstallable: Bool,
        installBlockReason: String?,
        kind: ModKind,
        reasons: [String],
        findings: [ModScanFinding],
        redscriptEntries: [String],
        archiveEntries: [String],
        allEntries: [String]
    ) {
        self.archiveURL = archiveURL
        self.displayName = displayName
        self.compatibilityStatus = compatibilityStatus
        self.sidecarInstallable = sidecarInstallable
        self.installBlockReason = installBlockReason
        self.kind = kind
        self.reasons = reasons
        self.findings = findings
        self.redscriptEntries = redscriptEntries
        self.archiveEntries = archiveEntries
        self.allEntries = allEntries
    }
}

public enum ActivationState: String, Codable, Sendable {
    case requiresBundleActivation
    case outOfSync
    case active
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

public struct InstalledFileRecord: Codable, Sendable {
    public let sourceInArchive: String
    public let installedPath: String
    public let sizeBytes: UInt64
    public let sha256: String

    public init(sourceInArchive: String, installedPath: String, sizeBytes: UInt64, sha256: String) {
        self.sourceInArchive = sourceInArchive
        self.installedPath = installedPath
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
    }
}

public struct InstalledModManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let type: ModKind
    public var status: InstalledModStatus
    public let sourceArchive: String
    public let installedAt: Date
    public let gameAppPath: String
    public let installMode: String
    public var installedFiles: [InstalledFileRecord]
    public let detectedDependencies: [String]
    public let compatibilityStatus: CompatibilityStatus

    public init(
        schemaVersion: Int = 1,
        id: String,
        displayName: String,
        type: ModKind,
        status: InstalledModStatus,
        sourceArchive: String,
        installedAt: Date,
        gameAppPath: String,
        installMode: String,
        installedFiles: [InstalledFileRecord],
        detectedDependencies: [String],
        compatibilityStatus: CompatibilityStatus
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.type = type
        self.status = status
        self.sourceArchive = sourceArchive
        self.installedAt = installedAt
        self.gameAppPath = gameAppPath
        self.installMode = installMode
        self.installedFiles = installedFiles
        self.detectedDependencies = detectedDependencies
        self.compatibilityStatus = compatibilityStatus
    }
}

public enum LaunchWorkflowState: String, Codable, Sendable {
    case notVerified
    case verified
    case failed
}

public struct LaunchWorkflowStatus: Codable, Sendable {
    public let state: LaunchWorkflowState
    public let checkedAt: Date
    public let message: String

    public init(state: LaunchWorkflowState, checkedAt: Date, message: String) {
        self.state = state
        self.checkedAt = checkedAt
        self.message = message
    }
}

public struct DiagnosticReport: Codable, Sendable {
    public let generatedAt: Date
    public let cyberMacVersion: String
    public let macOS: String
    public let architecture: String
    public let gameFound: Bool
    public let storefront: String
    public let gameAppPath: String?
    public let executableExists: Bool
    public let dataPathExists: Bool
    public let cyberMacHome: String
    public let redscriptRuntime: String
    public let inputLoaderRuntime: String
    public let launchWorkflow: String
    public let activationState: String
    public let bundleChangedSinceLastActivation: Bool
    public let activeModIDs: [String]
    public let baseCacheSnapshotID: String?
    public let lastBackupID: String?
    public let installedManagedMods: Int
    public let notes: [String]

    public init(
        generatedAt: Date,
        cyberMacVersion: String,
        macOS: String,
        architecture: String,
        gameFound: Bool,
        storefront: String,
        gameAppPath: String?,
        executableExists: Bool,
        dataPathExists: Bool,
        cyberMacHome: String,
        redscriptRuntime: String,
        inputLoaderRuntime: String,
        launchWorkflow: String,
        activationState: String,
        bundleChangedSinceLastActivation: Bool,
        activeModIDs: [String],
        baseCacheSnapshotID: String?,
        lastBackupID: String?,
        installedManagedMods: Int,
        notes: [String]
    ) {
        self.generatedAt = generatedAt
        self.cyberMacVersion = cyberMacVersion
        self.macOS = macOS
        self.architecture = architecture
        self.gameFound = gameFound
        self.storefront = storefront
        self.gameAppPath = gameAppPath
        self.executableExists = executableExists
        self.dataPathExists = dataPathExists
        self.cyberMacHome = cyberMacHome
        self.redscriptRuntime = redscriptRuntime
        self.inputLoaderRuntime = inputLoaderRuntime
        self.launchWorkflow = launchWorkflow
        self.activationState = activationState
        self.bundleChangedSinceLastActivation = bundleChangedSinceLastActivation
        self.activeModIDs = activeModIDs
        self.baseCacheSnapshotID = baseCacheSnapshotID
        self.lastBackupID = lastBackupID
        self.installedManagedMods = installedManagedMods
        self.notes = notes
    }
}
