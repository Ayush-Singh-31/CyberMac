import Foundation
import Darwin

/// A local Installer package containing only the files from a validated plan.
/// Apple Installer owns authorization and payload placement; mod ZIP scripts
/// are never copied or executed. Recovery scripts are generated here.
public struct ModInstallerPackage: Sendable {
    public let url: URL
    public let identifier: String
    public let sha256: String
    public let directory: URL

    public static func build(plan: ModInstallTransaction, under root: URL) throws -> Self {
        _ = try NativeModInstallTransaction(plan: plan) // Read-only validation before authorization.
        let bytes = try plan.files.reduce(UInt64(0)) { try $0 + PathSafety.fileSize(url: URL(fileURLWithPath: $1.source)) }
        if bytes > PathSafety.maxArchiveBytes {
            return try buildLocalFilePackage(plan: plan, under: root)
        }
        let identifier = "com.cybermac.mod-files.\(UUID().uuidString.lowercased())"
        let directory = root.appendingPathComponent(identifier)
        let payload = directory.appendingPathComponent("Payload")
        let scripts = directory.appendingPathComponent("Scripts")
        let assets = scripts.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: directory) } }
        for (index, file) in plan.files.enumerated() {
            let relative = String(file.target.dropFirst())
            try PathSafety.validateArchivePath(relative)
            let destination = payload.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PathSafety.copySpaceEfficiently(from: URL(fileURLWithPath: file.source), to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destination.path)
            let backup = assets.appendingPathComponent("original-\(index)")
            try PathSafety.copySpaceEfficiently(from: URL(fileURLWithPath: file.backup), to: backup)
            guard try PathSafety.sha256(url: destination) == file.installedSHA256,
                  try PathSafety.sha256(url: backup) == file.originalSHA256 else {
                throw CyberMacError.fileSystem("A package source changed during preparation. Inspect the mod again.")
            }
        }
        let common = """
        #!/bin/sh
        set -eu
        assets=$(CDPATH= cd -- "$(/usr/bin/dirname -- "$0")/assets" && /bin/pwd -P)
        fail() { printf '%s\\n' "$1" >&2; exit 1; }
        matches() { [ -f "$1" ] && [ ! -L "$1" ] && actual=$(/usr/bin/openssl dgst -sha256 -r "$1") && [ "${actual%% *}" = "$2" ]; }
        """
        var pre = [common,
            "[ \"${3:-/}\" = / ] || fail 'Install on the current startup disk.'",
            "if /usr/bin/pgrep -x \(PathSafety.shellQuoted(plan.executableName)) >/dev/null; then fail 'Fully close Cyberpunk 2077 before installing or restoring mods.'; fi"]
        for (index, file) in plan.files.enumerated() {
            pre.append("matches \"$assets/original-\(index)\" \(PathSafety.shellQuoted(file.originalSHA256)) || fail 'The recovery file is invalid.'")
            pre.append("matches \(PathSafety.shellQuoted(file.target)) \(PathSafety.shellQuoted(file.originalSHA256)) || fail 'Game files changed. Return to CyberMac and inspect the mod again.'")
            let parent = URL(fileURLWithPath: file.target).deletingLastPathComponent()
            let physical = try physicalPath(parent)
            pre.append("[ \"$(cd \(PathSafety.shellQuoted(parent.path)) && /bin/pwd -P)\" = \(PathSafety.shellQuoted(physical)) ] || fail 'The game folder changed its symbolic-link destination.'")
        }
        var post = [common, "failed=0"]
        for file in plan.files {
            post.append("matches \(PathSafety.shellQuoted(file.target)) \(PathSafety.shellQuoted(file.installedSHA256)) || failed=1")
        }
        post += ["if [ \"$failed\" -eq 0 ]; then exit 0; fi", "recovery_failed=0", "restore() {",
            "  source=\"$assets/original-$1\"; target=\"$2\"; expected=\"$3\"",
            "  matches \"$source\" \"$expected\" || return 1",
            "  temporary=$(/usr/bin/mktemp -d \"${target%/*}/.cybermac-recover.XXXXXX\") || return 1",
            "  if /bin/cp -c \"$source\" \"$temporary/payload\" && /bin/chmod 644 \"$temporary/payload\" && /usr/sbin/chown root:wheel \"$temporary/payload\" && /bin/mv -f \"$temporary/payload\" \"$target\"; then result=0; else result=1; fi",
            "  /bin/rm -f \"$temporary/payload\"; /bin/rmdir \"$temporary\"",
            "  [ \"$result\" -eq 0 ] && matches \"$target\" \"$expected\"", "}"]
        for (index, file) in plan.files.enumerated().reversed() {
            let target = PathSafety.shellQuoted(file.target), original = PathSafety.shellQuoted(file.originalSHA256)
            post.append("if matches \(target) \(original); then :; elif matches \(target) \(PathSafety.shellQuoted(file.installedSHA256)); then restore \(index) \(target) \(original) || recovery_failed=1; else recovery_failed=1; fi")
        }
        post += ["if [ \"$recovery_failed\" -ne 0 ]; then fail 'Verification failed. Use the saved recovery plan in CyberMac.'; fi",
                 "fail 'Verification failed; previous files were restored.'"]
        for (name, lines) in [("preinstall", pre), ("postinstall", post)] {
            let script = scripts.appendingPathComponent(name)
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: script)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        }
        // Disable bundle relocation and whole-bundle replacement. This package
        // contains individual cache/config/archive files, never the game app.
        let components = directory.appendingPathComponent("components.plist")
        try PropertyListSerialization.data(fromPropertyList: [], format: .xml, options: 0).write(to: components)
        let url = directory.appendingPathComponent("CyberMac Game Files.pkg")
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pkgbuild"),
            arguments: ["--root", payload.path, "--component-plist", components.path, "--scripts", scripts.path,
                        "--identifier", identifier, "--version", "1.0", "--install-location", "/", "--ownership", "recommended", url.path],
            timeoutSeconds: 180)
        complete = true
        return try Self(url: url, identifier: identifier, sha256: PathSafety.sha256(url: url), directory: directory)
    }

    /// Large clothing archives stay as local APFS clones, rather than being
    /// compressed into multi-gigabyte packages. Installer runs our typed plan
    /// after authorization; its first operation rechecks all hashes and paths.
    private static func buildLocalFilePackage(plan: ModInstallTransaction, under root: URL) throws -> Self {
        let identifier = "com.cybermac.mod-files.\(UUID().uuidString.lowercased())"
        let directory = root.appendingPathComponent(identifier)
        let scripts = directory.appendingPathComponent("Scripts")
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        let script = scripts.appendingPathComponent("postinstall")
        try Data(("#!/bin/sh\n" + plan.command() + "\n").utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let url = directory.appendingPathComponent("CyberMac Game Files.pkg")
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pkgbuild"),
            arguments: ["--nopayload", "--scripts", scripts.path, "--identifier", identifier, "--version", "1.0", "--install-location", "/", url.path], timeoutSeconds: 60)
        return try Self(url: url, identifier: identifier, sha256: PathSafety.sha256(url: url), directory: directory)
    }

    private static func physicalPath(_ url: URL) throws -> String {
        guard let path = url.path.withCString({ realpath($0, nil) }) else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { free(path) }
        return String(cString: path)
    }

    public func verifyPackage() throws {
        guard try PathSafety.sha256(url: url) == sha256 else { throw CyberMacError.fileSystem("The prepared Installer package changed. Inspect the mod again.") }
    }

    public var hasInstallationReceipt: Bool {
        let result = try? ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/sbin/pkgutil"),
            arguments: ["--pkg-info", identifier], timeoutSeconds: 5, allowFailure: true)
        if result?.exitCode == 0 { return true }
        // Successful --nopayload packages have no pkgutil receipt. Installer
        // still commits their unique identifier to the system install history
        // after postinstall succeeds. Never use payload visibility as success.
        let history = URL(fileURLWithPath: "/Library/Receipts/InstallHistory.plist")
        var info = stat()
        guard lstat(history.path, &info) == 0,
              Self.trustedHistoryMetadata(owner: info.st_uid, group: info.st_gid, mode: info.st_mode),
              let data = try? Data(contentsOf: history) else { return false }
        return Self.successRecorded(identifier: identifier, history: data)
    }

    static func trustedHistoryMetadata(owner: uid_t, group: gid_t, mode: mode_t) -> Bool {
        // macOS maintains this as root:admin 0664 on supported installations.
        // Both wheel (0) and admin (80) are system administration groups.
        // Reject world writes and group writes by any other group. A success
        // record is still followed by verification of every planned game file.
        owner == 0 && (mode & S_IFMT) == S_IFREG && (mode & 0o002) == 0 &&
            ((mode & 0o020) == 0 || group == 0 || group == 80)
    }

    static func successRecorded(identifier: String, history: Data) -> Bool {
        guard let records = (try? PropertyListSerialization.propertyList(from: history, format: nil)) as? [[String: Any]] else { return false }
        return records.contains {
            $0["processName"] as? String == "Installer" &&
            ($0["packageIdentifiers"] as? [String])?.contains(identifier) == true
        }
    }
}
