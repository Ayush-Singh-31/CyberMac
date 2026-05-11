import Foundation

public struct InputConfigBackupManager: Sendable {
    private let home: CyberMacHomeManager
    private let baseCacheManager: BaseCacheManager
    private let manifestStore: ManifestStore
    private let stateStore: StateStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.baseCacheManager = BaseCacheManager(home: home)
        self.manifestStore = ManifestStore(home: home)
        self.stateStore = StateStore(home: home)
    }

    public func backup(gameInstall: GameInstall, modIDs: [String]) throws -> InputConfigBackupManifest {
        try home.bootstrap()
        let id = try uniqueBackupID()
        let directory = backupDirectory(id: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fingerprint = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        let targets: [(InputConfigRole, URL, String)] = [
            (.inputContexts, inputContextsTarget(gameInstall: gameInstall), "inputContexts_mac.xml"),
            (.inputUserMappings, inputUserMappingsTarget(gameInstall: gameInstall), "inputUserMappings.xml")
        ]
        let files = try targets.map { role, target, backupName in
            let backupURL = directory.appendingPathComponent(backupName)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.copyItem(at: target, to: backupURL)
                return InputConfigBackupFile(
                    role: role,
                    bundlePath: target.path,
                    backupPath: backupURL.path,
                    priorState: .present,
                    sha256: try PathSafety.sha256(url: target),
                    sizeBytes: try PathSafety.fileSize(url: target)
                )
            }
            return InputConfigBackupFile(
                role: role,
                bundlePath: target.path,
                backupPath: nil,
                priorState: .absent,
                sha256: nil,
                sizeBytes: nil
            )
        }

        let manifest = InputConfigBackupManifest(
            id: id,
            createdAt: Date(),
            gameAppPath: gameInstall.appURL.path,
            gameFingerprintID: fingerprint.id,
            files: files,
            modIDs: modIDs.sorted()
        )
        try save(manifest)
        return manifest
    }

    public func list() throws -> [InputConfigBackupManifest] {
        guard FileManager.default.fileExists(atPath: home.inputPatchBackupsURL.path) else { return [] }
        let directories = try FileManager.default.contentsOfDirectory(
            at: home.inputPatchBackupsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try directories.compactMap { directory in
            let metadataURL = directory.appendingPathComponent("backup-manifest.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
            return try JSONDecoder.cybermac.decode(InputConfigBackupManifest.self, from: Data(contentsOf: metadataURL))
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public func load(id: String) throws -> InputConfigBackupManifest {
        let url = backupDirectory(id: id).appendingPathComponent("backup-manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Input config backup not found: \(id)")
        }
        return try JSONDecoder.cybermac.decode(InputConfigBackupManifest.self, from: Data(contentsOf: url))
    }

    public func restoreCommands(id: String, gameInstall: GameInstall?) throws -> [String] {
        let manifest = try load(id: id)
        try validateCurrentFingerprintIfNeeded(manifest: manifest, gameInstall: gameInstall)
        return try restoreCommands(manifest: manifest)
    }

    public func verifyRestore(id: String, gameInstall: GameInstall?) throws -> InputConfigRestoreVerificationResult {
        let manifest = try load(id: id)
        let commands = try restoreCommands(manifest: manifest)
        let verifyCommand = "swift run cybermac restore-input-config --verify \(id)"

        if let gameInstall {
            let current = try baseCacheManager.fingerprint(gameInstall: gameInstall)
            if current.id != manifest.gameFingerprintID {
                let fileResults = manifest.files.map { file in
                    InputConfigRestoreFileVerification(
                        role: file.role,
                        target: file.bundlePath,
                        status: .staleBackup(expectedFingerprint: manifest.gameFingerprintID, actualFingerprint: current.id)
                    )
                }
                return InputConfigRestoreVerificationResult(
                    backupID: id,
                    matched: false,
                    fileResults: fileResults,
                    restoreCommands: commands,
                    verifyCommand: verifyCommand
                )
            }
        }

        let fileResults = try manifest.files.map { file in
            let targetURL = URL(fileURLWithPath: file.bundlePath)
            switch file.priorState {
            case .absent:
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    return InputConfigRestoreFileVerification(
                        role: file.role,
                        target: file.bundlePath,
                        status: .expectedAbsentButFileExists(target: targetURL.path, actualHash: try PathSafety.sha256(url: targetURL))
                    )
                }
                return InputConfigRestoreFileVerification(
                    role: file.role,
                    target: file.bundlePath,
                    status: .verified(target: targetURL.path)
                )
            case .present:
                guard FileManager.default.fileExists(atPath: targetURL.path) else {
                    return InputConfigRestoreFileVerification(
                        role: file.role,
                        target: file.bundlePath,
                        status: .expectedPresentButFileMissing(target: targetURL.path)
                    )
                }
                guard let expected = file.sha256 else {
                    throw CyberMacError.fileSystem("Backup \(id) prior state is present but no expected input config hash was recorded.")
                }
                let actual = try PathSafety.sha256(url: targetURL)
                guard actual == expected else {
                    return InputConfigRestoreFileVerification(
                        role: file.role,
                        target: file.bundlePath,
                        status: .hashMismatch(expected: expected, actual: actual, target: targetURL.path)
                    )
                }
                return InputConfigRestoreFileVerification(
                    role: file.role,
                    target: file.bundlePath,
                    status: .verified(target: targetURL.path)
                )
            }
        }

        let matched = fileResults.allSatisfy { result in
            if case .verified = result.status { return true }
            return false
        }
        if matched, gameInstall != nil {
            try clearInputPatchStateAfterRestore()
        }

        return InputConfigRestoreVerificationResult(
            backupID: id,
            matched: matched,
            fileResults: fileResults,
            restoreCommands: commands,
            verifyCommand: verifyCommand
        )
    }

    public func backupDirectory(id: String) -> URL {
        home.inputPatchBackupsURL.appendingPathComponent(id, isDirectory: true)
    }

    private func inputContextsTarget(gameInstall: GameInstall) -> URL {
        let macURL = gameInstall.dataURL.appendingPathComponent("r6/config/inputContexts_mac.xml")
        if FileManager.default.fileExists(atPath: macURL.path) {
            return macURL
        }
        return gameInstall.dataURL.appendingPathComponent("r6/config/inputContexts.xml")
    }

    private func inputUserMappingsTarget(gameInstall: GameInstall) -> URL {
        gameInstall.dataURL.appendingPathComponent("r6/config/inputUserMappings.xml")
    }

    private func save(_ manifest: InputConfigBackupManifest) throws {
        let directory = backupDirectory(id: manifest.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.cybermac.encode(manifest)
        try data.write(to: directory.appendingPathComponent("backup-manifest.json"), options: [.atomic])
    }

    private func restoreCommands(manifest: InputConfigBackupManifest) throws -> [String] {
        try manifest.files.map { file in
            switch file.priorState {
            case .present:
                guard let backupPath = file.backupPath else {
                    throw CyberMacError.fileSystem("Backup \(manifest.id) has a present input config record without a backup path.")
                }
                return "sudo cp \(PathSafety.shellDoubleQuoted(backupPath)) \(PathSafety.shellDoubleQuoted(file.bundlePath))"
            case .absent:
                return "sudo rm -f \(PathSafety.shellDoubleQuoted(file.bundlePath))"
            }
        }
    }

    private func uniqueBackupID() throws -> String {
        let base = Self.makeID()
        if !FileManager.default.fileExists(atPath: backupDirectory(id: base).path) {
            return base
        }
        return "\(base)-\(UUID().uuidString.prefix(8))"
    }

    private func validateCurrentFingerprintIfNeeded(manifest: InputConfigBackupManifest, gameInstall: GameInstall?) throws {
        guard let gameInstall else { return }
        let current = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        guard current.id == manifest.gameFingerprintID else {
            throw CyberMacError.unsupported("Input config backup \(manifest.id) belongs to a different game fingerprint and is stale for the current bundle.")
        }
    }

    private func clearInputPatchStateAfterRestore() throws {
        var state = stateStore.load()
        state.pendingInputPatch = nil
        state.activeInputPatchModIDs = []
        state.activeInputTargetHashes = [:]
        try stateStore.save(state)

        let manifests = try manifestStore.list()
        for var manifest in manifests where manifest.requiresInputMappingPatch {
            manifest.inputPatchState = manifest.status == .enabled ? .required : .outOfSync
            try manifestStore.save(manifest)
        }
    }

    private static func makeID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return "input-\(formatter.string(from: date))"
    }
}
