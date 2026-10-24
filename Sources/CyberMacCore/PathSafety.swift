import Foundation
import CryptoKit
import Darwin

public enum PathSafety {
    public static let maxArchiveBytes: UInt64 = 500 * 1024 * 1024
    public static let maxArchiveEntries = 50_000

    /// APFS copy-on-write avoids allocating a second full game archive.
    /// Never silently fall back to a large physical copy on other volumes.
    static func copySpaceEfficiently(from source: URL, to destination: URL) throws {
        let result = try source.withUnsafeFileSystemRepresentation { sourcePath in
            guard let sourcePath else { throw CyberMacError.unsafePath("Invalid copy source.") }
            return try destination.withUnsafeFileSystemRepresentation { destinationPath in
                guard let destinationPath else { throw CyberMacError.unsafePath("Invalid copy destination.") }
                return clonefile(sourcePath, destinationPath, 0)
            }
        }
        guard result != 0 else { return }
        let failure = errno
        guard [EXDEV, ENOTSUP, EINVAL, ENOSYS].contains(failure) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure))
        }
        guard try fileSize(url: source) <= maxArchiveBytes else {
            throw CyberMacError.fileSystem("This volume cannot create a space-saving clone. A full archive copy would exceed 500 MB; choose an APFS workspace on the game's volume.")
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    public static func expandedURL(from path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    public static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func shellDoubleQuoted(_ string: String) -> String {
        "\"" + string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`") + "\""
    }

    public static func sanitizeModID(from rawName: String, date: Date = Date()) -> String {
        let base = rawName
            .lowercased()
            .replacingOccurrences(of: ".zip", with: "")
            .replacingOccurrences(of: ".7z", with: "")
            .replacingOccurrences(of: ".rar", with: "")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(scalars)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.timeZone = TimeZone.current
        let stamp = formatter.string(from: date)
        return "\(cleaned.isEmpty ? "mod" : cleaned)_\(stamp)"
    }

    public static func validateArchivePath(_ path: String) throws {
        if path.isEmpty { throw CyberMacError.unsafePath("Archive entry has an empty path") }
        if path.hasPrefix("/") { throw CyberMacError.unsafePath("Archive entry uses an absolute path: \(path)") }
        if path.contains("\\") { throw CyberMacError.unsafePath("Archive entry uses backslashes: \(path)") }
        if path.split(separator: "/").contains("..") { throw CyberMacError.unsafePath("Archive entry contains traversal: \(path)") }
        if path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            throw CyberMacError.unsafePath("Archive entry contains control characters: \(path)")
        }
    }

    public static func validateArchiveSize(_ url: URL, maxBytes: UInt64 = maxArchiveBytes) throws {
        let size = try fileSize(url: url)
        guard size <= maxBytes else {
            throw CyberMacError.invalidInput("Archive is too large: \(size) bytes exceeds limit of \(maxBytes) bytes")
        }
    }

    public static func validateContainedPath(_ url: URL, in rootURL: URL) throws {
        let root = rootURL.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard target.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("Resolved path escapes destination root: \(target)")
        }
    }

    public static func relativePath(of url: URL, in rootURL: URL) throws -> String {
        let root = rootURL.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard target.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("Path is outside expected root: \(target)")
        }
        return String(target.dropFirst(prefix.count))
    }

    public static func redactUserPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "/Users/<user>")
        }
        return path
    }

    public static func relativeDisplayPath(_ url: URL) -> String {
        redactUserPath(url.path)
    }

    public static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while try autoreleasepool(invoking: { () -> Bool in
            guard let chunk = try handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(string: String) -> String {
        sha256(data: Data(string.utf8))
    }

    public static func fileSize(url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    public static func modificationDate(url: URL) throws -> Date? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }
}
