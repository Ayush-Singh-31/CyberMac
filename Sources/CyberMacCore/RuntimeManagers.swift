import Foundation
import ZIPFoundation

public struct RuntimeArchiveImporter: Sendable {
    private let home: CyberMacHomeManager
    private let quarantine: QuarantineManager

    public init(home: CyberMacHomeManager, quarantine: QuarantineManager = QuarantineManager()) {
        self.home = home
        self.quarantine = quarantine
    }

    public func importRedscript(zipURL: URL) throws -> RuntimeStatus {
        try importRuntime(zipURL: zipURL, kind: .redscript, destinationURL: home.redscriptRuntimeURL, requiredToolName: "scc")
    }

    public func importInputLoader(zipURL: URL) throws -> RuntimeStatus {
        try importRuntime(zipURL: zipURL, kind: .inputLoader, destinationURL: home.inputLoaderRuntimeURL, requiredToolName: "inputloader.pl")
    }

    public func redscriptStatus() -> RuntimeStatus {
        status(kind: .redscript, rootURL: home.redscriptRuntimeURL, requiredToolName: "scc")
    }

    public func inputLoaderStatus() -> RuntimeStatus {
        status(kind: .inputLoader, rootURL: home.inputLoaderRuntimeURL, requiredToolName: "inputloader.pl")
    }

    private func importRuntime(zipURL: URL, kind: RuntimeKind, destinationURL: URL, requiredToolName: String) throws -> RuntimeStatus {
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw CyberMacError.notFound("Runtime zip does not exist: \(zipURL.path)")
        }
        guard zipURL.pathExtension.lowercased() == "zip" else {
            throw CyberMacError.invalidInput("Runtime import currently accepts .zip files only")
        }
        try PathSafety.validateArchiveSize(zipURL)
        let archiveSHA256 = try PathSafety.sha256(url: zipURL)
        let detectedVersion = Self.versionString(from: zipURL.deletingPathExtension().lastPathComponent)

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        let parentURL = destinationURL.deletingLastPathComponent()
        let stagingURL = parentURL.appendingPathComponent(".\(destinationURL.lastPathComponent)-staging-\(UUID().uuidString)", isDirectory: true)
        let backupURL = parentURL.appendingPathComponent(".\(destinationURL.lastPathComponent)-backup-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
            var entryCount = 0
            for entry in archive {
                entryCount += 1
                guard entryCount <= PathSafety.maxArchiveEntries else {
                    throw CyberMacError.invalidInput("Runtime archive has too many entries: limit is \(PathSafety.maxArchiveEntries)")
                }
                try PathSafety.validateArchivePath(entry.path)
                let target = stagingURL.appendingPathComponent(entry.path)
                try PathSafety.validateContainedPath(target, in: stagingURL)
                switch entry.type {
                case .directory:
                    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                case .file:
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    _ = try archive.extract(entry, to: target)
                case .symlink:
                    throw CyberMacError.unsafePath("Runtime archive contains symlink: \(entry.path)")
                }
            }

            try saveMetadata(
                RuntimeMetadata(
                    sourceArchiveName: zipURL.lastPathComponent,
                    sourceArchiveSHA256: archiveSHA256,
                    version: detectedVersion,
                    importedAt: Date()
                ),
                to: stagingURL
            )

            let importedStatus = status(kind: kind, rootURL: stagingURL, requiredToolName: requiredToolName)
            guard let toolURL = importedStatus.toolURL else {
                throw CyberMacError.invalidInput("Imported \(kind.rawValue) archive does not contain required tool: \(requiredToolName)")
            }

            if requiredToolName == "scc" {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: toolURL.path)
            }

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.moveItem(at: destinationURL, to: backupURL)
            }
            do {
                try FileManager.default.moveItem(at: stagingURL, to: destinationURL)
                try? FileManager.default.removeItem(at: backupURL)
            } catch {
                if FileManager.default.fileExists(atPath: backupURL.path), !FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.moveItem(at: backupURL, to: destinationURL)
                }
                throw error
            }

            return status(kind: kind, rootURL: destinationURL, requiredToolName: requiredToolName)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        }
    }

    private func status(kind: RuntimeKind, rootURL: URL, requiredToolName: String) -> RuntimeStatus {
        let rootExists = FileManager.default.fileExists(atPath: rootURL.path)
        let toolURL = rootExists ? findFile(named: requiredToolName, under: rootURL) : nil
        let metadata = rootExists ? loadMetadata(from: rootURL) : nil
        let installed = toolURL != nil
        var notes: [String] = []
        if !rootExists {
            notes.append("Runtime folder is missing")
        } else if toolURL == nil {
            notes.append("Runtime folder exists but required tool was not found: \(requiredToolName)")
        }
        if let toolURL, requiredToolName == "scc", !FileManager.default.isExecutableFile(atPath: toolURL.path) {
            notes.append("scc exists but is not marked executable")
        }
        if let metadata, kind == .inputLoader {
            if KnownBadRuntimeHashes.inputLoaderArchiveSHA256.contains(metadata.sourceArchiveSHA256.lowercased()) {
                notes.append("Known-bad input-loader archive detected; replace inputloader.pl with the fixed version referenced by the macOS modding guide")
            } else if metadata.version == "1.0" {
                notes.append("input-loader v1.0 is associated with macOS launch crashes; use the fixed inputloader.pl if available")
            }
        }

        return RuntimeStatus(
            kind: kind,
            rootURL: rootURL,
            installed: installed,
            toolURL: toolURL,
            version: metadata?.version,
            quarantinedPaths: rootExists ? quarantine.quarantinedPaths(under: rootURL) : [],
            notes: notes
        )
    }

    private func findFile(named fileName: String, under rootURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return nil }
        if rootURL.lastPathComponent == fileName { return rootURL }
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == fileName {
                return url
            }
        }
        return nil
    }

    private func metadataURL(for rootURL: URL) -> URL {
        rootURL.appendingPathComponent(".cybermac-runtime.json")
    }

    private func saveMetadata(_ metadata: RuntimeMetadata, to rootURL: URL) throws {
        let data = try JSONEncoder.cybermac.encode(metadata)
        try data.write(to: metadataURL(for: rootURL), options: [.atomic])
    }

    private func loadMetadata(from rootURL: URL) -> RuntimeMetadata? {
        let url = metadataURL(for: rootURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.cybermac.decode(RuntimeMetadata.self, from: data)
    }

    private static func versionString(from baseName: String) -> String? {
        let pattern = #"(?i)(?:^|[-_])v?([0-9]+(?:\.[0-9]+)+(?:[-_](?:preview|alpha|beta|rc)\.?[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(baseName.startIndex..<baseName.endIndex, in: baseName)
        guard let match = regex.firstMatch(in: baseName, range: range),
              let versionRange = Range(match.range(at: 1), in: baseName)
        else { return nil }
        return String(baseName[versionRange]).replacingOccurrences(of: "_", with: "-")
    }
}

private struct RuntimeMetadata: Codable, Sendable {
    let sourceArchiveName: String
    let sourceArchiveSHA256: String
    let version: String?
    let importedAt: Date
}

private enum KnownBadRuntimeHashes {
    static let inputLoaderArchiveSHA256: Set<String> = [
        "cb1d97f1b493f22585d578be4a3ffe98345807101d8305792c6ba3743c360f77"
    ]
}
