import Foundation
import Darwin

/// Prepares verified payloads for the app's authorized FileManager. The caller
/// supplies only the file replacement operation, never a shell or package code.
public struct NativeModInstallTransaction: Sendable {
    private let plan: ModInstallTransaction
    private let parents: [String: String]

    public init(plan: ModInstallTransaction) throws {
        self.plan = plan
        var parents: [String: String] = [:]
        for file in plan.files {
            for path in [file.source, file.backup, file.target] {
                let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
                parents[parent.path] = parent.resolvingSymlinksInPath().path
            }
        }
        self.parents = parents
        try preflight()
    }

    private func validateParents() throws {
        for (path, expected) in parents {
            guard URL(fileURLWithPath: path).resolvingSymlinksInPath().path == expected else {
                throw CyberMacError.unsafePath("A planned folder changed its symbolic-link destination. Inspect the mod again.")
            }
        }
    }

    private func verify(_ path: String, hash: String) throws {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              try PathSafety.sha256(url: url) == hash else {
            throw CyberMacError.fileSystem("A planned file changed or is not a regular file: \(url.lastPathComponent). Inspect the mod again.")
        }
    }

    private func device(_ path: String) throws -> dev_t {
        var info = stat()
        guard lstat(path, &info) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return info.st_dev
    }

    private func preflight() throws {
        try validateParents()
        for file in plan.files {
            try verify(file.source, hash: file.installedSHA256)
            try verify(file.backup, hash: file.originalSHA256)
            try verify(file.target, hash: file.originalSHA256)
            guard try device(file.source) == device(file.target), try device(file.backup) == device(file.target) else {
                throw CyberMacError.fileSystem("Replacement and recovery files must be on the game's volume.")
            }
        }
    }

    /// Called again after authorization. Each replacement consumes a fresh clone;
    /// the retained generated file and original backup are never moved or edited.
    public func apply(replace: (URL, URL) throws -> Void) throws {
        try preflight()
        var temporaryDirectories: [URL] = []
        defer { for directory in temporaryDirectories { try? FileManager.default.removeItem(at: directory) } }
        func payload(from path: String, hash: String) throws -> URL {
            let source = URL(fileURLWithPath: path)
            let directory = source.deletingLastPathComponent().appendingPathComponent(".cybermac-place.\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            temporaryDirectories.append(directory)
            let copy = directory.appendingPathComponent("payload")
            try PathSafety.copySpaceEfficiently(from: source, to: copy)
            try verify(copy.path, hash: hash)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: copy.path)
            return copy
        }
        // Prepare both directions before touching any game file.
        let payloads = try plan.files.map { try payload(from: $0.source, hash: $0.installedSHA256) }
        let recovery = try plan.files.map { try payload(from: $0.backup, hash: $0.originalSHA256) }
        try preflight()
        var attempted: [Int] = []
        do {
            for (index, file) in plan.files.enumerated() {
                try validateParents()
                try verify(file.target, hash: file.originalSHA256)
                try verify(payloads[index].path, hash: file.installedSHA256)
                attempted.append(index)
                try replace(URL(fileURLWithPath: file.target), payloads[index])
                try validateParents()
                try verify(file.target, hash: file.installedSHA256)
            }
            try plan.verify()
        } catch {
            let installError = error
            var recoveryErrors: [String] = []
            for index in attempted.reversed() {
                let file = plan.files[index]
                do {
                    try validateParents()
                    // Permission denial commonly happens before the rename.
                    if (try? verify(file.target, hash: file.originalSHA256)) != nil { continue }
                    // Do not overwrite an unknown external change during recovery.
                    try verify(file.target, hash: file.installedSHA256)
                    try verify(recovery[index].path, hash: file.originalSHA256)
                    try replace(URL(fileURLWithPath: file.target), recovery[index])
                    try verify(file.target, hash: file.originalSHA256)
                } catch { recoveryErrors.append(String(describing: error)) }
            }
            if !recoveryErrors.isEmpty {
                throw CyberMacError.fileSystem("\(installError)\nAutomatic recovery could not be verified. Use the saved recovery plan.\n\(recoveryErrors.joined(separator: "\n"))")
            }
            throw installError
        }
    }
}
