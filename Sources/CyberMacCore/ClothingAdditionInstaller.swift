import Foundation
import ZIPFoundation

/// Discover clothing against the game's templates. Conversion never renders
/// images and writes only to CyberMac's sidecar until the typed install plan.
public struct ClothingAdditionInstaller: Sendable {
    public static let verificationPrefix = "clothing-additions:"
    public let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    struct Tools: Codable, Sendable { let python: String; let dotnet: String; let wolvenkit: String; let kraken: String }
    struct Item: Codable, Sendable {
        let record: String?
        let name: String
        let source: String?
        let slot: String
        let archivePath: String
        let sourceSHA256: String
        let entityName: String?
        let problem: String?
    }
    struct Inspection: Codable, Sendable { let version: Int; let packageSHA256: String; let items: [Item] }
    struct Assets: Decodable { let archive: String; let archiveSHA256: String; let resources: [String]; let originalResourceHashes: [String]; let items: [Item] }
    struct State: Codable {
        let id: String
        let gameApp: String
        let gameSealSHA256: String
        let files: [ModInstallTransaction.File]
        let items: [StandaloneClothingSource.Piece]
        let selectedRecords: [String]
        let helperModID: String
    }
    private var currentURL: URL { home.configURL.appendingPathComponent("clothing-additions.json") }
    private var states: URL { home.generatedURL.appendingPathComponent("clothing-additions/states") }
    private var repo: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }

    private func environment() throws -> (Tools, URL) {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("ClothingConversion")
        let scripts = bundled.flatMap { FileManager.default.fileExists(atPath: $0.appendingPathComponent("prepare_clothing_additions.py").path) ? $0 : nil } ?? repo.appendingPathComponent("tools")
        let config = [bundled?.appendingPathComponent("conversion-tools.json"), repo.appendingPathComponent(".research/conversion-tools.json"), repo.appendingPathComponent(".research/renderer-tools.json")]
            .compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
        guard let config else { throw CyberMacError.notFound("The clothing conversion tools are not configured. Rebuild CyberMac with its archive tools available.") }
        let tools = try JSONDecoder().decode(Tools.self, from: Data(contentsOf: config))
        for path in [tools.python, tools.dotnet] where !FileManager.default.isExecutableFile(atPath: path) {
            throw CyberMacError.notFound("A clothing conversion tool is missing: \(URL(fileURLWithPath: path).lastPathComponent)")
        }
        for path in [tools.wolvenkit, tools.kraken, scripts.appendingPathComponent("prepare_clothing_additions.py").path] where !FileManager.default.fileExists(atPath: path) {
            throw CyberMacError.notFound("A clothing conversion dependency is missing: \(URL(fileURLWithPath: path).lastPathComponent)")
        }
        return (tools, scripts)
    }

    private func work(_ package: URL, game: GameInstall) throws -> URL {
        let key = try PathSafety.sha256(string: "clothing-additions-v1|\(PathSafety.sha256(url: package))|\(PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources")))")
        return home.generatedURL.appendingPathComponent("clothing-additions/packages/\(key)")
    }

    private func convert(_ package: URL, game: GameInstall, records: [String]? = nil, factory: URL? = nil) throws -> URL {
        let (tools, scripts) = try environment()
        let output = try work(package, game: game)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        struct Request: Encodable {
            let action: String; let package: String; let packageSHA256: String; let gameApp: String
            let output: String; let templateCache: String; let tools: Tools; let records: [String]?; let baseFactoryArchive: String?
        }
        let request = Request(action: records == nil ? "inspect" : "build", package: package.path, packageSHA256: try PathSafety.sha256(url: package), gameApp: game.appURL.path,
            output: output.path, templateCache: home.generatedURL.appendingPathComponent("clothing-additions/templates").path, tools: tools, records: records, baseFactoryArchive: factory?.path)
        let file = output.appendingPathComponent("request.json")
        try JSONEncoder().encode(request).write(to: file, options: .atomic)
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: tools.python),
            arguments: ["-B", scripts.appendingPathComponent("prepare_clothing_additions.py").path, "--request", file.path], timeoutSeconds: 300)
        return output
    }

    func inspect(_ package: URL, game: GameInstall) throws -> Inspection {
        let output = try work(package, game: game)
        let result = output.appendingPathComponent("inspection.json")
        if FileManager.default.fileExists(atPath: result.path) {
            let value = try JSONDecoder().decode(Inspection.self, from: Data(contentsOf: result))
            if value.version == 1, value.packageSHA256 == (try PathSafety.sha256(url: package)) { return value }
        }
        _ = try convert(package, game: game)
        return try JSONDecoder().decode(Inspection.self, from: Data(contentsOf: result))
    }

    public func contents(_ package: URL, game: GameInstall? = nil) throws -> ModPackageContents {
        let game = try game ?? GameInstallDetector().detect()
        let scan = try ModArchiveScanner().scan(zipURL: package)
        guard scan.dependencyMarkers.frameworkMarkerLabels.isEmpty else { return try ClothingWardrobeManager(home: home).packageContents(in: package) }
        let inspection = try inspect(package, game: game)
        let legacy = try ClothingWardrobeManager(home: home).packageContents(in: package)
        if !legacy.isClothingCollection && inspection.items.allSatisfy({ $0.record == nil }) { return legacy }
        let wardrobe = try? ClothingWardrobeManager(home: home).current()
        let grouped = Dictionary(grouping: inspection.items, by: \.archivePath)
        return ModPackageContents(archives: legacy.archives.map { archive in
            let ready = archive.preparedPieces.filter { piece in wardrobe?.items.contains { $0.id == piece.id } == true }
            if !ready.isEmpty {
                return .init(path: archive.path, preparedPieces: ready.map { .init(id: $0.id, name: $0.name, requiresConversion: true) })
            }
            let found = grouped[archive.path] ?? []
            return .init(path: archive.path, preparedPieces: found.compactMap { item in
                item.record.map { .init(id: $0, name: item.name, requiresConversion: true) }
            }, problem: found.first(where: { $0.record == nil })?.problem)
        }, clothingDiscoveryVersion: 1)
    }

    private func current() throws -> State? {
        guard FileManager.default.fileExists(atPath: currentURL.path) else { return nil }
        return try JSONDecoder().decode(State.self, from: Data(contentsOf: currentURL))
    }

    public func prepare(_ package: URL, records: [String], game: GameInstall) throws -> ModInstallPreparation {
        let scan = try ModArchiveScanner().scan(zipURL: package)
        guard scan.dependencyMarkers.frameworkMarkerLabels.isEmpty else {
            return .blocked("This clothing package requires \(scan.dependencyMarkers.frameworkMarkerLabels.joined(separator: ", ")). Its framework rules need a Mac conversion adapter before installation.")
        }
        let runtime = RuntimeArchiveImporter(home: home).redscriptStatus()
        guard runtime.installed else { return .needsSetup("Drop the macOS redscript release ZIP to finish clothing installation.") }
        if let issue = RedscriptCompatibility.setupIssue(runtimeVersion: runtime.version, gameVersion: try RedscriptCompatibility.gameVersion(game)) { return .needsSetup(issue) }
        guard runtime.quarantinedPaths.isEmpty else { return .blocked("The redscript compiler is quarantined. Resolve its macOS security prompt, then retry.") }
        let base = BaseCacheManager(home: home)
        if try base.status(gameInstall: game).snapshot == nil {
            let contents = game.appURL.appendingPathComponent("Contents")
            let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: contents.appendingPathComponent("_CodeSignature/CodeResources")), format: nil) as? [String: Any]
            let entry = (seal?["files2"] as? [String: Any])?["Data/r6/cache/final.redscripts"] as? [String: Any]
            guard let digest = entry?["hash2"] as? Data,
                  try PathSafety.sha256(url: base.bundleCacheURL(gameInstall: game)) == digest.map({ String(format: "%02x", $0) }).joined() else {
                return .blocked("Restore the original script cache before setting up clothing on a fresh CyberMac installation.")
            }
            _ = try base.refreshBaseCache(gameInstall: game, dryRun: false)
        }
        let contents = try contents(package, game: game)
        let allowed = Set(contents.preparedPieces.map(\.id))
        guard !records.isEmpty, Set(records).count == records.count, Set(records).isSubset(of: allowed) else {
            throw CyberMacError.invalidInput("Select available garments from this ZIP.")
        }
        let old = try current()
        let gameSealSHA256 = try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources"))
        if let old, URL(fileURLWithPath: old.gameApp).standardizedFileURL != game.appURL.standardizedFileURL {
            throw CyberMacError.invalidInput("The clothing library belongs to another game installation.")
        }
        if let old, old.gameSealSHA256 != gameSealSHA256 {
            throw CyberMacError.unsupported("The game was updated after this clothing library was prepared. Rebuild the clothing library for this game version before adding more clothes.")
        }
        let legacy = old == nil ? (try? ClothingWardrobeManager(home: home).current()) : nil
        let legacyManifest = try legacy.map { try JSONDecoder().decode(StandaloneClothingPreparer.Manifest.self, from: Data(contentsOf: $0.workspace.appendingPathComponent("clothing.json"))) }
        var pieces = old?.items ?? legacyManifest?.items ?? []
        let existing = Set(pieces.map(\.record))
        let newRecords = records.filter { !existing.contains($0) }
        let id = UUID().uuidString.lowercased()
        let output = states.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: output) } }
        let relativeFiles = ["Data/archive/Mac/content/basegame_4_gamedata.archive", "Data/archive/Mac/content/basegame_4_appearance.archive", "Data/r6/cache/tweakdb.bin", "Data/r6/cache/tweakdb_ep1.bin"]
        let seals = try PropertyListSerialization.propertyList(from: Data(contentsOf: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources")), format: nil) as? [String: Any]
        guard let sealFiles = seals?["files2"] as? [String: Any] else { throw CyberMacError.invalidInput("Game resource seal is missing.") }
        let fingerprints = FingerprintCacheStore(home: home)
        var files: [ModInstallTransaction.File] = []
        var baselines: [String: URL] = [:]
        for relative in relativeFiles {
            let target = game.appURL.appendingPathComponent("Contents/\(relative)")
            guard let sealed = sealFiles[relative] as? [String: Any], let hash = sealed["hash2"] as? Data else { throw CyberMacError.unsupported("No original digest for \(relative).") }
            let sealedHash = hash.map { String(format: "%02x", $0) }.joined()
            let oldFile = old?.files.first { $0.target == target.path }
            let seed = legacyManifest?.files.first { $0.target == target.path }
            if let seed, seed.originalSHA256 != sealedHash { throw CyberMacError.unsupported("The prepared wardrobe belongs to another game version.") }
            let actual = try fingerprints.sha256(url: target)
            guard actual == sealedHash || actual == oldFile?.installedSHA256 || actual == seed?.stagedSHA256 else {
                throw CyberMacError.invalidInput("\(target.lastPathComponent) changed outside this clothing library. Restore its verified previous files before adding clothes.")
            }
            let source = oldFile.map { URL(fileURLWithPath: $0.source) } ?? seed.map { URL(fileURLWithPath: $0.staged) } ?? target
            let expected = oldFile?.installedSHA256 ?? seed?.stagedSHA256 ?? sealedHash
            guard try fingerprints.sha256(url: source) == expected else { throw CyberMacError.invalidInput("The prepared clothing library changed.") }
            baselines[target.lastPathComponent] = source
            let backup = home.backupsURL.appendingPathComponent("clothing/\(actual)/\(target.lastPathComponent)")
            try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: backup.path) { try PathSafety.copySpaceEfficiently(from: target, to: backup) }
            guard try fingerprints.sha256(url: backup) == actual else { throw CyberMacError.invalidInput("A clothing recovery copy changed.") }
            files.append(.init(source: output.appendingPathComponent(target.lastPathComponent).path, target: target.path, backup: backup.path,
                               originalSHA256: actual, installedSHA256: String(repeating: "0", count: 64)))
        }
        var assets: Assets?
        if !newRecords.isEmpty {
            let converted = try convert(package, game: game, records: newRecords, factory: baselines["basegame_4_gamedata.archive"])
            assets = try JSONDecoder().decode(Assets.self, from: Data(contentsOf: converted.appendingPathComponent("assets.json")))
            for item in assets!.items {
                guard let record = item.record, let source = item.source, let entity = item.entityName,
                      newRecords.contains(record), record.hasPrefix("Items.CyberMac_Import_"),
                      record.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }),
                      source.hasPrefix("Items."), source.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }) else {
                    throw CyberMacError.invalidInput("A converted garment has an invalid identity.")
                }
                pieces.append(.init(source: source, record: record, label: "CyberMac " + String(item.name.prefix(120)), entityName: entity))
            }
            guard Set(assets!.items.compactMap(\.record)) == Set(newRecords) else { throw CyberMacError.invalidInput("The clothing conversion is incomplete.") }
        }
        for index in files.indices {
            let file = files[index], name = URL(fileURLWithPath: file.target).lastPathComponent
            let destination = URL(fileURLWithPath: file.source)
            let baseline = baselines[name]!
            if let assets, name.hasSuffix(".archive") {
                let donor = URL(fileURLWithPath: assets.archive)
                try EquipProbePreparer.verify(donor, sha256: assets.archiveSHA256)
                let archive = try NativeArchive.read(donor)
                let factory = IsolatedClothingAssets.factoryHash
                let all = Set(archive.records.map(\.hash))
                guard all.contains(factory), Set(assets.resources) == Set(all.map(NativeArchive.hex)),
                      Set(assets.originalResourceHashes).isDisjoint(with: Set(all.map(NativeArchive.hex))) else { throw CyberMacError.invalidInput("Converted clothing overwrites source assets.") }
                _ = try NativeArchive.stageReplacing(source: archive, target: NativeArchive.read(baseline), hashes: name.contains("gamedata") ? [factory] : [],
                    insertionHashes: name.contains("gamedata") ? [] : all.subtracting([factory]), output: destination)
            } else if name.hasSuffix(".bin") && !newRecords.isEmpty {
                try TweakDBCloneRecordStager().stageClothingAdditions(fileURL: baseline, outputURL: destination,
                    pieces: pieces.filter { newRecords.contains($0.record) })
            } else { try PathSafety.copySpaceEfficiently(from: baseline, to: destination) }
            files[index] = .init(source: file.source, target: file.target, backup: file.backup,
                                originalSHA256: file.originalSHA256, installedSHA256: try fingerprints.sha256(url: destination))
        }
        let previousSelected = Set(old?.selectedRecords ?? legacy?.selectedRecords.sorted() ?? [])
        let selected = previousSelected.subtracting(allowed).union(records).sorted()
        let helper = StandaloneClothingSource.render(pieces: pieces, showPhysicalClothes: true,
                                                    delivery: pieces.filter { selected.contains($0.record) }, autoEquip: false)
        let helperID: String
        let script = "CyberMacClothingImports.reds"
        var previousHelper: String?
        let previousState = StateStore(home: home).load()
        if let old, let manifest = try? ManifestStore(home: home).load(id: old.helperModID), manifest.status != .uninstalled {
            helperID = old.helperModID
            _ = try ModStateManager(home: home).enable(id: helperID)
            previousHelper = try ScriptEditorService(home: home).loadScript(modID: helperID, relativePath: script)
            _ = try ScriptEditorService(home: home).saveScript(modID: helperID, relativePath: script, contents: helper)
        } else {
            let folder = home.generatedURL.appendingPathComponent("clothing-additions/helpers/\(id)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let zip = folder.appendingPathComponent("CyberMac Clothing Imports.zip")
            let archive = try Archive(url: zip, accessMode: .create)
            let data = Data(helper.utf8)
            try archive.addEntry(with: "r6/scripts/\(script)", type: .file, uncompressedSize: Int64(data.count)) { position, size in data.subdata(in: Int(position)..<min(Int(position) + size, data.count)) }
            helperID = try RedscriptModInstaller(home: home).install(zipURL: zip, gameInstall: game).id
        }
        let activation: ActivationBundleModeResult
        do { activation = try ActivationManager(home: home).activateBundleMode(gameInstall: game) }
        catch {
            if let previousHelper {
                _ = try? ScriptEditorService(home: home).saveScript(modID: helperID, relativePath: script, contents: previousHelper)
            } else { _ = try? ModStateManager(home: home).disable(id: helperID) }
            try? StateStore(home: home).save(previousState)
            throw error
        }
        guard let originalScriptHash = activation.backup.sha256 else { throw CyberMacError.invalidInput("The script recovery digest is missing.") }
        files.insert(.init(source: activation.tempOutputPath, target: activation.bundleTarget,
            backup: BundleBackupManager(home: home).backupDirectory(id: activation.backup.id).appendingPathComponent("final.redscripts").path,
            originalSHA256: originalScriptHash, installedSHA256: activation.generatedSHA256), at: 0)
        let state = State(id: id, gameApp: game.appURL.path, gameSealSHA256: gameSealSHA256, files: files.filter { !$0.target.hasSuffix("final.redscripts") }, items: pieces, selectedRecords: selected, helperModID: helperID)
        try JSONEncoder().encode(state).write(to: output.appendingPathComponent("state.json"), options: .atomic)
        complete = true
        return .prepared(try ModInstallTransaction(game: game, files: files), appearanceID: Self.verificationPrefix + id)
    }

    public func verify(id: String, game: GameInstall) throws {
        guard UUID(uuidString: id) != nil else { throw CyberMacError.invalidInput("Invalid clothing installation identity.") }
        let url = states.appendingPathComponent(id).appendingPathComponent("state.json")
        let state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
        guard state.id == id, state.gameApp == game.appURL.path,
              state.gameSealSHA256 == (try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources"))) else {
            throw CyberMacError.invalidInput("The prepared clothing library belongs to another game version or installation.")
        }
        try ModInstallTransaction(game: game, files: state.files).verify()
        let activation = StateStore(home: home).load()
        if let pending = activation.pendingActivation {
            guard pending.activeModIDs.contains(state.helperModID),
                  try ActivationManager(home: home).verify(gameInstall: game).matched else {
                throw CyberMacError.fileSystem("The clothing script installation was not verified.")
            }
        } else {
            let target = game.appURL.appendingPathComponent("Contents/Data/r6/cache/final.redscripts")
            guard activation.activationState == .active, activation.activeModIDs.contains(state.helperModID),
                  activation.activeBundleTargetHashes[target.path] == (try PathSafety.sha256(url: target)) else {
                throw CyberMacError.fileSystem("The clothing script installation was not verified.")
            }
        }
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: currentURL, options: .atomic)
    }
}
