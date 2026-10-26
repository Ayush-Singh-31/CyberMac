import Foundation
import Darwin

/// Typed file replacements, never commands taken from a ZIP. All original,
/// replacement and backup hashes are checked before the first game write.
public struct ModInstallTransaction: Codable, Sendable {
    public struct File: Codable, Sendable {
        public let source: String
        public let target: String
        public let backup: String
        public let originalSHA256: String
        public let installedSHA256: String
        public init(source: String, target: String, backup: String, originalSHA256: String, installedSHA256: String) {
            self.source = source; self.target = target; self.backup = backup
            self.originalSHA256 = originalSHA256; self.installedSHA256 = installedSHA256
        }
    }
    public let gameApp: String
    public let executableName: String
    public let files: [File]

    public init(game: GameInstall, files: [File]) throws {
        guard !files.isEmpty, Set(files.map(\.target)).count == files.count else {
            throw CyberMacError.invalidInput("The install plan is empty or has conflicting destinations.")
        }
        let data = game.dataURL.resolvingSymlinksInPath()
        for file in files {
            let target = URL(fileURLWithPath: file.target)
            try PathSafety.validateContainedPath(target.resolvingSymlinksInPath(), in: data)
            let relative = try PathSafety.relativePath(of: target, in: game.dataURL)
            let allowed = ["r6/cache/final.redscripts", "r6/config/inputContexts_mac.xml",
                           "r6/config/inputContexts.xml", "r6/config/inputUserMappings.xml"]
            guard allowed.contains(relative) || (relative.hasPrefix("archive/Mac/") && target.pathExtension == "archive"),
                  [file.originalSHA256, file.installedSHA256].allSatisfy({ $0.count == 64 && $0.allSatisfy { $0.isHexDigit } }) else {
                throw CyberMacError.unsafePath("The install plan contains an invalid game target or digest.")
            }
        }
        self.gameApp = game.appURL.path; self.executableName = game.executableURL.lastPathComponent; self.files = files
    }

    public func reversed() -> ModInstallTransaction {
        ModInstallTransaction(gameApp: gameApp, executableName: executableName, files: files.map {
            File(source: $0.backup, target: $0.target, backup: $0.source,
                 originalSHA256: $0.installedSHA256, installedSHA256: $0.originalSHA256)
        })
    }

    private init(gameApp: String, executableName: String, files: [File]) {
        self.gameApp = gameApp; self.executableName = executableName; self.files = files
    }

    public func verify() throws {
        for file in files {
            guard try PathSafety.sha256(url: URL(fileURLWithPath: file.target)) == file.installedSHA256 else {
                throw CyberMacError.fileSystem("Installation could not be verified: \(URL(fileURLWithPath: file.target).lastPathComponent)")
            }
        }
    }

    /// Run only through the app's system authorization boundary. Root ownership
    /// is omitted for fixture tests; normal app installs always request it.
    public func command(requiresAdministrator: Bool = true) -> String {
        var lines = ["set -eu", "fail() { printf '%s\\n' \"$1\" >&2; exit 1; }",
            "check() { [ -f \"$1\" ] && [ ! -L \"$1\" ] || fail 'A planned file is missing or is a symbolic link.'; actual=$(/usr/bin/openssl dgst -sha256 -r \"$1\"); [ \"${actual%% *}\" = \"$2\" ] || fail 'A planned file changed. Import the mod again.'; }",
            "if /usr/bin/pgrep -x \(PathSafety.shellQuoted(executableName)) >/dev/null; then fail 'Fully close Cyberpunk 2077 before installing or restoring mods.'; fi"]
        for file in files {
            for (path, hash) in [(file.source, file.installedSHA256), (file.backup, file.originalSHA256), (file.target, file.originalSHA256)] {
                lines.append("check \(PathSafety.shellQuoted(path)) \(PathSafety.shellQuoted(hash))")
                let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
                lines.append("actual_parent=$(cd \(PathSafety.shellQuoted(parent.path)) && /bin/pwd -P)")
                lines.append("[ \"$actual_parent\" = \(PathSafety.shellQuoted(physicalPath(parent))) ] || fail 'A planned folder changed its symbolic-link destination.'")
            }
        }
        lines += ["applied=0", "rollback() {", "  status=$?", "  trap - EXIT INT TERM", "  if [ \"$status\" -ne 0 ]; then", "    rollback_failed=0"]
        for (index, file) in files.enumerated().reversed() {
            let restore = VerifiedFileReplacement.command(source: file.backup, target: file.target,
                sha256: file.originalSHA256, requiresAdministrator: false)
            lines.append("    if [ \"$applied\" -ge \(index + 1) ]; then if ! \(restore); then rollback_failed=1; fi; fi")
        }
        lines += ["    if [ \"$rollback_failed\" -ne 0 ]; then printf '%s\\n' 'Automatic rollback failed. Use the saved recovery plan in CyberMac.' >&2; fi",
                  "  fi", "  exit \"$status\"", "}", "trap rollback EXIT", "trap 'exit 1' INT TERM"]
        for (index, file) in files.enumerated() {
            lines.append("applied=\(index + 1)")
            lines.append(VerifiedFileReplacement.command(source: file.source, target: file.target,
                sha256: file.installedSHA256, requiresAdministrator: false))
            if requiresAdministrator { lines.append("/usr/sbin/chown root:wheel \(PathSafety.shellQuoted(file.target))") }
        }
        lines.append("trap - EXIT INT TERM")
        return lines.joined(separator: "\n")
    }

    // Foundation canonicalizes /private/var back to /var on macOS. The shell's
    // pwd -P uses POSIX realpath, so compare paths from the same representation.
    private func physicalPath(_ url: URL) -> String {
        guard let resolved = url.path.withCString({ realpath($0, nil) }) else { return url.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
