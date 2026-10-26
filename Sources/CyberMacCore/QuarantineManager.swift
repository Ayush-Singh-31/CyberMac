import Foundation
import Darwin

public struct QuarantineManager: Sendable {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func quarantinedPaths(under rootURL: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return [] }
        var result: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        if hasQuarantineAttribute(rootURL) {
            result.append(rootURL)
        }

        while let url = enumerator?.nextObject() as? URL {
            if hasQuarantineAttribute(url) {
                result.append(url)
            }
        }
        return result
    }

    public func hasQuarantineAttribute(_ url: URL) -> Bool {
        // A health refresh must not wait for an external xattr process (or its
        // termination notification). Query the attribute directly, without
        // following symbolic links or removing any macOS protection.
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) >= 0
        }
    }

    public func clearQuarantine(under rootURL: URL) throws -> ProcessResult {
        try runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xattr"),
            arguments: ["-r", "-d", "com.apple.quarantine", rootURL.path],
            timeoutSeconds: 10,
            allowFailure: true
        )
    }
}
