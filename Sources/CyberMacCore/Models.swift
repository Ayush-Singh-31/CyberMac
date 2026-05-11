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

public struct GameInstallSummary: Codable, Sendable {
    public let found: Bool
    public let edition: String?
    public let storefront: String
    public let appPath: String?
    public let dataPath: String?
    public let bundleTarget: String?
    public let executableFound: Bool
    public let dataPathFound: Bool

    public init(found: Bool, edition: String?, storefront: String, appPath: String?, dataPath: String?, bundleTarget: String?, executableFound: Bool, dataPathFound: Bool) {
        self.found = found
        self.edition = edition
        self.storefront = storefront
        self.appPath = appPath
        self.dataPath = dataPath
        self.bundleTarget = bundleTarget
        self.executableFound = executableFound
        self.dataPathFound = dataPathFound
    }
}

public struct RuntimeToolSummary: Codable, Sendable {
    public let installed: Bool
    public let toolFound: Bool
    public let version: String?
    public let rootPath: String
    public let toolPath: String?
    public let quarantinedPathCount: Int
    public let notes: [String]

    public init(installed: Bool, toolFound: Bool, version: String?, rootPath: String, toolPath: String?, quarantinedPathCount: Int, notes: [String]) {
        self.installed = installed
        self.toolFound = toolFound
        self.version = version
        self.rootPath = rootPath
        self.toolPath = toolPath
        self.quarantinedPathCount = quarantinedPathCount
        self.notes = notes
    }
}

public struct RuntimeSummary: Codable, Sendable {
    public let redscript: RuntimeToolSummary
    public let inputLoader: RuntimeToolSummary

    public var ready: Bool {
        redscript.installed && inputLoader.installed &&
            redscript.quarantinedPathCount == 0 &&
            inputLoader.quarantinedPathCount == 0
    }

    public init(redscript: RuntimeToolSummary, inputLoader: RuntimeToolSummary) {
        self.redscript = redscript
        self.inputLoader = inputLoader
    }
}

public struct CacheSummary: Codable, Sendable {
    public let baseSnapshotPresent: Bool
    public let currentBundle: BundleCacheKind
    public let bundleTarget: String?
    public let bundleCacheSHA256: String?
    public let baseSnapshotSHA256: String?
    public let overlayMirrorPresent: Bool

    public init(baseSnapshotPresent: Bool, currentBundle: BundleCacheKind, bundleTarget: String?, bundleCacheSHA256: String?, baseSnapshotSHA256: String?, overlayMirrorPresent: Bool) {
        self.baseSnapshotPresent = baseSnapshotPresent
        self.currentBundle = currentBundle
        self.bundleTarget = bundleTarget
        self.bundleCacheSHA256 = bundleCacheSHA256
        self.baseSnapshotSHA256 = baseSnapshotSHA256
        self.overlayMirrorPresent = overlayMirrorPresent
    }
}

public struct ActivationSummary: Codable, Sendable {
    public let state: ActivationState
    public let enabledMods: Int
    public let activeModIDs: [String]
    public let bundleChangedSinceLastActivation: Bool
    public let manualPrivilegedWriteRequired: Bool
    public let safeToProceedToActivation: Bool
    public let nextStep: String

    public init(state: ActivationState, enabledMods: Int, activeModIDs: [String], bundleChangedSinceLastActivation: Bool, manualPrivilegedWriteRequired: Bool, safeToProceedToActivation: Bool, nextStep: String) {
        self.state = state
        self.enabledMods = enabledMods
        self.activeModIDs = activeModIDs
        self.bundleChangedSinceLastActivation = bundleChangedSinceLastActivation
        self.manualPrivilegedWriteRequired = manualPrivilegedWriteRequired
        self.safeToProceedToActivation = safeToProceedToActivation
        self.nextStep = nextStep
    }
}

public struct DoctorWarning: Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct LegacyProbeSummary: Codable, Sendable {
    public let sidecarOnlyLaunchProbeEnabled: Bool
    public let state: String
    public let message: String
    public let reason: String

    public init(sidecarOnlyLaunchProbeEnabled: Bool, state: String, message: String, reason: String) {
        self.sidecarOnlyLaunchProbeEnabled = sidecarOnlyLaunchProbeEnabled
        self.state = state
        self.message = message
        self.reason = reason
    }
}

public struct DoctorReport: Codable, Sendable {
    public let game: GameInstallSummary
    public let runtime: RuntimeSummary
    public let cache: CacheSummary
    public let activation: ActivationSummary
    public let warnings: [DoctorWarning]
    public let legacyProbe: LegacyProbeSummary?

    public init(game: GameInstallSummary, runtime: RuntimeSummary, cache: CacheSummary, activation: ActivationSummary, warnings: [DoctorWarning], legacyProbe: LegacyProbeSummary?) {
        self.game = game
        self.runtime = runtime
        self.cache = cache
        self.activation = activation
        self.warnings = warnings
        self.legacyProbe = legacyProbe
    }
}

public enum RestoreVerificationStatus: Codable, Equatable, Sendable {
    case verified(target: String)
    case hashMismatch(expected: String, actual: String, target: String)
    case expectedAbsentButFileExists(target: String, actualHash: String)
    case expectedPresentButFileMissing(target: String)
    case staleBackup(expectedFingerprint: String, actualFingerprint: String)
}

public struct RestoreVerificationResult: Codable, Equatable, Sendable {
    public let backupID: String
    public let status: RestoreVerificationStatus
    public let restoreCommand: String
    public let verifyCommand: String

    public init(backupID: String, status: RestoreVerificationStatus, restoreCommand: String, verifyCommand: String) {
        self.backupID = backupID
        self.status = status
        self.restoreCommand = restoreCommand
        self.verifyCommand = verifyCommand
    }
}

public enum LaunchPolicy: String, Codable, Sendable {
    case `default`
    case vanillaOK
    case requireActive
}

public struct LaunchGamePlan: Codable, Sendable {
    public let appURL: URL
    public let bundleKind: BundleCacheKind
    public let activationState: ActivationState
    public let enabledMods: [InstalledModManifest]
    public let commandPreview: String
    public let warnings: [String]
    public let canLaunch: Bool
    public let refusalReason: String?

    public init(appURL: URL, bundleKind: BundleCacheKind, activationState: ActivationState, enabledMods: [InstalledModManifest], commandPreview: String, warnings: [String], canLaunch: Bool, refusalReason: String?) {
        self.appURL = appURL
        self.bundleKind = bundleKind
        self.activationState = activationState
        self.enabledMods = enabledMods
        self.commandPreview = commandPreview
        self.warnings = warnings
        self.canLaunch = canLaunch
        self.refusalReason = refusalReason
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
