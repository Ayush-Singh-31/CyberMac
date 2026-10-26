import Foundation
import XCTest
@testable import CyberMacCore

final class StandaloneClothingTests: XCTestCase {
    func testSelectionRefusesExistingLockWithoutRemovingAnotherSelectorsWork() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SelectionLock-\(UUID().uuidString)")
        let output = root.appendingPathComponent("wardrobe"), lock = output.appendingPathComponent(".selection-lock")
        try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sentinel = lock.appendingPathComponent("active")
        try Data("another selection".utf8).write(to: sentinel)
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: root.appendingPathComponent("unused"), dataURL: root, archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let manifest = StandaloneClothingPreparer.Manifest(gameApp: game.appURL.path, files: [],
            items: StandaloneClothingSource.wardrobePieces, compiledSHA256: String(repeating: "a", count: 64),
            gameplay: "fixture", limitations: "fixture", selection: "both", compiler: "unused", originalScripts: "unused")
        try JSONEncoder().encode(manifest).write(to: output.appendingPathComponent("clothing.json"))
        XCTAssertThrowsError(try StandaloneClothingPreparer().selectClothes(game: game, output: output, group: "jinguji"))
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "another selection")
        XCTAssertThrowsError(try StandaloneClothingPreparer().selectClothes(game: game, output: game.appURL, group: "jinguji"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: game.appURL.path))
    }

    func testRefreshRejectsMalformedHashesBeforeGeneratingCommands() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HashBoundary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: root.appendingPathComponent("unused"), dataURL: root, archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let manifest: [String: Any] = ["gameApp": game.appURL.path, "files": [], "compiledSHA256": "'; touch injected; '"]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("clothing.json"))
        XCTAssertThrowsError(try StandaloneClothingPreparer().refreshCommands(game: game, output: root)) { error in
            XCTAssertTrue(error.localizedDescription.contains("hashes are malformed"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Run New Clothing.command").path))
    }

    func testWardrobeSelectionLimitsGrantsAndKeepsAllLabelsWithoutEquipmentChanges() throws {
        let all = StandaloneClothingSource.wardrobePieces
        XCTAssertEqual(Set(all.map(\.record)).count, 7)
        for (group, count) in [("jinguji", 3), ("lucy", 4), ("both", 7), ("none", 0)] {
            let selected = try StandaloneClothingSource.selectedPieces(group: group)
            XCTAssertEqual(selected.count, count)
            let source = StandaloneClothingSource.render(pieces: all, showPhysicalClothes: true, delivery: selected, autoEquip: false)
            let ids = try XCTUnwrap(source.split(separator: "\n").first { $0.contains("let items:") })
            for piece in all {
                XCTAssertEqual(ids.contains(piece.record), selected.contains(piece))
                XCTAssertTrue(source.contains("return \"\(piece.label)\""))
            }
            XCTAssertFalse(source.contains("QueueRequest"))
            XCTAssertFalse(source.contains("UnequipWardrobeSet"))
            XCTAssertTrue(source.contains("/\(count) selected clothes"))
        }
        XCTAssertThrowsError(try StandaloneClothingSource.selectedPieces(group: "typo"))
        XCTAssertTrue(StandaloneClothingSource.render().contains("eq.QueueRequest(request)"), "Legacy equipment test remains supported")
    }

    func testChooserRunsOnlySelectedGroupWithQuotedWorkspacePaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Chooser ' $() \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = root.appendingPathComponent("args")
        let cli = root.appendingPathComponent("tool")
        try Data(("#!/bin/zsh\nprint -rl -- \"$@\" > " + PathSafety.shellQuoted(receipt.path) + "\n").utf8).write(to: cli)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        let run = root.appendingPathComponent("Run New Clothing.command")
        try Data("#!/bin/zsh\nprint launched\n".utf8).write(to: run)
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: root.appendingPathComponent("unused"), dataURL: root, archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let chooser = root.appendingPathComponent("Choose.command")
        let inputFile = root.appendingPathComponent("choice-input")
        try Data(StandaloneClothingPreparer.chooserScript(game: game, output: root, commandLineTool: cli).utf8).write(to: chooser)
        for (input, group) in [("1", "jinguji"), ("2", "lucy"), ("3", "both"), ("4", "none")] {
            try Data((input + "\n").utf8).write(to: inputFile)
            let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", "exec /bin/zsh " + PathSafety.shellQuoted(chooser.path) + " < " + PathSafety.shellQuoted(inputFile.path)], timeoutSeconds: 5)
            let args = try String(contentsOf: receipt, encoding: .utf8).split(separator: "\n").map(String.init)
            XCTAssertEqual(args, ["clothing", "select", "--out-dir", root.path, "--game-app", game.appURL.path, "--group", group])
            XCTAssertTrue(result.stdout.contains("launched"))
        }
        try FileManager.default.removeItem(at: receipt)
        try Data("bad\n".utf8).write(to: inputFile)
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", "exec /bin/zsh " + PathSafety.shellQuoted(chooser.path) + " < " + PathSafety.shellQuoted(inputFile.path)], timeoutSeconds: 5, allowFailure: true)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: receipt.path))
        XCTAssertFalse(result.stdout.contains("launched"))
    }

    func testGeneratedPreflightRunsAndRefusesFailedProcessEnumeration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Clothing guards ' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("game"), scripts = root.appendingPathComponent("scripts")
        try Data("fixture executable".utf8).write(to: executable)
        try Data("fixture scripts".utf8).write(to: scripts)
        let fixture = StandaloneClothingPreparer.preamble(executable: executable, scripts: scripts)
            .replacingOccurrences(of: EquipProbePreparer.executableSHA, with: try PathSafety.sha256(url: executable))
            .replacingOccurrences(of: EquipProbePreparer.originalSHA, with: try PathSafety.sha256(url: scripts))
        for (processResult, expectedExit) in [(1, Int32(0)), (0, Int32(1)), (3, Int32(1))] {
            // Only the process source and pinned fixture hashes are substituted.
            // The generated zsh declarations, conditionals and hash checks run.
            let source = fixture.replacingOccurrences(of: "/usr/bin/pgrep -x Cyberpunk2077", with: "/bin/sh -c 'exit \(processResult)'")
            let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", source], timeoutSeconds: 5, allowFailure: true)
            XCTAssertEqual(result.exitCode, expectedExit, result.stderr)
        }
    }

    func testInheritedItemBehaviorIsClonedIncludingFalseAndArrayValues() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("inherited-clothing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let arrayProps = ["statModifierGroups", "effectors", "statPools", "statModifiers", "weakspots", "objectActions"]
        let boolProps = ["savable", "isGarment", "canDrop"]
        func u32(_ value: UInt32) -> Data { var value = value.littleEndian; return withUnsafeBytes(of: &value) { Data($0) } }
        func u64(_ value: UInt64) -> Data { var value = value.littleEndian; return withUnsafeBytes(of: &value) { Data($0) } }
        func id(_ name: String) -> UInt64 { UInt64(TweakDBPackedStringAnalyzer.crc32(Array(name.utf8))) | (UInt64(name.utf8.count) << 32) }
        var data = Data(count: 32)
        data.append(u32(2)); data.append(Data(count: 40))
        let arrayOffset = data.count
        data.append(u32(1)); data.append(0x02); data.append(u64(id("Stats.Source1"))); data.append(u64(id("Stats.Source2")))
        data.append(u32(UInt32(arrayProps.count)))
        for property in arrayProps { data.append(u64(id("Items.Source.\(property)"))); data.append(u32(0)) }
        let boolOffset = data.count
        data.append(u32(2)); data.append(contentsOf: [0, 1]); data.append(u32(UInt32(boolProps.count)))
        for (index, property) in boolProps.enumerated() { data.append(u64(id("Items.Source.\(property)"))); data.append(u32(index == 1 ? 1 : 0)) }
        let recordOffset = data.count
        data.append(u32(1)); data.append(u64(id("Items.Source"))); data.append(u32(0x12345678))
        let queryOffset = data.count; data.append(u32(0))
        let tagOffset = data.count; data.append(u32(0))
        let header = [UInt32(0x0BB1DB47), 8, 4, 0x11223344, 32, UInt32(recordOffset), UInt32(queryOffset), UInt32(tagOffset)].reduce(Data()) { $0 + u32($1) }
        data.replaceSubrange(0..<32, with: header)
        for (index, type) in [("array:TweakDBID", 1, arrayProps.count, arrayOffset), ("Bool", 2, boolProps.count, boolOffset)].enumerated() {
            var row = u64(TweakDBPackedStringAnalyzer.fnv1a64(Array(type.0.utf8)))
            row.append(u32(UInt32(type.1))); row.append(u32(UInt32(type.2))); row.append(u32(UInt32(type.3)))
            data.replaceSubrange((36 + index * 20)..<(56 + index * 20), with: row)
        }
        let file = root.appendingPathComponent("source.bin"); try data.write(to: file)
        let report = try TweakDBCloneRecordStager().stage(request: .init(fileURL: file,
            outputDirectoryURL: root.appendingPathComponent("clone"), sourceRecord: "Items.Source", newRecord: "Items.Clone"))
        for property in arrayProps {
            let flat = try XCTUnwrap(report.clonedFlats.first { $0.property == property })
            XCTAssertEqual(flat.typeName, "array:TweakDBID")
            XCTAssertEqual(flat.valueSummary, "array:TweakDBID count=2")
            XCTAssertEqual(flat.sourceValueIndex, flat.newValueIndex)
        }
        XCTAssertEqual(report.clonedFlats.first { $0.property == "savable" }?.valueSummary, "false")
        XCTAssertEqual(report.clonedFlats.first { $0.property == "isGarment" }?.valueSummary, "true")
        XCTAssertEqual(report.clonedFlats.first { $0.property == "canDrop" }?.valueSummary, "false")
        XCTAssertTrue(report.stagedRecordsSortedByID)
    }

    func testCombinedCommandsParseQuotedPathsAndRestoreDoesNotNeedCompiledPayload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Clothes ' $() \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: root.appendingPathComponent("Game.app/Contents/MacOS/Cyberpunk2077"), dataURL: root.appendingPathComponent("Game.app/Contents/Data"), archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let originalHash = String(repeating: "a", count: 64), stagedHash = String(repeating: "b", count: 64)
        // The Lucy package restores two archives as well as both databases.
        let files = ["appearance.archive", "gamedata.archive", "tweakdb.bin", "tweakdb_ep1.bin"].map { name in
            StandaloneClothingPreparer.File(target: root.appendingPathComponent(name).path,
                original: root.appendingPathComponent("original-" + name).path, originalSHA256: originalHash,
                staged: root.appendingPathComponent("staged-" + name).path, stagedSHA256: stagedHash)
        }
        let script = root.appendingPathComponent("final.redscripts"), aux = root.appendingPathComponent("aux.redscripts")
        let restore = root.appendingPathComponent("restore.command")
        let source = StandaloneClothingPreparer.restoreScript(files: files, executable: game.executableURL,
            scripts: script, auxiliary: aux, compiledSHA: stagedHash)
        for file in files {
            XCTAssertFalse(source.contains(file.staged), "Recovery must survive removal of generated payloads")
            XCTAssertTrue(source.contains(PathSafety.shellQuoted(file.original)))
        }
        XCTAssertTrue(source.contains(originalHash)); XCTAssertTrue(source.contains(stagedHash))
        let run = StandaloneClothingPreparer.runScript(files: files, game: game, scripts: script, auxiliary: aux,
            compiled: root.appendingPathComponent("compiled.redscripts"), compiledSHA: stagedHash, restore: restore)
        XCTAssertTrue(run.contains("trap cleanup EXIT")); XCTAssertTrue(run.contains("-scriptsBlobPath="))
        for (index, content) in [source, run].enumerated() {
            let file = root.appendingPathComponent("\(index).command"); try Data(content.utf8).write(to: file)
            _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-n", file.path], timeoutSeconds: 5)
        }
    }

    func testLucyRecipeRejectsArchivePathTraversalBeforeReadingPayload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lucy recipe \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest: [String: Any] = ["version": 2, "archive": "../outside.archive", "archiveSHA256": "unused",
            "jacketSHA256": "85a010c28a0ca96c689f5fde2f97ec6f3e5be583f7cc9fd2e89b93a3c73db9ab",
            "clothesSHA256": "c8d434ce62e2f5eca2d2ec0c4274f7acca3a48c35db45035d19f7cb22a0a1c8f",
            "resourceHashes": [], "originalMeshHashes": []]
        let url = root.appendingPathComponent("lucy-assets.json")
        try JSONSerialization.data(withJSONObject: manifest).write(to: url)
        XCTAssertThrowsError(try IsolatedClothingAssets(manifestURL: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unsupported Lucy asset recipe"))
        }
    }
}
