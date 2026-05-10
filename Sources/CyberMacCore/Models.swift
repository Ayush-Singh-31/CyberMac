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
    public let quarantinedPaths: [URL]
    public let notes: [String]

    public init(kind: RuntimeKind, rootURL: URL, installed: Bool, toolURL: URL?, quarantinedPaths: [URL], notes: [String]) {
        self.kind = kind
        self.rootURL = rootURL
        self.installed = installed
        self.toolURL = toolURL
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
        self.kind = kind
        self.reasons = reasons
        self.findings = findings
        self.redscriptEntries = redscriptEntries
        self.archiveEntries = archiveEntries
        self.allEntries = allEntries
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
        self.installedManagedMods = installedManagedMods
        self.notes = notes
    }
}
