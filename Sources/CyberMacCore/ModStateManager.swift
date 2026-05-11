import Foundation

public struct ModStateManager: Sendable {
    private let home: CyberMacHomeManager
    private let manifestStore: ManifestStore
    private let stateStore: StateStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.manifestStore = ManifestStore(home: home)
        self.stateStore = StateStore(home: home)
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
        if manifest.requiresInputMappingPatch {
            manifest.inputPatchState = .outOfSync
        }
        try manifestStore.save(manifest)
        try stateStore.markActivationOutOfSync()
        if manifest.requiresInputMappingPatch {
            try stateStore.markInputPatchOutOfSync()
            try markInputPatchManifestsOutOfSync(overrides: [manifest.id: .outOfSync])
        }
        return manifest
    }

    public func enable(id: String) throws -> InstalledModManifest {
        var manifest = try manifestStore.load(id: id)
        guard manifest.status == .disabled else { return manifest }
        try home.bootstrap()
        let files = try managedFiles(for: manifest)
        try move(files: files, from: \.disabledURL, to: \.enabledURL)
        manifest.status = .enabled
        if manifest.requiresInputMappingPatch {
            manifest.inputPatchState = .required
        }
        try manifestStore.save(manifest)
        try stateStore.markActivationOutOfSync()
        if manifest.requiresInputMappingPatch {
            try stateStore.markInputPatchOutOfSync()
            try markInputPatchManifestsOutOfSync(overrides: [manifest.id: .required])
        }
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
                let trashURL = trashRoot.appendingPathComponent(file.stagingRelativePath)
                try PathSafety.validateContainedPath(trashURL, in: trashRoot)
                try FileManager.default.createDirectory(at: trashURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: sourceURL, to: trashURL)
                moved.append((from: trashURL, to: sourceURL))
                pruneEmptyDirectories(startingAt: sourceURL.deletingLastPathComponent(), stopAt: file.root(for: sourceURL))
            }
            manifest.status = .uninstalled
            if manifest.requiresInputMappingPatch {
                manifest.inputPatchState = .outOfSync
            }
            try manifestStore.save(manifest)
            try stateStore.markActivationOutOfSync()
            if manifest.requiresInputMappingPatch {
                try stateStore.markInputPatchOutOfSync()
                try markInputPatchManifestsOutOfSync(overrides: [manifest.id: .outOfSync])
            }
            try? FileManager.default.removeItem(at: trashRoot)
        } catch {
            rollback(moved: moved)
            throw error
        }
        return manifest
    }

    private enum ManagedFileZone {
        case scripts
        case input

        var directoryName: String {
            switch self {
            case .scripts:
                return "scripts"
            case .input:
                return "input"
            }
        }
    }

    private struct ManagedFile {
        let zone: ManagedFileZone
        let relativePath: String
        let enabledRoot: URL
        let disabledRoot: URL
        let enabledURL: URL
        let disabledURL: URL

        var stagingRelativePath: String {
            "\(zone.directoryName)/\(relativePath)"
        }

        func root(for url: URL) -> URL {
            let path = url.standardizedFileURL.path
            if path.hasPrefix(disabledRoot.standardizedFileURL.path + "/") {
                return disabledRoot
            }
            return enabledRoot
        }
    }

    private func managedFiles(for manifest: InstalledModManifest) throws -> [ManagedFile] {
        guard !manifest.installedFiles.isEmpty || !manifest.inputMappingFiles.isEmpty else {
            throw CyberMacError.fileSystem("Manifest has no installed file records: \(manifest.id)")
        }

        let scriptFiles = try managedFiles(
            records: manifest.installedFiles,
            manifestID: manifest.id,
            zone: .scripts,
            enabledRoot: home.overlayScriptsURL.appendingPathComponent(manifest.id, isDirectory: true),
            disabledRoot: home.disabledURL
                .appendingPathComponent(manifest.id, isDirectory: true)
                .appendingPathComponent("scripts", isDirectory: true)
        )
        let inputFiles = try managedFiles(
            records: manifest.inputMappingFiles,
            manifestID: manifest.id,
            zone: .input,
            enabledRoot: home.overlayInputURL.appendingPathComponent(manifest.id, isDirectory: true),
            disabledRoot: home.disabledURL
                .appendingPathComponent(manifest.id, isDirectory: true)
                .appendingPathComponent("input", isDirectory: true)
        )

        return scriptFiles + inputFiles
    }

    private func managedFiles(records: [InstalledFileRecord], manifestID: String, zone: ManagedFileZone, enabledRoot: URL, disabledRoot: URL) throws -> [ManagedFile] {
        try records.map { record in
            guard !record.installedPath.contains("/Users/<user>") else {
                throw CyberMacError.fileSystem("Manifest contains a redacted installed path; reinstall the mod to regenerate file records: \(manifestID)")
            }
            let enabledURL = URL(fileURLWithPath: record.installedPath)
            try PathSafety.validateContainedPath(enabledURL, in: enabledRoot)
            let relativePath = try PathSafety.relativePath(of: enabledURL, in: enabledRoot)
            let disabledURL = disabledRoot.appendingPathComponent(relativePath)
            try PathSafety.validateContainedPath(disabledURL, in: disabledRoot)
            return ManagedFile(zone: zone, relativePath: relativePath, enabledRoot: enabledRoot, disabledRoot: disabledRoot, enabledURL: enabledURL, disabledURL: disabledURL)
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

    private func markInputPatchManifestsOutOfSync(overrides: [String: InputPatchState]) throws {
        let manifests = try manifestStore.list()
        for var manifest in manifests where manifest.requiresInputMappingPatch {
            manifest.inputPatchState = overrides[manifest.id] ?? .outOfSync
            try manifestStore.save(manifest)
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
