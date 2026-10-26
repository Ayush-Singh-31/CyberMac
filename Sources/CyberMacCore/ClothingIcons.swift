import Foundation
import ImageIO

public struct ClothingIconManifest: Codable, Sendable {
    public struct Item: Codable, Sendable {
        public let record: String
        public let iconName: String
        public let part: String
        public let preview: String
        public let sha256: String
    }
    public let version: Int
    public let archive: String
    public let archiveSHA256: String
    public let atlasPath: String
    public let texturePath: String
    public let previewStyle: String
    public let items: [Item]

    public static func load(_ url: URL) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        let expected = StandaloneClothingSource.wardrobePieces
        guard value.version == 1, value.archive == "clothing-icons.archive",
              value.atlasPath == "cybermac\\ui\\clothing.inkatlas", value.texturePath == "cybermac\\ui\\clothing.xbm",
              value.items.count == expected.count, Set(value.items.map(\.record)) == Set(expected.map(\.record)) else {
            throw CyberMacError.invalidInput("Unrecognized clothing icon package.")
        }
        for item in value.items {
            guard let piece = expected.first(where: { $0.record == item.record }),
                  item.part == piece.entityName, item.iconName == "CyberMac_" + String(piece.record.split(separator: ".").last!),
                  item.preview == "previews/" + item.part + ".png" else {
                throw CyberMacError.invalidInput("Clothing icon identities do not match their items.")
            }
            let preview = url.deletingLastPathComponent().appendingPathComponent(item.preview)
            try PathSafety.validateContainedPath(preview, in: url.deletingLastPathComponent())
            guard try PathSafety.fileSize(url: preview) <= 2 * 1024 * 1024,
                  let source = CGImageSourceCreateWithURL(preview as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  properties[kCGImagePropertyPixelWidth] as? Int == 256,
                  properties[kCGImagePropertyPixelHeight] as? Int == 256 else {
                throw CyberMacError.invalidInput("Clothing preview must be a small 256-pixel image.")
            }
            try EquipProbePreparer.verify(preview, sha256: item.sha256)
        }
        let archive = url.deletingLastPathComponent().appendingPathComponent(value.archive)
        guard try PathSafety.fileSize(url: archive) <= 8 * 1024 * 1024 else { throw CyberMacError.invalidInput("Clothing icon atlas is too large.") }
        try EquipProbePreparer.verify(archive, sha256: value.archiveSHA256)
        return value
    }
}

extension StandaloneClothingPreparer {
    /// Creates a new disposable version using the working seven-item package.
    /// Original restores are referenced, never copied. The prior working version
    /// remains available until the new icons have their in-game check.
    public func prepareIcons(game: GameInstall, workspace: URL, iconsURL: URL, output: URL) throws -> URL {
        let root = EquipProbePreparer.resolvedPath(output), gameRoot = EquipProbePreparer.resolvedPath(game.appURL)
        guard !FileManager.default.fileExists(atPath: output.path), root != gameRoot, !root.hasPrefix(gameRoot + "/") else {
            throw CyberMacError.unsafePath("Use a new icon wardrobe folder outside the game.")
        }
        let icons = try ClothingIconManifest.load(iconsURL)
        try refreshCommands(game: game, output: workspace)
        let old = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: workspace.appendingPathComponent("clothing.json")))
        guard old.items == StandaloneClothingSource.wardrobePieces, old.iconManifestPath == nil else {
            throw CyberMacError.invalidInput("Use the verified seven-item wardrobe without a previous icon patch.")
        }
        let iconArchive = try NativeArchive.read(iconsURL.deletingLastPathComponent().appendingPathComponent(icons.archive))
        let additions = Set([icons.atlasPath, icons.texturePath].map { TweakDBPackedStringAnalyzer.fnv1a64(Array($0.utf8)) })
        guard iconArchive.records.count == 2, Set(iconArchive.records.map(\.hash)) == additions else {
            throw CyberMacError.invalidInput("Icon archive contains unexpected resources.")
        }
        if let enumerator = FileManager.default.enumerator(at: game.appURL.appendingPathComponent("Contents/Data/archive/Mac"), includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "archive" {
                guard Set(try NativeArchive.read(url).records.map(\.hash)).isDisjoint(with: additions) else {
                    throw CyberMacError.invalidInput("Icon resources collide with the game.")
                }
            }
        } else { throw CyberMacError.fileSystem("Cannot check official icon resources.") }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: output) } }
        guard let compiler = old.compiler, let original = old.originalScripts else { throw CyberMacError.invalidInput("Clothing runtime is missing.") }
        let records = try old.selectedRecords ?? StandaloneClothingSource.selectedPieces(group: old.selection ?? "both").map(\.record)
        let text = StandaloneClothingSource.render(pieces: old.items, delivery: old.items.filter { records.contains($0.record) }, autoEquip: false, customIcons: true)
        let (compiled, compiledSHA) = try Self.compileHelper(text: text, compiler: URL(fileURLWithPath: compiler),
            original: URL(fileURLWithPath: original), directory: output)
        var files: [File] = []
        var receipts: [AddonProbeTweakDBCloneRecordReport] = []
        for file in old.files {
            let name = URL(fileURLWithPath: file.target).lastPathComponent
            let source = URL(fileURLWithPath: file.staged), final = output.appendingPathComponent(name)
            if name == "basegame_4_appearance.archive" {
                let baseline = try NativeArchive.read(source)
                _ = try NativeArchive.stageReplacing(source: iconArchive, target: baseline, hashes: [], insertionHashes: additions, output: final)
            } else if name.hasPrefix("tweakdb") {
                var current = source
                for (index, icon) in icons.items.enumerated() {
                    let folder = output.appendingPathComponent("\(name)-icon-\(index)")
                    let report = try TweakDBCloneRecordStager().stage(request: .init(fileURL: current, outputDirectoryURL: folder,
                        sourceRecord: "UIIcon.ItemIcon", newRecord: "UIIcon." + icon.iconName,
                        overrides: [.resource(property: "atlasResourcePath", path: icons.atlasPath), .cName(property: "atlasPartName", value: icon.part)]))
                    guard report.conclusions.contains(.overrideFlatsResolved), report.conclusions.contains(.newRecordResolved),
                          report.clonedFlats.count == 2, report.appliedOverrides.allSatisfy({ !$0.unresolved }) else {
                        throw CyberMacError.invalidInput("Custom icon record failed verification: \(icon.record)")
                    }
                    if current != source { try FileManager.default.removeItem(at: current) }
                    current = URL(fileURLWithPath: report.stagedFilePath); receipts.append(report)
                }
                try FileManager.default.moveItem(at: current, to: final)
            } else { try PathSafety.copySpaceEfficiently(from: source, to: final) }
            files.append(.init(target: file.target, original: file.original, originalSHA256: file.originalSHA256,
                               staged: final.path, stagedSHA256: try PathSafety.sha256(url: final)))
        }
        for icon in icons.items {
            let target = output.appendingPathComponent(icon.preview)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: iconsURL.deletingLastPathComponent().appendingPathComponent(icon.preview), to: target)
        }
        try FileManager.default.copyItem(at: iconsURL.deletingLastPathComponent().appendingPathComponent(icons.archive), to: output.appendingPathComponent(icons.archive))
        let newIcons = output.appendingPathComponent("icons.json")
        try JSONEncoder.cybermac.encode(icons).write(to: newIcons)
        try Data(text.utf8).write(to: output.appendingPathComponent("StandaloneClothing.reds"))
        try EquipProbePreparer.verify(compiled, sha256: compiledSHA)
        let manifest = Manifest(gameApp: old.gameApp, files: files, items: old.items, compiledSHA256: compiledSHA,
            gameplay: "Garments user-confirmed; rendered inventory icons need gameplay verification", limitations: old.limitations,
            selection: old.selection, compiler: old.compiler, originalScripts: old.originalScripts, iconManifestPath: newIcons.path,
            selectedRecords: records)
        try JSONEncoder.cybermac.encode(manifest).write(to: output.appendingPathComponent("clothing.json"))
        try JSONEncoder.cybermac.encode(receipts).write(to: output.appendingPathComponent("icon-clone-receipts.json"))
        try Self.writeCommands(files: files, game: game, output: output, compiledSHA: compiledSHA, lucy: true, inventoryOnly: true)
        complete = true
        return output
    }
}
