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

    public func install(zipURL: URL, gameInstall: GameInstall, launchWorkflowVerified: Bool) throws -> InstalledModManifest {
        try home.bootstrap()
        let scanResult = try scanner.scan(zipURL: zipURL, launchWorkflowVerified: launchWorkflowVerified)
        guard scanResult.compatibilityStatus == .supported else {
            throw CyberMacError.unsupported("Only supported redscript-only mods can be installed. Scan status: \(scanResult.compatibilityStatus.rawValue)")
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
        try FileManager.default.createDirectory(at: installRoot, withIntermediateDirectories: true)

        var records: [InstalledFileRecord] = []
        let redscriptSet = Set(scanResult.redscriptEntries)

        for entry in archive where redscriptSet.contains(entry.path) {
            try PathSafety.validateArchivePath(entry.path)
            guard entry.type == .file else { continue }
            let relative = normalizedRedscriptRelativePath(entry.path)
            let targetURL = installRoot.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: targetURL)

            let sha = try PathSafety.sha256(url: targetURL)
            let size = try PathSafety.fileSize(url: targetURL)
            records.append(InstalledFileRecord(
                sourceInArchive: entry.path,
                installedPath: PathSafety.redactUserPath(targetURL.path),
                sizeBytes: size,
                sha256: sha
            ))
        }

        guard !records.isEmpty else {
            try? FileManager.default.removeItem(at: installRoot)
            throw CyberMacError.invalidInput("No .reds files were extracted")
        }

        let manifest = InstalledModManifest(
            id: id,
            displayName: scanResult.displayName,
            type: .redscript,
            status: .enabled,
            sourceArchive: PathSafety.redactUserPath(zipURL.path),
            installedAt: Date(),
            gameAppPath: gameInstall.appURL.path,
            installMode: "sidecar_overlay",
            installedFiles: records,
            detectedDependencies: ["redscript"],
            compatibilityStatus: .supported
        )
        try manifestStore.save(manifest)
        return manifest
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
