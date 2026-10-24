import Foundation
import CryptoKit
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class AppearancePatchTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CyberMac Appearance 'Tests' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testNativeReaderRejectsTruncationBadCountsAndOutOfBoundsPayloads() throws {
        let file = root.appendingPathComponent("malformed.archive")
        try Data("RDAR".utf8).write(to: file)
        XCTAssertThrowsError(try NativeArchive.read(file))
        let valid = try archive("valid.archive", records: [Fixture(1, "payload")])
        let original = try Data(contentsOf: valid)
        let parsed = try NativeArchive.read(valid)
        var bad = original
        put32(UInt32.max, &bad, Int(try integer64(original, 8)) + 16)
        try bad.write(to: file)
        XCTAssertThrowsError(try NativeArchive.read(file))
        var index = parsed.index
        put64(UInt64(original.count + 100), &index, 28 + 56)
        put64(NativeArchive.crc64(Data(index.dropFirst(16))), &index, 8)
        bad = original; bad.replaceSubrange(Int(try integer64(original, 8))..<Int(try integer64(original, 8))+index.count, with: index)
        try bad.write(to: file)
        XCTAssertThrowsError(try NativeArchive.read(file))
    }

    func testNativeReaderRejectsBadChecksumAndRecordRanges() throws {
        let file = try archive("range.archive", records: [Fixture(1, "payload")])
        var bytes = try Data(contentsOf: file)
        let position = Int(try integer64(bytes, 8))
        bytes[position + 8] ^= 1
        try bytes.write(to: file)
        XCTAssertThrowsError(try NativeArchive.read(file))
        bytes[position + 8] ^= 1
        var index = Data(bytes[position..<position+100])
        put32(5, &index, 28 + 24)
        put64(NativeArchive.crc64(Data(index.dropFirst(16))), &index, 8)
        bytes.replaceSubrange(position..<position+index.count, with: index)
        try bytes.write(to: file)
        XCTAssertThrowsError(try NativeArchive.read(file))
    }

    func testNativeStagePreservesDonorMetadataDependenciesAndUnchangedResources() throws {
        let official = try archive("official.archive", records: [Fixture(1, "old", [91]), Fixture(2, "unchanged")])
        let mod = try archive("mod.archive", records: [Fixture(1, "new garment", [92, 93], stamp: 444, inline: 7)])
        let before = try PathSafety.sha256(url: official)
        let source = try NativeArchive.read(mod), target = try NativeArchive.read(official)
        let output = try NativeArchive.stageReplacing(source: source, target: target, hashes: [1], output: root.appendingPathComponent("staged.archive"))
        let replacement = try XCTUnwrap(output.records.first { $0.hash == 1 })
        XCTAssertEqual(try output.payloadDigest(replacement), try source.payloadDigest(source.records[0]))
        XCTAssertEqual(Array(output.dependencies[replacement.dependencies]), [92, 93])
        XCTAssertEqual(replacement.bytes.prefix(20), source.records[0].bytes.prefix(20))
        XCTAssertEqual(replacement.bytes.suffix(20), source.records[0].bytes.suffix(20))
        let untouched = try XCTUnwrap(output.records.first { $0.hash == 2 })
        XCTAssertEqual(try output.payloadDigest(untouched), try target.payloadDigest(target.records[1]))
        XCTAssertEqual(try PathSafety.sha256(url: official), before)
    }

    func testAmbiguousDuplicatesAreRejectedBeforeOutputAndInputsRemainIntact() throws {
        let official = try archive("ambiguous.archive", records: [Fixture(1, "one"), Fixture(1, "two")])
        let mod = try archive("mod.archive", records: [Fixture(1, "new")])
        let before = try PathSafety.sha256(url: official)
        let output = root.appendingPathComponent("output.archive")
        XCTAssertThrowsError(try NativeArchive.stageReplacing(source: NativeArchive.read(mod), target: NativeArchive.read(official), hashes: [1], output: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try PathSafety.sha256(url: official), before)
    }

    func testIdenticalDuplicatesAllReceiveTheReplacement() throws {
        let official = try archive("duplicate.archive", records: [Fixture(1, "same"), Fixture(1, "same")])
        let mod = try archive("mod.archive", records: [Fixture(1, "new")])
        let output = try NativeArchive.stageReplacing(source: NativeArchive.read(mod), target: NativeArchive.read(official), hashes: [1], output: root.appendingPathComponent("output.archive"))
        XCTAssertEqual(output.records.count, 2)
        XCTAssertEqual(try output.payloadDigest(output.records[0]), try output.payloadDigest(output.records[1]))
    }

    func testNewGarmentAssetsAreInsertedWithSortedHashesAndTheirOwnDependencies() throws {
        let (game, manager) = try game(duplicateOwner: false)
        let mod = try archive("garment-new-mesh.archive", records: [Fixture(1, "jacket", [3]), Fixture(3, "new mesh", [2])])
        let plan = try manager.inspect(packageURL: mod, game: game)
        XCTAssertTrue(plan.canStage)
        XCTAssertEqual(plan.unmatchedResources, ["0x0000000000000003"])
        XCTAssertEqual(plan.newResourceTarget, "Data/archive/Mac/content/basegame_test.archive")
        let stage = try manager.stage(id: plan.id, game: game)
        XCTAssertEqual(stage.files.count, 1)
        XCTAssertEqual(stage.files[0].resourceCount, 2)
        let staged = try NativeArchive.read(URL(fileURLWithPath: stage.files[0].stagedPath))
        XCTAssertEqual(staged.records.map(\.hash), [1, 2, 3])
        let mesh = try XCTUnwrap(staged.records.first { $0.hash == 3 })
        XCTAssertEqual(Array(staged.dependencies[mesh.dependencies]), [2])
        let source = try NativeArchive.read(mod)
        XCTAssertEqual(try staged.payloadDigest(mesh), try source.payloadDigest(source.records[1]))
    }

    func testInspectFindsEveryOfficialOwnerAndResolvesDependenciesAcrossArchives() throws {
        let (game, manager) = try game()
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket", [2])])
        let plan = try manager.inspect(packageURL: mod, game: game)
        XCTAssertTrue(plan.canStage)
        XCTAssertEqual(plan.gameVersion, "2.5.0")
        XCTAssertEqual(plan.targets.count, 2)
        XCTAssertEqual(plan.officialArchiveCount, 2)
        XCTAssertEqual(plan.targets.map(\.resourceHashes), [["0x0000000000000001"], ["0x0000000000000001"]])
        XCTAssertTrue(plan.unresolvedDependencies.isEmpty)
    }

    func testUnknownResourcesAndDependenciesBlockStaging() throws {
        let (game, manager) = try game()
        let mod = try archive("addon.archive", records: [Fixture(1, "jacket", [99]), Fixture(3, "new item")])
        let plan = try manager.inspect(packageURL: mod, game: game)
        XCTAssertFalse(plan.canStage)
        XCTAssertEqual(plan.unmatchedResources, ["0x0000000000000003"])
        XCTAssertEqual(plan.unresolvedDependencies, ["0x0000000000000063"])
        XCTAssertThrowsError(try manager.stage(id: plan.id, game: game))
    }

    func testStageAndManualInstallRestoreVerificationOnFixtureGame() throws {
        let (game, manager) = try game()
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket", [2])])
        let plan = try manager.inspect(packageURL: mod, game: game)
        let original = try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/\(plan.targets[0].relativePath)"))
        let stage = try manager.stage(id: plan.id, game: game)
        XCTAssertEqual(stage.files.count, 2)
        XCTAssertFalse(stage.gameplayVerified)
        // Refresh unsafe commands persisted by older versions without restaging archives.
        var legacy = stage
        legacy.files[0].installCommand = "sudo cp -c old-source old-target"
        legacy.files[0].restoreCommand = "sudo cp -c old-backup old-target"
        let stageURL = manager.home.homeURL.appendingPathComponent("generated/appearance/\(plan.id)/stage.json")
        try JSONEncoder.cybermac.encode(legacy).write(to: stageURL)
        let refreshed = try manager.loadStage(plan.id)
        XCTAssertFalse(refreshed.files[0].installCommand.contains("sudo cp"))
        XCTAssertFalse(refreshed.files[0].restoreCommand.contains("sudo cp"))
        XCTAssertEqual(try PathSafety.sha256(url: game.appURL.appendingPathComponent("Contents/\(plan.targets[0].relativePath)")), original)
        XCTAssertFalse(try manager.verify(id: plan.id, game: game).matched)
        for file in stage.files {
            let target = game.appURL.appendingPathComponent("Contents/\(file.relativePath)")
            XCTAssertTrue(file.installCommand.contains("sudo /bin/mv"))
            XCTAssertFalse(file.installCommand.contains("sudo cp"))
            try FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(atPath: file.stagedPath, toPath: target.path)
        }
        XCTAssertTrue(try manager.verify(id: plan.id, game: game).matched)
        XCTAssertFalse(try manager.verify(id: plan.id, game: game).gameplayVerified)
        for file in stage.files {
            let target = game.appURL.appendingPathComponent("Contents/\(file.relativePath)")
            try FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(atPath: file.backupPath, toPath: target.path)
        }
        XCTAssertTrue(try manager.verify(id: plan.id, game: game, restore: true).matched)
    }

    func testChangedPayloadWithUnchangedIndexCannotBecomeANewBaseline() throws {
        let (game, manager) = try game()
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket")])
        let plan = try manager.inspect(packageURL: mod, game: game)
        let target = game.appURL.appendingPathComponent("Contents/\(plan.targets[0].relativePath)")
        let handle = try FileHandle(forUpdating: target)
        try handle.seek(toOffset: 52); try handle.write(contentsOf: Data("X".utf8)); try handle.close()
        XCTAssertThrowsError(try manager.stage(id: plan.id, game: game))
    }

    func testZipVariantsRequireSelectionAndExtractOnlyTheChosenArchive() throws {
        let (game, manager) = try game()
        let first = try Data(contentsOf: archive("first.archive", records: [Fixture(1, "jacket")]))
        let second = try Data(contentsOf: archive("second.archive", records: [Fixture(1, "another jacket")]))
        let zip = try zip("variants.zip", entries: [("a/first.archive", first), ("b/second.archive", second),
            ("Codes.txt", Data(#"Game.AddToInventory("Items.Vest_08_basic_01", 1)"#.utf8))])
        XCTAssertThrowsError(try manager.inspect(packageURL: zip, game: game))
        XCTAssertThrowsError(try manager.inspect(packageURL: zip, game: game, archiveEntry: "missing.archive"))
        let plan = try manager.inspect(packageURL: zip, game: game, archiveEntry: "b/second.archive")
        XCTAssertEqual(plan.sourceSHA256, PathSafety.sha256(data: second))
        XCTAssertEqual(plan.itemIDs, ["Items.Vest_08_basic_01"])
        XCTAssertEqual(plan.selectedArchiveEntry, "b/second.archive")
    }

    func testFrameworkPackagesAreNotSilentlyReducedToAnArchiveReplacement() throws {
        let (game, manager) = try game()
        let bytes = try Data(contentsOf: archive("garment.archive", records: [Fixture(1, "jacket")]))
        for extra in ["archive/pc/mod/garment.archive.xl", "r6/scripts/garment.reds", "r6/tweaks/garment.yaml"] {
            let package = try zip("\(UUID().uuidString).zip", entries: [("archive/pc/mod/garment.archive", bytes), (extra, Data("content".utf8))])
            XCTAssertThrowsError(try manager.inspect(packageURL: package, game: game))
        }
    }

    func testVerificationRejectsAlteredStagedCopyAndBackup() throws {
        let (game, manager) = try game()
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket")])
        let first = try manager.inspect(packageURL: mod, game: game)
        let stage = try manager.stage(id: first.id, game: game)
        try Data("corrupted output".utf8).write(to: URL(fileURLWithPath: stage.files[0].stagedPath))
        XCTAssertThrowsError(try manager.verify(id: first.id, game: game, restore: true))
        let second = try manager.inspect(packageURL: mod, game: game)
        let next = try manager.stage(id: second.id, game: game)
        let backup = URL(fileURLWithPath: next.files[0].backupPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        try Data("corrupted backup".utf8).write(to: backup)
        XCTAssertThrowsError(try manager.verify(id: second.id, game: game, restore: true))
    }

    func testChangedSourceAndGameVersionInvalidateThePlan() throws {
        let (game, manager) = try game()
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket")])
        let plan = try manager.inspect(packageURL: mod, game: game)
        let stored = manager.home.generatedURL.appendingPathComponent("appearance/\(plan.id)/source.archive")
        let other = try archive("other.archive", records: [Fixture(1, "different jacket")])
        try FileManager.default.removeItem(at: stored); try FileManager.default.copyItem(at: other, to: stored)
        XCTAssertThrowsError(try manager.stage(id: plan.id, game: game))
        let newPlan = try manager.inspect(packageURL: mod, game: game)
        try Data("changed executable".utf8).write(to: game.executableURL)
        XCTAssertThrowsError(try manager.stage(id: newPlan.id, game: game))
    }

    func testManagedSymlinkIntoGameAndInvalidIDsAreRefused() throws {
        let (game, manager) = try game()
        try FileManager.default.createDirectory(at: manager.home.homeURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: manager.home.generatedURL, withDestinationURL: game.appURL)
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket")])
        XCTAssertThrowsError(try manager.inspect(packageURL: mod, game: game))
        XCTAssertThrowsError(try manager.loadPlan("../outside"))
    }

    func testStreamingHashMatchesInMemoryHashAcrossChunkBoundaries() throws {
        let bytes = Data(repeating: 73, count: 5 * 1024 * 1024 + 17)
        let file = root.appendingPathComponent("large-hash.bin")
        try bytes.write(to: file)
        XCTAssertEqual(try PathSafety.sha256(url: file), PathSafety.sha256(data: bytes))
        try Data().write(to: file)
        XCTAssertEqual(try PathSafety.sha256(url: file), PathSafety.sha256(data: Data()))
    }

    func testRepeatedAppearanceExperimentsReuseOneVerifiedOriginalPerArchive() throws {
        let (game, manager) = try game(duplicateOwner: false)
        let mod = try archive("garment.archive", records: [Fixture(1, "jacket")])
        let first = try manager.inspect(packageURL: mod, game: game)
        let one = try manager.stage(id: first.id, game: game)
        let second = try manager.inspect(packageURL: mod, game: game)
        let two = try manager.stage(id: second.id, game: game)
        XCTAssertEqual(one.files[0].backupID, two.files[0].backupID)
        XCTAssertEqual(try OfficialArchiveBackupManager(home: manager.home).list().count, 1)
        XCTAssertEqual(one.files[0].stagedSHA256, two.files[0].stagedSHA256)
    }

    func testItemDeliveryRequiresACompilerVersionCompatibleWithTheGame() {
        XCTAssertFalse(AppearancePatchManager.supportsItemDelivery("0.5.31"))
        XCTAssertTrue(AppearancePatchManager.supportsItemDelivery("0.5.32"))
        XCTAssertTrue(AppearancePatchManager.supportsItemDelivery("0.5.33"))
        XCTAssertFalse(AppearancePatchManager.supportsItemDelivery(nil))
        XCTAssertFalse(AppearancePatchManager.supportsItemDelivery("0.5.32-preview1"))
    }

    func testItemDeliveryCompilesInIsolationAndVerifiesFixtureInstallAndRestore() throws {
        let (game, manager) = try game()
        let plan = try clothingDeliveryPlan(game: game, manager: manager)
        let original = game.dataURL.appendingPathComponent("r6/cache/final.redscripts")
        let before = try Data(contentsOf: original)
        let delivery = try manager.prepareItemDelivery(id: plan.id, game: game, runtimeZipURL: runtime("0.5.32"))
        XCTAssertEqual(delivery.itemIDs, ["Items.Vest_08_basic_01"])
        XCTAssertFalse(delivery.gameplayVerified)
        var legacy = delivery
        legacy.installCommand = "sudo cp -c old-source old-target"
        legacy.restoreCommand = "sudo cp -c old-backup old-target"
        let deliveryURL = manager.home.generatedURL.appendingPathComponent("appearance/\(plan.id)/item-delivery/delivery.json")
        try JSONEncoder.cybermac.encode(legacy).write(to: deliveryURL)
        let refreshed = try manager.loadItemDelivery(plan.id)
        XCTAssertFalse(refreshed.installCommand.contains("sudo cp"))
        XCTAssertFalse(refreshed.restoreCommand.contains("sudo cp"))
        XCTAssertEqual(try Data(contentsOf: original), before)
        XCTAssertTrue(delivery.workspacePath.contains("\(plan.id)/item-delivery/workspace"))
        XCTAssertFalse(try manager.verifyItemDelivery(id: plan.id, game: game).matched)
        XCTAssertTrue(try manager.verifyItemDelivery(id: plan.id, game: game, restore: true).matched)
        try Data(contentsOf: URL(fileURLWithPath: delivery.compiledPath)).write(to: original)
        XCTAssertTrue(try manager.verifyItemDelivery(id: plan.id, game: game).matched)
        XCTAssertFalse(try manager.verifyItemDelivery(id: plan.id, game: game).gameplayVerified)
        try before.write(to: original)
        XCTAssertTrue(try manager.verifyItemDelivery(id: plan.id, game: game, restore: true).matched)
        try Data("tampered".utf8).write(to: URL(fileURLWithPath: delivery.compiledPath))
        XCTAssertThrowsError(try manager.verifyItemDelivery(id: plan.id, game: game, restore: true))
    }

    func testItemDeliveryRejectsOldRuntimeAndMissingGarmentIDsWithoutLeavingOutput() throws {
        let (game, manager) = try game()
        let plan = try clothingDeliveryPlan(game: game, manager: manager)
        XCTAssertThrowsError(try manager.prepareItemDelivery(id: plan.id, game: game, runtimeZipURL: runtime("0.5.31")))
        let folder = manager.home.generatedURL.appendingPathComponent("appearance/\(plan.id)/item-delivery")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        let mod = try archive("no-codes.archive", records: [Fixture(1, "jacket")])
        let noCodes = try manager.inspect(packageURL: mod, game: game)
        XCTAssertThrowsError(try manager.prepareItemDelivery(id: noCodes.id, game: game, runtimeZipURL: runtime("0.5.32")))
    }

    func testItemDeliveryRefusesToUseAnAlteredScriptCacheAsOriginal() throws {
        let (game, manager) = try game()
        let plan = try clothingDeliveryPlan(game: game, manager: manager)
        let target = game.dataURL.appendingPathComponent("r6/cache/final.redscripts")
        try Data("other mod".utf8).write(to: target)
        XCTAssertThrowsError(try manager.prepareItemDelivery(id: plan.id, game: game, runtimeZipURL: runtime("0.5.32")))
        XCTAssertEqual(try Data(contentsOf: target), Data("other mod".utf8))
    }

    private func clothingDeliveryPlan(game: GameInstall, manager: AppearancePatchManager) throws -> AppearancePatchPlan {
        let mod = try Data(contentsOf: archive("clothing.archive", records: [Fixture(1, "jacket")]))
        let package = try zip("clothing.zip", entries: [("clothing.archive", mod), ("Codes.txt", Data("Items.Vest_08_basic_01".utf8))])
        return try manager.inspect(packageURL: package, game: game)
    }

    private func runtime(_ version: String) throws -> URL {
        // Fixture compiler exercises isolation, backup and verification; actual 2.5 compilation is checked separately.
        let script = """
        #!/bin/sh
        if [ "$2" = "-h" ]; then exit 0; fi
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "-outputCacheFile" ]; then
            shift
            printf '%s' 'fixture-compiled-clothing-helper' > "$1"
            exit 0
          fi
          shift
        done
        exit 1
        """
        return try zip("redscript-v\(version)-macos.zip", entries: [("engine/tools/scc", Data(script.utf8))])
    }

    private func game(duplicateOwner: Bool = true) throws -> (GameInstall, AppearancePatchManager) {
        let app = root.appendingPathComponent("Cyberpunk2077.app"), contents = app.appendingPathComponent("Contents")
        let one = try archive("one.archive", records: [Fixture(1, "stock"), Fixture(2, "dependency")])
        let two = try archive("two.archive", records: [Fixture(duplicateOwner ? 1 : 7, "stock patch")])
        var files: [String: [String: Data]] = [:]
        for (source, relative) in [(one, "Data/archive/Mac/content/basegame_test.archive"), (two, "Data/archive/Mac/ep1/ep1_test.archive")] {
            let target = contents.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: target)
            files[relative] = ["hash2": Data(SHA256.hash(data: try Data(contentsOf: source)))]
        }
        let cache = contents.appendingPathComponent("Data/r6/cache/final.redscripts")
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        let scripts = Data("fixture vanilla scripts".utf8)
        try scripts.write(to: cache)
        files["Data/r6/cache/final.redscripts"] = ["hash2": Data(SHA256.hash(data: scripts))]
        let seal = contents.appendingPathComponent("_CodeSignature/CodeResources")
        try FileManager.default.createDirectory(at: seal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["files2": files], format: .xml, options: 0).write(to: seal)
        let executable = contents.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fixture executable".utf8).write(to: executable)
        let info = ["CFBundleIdentifier": "test.cyberpunk", "CFBundleShortVersionString": "2.5.0", "CFBundleVersion": "123"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let game = GameInstall(appURL: app, executableURL: executable, dataURL: contents.appendingPathComponent("Data"), archiveMacURL: contents.appendingPathComponent("Data/archive/Mac"), r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
        return (game, AppearancePatchManager(home: CyberMacHomeManager(homeURL: root.appendingPathComponent("home"))))
    }

    private struct Fixture {
        let hash: UInt64, payload: Data, deps: [UInt64], stamp: UInt64, inline: UInt32
        init(_ hash: UInt64, _ text: String, _ deps: [UInt64] = [], stamp: UInt64 = 123, inline: UInt32 = 0) {
            self.hash = hash; payload = Data(text.utf8); self.deps = deps; self.stamp = stamp; self.inline = inline
        }
    }
    private func zip(_ name: String, entries: [(String, Data)]) throws -> URL {
        let url = root.appendingPathComponent(name)
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            })
        }
        return url
    }
    private func archive(_ name: String, records: [Fixture]) throws -> URL {
        var file = Data(count: 52), payloads: [(UInt64, Fixture)] = []
        file.replaceSubrange(0..<4, with: Data("RDAR".utf8)); put32(12, &file, 4)
        for record in records { payloads.append((UInt64(file.count), record)); file.append(record.payload) }
        let position = (file.count + 4095) / 4096 * 4096
        file.append(Data(count: position - file.count))
        let depCount = records.reduce(0) { $0 + $1.deps.count }
        var index = Data(count: 28 + records.count * 72 + depCount * 8)
        put32(8, &index, 0); put32(UInt32(index.count - 8), &index, 4)
        put32(UInt32(records.count), &index, 16); put32(UInt32(records.count), &index, 20); put32(UInt32(depCount), &index, 24)
        var dep = 0
        for (i, pair) in payloads.enumerated() {
            let record = pair.1, at = 28 + i * 56, segment = 28 + records.count * 56 + i * 16
            put64(record.hash, &index, at); put64(record.stamp, &index, at + 8); put32(record.inline, &index, at + 16)
            put32(UInt32(i), &index, at + 20); put32(UInt32(i+1), &index, at + 24)
            put32(UInt32(dep), &index, at + 28); put32(UInt32(dep + record.deps.count), &index, at + 32)
            index.replaceSubrange(at+36..<at+56, with: Data(Insecure.SHA1.hash(data: record.payload)))
            put64(pair.0, &index, segment); put32(UInt32(record.payload.count), &index, segment + 8); put32(UInt32(record.payload.count), &index, segment + 12)
            for hash in record.deps { put64(hash, &index, 28 + records.count * 72 + dep * 8); dep += 1 }
        }
        put64(NativeArchive.crc64(Data(index.dropFirst(16))), &index, 8)
        file.append(index); put64(UInt64(position), &file, 8); put32(UInt32(index.count), &file, 16); put64(UInt64(file.count), &file, 32)
        let url = root.appendingPathComponent(name); try file.write(to: url); return url
    }
    private func put32(_ value: UInt32, _ data: inout Data, _ offset: Int) {
        for i in 0..<4 { data[offset+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
    }
    private func put64(_ value: UInt64, _ data: inout Data, _ offset: Int) {
        for i in 0..<8 { data[offset+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
    }
    private func integer64(_ data: Data, _ offset: Int) throws -> UInt64 {
        (0..<8).reduce(UInt64(0)) { $0 | UInt64(data[offset+$1]) << ($1*8) }
    }
}
