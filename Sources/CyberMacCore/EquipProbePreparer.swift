import Foundation

/// An isolated experiment for one verified build, not a general mod installer.
/// Reuses an existing restore copy and only prints manual game-write commands.
public struct EquipProbePreparer: Sendable {
    static let originalSHA = "7a5a798fe88c5e4afd64b91e265deccd091c2c5c94241003a11abbd70fb6785c"
    static let executableSHA = "8f4a88ad201f360772b3747f51701944f39b98b4ecbf7edc6271c1cc24932844"
    static let compilerSHA = "24f6a1eef2372e950ec55eca0d5370da57d4850241f28efe6166e0e7ac666c64"

    public init() {}

    public func prepare(game: GameInstall, compiler: URL, originalCache: URL,
                        outputDirectory: URL, itemIDs: [String], commandLineTool: URL? = nil) throws -> URL {
        let source = try RedscriptEquipProbeGenerator().source(itemIDs: itemIDs)
        let gameRoot = game.appURL.resolvingSymlinksInPath().standardizedFileURL.path
        for url in [outputDirectory, originalCache] {
            let path = Self.resolvedPath(url)
            guard path != gameRoot, !path.hasPrefix(gameRoot + "/") else {
                throw CyberMacError.unsafePath("Probe output and restore copy must be outside the game app.")
            }
        }
        guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
            throw CyberMacError.invalidInput("Choose a new probe directory; existing experiments are never overwritten.")
        }
        let target = game.appURL.appendingPathComponent("Contents/Data/r6/cache/final.redscripts")
        try Self.verify(game.executableURL, sha256: Self.executableSHA)
        try Self.verify(target, sha256: Self.originalSHA)
        try Self.verify(originalCache, sha256: Self.originalSHA)
        try Self.verify(compiler, sha256: Self.compilerSHA)

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: outputDirectory) } }
        let sourceURL = outputDirectory.appendingPathComponent("CyberMacEquipProbe.reds")
        let compiledURL = outputDirectory.appendingPathComponent("final.redscripts")
        try Data(source.utf8).write(to: sourceURL, options: .atomic)
        let result = try ProcessRunner().run(executableURL: compiler,
            arguments: ["compile", "-s", sourceURL.path, "-b", originalCache.path, "-o", compiledURL.path],
            timeoutSeconds: 60)
        try Data((result.stdout + result.stderr).utf8).write(to: outputDirectory.appendingPathComponent("compile.log"), options: .atomic)
        guard try PathSafety.fileSize(url: compiledURL) > 0 else {
            throw CyberMacError.fileSystem("Compiler did not produce a script cache.")
        }
        let compiledSHA = try PathSafety.sha256(url: compiledURL)
        guard compiledSHA != Self.originalSHA else {
            throw CyberMacError.fileSystem("Compiler returned the unmodified original cache.")
        }
        // Detect changes while compiling, before handing out usable install commands.
        try Self.verify(game.executableURL, sha256: Self.executableSHA)
        try Self.verify(target, sha256: Self.originalSHA)
        try Self.verify(originalCache, sha256: Self.originalSHA)
        try Self.verify(compiler, sha256: Self.compilerSHA)

        for restore in [false, true] {
            let script = Self.manualScript(executable: game.executableURL, target: target,
                compiled: compiledURL, original: originalCache, compiledSHA: compiledSHA, restore: restore)
            let url = outputDirectory.appendingPathComponent(restore ? "Restore Equip Probe.command" : "Install Equip Probe.command")
            try Data(script.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        if let commandLineTool {
            guard FileManager.default.isExecutableFile(atPath: commandLineTool.path) else {
                throw CyberMacError.notFound("CyberMac command-line tool is not executable.")
            }
            let script = Self.combinedScript(executable: game.executableURL, target: target,
                compiled: compiledURL, original: originalCache, compiledSHA: compiledSHA,
                commandLineTool: commandLineTool, directory: outputDirectory)
            let url = outputDirectory.appendingPathComponent("Run Equip Probe.command")
            try Data(script.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        let report: [String: String] = [
            "gameApp": game.appURL.path, "executableSHA256": Self.executableSHA,
            "compilerSHA256": Self.compilerSHA, "originalCache": originalCache.path,
            "originalSHA256": Self.originalSHA, "compiledSHA256": compiledSHA,
            "gameplay": "unverified", "logSink": "unverified", "screenNotification": "unverified",
            "backup": "existing verified restore copy reused; no new backup",
            "scope": "direct MENU/HUD execution markers; record checks; 32 combined equipment/wardrobe observations per restore",
            "probeVersion": "2"
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: outputDirectory.appendingPathComponent("probe.json"), options: .atomic)
        complete = true
        return outputDirectory
    }

    static func verify(_ url: URL, sha256: String) throws {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true,
              try PathSafety.sha256(url: url) == sha256 else {
            throw CyberMacError.invalidInput("Probe integrity check failed: \(url.path)")
        }
    }

    // Foundation does not resolve a directory symlink when its final child does
    // not exist yet. Resolve the existing ancestor before checking containment.
    private static func resolvedPath(_ url: URL) -> String {
        var ancestor = url.standardizedFileURL
        var suffix: [String] = []
        while !FileManager.default.fileExists(atPath: ancestor.path), ancestor.path != "/" {
            suffix.append(ancestor.lastPathComponent)
            ancestor.deleteLastPathComponent()
        }
        var resolved = ancestor.resolvingSymlinksInPath()
        for component in suffix.reversed() { resolved.appendPathComponent(component) }
        return resolved.standardizedFileURL.path
    }

    static func manualScript(executable: URL, target: URL, compiled: URL, original: URL,
                             compiledSHA: String, restore: Bool, pause: Bool = true) -> String {
        let replacement = VerifiedFileReplacement.command(
            source: (restore ? original : compiled).path, target: target.path,
            sha256: restore ? originalSHA : compiledSHA)
        let currentCondition = restore
            ? "[[ \"$current\" == '\(originalSHA)' || \"$current\" == '\(compiledSHA)' ]]"
            : "[[ \"$current\" == '\(originalSHA)' ]]"
        let message = restore
            ? "Original scripts verified. Equip probe removed."
            : "Equip probe installed. Manual test: start recording, launch normally, check the main-menu marker, load a manual save and try clothing plus a wardrobe outfit. Quit and restore afterward."
        return """
        #!/bin/zsh
        set -euo pipefail
        set +e
        /usr/bin/pgrep -x Cyberpunk2077 >/dev/null
        game_status=$?
        set -e
        case "$game_status" in
          0) print 'Fully close Cyberpunk, then run this file again.'; exit 1 ;;
          1) ;;
          *) print 'Could not check whether Cyberpunk is running. No files changed.' >&2; exit 1 ;;
        esac
        verify() {
          [[ -f "$1" && ! -L "$1" ]] || { print 'Expected a regular file.' >&2; exit 1; }
          local actual=$(/usr/bin/shasum -a 256 "$1")
          [[ "${actual%% *}" == "$2" ]] || { print "Integrity check failed: $1" >&2; exit 1; }
        }
        verify \(PathSafety.shellQuoted(executable.path)) '\(executableSHA)'
        verify \(PathSafety.shellQuoted(original.path)) '\(originalSHA)'
        \(restore ? "" : "verify \(PathSafety.shellQuoted(compiled.path)) '\(compiledSHA)'")
        [[ -f \(PathSafety.shellQuoted(target.path)) && ! -L \(PathSafety.shellQuoted(target.path)) ]] || { print 'Script target is missing or is a symlink.' >&2; exit 1; }
        current=$(/usr/bin/shasum -a 256 \(PathSafety.shellQuoted(target.path)))
        current="${current%% *}"
        \(currentCondition) || { print 'Game scripts changed. Stop and review before replacing them.' >&2; exit 1; }
        print 'Files verified. Reusing the existing restore copy; no new backup will be made.'
        sudo -v
        \(replacement)
        print \(PathSafety.shellQuoted(message))
        \(pause ? "read '?Press Return to close this window.'" : "")

        """
    }

    static func combinedScript(executable: URL, target: URL, compiled: URL, original: URL,
                               compiledSHA: String, commandLineTool: URL, directory: URL) -> String {
        let install = manualScript(executable: executable, target: target, compiled: compiled,
            original: original, compiledSHA: compiledSHA, restore: false, pause: false)
        let restore = manualScript(executable: executable, target: target, compiled: compiled,
            original: original, compiledSHA: compiledSHA, restore: true, pause: false)
        return """
        \(install)
        print 'Starting automatic recording and a three-minute startup file-access trace. Only game script-file rows and trace diagnostics are saved.'
        set +e
        \(PathSafety.shellQuoted(commandLineTool.path)) redscript equip-probe run --directory \(PathSafety.shellQuoted(directory.path))
        test_status=$?
        set -e
        if [[ "$test_status" != 0 ]]; then
          print 'The test did not finish successfully. Partial evidence was retained. Restoration will proceed only if the game is closed and hashes match.' >&2
        fi
        \(restore)
        read '?Press Return to close this window.'
        exit "$test_status"

        """
    }
}
