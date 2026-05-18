import Foundation
import XCTest
@testable import CyberMacCore

final class OutfitBundleManagerTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var patchedArchiveURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacOutfitBundleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        try home.bootstrap()

        patchedArchiveURL = tempDir.appendingPathComponent("basegame_4_appearance.archive")
        try Data("fake-archive-contents".utf8).write(to: patchedArchiveURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Create

    func testCreateProducesBundleJSONAtOutAndRegistersInHome() throws {
        let outURL = tempDir.appendingPathComponent("lucy.outfit.json")
        let manager = OutfitBundleManager(home: home)
        let result = try manager.create(request: defaultCreateRequest(outURL: outURL))

        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path))
        XCTAssertEqual(result.bundleURL, outURL)
        XCTAssertNotNil(result.homeRegistrationURL)
        if let registration = result.homeRegistrationURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: registration.path))
            XCTAssertTrue(registration.path.contains(home.outfitBundlesURL.path))
        }
        XCTAssertEqual(result.bundle.displayName, "Lucy Outfit")
        XCTAssertEqual(result.bundle.targetArchive, "Data/archive/Mac/content/basegame_4_appearance.archive")
        XCTAssertEqual(result.bundle.affectedItemIDs, ["Items.Lucy_Clothes", "Items.Lucy_Jacket"])
        XCTAssertEqual(result.bundle.affectedAssets, ["base/characters/lucy_clothes.mesh", "base/characters/lucy_jacket.mesh"])
        XCTAssertEqual(result.bundle.status, .staged)
        XCTAssertEqual(result.bundle.patchedArchiveSizeBytes, UInt64("fake-archive-contents".utf8.count))
        XCTAssertFalse(result.bundle.patchedArchiveSHA256.isEmpty)
    }

    func testCreateRoundTripsThroughLoad() throws {
        let outURL = tempDir.appendingPathComponent("roundtrip.outfit.json")
        let manager = OutfitBundleManager(home: home)
        let created = try manager.create(request: defaultCreateRequest(outURL: outURL))
        let loaded = try manager.load(bundleURL: outURL)

        XCTAssertEqual(loaded.id, created.bundle.id)
        XCTAssertEqual(loaded.affectedItemIDs, created.bundle.affectedItemIDs)
        XCTAssertEqual(loaded.affectedAssets, created.bundle.affectedAssets)
        XCTAssertEqual(loaded.patchedArchiveSHA256, created.bundle.patchedArchiveSHA256)
        XCTAssertEqual(loaded.backupID, created.bundle.backupID)
        XCTAssertEqual(loaded.status, .staged)
    }

    func testCreateRejectsItemIdMissingPrefix() {
        let outURL = tempDir.appendingPathComponent("bad-item.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, items: ["Items.Good", "NotPrefixed"])
        )) { error in
            XCTAssertTrue(String(describing: error).contains("must start with 'Items.'"))
        }
    }

    func testCreateRejectsAbsoluteAssetPath() {
        let outURL = tempDir.appendingPathComponent("bad-asset.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, assets: ["/absolute/path/asset.mesh"])
        )) { error in
            XCTAssertTrue(String(describing: error).contains("Asset path must be relative"))
        }
    }

    func testCreateRejectsAssetTraversal() {
        let outURL = tempDir.appendingPathComponent("traversal.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, assets: ["base/../../etc/passwd"])
        )) { error in
            XCTAssertTrue(String(describing: error).contains("traversal"))
        }
    }

    func testCreateRejectsEmptyItemsAndAssets() {
        let outURL = tempDir.appendingPathComponent("empty.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, items: [])
        ))
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, assets: [])
        ))
    }

    func testCreateRejectsRelativeTargetArchiveThatIsAbsolute() {
        let outURL = tempDir.appendingPathComponent("bad-target.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, targetArchive: "/abs/path.archive")
        )) { error in
            XCTAssertTrue(String(describing: error).contains("relative"))
        }
    }

    func testCreateRejectsMissingPatchedArchive() {
        let outURL = tempDir.appendingPathComponent("missing-patched.outfit.json")
        let missingPatchedURL = tempDir.appendingPathComponent("does-not-exist.archive")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, patchedURL: missingPatchedURL)
        )) { error in
            XCTAssertTrue(String(describing: error).contains("does not exist"))
        }
    }

    func testCreateRejectsEmptyBackupID() {
        let outURL = tempDir.appendingPathComponent("no-backup.outfit.json")
        XCTAssertThrowsError(try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL, backupID: "   ")
        )) { error in
            XCTAssertTrue(String(describing: error).contains("--backup-id"))
        }
    }

    func testCreateDeduplicatesAndSortsItemsAndAssets() throws {
        let outURL = tempDir.appendingPathComponent("dedup.outfit.json")
        let manager = OutfitBundleManager(home: home)
        let result = try manager.create(request: defaultCreateRequest(
            outURL: outURL,
            items: ["Items.Zeta", "Items.Alpha", "Items.Zeta", " Items.Alpha "],
            assets: ["c.mesh", "a.mesh", "c.mesh"]
        ))
        XCTAssertEqual(result.bundle.affectedItemIDs, ["Items.Alpha", "Items.Zeta"])
        XCTAssertEqual(result.bundle.affectedAssets, ["a.mesh", "c.mesh"])
    }

    // MARK: - listRegistered

    func testListRegisteredReturnsCreatedBundlesNewestFirst() throws {
        let manager = OutfitBundleManager(home: home)
        let firstURL = tempDir.appendingPathComponent("a.outfit.json")
        let secondURL = tempDir.appendingPathComponent("b.outfit.json")
        _ = try manager.create(request: defaultCreateRequest(outURL: firstURL, name: "Older Outfit"))
        Thread.sleep(forTimeInterval: 1.05)
        _ = try manager.create(request: defaultCreateRequest(outURL: secondURL, name: "Newer Outfit"))

        let bundles = try manager.listRegistered()
        XCTAssertEqual(bundles.count, 2)
        XCTAssertEqual(bundles.first?.displayName, "Newer Outfit")
        XCTAssertEqual(bundles.last?.displayName, "Older Outfit")
    }

    // MARK: - Restore + disable-grant plans

    func testRestorePlanFailsWithoutBackup() throws {
        let manager = OutfitBundleManager(home: home)
        let bundle = try manager.create(request: defaultCreateRequest(
            outURL: tempDir.appendingPathComponent("restore.outfit.json")
        )).bundle

        XCTAssertThrowsError(try manager.restorePlan(bundle: bundle, preferredGameAppPath: nil)) { error in
            let description = String(describing: error)
            XCTAssertTrue(description.contains("not found") || description.contains("Not found") || description.contains("game") || description.contains("Game"))
        }
    }

    func testDisableGrantPlanProducesExpectedCommands() throws {
        let plan = try OutfitBundleManager(home: home).disableGrantPlan(modID: "cybermacitemgrant_20260518_120000")
        XCTAssertEqual(plan.modID, "cybermacitemgrant_20260518_120000")
        XCTAssertTrue(plan.disableCommand.contains("swift run cybermac disable"))
        XCTAssertTrue(plan.disableCommand.contains("cybermacitemgrant_20260518_120000"))
        XCTAssertTrue(plan.listModsCommand.contains("list-mods"))
    }

    func testDisableGrantPlanRejectsEmptyModID() {
        XCTAssertThrowsError(try OutfitBundleManager(home: home).disableGrantPlan(modID: "   ")) { error in
            XCTAssertTrue(String(describing: error).contains("Missing <mod-id>"))
        }
    }

    // MARK: - Formatter smoke

    func testShowFormatterIncludesAllSummaryFields() throws {
        let outURL = tempDir.appendingPathComponent("show.outfit.json")
        let bundle = try OutfitBundleManager(home: home).create(
            request: defaultCreateRequest(outURL: outURL)
        ).bundle
        let text = OutfitBundleFormatter.formatShow(bundle)
        XCTAssertTrue(text.contains("Outfit bundle"))
        XCTAssertTrue(text.contains(bundle.id))
        XCTAssertTrue(text.contains(bundle.displayName))
        XCTAssertTrue(text.contains(bundle.targetArchive))
        XCTAssertTrue(text.contains(bundle.patchedArchiveSHA256))
        XCTAssertTrue(text.contains("Items.Lucy_Jacket"))
        XCTAssertTrue(text.contains("base/characters/lucy_jacket.mesh"))
    }

    func testDoesNotMutateGameOrPatchedArchive() throws {
        let outURL = tempDir.appendingPathComponent("nomutate.outfit.json")
        let before = try Data(contentsOf: patchedArchiveURL)
        _ = try OutfitBundleManager(home: home).create(request: defaultCreateRequest(outURL: outURL))
        let after = try Data(contentsOf: patchedArchiveURL)
        XCTAssertEqual(before, after, "Outfit bundle creation must not mutate the patched archive file")
    }

    // MARK: - Helpers

    private func defaultCreateRequest(
        outURL: URL,
        name: String = "Lucy Outfit",
        targetArchive: String = "Data/archive/Mac/content/basegame_4_appearance.archive",
        patchedURL: URL? = nil,
        backupID: String = "official-archive-backup-1",
        items: [String] = ["Items.Lucy_Jacket", "Items.Lucy_Clothes"],
        assets: [String] = [
            "base/characters/lucy_jacket.mesh",
            "base/characters/lucy_clothes.mesh"
        ],
        grantModID: String? = nil
    ) -> OutfitBundleCreateRequest {
        OutfitBundleCreateRequest(
            displayName: name,
            targetArchive: targetArchive,
            patchedArchiveURL: patchedURL ?? patchedArchiveURL,
            backupID: backupID,
            affectedItemIDs: items,
            affectedAssets: assets,
            optionalItemGrantModID: grantModID,
            outputBundleURL: outURL
        )
    }
}
