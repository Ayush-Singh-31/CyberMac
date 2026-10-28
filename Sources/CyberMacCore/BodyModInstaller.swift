import Foundation
import ZIPFoundation

/// The initial body adapter targets the inspected legacy Unique V 2.31 archive.
/// Player definitions are rebuilt from Mac data, never copied from the PC ZIP.
public struct BodyModInstaller: Sendable {
    public static let verificationPrefix = "body-mod:"
    public static let variants = ["Original shape (Unique V)", "Shoulder test (+20%)"]
    static let frameworkSHA256 = "d781605f513854cf09864149869b8339ef5a282c73d8efaf69ac2d5f77f40c4e"
    private static let femaleHashes: Set<UInt64> = [0x1c77c037bb303ec1, 0x33897e69b7c93465, 0x33ad3ad818aca033, 0x55e919f317f9d55e,
        0x765e50b58bda6537, 0x969e1b776584b2cc, 0xb0bb924c7f54b5e7, 0xee42aaa3659741ec]
    private static let privateHashes: Set<UInt64> = [0xba39449df692ab6b, 0xc1c88944707f2a52]
    private static let sharedRigHash: UInt64 = 0x8b729f66f6713026
    private static let firstPersonRigHash: UInt64 = 0x92869df7e9401972
    private static let paths = ["Data/archive/Mac/content/basegame_1_engine.archive",
        "Data/archive/Mac/content/basegame_4_appearance.archive", "Data/archive/Mac/ep1/ep1_2_gamedata.archive"]
    public let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    private struct Preset: Codable {
        let format: String; let name: String; let sourceSHA256: String
        let bones: [String: [String: [String: Double]]]
        let firstPersonBones: [String: [String: [String: Double]]]?
    }

    private static func preset(in package: URL) throws -> Preset? {
        guard package.pathExtension.lowercased() == "zip" else { return nil }
        let zip = try Archive(url: package, accessMode: .read)
        guard let entry = zip["cybermac-body-preset.json"] else { return nil }
        guard zip.filter({ $0.type == .file }).count == 1, entry.type == .file,
              entry.uncompressedSize <= 128 * 1024 else { throw CyberMacError.invalidInput("Invalid body preset metadata.") }
        var data = Data(); _ = try zip.extract(entry) { data.append($0) }
        let preset = try JSONDecoder().decode(Preset.self, from: data)
        guard preset.format == "cybermac-body-preset-v1", !preset.name.isEmpty, preset.name.count <= 80,
              preset.sourceSHA256.count == 64, preset.sourceSHA256.allSatisfy(\.isHexDigit),
              !preset.bones.isEmpty, preset.bones.count <= 128 else { throw CyberMacError.invalidInput("Invalid body preset definition.") }
        for overrides in [preset.bones] + (preset.firstPersonBones.map { [$0] } ?? []) {
            guard !overrides.isEmpty, overrides.count <= 128 else { throw CyberMacError.invalidInput("Invalid body preset bone count.") }
            for (bone, transforms) in overrides {
                guard !bone.isEmpty, bone.count <= 100, bone.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }),
                      !transforms.isEmpty, Set(transforms.keys).isSubset(of: ["Scale", "Translation"]) else {
                    throw CyberMacError.invalidInput("Unsupported body preset bone or transform.")
                }
                for (transform, axes) in transforms {
                    guard !axes.isEmpty, Set(axes.keys).isSubset(of: ["X", "Y", "Z"]),
                          axes.values.allSatisfy({ $0.isFinite && (transform == "Scale" ? (0.05...5).contains($0) : abs($0) <= 2) }) else {
                        throw CyberMacError.invalidInput("Invalid body preset transform values.")
                    }
                }
            }
        }
        return preset
    }

    public static func variants(for package: URL) throws -> [String] {
        guard let preset = try preset(in: package) else { return variants }
        return [preset.name + " (V only)", preset.name + " (V + NPCs test)"]
    }

    public static func recognizes(_ package: URL) throws -> Bool {
        if package.pathExtension.lowercased() == "archive" {
            return try PathSafety.fileSize(url: package) == 491_520 && PathSafety.sha256(url: package) == frameworkSHA256
        }
        guard package.pathExtension.lowercased() == "zip" else { return false }
        if try preset(in: package) != nil { return true }
        let zip = try Archive(url: package, accessMode: .read)
        let entries = zip.filter { $0.type == .file && $0.path.lowercased().hasSuffix(".archive") && !$0.path.hasPrefix("__MACOSX/") }
        guard entries.count == 1, entries[0].uncompressedSize == 491_520 else { return false }
        var data = Data()
        _ = try zip.extract(entries[0]) { data.append($0) }
        return PathSafety.sha256(data: data) == frameworkSHA256
    }

    private struct Target: Codable {
        let relativePath: String
        let source: String
        let sourceSHA256: String
        let replacementHashes: [String]
        let insertPrivateResources: Bool
    }
    private struct Assets: Decodable {
        struct Archive: Decodable {
            let relativePath: String; let archive: String; let sha256: String
            let replacements: [String]; let privateResources: [String]
        }
        let version: Int; let variant: String; let archives: [Archive]; let verifiedResources: Int
    }
    private struct State: Codable {
        let id: String; let seal: String; let variant: String; let transaction: ModInstallTransaction
        let scope: String?
    }

    public func prepare(_ package: URL, variant: String?, game: GameInstall) throws -> ModInstallPreparation {
        guard try Self.recognizes(package) else { throw CyberMacError.unsupported("This body framework needs a different conversion recipe.") }
        let preset = try Self.preset(in: package)
        let variants = try Self.variants(for: package)
        guard let variant else { return .choices(variants) }
        guard let choice = variants.firstIndex(of: variant) else { throw CyberMacError.invalidInput("Choose a supported body option.") }
        let shared = preset != nil && choice == 1
        let archivePaths = shared ? Array(Self.paths.prefix(2)) : Self.paths
        guard let version = try RedscriptCompatibility.gameVersion(game), version == "2.5" || version.hasPrefix("2.5.") else {
            return .blocked("This player-rig adapter targets Mac game 2.5. Rebuild the recipe for your game version.")
        }
        let (tools, scripts) = try ClothingAdditionInstaller(home: home).environment()
        let script = scripts.appendingPathComponent("prepare_body_mod.py")
        guard FileManager.default.fileExists(atPath: script.path) else { throw CyberMacError.notFound("Rebuild CyberMac to include the body conversion tools.") }
        let id = UUID().uuidString.lowercased()
        let folder = home.generatedURL.appendingPathComponent("body-mods/\(id)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let contents = game.appURL.appendingPathComponent("Contents")
        let sealURL = contents.appendingPathComponent("_CodeSignature/CodeResources")
        let sealHash = try PathSafety.sha256(url: sealURL)
        let activeStateURL = home.configURL.appendingPathComponent("body-mod.json")
        if FileManager.default.fileExists(atPath: activeStateURL.path) {
            let active = try JSONDecoder().decode(State.self, from: Data(contentsOf: activeStateURL))
            if active.transaction.gameApp == game.appURL.path, active.seal == sealHash,
               (active.scope == "shared") != shared,
               active.transaction.files.contains(where: { (try? PathSafety.sha256(url: URL(fileURLWithPath: $0.target))) == $0.installedSHA256 }) {
                return .blocked("Restore your current body installation before changing between V-only and V + NPCs tests. This keeps the scopes separate.")
            }
        }
        let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: sealURL), format: nil) as? [String: Any]
        guard let sealedFiles = seal?["files2"] as? [String: Any] else { throw CyberMacError.invalidInput("Game resource seal is missing.") }
        let fingerprints = FingerprintCacheStore(home: home)
        let clothing = try ClothingAdditionInstaller(home: home).managedFiles(game: game)
        var targets: [Target] = [], backups: [String: String] = [:]
        for path in archivePaths {
            let target = contents.appendingPathComponent(path)
            guard let entry = sealedFiles[path] as? [String: Any], let hash = entry["hash2"] as? Data else {
                throw CyberMacError.invalidInput("No original digest for a player archive.")
            }
            let sealedHash = hash.map { String(format: "%02x", $0) }.joined()
            let actual = try fingerprints.sha256(url: target)
            let managed = try ManagedArchiveStore(home: home).knownFile(target: target, game: game)
                ?? clothing.first { $0.target == target.path && $0.installedSHA256 == actual }
            guard actual == sealedHash || managed != nil else {
                throw CyberMacError.invalidInput("\(target.lastPathComponent) changed outside CyberMac. Restore its previous files before installing a body.")
            }
            let source = managed.map { URL(fileURLWithPath: $0.source) } ?? target
            guard try fingerprints.sha256(url: source) == actual else { throw CyberMacError.invalidInput("A prepared player archive changed.") }
            let native = try NativeArchive.read(source)
            if shared && path.contains("basegame_4_appearance"),
               !Self.privateHashes.isDisjoint(with: native.records.map(\.hash)) {
                return .blocked("Restore the current Unique V body test first. Otherwise V can keep using its private rig during the shared-rig comparison.")
            }
            var desired: Set<UInt64> = shared ? [Self.sharedRigHash] : Self.femaleHashes
            if preset?.firstPersonBones != nil && path != Self.paths[2] { desired.insert(Self.firstPersonRigHash) }
            let replacements = desired.intersection(native.records.map(\.hash))
            if preset?.firstPersonBones != nil && path != Self.paths[2] && !replacements.contains(Self.firstPersonRigHash) {
                throw CyberMacError.unsupported("The game is missing the expected first-person body rig.")
            }
            guard !replacements.isEmpty else { throw CyberMacError.unsupported("The game has different player templates from the body recipe.") }
            let backup = home.backupsURL.appendingPathComponent("body-mods/\(actual)/\(target.lastPathComponent)")
            try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: backup.path) { try PathSafety.copySpaceEfficiently(from: target, to: backup) }
            guard try fingerprints.sha256(url: backup) == actual else { throw CyberMacError.invalidInput("Body recovery copy does not match.") }
            backups[path] = backup.path
            targets.append(Target(relativePath: path, source: source.path, sourceSHA256: actual,
                replacementHashes: replacements.sorted().map { String(format: "%016llx", $0) },
                insertPrivateResources: !shared && path.contains("basegame_4_appearance")))
        }
        struct Request: Encodable {
            let output: String; let variant: String; let tools: ClothingAdditionInstaller.Tools
            let targets: [Target]; let rigSource: String
            let scope: String; let preset: Preset?
        }
        let mode = preset != nil ? "lethal" : (choice == 0 ? "neutral" : "shoulders")
        let request = folder.appendingPathComponent("request.json")
        try JSONEncoder().encode(Request(output: folder.path, variant: mode, tools: tools, targets: targets,
            rigSource: targets[0].source, scope: shared ? "shared" : "player", preset: preset)).write(to: request, options: .atomic)
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: tools.python),
            arguments: ["-B", script.path, "--request", request.path], timeoutSeconds: 300)
        let assets = try JSONDecoder().decode(Assets.self, from: Data(contentsOf: folder.appendingPathComponent("body-assets.json")))
        guard assets.version == 1, assets.variant == mode, assets.verifiedResources == (shared ? 1 : 11) + (preset?.firstPersonBones == nil ? 0 : 1),
              assets.archives.count == targets.count, Set(assets.archives.map(\.relativePath)) == Set(archivePaths) else {
            throw CyberMacError.invalidInput("Body conversion returned incomplete resources.")
        }
        var files: [ModInstallTransaction.File] = []
        for target in targets {
            let converted = assets.archives.first { $0.relativePath == target.relativePath }!
            let donor = URL(fileURLWithPath: converted.archive)
            try PathSafety.validateContainedPath(donor.resolvingSymlinksInPath(), in: folder.resolvingSymlinksInPath())
            guard try fingerprints.sha256(url: donor) == converted.sha256,
                  Set(converted.replacements) == Set(target.replacementHashes) else { throw CyberMacError.invalidInput("Body output changed.") }
            let source = try NativeArchive.read(donor)
            let baseline = try NativeArchive.read(URL(fileURLWithPath: target.source))
            let expected = Set(target.replacementHashes.compactMap { UInt64($0, radix: 16) })
                .union(target.insertPrivateResources ? Self.privateHashes : [])
            guard Set(source.records.map(\.hash)) == expected else { throw CyberMacError.invalidInput("Body output contains unexpected resources.") }
            let existing = expected.intersection(baseline.records.map(\.hash))
            let output = folder.appendingPathComponent("staged/\(URL(fileURLWithPath: target.relativePath).lastPathComponent)")
            _ = try NativeArchive.stageReplacing(source: source, target: baseline, hashes: existing,
                insertionHashes: expected.subtracting(existing), output: output)
            let destination = contents.appendingPathComponent(target.relativePath)
            guard try fingerprints.sha256(url: destination) == target.sourceSHA256 else { throw CyberMacError.invalidInput("Game archives changed during body preparation.") }
            files.append(.init(source: output.path, target: destination.path, backup: backups[target.relativePath]!,
                originalSHA256: target.sourceSHA256, installedSHA256: try fingerprints.sha256(url: output)))
        }
        let transaction = try ModInstallTransaction(game: game, files: files)
        try JSONEncoder().encode(State(id: id, seal: sealHash, variant: variant, transaction: transaction, scope: shared ? "shared" : "player"))
            .write(to: folder.appendingPathComponent("state.json"), options: .atomic)
        return .prepared(transaction, appearanceID: Self.verificationPrefix + id)
    }

    public func verify(id: String, game: GameInstall) throws {
        guard UUID(uuidString: id) != nil else { throw CyberMacError.invalidInput("Invalid body installation identity.") }
        let file = home.generatedURL.appendingPathComponent("body-mods/\(id)/state.json")
        let state = try JSONDecoder().decode(State.self, from: Data(contentsOf: file))
        guard state.id == id, state.transaction.gameApp == game.appURL.path,
              state.seal == (try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources"))) else {
            throw CyberMacError.invalidInput("This body was prepared for another game installation or version.")
        }
        try ManagedArchiveStore(home: home).remember(ModInstallTransaction(game: game, files: state.transaction.files), game: game)
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: home.configURL.appendingPathComponent("body-mod.json"), options: .atomic)
    }
}
