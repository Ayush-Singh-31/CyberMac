import Foundation

public struct BaseCacheStatus: Sendable {
    public let fingerprint: GameBundleFingerprint
    public let bundleCacheURL: URL
    public let bundleCacheSHA256: String
    public let snapshot: BaseCacheSnapshotMetadata?
    public let mirrorExists: Bool
    public let refusedRefreshReason: String?
}

public struct BaseCacheRefreshResult: Sendable {
    public let dryRun: Bool
    public let snapshotID: String
    public let snapshotURL: URL
    public let metadata: BaseCacheSnapshotMetadata
    public let didWrite: Bool
}

public struct BaseCacheManager: Sendable {
    private let home: CyberMacHomeManager
    private let stateStore: StateStore
    private let fingerprintCache: FingerprintCacheStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.stateStore = StateStore(home: home)
        self.fingerprintCache = FingerprintCacheStore(home: home)
    }

    public func bundleCacheURL(gameInstall: GameInstall) -> URL {
        gameInstall.dataURL.appendingPathComponent("r6/cache/final.redscripts")
    }

    public func fingerprint(gameInstall: GameInstall) throws -> GameBundleFingerprint {
        let info = try readBundleInfo(appURL: gameInstall.appURL)
        let receiptURL = gameInstall.appURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        let receiptSHA = FileManager.default.fileExists(atPath: receiptURL.path) ? try PathSafety.sha256(url: receiptURL) : "missing"
        let executableSHA = try PathSafety.sha256(url: gameInstall.executableURL)
        let material = [
            info.bundleIdentifier,
            info.shortVersion,
            info.bundleVersion,
            gameInstall.appURL.path,
            executableSHA,
            receiptSHA
        ].joined(separator: "|")
        let id = PathSafety.sha256(string: material)
        return GameBundleFingerprint(
            id: id,
            bundleIdentifier: info.bundleIdentifier,
            bundleShortVersion: info.shortVersion,
            bundleVersion: info.bundleVersion,
            appPath: gameInstall.appURL.path,
            executableSHA256: executableSHA,
            receiptSHA256: receiptSHA
        )
    }

    public func status(gameInstall: GameInstall) throws -> BaseCacheStatus {
        let fingerprint = try fingerprint(gameInstall: gameInstall)
        let bundleCacheURL = bundleCacheURL(gameInstall: gameInstall)
        guard FileManager.default.fileExists(atPath: bundleCacheURL.path) else {
            throw CyberMacError.notFound("Bundle final.redscripts was not found: \(bundleCacheURL.path)")
        }
        let bundleSHA = try fingerprintCache.sha256(url: bundleCacheURL)
        let snapshot = try? loadSnapshot(id: fingerprint.id)
        let mirrorURL = home.overlayCacheURL.appendingPathComponent("final.redscripts")
        let state = stateStore.load()
        let refused: String?
        if state.activeBundleTargetHashes[bundleCacheURL.path] == bundleSHA {
            refused = "Current bundle cache appears to be CyberMac-generated. Restore vanilla or confirm game update before refreshing base cache."
        } else {
            refused = nil
        }
        return BaseCacheStatus(
            fingerprint: fingerprint,
            bundleCacheURL: bundleCacheURL,
            bundleCacheSHA256: bundleSHA,
            snapshot: snapshot,
            mirrorExists: FileManager.default.fileExists(atPath: mirrorURL.path),
            refusedRefreshReason: refused
        )
    }

    public func refreshBaseCache(gameInstall: GameInstall, dryRun: Bool) throws -> BaseCacheRefreshResult {
        try home.bootstrap()
        let fingerprint = try fingerprint(gameInstall: gameInstall)
        let bundleCacheURL = bundleCacheURL(gameInstall: gameInstall)
        guard FileManager.default.fileExists(atPath: bundleCacheURL.path) else {
            throw CyberMacError.notFound("Bundle final.redscripts was not found: \(bundleCacheURL.path)")
        }
        let bundleSHA = try fingerprintCache.sha256(url: bundleCacheURL)
        let state = stateStore.load()
        if state.activeBundleTargetHashes[bundleCacheURL.path] == bundleSHA {
            throw CyberMacError.unsupported("Current bundle cache appears to be CyberMac-generated. Restore vanilla or confirm game update before refreshing base cache.")
        }

        let size = try PathSafety.fileSize(url: bundleCacheURL)
        let metadata = BaseCacheSnapshotMetadata(
            snapshotID: fingerprint.id,
            createdAt: Date(),
            gameFingerprint: fingerprint,
            bundleCachePath: bundleCacheURL.path,
            bundleCacheSHA256: bundleSHA,
            sizeBytes: size,
            modificationDate: try PathSafety.modificationDate(url: bundleCacheURL)
        )
        let directory = snapshotDirectory(id: fingerprint.id)
        let snapshotURL = directory.appendingPathComponent("final.redscripts")
        if !dryRun {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                try FileManager.default.removeItem(at: snapshotURL)
            }
            try FileManager.default.copyItem(at: bundleCacheURL, to: snapshotURL)
            let data = try JSONEncoder.cybermac.encode(metadata)
            try data.write(to: metadataURL(id: fingerprint.id), options: [.atomic])
        }
        return BaseCacheRefreshResult(
            dryRun: dryRun,
            snapshotID: fingerprint.id,
            snapshotURL: snapshotURL,
            metadata: metadata,
            didWrite: !dryRun
        )
    }

    public func loadSnapshot(id: String) throws -> BaseCacheSnapshotMetadata {
        let url = metadataURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Base cache snapshot metadata missing: \(id)")
        }
        return try JSONDecoder.cybermac.decode(BaseCacheSnapshotMetadata.self, from: Data(contentsOf: url))
    }

    public func copySnapshotToOverlay(snapshotID: String) throws -> URL {
        let sourceURL = snapshotDirectory(id: snapshotID).appendingPathComponent("final.redscripts")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CyberMacError.notFound("Base cache snapshot missing: \(sourceURL.path)")
        }
        try FileManager.default.createDirectory(at: home.overlayCacheURL, withIntermediateDirectories: true)
        let targetURL = home.overlayCacheURL.appendingPathComponent("final.redscripts")
        let timestampURL = home.overlayCacheURL.appendingPathComponent("final.redscripts.ts")
        let backupURL = home.overlayCacheURL.appendingPathComponent("final.redscripts.bk")
        for disposable in [timestampURL, backupURL] where FileManager.default.fileExists(atPath: disposable.path) {
            try FileManager.default.removeItem(at: disposable)
        }
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    public func snapshotDirectory(id: String) -> URL {
        home.baseCacheURL.appendingPathComponent(id, isDirectory: true)
    }

    private func metadataURL(id: String) -> URL {
        snapshotDirectory(id: id).appendingPathComponent("metadata.json")
    }

    private func readBundleInfo(appURL: URL) throws -> (bundleIdentifier: String, shortVersion: String, bundleVersion: String) {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw CyberMacError.invalidInput("Could not parse Info.plist: \(plistURL.path)")
        }
        return (
            plist["CFBundleIdentifier"] as? String ?? "unknown",
            plist["CFBundleShortVersionString"] as? String ?? "unknown",
            plist["CFBundleVersion"] as? String ?? "unknown"
        )
    }
}
