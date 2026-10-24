import Foundation
import XCTest
@testable import CyberMacCore

final class EquipProbeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("Equip probe ' $() \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testSourceRejectsInjectionAndOversizedRequests() throws {
        let generator = RedscriptEquipProbeGenerator()
        for items in [[], ["Items.X\"); GiveItem()"], ["Items." + String(repeating: "a", count: 250)],
                      (0..<9).map { "Items.Test\($0)" }] {
            XCTAssertThrowsError(try generator.source(itemIDs: items))
        }
        XCTAssertEqual(try generator.source(itemIDs: [" Items.Test ", "Items.Test"]),
                       try generator.source(itemIDs: ["Items.Test"]))
    }

    func testVerifiedRestoreCopyRejectsCorruptionAndSymlinks() throws {
        let file = root.appendingPathComponent("original.redscripts")
        try Data("original".utf8).write(to: file)
        let hash = try PathSafety.sha256(url: file)
        XCTAssertNoThrow(try EquipProbePreparer.verify(file, sha256: hash))
        let link = root.appendingPathComponent("link.redscripts")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try EquipProbePreparer.verify(link, sha256: hash))
        try Data("modified".utf8).write(to: file)
        XCTAssertThrowsError(try EquipProbePreparer.verify(file, sha256: hash))
    }

    func testPreparationCannotOverwriteAnExistingExperiment() throws {
        let output = root.appendingPathComponent("existing")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let sentinel = output.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: sentinel)
        XCTAssertThrowsError(try prepare(output: output)) { error in
            XCTAssertTrue(String(describing: error).contains("never overwritten"))
        }
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep".utf8))
    }

    func testPreparationRejectsGamePathsIncludingThroughDirectorySymlink() throws {
        let app = game.appURL
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("redirect")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app)
        XCTAssertThrowsError(try prepare(output: link.appendingPathComponent("new"))) { error in
            XCTAssertTrue(String(describing: error).contains("outside the game"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("new").path))
    }

    func testUnsupportedGameFailsBeforeCreatingOutput() throws {
        try FileManager.default.createDirectory(at: game.executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("unsupported game build".utf8).write(to: game.executableURL)
        let output = root.appendingPathComponent("new")
        XCTAssertThrowsError(try prepare(output: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try Data(contentsOf: game.executableURL), Data("unsupported game build".utf8))
    }

    func testManualScriptsParsePathsWithShellMetacharacters() throws {
        for restore in [false, true] {
            let script = EquipProbePreparer.manualScript(executable: game.executableURL,
                target: root.appendingPathComponent("target ' $().redscripts"),
                compiled: root.appendingPathComponent("compiled ' $().redscripts"),
                compiledSHA: String(repeating: "a", count: 64), restore: restore)
            let url = root.appendingPathComponent("\(restore).command")
            try Data(script.utf8).write(to: url)
            let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-n", url.path], timeoutSeconds: 5)
            XCTAssertEqual(result.exitCode, 0)
        }
        let combined = EquipProbePreparer.combinedScript(executable: game.executableURL,
            target: root.appendingPathComponent("target"), compiled: root.appendingPathComponent("compiled"),
            compiledSHA: String(repeating: "a", count: 64),
            commandLineTool: root.appendingPathComponent("cli ' $()"), directory: root)
        let url = root.appendingPathComponent("combined.command")
        try Data(combined.utf8).write(to: url)
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-n", url.path], timeoutSeconds: 5)
    }

    func testRunnerRejectsOldOrOversizedManifestBeforeStartingCapture() throws {
        let file = root.appendingPathComponent("probe.json")
        try JSONSerialization.data(withJSONObject: ["probeVersion": "1", "gameApp": "/Applications/Cyberpunk2077.app"])
            .write(to: file)
        XCTAssertThrowsError(try EquipProbeRunner().run(directory: root))
        try Data(repeating: 32, count: 65 * 1024).write(to: file)
        XCTAssertThrowsError(try EquipProbeRunner().run(directory: root))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["probe.json"])
    }

    func testExplicitLaunchUsesOneArgumentAndRequiresTheFixedAuxiliaryPath() throws {
        let auxiliary = game.appURL.appendingPathComponent("Contents/Data/r6/cache/cybermac-equip-probe.redscripts")
        var manifest = ["probeVersion": "3", "launchMode": "explicit-script-file", "scriptPath": auxiliary.path]
        XCTAssertEqual(try EquipProbeRunner.scriptURL(game: game, manifest: manifest), auxiliary)
        let arguments = EquipProbeRunner.launchArguments(app: game.appURL, script: auxiliary, explicit: true)
        XCTAssertEqual(arguments, ["-W", game.appURL.path, "--args", "-scriptsBlobPath=\(auxiliary.path)"])
        // Spaces and shell metacharacters in a path remain part of one argv value.
        XCTAssertTrue(arguments.last!.contains("' $()"))
        manifest["scriptPath"] = root.appendingPathComponent("untrusted.redscripts").path
        XCTAssertThrowsError(try EquipProbeRunner.scriptURL(game: game, manifest: manifest))
        manifest["scriptPath"] = auxiliary.path
        manifest["launchMode"] = "unknown"
        XCTAssertThrowsError(try EquipProbeRunner.scriptURL(game: game, manifest: manifest))
        XCTAssertEqual(try EquipProbeRunner.scriptURL(game: game, manifest: ["probeVersion": "2"]).lastPathComponent,
                       "final.redscripts")
    }

    private var game: GameInstall {
        let app = root.appendingPathComponent("Game.app")
        return GameInstall(appURL: app, executableURL: app.appendingPathComponent("Contents/MacOS/Cyberpunk2077"),
            dataURL: app.appendingPathComponent("Contents/Data"), archiveMacURL: nil, r6URL: nil,
            storefront: .macAppStore, displayName: "Test")
    }

    private func prepare(output: URL) throws -> URL {
        try EquipProbePreparer().prepare(game: game, compiler: root.appendingPathComponent("compiler"),
            originalCache: root.appendingPathComponent("restore.redscripts"), outputDirectory: output,
            itemIDs: ["Items.Vest_08_basic_01"])
    }
}
