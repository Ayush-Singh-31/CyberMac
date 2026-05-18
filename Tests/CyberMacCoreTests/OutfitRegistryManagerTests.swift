import Foundation
import XCTest
@testable import CyberMacCore

final class OutfitRegistryManagerTests: XCTestCase {
    private let relativeArchivePath = "Data/archive/Mac/content/basegame_4_appearance.archive"
    private let otherRelativeArchivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
    private let fixedDate = Date(timeIntervalSince1970: 0)

    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var catalogDir: URL!
    private var dbURL: URL!
    private var cp77toolsURL: URL!
    private var game: GameInstall!
    private var backupManager: OfficialArchiveBackupManager!
    private var backup: OfficialArchiveBackupMetadata!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacOutfitRegistryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
        try "#!/bin/sh\nexit 0\n".write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)

        game = try makeGameInstall()
        backupManager = OfficialArchiveBackupManager(home: home)
        backup = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCreateProfileWritesDeterministicJSONAndRegistry() throws {
        let manager = makeManager()
        let profile = try manager.createProfile(request: createRequest())

        let profileJSON = try String(contentsOf: home.outfitProfilesURL.appendingPathComponent("appearance-main.json"), encoding: .utf8)
        XCTAssertTrue(profileJSON.contains(#""createdAt" : "1970-01-01T00:00:00Z""#))
        XCTAssertTrue(profileJSON.contains(#""disabledPieceIds" : ["#))
        XCTAssertTrue(profileJSON.contains(#""enabledPieceIds" : ["#))
        XCTAssertTrue(profileJSON.contains(#""pieces" : ["#))
        XCTAssertTrue(profileJSON.contains(#""pristineBackupId" : "\#(backup.backupID)""#))
        let decoded = try JSONDecoder.cybermac.decode(
            OutfitProfile.self,
            from: Data(contentsOf: home.outfitProfilesURL.appendingPathComponent("appearance-main.json"))
        )
        XCTAssertEqual(decoded.pristineArchivePath, profile.pristineArchivePath)
        XCTAssertEqual(decoded.targetArchiveRelativePath, relativeArchivePath)

        let registry = try JSONDecoder.cybermac.decode(OutfitRegistry.self, from: Data(contentsOf: home.outfitRegistryURL))
        XCTAssertEqual(registry.profiles.map(\.id), ["appearance-main"])
        XCTAssertEqual(registry.profiles.first?.profilePath, home.outfitProfilesURL.appendingPathComponent("appearance-main.json").path)
    }

    func testCreateProfileRejectsMissingBackupAndTargetMismatchAndUnsafeTarget() throws {
        let manager = makeManager()

        XCTAssertThrowsError(try manager.createProfile(request: OutfitProfileCreateRequest(
            id: "missing",
            displayName: "Missing",
            targetArchiveRelativePath: relativeArchivePath,
            backupID: "official-archive-missing"
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("not found") || String(describing: error).contains("Not found"))
        }

        let otherBackup = try backupManager.backup(relativeArchivePath: otherRelativeArchivePath, gameInstall: game)
        XCTAssertThrowsError(try manager.createProfile(request: OutfitProfileCreateRequest(
            id: "mismatch",
            displayName: "Mismatch",
            targetArchiveRelativePath: relativeArchivePath,
            backupID: otherBackup.backupID
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("belongs to"))
        }

        XCTAssertThrowsError(try manager.createProfile(request: OutfitProfileCreateRequest(
            id: "unsafe",
            displayName: "Unsafe",
            targetArchiveRelativePath: "Data/archive/Mac/content/../bad.archive",
            backupID: backup.backupID
        )))
    }

    func testCreateProfileRejectsDuplicateProfileID() throws {
        let manager = makeManager()
        _ = try manager.createProfile(request: createRequest())

        XCTAssertThrowsError(try manager.createProfile(request: createRequest())) { error in
            XCTAssertTrue(String(describing: error).contains("already exists"))
        }
    }

    func testAddPieceRecordsReplacedAndAddedAssetsForPartialMatch() throws {
        try writeCatalog("Data_archive_Mac_content_basegame_4_appearance.archive.txt", contents: "base/garment/replaced.mesh\n")
        try buildIndex()
        let sourceArchive = try makeSourceArchive(name: "lucy.archive")
        let tooling = FakeOutfitTooling(filesByArchivePath: [
            sourceArchive.path: [
                "base/garment/replaced.mesh": "lucy replacement",
                "base/garment/custom.mesh": "lucy custom"
            ]
        ])
        let manager = makeManager(tooling: tooling)
        _ = try manager.createProfile(request: createRequest())

        let piece = try manager.addPiece(request: pieceAddRequest(
            pieceID: "lucy-jacket",
            name: "Lucy Jacket",
            sourceArchives: [sourceArchive],
            items: ["Items.Lucy_Jacket"],
            tags: ["lucy", "jacket"]
        ))

        XCTAssertEqual(piece.affectedAssets.replacedAssets, ["base/garment/replaced.mesh"])
        XCTAssertEqual(piece.affectedAssets.addedAssets, ["base/garment/custom.mesh"])
        XCTAssertEqual(piece.itemIds, ["Items.Lucy_Jacket"])
        XCTAssertEqual(piece.tags, ["jacket", "lucy"])
        XCTAssertEqual(tooling.extractRequests.map(\.sourceArchiveURL.path), [sourceArchive.path])
    }

    func testAddPieceRejectsZeroMatchSourceArchive() throws {
        try writeCatalog("Data_archive_Mac_content_basegame_4_appearance.archive.txt", contents: "base/garment/replaced.mesh\n")
        try buildIndex()
        let sourceArchive = try makeSourceArchive(name: "custom-only.archive")
        let tooling = FakeOutfitTooling(filesByArchivePath: [
            sourceArchive.path: [
                "base/garment/custom.mesh": "custom"
            ]
        ])
        let manager = makeManager(tooling: tooling)
        _ = try manager.createProfile(request: createRequest())

        XCTAssertThrowsError(try manager.addPiece(request: pieceAddRequest(
            pieceID: "custom-only",
            name: "Custom Only",
            sourceArchives: [sourceArchive]
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("At least one replacement is required"))
        }
    }

    func testAddPieceRejectsMissingSourceArchive() throws {
        try writeCatalog("Data_archive_Mac_content_basegame_4_appearance.archive.txt", contents: "base/garment/replaced.mesh\n")
        try buildIndex()
        let manager = makeManager()
        _ = try manager.createProfile(request: createRequest())
        let missing = tempDir.appendingPathComponent("missing.archive")

        XCTAssertThrowsError(try manager.addPiece(request: pieceAddRequest(
            pieceID: "missing-source",
            name: "Missing Source",
            sourceArchives: [missing]
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("Source archive does not exist"))
        }
    }

    func testEnableDisableOnlyChangesDesiredState() throws {
        let (manager, _) = try managerWithTwoPieces()

        let disabled = try manager.disablePiece(profileID: "appearance-main", pieceID: "lucy-jacket")
        XCTAssertEqual(disabled.enabledPieceIds, ["lucy-pants"])
        XCTAssertEqual(disabled.disabledPieceIds, ["lucy-jacket"])
        XCTAssertNil(disabled.lastBuiltArchivePath)

        let enabled = try manager.enablePiece(profileID: "appearance-main", pieceID: "lucy-jacket")
        XCTAssertEqual(enabled.enabledPieceIds, ["lucy-jacket", "lucy-pants"])
        XCTAssertTrue(enabled.disabledPieceIds.isEmpty)
        XCTAssertNil(enabled.lastBuiltArchiveSHA256)
    }

    func testBuildExtractsPristineBackupAndMergesEnabledPiecesOnly() throws {
        let (manager, tooling) = try managerWithTwoPieces()
        _ = try manager.disablePiece(profileID: "appearance-main", pieceID: "lucy-pants")
        tooling.filesByArchivePath[backup.backupFilePath] = [
            "base/garment/replaced.mesh": "pristine",
            "base/garment/pants.mesh": "pristine pants",
            "base/garment/vanilla-only.mesh": "vanilla"
        ]
        tooling.filesByArchivePath[archiveURL(relativePath: relativeArchivePath).path] = [
            "base/garment/replaced.mesh": "currently modified"
        ]

        let outputURL = tempDir.appendingPathComponent("out/patched.archive")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let result = try manager.buildProfile(request: OutfitProfileBuildRequest(
            profileID: "appearance-main",
            outputArchiveURL: outputURL,
            workDirectoryURL: tempDir.appendingPathComponent("work", isDirectory: true),
            cp77toolsURL: cp77toolsURL
        ))

        let buildStartIndex = try XCTUnwrap(tooling.extractRequests.firstIndex {
            $0.sourceArchiveURL.path == backup.backupFilePath
        })
        XCTAssertEqual(tooling.extractRequests[buildStartIndex].sourceArchiveURL.path, backup.backupFilePath)
        XCTAssertEqual(tooling.packedFiles["base/garment/replaced.mesh"], "lucy jacket")
        XCTAssertEqual(tooling.packedFiles["base/garment/pants.mesh"], "pristine pants")
        XCTAssertEqual(tooling.packedFiles["base/garment/vanilla-only.mesh"], "vanilla")
        XCTAssertNil(tooling.packedFiles["base/garment/pants-custom.mesh"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(result.enabledPieceIds, ["lucy-jacket"])
        XCTAssertEqual(result.outputArchiveSHA256, try PathSafety.sha256(url: outputURL))
        let profile = try manager.loadProfile(id: "appearance-main")
        XCTAssertEqual(profile.lastBuiltArchivePath, outputURL.path)
        XCTAssertEqual(profile.lastBuiltArchiveSHA256, result.outputArchiveSHA256)
        XCTAssertNil(profile.lastInstalledSHA256)
    }

    func testBuildWarnsOnConflictAndLastInstallOrderWins() throws {
        let (manager, tooling) = try managerWithTwoPieces(sameReplacementPath: true)
        tooling.filesByArchivePath[backup.backupFilePath] = [
            "base/garment/replaced.mesh": "pristine"
        ]
        let outputURL = tempDir.appendingPathComponent("out/conflict.archive")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let result = try manager.buildProfile(request: OutfitProfileBuildRequest(
            profileID: "appearance-main",
            outputArchiveURL: outputURL,
            workDirectoryURL: tempDir.appendingPathComponent("work-conflict", isDirectory: true),
            cp77toolsURL: cp77toolsURL
        ))

        XCTAssertEqual(result.conflictWarnings, [
            OutfitBuildConflict(
                assetPath: "base/garment/replaced.mesh",
                previousPieceId: "lucy-jacket",
                winningPieceId: "lucy-pants"
            )
        ])
        XCTAssertEqual(tooling.packedFiles["base/garment/replaced.mesh"], "lucy pants")
    }

    func testBuildFailsClearlyOnZeroOrMultiplePackedArchives() throws {
        let (manager, tooling) = try managerWithTwoPieces()
        tooling.filesByArchivePath[backup.backupFilePath] = [
            "base/garment/replaced.mesh": "pristine",
            "base/garment/pants.mesh": "pristine pants"
        ]
        let outDir = tempDir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        tooling.packMode = .zero
        XCTAssertThrowsError(try manager.buildProfile(request: OutfitProfileBuildRequest(
            profileID: "appearance-main",
            outputArchiveURL: outDir.appendingPathComponent("zero.archive"),
            workDirectoryURL: tempDir.appendingPathComponent("work-zero", isDirectory: true),
            cp77toolsURL: cp77toolsURL
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("No generated .archive"))
        }

        tooling.packMode = .multiple
        XCTAssertThrowsError(try manager.buildProfile(request: OutfitProfileBuildRequest(
            profileID: "appearance-main",
            outputArchiveURL: outDir.appendingPathComponent("multiple.archive"),
            workDirectoryURL: tempDir.appendingPathComponent("work-multiple", isDirectory: true),
            cp77toolsURL: cp77toolsURL
        ))) { error in
            XCTAssertTrue(String(describing: error).contains("more than one .archive"))
        }
    }

    func testGrantItemsCollectsOnlyEnabledPieceItemsAndDoesNotMutateGameArchive() throws {
        let (manager, _) = try managerWithTwoPieces()
        _ = try manager.disablePiece(profileID: "appearance-main", pieceID: "lucy-pants")
        let before = try Data(contentsOf: archiveURL(relativePath: relativeArchivePath))
        let outputZip = tempDir.appendingPathComponent("grant.zip")

        let result = try manager.grantItems(request: OutfitGrantItemsRequest(
            profileID: "appearance-main",
            outputZipURL: outputZip,
            modName: "LucyGrant"
        ))

        XCTAssertEqual(result.enabledItemIds, ["Items.Lucy_Jacket"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path))
        XCTAssertEqual(try Data(contentsOf: archiveURL(relativePath: relativeArchivePath)), before)
    }

    func testInstallPlanPrintsOnlyManualCommandsAndDoesNotMutateGameArchive() throws {
        let (manager, tooling) = try managerWithTwoPieces()
        tooling.filesByArchivePath[backup.backupFilePath] = [
            "base/garment/replaced.mesh": "pristine",
            "base/garment/pants.mesh": "pristine pants"
        ]
        let outputURL = tempDir.appendingPathComponent("out/install.archive")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try manager.buildProfile(request: OutfitProfileBuildRequest(
            profileID: "appearance-main",
            outputArchiveURL: outputURL,
            workDirectoryURL: tempDir.appendingPathComponent("work-install", isDirectory: true),
            cp77toolsURL: cp77toolsURL
        ))
        let before = try Data(contentsOf: archiveURL(relativePath: relativeArchivePath))

        let plan = try manager.installPlan(profileID: "appearance-main")

        XCTAssertTrue(plan.manualInstallCommand.hasPrefix("sudo cp "))
        XCTAssertTrue(plan.statusCommand.contains("archive-patch status"))
        XCTAssertTrue(plan.preflightCommand.contains("archive-patch preflight"))
        XCTAssertEqual(try Data(contentsOf: archiveURL(relativePath: relativeArchivePath)), before)
    }

    private func managerWithTwoPieces(sameReplacementPath: Bool = false) throws -> (OutfitRegistryManager, FakeOutfitTooling) {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_4_appearance.archive.txt",
            contents: """
            base/garment/replaced.mesh
            base/garment/pants.mesh
            """
        )
        try buildIndex()
        let jacketArchive = try makeSourceArchive(name: "jacket.archive")
        let pantsArchive = try makeSourceArchive(name: "pants.archive")
        let pantsPath = sameReplacementPath ? "base/garment/replaced.mesh" : "base/garment/pants.mesh"
        let tooling = FakeOutfitTooling(filesByArchivePath: [
            jacketArchive.path: [
                "base/garment/replaced.mesh": "lucy jacket"
            ],
            pantsArchive.path: [
                pantsPath: "lucy pants",
                "base/garment/pants-custom.mesh": "pants custom"
            ],
            backup.backupFilePath: [
                "base/garment/replaced.mesh": "pristine",
                "base/garment/pants.mesh": "pristine pants"
            ]
        ])
        let manager = makeManager(tooling: tooling)
        _ = try manager.createProfile(request: createRequest())
        _ = try manager.addPiece(request: pieceAddRequest(
            pieceID: "lucy-jacket",
            name: "Lucy Jacket",
            sourceArchives: [jacketArchive],
            items: ["Items.Lucy_Jacket"]
        ))
        _ = try manager.addPiece(request: pieceAddRequest(
            pieceID: "lucy-pants",
            name: "Lucy Pants",
            sourceArchives: [pantsArchive],
            items: ["Items.Lucy_Pants"]
        ))
        return (manager, tooling)
    }

    private func makeManager(tooling: FakeOutfitTooling = FakeOutfitTooling()) -> OutfitRegistryManager {
        let date = fixedDate
        return OutfitRegistryManager(
            home: home,
            tooling: tooling,
            dateProvider: { date },
            idProvider: { "stageid" }
        )
    }

    private func createRequest(
        id: String = "appearance-main",
        name: String = "Appearance Main",
        targetArchive: String? = nil,
        backupID: String? = nil
    ) -> OutfitProfileCreateRequest {
        OutfitProfileCreateRequest(
            id: id,
            displayName: name,
            targetArchiveRelativePath: targetArchive ?? relativeArchivePath,
            backupID: backupID ?? backup.backupID
        )
    }

    private func pieceAddRequest(
        pieceID: String,
        name: String,
        sourceArchives: [URL],
        items: [String] = [],
        tags: [String] = []
    ) -> OutfitPieceAddRequest {
        OutfitPieceAddRequest(
            profileID: "appearance-main",
            pieceID: pieceID,
            displayName: name,
            sourceArchiveURLs: sourceArchives,
            itemIDs: items,
            tags: tags,
            cp77toolsURL: cp77toolsURL,
            workDirectoryURL: tempDir.appendingPathComponent("piece-work-\(pieceID)", isDirectory: true),
            databaseURL: dbURL
        )
    }

    @discardableResult
    private func buildIndex() throws -> ArchiveCatalogIndexBuildReport {
        try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))
    }

    private func writeCatalog(_ relativePath: String, contents: String) throws {
        let url = catalogDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeSourceArchive(name: String) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try "source \(name)".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077 Test.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        for path in [relativeArchivePath, otherRelativeArchivePath] {
            let url = archiveURL(relativePath: path, contentsURL: contentsURL)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "official \(path)".write(to: url, atomically: true, encoding: .utf8)
        }
        try writeCodeResources(contentsURL: contentsURL)

        return GameInstall(
            appURL: appURL,
            executableURL: executableURL,
            dataURL: dataURL,
            archiveMacURL: dataURL.appendingPathComponent("archive/Mac", isDirectory: true),
            r6URL: nil,
            storefront: .macAppStore,
            displayName: "Cyberpunk 2077"
        )
    }

    private func writeCodeResources(contentsURL: URL) throws {
        let codeSignatureURL = contentsURL.appendingPathComponent("_CodeSignature", isDirectory: true)
        try FileManager.default.createDirectory(at: codeSignatureURL, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "files2": [
                relativeArchivePath: ["hash": "fixture"],
                otherRelativeArchivePath: ["hash": "fixture"]
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: codeSignatureURL.appendingPathComponent("CodeResources"), options: [.atomic])
    }

    private func archiveURL(relativePath: String) -> URL {
        archiveURL(relativePath: relativePath, contentsURL: game.appURL.appendingPathComponent("Contents", isDirectory: true))
    }

    private func archiveURL(relativePath: String, contentsURL: URL) -> URL {
        relativePath.split(separator: "/").reduce(contentsURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}

private final class FakeOutfitTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    enum PackMode {
        case single
        case zero
        case multiple
    }

    struct ExtractRequest {
        let sourceArchiveURL: URL
        let outputDirectoryURL: URL
    }

    var filesByArchivePath: [String: [String: String]]
    var packMode: PackMode = .single
    private(set) var extractRequests: [ExtractRequest] = []
    private(set) var packedFiles: [String: String] = [:]

    init(filesByArchivePath: [String: [String: String]] = [:]) {
        self.filesByArchivePath = filesByArchivePath
    }

    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {
        extractRequests.append(ExtractRequest(
            sourceArchiveURL: sourceArchiveURL.standardizedFileURL,
            outputDirectoryURL: outputDirectoryURL.standardizedFileURL
        ))
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        for (assetPath, contents) in filesByArchivePath[sourceArchiveURL.path, default: [:]] {
            let url = assetPath
                .split(separator: "/")
                .reduce(outputDirectoryURL) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        packedFiles = try files(under: extractedDirectoryURL)
        try FileManager.default.createDirectory(at: outputArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        switch packMode {
        case .single:
            try packedSummary().write(to: outputArchiveURL, atomically: true, encoding: .utf8)
        case .zero:
            break
        case .multiple:
            try "a".write(to: outputArchiveURL.deletingLastPathComponent().appendingPathComponent("a.archive"), atomically: true, encoding: .utf8)
            try "b".write(to: outputArchiveURL.deletingLastPathComponent().appendingPathComponent("b.archive"), atomically: true, encoding: .utf8)
        }
    }

    private func packedSummary() -> String {
        packedFiles
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    private func files(under rootURL: URL) throws -> [String: String] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return [:]
        }
        var result: [String: String] = [:]
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            result[relativePath] = try String(contentsOf: url, encoding: .utf8)
        }
        return result
    }
}
