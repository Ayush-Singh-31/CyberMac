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
        try home.bootstrap()
        let files = try managedFiles(for: manifest)
        try move(files: files, from: \.enabledURL, to: \.disabledURL)
        manifest.status = .disabled
        try manifestStore.save(manifest)
        return manifest
    }

    public func enable(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        guard manifest.status == .disabled else { return manifest }
        try home.bootstrap()
        let files = try managedFiles(for: manifest)
        try move(files: files, from: \.disabledURL, to: \.enabledURL)
        manifest.status = .enabled
        try manifestStore.save(manifest)
        return manifest
    }

    public func uninstall(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        guard manifest.status != .uninstalled else { return manifest }
        try home.bootstrap()
        let files = try managedFiles(for: manifest)
        let source: KeyPath<ManagedFile, URL> = manifest.status == .disabled ? \.disabledURL : \.enabledURL
        let trashRoot = home.homeURL
            .appendingPathComponent("tmp", isDirectory: true)
            .appendingPathComponent("uninstall-\(id)-\(UUID().uuidString)", isDirectory: true)
        var moved: [(from: URL, to: URL)] = []

        do {
            for file in files {
                let sourceURL = file[keyPath: source]
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    throw CyberMacError.fileSystem("Managed file is missing; refusing to desync manifest: \(sourceURL.path)")
                }
                let trashURL = trashRoot.appendingPathComponent(file.relativePath)
                try PathSafety.validateContainedPath(trashURL, in: trashRoot)
                try FileManager.default.createDirectory(at: trashURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: sourceURL, to: trashURL)
                moved.append((from: trashURL, to: sourceURL))
                pruneEmptyDirectories(startingAt: sourceURL.deletingLastPathComponent(), stopAt: file.root(for: sourceURL))
            }
            manifest.status = .uninstalled
            try manifestStore.save(manifest)
            try? FileManager.default.removeItem(at: trashRoot)
        } catch {
            rollback(moved: moved)
            throw error
        }
        return manifest
    }

    private struct ManagedFile {
        let relativePath: String
        let enabledRoot: URL
        let disabledRoot: URL
        let enabledURL: URL
        let disabledURL: URL

        func root(for url: URL) -> URL {
            let path = url.standardizedFileURL.path
            if path.hasPrefix(disabledRoot.standardizedFileURL.path + "/") {
                return disabledRoot
            }
            return enabledRoot
        }
    }

    private func managedFiles(for manifest: InstalledModManifest) throws -> [ManagedFile] {
        guard !manifest.installedFiles.isEmpty else {
            throw CyberMacError.fileSystem("Manifest has no installed file records: \(manifest.id)")
        }

        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(manifest.id, isDirectory: true)
        let disabledRoot = home.disabledURL.appendingPathComponent(manifest.id, isDirectory: true)

        return try manifest.installedFiles.map { record in
            guard !record.installedPath.contains("/Users/<user>") else {
                throw CyberMacError.fileSystem("Manifest contains a redacted installed path; reinstall the mod to regenerate file records: \(manifest.id)")
            }
            let enabledURL = URL(fileURLWithPath: record.installedPath)
            try PathSafety.validateContainedPath(enabledURL, in: enabledRoot)
            let relativePath = try PathSafety.relativePath(of: enabledURL, in: enabledRoot)
            let disabledURL = disabledRoot.appendingPathComponent(relativePath)
            try PathSafety.validateContainedPath(disabledURL, in: disabledRoot)
            return ManagedFile(relativePath: relativePath, enabledRoot: enabledRoot, disabledRoot: disabledRoot, enabledURL: enabledURL, disabledURL: disabledURL)
        }
    }

    private func move(files: [ManagedFile], from source: KeyPath<ManagedFile, URL>, to destination: KeyPath<ManagedFile, URL>) throws {
        var moved: [(from: URL, to: URL)] = []
        do {
            for file in files {
                let sourceURL = file[keyPath: source]
                let destinationURL = file[keyPath: destination]
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    throw CyberMacError.fileSystem("Managed file is missing; refusing to desync manifest: \(sourceURL.path)")
                }
                guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
                    throw CyberMacError.fileSystem("Destination already exists for managed file: \(destinationURL.path)")
                }
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                moved.append((from: destinationURL, to: sourceURL))
                pruneEmptyDirectories(startingAt: sourceURL.deletingLastPathComponent(), stopAt: file.root(for: sourceURL))
            }
        } catch {
            rollback(moved: moved)
            throw error
        }
    }

    private func rollback(moved: [(from: URL, to: URL)]) {
        for item in moved.reversed() where FileManager.default.fileExists(atPath: item.from.path) {
            try? FileManager.default.createDirectory(at: item.to.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: item.from, to: item.to)
        }
    }

    private func pruneEmptyDirectories(startingAt startURL: URL, stopAt stopURL: URL) {
        var current = startURL
        let stopPath = stopURL.standardizedFileURL.path
        while current.standardizedFileURL.path.hasPrefix(stopPath) && current.standardizedFileURL.path != stopPath {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: current.path), contents.isEmpty else {
                return
            }
            try? FileManager.default.removeItem(at: current)
            current.deleteLastPathComponent()
        }
    }
}
