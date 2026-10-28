import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class ModPackageRouterTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testAuthoredBodyPresetRoutesWithoutClothingOrRuntimeAndShowsBothScopes() throws {
        let data = try JSONSerialization.data(withJSONObject: ["format": "cybermac-body-preset-v1", "name": "Lethal Curves maximum",
            "sourceSHA256": String(repeating: "a", count: 64), "bones": ["l_thigh_0_JNT": ["Scale": ["X": 1.2]]]])
        let package = try zip([("cybermac-body-preset.json", data)])
        guard case .body = try ModPackageRouter().route(package) else { return XCTFail("Expected body preset route") }
        XCTAssertEqual(try BodyModInstaller.variants(for: package),
            ["Lethal Curves maximum (V only)", "Lethal Curves maximum (V + NPCs test)"])
    }

    func testAuthoredBodyPresetRejectsInvalidScaleAndAdditionalPayload() throws {
        func data(scale: Double) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["format": "cybermac-body-preset-v1", "name": "Lethal Curves maximum",
                "sourceSHA256": String(repeating: "a", count: 64), "bones": ["l_thigh_0_JNT": ["Scale": ["X": scale]]]])
        }
        XCTAssertThrowsError(try ModPackageRouter().route(zip([("cybermac-body-preset.json", data(scale: -1))])))
        let mixed = try zip([("cybermac-body-preset.json", data(scale: 1.2)), ("extra.archive", Data())])
        XCTAssertThrowsError(try BodyModInstaller.recognizes(mixed))
    }

    func testGameplayBodyPresetValidatesFirstPersonBonesSeparately() throws {
        var recipe: [String: Any] = ["format": "cybermac-body-preset-v1", "name": "Gameplay",
            "sourceSHA256": String(repeating: "a", count: 64), "bones": ["l_SHL_1_JNT": ["Translation": ["X": 0.2405]]],
            "firstPersonBones": ["l_SHL_1_JNT": ["Translation": ["X": 0.2536]]]]
        let valid = try zip([("cybermac-body-preset.json", JSONSerialization.data(withJSONObject: recipe))])
        guard case .body = try ModPackageRouter().route(valid) else { return XCTFail("Expected both rigs to route as a body preset") }
        recipe["firstPersonBones"] = ["l_SHL_1_JNT": ["Scale": ["X": -1]]]
        XCTAssertThrowsError(try BodyModInstaller.recognizes(zip([("cybermac-body-preset.json", JSONSerialization.data(withJSONObject: recipe))])))
        recipe["firstPersonBones"] = [String: Any]()
        XCTAssertThrowsError(try BodyModInstaller.recognizes(zip([("cybermac-body-preset.json", JSONSerialization.data(withJSONObject: recipe))])))
    }

    func testScriptsAndInputModsShareAutomaticRoute() throws {
        let url = try zip([("r6/scripts/main.reds", Data()), ("r6/input/example_input.xml", Data("<bindings/>".utf8))])
        guard case .scripts = try ModPackageRouter().route(url) else { return XCTFail("Expected script route") }
    }
    func testArchiveCollectionRequiresChoiceAndDoesNotSelectAllAlternatives() throws {
        let url = try zip([("red.archive", Data()), ("blue.archive", Data())])
        guard case .appearance(let variants) = try ModPackageRouter().route(url) else { return XCTFail("Expected appearance route") }
        XCTAssertEqual(variants, ["blue.archive", "red.archive"])
        guard case .choices(let choices) = try AutomaticModInstaller(home: .init(homeURL: root.appendingPathComponent("app"))).prepare(url) else {
            return XCTFail("Choices must be returned without detecting or writing a game")
        }
        XCTAssertEqual(choices, variants)
    }
    func testMixedFrameworkPackageCannotPartiallyInstallScripts() throws {
        let url = try zip([("r6/scripts/main.reds", Data()), ("archive/pc/mod/item.archive.xl", Data())])
        guard case .blocked(let reason) = try ModPackageRouter().route(url) else { return XCTFail("Expected blocked route") }
        XCTAssertTrue(reason.contains("ArchiveXL"))
    }
    func testRuntimeDetectionUsesContentsAndMacMagic() throws {
        let url = try zip([("redscript/bin/scc", Data([0xcf, 0xfa, 0xed, 0xfe, 0]))])
        guard case .runtime(.redscript) = try ModPackageRouter().route(url) else { return XCTFail("Expected Mac runtime") }
    }
    func testWindowsCompilerIsBlockedEvenIfRenamedSCC() throws {
        let url = try zip([("scc", Data("MZWindows".utf8))])
        guard case .blocked(let message) = try ModPackageRouter().route(url) else { return XCTFail("Expected block") }
        XCTAssertTrue(message.contains("Mac executable"))
    }
    func testInputLoaderRuntimeHasItsOwnRoute() throws {
        let url = try zip([("input-loader/inputloader.pl", Data("use strict;".utf8))])
        guard case .runtime(.inputLoader) = try ModPackageRouter().route(url) else { return XCTFail("Expected input runtime") }
    }
    func testTraversalCannotBypassRouting() throws {
        let url = try zip([("../outside.reds", Data())])
        XCTAssertThrowsError(try ModPackageRouter().route(url))
    }
    func testSymlinkCannotBeInstalled() throws {
        let url = root.appendingPathComponent("link.zip")
        let archive = try Archive(url: url, accessMode: .create)
        let value = Data("outside".utf8)
        try archive.addEntry(with: "link", type: .symlink, uncompressedSize: Int64(value.count), provider: { _, _ in value })
        XCTAssertThrowsError(try ModPackageRouter().route(url))
    }
    func testRetainedCopyIsStableAndTamperingIsDetected() throws {
        let url = try zip([("main.reds", Data("source".utf8))])
        let router = ModPackageRouter(home: .init(homeURL: root.appendingPathComponent("app")))
        let retained = try router.retain(url)
        XCTAssertEqual(try router.retain(url), retained)
        try Data("tampered".utf8).write(to: retained)
        XCTAssertThrowsError(try router.retain(url))
    }
    private func zip(_ entries: [(String, Data)]) throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString + ".zip")
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
                data.subdata(in: Int(position)..<min(data.count, Int(position) + size))
            })
        }
        return url
    }
}
