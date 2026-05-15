import Foundation

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
