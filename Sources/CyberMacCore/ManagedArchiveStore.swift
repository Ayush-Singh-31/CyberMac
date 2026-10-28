import Foundation

/// Shared, verified archive snapshots used by body and clothing preparation.
/// A later installer starts with the combined archive, preserving earlier mods.
struct ManagedArchiveStore {
    let home: CyberMacHomeManager
    private var url: URL { home.configURL.appendingPathComponent("managed-archives.json") }
    private struct Receipt: Codable {
        let gameApp: String
        let seal: String
        var files: [ModInstallTransaction.File]
    }

    private func seal(_ game: GameInstall) throws -> String {
        try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources"))
    }

    private func load(_ game: GameInstall) throws -> Receipt? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let receipt = try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: url))
        guard receipt.gameApp == game.appURL.path, receipt.seal == (try seal(game)) else { return nil }
        return receipt
    }

    func knownFile(target: URL, game: GameInstall) throws -> ModInstallTransaction.File? {
        guard target.pathExtension == "archive", let receipt = try load(game) else { return nil }
        let hashes = FingerprintCacheStore(home: home)
        let actual = try hashes.sha256(url: target)
        guard let file = receipt.files.last(where: { $0.target == target.path && $0.installedSHA256 == actual }) else { return nil }
        guard try hashes.sha256(url: URL(fileURLWithPath: file.source)) == actual else {
            throw CyberMacError.invalidInput("A prepared archive changed. Rebuild the body or clothing selection.")
        }
        return file
    }

    func remember(_ transaction: ModInstallTransaction, game: GameInstall) throws {
        try transaction.verify()
        var files = try load(game)?.files ?? []
        for file in transaction.files where URL(fileURLWithPath: file.target).pathExtension == "archive" {
            files.removeAll { $0.target == file.target && $0.installedSHA256 == file.installedSHA256 }
            files.append(file)
            // Retain the preceding combined state as well, so an ordinary undo
            // can be recognized without mistaking it for an external edit.
            if !files.contains(where: { $0.target == file.target && $0.installedSHA256 == file.originalSHA256 }) {
                files.append(.init(source: file.backup, target: file.target, backup: file.source,
                    originalSHA256: file.installedSHA256, installedSHA256: file.originalSHA256))
            }
        }
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(Receipt(gameApp: game.appURL.path, seal: try seal(game), files: files))
            .write(to: url, options: .atomic)
    }
}
