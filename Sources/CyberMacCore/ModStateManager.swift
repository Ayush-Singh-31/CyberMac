import Foundation

public struct ModStateManager: Sendable {
    private let home: CyberMacHomeManager
    private let manifestStore: ManifestStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.manifestStore = ManifestStore(home: home)
    }

    public func list() throws -> [InstalledModManifest] {
        try manifestStore.list()
    }

    public func disable(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        guard manifest.status == .enabled else { return manifest }
        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let disabledRoot = home.disabledURL.appendingPathComponent(id, isDirectory: true)
        try home.bootstrap()
        if FileManager.default.fileExists(atPath: disabledRoot.path) {
            try FileManager.default.removeItem(at: disabledRoot)
        }
        if FileManager.default.fileExists(atPath: enabledRoot.path) {
            try FileManager.default.createDirectory(at: disabledRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: enabledRoot, to: disabledRoot)
        }
        manifest.status = .disabled
        try manifestStore.save(manifest)
        return manifest
    }

    public func enable(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        guard manifest.status == .disabled else { return manifest }
        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let disabledRoot = home.disabledURL.appendingPathComponent(id, isDirectory: true)
        try home.bootstrap()
        if FileManager.default.fileExists(atPath: enabledRoot.path) {
            try FileManager.default.removeItem(at: enabledRoot)
        }
        if FileManager.default.fileExists(atPath: disabledRoot.path) {
            try FileManager.default.createDirectory(at: enabledRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: disabledRoot, to: enabledRoot)
        }
        manifest.status = .enabled
        try manifestStore.save(manifest)
        return manifest
    }

    public func uninstall(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let disabledRoot = home.disabledURL.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: enabledRoot.path) {
            try FileManager.default.removeItem(at: enabledRoot)
        }
        if FileManager.default.fileExists(atPath: disabledRoot.path) {
            try FileManager.default.removeItem(at: disabledRoot)
        }
        manifest.status = .uninstalled
        try manifestStore.save(manifest)
        return manifest
    }
}
