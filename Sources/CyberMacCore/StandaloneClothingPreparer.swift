import Foundation
import Darwin

/// Build-specific standalone clothing workflow. Preparation writes only outside
/// the game; the user runs the generated, reversible installation command.
public struct StandaloneClothingPreparer {
    struct File: Codable {
        let target: String
        let original: String
        let originalSHA256: String
        let staged: String
        let stagedSHA256: String
    }

    struct Manifest: Codable {
        let gameApp: String
        let files: [File]
        let items: [StandaloneClothingSource.Piece]
        var compiledSHA256: String
        let gameplay: String
        let limitations: String
        var selection: String?
        let compiler: String?
        let originalScripts: String?
    }

    public init() {}

    public func prepare(game: GameInstall, compiler: URL, originalScripts: URL, output: URL,
                        lucyAssets: URL? = nil, originalAppearance: URL? = nil,
                        assetsManifest: URL? = nil, reuseRestoreManifest: URL? = nil) throws -> URL {
        guard lucyAssets == nil || assetsManifest == nil else { throw CyberMacError.invalidInput("Use --assets or --lucy-assets, not both.") }
        let assets = try (assetsManifest ?? lucyAssets).map { try IsolatedClothingAssets(manifestURL: $0) }
        guard assetsManifest == nil || assets?.includesJinguji == true,
              lucyAssets == nil || assets?.includesJinguji == false else {
            throw CyberMacError.invalidInput("Use --assets for the combined wardrobe and --lucy-assets for the legacy Lucy recipe.")
        }
        var originals: [String: URL] = [:]
        if let reuseRestoreManifest {
            let previous = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: reuseRestoreManifest))
            guard EquipProbePreparer.resolvedPath(URL(fileURLWithPath: previous.gameApp)) == EquipProbePreparer.resolvedPath(game.appURL) else {
                throw CyberMacError.invalidInput("Restore files belong to another installation.")
            }
            for file in previous.files {
                let name = URL(fileURLWithPath: file.target).lastPathComponent
                let original = URL(fileURLWithPath: file.original)
                guard originals[name] == nil, !EquipProbePreparer.resolvedPath(original).hasPrefix(EquipProbePreparer.resolvedPath(game.appURL) + "/") else {
                    throw CyberMacError.unsafePath("Restore files must be unambiguous and outside the game.")
                }
                originals[name] = original
            }
        }
        let gameRoot = game.appURL.resolvingSymlinksInPath().path
        let resolved = EquipProbePreparer.resolvedPath(output)
        guard resolved != gameRoot, !resolved.hasPrefix(gameRoot + "/"),
              !FileManager.default.fileExists(atPath: output.path) else {
            throw CyberMacError.unsafePath("Use a new clothing workspace outside the game.")
        }
        try EquipProbePreparer.verify(game.executableURL, sha256: EquipProbePreparer.executableSHA)
        try EquipProbePreparer.verify(compiler, sha256: EquipProbePreparer.compilerSHA)
        try EquipProbePreparer.verify(originalScripts, sha256: EquipProbePreparer.originalSHA)
        let gameScripts = game.appURL.appendingPathComponent("Contents/Data/r6/cache/final.redscripts")
        try EquipProbePreparer.verify(gameScripts, sha256: EquipProbePreparer.originalSHA)
        let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources")), format: nil) as? [String: Any]
        guard let seals = seal?["files2"] as? [String: Any] else { throw CyberMacError.invalidInput("Game resource seal is missing.") }
        let auxiliary = gameScripts.deletingLastPathComponent().appendingPathComponent("cybermac-standalone.redscripts")
        guard !FileManager.default.fileExists(atPath: auxiliary.path),
              (try? auxiliary.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw CyberMacError.invalidInput("Remove the previous standalone helper with its cleanup command first.")
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: output) } }
        var files: [File] = []
        var receipts: [AddonProbeTweakDBCloneRecordReport] = []
        let pieces = assets?.pieces ?? StandaloneClothingSource.pieces
        let wardrobe = assets?.includesJinguji == true
        // Compile before staging large archives/databases so invalid helpers fail early.
        let source = output.appendingPathComponent("StandaloneClothing.reds")
        try Data(StandaloneClothingSource.render(pieces: pieces, showPhysicalClothes: assets != nil,
            delivery: wardrobe ? StandaloneClothingSource.jingujiPieces : nil, autoEquip: !wardrobe).utf8).write(to: source)
        let compiled = output.appendingPathComponent("clothing.redscripts")
        let result = try ProcessRunner().run(executableURL: compiler,
            arguments: ["compile", "-s", source.path, "-b", originalScripts.path, "-o", compiled.path], timeoutSeconds: 60)
        try Data((result.stdout + result.stderr).utf8).write(to: output.appendingPathComponent("compile.log"))
        guard try PathSafety.fileSize(url: compiled) > 0 else { throw CyberMacError.invalidInput("Compiler produced an empty clothing cache.") }
        let compiledSHA = try PathSafety.sha256(url: compiled)
        guard compiledSHA != EquipProbePreparer.originalSHA else { throw CyberMacError.invalidInput("Clothing helper is unmodified.") }
        if let assets {
            files += try assets.stage(game: game, output: output,
                originalAppearance: originalAppearance ?? originals["basegame_4_appearance.archive"], seals: seals, originals: originals)
        } else if originalAppearance != nil {
            throw CyberMacError.invalidInput("--original-appearance requires an asset manifest.")
        }
        for filename in ["tweakdb.bin", "tweakdb_ep1.bin"] {
            let relative = "Data/r6/cache/\(filename)"
            guard let entry = seals[relative] as? [String: Any], let hash = entry["hash2"] as? Data, hash.count == 32 else {
                throw CyberMacError.unsupported("No resource seal for \(filename).")
            }
            let originalSHA = hash.map { String(format: "%02x", $0) }.joined()
            let target = game.appURL.appendingPathComponent("Contents/\(relative)")
            try EquipProbePreparer.verify(target, sha256: originalSHA)
            let backup = originals[filename] ?? output.appendingPathComponent("original-\(filename)")
            if originals[filename] == nil { try PathSafety.copySpaceEfficiently(from: target, to: backup) }
            try EquipProbePreparer.verify(backup, sha256: originalSHA)
            var current = backup
            for (index, piece) in pieces.enumerated() {
                let folder = output.appendingPathComponent("\(filename)-piece-\(index)")
                let report = try TweakDBCloneRecordStager().stage(request: .init(fileURL: current,
                    outputDirectoryURL: folder, sourceRecord: piece.source, newRecord: piece.record,
                    overrides: piece.entityName.map { [
                        .cName(property: "entityName", value: $0),
                        .cName(property: "appearanceName", value: $0 + "_")
                    ] } ?? []))
                guard report.conclusions.contains(.newRecordResolved), report.stagedRecordsSortedByID,
                      report.touchedFlatKeyTables.allSatisfy(\.keyTableSortedByID) else {
                    throw CyberMacError.invalidInput("Cloned clothing did not pass structural checks: \(piece.record)")
                }
                receipts.append(report)
                if current != backup { try FileManager.default.removeItem(at: current) }
                current = URL(fileURLWithPath: report.stagedFilePath)
            }
            // Later inserts must not discard an earlier cloned record.
            let final = output.appendingPathComponent(filename)
            try FileManager.default.moveItem(at: current, to: final)
            for (index, piece) in pieces.enumerated() {
                let report = try TweakDBStructureInspector().trace(request: .init(fileURL: final,
                    record: piece.record, outputDirectoryURL: output.appendingPathComponent("\(filename)-final-\(index)")))
                guard report.trace.recordTableEntry != nil else { throw CyberMacError.invalidInput("Final cache lost \(piece.record).") }
            }
            try EquipProbePreparer.verify(target, sha256: originalSHA)
            files.append(File(target: target.path, original: backup.path, originalSHA256: originalSHA,
                staged: final.path, stagedSHA256: try PathSafety.sha256(url: final)))
        }
        try EquipProbePreparer.verify(game.executableURL, sha256: EquipProbePreparer.executableSHA)
        try EquipProbePreparer.verify(compiler, sha256: EquipProbePreparer.compilerSHA)
        try EquipProbePreparer.verify(originalScripts, sha256: EquipProbePreparer.originalSHA)
        try EquipProbePreparer.verify(gameScripts, sha256: EquipProbePreparer.originalSHA)
        for file in files { try EquipProbePreparer.verify(URL(fileURLWithPath: file.target), sha256: file.originalSHA256) }
        try Self.writeCommands(files: files, game: game, output: output, compiledSHA: compiledSHA, lucy: assets != nil, inventoryOnly: wardrobe)
        try JSONEncoder.cybermac.encode(Manifest(gameApp: game.appURL.path, files: files,
            items: pieces, compiledSHA256: compiledSHA,
            gameplay: wardrobe ? "Jinguji gameplay unverified; Lucy assets retained; selected grants only; equipment and wardrobe unchanged" : (assets == nil ? "unverified; new records keep vanilla appearances and donor icon lookup" : "isolated Lucy assets for feminine V; donor icon lookup; active wardrobe set disabled for test"),
            limitations: "Offline TweakDB writer preserves the original records checksum. New recipes require gameplay verification.",
            selection: wardrobe ? "jinguji" : nil, compiler: wardrobe ? compiler.path : nil,
            originalScripts: wardrobe ? originalScripts.path : nil)).write(to: output.appendingPathComponent("clothing.json"))
        try JSONEncoder.cybermac.encode(receipts).write(to: output.appendingPathComponent("clone-receipts.json"))
        complete = true
        return output
    }

    /// Refresh small launch/recovery scripts while reusing every existing payload.
    public func refreshCommands(game: GameInstall, output: URL) throws {
        try refreshCommands(game: game, output: output, verifyPayloads: true, verifyHelper: true)
    }

    /// Recompile only the small helper. Assets, databases and restore copies stay
    /// unchanged. The launch command verifies every payload before installation.
    public func selectClothes(game: GameInstall, output: URL, group: String) throws {
        let delivery = try StandaloneClothingSource.selectedPieces(group: group)
        let root = EquipProbePreparer.resolvedPath(output), gameRoot = EquipProbePreparer.resolvedPath(game.appURL)
        guard root != gameRoot, !root.hasPrefix(gameRoot + "/") else {
            throw CyberMacError.unsafePath("Clothing selection workspace must be outside the game.")
        }
        let manifestURL = output.appendingPathComponent("clothing.json")
        var manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.selection != nil, manifest.items == StandaloneClothingSource.wardrobePieces,
              let compilerPath = manifest.compiler, let originalPath = manifest.originalScripts else {
            throw CyberMacError.invalidInput("Selection needs a prepared Lucy and Jinguji wardrobe.")
        }
        let lock = output.appendingPathComponent(".selection-lock")
        // Exclusive mkdir also prevents two selectors from replacing the helper
        // together; generated launchers refuse to install while it exists.
        guard mkdir(lock.path, 0o700) == 0 else {
            throw CyberMacError.invalidInput("A clothing selection is already running, or its lock remains after an interrupted selection: \(lock.path)")
        }
        defer { try? FileManager.default.removeItem(at: lock) }
        try refreshCommands(game: game, output: output, verifyPayloads: false, verifyHelper: false)
        let compiler = URL(fileURLWithPath: compilerPath), original = URL(fileURLWithPath: originalPath)
        try EquipProbePreparer.verify(compiler, sha256: EquipProbePreparer.compilerSHA)
        try EquipProbePreparer.verify(original, sha256: EquipProbePreparer.originalSHA)
        let source = lock.appendingPathComponent("SelectedClothing.reds")
        let compiled = lock.appendingPathComponent("clothing.redscripts")
        let text = StandaloneClothingSource.render(pieces: manifest.items, delivery: delivery, autoEquip: false)
        try Data(text.utf8).write(to: source)
        let result = try ProcessRunner().run(executableURL: compiler,
            arguments: ["compile", "-s", source.path, "-b", original.path, "-o", compiled.path], timeoutSeconds: 60)
        try Data((result.stdout + result.stderr).utf8).write(to: output.appendingPathComponent("selection-compile.log"), options: .atomic)
        guard try PathSafety.fileSize(url: compiled) > 0 else { throw CyberMacError.invalidInput("Compiler produced an empty clothing helper.") }
        let digest = try PathSafety.sha256(url: compiled)
        guard digest != EquipProbePreparer.originalSHA else { throw CyberMacError.invalidInput("Selection helper is unmodified.") }
        try EquipProbePreparer.verify(compiler, sha256: EquipProbePreparer.compilerSHA)
        try EquipProbePreparer.verify(original, sha256: EquipProbePreparer.originalSHA)
        // Atomic replacement avoids retaining a cache for each combination. If a
        // later metadata write fails, the prior launcher refuses its hash; select
        // can be retried without touching any game files.
        try Data(contentsOf: compiled).write(to: output.appendingPathComponent("clothing.redscripts"), options: .atomic)
        try Data(text.utf8).write(to: output.appendingPathComponent("StandaloneClothing.reds"), options: .atomic)
        manifest.compiledSHA256 = digest; manifest.selection = group
        try JSONEncoder.cybermac.encode(manifest).write(to: manifestURL, options: .atomic)
        try Self.writeCommands(files: manifest.files, game: game, output: output, compiledSHA: digest, lucy: true, inventoryOnly: true)
    }

    public func writeClothingChooser(game: GameInstall, output: URL, commandLineTool: URL) throws {
        let text = Self.chooserScript(game: game, output: output, commandLineTool: commandLineTool)
        let file = output.appendingPathComponent("Choose Clothes and Play.command")
        try Data(text.utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    static func chooserScript(game: GameInstall, output: URL, commandLineTool: URL) -> String {
        """
        #!/bin/zsh
        set -euo pipefail
        print 'Choose clothes to add (items already in your inventory are skipped):'
        print '1) Jinguji corset, Judy pants and chrome heels'
        print '2) Lucy jacket, top, pants and boots'
        print '3) Both collections'
        print '4) Add nothing; keep support for clothing already in your save'
        read -r 'choice?Choose [1]: '
        case "$choice" in
          ''|1) group=jinguji ;;
          2) group=lucy ;;
          3) group=both ;;
          4) group=none ;;
          *) print 'Invalid choice; nothing changed.' >&2; exit 1 ;;
        esac
        print 'Preparing your selection. Large outfit files and restore copies are reused.'
        \(PathSafety.shellQuoted(commandLineTool.path)) clothing select --out-dir \(PathSafety.shellQuoted(output.path)) --game-app \(PathSafety.shellQuoted(game.appURL.path)) --group "$group"
        exec /bin/zsh \(PathSafety.shellQuoted(output.appendingPathComponent("Run New Clothing.command").path))
        """
    }

    private func refreshCommands(game: GameInstall, output: URL, verifyPayloads: Bool, verifyHelper: Bool) throws {
        struct Manifest: Decodable {
            let gameApp: String
            let files: [File]
            let compiledSHA256: String
            let selection: String?
        }
        let root = EquipProbePreparer.resolvedPath(output)
        let gameRoot = EquipProbePreparer.resolvedPath(game.appURL)
        guard root != gameRoot, !root.hasPrefix(gameRoot + "/") else { throw CyberMacError.unsafePath("Clothing workspace must be outside the game.") }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: output.appendingPathComponent("clothing.json")))
        guard manifest.compiledSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              manifest.files.allSatisfy({ $0.stagedSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil }) else {
            throw CyberMacError.invalidInput("Prepared clothing hashes are malformed.")
        }
        guard EquipProbePreparer.resolvedPath(URL(fileURLWithPath: manifest.gameApp)) == gameRoot else {
            throw CyberMacError.invalidInput("Prepared workspace belongs to another game installation.")
        }
        let baseTargets = Set(["Data/r6/cache/tweakdb.bin", "Data/r6/cache/tweakdb_ep1.bin"])
        let lucyTargets = baseTargets.union(["Data/archive/Mac/content/basegame_4_gamedata.archive", "Data/archive/Mac/content/basegame_4_appearance.archive"])
        let contents = game.appURL.appendingPathComponent("Contents")
        let expectedBase = Set(baseTargets.map { contents.appendingPathComponent($0).path })
        let expectedLucy = Set(lucyTargets.map { contents.appendingPathComponent($0).path })
        let targets = Set(manifest.files.map(\.target))
        guard targets.count == manifest.files.count, targets == expectedBase || targets == expectedLucy else {
            throw CyberMacError.invalidInput("Prepared clothing targets are not recognized.")
        }
        let process = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-x", "Cyberpunk2077"], timeoutSeconds: 5, allowFailure: true)
        guard process.exitCode == 1 else { throw CyberMacError.invalidInput("Fully close the game before refreshing clothing commands; process checks must succeed.") }
        for name in ["Run New Clothing.command", "Restore New Clothing.command"] {
            let pattern = NSRegularExpression.escapedPattern(for: output.appendingPathComponent(name).path)
            let running = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
                arguments: ["-f", pattern], timeoutSeconds: 5, allowFailure: true)
            guard running.exitCode == 1 else { throw CyberMacError.invalidInput("Wait for the existing clothing command to finish before refreshing it.") }
        }
        try EquipProbePreparer.verify(game.executableURL, sha256: EquipProbePreparer.executableSHA)
        try EquipProbePreparer.verify(contents.appendingPathComponent("Data/r6/cache/final.redscripts"), sha256: EquipProbePreparer.originalSHA)
        let auxiliary = contents.appendingPathComponent("Data/r6/cache/cybermac-standalone.redscripts")
        guard !FileManager.default.fileExists(atPath: auxiliary.path),
              (try? auxiliary.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw CyberMacError.invalidInput("Finish the previous clothing cleanup first.")
        }
        let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: contents.appendingPathComponent("_CodeSignature/CodeResources")), format: nil) as? [String: Any]
        guard let seals = seal?["files2"] as? [String: Any] else { throw CyberMacError.invalidInput("Game resource seal is missing.") }
        for file in manifest.files {
            let target = URL(fileURLWithPath: file.target)
            let staged = output.appendingPathComponent(target.lastPathComponent)
            let relative = String(file.target.dropFirst(contents.path.count + 1))
            guard let entry = seals[relative] as? [String: Any], let digest = entry["hash2"] as? Data,
                  digest.map({ String(format: "%02x", $0) }).joined() == file.originalSHA256,
                  file.staged == staged.path,
                  !EquipProbePreparer.resolvedPath(URL(fileURLWithPath: file.original)).hasPrefix(gameRoot + "/") else {
                throw CyberMacError.invalidInput("Prepared file paths or original seal do not match.")
            }
            if verifyPayloads {
                try EquipProbePreparer.verify(target, sha256: file.originalSHA256)
                try EquipProbePreparer.verify(URL(fileURLWithPath: file.original), sha256: file.originalSHA256)
                try EquipProbePreparer.verify(staged, sha256: file.stagedSHA256)
            }
        }
        if verifyHelper { try EquipProbePreparer.verify(output.appendingPathComponent("clothing.redscripts"), sha256: manifest.compiledSHA256) }
        try Self.writeCommands(files: manifest.files, game: game, output: output, compiledSHA: manifest.compiledSHA256, lucy: targets == expectedLucy, inventoryOnly: manifest.selection != nil)
    }

    private static func writeCommands(files: [File], game: GameInstall, output: URL, compiledSHA: String, lucy: Bool, inventoryOnly: Bool = false) throws {
        let gameScripts = game.appURL.appendingPathComponent("Contents/Data/r6/cache/final.redscripts")
        let auxiliary = gameScripts.deletingLastPathComponent().appendingPathComponent("cybermac-standalone.redscripts")
        let restoreURL = output.appendingPathComponent("Restore New Clothing.command")
        let restore = Self.restoreScript(files: files, executable: game.executableURL, scripts: gameScripts,
            auxiliary: auxiliary, compiledSHA: compiledSHA)
        let run = Self.runScript(files: files, game: game, scripts: gameScripts, auxiliary: auxiliary,
            compiled: output.appendingPathComponent("clothing.redscripts"), compiledSHA: compiledSHA, restore: restoreURL, lucy: lucy, inventoryOnly: inventoryOnly)
        for (name, contents) in [(restoreURL.lastPathComponent, restore), ("Run New Clothing.command", run)] {
            let file = output.appendingPathComponent(name)
            try Data(contents.utf8).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
    }

    static func preamble(executable: URL, scripts: URL) -> String {
        """
        #!/bin/zsh
        set -euo pipefail
        closed() {
          local game_status=0
          /usr/bin/pgrep -x Cyberpunk2077 >/dev/null || game_status=$?
          [[ "$game_status" == 1 ]] || { print 'Fully close Cyberpunk before changing clothing files.' >&2; return 1; }
        }
        file_hash() {
          [[ -f "$1" && ! -L "$1" ]] || { print "Not a regular file: $1" >&2; return 1; }
          local hash
          hash=$(/usr/bin/openssl dgst -sha256 -r "$1") || return 1
          print -r -- "${hash%% *}"
        }
        verify() {
          local hash
          hash=$(file_hash "$1") || return 1
          [[ "$hash" == "$2" ]] || { print "Integrity check failed: $1" >&2; return 1; }
        }
        file_state() {
          /usr/bin/stat -f '%d:%i:%z:%m:%c' "$1"
        }
        closed
        verify \(PathSafety.shellQuoted(executable.path)) '\(EquipProbePreparer.executableSHA)'
        verify \(PathSafety.shellQuoted(scripts.path)) '\(EquipProbePreparer.originalSHA)'
        """
    }

    static func restoreScript(files: [File], executable: URL, scripts: URL, auxiliary: URL, compiledSHA: String) -> String {
        var result = preamble(executable: executable, scripts: scripts) + "\ntypeset -a restore_needed restore_states\nneeds_admin=0\n"
        for file in files {
            let target = PathSafety.shellQuoted(file.target)
            result += "print -r -- \(PathSafety.shellQuoted("Checking restore: " + URL(fileURLWithPath: file.target).lastPathComponent))\n"
            result += "restore_states+=(\"$(file_state \(target))\")\ncurrent=$(file_hash \(target))\n"
            result += "[[ \"$(file_state \(target))\" == \"${restore_states[-1]}\" ]] || { print 'Game file changed during verification; cleanup stopped.' >&2; exit 1; }\n"
            result += "case \"$current\" in\n '\(file.originalSHA256)') restore_needed+=(0) ;;\n '\(file.stagedSHA256)') verify \(PathSafety.shellQuoted(file.original)) '\(file.originalSHA256)'; restore_needed+=(1); needs_admin=1 ;;\n *) print 'Unknown game file hash; cleanup stopped.' >&2; exit 1 ;;\nesac\n"
        }
        result += "if [[ -e \(PathSafety.shellQuoted(auxiliary.path)) || -L \(PathSafety.shellQuoted(auxiliary.path)) ]]; then verify \(PathSafety.shellQuoted(auxiliary.path)) '\(compiledSHA)'; needs_admin=1; fi\nif [[ \"$needs_admin\" == 1 ]]; then sudo -v; fi\n"
        // State is reused only within this invocation, never cached across runs.
        // Detect intervening replacement/updates before either placing or skipping.
        for (index, file) in files.enumerated() {
            result += "[[ \"$(file_state \(PathSafety.shellQuoted(file.target)))\" == \"${restore_states[\(index + 1)]}\" ]] || { print 'Game file changed after verification; cleanup stopped.' >&2; exit 1; }\n"
            result += "if [[ \"${restore_needed[\(index + 1)]}\" == 1 ]]; then\n"
            result += "print -r -- \(PathSafety.shellQuoted("Restoring: " + URL(fileURLWithPath: file.target).lastPathComponent))\n"
            result += VerifiedFileReplacement.command(source: file.original, target: file.target, sha256: file.originalSHA256) + "\nfi\n"
        }
        result += "if [[ -f \(PathSafety.shellQuoted(auxiliary.path)) ]]; then sudo /bin/rm -- \(PathSafety.shellQuoted(auxiliary.path)); fi\n"
        result += "print 'Finished. Original game files verified and restored; temporary helper removed. You can close this window.'\n"
        return result
    }

    static func runScript(files: [File], game: GameInstall, scripts: URL, auxiliary: URL, compiled: URL,
                          compiledSHA: String, restore: URL, lucy: Bool = false, inventoryOnly: Bool = false) -> String {
        var result = preamble(executable: game.executableURL, scripts: scripts) + "\n"
        result += "[[ ! -e \(PathSafety.shellQuoted(restore.deletingLastPathComponent().appendingPathComponent(".selection-lock").path)) ]] || { print 'Clothing selection is being prepared. Wait for it to finish.' >&2; exit 1; }\n"
        for file in files {
            result += "print -r -- \(PathSafety.shellQuoted("Checking: " + URL(fileURLWithPath: file.target).lastPathComponent))\n"
            result += "verify \(PathSafety.shellQuoted(file.target)) '\(file.originalSHA256)'\nverify \(PathSafety.shellQuoted(file.original)) '\(file.originalSHA256)'\nverify \(PathSafety.shellQuoted(file.staged)) '\(file.stagedSHA256)'\n"
        }
        result += "verify \(PathSafety.shellQuoted(compiled.path)) '\(compiledSHA)'\n"
        result += "[[ ! -e \(PathSafety.shellQuoted(auxiliary.path)) && ! -L \(PathSafety.shellQuoted(auxiliary.path)) ]] || { print 'Temporary clothing cache already exists.' >&2; exit 1; }\n"
        result += "sudo -v\ncleanup() {\n local result=$?\n trap - EXIT\n /bin/zsh \(PathSafety.shellQuoted(restore.path)) || { print 'Automatic cleanup stopped; run Restore New Clothing.command after closing the game.' >&2; exit 1; }\n exit \"$result\"\n}\ntrap cleanup EXIT\ntrap 'exit 130' INT TERM\n"
        for file in files {
            result += "print -r -- \(PathSafety.shellQuoted("Installing: " + URL(fileURLWithPath: file.target).lastPathComponent))\n"
            result += VerifiedFileReplacement.command(source: file.staged, target: file.target, sha256: file.stagedSHA256) + "\n"
        }
        result += VerifiedFileReplacement.command(source: compiled.path, target: auxiliary.path, sha256: compiledSHA, requiresAbsentDestination: true) + "\n"
        if inventoryOnly {
            result += "print 'Lucy and Jinguji item records installed. Load a manual save; only your selected clothes will be added. Equip them yourself in clothing inventory.'\n"
            result += "print 'Active wardrobe outfits can hide equipped clothing; turn the wardrobe outfit off to see your selected pieces. Keep your reference save untouched.'\n"
        } else {
            result += "print 'Four NEW clothing records installed. Load a manual save; the clothes will be added and equipment requested after three seconds.'\n"
            result += "print 'Keep your reference save untouched. \(lucy ? "Lucy uses unique appearance names and donor icon lookup. An active wardrobe set is disabled for this test; saved presets are kept." : "These are separate records with vanilla looks. Active wardrobe outfits can hide the equipped pieces.")'\n"
        }
        result += "/usr/bin/open -W \(PathSafety.shellQuoted(game.appURL.path)) --args \(PathSafety.shellQuoted("-scriptsBlobPath=" + auxiliary.path))\n"
        return result
    }
}
