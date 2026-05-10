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

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        for entry in archive {
            try PathSafety.validateArchivePath(entry.path)
            let target = destinationURL.appendingPathComponent(entry.path)
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

        var importedStatus = status(kind: kind, rootURL: destinationURL, requiredToolName: requiredToolName)
        guard let toolURL = importedStatus.toolURL else {
            throw CyberMacError.invalidInput("Imported \(kind.rawValue) archive does not contain required tool: \(requiredToolName)")
        }

        if requiredToolName == "scc" {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: toolURL.path)
            importedStatus = status(kind: kind, rootURL: destinationURL, requiredToolName: requiredToolName)
        }

        return importedStatus
    }

    private func status(kind: RuntimeKind, rootURL: URL, requiredToolName: String) -> RuntimeStatus {
        let rootExists = FileManager.default.fileExists(atPath: rootURL.path)
        let toolURL = rootExists ? findFile(named: requiredToolName, under: rootURL) : nil
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

        return RuntimeStatus(
            kind: kind,
            rootURL: rootURL,
            installed: installed,
            toolURL: toolURL,
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
}
