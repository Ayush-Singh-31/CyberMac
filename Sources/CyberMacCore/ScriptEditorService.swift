import Foundation

public struct EditableScriptFile: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let modID: String
    public let relativePath: String
    public let absolutePath: String
    public let sizeBytes: UInt64
    public let sha256: String
    public let lastModified: Date?

    public init(id: String, modID: String, relativePath: String, absolutePath: String, sizeBytes: UInt64, sha256: String, lastModified: Date?) {
        self.id = id
        self.modID = modID
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.lastModified = lastModified
    }
}

public struct ScriptSaveResult: Codable, Sendable, Equatable {
    public let file: EditableScriptFile
    public let backupPath: String

    public init(file: EditableScriptFile, backupPath: String) {
        self.file = file
        self.backupPath = backupPath
    }
}

public enum ScriptEditorError: Error, LocalizedError {
    case modNotFound(String)
    case modNotEditable(String)
    case fileNotFound(String)
    case fileOutsideOverlay
    case unsupportedExtension(String)
    case fileTooLarge(UInt64)
    case unreadable(String)
    case backupFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modNotFound(let id):
            return "Installed mod was not found: \(id)"
        case .modNotEditable(let id):
            return "Mod is not editable in the script editor: \(id)"
        case .fileNotFound(let path):
            return "Editable script file was not found: \(path)"
        case .fileOutsideOverlay:
            return "Script editor path is outside the CyberMac sidecar script overlay."
        case .unsupportedExtension(let path):
            return "Script editor only supports .reds files: \(path)"
        case .fileTooLarge(let size):
            return "Script file is too large for the editor: \(size) bytes"
        case .unreadable(let path):
            return "Script file could not be read as UTF-8 text: \(path)"
        case .backupFailed(let message):
            return "Could not create script backup: \(message)"
        case .writeFailed(let message):
            return "Could not save script file: \(message)"
        }
    }
}

public struct ScriptEditorService: Sendable {
    public static let maxScriptBytes = 1_048_576

    public let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func listEditableScripts(modID: String) throws -> [EditableScriptFile] {
        let manifest = try loadEditableManifest(modID: modID)
        let modRoot = try resolvedModRoot(modID: modID)

        return manifest.installedFiles.compactMap { record in
            guard recordLooksLikeReds(record.installedPath),
                  !isBackupPath(record.installedPath) else {
                return nil
            }
            return try? editableFile(from: URL(fileURLWithPath: record.installedPath), modID: modID, modRoot: modRoot)
        }
        .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    public func loadScript(modID: String, relativePath: String) throws -> String {
        let file = try validatedEditableFile(modID: modID, relativePath: relativePath)
        guard file.sizeBytes <= UInt64(Self.maxScriptBytes) else {
            throw ScriptEditorError.fileTooLarge(file.sizeBytes)
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file.absolutePath))
            guard let contents = String(data: data, encoding: .utf8) else {
                throw ScriptEditorError.unreadable(file.relativePath)
            }
            return contents
        } catch let error as ScriptEditorError {
            throw error
        } catch {
            throw ScriptEditorError.unreadable(file.relativePath)
        }
    }

    public func saveScript(modID: String, relativePath: String, contents: String) throws -> ScriptSaveResult {
        guard let encoded = contents.data(using: .utf8), encoded.count <= Self.maxScriptBytes else {
            throw ScriptEditorError.fileTooLarge(UInt64(contents.utf8.count))
        }

        let file = try validatedEditableFile(modID: modID, relativePath: relativePath)
        let targetURL = URL(fileURLWithPath: file.absolutePath)
        let backupURL = try backupURL(for: targetURL, modID: modID)

        do {
            try FileManager.default.copyItem(at: targetURL, to: backupURL)
        } catch {
            throw ScriptEditorError.backupFailed(error.localizedDescription)
        }

        do {
            try contents.write(to: targetURL, atomically: true, encoding: .utf8)
            try StateStore(home: home).markActivationOutOfSync()
            let refreshed = try validatedEditableFile(modID: modID, relativePath: relativePath)
            return ScriptSaveResult(file: refreshed, backupPath: backupURL.path)
        } catch {
            throw ScriptEditorError.writeFailed(error.localizedDescription)
        }
    }

    private func loadEditableManifest(modID: String) throws -> InstalledModManifest {
        let manifest: InstalledModManifest
        do {
            manifest = try ManifestStore(home: home).load(id: modID)
        } catch CyberMacError.notFound(_) {
            throw ScriptEditorError.modNotFound(modID)
        }

        guard manifest.status == .enabled,
              manifest.installMode == "sidecar_overlay",
              !manifest.installedFiles.isEmpty else {
            throw ScriptEditorError.modNotEditable(modID)
        }
        return manifest
    }

    private func validatedEditableFile(modID: String, relativePath: String) throws -> EditableScriptFile {
        _ = try loadEditableManifest(modID: modID)
        let modRoot = try resolvedModRoot(modID: modID)
        try validateRelativePath(relativePath)
        let requestedURL = try resolvedURL(relativePath: relativePath, in: modRoot)
        let editableFiles = try listEditableScripts(modID: modID)

        guard editableFiles.contains(where: { $0.absolutePath == requestedURL.path }) else {
            throw ScriptEditorError.fileNotFound(relativePath)
        }
        return try editableFile(from: requestedURL, modID: modID, modRoot: modRoot)
    }

    private func editableFile(from url: URL, modID: String, modRoot: URL) throws -> EditableScriptFile {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        try validateResolvedContainment(resolved, in: modRoot)
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            throw ScriptEditorError.fileNotFound(resolved.path)
        }
        let relativePath = try PathSafety.relativePath(of: resolved, in: modRoot)
        try validateRelativePath(relativePath)
        return EditableScriptFile(
            id: "\(modID):\(relativePath)",
            modID: modID,
            relativePath: relativePath,
            absolutePath: resolved.path,
            sizeBytes: try PathSafety.fileSize(url: resolved),
            sha256: try PathSafety.sha256(url: resolved),
            lastModified: try PathSafety.modificationDate(url: resolved)
        )
    }

    private func resolvedModRoot(modID: String) throws -> URL {
        guard isSafePathComponent(modID) else {
            throw ScriptEditorError.fileOutsideOverlay
        }
        let overlayRoot = home.overlayScriptsURL.resolvingSymlinksInPath().standardizedFileURL
        let modRoot = overlayRoot.appendingPathComponent(modID, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        try validateResolvedContainment(modRoot, in: overlayRoot)
        return modRoot
    }

    private func resolvedURL(relativePath: String, in modRoot: URL) throws -> URL {
        var target = modRoot
        for component in relativePath.split(separator: "/").map(String.init) {
            target.appendPathComponent(component)
        }
        let resolved = target.resolvingSymlinksInPath().standardizedFileURL
        try validateResolvedContainment(resolved, in: modRoot)
        return resolved
    }

    private func backupURL(for targetURL: URL, modID: String) throws -> URL {
        let modRoot = try resolvedModRoot(modID: modID)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let backupURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent("\(targetURL.lastPathComponent).bak.\(formatter.string(from: Date()))")
            .standardizedFileURL
        try validateResolvedContainment(backupURL, in: modRoot)
        guard !FileManager.default.fileExists(atPath: backupURL.path) else {
            throw ScriptEditorError.backupFailed("Backup already exists: \(backupURL.path)")
        }
        return backupURL
    }

    private func validateRelativePath(_ relativePath: String) throws {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("\\") else {
            throw ScriptEditorError.fileOutsideOverlay
        }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.allSatisfy({ isSafePathComponent($0) }) else {
            throw ScriptEditorError.fileOutsideOverlay
        }

        guard relativePath.lowercased() != "final.redscripts",
              URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "reds" else {
            throw ScriptEditorError.unsupportedExtension(relativePath)
        }
        guard !isBackupPath(relativePath) else {
            throw ScriptEditorError.unsupportedExtension(relativePath)
        }
    }

    private func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty &&
        component != "." &&
        component != ".." &&
        !component.hasPrefix(".") &&
        !component.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) &&
        !component.contains("/")
    }

    private func validateResolvedContainment(_ url: URL, in rootURL: URL) throws {
        do {
            try PathSafety.validateContainedPath(url.resolvingSymlinksInPath(), in: rootURL.resolvingSymlinksInPath())
        } catch {
            throw ScriptEditorError.fileOutsideOverlay
        }
    }

    private func recordLooksLikeReds(_ path: String) -> Bool {
        URL(fileURLWithPath: path).pathExtension.lowercased() == "reds"
    }

    private func isBackupPath(_ path: String) -> Bool {
        path.lowercased().contains(".reds.bak.")
    }

}
