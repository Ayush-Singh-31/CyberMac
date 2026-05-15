import Foundation

public struct ActivationDryRunResult: Sendable {
    public let gameAppPath: String
    public let bundleTarget: String
    public let baseSnapshotID: String
    public let enabledModIDs: [String]
    public let compileCommand: String
    public let tempOutputPath: String
    public let backupDestination: String
    public let sudoCommandShape: String
}

public struct ActivationBundleModeResult: Sendable {
    public let bundleTarget: String
    public let tempOutputPath: String
    public let generatedSHA256: String
    public let backup: BundleBackupManifest
    public let compileCommand: String
    public let sudoCommand: String
    public let verifyCommand: String
}

public struct ActivationVerifyResult: Sendable {
    public let matched: Bool
    public let bundleTarget: String
    public let expectedSHA256: String?
    public let actualSHA256: String?
}

public struct ActivationManager: Sendable {
    private let home: CyberMacHomeManager
    private let baseCacheManager: BaseCacheManager
    private let backupManager: BundleBackupManager
    private let compiler: ActivationCompiler
    private let manifestStore: ManifestStore
    private let stateStore: StateStore
    private let fingerprintCache: FingerprintCacheStore
    private let bundleStateResolver: BundleStateResolver

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.baseCacheManager = BaseCacheManager(home: home)
        self.backupManager = BundleBackupManager(home: home)
        self.compiler = ActivationCompiler(home: home)
        self.manifestStore = ManifestStore(home: home)
        self.stateStore = StateStore(home: home)
        self.fingerprintCache = FingerprintCacheStore(home: home)
        self.bundleStateResolver = BundleStateResolver(home: home)
    }

    public func dryRun(gameInstall: GameInstall) throws -> ActivationDryRunResult {
        try home.bootstrap()
        try refuseIfBundleChanged(gameInstall: gameInstall)
        try preflightStorage()
        let snapshot = try currentSnapshot(gameInstall: gameInstall)
        let outputURL = activationOutputURL()
        let bundleTarget = baseCacheManager.bundleCacheURL(gameInstall: gameInstall)
        let backupDestination = home.backupsURL.appendingPathComponent(Self.makeID(), isDirectory: true)
        return ActivationDryRunResult(
            gameAppPath: gameInstall.appURL.path,
            bundleTarget: bundleTarget.path,
            baseSnapshotID: snapshot.snapshotID,
            enabledModIDs: try enabledModIDs(),
            compileCommand: try compiler.commandDescription(outputURL: outputURL),
            tempOutputPath: outputURL.path,
            backupDestination: backupDestination.path,
            sudoCommandShape: sudoCopyCommand(source: outputURL, target: bundleTarget)
        )
    }

    public func activateBundleMode(gameInstall: GameInstall) throws -> ActivationBundleModeResult {
        try home.bootstrap()
        try refuseIfBundleChanged(gameInstall: gameInstall)
        try preflightStorage()
        let fingerprint = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        let snapshot = try currentSnapshot(gameInstall: gameInstall)
        _ = try baseCacheManager.copySnapshotToOverlay(snapshotID: snapshot.snapshotID)

        let outputURL = activationOutputURL()
        do {
            _ = try compiler.compile(outputURL: outputURL)
        } catch CyberMacError.processTimedOut {
            throw CyberMacError.processFailed(command: try compiler.commandDescription(outputURL: outputURL), exitCode: -1, stderr: ActivationCompiler.timeoutMessage)
        }

        let generatedSHA = try PathSafety.sha256(url: outputURL)
        let backup = try backupManager.backup(gameInstall: gameInstall, fingerprintID: fingerprint.id)
        let bundleTarget = baseCacheManager.bundleCacheURL(gameInstall: gameInstall)
        let expectedHashes = [bundleTarget.path: generatedSHA]
        let modIDs = try enabledModIDs()

        var state = stateStore.load()
        state.activationState = .outOfSync
        state.bundleChangedSinceLastActivation = false
        state.pendingExpectedHashes = expectedHashes
        state.pendingActivation = PendingActivation(
            createdAt: Date(),
            gameAppPath: gameInstall.appURL.path,
            bundleTarget: bundleTarget.path,
            tempOutputPath: outputURL.path,
            backupID: backup.id,
            baseCacheSnapshotID: snapshot.snapshotID,
            activeModIDs: modIDs,
            expectedHashes: expectedHashes
        )
        state.baseCacheSnapshotID = snapshot.snapshotID
        state.lastBackupID = backup.id
        try stateStore.save(state)

        return ActivationBundleModeResult(
            bundleTarget: bundleTarget.path,
            tempOutputPath: outputURL.path,
            generatedSHA256: generatedSHA,
            backup: backup,
            compileCommand: try compiler.commandDescription(outputURL: outputURL),
            sudoCommand: sudoCopyCommand(source: outputURL, target: bundleTarget),
            verifyCommand: "swift run cybermac activate --verify"
        )
    }

    public func verify(gameInstall: GameInstall) throws -> ActivationVerifyResult {
        var state = stateStore.load()
        guard let pending = state.pendingActivation else {
            throw CyberMacError.invalidInput("No pending activation exists. Run `cybermac activate --bundle-mode` first.")
        }
        let bundleTarget = baseCacheManager.bundleCacheURL(gameInstall: gameInstall)
        let expected = pending.expectedHashes[bundleTarget.path]
        guard let expected else {
            throw CyberMacError.invalidInput("Pending activation does not contain expected hash for \(bundleTarget.path)")
        }
        guard FileManager.default.fileExists(atPath: bundleTarget.path) else {
            state.activationState = .outOfSync
            try stateStore.save(state)
            return ActivationVerifyResult(matched: false, bundleTarget: bundleTarget.path, expectedSHA256: expected, actualSHA256: nil)
        }

        let actual = try fingerprintCache.sha256(url: bundleTarget)
        guard actual == expected else {
            state.activationState = .outOfSync
            try stateStore.save(state)
            return ActivationVerifyResult(matched: false, bundleTarget: bundleTarget.path, expectedSHA256: expected, actualSHA256: actual)
        }

        state.activationState = .active
        state.bundleChangedSinceLastActivation = false
        state.activeModIDs = pending.activeModIDs
        state.pendingExpectedHashes = [:]
        state.activeBundleTargetHashes = pending.expectedHashes
        state.baseCacheSnapshotID = pending.baseCacheSnapshotID
        state.lastBackupID = pending.backupID
        state.pendingActivation = nil
        try stateStore.save(state)
        return ActivationVerifyResult(matched: true, bundleTarget: bundleTarget.path, expectedSHA256: expected, actualSHA256: actual)
    }

    public func updateBundleChangedFlag(gameInstall: GameInstall) throws -> CyberMacState {
        try reconcileBundleState(gameInstall: gameInstall)
    }

    public func reconcileBundleState(gameInstall: GameInstall) throws -> CyberMacState {
        _ = try bundleStateResolver.snapshot(gameInstall: gameInstall)
        return stateStore.load()
    }

    private func currentSnapshot(gameInstall: GameInstall) throws -> BaseCacheSnapshotMetadata {
        let fingerprint = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        do {
            return try baseCacheManager.loadSnapshot(id: fingerprint.id)
        } catch {
            throw CyberMacError.notFound("Base cache snapshot missing for this game version. Run `cybermac refresh-base-cache` first.")
        }
    }

    private func enabledModIDs() throws -> [String] {
        try manifestStore.list()
            .filter { $0.status == .enabled }
            .map(\.id)
            .sorted()
    }

    private func activationOutputURL(date: Date = Date()) -> URL {
        home.tmpURL
            .appendingPathComponent("activation-\(Self.makeID(date: date))", isDirectory: true)
            .appendingPathComponent("final.redscripts")
    }

    private func sudoCopyCommand(source: URL, target: URL) -> String {
        "sudo cp \(PathSafety.shellDoubleQuoted(source.path)) \(PathSafety.shellDoubleQuoted(target.path))"
    }

    private func preflightStorage() throws {
        for directory in [home.tmpURL, home.backupsURL, home.overlayCacheURL] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard FileManager.default.isWritableFile(atPath: directory.path) else {
                throw CyberMacError.fileSystem("Activation directory is not writable: \(directory.path)")
            }
        }
        let values = try home.homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage, available < 128 * 1024 * 1024 {
            throw CyberMacError.fileSystem("Less than 128 MB is available under CyberMac home; activation needs space for cache output and backup.")
        }
    }

    private func refuseIfBundleChanged(gameInstall: GameInstall) throws {
        let snapshot = try bundleStateResolver.snapshot(gameInstall: gameInstall)
        if snapshot.activationBlocked {
            switch snapshot.bundle.kind {
            case .missing:
                throw CyberMacError.unsupported("Bundle final.redscripts is missing. Restore a backup or inspect manually before activation.")
            case .externallyChanged:
                throw CyberMacError.unsupported("Bundle final.redscripts does not match the base snapshot or the last CyberMac activation. Restore vanilla, refresh base cache only after confirming a game update, or inspect manually before activation.")
            case .vanilla, .cyberMacActive:
                break
            }
        }
    }

    private static func makeID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone.current
        return "\(formatter.string(from: date))-\(UUID().uuidString.prefix(8))"
    }
}
