import Foundation
import ZIPFoundation

public struct ClothingWardrobeItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let collection: String
    public let slot: String
    public let previewURL: URL
}

public struct ClothingWardrobe: Sendable {
    public let workspace: URL
    public let gameApp: String
    public let items: [ClothingWardrobeItem]
    public let selectedRecords: Set<String>
    public let previewStyle: String
}

/// The app selects from the recipes whose assets are already prepared and
/// independently verified. Registering a folder references existing files;
/// it does not duplicate multi-gigabyte game archives or their restore copies.
public struct ClothingWardrobeManager: Sendable {
    private let home: CyberMacHomeManager
    private var configuration: URL { home.configURL.appendingPathComponent("clothing-wardrobe.json") }
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    public func current() throws -> ClothingWardrobe? {
        guard FileManager.default.fileExists(atPath: configuration.path) else { return nil }
        struct Configuration: Decodable { let workspace: String }
        let value = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: configuration))
        return try load(workspace: URL(fileURLWithPath: value.workspace))
    }

    public func register(workspace: URL) throws -> ClothingWardrobe {
        let result = try load(workspace: workspace)
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        struct Configuration: Encodable { let workspace: String }
        try JSONEncoder.cybermac.encode(Configuration(workspace: workspace.path)).write(to: configuration, options: .atomic)
        return result
    }

    public func load(workspace: URL) throws -> ClothingWardrobe {
        let manifest = try JSONDecoder().decode(StandaloneClothingPreparer.Manifest.self,
            from: Data(contentsOf: workspace.appendingPathComponent("clothing.json")))
        let root = EquipProbePreparer.resolvedPath(workspace), game = EquipProbePreparer.resolvedPath(URL(fileURLWithPath: manifest.gameApp))
        guard root != game, !root.hasPrefix(game + "/"), manifest.items == StandaloneClothingSource.wardrobePieces,
              let iconPath = manifest.iconManifestPath,
              URL(fileURLWithPath: iconPath).standardizedFileURL == workspace.appendingPathComponent("icons.json").standardizedFileURL else {
            throw CyberMacError.invalidInput("Choose a prepared Lucy/Jinguji wardrobe with rendered icons.")
        }
        let targets = ["Data/r6/cache/tweakdb.bin", "Data/r6/cache/tweakdb_ep1.bin",
                       "Data/archive/Mac/content/basegame_4_appearance.archive", "Data/archive/Mac/content/basegame_4_gamedata.archive"]
        let contents = URL(fileURLWithPath: manifest.gameApp).appendingPathComponent("Contents")
        guard manifest.files.count == 4, Set(manifest.files.map(\.target)) == Set(targets.map { contents.appendingPathComponent($0).path }) else {
            throw CyberMacError.invalidInput("Wardrobe game files are incomplete.")
        }
        for file in manifest.files {
            let staged = workspace.appendingPathComponent(URL(fileURLWithPath: file.target).lastPathComponent)
            guard file.staged == staged.path, FileManager.default.fileExists(atPath: staged.path) else {
                throw CyberMacError.invalidInput("A prepared wardrobe file is missing.")
            }
        }
        let iconsURL = URL(fileURLWithPath: iconPath)
        let icons = try ClothingIconManifest.load(iconsURL)
        let slots = ["Outer torso", "Inner torso", "Legs", "Feet", "Inner torso", "Legs", "Feet"]
        let items = try manifest.items.enumerated().map { index, piece in
            guard let icon = icons.items.first(where: { $0.record == piece.record }) else {
                throw CyberMacError.invalidInput("Missing clothing preview.")
            }
            return ClothingWardrobeItem(id: piece.record,
                name: piece.label.replacingOccurrences(of: "CyberMac ", with: ""),
                collection: piece.record.contains("Jinguji") ? "Jinguji" : "Lucy", slot: slots[index],
                previewURL: workspace.appendingPathComponent(icon.preview))
        }
        let selected = try manifest.selectedRecords ?? StandaloneClothingSource.selectedPieces(group: manifest.selection ?? "none").map(\.record)
        guard Set(selected).count == selected.count, Set(selected).isSubset(of: Set(items.map(\.id))) else {
            throw CyberMacError.invalidInput("Saved clothing selection contains unknown items.")
        }
        return ClothingWardrobe(workspace: workspace, gameApp: manifest.gameApp, items: items,
                                selectedRecords: Set(selected), previewStyle: icons.previewStyle)
    }

    /// Validated supported ZIPs enable their prepared pieces. This deliberately
    /// does not claim to convert arbitrary archives or every Jinguji variant.
    public func pieces(in zip: URL) throws -> [String] {
        let package = try Archive(url: zip, accessMode: .read)
        let recipes: [(String, String, [String])] = [
            ("JingujiAllInOne/Corset Top/Jinguji_MuscleTankToCorsetBlackSilver.archive", "892d84a512e8124a62518829fb375c0d7de3390146921eb21f95769905fcb7cb", ["Items.CyberMac_Jinguji_Corset"]),
            ("JingujiAllInOne/Judy Pants/Jinguji_ShinosToJudyPantsBlack.archive", "6316f0a15d4f04cb7bd040527a680bcf026f003164c49f69222fcd7f9801d18e", ["Items.CyberMac_Jinguji_Pants"]),
            ("JingujiAllInOne/Chrome Heels/Jinguji_FleetsToChromeHeels.archive", "4cac455d865db1b6a91dffb603d9793132d0bc43cb6ebffe4c21a888b505fe4c", ["Items.CyberMac_Jinguji_Heels"]),
            ("Edgerunners_Jacket/Edgerunners_Lucy_Jacket_xBaebsae.archive", "85a010c28a0ca96c689f5fde2f97ec6f3e5be583f7cc9fd2e89b93a3c73db9ab", ["Items.CyberMac_Standalone_Jacket"]),
            ("Edgerunners_Clothes/Edgerunners_Lucy_Clothes_Heladios.archive", "c8d434ce62e2f5eca2d2ec0c4274f7acca3a48c35db45035d19f7cb22a0a1c8f", ["Items.CyberMac_Standalone_Top", "Items.CyberMac_Standalone_Pants", "Items.CyberMac_Standalone_Boots"])
        ]
        var found: [String] = []
        for (path, digest, records) in recipes {
            guard let entry = package[path] else { continue }
            guard entry.uncompressedSize <= 80 * 1024 * 1024 else { throw CyberMacError.invalidInput("Clothing archive is too large.") }
            var data = Data()
            _ = try package.extract(entry) { data.append($0) }
            guard PathSafety.sha256(data: data) == digest else { throw CyberMacError.invalidInput("This clothing variant differs from the supported recipe.") }
            found += records
        }
        guard !found.isEmpty else { throw CyberMacError.unsupported("This ZIP has no prepared Lucy or Jinguji pieces. Other variants need conversion first.") }
        return found
    }

    public func prepareLaunch(workspace: URL, records: [String]) throws -> URL {
        let wardrobe = try load(workspace: workspace)
        let game = try GameInstallDetector().detect(preferredAppPath: wardrobe.gameApp)
        try StandaloneClothingPreparer().selectClothes(game: game, output: workspace, records: records)
        return workspace.appendingPathComponent("Run New Clothing.command")
    }
}

public enum ClothingSessionStatus: String, Codable, Sendable {
    case preparing, playing, restoring, finished, failed
    public var isActive: Bool { self == .preparing || self == .playing || self == .restoring }
}

extension ClothingWardrobeManager {
    public func sessionStatus(workspace: URL) throws -> ClothingSessionStatus? {
        let url = workspace.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard try PathSafety.fileSize(url: url) <= 4096 else { throw CyberMacError.invalidInput("Clothing session status is too large.") }
        struct Session: Decodable { let status: ClothingSessionStatus }
        return try JSONDecoder().decode(Session.self, from: Data(contentsOf: url)).status
    }
}
