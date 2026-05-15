import Foundation

public enum InstalledModStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case uninstalled
}

public enum ModKind: String, Codable, Sendable {
    case redscript
    case redscriptInput
    case archiveOnly
    case frameworkStack
    case mixed
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "redscript":
            self = .redscript
        case "redscriptInput":
            self = .redscriptInput
        case "archive", "archiveOnly":
            self = .archiveOnly
        case "frameworkStack":
            self = .frameworkStack
        case "mixed":
            self = .mixed
        default:
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ModDependencyMarkers: Codable, Sendable, Equatable {
    public var hasArchiveFiles: Bool
    public var hasArchiveXL: Bool
    public var hasTweakXL: Bool
    public var hasRED4ext: Bool
    public var hasCodeware: Bool
    public var hasCET: Bool
    public var hasEquipmentEX: Bool
    public var hasREDmod: Bool
    public var hasNativePlugin: Bool
    public var hasArchivePCModPath: Bool
    public var hasArchivePCContentPath: Bool
    public var hasArchiveMacModPath: Bool
    public var hasArchiveMacContentPath: Bool
    public var hasInputMappingXML: Bool

    public init(
        hasArchiveFiles: Bool = false,
        hasArchiveXL: Bool = false,
        hasTweakXL: Bool = false,
        hasRED4ext: Bool = false,
        hasCodeware: Bool = false,
        hasCET: Bool = false,
        hasEquipmentEX: Bool = false,
        hasREDmod: Bool = false,
        hasNativePlugin: Bool = false,
        hasArchivePCModPath: Bool = false,
        hasArchivePCContentPath: Bool = false,
        hasArchiveMacModPath: Bool = false,
        hasArchiveMacContentPath: Bool = false,
        hasInputMappingXML: Bool = false
    ) {
        self.hasArchiveFiles = hasArchiveFiles
        self.hasArchiveXL = hasArchiveXL
        self.hasTweakXL = hasTweakXL
        self.hasRED4ext = hasRED4ext
        self.hasCodeware = hasCodeware
        self.hasCET = hasCET
        self.hasEquipmentEX = hasEquipmentEX
        self.hasREDmod = hasREDmod
        self.hasNativePlugin = hasNativePlugin
        self.hasArchivePCModPath = hasArchivePCModPath
        self.hasArchivePCContentPath = hasArchivePCContentPath
        self.hasArchiveMacModPath = hasArchiveMacModPath
        self.hasArchiveMacContentPath = hasArchiveMacContentPath
        self.hasInputMappingXML = hasInputMappingXML
    }
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
    public let inputMappingEntries: [String]
    public let dependencyMarkers: ModDependencyMarkers
    public let requiresInputMappingPatch: Bool
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
        inputMappingEntries: [String] = [],
        dependencyMarkers: ModDependencyMarkers = ModDependencyMarkers(),
        requiresInputMappingPatch: Bool = false,
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
        self.inputMappingEntries = inputMappingEntries
        self.dependencyMarkers = dependencyMarkers
        self.requiresInputMappingPatch = requiresInputMappingPatch
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
    public var displayName: String
    public let type: ModKind
    public var status: InstalledModStatus
    public let sourceArchive: String
    public let installedAt: Date
    public let gameAppPath: String
    public let installMode: String
    public var installedFiles: [InstalledFileRecord]
    public let inputMappingFiles: [InstalledFileRecord]
    public var inputPatchState: InputPatchState
    public let requiresInputMappingPatch: Bool
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
        inputMappingFiles: [InstalledFileRecord] = [],
        inputPatchState: InputPatchState = .notRequired,
        requiresInputMappingPatch: Bool = false,
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
        self.inputMappingFiles = inputMappingFiles
        self.inputPatchState = inputPatchState
        self.requiresInputMappingPatch = requiresInputMappingPatch
        self.detectedDependencies = detectedDependencies
        self.compatibilityStatus = compatibilityStatus
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case displayName
        case type
        case status
        case sourceArchive
        case installedAt
        case gameAppPath
        case installMode
        case installedFiles
        case inputMappingFiles
        case inputPatchState
        case requiresInputMappingPatch
        case detectedDependencies
        case compatibilityStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.type = try container.decodeIfPresent(ModKind.self, forKey: .type) ?? .unknown
        self.status = try container.decodeIfPresent(InstalledModStatus.self, forKey: .status) ?? .enabled
        self.sourceArchive = try container.decode(String.self, forKey: .sourceArchive)
        self.installedAt = try container.decodeIfPresent(Date.self, forKey: .installedAt) ?? Date(timeIntervalSince1970: 0)
        self.gameAppPath = try container.decodeIfPresent(String.self, forKey: .gameAppPath) ?? ""
        self.installMode = try container.decodeIfPresent(String.self, forKey: .installMode) ?? "sidecar_overlay"
        self.installedFiles = try container.decodeIfPresent([InstalledFileRecord].self, forKey: .installedFiles) ?? []
        self.inputMappingFiles = try container.decodeIfPresent([InstalledFileRecord].self, forKey: .inputMappingFiles) ?? []
        self.inputPatchState = try container.decodeIfPresent(InputPatchState.self, forKey: .inputPatchState) ?? .notRequired
        self.requiresInputMappingPatch = try container.decodeIfPresent(Bool.self, forKey: .requiresInputMappingPatch) ?? false
        self.detectedDependencies = try container.decodeIfPresent([String].self, forKey: .detectedDependencies) ?? []
        self.compatibilityStatus = try container.decodeIfPresent(CompatibilityStatus.self, forKey: .compatibilityStatus) ?? .untested
    }
}
