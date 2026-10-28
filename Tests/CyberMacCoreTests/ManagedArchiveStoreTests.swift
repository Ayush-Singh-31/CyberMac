import Foundation
import XCTest
@testable import CyberMacCore

final class ManagedArchiveStoreTests: XCTestCase {
    private var root: URL!
    private var game: GameInstall!
    private var store: ManagedArchiveStore!
    private var target: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("Body composition \(UUID().uuidString)")
        let app = root.appendingPathComponent("Fixture.app"), data = app.appendingPathComponent("Contents/Data")
        target = data.appendingPathComponent("archive/Mac/content/appearance.archive")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let seal = app.appendingPathComponent("Contents/_CodeSignature/CodeResources")
        try FileManager.default.createDirectory(at: seal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("game version one".utf8).write(to: seal)
        try Data("vanilla".utf8).write(to: target)
        game = GameInstall(appURL: app, executableURL: app.appendingPathComponent("Contents/MacOS/Fixture"),
            dataURL: data, archiveMacURL: nil, r6URL: nil, storefront: .unknown, displayName: "Fixture")
        store = ManagedArchiveStore(home: CyberMacHomeManager(homeURL: root.appendingPathComponent("home")))
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testCombinedBodyThenClothingSnapshotAndUndoAreRecognized() throws {
        let body = try install("body"), clothes = try install("body plus clothes")
        XCTAssertEqual(try store.knownFile(target: target, game: game)?.source, clothes.files[0].source)
        try Data(contentsOf: URL(fileURLWithPath: clothes.files[0].backup)).write(to: target, options: .atomic)
        XCTAssertEqual(try store.knownFile(target: target, game: game)?.installedSHA256, body.files[0].installedSHA256)
    }

    func testUnknownExternalEditAndGameUpdateAreNotAdopted() throws {
        _ = try install("body")
        try Data("external edit".utf8).write(to: target, options: .atomic)
        XCTAssertNil(try store.knownFile(target: target, game: game))
        _ = try install("body plus clothes")
        try Data("game version two".utf8).write(to: game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources"))
        XCTAssertNil(try store.knownFile(target: target, game: game))
    }

    func testUnverifiedInstallAndDamagedRetainedOutputAreRejected() throws {
        let transaction = try transaction("body")
        XCTAssertThrowsError(try store.remember(transaction, game: game))
        let installed = try install("body")
        try Data("damaged".utf8).write(to: URL(fileURLWithPath: installed.files[0].source), options: .atomic)
        XCTAssertThrowsError(try store.knownFile(target: target, game: game))
    }

    private func transaction(_ value: String) throws -> ModInstallTransaction {
        let folder = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appendingPathComponent("staged.archive"), backup = folder.appendingPathComponent("previous.archive")
        try Data(value.utf8).write(to: source)
        try FileManager.default.copyItem(at: target, to: backup)
        return try ModInstallTransaction(game: game, files: [.init(source: source.path, target: target.path, backup: backup.path,
            originalSHA256: PathSafety.sha256(url: backup), installedSHA256: PathSafety.sha256(url: source))])
    }
    private func install(_ value: String) throws -> ModInstallTransaction {
        let plan = try transaction(value)
        try Data(contentsOf: URL(fileURLWithPath: plan.files[0].source)).write(to: target, options: .atomic)
        try store.remember(plan, game: game)
        return plan
    }
}
