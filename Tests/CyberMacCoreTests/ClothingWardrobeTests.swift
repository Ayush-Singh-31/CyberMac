import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class ClothingWardrobeTests: XCTestCase {
    func fixture(_ root: URL) throws -> URL {
        let workspace = root.appendingPathComponent("wardrobe")
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("previews"), withIntermediateDirectories: true)
        let png = workspace.appendingPathComponent("image.png")
        try CyberpunkXBMPNGWriter.writePNG(rgba: Data(repeating: 180, count: 256 * 256 * 4), width: 256, height: 256, to: png)
        let image = try Data(contentsOf: png)
        let pieces = StandaloneClothingSource.wardrobePieces
        var icons: [[String: String]] = []
        for item in pieces {
            let name = "previews/" + item.entityName! + ".png"
            try image.write(to: workspace.appendingPathComponent(name))
            icons.append(["record": item.record, "iconName": "CyberMac_" + String(item.record.split(separator: ".").last!),
                          "part": item.entityName!, "preview": name, "sha256": PathSafety.sha256(data: image)])
        }
        let archive = workspace.appendingPathComponent("clothing-icons.archive")
        try Data("fixture atlas".utf8).write(to: archive)
        let iconJSON: [String: Any] = ["version": 1, "archive": archive.lastPathComponent, "archiveSHA256": try PathSafety.sha256(url: archive),
            "atlasPath": "cybermac\\ui\\clothing.inkatlas", "texturePath": "cybermac\\ui\\clothing.xbm", "previewStyle": "Neutral geometry", "items": icons]
        try JSONSerialization.data(withJSONObject: iconJSON).write(to: workspace.appendingPathComponent("icons.json"))
        let game = root.appendingPathComponent("Game.app")
        let targets = ["Data/r6/cache/tweakdb.bin", "Data/r6/cache/tweakdb_ep1.bin", "Data/archive/Mac/content/basegame_4_appearance.archive", "Data/archive/Mac/content/basegame_4_gamedata.archive"]
        let files = try targets.map { target in
            let staged = workspace.appendingPathComponent(URL(fileURLWithPath: target).lastPathComponent)
            try Data("fixture payload".utf8).write(to: staged)
            return StandaloneClothingPreparer.File(target: game.appendingPathComponent("Contents/" + target).path,
                original: root.appendingPathComponent("original").path, originalSHA256: String(repeating: "a", count: 64),
                staged: staged.path, stagedSHA256: String(repeating: "b", count: 64))
        }
        let manifest = StandaloneClothingPreparer.Manifest(gameApp: game.path, files: files, items: pieces,
            compiledSHA256: String(repeating: "c", count: 64), gameplay: "fixture", limitations: "fixture",
            selection: "custom", compiler: "unused", originalScripts: "unused", iconManifestPath: workspace.appendingPathComponent("icons.json").path,
            selectedRecords: [pieces[4].record])
        try JSONEncoder().encode(manifest).write(to: workspace.appendingPathComponent("clothing.json"))
        return workspace
    }

    func testRegistrationReferencesExistingFilesAndRetainsPerPieceSelection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try fixture(root)
        let manager = ClothingWardrobeManager(home: .init(homeURL: root.appendingPathComponent("app")))
        XCTAssertNil(try manager.current())
        let before = try FileManager.default.contentsOfDirectory(atPath: workspace.path).sorted()
        let value = try manager.register(workspace: workspace)
        XCTAssertEqual(value.items.count, 7)
        XCTAssertEqual(value.selectedRecords, ["Items.CyberMac_Jinguji_Corset"])
        XCTAssertEqual(try manager.current()?.workspace.path, workspace.path)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: workspace.path).sorted(), before)
        try Data("{\"status\":\"restoring\"}".utf8).write(to: workspace.appendingPathComponent("session.json"))
        XCTAssertEqual(try manager.sessionStatus(workspace: workspace), .restoring)
        try Data("broken".utf8).write(to: workspace.appendingPathComponent("session.json"))
        XCTAssertThrowsError(try manager.sessionStatus(workspace: workspace))
    }

    func testMissingPayloadOrTamperedPreviewIsNotShownAsAnEmptyLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try fixture(root), manager = ClothingWardrobeManager(home: .init(homeURL: root.appendingPathComponent("app")))
        try Data("bad".utf8).write(to: workspace.appendingPathComponent("previews/cybermac_lucy_jacket.png"))
        XCTAssertThrowsError(try manager.register(workspace: workspace))
        XCTAssertNil(try manager.current())
        try FileManager.default.removeItem(at: workspace.appendingPathComponent("tweakdb.bin"))
        XCTAssertThrowsError(try manager.load(workspace: workspace))
    }

    func testUnsupportedOrModifiedZIPNeverSelectsPreparedPieces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["other.archive", "JingujiAllInOne/Corset Top/Jinguji_MuscleTankToCorsetBlackSilver.archive"] {
            let zip = root.appendingPathComponent(UUID().uuidString + ".zip")
            let archive = try Archive(url: zip, accessMode: .create)
            let data = Data("unsupported contents".utf8)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
                data.subdata(in: Int(position)..<min(data.count, Int(position) + size))
            })
            XCTAssertThrowsError(try ClothingWardrobeManager().pieces(in: zip))
        }
    }
}
