import Foundation

/// Accepts the isolated Lucy recipe and the three pinned Jinguji additions.
/// The sole existing resource replaced is the clothing factory table;
/// original garment meshes, entities and appearances stay byte identical.
struct IsolatedClothingAssets {
    struct Manifest: Decodable {
        let version: Int
        let archive: String
        let archiveSHA256: String
        let jacketSHA256: String?
        let clothesSHA256: String?
        let kind: String?
        let lucyArchiveSHA256: String?
        let recipes: [Recipe]?
        let resourceHashes: [String]
        let originalMeshHashes: [String]
    }

    struct Recipe: Decodable {
        let key: String?
        let source: String?
        let record: String?
        let label: String?
        let sha256: String?
        let entityName: String
        let appearanceName: String
    }

    static let factoryHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("base\\gameplay\\factories\\items\\clothing.csv".utf8))
    let archive: NativeArchive
    let digest: String
    let includesJinguji: Bool
    var pieces: [StandaloneClothingSource.Piece] {
        includesJinguji ? StandaloneClothingSource.wardrobePieces : StandaloneClothingSource.lucyPieces
    }

    init(manifestURL: URL) throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        includesJinguji = manifest.kind == "lucy-jinguji"
        if includesJinguji {
            let hashes = ["892d84a512e8124a62518829fb375c0d7de3390146921eb21f95769905fcb7cb",
                          "6316f0a15d4f04cb7bd040527a680bcf026f003164c49f69222fcd7f9801d18e",
                          "4cac455d865db1b6a91dffb603d9793132d0bc43cb6ebffe4c21a888b505fe4c"]
            guard manifest.version == 1, manifest.archive == "wardrobe-isolated.archive",
                  manifest.lucyArchiveSHA256 == "c5e7ac0a4c4d45ade29c93b36192a6fd1405f06711f661a0285806b0d195ceb2",
                  let recipes = manifest.recipes, recipes.count == 3 else {
                throw CyberMacError.unsupported("Unsupported Jinguji recipe. Use tools/prepare_jinguji_assets.py.")
            }
            for (index, recipe) in recipes.enumerated() {
                let piece = StandaloneClothingSource.jingujiPieces[index]
                guard recipe.source == piece.source, recipe.record == piece.record,
                      recipe.label == piece.label, recipe.sha256 == hashes[index],
                      recipe.entityName == piece.entityName,
                      recipe.appearanceName == recipe.entityName + "_",
                      recipe.key == ["corset", "pants", "heels"][index] else {
                    throw CyberMacError.invalidInput("Jinguji garment identity or source is not recognized.")
                }
            }
        } else {
            guard manifest.version == 2, manifest.kind == nil, manifest.archive == "lucy-isolated.archive",
                  manifest.jacketSHA256 == "85a010c28a0ca96c689f5fde2f97ec6f3e5be583f7cc9fd2e89b93a3c73db9ab",
                  manifest.clothesSHA256 == "c8d434ce62e2f5eca2d2ec0c4274f7acca3a48c35db45035d19f7cb22a0a1c8f" else {
                throw CyberMacError.unsupported("Unsupported Lucy asset recipe. Use tools/prepare_lucy_assets.py with the saved Lucy ZIPs.")
            }
        }
        let source = manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.archive)
        try EquipProbePreparer.verify(source, sha256: manifest.archiveSHA256)
        archive = try NativeArchive.read(source)
        digest = manifest.archiveSHA256
        let hashes = Set(archive.records.map(\.hash))
        let count = includesJinguji ? 54 : 42
        guard archive.records.count == count, hashes.count == count,
              Set(manifest.resourceHashes) == Set(hashes.map(NativeArchive.hex)),
              manifest.originalMeshHashes.count == (includesJinguji ? 11 : 8),
              Set(manifest.originalMeshHashes).isDisjoint(with: Set(hashes.map(NativeArchive.hex))),
              hashes.contains(Self.factoryHash) else {
            throw CyberMacError.invalidInput("Clothing assets have an unexpected resource inventory or overwrite original meshes.")
        }
        for piece in ["jacket", "top", "pants", "boots"] {
            for ext in ["ent", "app"] {
                let path = "cybermac\\lucy\\\(piece).\(ext)"
                guard hashes.contains(TweakDBPackedStringAnalyzer.fnv1a64(Array(path.utf8))) else {
                    throw CyberMacError.invalidInput("Lucy assets are missing \(path).")
                }
            }
        }
        if includesJinguji {
            for piece in ["corset", "pants", "heels"] {
                for ext in ["ent", "app", "mesh"] {
                    let path = "cybermac\\jinguji\\\(piece).\(ext)"
                    guard hashes.contains(TweakDBPackedStringAnalyzer.fnv1a64(Array(path.utf8))) else {
                        throw CyberMacError.invalidInput("Jinguji assets are missing \(path).")
                    }
                }
            }
        }
    }

    func stage(game: GameInstall, output: URL, originalAppearance: URL?, seals: [String: Any], originals: [String: URL] = [:]) throws -> [StandaloneClothingPreparer.File] {
        guard let originalAppearance else {
            throw CyberMacError.invalidInput("Clothing preparation requires an existing verified appearance restore archive through --restore-from or --original-appearance.")
        }
        let hashes = Set(archive.records.map(\.hash))
        let insertions = hashes.subtracting([Self.factoryHash])
        // Check every official owner, including EP1, before accepting new resource
        // hashes. A collision elsewhere could silently modify another garment.
        let folder = game.appURL.appendingPathComponent("Contents/Data/archive/Mac")
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw CyberMacError.fileSystem("Cannot enumerate official archives.")
        }
        var official: Set<UInt64> = []
        var factoryOwners: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "archive" {
            let contents = try NativeArchive.read(url)
            let present = Set(contents.records.map(\.hash))
            guard present.isDisjoint(with: insertions) else { throw CyberMacError.invalidInput("Clothing asset collides with an official resource: \(url.lastPathComponent)") }
            if present.contains(Self.factoryHash) { factoryOwners.append(url.standardizedFileURL) }
            official.formUnion(present)
        }
        guard archive.dependencies.allSatisfy({ official.contains($0) || hashes.contains($0) }) else {
            throw CyberMacError.invalidInput("Clothing assets have unresolved dependencies.")
        }
        let gamedata = folder.appendingPathComponent("content/basegame_4_gamedata.archive")
        guard factoryOwners == [gamedata.standardizedFileURL] else { throw CyberMacError.unsupported("Clothing factory has an unexpected official owner.") }
        var files: [StandaloneClothingPreparer.File] = []
        for (name, replacements, additions) in [
            ("basegame_4_gamedata.archive", Set([Self.factoryHash]), Set<UInt64>()),
            ("basegame_4_appearance.archive", Set<UInt64>(), insertions)
        ] {
            let relative = "Data/archive/Mac/content/\(name)"
            guard let entry = seals[relative] as? [String: Any], let hash = entry["hash2"] as? Data, hash.count == 32 else {
                throw CyberMacError.unsupported("Missing game seal for \(name).")
            }
            let originalSHA = hash.map { String(format: "%02x", $0) }.joined()
            let target = game.appURL.appendingPathComponent("Contents/\(relative)")
            try EquipProbePreparer.verify(target, sha256: originalSHA)
            let original: URL
            if name == "basegame_4_appearance.archive" {
                original = originalAppearance
                let path = EquipProbePreparer.resolvedPath(original)
                let gamePath = game.appURL.resolvingSymlinksInPath().path
                guard path != gamePath, !path.hasPrefix(gamePath + "/") else { throw CyberMacError.unsafePath("Restore archive must be outside the game.") }
                try EquipProbePreparer.verify(original, sha256: originalSHA)
            } else {
                original = originals[name] ?? output.appendingPathComponent("original-\(name)")
                if originals[name] == nil { try PathSafety.copySpaceEfficiently(from: target, to: original) }
                try EquipProbePreparer.verify(original, sha256: originalSHA)
            }
            let staged = output.appendingPathComponent(name)
            let baseline = try NativeArchive.read(target)
            let result = try NativeArchive.stageReplacing(source: archive, target: baseline,
                hashes: replacements, insertionHashes: additions, output: staged)
            // Prove all original resources except the intended factory keep their
            // original index rows; the stager verifies inserted payloads/dependencies.
            let grouped = Dictionary(grouping: result.records, by: \.hash)
            for record in baseline.records where !replacements.contains(record.hash) {
                guard grouped[record.hash]?.contains(where: { $0.bytes == record.bytes }) == true else {
                    throw CyberMacError.invalidInput("An original archive record changed during clothing staging.")
                }
            }
            files.append(.init(target: target.path, original: original.path, originalSHA256: originalSHA,
                staged: staged.path, stagedSHA256: try PathSafety.sha256(url: staged)))
        }
        try EquipProbePreparer.verify(archive.url, sha256: digest)
        return files
    }
}
