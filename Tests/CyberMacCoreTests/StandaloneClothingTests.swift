import Foundation
import XCTest
@testable import CyberMacCore

final class StandaloneClothingTests: XCTestCase {
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
        let files = [StandaloneClothingPreparer.File(target: root.appendingPathComponent("game.bin").path,
            original: root.appendingPathComponent("original.bin").path, originalSHA256: originalHash,
            staged: root.appendingPathComponent("staged.bin").path, stagedSHA256: stagedHash)]
        let script = root.appendingPathComponent("final.redscripts"), aux = root.appendingPathComponent("aux.redscripts")
        let restore = root.appendingPathComponent("restore.command")
        let source = StandaloneClothingPreparer.restoreScript(files: files, executable: game.executableURL,
            scripts: script, auxiliary: aux, compiledSHA: stagedHash)
        XCTAssertFalse(source.contains(files[0].staged), "Recovery must survive removal of generated database payloads")
        XCTAssertTrue(source.contains(originalHash)); XCTAssertTrue(source.contains(stagedHash))
        let run = StandaloneClothingPreparer.runScript(files: files, game: game, scripts: script, auxiliary: aux,
            compiled: root.appendingPathComponent("compiled.redscripts"), compiledSHA: stagedHash, restore: restore)
        XCTAssertTrue(run.contains("trap cleanup EXIT")); XCTAssertTrue(run.contains("-scriptsBlobPath="))
        for (index, content) in [source, run].enumerated() {
            let file = root.appendingPathComponent("\(index).command"); try Data(content.utf8).write(to: file)
            _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-n", file.path], timeoutSeconds: 5)
        }
    }
}
