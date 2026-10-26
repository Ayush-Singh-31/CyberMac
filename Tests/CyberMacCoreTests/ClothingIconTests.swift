import Foundation
import XCTest
@testable import CyberMacCore

final class ClothingIconTests: XCTestCase {
    func testUnavailableStatusDirectoryDoesNotAbortTheRequiredWorkflow() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let exe = root.appendingPathComponent("game"), scripts = root.appendingPathComponent("scripts"), helper = root.appendingPathComponent("helper")
        for file in [exe, scripts, helper] { try Data(file.lastPathComponent.utf8).write(to: file) }
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: exe, dataURL: root, archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let admin = root.appendingPathComponent("reached-admin")
        let source = StandaloneClothingPreparer.runScript(files: [], game: game, scripts: scripts,
            auxiliary: root.appendingPathComponent("aux"), compiled: helper, compiledSHA: try PathSafety.sha256(url: helper),
            restore: root.appendingPathComponent("missing/Restore.command"))
            .replacingOccurrences(of: EquipProbePreparer.executableSHA, with: try PathSafety.sha256(url: exe))
            .replacingOccurrences(of: EquipProbePreparer.originalSHA, with: try PathSafety.sha256(url: scripts))
            .replacingOccurrences(of: "/usr/bin/pgrep -x Cyberpunk2077", with: "/bin/sh -c 'exit 1'")
        let command = "sudo() { print reached > \(PathSafety.shellQuoted(admin.path)); return 88; }\n" + source
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-c", command], timeoutSeconds: 5, allowFailure: true)
        XCTAssertEqual(result.exitCode, 88)
        XCTAssertTrue(FileManager.default.fileExists(atPath: admin.path))
        XCTAssertTrue(result.stderr.contains("Could not update app status"))
    }

    func testLaunchPreflightFailureReportsFailedSessionBeforeAdministratorActions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("IconSession ' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("game"), scripts = root.appendingPathComponent("scripts")
        let target = root.appendingPathComponent("target"), admin = root.appendingPathComponent("admin")
        try Data("executable".utf8).write(to: executable); try Data("scripts".utf8).write(to: scripts)
        try Data("original".utf8).write(to: target)
        let game = GameInstall(appURL: root.appendingPathComponent("Game.app"), executableURL: executable, dataURL: root, archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        let file = StandaloneClothingPreparer.File(target: target.path, original: root.appendingPathComponent("missing").path,
            originalSHA256: String(repeating: "a", count: 64), staged: root.appendingPathComponent("staged").path, stagedSHA256: String(repeating: "b", count: 64))
        let source = StandaloneClothingPreparer.runScript(files: [file], game: game, scripts: scripts,
            auxiliary: root.appendingPathComponent("aux"), compiled: root.appendingPathComponent("helper"),
            compiledSHA: String(repeating: "c", count: 64), restore: root.appendingPathComponent("Restore.command"), inventoryOnly: true)
            .replacingOccurrences(of: EquipProbePreparer.executableSHA, with: try PathSafety.sha256(url: executable))
            .replacingOccurrences(of: EquipProbePreparer.originalSHA, with: try PathSafety.sha256(url: scripts))
            .replacingOccurrences(of: "/usr/bin/pgrep -x Cyberpunk2077", with: "/bin/sh -c 'exit 1'")
        let guarded = "sudo() { print unexpected > \(PathSafety.shellQuoted(admin.path)); return 99; }\n" + source
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-c", guarded], timeoutSeconds: 5, allowFailure: true)
        XCTAssertNotEqual(result.exitCode, 0)
        let session = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("session.json"))) as? [String: String]
        XCTAssertEqual(session?["status"], "failed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: admin.path))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "original")
    }

    func testUIIconClonePreservesSourceAndWritesResourceHashWithCorrectTypes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func u32(_ n: UInt32) -> Data { var x = n.littleEndian; return withUnsafeBytes(of: &x) { Data($0) } }
        func u64(_ n: UInt64) -> Data { var x = n.littleEndian; return withUnsafeBytes(of: &x) { Data($0) } }
        func tid(_ s: String) -> UInt64 { UInt64(TweakDBPackedStringAnalyzer.crc32(Array(s.utf8))) | UInt64(s.utf8.count) << 32 }
        let source = "UIIcon.ItemIcon", target = "UIIcon.CyberMac_Test"
        var d = Data(count: 32); d += u32(2); d += Data(count: 40)
        let nameOffset = d.count
        d += u32(1); d.append(0x84); d += Data("slot".utf8)
        d += u32(1); d += u64(tid(source + ".atlasPartName")); d += u32(0)
        let resourceOffset = d.count
        d += u32(1); d += u64(1234); d += u32(1); d += u64(tid(source + ".atlasResourcePath")); d += u32(0)
        let records = d.count; d += u32(1); d += u64(tid(source)); d += u32(0x9336bd0f)
        let queries = d.count; d += u32(0); let tags = d.count; d += u32(0)
        let header: [UInt32] = [0x0bb1db47, 8, 4, 77, 32, UInt32(records), UInt32(queries), UInt32(tags)]
        d.replaceSubrange(0..<32, with: header.reduce(Data()) { $0 + u32($1) })
        for (i, item) in [("CName", nameOffset), ("raRef:CResource", resourceOffset)].enumerated() {
            let row = u64(TweakDBPackedStringAnalyzer.fnv1a64(Array(item.0.utf8))) + u32(1) + u32(1) + u32(UInt32(item.1))
            d.replaceSubrange((36 + i * 20)..<(56 + i * 20), with: row)
        }
        let file = root.appendingPathComponent("source.bin"); try d.write(to: file)
        let path = "cybermac\\ui\\clothing.inkatlas"
        let report = try TweakDBCloneRecordStager().stage(request: .init(fileURL: file,
            outputDirectoryURL: root.appendingPathComponent("out"), sourceRecord: source, newRecord: target,
            overrides: [.cName(property: "atlasPartName", value: "corset"), .resource(property: "atlasResourcePath", path: path)]))
        XCTAssertEqual(report.clonedFlats.count, 2)
        XCTAssertEqual(report.knownSchemaPropertyCount, 2)
        XCTAssertTrue(report.conclusions.contains(.overrideFlatsResolved))
        let resource = try XCTUnwrap(report.verification?.knownFlats.first { $0.property == "atlasResourcePath" })
        XCTAssertEqual(resource.typeName, "raRef:CResource")
        XCTAssertTrue(resource.valueSummary?.lowercased().contains(String(TweakDBPackedStringAnalyzer.fnv1a64(Array(path.utf8)), radix: 16)) == true)
        XCTAssertEqual(try Data(contentsOf: file), d)
        XCTAssertEqual(TweakDBStructureInspector.itemRecordProperties.count, 91)
    }

    func testCustomPreviewMappingsRemainAvailableWhenOnlyOneItemIsGranted() {
        let items = StandaloneClothingSource.wardrobePieces
        let source = StandaloneClothingSource.render(pieces: items, delivery: [items[4]], autoEquip: false, customIcons: true)
        let grant = source.split(separator: "\n").first { $0.contains("let items:") }!
        XCTAssertTrue(grant.contains(items[4].record))
        XCTAssertFalse(grant.contains(items[0].record))
        for piece in items { XCTAssertTrue(source.contains("return \"CyberMac_\(piece.record.split(separator: ".").last!)\"")) }
        XCTAssertTrue(source.contains("return \"UIIcon.\" + custom"))
        XCTAssertFalse(source.contains("QueueRequest"))
        XCTAssertFalse(source.contains("UnequipWardrobeSet"))
    }

    func testPerPieceSelectionRejectsUnknownAndDuplicateRecordsBeforeWorkspaceAccess() {
        let game = GameInstall(appURL: URL(fileURLWithPath: "/unused.app"), executableURL: URL(fileURLWithPath: "/unused"), dataURL: URL(fileURLWithPath: "/unused"), archiveMacURL: nil, r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        for records in [["Items.Money"], ["Items.CyberMac_Jinguji_Corset", "Items.CyberMac_Jinguji_Corset"]] {
            XCTAssertThrowsError(try StandaloneClothingPreparer().selectClothes(game: game, output: URL(fileURLWithPath: "/missing"), records: records)) { error in
                XCTAssertTrue(error.localizedDescription.contains("unknown or duplicate"))
            }
        }
    }
}
