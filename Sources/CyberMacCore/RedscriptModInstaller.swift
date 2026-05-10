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
            throw CyberMacError.unsupported("Only supported redscript-only mods can be installed. Scan status: \(scanResult.compatibilityStatus.rawValue)")
        }
        guard scanResult.sidecarInstallable else {
            throw CyberMacError.unsupported(scanResult.installBlockReason ?? "Mod is not installable")
        }
        guard scanResult.kind == .redscript else {
            throw CyberMacError.unsupported("Only redscript mods can be installed in v0.1")
        }
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        let id = PathSafety.sanitizeModID(from: scanResult.displayName)
        let installRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: installRoot.path) else {
            throw CyberMacError.fileSystem("Install root already exists: \(installRoot.path)")
        }

        var records: [InstalledFileRecord] = []
        let redscriptSet = Set(scanResult.redscriptEntries)

        do {
            try FileManager.default.createDirectory(at: installRoot, withIntermediateDirectories: true)

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

            guard !records.isEmpty else {
                throw CyberMacError.invalidInput("No .reds files were extracted")
            }

            let manifest = InstalledModManifest(
                id: id,
                displayName: scanResult.displayName,
                type: .redscript,
                status: .enabled,
                sourceArchive: zipURL.path,
                installedAt: Date(),
                gameAppPath: gameInstall.appURL.path,
                installMode: "sidecar_overlay",
                installedFiles: records,
                detectedDependencies: ["redscript"],
                compatibilityStatus: .supported
            )
            try manifestStore.save(manifest)
            try StateStore(home: home).markActivationOutOfSync()
            return manifest
        } catch {
            try? FileManager.default.removeItem(at: installRoot)
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
}
