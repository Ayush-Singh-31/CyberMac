import Foundation

public struct BundleBackupManager: Sendable {
    private let home: CyberMacHomeManager
    private let baseCacheManager: BaseCacheManager

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.baseCacheManager = BaseCacheManager(home: home)
    }

    public func bundleTargetURL(gameInstall: GameInstall) -> URL {
        baseCacheManager.bundleCacheURL(gameInstall: gameInstall)
    }

    public func backup(gameInstall: GameInstall, fingerprintID: String) throws -> BundleBackupManifest {
        try home.bootstrap()
        let id = try uniqueBackupID()
        let directory = backupDirectory(id: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let targetURL = bundleTargetURL(gameInstall: gameInstall)
        let backupURL = directory.appendingPathComponent("final.redscripts")
        let manifest: BundleBackupManifest
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.copyItem(at: targetURL, to: backupURL)
            manifest = BundleBackupManifest(
                id: id,
                createdAt: Date(),
                gameAppPath: gameInstall.appURL.path,
                bundleTarget: targetURL.path,
                priorState: .present,
                sha256: try PathSafety.sha256(url: targetURL),
                sizeBytes: try PathSafety.fileSize(url: targetURL),
                gameFingerprintID: fingerprintID
            )
        } else {
            manifest = BundleBackupManifest(
                id: id,
                createdAt: Date(),
                gameAppPath: gameInstall.appURL.path,
                bundleTarget: targetURL.path,
                priorState: .absent,
                sha256: nil,
                sizeBytes: nil,
                gameFingerprintID: fingerprintID
            )
        }
        try save(manifest)
        try pruneRetention(currentFingerprintID: fingerprintID)
        return manifest
    }

    public func list() throws -> [BundleBackupManifest] {
        guard FileManager.default.fileExists(atPath: home.backupsURL.path) else { return [] }
        let directories = try FileManager.default.contentsOfDirectory(
            at: home.backupsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try directories.compactMap { directory in
            let metadataURL = directory.appendingPathComponent("backup-manifest.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
            return try JSONDecoder.cybermac.decode(BundleBackupManifest.self, from: Data(contentsOf: metadataURL))
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public func load(id: String) throws -> BundleBackupManifest {
        let url = backupDirectory(id: id).appendingPathComponent("backup-manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Backup not found: \(id)")
        }
        return try JSONDecoder.cybermac.decode(BundleBackupManifest.self, from: Data(contentsOf: url))
    }

    public func restoreCommand(id: String) throws -> String {
        try restoreCommand(id: id, gameInstall: nil)
    }

    public func restoreCommand(id: String, gameInstall: GameInstall?) throws -> String {
        let manifest = try load(id: id)
        try validateCurrentFingerprintIfNeeded(manifest: manifest, gameInstall: gameInstall)
        switch manifest.priorState {
        case .present:
            let backupURL = backupDirectory(id: id).appendingPathComponent("final.redscripts")
            return "sudo cp \(PathSafety.shellDoubleQuoted(backupURL.path)) \(PathSafety.shellDoubleQuoted(manifest.bundleTarget))"
        case .absent:
            return "sudo rm -f \(PathSafety.shellDoubleQuoted(manifest.bundleTarget))"
        }
    }

    public func verifyRestore(id: String) throws -> Bool {
        try verifyRestore(id: id, gameInstall: nil)
    }

    public func verifyRestore(id: String, gameInstall: GameInstall?) throws -> Bool {
        let manifest = try load(id: id)
        try validateCurrentFingerprintIfNeeded(manifest: manifest, gameInstall: gameInstall)
        let targetURL = URL(fileURLWithPath: manifest.bundleTarget)
        switch manifest.priorState {
        case .absent:
            return !FileManager.default.fileExists(atPath: targetURL.path)
        case .present:
            guard let expected = manifest.sha256,
                  FileManager.default.fileExists(atPath: targetURL.path)
            else { return false }
            return try PathSafety.sha256(url: targetURL) == expected
        }
    }

    public func backupDirectory(id: String) -> URL {
        home.backupsURL.appendingPathComponent(id, isDirectory: true)
    }

    private func save(_ manifest: BundleBackupManifest) throws {
        let directory = backupDirectory(id: manifest.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.cybermac.encode(manifest)
        try data.write(to: directory.appendingPathComponent("backup-manifest.json"), options: [.atomic])
    }

    private func uniqueBackupID() throws -> String {
        let base = Self.makeID()
        if !FileManager.default.fileExists(atPath: backupDirectory(id: base).path) {
            return base
        }
        return "\(base)-\(UUID().uuidString.prefix(8))"
    }

    private func validateCurrentFingerprintIfNeeded(manifest: BundleBackupManifest, gameInstall: GameInstall?) throws {
        guard let gameInstall else { return }
        let current = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        guard current.id == manifest.gameFingerprintID else {
            throw CyberMacError.unsupported("Backup \(manifest.id) belongs to a different game fingerprint and is stale for the current bundle.")
        }
    }

    private func pruneRetention(currentFingerprintID: String) throws {
        let manifests = try list()
        let current = manifests.filter { $0.gameFingerprintID == currentFingerprintID }.sorted { $0.createdAt < $1.createdAt }
        if current.count > 11 {
            let oldest: Set<String> = current.first.map { Set([$0.id]) } ?? []
            let newest = Set(current.suffix(10).map(\.id))
            let keep = oldest.union(newest)
            for manifest in current where !keep.contains(manifest.id) {
                try? FileManager.default.removeItem(at: backupDirectory(id: manifest.id))
            }
        }

        let refreshed = try list()
        var stale = refreshed
            .filter { $0.gameFingerprintID != currentFingerprintID }
            .sorted { $0.createdAt < $1.createdAt }
        var staleBytes = try stale.reduce(UInt64(0)) { partial, manifest in
            partial + (try directorySize(backupDirectory(id: manifest.id)))
        }
        let limit: UInt64 = 1_000_000_000
        while staleBytes > limit, let manifest = stale.first {
            let directory = backupDirectory(id: manifest.id)
            let size = (try? directorySize(directory)) ?? 0
            try? FileManager.default.removeItem(at: directory)
            staleBytes = staleBytes > size ? staleBytes - size : 0
            stale.removeFirst()
        }
    }

    private func directorySize(_ url: URL) throws -> UInt64 {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
        var total: UInt64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                total += UInt64(values.fileSize ?? 0)
            }
        }
        return total
    }

    private static func makeID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
