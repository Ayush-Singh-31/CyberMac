import Foundation
import XCTest
@testable import CyberMacCore

final class ClothingAdditionVerificationTests: XCTestCase {
    func testAlreadyActiveClothingVerificationIsRepeatableAndRequiresTheHelper() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = CyberMacHomeManager(homeURL: root.appendingPathComponent("home"))
        let app = root.appendingPathComponent("Game.app"), data = app.appendingPathComponent("Contents/Data")
        let game = GameInstall(appURL: app, executableURL: app.appendingPathComponent("Contents/MacOS/FakeGame"),
                               dataURL: data, archiveMacURL: nil, r6URL: nil, storefront: .unknown, displayName: "Fixture")
        let seal = app.appendingPathComponent("Contents/_CodeSignature/CodeResources")
        let scripts = data.appendingPathComponent("r6/cache/final.redscripts")
        let database = data.appendingPathComponent("r6/cache/tweakdb.bin")
        for file in [seal, scripts, database] {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(file.lastPathComponent.utf8).write(to: file)
        }
        let id = UUID().uuidString.lowercased(), helper = "clothing-helper"
        let pending = home.generatedURL.appendingPathComponent("clothing-additions/states/\(id)/state.json")
        try FileManager.default.createDirectory(at: pending.deletingLastPathComponent(), withIntermediateDirectories: true)
        let state = ClothingAdditionInstaller.State(id: id, gameApp: app.path, gameSealSHA256: try PathSafety.sha256(url: seal),
            files: [.init(source: root.appendingPathComponent("source").path, target: database.path, backup: root.appendingPathComponent("backup").path,
                          originalSHA256: String(repeating: "a", count: 64), installedSHA256: try PathSafety.sha256(url: database))],
            items: [], selectedRecords: [], helperModID: helper)
        try JSONEncoder().encode(state).write(to: pending)
        let store = StateStore(home: home)
        var activation = CyberMacState(activationState: .active, activeModIDs: [helper], activeBundleTargetHashes: [scripts.path: try PathSafety.sha256(url: scripts)])
        try store.save(activation)
        let installer = ClothingAdditionInstaller(home: home)
        try installer.verify(id: id, game: game)
        XCTAssertNoThrow(try installer.verify(id: id, game: game))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.configURL.appendingPathComponent("clothing-additions.json").path))
        activation.activeModIDs = []
        try store.save(activation)
        XCTAssertThrowsError(try installer.verify(id: id, game: game))
        activation.activeModIDs = [helper]
        try store.save(activation)
        try Data("unrelated script cache".utf8).write(to: scripts)
        XCTAssertThrowsError(try installer.verify(id: id, game: game))
    }
}
