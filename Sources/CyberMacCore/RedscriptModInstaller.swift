import Foundation
import ZIPFoundation

public struct RedscriptModInstaller: Sendable {
    private let home: CyberMacHomeManager
    private let manifestStore: ManifestStore
    private let scanner: ModArchiveScanner

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.manifestStore = ManifestStore(home: home)
        self.scanner = ModArchiveScanner()
    }

    public func install(zipURL: URL, gameInstall: GameInstall) throws -> InstalledModManifest {
        try home.bootstrap()
        let scanResult = try scanner.scan(zipURL: zipURL)
        guard scanResult.compatibilityStatus == .supported else {
            throw CyberMacError.unsupported("Only supported redscript or redscript input-mapping mods can be installed. Scan status: \(scanResult.compatibilityStatus.rawValue)")
        }
        guard scanResult.sidecarInstallable else {
            throw CyberMacError.unsupported(scanResult.installBlockReason ?? "Mod is not installable")
        }
        guard scanResult.kind == .redscript || scanResult.kind == .redscriptInput else {
            throw CyberMacError.unsupported("Only redscript and redscript input-mapping mods can be installed in v0.1")
        }
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        let id = PathSafety.sanitizeModID(from: scanResult.displayName)
        let installRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let inputRoot = home.overlayInputURL.appendingPathComponent(id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: installRoot.path) else {
            throw CyberMacError.fileSystem("Install root already exists: \(installRoot.path)")
        }
        if scanResult.requiresInputMappingPatch && FileManager.default.fileExists(atPath: inputRoot.path) {
            throw CyberMacError.fileSystem("Input install root already exists: \(inputRoot.path)")
        }

        var records: [InstalledFileRecord] = []
        var inputRecords: [InstalledFileRecord] = []
        let redscriptSet = Set(scanResult.redscriptEntries)
        let inputSet = Set(scanResult.inputMappingEntries)

        do {
            try FileManager.default.createDirectory(at: installRoot, withIntermediateDirectories: true)
            if scanResult.requiresInputMappingPatch {
                try FileManager.default.createDirectory(at: inputRoot, withIntermediateDirectories: true)
            }

            for entry in archive where redscriptSet.contains(entry.path) {
                try PathSafety.validateArchivePath(entry.path)
                guard entry.type == .file else { continue }
                let relative = normalizedRedscriptRelativePath(entry.path)
                let targetURL = installRoot.appendingPathComponent(relative)
                try PathSafety.validateContainedPath(targetURL, in: installRoot)
                try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: targetURL)

                let sha = try PathSafety.sha256(url: targetURL)
                let size = try PathSafety.fileSize(url: targetURL)
                records.append(InstalledFileRecord(
                    sourceInArchive: entry.path,
                    installedPath: targetURL.path,
                    sizeBytes: size,
                    sha256: sha
                ))
            }

            for entry in archive where inputSet.contains(entry.path) {
                try PathSafety.validateArchivePath(entry.path)
                guard entry.type == .file else { continue }
                let relative = normalizedInputRelativePath(entry.path)
                let targetURL = inputRoot.appendingPathComponent(relative)
                try PathSafety.validateContainedPath(targetURL, in: inputRoot)
                try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: targetURL)

                let sha = try PathSafety.sha256(url: targetURL)
                let size = try PathSafety.fileSize(url: targetURL)
                inputRecords.append(InstalledFileRecord(
                    sourceInArchive: entry.path,
                    installedPath: targetURL.path,
                    sizeBytes: size,
                    sha256: sha
                ))
            }

            guard !records.isEmpty else {
                throw CyberMacError.invalidInput("No .reds files were extracted")
            }
            if scanResult.requiresInputMappingPatch && inputRecords.isEmpty {
                throw CyberMacError.invalidInput("Input mapping patch is required, but no input XML files were extracted")
            }

            let manifest = InstalledModManifest(
                id: id,
                displayName: scanResult.displayName,
                type: scanResult.kind,
                status: .enabled,
                sourceArchive: zipURL.path,
                installedAt: Date(),
                gameAppPath: gameInstall.appURL.path,
                installMode: "sidecar_overlay",
                installedFiles: records,
                inputMappingFiles: inputRecords,
                inputPatchState: scanResult.requiresInputMappingPatch ? .required : .notRequired,
                requiresInputMappingPatch: scanResult.requiresInputMappingPatch,
                detectedDependencies: scanResult.requiresInputMappingPatch ? ["redscript", "input-mapping"] : ["redscript"],
                compatibilityStatus: .supported
            )
            try manifestStore.save(manifest)
            try StateStore(home: home).markActivationOutOfSync()
            if scanResult.requiresInputMappingPatch {
                try StateStore(home: home).markInputPatchOutOfSync()
                try markInputPatchManifestsOutOfSync(newModID: id)
            }
            return manifest
        } catch {
            try? FileManager.default.removeItem(at: installRoot)
            try? FileManager.default.removeItem(at: inputRoot)
            throw error
        }
    }

    private func normalizedRedscriptRelativePath(_ archivePath: String) -> String {
        let lower = archivePath.lowercased()
        if let range = lower.range(of: "r6/scripts/") {
            let suffix = archivePath[range.upperBound...]
            return String(suffix).isEmpty ? URL(fileURLWithPath: archivePath).lastPathComponent : String(suffix)
        }
        return URL(fileURLWithPath: archivePath).lastPathComponent
    }

    private func normalizedInputRelativePath(_ archivePath: String) -> String {
        let lower = archivePath.lowercased()
        if let range = lower.range(of: "r6/input/") {
            let suffix = archivePath[range.upperBound...]
            return String(suffix).isEmpty ? URL(fileURLWithPath: archivePath).lastPathComponent : String(suffix)
        }
        return URL(fileURLWithPath: archivePath).lastPathComponent
    }

    private func markInputPatchManifestsOutOfSync(newModID: String) throws {
        let manifests = try manifestStore.list()
        for var manifest in manifests where manifest.requiresInputMappingPatch {
            manifest.inputPatchState = manifest.id == newModID ? .required : .outOfSync
            try manifestStore.save(manifest)
        }
    }
}
