import Foundation

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
    public let inputMappings: InputPatchStatus?
    public let warnings: [DoctorWarning]
    public let legacyProbe: LegacyProbeSummary?

    public init(game: GameInstallSummary, runtime: RuntimeSummary, cache: CacheSummary, activation: ActivationSummary, inputMappings: InputPatchStatus? = nil, warnings: [DoctorWarning], legacyProbe: LegacyProbeSummary?) {
        self.game = game
        self.runtime = runtime
        self.cache = cache
        self.activation = activation
        self.inputMappings = inputMappings
        self.warnings = warnings
        self.legacyProbe = legacyProbe
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
    public let inputPatchRequiredMods: Int
    public let pendingInputPatchID: String?
    public let activeInputPatchModIDs: [String]
    public let lastInputBackupID: String?
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
        inputPatchRequiredMods: Int = 0,
        pendingInputPatchID: String? = nil,
        activeInputPatchModIDs: [String] = [],
        lastInputBackupID: String? = nil,
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
        self.inputPatchRequiredMods = inputPatchRequiredMods
        self.pendingInputPatchID = pendingInputPatchID
        self.activeInputPatchModIDs = activeInputPatchModIDs
        self.lastInputBackupID = lastInputBackupID
        self.installedManagedMods = installedManagedMods
        self.notes = notes
    }
}
