import Foundation

public enum InputPatchState: String, Codable, Sendable {
    case notRequired
    case required
    case prepared
    case active
    case outOfSync
    case failed
}

public enum InputConfigRole: String, Codable, Sendable {
    case inputContexts
    case inputUserMappings
}

public enum InputPatchVerificationStatus: Codable, Equatable, Sendable {
    case verified
    case hashMismatch(expected: String, actual: String, target: String)
    case expectedPresentButFileMissing(target: String)
    case staleBackup(expectedFingerprint: String, actualFingerprint: String)
}

public struct PendingInputPatch: Codable, Equatable, Sendable {
    public let id: String
    public let createdAt: Date
    public let gameAppPath: String
    public let modIDs: [String]
    public let targetHashes: [String: String]
    public let generatedFiles: [String: String]
    public let backupID: String
    public let sudoCommands: [String]

    public init(id: String, createdAt: Date, gameAppPath: String, modIDs: [String], targetHashes: [String: String], generatedFiles: [String: String], backupID: String, sudoCommands: [String]) {
        self.id = id
        self.createdAt = createdAt
        self.gameAppPath = gameAppPath
        self.modIDs = modIDs
        self.targetHashes = targetHashes
        self.generatedFiles = generatedFiles
        self.backupID = backupID
        self.sudoCommands = sudoCommands
    }
}

public struct ExtractedInputMapping: Codable, Sendable {
    public let modID: String
    public let sourcePath: String
    public let actionNames: [String]
    public let mappingNames: [String]
    public let actionMappingsXML: String
    public let holdTimeoutsXML: String
    public let acceptedEventsXML: String
    public let keyMappingsXML: String

    public init(modID: String, sourcePath: String, actionNames: [String], mappingNames: [String], actionMappingsXML: String, holdTimeoutsXML: String, acceptedEventsXML: String, keyMappingsXML: String) {
        self.modID = modID
        self.sourcePath = sourcePath
        self.actionNames = actionNames
        self.mappingNames = mappingNames
        self.actionMappingsXML = actionMappingsXML
        self.holdTimeoutsXML = holdTimeoutsXML
        self.acceptedEventsXML = acceptedEventsXML
        self.keyMappingsXML = keyMappingsXML
    }
}

public struct InputPatchPrepareResult: Codable, Sendable {
    public let patchID: String
    public let modIDs: [String]
    public let generatedContextPath: String
    public let generatedUserMappingsPath: String
    public let backupID: String
    public let expectedHashes: [String: String]
    public let sudoCommands: [String]
    public let verifyCommand: String

    public init(patchID: String, modIDs: [String], generatedContextPath: String, generatedUserMappingsPath: String, backupID: String, expectedHashes: [String: String], sudoCommands: [String], verifyCommand: String) {
        self.patchID = patchID
        self.modIDs = modIDs
        self.generatedContextPath = generatedContextPath
        self.generatedUserMappingsPath = generatedUserMappingsPath
        self.backupID = backupID
        self.expectedHashes = expectedHashes
        self.sudoCommands = sudoCommands
        self.verifyCommand = verifyCommand
    }
}

public struct InputPatchVerifyResult: Codable, Sendable {
    public let patchID: String
    public let matched: Bool
    public let expectedHashes: [String: String]
    public let actualHashes: [String: String]
    public let mismatches: [String]

    public init(patchID: String, matched: Bool, expectedHashes: [String: String], actualHashes: [String: String], mismatches: [String]) {
        self.patchID = patchID
        self.matched = matched
        self.expectedHashes = expectedHashes
        self.actualHashes = actualHashes
        self.mismatches = mismatches
    }
}

public struct InputPatchStatus: Codable, Sendable {
    public let requiredMods: [InstalledModManifest]
    public let pendingInputPatch: PendingInputPatch?
    public let activeInputPatchModIDs: [String]
    public let activeInputTargetHashes: [String: String]
    public let targetInputContextsPath: String?
    public let targetInputUserMappingsPath: String?
    public let nextStep: String

    public var requiredModCount: Int { requiredMods.count }

    public init(requiredMods: [InstalledModManifest], pendingInputPatch: PendingInputPatch?, activeInputPatchModIDs: [String], activeInputTargetHashes: [String: String], targetInputContextsPath: String?, targetInputUserMappingsPath: String?, nextStep: String) {
        self.requiredMods = requiredMods
        self.pendingInputPatch = pendingInputPatch
        self.activeInputPatchModIDs = activeInputPatchModIDs
        self.activeInputTargetHashes = activeInputTargetHashes
        self.targetInputContextsPath = targetInputContextsPath
        self.targetInputUserMappingsPath = targetInputUserMappingsPath
        self.nextStep = nextStep
    }
}

public struct InputConfigBackupManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let createdAt: Date
    public let gameAppPath: String
    public let gameFingerprintID: String
    public let files: [InputConfigBackupFile]
    public let modIDs: [String]

    public init(schemaVersion: Int = 1, id: String, createdAt: Date, gameAppPath: String, gameFingerprintID: String, files: [InputConfigBackupFile], modIDs: [String]) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.gameAppPath = gameAppPath
        self.gameFingerprintID = gameFingerprintID
        self.files = files
        self.modIDs = modIDs
    }
}

public struct InputConfigBackupFile: Codable, Equatable, Sendable {
    public let role: InputConfigRole
    public let bundlePath: String
    public let backupPath: String?
    public let priorState: PriorFileState
    public let sha256: String?
    public let sizeBytes: UInt64?

    public init(role: InputConfigRole, bundlePath: String, backupPath: String?, priorState: PriorFileState, sha256: String?, sizeBytes: UInt64?) {
        self.role = role
        self.bundlePath = bundlePath
        self.backupPath = backupPath
        self.priorState = priorState
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

public struct InputConfigRestoreVerificationResult: Codable, Equatable, Sendable {
    public let backupID: String
    public let matched: Bool
    public let fileResults: [InputConfigRestoreFileVerification]
    public let restoreCommands: [String]
    public let verifyCommand: String

    public init(backupID: String, matched: Bool, fileResults: [InputConfigRestoreFileVerification], restoreCommands: [String], verifyCommand: String) {
        self.backupID = backupID
        self.matched = matched
        self.fileResults = fileResults
        self.restoreCommands = restoreCommands
        self.verifyCommand = verifyCommand
    }
}

public struct InputConfigRestoreFileVerification: Codable, Equatable, Sendable {
    public let role: InputConfigRole
    public let target: String
    public let status: RestoreVerificationStatus

    public init(role: InputConfigRole, target: String, status: RestoreVerificationStatus) {
        self.role = role
        self.target = target
        self.status = status
    }
}
