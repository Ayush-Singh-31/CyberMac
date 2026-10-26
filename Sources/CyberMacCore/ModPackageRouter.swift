import Foundation
import ZIPFoundation

public enum ModPackageRoute: Sendable {
    case scripts
    case clothing(records: [String])
    case appearance(variants: [String])
    case runtime(RuntimeKind)
    case blocked(String)
}

/// One entry point for user packages. Classification never executes package code.
public struct ModPackageRouter: Sendable {
    private let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    public func route(_ url: URL) throws -> ModPackageRoute {
        guard url.isFileURL else { throw CyberMacError.invalidInput("Choose a local ZIP file.") }
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else {
            throw CyberMacError.invalidInput("Choose a regular ZIP or archive file.")
        }
        try PathSafety.validateArchiveSize(url)
        if url.pathExtension.lowercased() == "archive" { return .appearance(variants: []) }
        guard url.pathExtension.lowercased() == "zip" else {
            return .blocked("Choose a .zip or .archive file. Extract RAR or 7z downloads and ZIP their contents first.")
        }
        // Validate the entire ZIP before matching a known recipe or extracting anything.
        let archive = try Archive(url: url, accessMode: .read)
        var total: UInt64 = 0
        var files: [String] = []
        for (index, entry) in archive.enumerated() {
            guard index < PathSafety.maxArchiveEntries else { throw CyberMacError.invalidInput("Too many files in this ZIP.") }
            try PathSafety.validateArchivePath(entry.path)
            guard entry.type != .symlink else { throw CyberMacError.unsafePath("ZIPs containing symbolic links cannot be installed.") }
            guard entry.uncompressedSize <= PathSafety.maxArchiveBytes,
                  total <= PathSafety.maxArchiveBytes * 2 - entry.uncompressedSize else {
                throw CyberMacError.invalidInput("This ZIP expands beyond the 1 GB installation limit.")
            }
            total += entry.uncompressedSize
            if entry.type == .file { files.append(entry.path) }
        }
        let scan = try ModArchiveScanner().scan(zipURL: url)
        let tools = files.filter { URL(fileURLWithPath: $0).lastPathComponent == "scc" }
        let loaders = files.filter { URL(fileURLWithPath: $0).lastPathComponent == "inputloader.pl" }
        if scan.redscriptEntries.isEmpty && scan.archiveEntries.isEmpty && scan.inputMappingEntries.isEmpty {
            if tools.count == 1 && loaders.isEmpty, let entry = archive[tools[0]] {
                var prefix = Data()
                _ = try archive.extract(entry) { if prefix.count < 4 { prefix.append($0.prefix(4 - prefix.count)) } }
                let magic = Array(prefix)
                guard [[UInt8](arrayLiteral: 0xcf, 0xfa, 0xed, 0xfe), [0xfe, 0xed, 0xfa, 0xcf],
                       [0xca, 0xfe, 0xba, 0xbe], [0xbe, 0xba, 0xfe, 0xca]].contains(magic) else {
                    return .blocked("This redscript compiler is not a Mac executable. Drop the macOS redscript release ZIP.")
                }
                return .runtime(.redscript)
            }
            if loaders.count == 1 && tools.isEmpty { return .runtime(.inputLoader) }
        }
        if scan.sidecarInstallable { return .scripts }
        if scan.kind == .archiveOnly && scan.dependencyMarkers.frameworkMarkerLabels.isEmpty {
            do { return .clothing(records: try ClothingWardrobeManager(home: home).pieces(in: url)) }
            catch CyberMacError.unsupported { /* Other packages use the native archive inspection route. */ }
            return .appearance(variants: scan.archiveEntries)
        }
        let frameworks = scan.dependencyMarkers.frameworkMarkerLabels
        if !frameworks.isEmpty {
            return .blocked("This package requires \(frameworks.joined(separator: ", ")). CyberMac cannot run these Windows frameworks on the Mac game. Choose a Mac-compatible version.")
        }
        return .blocked(scan.installBlockReason ?? scan.reasons.joined(separator: " "))
    }

    /// Retain a stable copy so retries survive Downloads moves and access scopes.
    public func retain(_ url: URL) throws -> URL {
        try PathSafety.validateArchiveSize(url)
        let digest = try PathSafety.sha256(url: url)
        let folder = home.homeURL.appendingPathComponent("imports/\(digest)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: url, to: destination)
        }
        guard try PathSafety.sha256(url: destination) == digest else {
            throw CyberMacError.invalidInput("The stored download changed. Remove it and import again.")
        }
        return destination
    }
}
