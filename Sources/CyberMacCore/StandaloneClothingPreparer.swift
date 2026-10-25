import Foundation

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

    public init() {}

    public func prepare(game: GameInstall, compiler: URL, originalScripts: URL, output: URL,
                        lucyAssets: URL? = nil, originalAppearance: URL? = nil) throws -> URL {
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
        let assets = try lucyAssets.map { try LucyClothingAssets(manifestURL: $0) }
        let pieces = assets == nil ? StandaloneClothingSource.pieces : StandaloneClothingSource.lucyPieces
        if let assets {
            files += try assets.stage(game: game, output: output, originalAppearance: originalAppearance, seals: seals)
        } else if originalAppearance != nil {
            throw CyberMacError.invalidInput("--original-appearance requires --lucy-assets.")
        }
        for filename in ["tweakdb.bin", "tweakdb_ep1.bin"] {
            let relative = "Data/r6/cache/\(filename)"
            guard let entry = seals[relative] as? [String: Any], let hash = entry["hash2"] as? Data, hash.count == 32 else {
                throw CyberMacError.unsupported("No resource seal for \(filename).")
            }
            let originalSHA = hash.map { String(format: "%02x", $0) }.joined()
            let target = game.appURL.appendingPathComponent("Contents/\(relative)")
            try EquipProbePreparer.verify(target, sha256: originalSHA)
            let backup = output.appendingPathComponent("original-\(filename)")
            try PathSafety.copySpaceEfficiently(from: target, to: backup)
            try EquipProbePreparer.verify(backup, sha256: originalSHA)
            var current = backup
            for (index, piece) in pieces.enumerated() {
                let folder = output.appendingPathComponent("\(filename)-piece-\(index)")
                let report = try TweakDBCloneRecordStager().stage(request: .init(fileURL: current,
                    outputDirectoryURL: folder, sourceRecord: piece.source, newRecord: piece.record,
                    overrides: assets == nil ? [] : [.cName(property: "entityName", value: "cybermac_lucy_" + ["jacket", "top", "pants", "boots"][index])]))
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
            for (index, piece) in StandaloneClothingSource.pieces.enumerated() {
                let report = try TweakDBStructureInspector().trace(request: .init(fileURL: final,
                    record: piece.record, outputDirectoryURL: output.appendingPathComponent("\(filename)-final-\(index)")))
                guard report.trace.recordTableEntry != nil else { throw CyberMacError.invalidInput("Final cache lost \(piece.record).") }
            }
            try EquipProbePreparer.verify(target, sha256: originalSHA)
            files.append(File(target: target.path, original: backup.path, originalSHA256: originalSHA,
                staged: final.path, stagedSHA256: try PathSafety.sha256(url: final)))
        }
        let source = output.appendingPathComponent("StandaloneClothing.reds")
        try Data(StandaloneClothingSource.render(pieces: pieces).utf8).write(to: source)
        let compiled = output.appendingPathComponent("clothing.redscripts")
        let result = try ProcessRunner().run(executableURL: compiler,
            arguments: ["compile", "-s", source.path, "-b", originalScripts.path, "-o", compiled.path], timeoutSeconds: 60)
        try Data((result.stdout + result.stderr).utf8).write(to: output.appendingPathComponent("compile.log"))
        guard try PathSafety.fileSize(url: compiled) > 0 else { throw CyberMacError.invalidInput("Compiler produced an empty clothing cache.") }
        let compiledSHA = try PathSafety.sha256(url: compiled)
        guard compiledSHA != EquipProbePreparer.originalSHA else { throw CyberMacError.invalidInput("Clothing helper is unmodified.") }
        try EquipProbePreparer.verify(game.executableURL, sha256: EquipProbePreparer.executableSHA)
        try EquipProbePreparer.verify(compiler, sha256: EquipProbePreparer.compilerSHA)
        try EquipProbePreparer.verify(originalScripts, sha256: EquipProbePreparer.originalSHA)
        try EquipProbePreparer.verify(gameScripts, sha256: EquipProbePreparer.originalSHA)
        for file in files { try EquipProbePreparer.verify(URL(fileURLWithPath: file.target), sha256: file.originalSHA256) }
        let restoreURL = output.appendingPathComponent("Restore New Clothing.command")
        let restore = Self.restoreScript(files: files, executable: game.executableURL, scripts: gameScripts,
            auxiliary: auxiliary, compiledSHA: compiledSHA)
        let run = Self.runScript(files: files, game: game, scripts: gameScripts, auxiliary: auxiliary,
            compiled: compiled, compiledSHA: compiledSHA, restore: restoreURL, lucy: assets != nil)
        for (name, contents) in [(restoreURL.lastPathComponent, restore), ("Run New Clothing.command", run)] {
            let file = output.appendingPathComponent(name)
            try Data(contents.utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        struct Manifest: Encodable {
            let gameApp: String
            let files: [File]
            let items: [StandaloneClothingSource.Piece]
            let compiledSHA256: String
            let gameplay: String
            let limitations = "Offline TweakDB writer preserves the original records checksum. Runtime record acceptance, inventory display and equipment require the combined test."
        }
        try JSONEncoder.cybermac.encode(Manifest(gameApp: game.appURL.path, files: files,
            items: pieces, compiledSHA256: compiledSHA,
            gameplay: assets == nil ? "unverified; new records keep vanilla appearances and icons" : "unverified; isolated Lucy outfit for feminine V; original inventory icons retained")).write(to: output.appendingPathComponent("clothing.json"))
        try JSONEncoder.cybermac.encode(receipts).write(to: output.appendingPathComponent("clone-receipts.json"))
        complete = true
        return output
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
        verify() {
          [[ -f "$1" && ! -L "$1" ]] || { print "Not a regular file: $1" >&2; return 1; }
          local hash=$(/usr/bin/shasum -a 256 "$1")
          [[ "${hash%% *}" == "$2" ]] || { print "Integrity check failed: $1" >&2; return 1; }
        }
        closed
        verify \(PathSafety.shellQuoted(executable.path)) '\(EquipProbePreparer.executableSHA)'
        verify \(PathSafety.shellQuoted(scripts.path)) '\(EquipProbePreparer.originalSHA)'
        """
    }

    static func restoreScript(files: [File], executable: URL, scripts: URL, auxiliary: URL, compiledSHA: String) -> String {
        var result = preamble(executable: executable, scripts: scripts) + "\n"
        for file in files {
            result += "verify \(PathSafety.shellQuoted(file.original)) '\(file.originalSHA256)'\n"
            result += "verify \(PathSafety.shellQuoted(file.target)) '\(file.originalSHA256)' 2>/dev/null || verify \(PathSafety.shellQuoted(file.target)) '\(file.stagedSHA256)'\n"
        }
        result += "if [[ -e \(PathSafety.shellQuoted(auxiliary.path)) || -L \(PathSafety.shellQuoted(auxiliary.path)) ]]; then verify \(PathSafety.shellQuoted(auxiliary.path)) '\(compiledSHA)'; fi\nsudo -v\n"
        for file in files {
            result += "if ! verify \(PathSafety.shellQuoted(file.target)) '\(file.originalSHA256)' 2>/dev/null; then\n"
            result += VerifiedFileReplacement.command(source: file.original, target: file.target, sha256: file.originalSHA256) + "\nfi\n"
        }
        result += "if [[ -f \(PathSafety.shellQuoted(auxiliary.path)) ]]; then sudo /bin/rm -- \(PathSafety.shellQuoted(auxiliary.path)); fi\n"
        result += "print 'Original game files verified and restored. Temporary clothing helper removed.'\n"
        return result
    }

    static func runScript(files: [File], game: GameInstall, scripts: URL, auxiliary: URL, compiled: URL,
                          compiledSHA: String, restore: URL, lucy: Bool = false) -> String {
        var result = preamble(executable: game.executableURL, scripts: scripts) + "\n"
        for file in files {
            result += "verify \(PathSafety.shellQuoted(file.target)) '\(file.originalSHA256)'\nverify \(PathSafety.shellQuoted(file.original)) '\(file.originalSHA256)'\nverify \(PathSafety.shellQuoted(file.staged)) '\(file.stagedSHA256)'\n"
        }
        result += "verify \(PathSafety.shellQuoted(compiled.path)) '\(compiledSHA)'\n"
        result += "[[ ! -e \(PathSafety.shellQuoted(auxiliary.path)) && ! -L \(PathSafety.shellQuoted(auxiliary.path)) ]] || { print 'Temporary clothing cache already exists.' >&2; exit 1; }\n"
        result += "sudo -v\ncleanup() {\n local result=$?\n trap - EXIT\n /bin/zsh \(PathSafety.shellQuoted(restore.path)) || { print 'Automatic cleanup stopped; run Restore New Clothing.command after closing the game.' >&2; exit 1; }\n exit \"$result\"\n}\ntrap cleanup EXIT\ntrap 'exit 130' INT TERM\n"
        for file in files { result += VerifiedFileReplacement.command(source: file.staged, target: file.target, sha256: file.stagedSHA256) + "\n" }
        result += VerifiedFileReplacement.command(source: compiled.path, target: auxiliary.path, sha256: compiledSHA, requiresAbsentDestination: true) + "\n"
        result += "print 'Four NEW clothing records installed. Load a manual save; the clothes will be added and equipment requested after three seconds.'\n"
        result += "print 'Keep your reference save untouched. \(lucy ? "These are separate Lucy clothing items for feminine V, with the original inventory icons." : "These are separate records with vanilla looks.") Active wardrobe outfits can hide the equipped pieces.'\n"
        result += "/usr/bin/open -W \(PathSafety.shellQuoted(game.appURL.path)) --args \(PathSafety.shellQuoted("-scriptsBlobPath=" + auxiliary.path))\n"
        return result
    }
}
