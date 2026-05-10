import Foundation
import CryptoKit

public enum PathSafety {
    public static let maxArchiveBytes: UInt64 = 500 * 1024 * 1024
    public static let maxArchiveEntries = 50_000

    public static func expandedURL(from path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    public static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func fileSize(url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values.fileSize ?? 0)
    }
}
