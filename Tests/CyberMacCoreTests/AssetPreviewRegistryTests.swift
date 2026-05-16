import Foundation
import SQLite3
import XCTest
@testable import CyberMacCore

final class AssetPreviewRegistryTests: XCTestCase {
    private var tempDir: URL!
    private var catalogDir: URL!
    private var previewsDir: URL!
    private var dbURL: URL!

    private let archivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
    private let firstAssetPath = "base\\gameplay\\gui\\widgets\\crosshair\\master_crosshair.xbm"
    private let secondAssetPath = "base\\gameplay\\vehicles\\quadra.mesh"
    private let uiAtlasAssetPath = "base\\gameplay\\gui\\main_menu.inkatlas"

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacAssetPreviewRegistryTests-\(UUID().uuidString)", isDirectory: true)
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        previewsDir = tempDir.appendingPathComponent("previews", isDirectory: true)
        dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: previewsDir, withIntermediateDirectories: true)

        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            \(firstAssetPath)
            \(secondAssetPath)
            \(uiAtlasAssetPath)
            """
        )
        try buildIndex()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFreshlyBuiltIndexCreatesPreviewTable() throws {
        // The build flow should have created asset_previews via the schema; stats() must succeed
        // and report zero rows without errors.
        let stats = try AssetPreviewRegistry().stats(databaseURL: dbURL)
        XCTAssertEqual(stats.totalPreviewRows, 0)
        XCTAssertEqual(stats.distinctAssetsWithPreviews, 0)
        XCTAssertTrue(stats.countsByKind.isEmpty)
        XCTAssertTrue(stats.countsByStatus.isEmpty)
        XCTAssertTrue(stats.topArchives.isEmpty)
    }

    func testEnsureSchemaIsIdempotentOnExistingDatabases() throws {
        let previewFile = try writePreviewFile(name: "crosshair.png")
        _ = try register(
            assetPath: firstAssetPath,
            preview: previewFile,
            kind: AssetPreviewKind.textureThumbnail
        )

        let database = try ArchiveCatalogSQLiteDatabase(url: dbURL, flags: SQLITE_OPEN_READWRITE)
        defer { database.close() }
        // Should not throw or duplicate any rows when re-applying migration.
        try AssetPreviewRegistry.ensureSchema(database: database)
        try AssetPreviewRegistry.ensureSchema(database: database)
        let count = try database.prepare("SELECT COUNT(*) FROM asset_previews;").firstInt([])
        XCTAssertEqual(count, 1)
    }

    func testRegisterPreviewForIndexedAsset() throws {
        let previewFile = try writePreviewFile(name: "crosshair.png")

        let report = try register(
            assetPath: firstAssetPath,
            preview: previewFile,
            kind: AssetPreviewKind.textureThumbnail,
            sourceTool: "wolvenkit"
        )

        XCTAssertTrue(report.inserted)
        XCTAssertFalse(report.updated)
        XCTAssertEqual(report.archivePath, archivePath)
        XCTAssertEqual(report.assetPath, firstAssetPath)
        XCTAssertEqual(report.previewKind, AssetPreviewKind.textureThumbnail)
        XCTAssertEqual(report.status, AssetPreviewStatus.available)
        XCTAssertEqual(report.previewPath, previewFile.standardizedFileURL.path)
        XCTAssertEqual(report.sourceTool, "wolvenkit")
    }

    func testRegisterUpdatesExistingRowInsteadOfInserting() throws {
        let previewFile = try writePreviewFile(name: "crosshair.png")

        let firstReport = try register(
            assetPath: firstAssetPath,
            preview: previewFile,
            kind: AssetPreviewKind.textureThumbnail,
            sourceTool: "manual"
        )
        let secondReport = try register(
            assetPath: firstAssetPath,
            preview: previewFile,
            kind: AssetPreviewKind.textureThumbnail,
            sourceTool: "wolvenkit"
        )

        XCTAssertTrue(firstReport.inserted)
        XCTAssertFalse(secondReport.inserted)
        XCTAssertTrue(secondReport.updated)
        XCTAssertEqual(secondReport.sourceTool, "wolvenkit")

        let stats = try AssetPreviewRegistry().stats(databaseURL: dbURL)
        XCTAssertEqual(stats.totalPreviewRows, 1)
    }

    func testRegisterRejectsUnknownAsset() throws {
        let previewFile = try writePreviewFile(name: "nope.png")
        XCTAssertThrowsError(try register(
            assetPath: "base\\does\\not\\exist.xbm",
            preview: previewFile,
            kind: AssetPreviewKind.textureThumbnail
        )) { error in
            guard case CyberMacError.notFound = error else {
                return XCTFail("Expected notFound, got \(error)")
            }
        }
    }

    func testRegisterRejectsMissingPreviewFile() throws {
        let bogusPreview = previewsDir.appendingPathComponent("missing.png")
        XCTAssertThrowsError(try register(
            assetPath: firstAssetPath,
            preview: bogusPreview,
            kind: AssetPreviewKind.textureThumbnail
        )) { error in
            guard case CyberMacError.notFound = error else {
                return XCTFail("Expected notFound, got \(error)")
            }
        }
    }

    func testRegisterDefaultsToExternalReferenceKind() throws {
        let previewFile = try writePreviewFile(name: "no-kind.png")
        let report = try register(
            assetPath: firstAssetPath,
            preview: previewFile,
            kind: nil
        )
        XCTAssertEqual(report.previewKind, AssetPreviewKind.externalReference)
    }

    func testImportManifestWithValidRows() throws {
        let firstPreview = try writePreviewFile(name: "first.png")
        let secondPreview = try writePreviewFile(name: "second.jpg")
        let manifestURL = try writeManifest([
            manifestEntry(archive: archivePath, assetPath: firstAssetPath, previewPath: firstPreview.path, kind: AssetPreviewKind.textureThumbnail, sourceTool: "manual"),
            manifestEntry(archive: archivePath, assetPath: secondAssetPath, previewPath: secondPreview.path, kind: AssetPreviewKind.meshRender, sourceTool: "blender")
        ])

        let report = try AssetPreviewRegistry().importManifest(manifestURL: manifestURL, databaseURL: dbURL)

        XCTAssertEqual(report.totalEntries, 2)
        XCTAssertEqual(report.importedCount, 2)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.failedCount, 0)
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testImportManifestResolvesPreviewPathsRelativeToManifest() throws {
        let manifestDir = tempDir.appendingPathComponent("manifest-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        let relativePreviewsDir = manifestDir.appendingPathComponent("img", isDirectory: true)
        try FileManager.default.createDirectory(at: relativePreviewsDir, withIntermediateDirectories: true)
        let previewName = "relative.png"
        let previewURL = relativePreviewsDir.appendingPathComponent(previewName)
        try Data([0x01, 0x02]).write(to: previewURL)

        let manifestURL = manifestDir.appendingPathComponent("previews.json")
        let entries = [manifestEntry(
            archive: archivePath,
            assetPath: firstAssetPath,
            previewPath: "img/\(previewName)",
            kind: AssetPreviewKind.textureThumbnail,
            sourceTool: nil
        )]
        let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted])
        try data.write(to: manifestURL)

        let report = try AssetPreviewRegistry().importManifest(manifestURL: manifestURL, databaseURL: dbURL)
        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.failedCount, 0)

        let searchReport = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "master_crosshair",
            databaseURL: dbURL
        ))
        XCTAssertEqual(searchReport.matches.first?.firstPreviewPath, previewURL.standardizedFileURL.path)
    }

    func testImportManifestWithMixedValidAndInvalidRows() throws {
        let realPreview = try writePreviewFile(name: "real.png")
        let manifestURL = try writeManifest([
            manifestEntry(archive: archivePath, assetPath: firstAssetPath, previewPath: realPreview.path, kind: AssetPreviewKind.textureThumbnail, sourceTool: nil),
            manifestEntry(archive: archivePath, assetPath: "base\\does\\not\\exist.xbm", previewPath: realPreview.path, kind: AssetPreviewKind.textureThumbnail, sourceTool: nil),
            manifestEntry(archive: archivePath, assetPath: secondAssetPath, previewPath: previewsDir.appendingPathComponent("missing.png").path, kind: AssetPreviewKind.meshRender, sourceTool: nil),
            ["archive": archivePath, "assetPath": "", "previewPath": realPreview.path]
        ])

        let report = try AssetPreviewRegistry().importManifest(manifestURL: manifestURL, databaseURL: dbURL)
        XCTAssertEqual(report.totalEntries, 4)
        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(report.failedCount, 3)
        XCTAssertEqual(report.failures.count, 3)
        let failedIndices = report.failures.map(\.index).sorted()
        XCTAssertEqual(failedIndices, [1, 2, 3])
    }

    func testSearchReturnsPreviewCountAndFirstPreviewPath() throws {
        let firstPreview = try writePreviewFile(name: "primary.png")
        let secondPreview = try writePreviewFile(name: "secondary.png")
        _ = try register(assetPath: firstAssetPath, preview: firstPreview, kind: AssetPreviewKind.textureThumbnail)
        _ = try register(assetPath: firstAssetPath, preview: secondPreview, kind: AssetPreviewKind.atlasSheet)

        let report = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "master_crosshair",
            databaseURL: dbURL,
            limit: 10
        ))

        let match = try XCTUnwrap(report.matches.first)
        XCTAssertEqual(match.previewCount, 2)
        XCTAssertNotNil(match.firstPreviewPath)
        XCTAssertTrue(
            match.firstPreviewPath == firstPreview.standardizedFileURL.path
                || match.firstPreviewPath == secondPreview.standardizedFileURL.path
        )
    }

    func testSearchHasPreviewFilter() throws {
        let preview = try writePreviewFile(name: "for-mesh.png")
        _ = try register(assetPath: secondAssetPath, preview: preview, kind: AssetPreviewKind.meshRender)

        let withPreview = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "base",
            databaseURL: dbURL,
            onlyWithPreview: true,
            limit: 20
        ))
        XCTAssertEqual(withPreview.matches.map(\.assetPath), [secondAssetPath])

        let unfiltered = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "base",
            databaseURL: dbURL,
            onlyWithPreview: false,
            limit: 20
        ))
        XCTAssertEqual(unfiltered.matches.count, 3)
    }

    func testSearchOrderingIsDeterministic() throws {
        let firstPreview = try writePreviewFile(name: "first.png")
        let secondPreview = try writePreviewFile(name: "second.png")
        _ = try register(assetPath: firstAssetPath, preview: firstPreview, kind: AssetPreviewKind.textureThumbnail)
        _ = try register(assetPath: secondAssetPath, preview: secondPreview, kind: AssetPreviewKind.meshRender)

        let runOne = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "base",
            databaseURL: dbURL,
            limit: 50
        ))
        let runTwo = try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: "base",
            databaseURL: dbURL,
            limit: 50
        ))
        XCTAssertEqual(runOne.matches, runTwo.matches)
        XCTAssertEqual(runOne.matches.map(\.assetPath), runOne.matches.map(\.assetPath).sorted())
    }

    func testStatsReturnsCorrectCounts() throws {
        let textureA = try writePreviewFile(name: "textureA.png")
        let textureB = try writePreviewFile(name: "textureB.png")
        let mesh = try writePreviewFile(name: "mesh.png")
        _ = try register(assetPath: firstAssetPath, preview: textureA, kind: AssetPreviewKind.textureThumbnail)
        _ = try register(assetPath: firstAssetPath, preview: textureB, kind: AssetPreviewKind.atlasSheet)
        _ = try register(assetPath: secondAssetPath, preview: mesh, kind: AssetPreviewKind.meshRender)

        let stats = try AssetPreviewRegistry().stats(databaseURL: dbURL)
        XCTAssertEqual(stats.totalPreviewRows, 3)
        XCTAssertEqual(stats.distinctAssetsWithPreviews, 2)
        let kindCounts = Dictionary(uniqueKeysWithValues: stats.countsByKind.map { ($0.value, $0.count) })
        XCTAssertEqual(kindCounts[AssetPreviewKind.textureThumbnail], 1)
        XCTAssertEqual(kindCounts[AssetPreviewKind.atlasSheet], 1)
        XCTAssertEqual(kindCounts[AssetPreviewKind.meshRender], 1)
        let statusCounts = Dictionary(uniqueKeysWithValues: stats.countsByStatus.map { ($0.value, $0.count) })
        XCTAssertEqual(statusCounts[AssetPreviewStatus.available], 3)
        XCTAssertEqual(stats.topArchives.first?.value, archivePath)
        XCTAssertEqual(stats.topArchives.first?.count, 3)
    }

    func testFixtureManifestImports() throws {
        let fixtureURL = try fixtureURL(named: "sample-asset-previews-manifest.json")
        let report = try AssetPreviewRegistry().importManifest(manifestURL: fixtureURL, databaseURL: dbURL)
        XCTAssertGreaterThan(report.totalEntries, 0)
        // Fixture references previews that don't exist on disk; rows should all fail
        // with notFound rather than crash. This confirms graceful per-row handling.
        XCTAssertEqual(report.importedCount, 0)
        XCTAssertEqual(report.failedCount, report.totalEntries)
    }

    // MARK: - Helpers

    private func writePreviewFile(name: String) throws -> URL {
        let url = previewsDir.appendingPathComponent(name)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        return url
    }

    @discardableResult
    private func register(
        assetPath: String,
        preview: URL,
        kind: String?,
        sourceTool: String? = nil
    ) throws -> AssetPreviewRegisterReport {
        try AssetPreviewRegistry().register(options: AssetPreviewRegisterOptions(
            databaseURL: dbURL,
            archivePath: archivePath,
            assetPath: assetPath,
            previewURL: preview,
            kind: kind,
            sourceTool: sourceTool
        ))
    }

    private func manifestEntry(
        archive: String,
        assetPath: String,
        previewPath: String,
        kind: String?,
        sourceTool: String?
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "archive": archive,
            "assetPath": assetPath,
            "previewPath": previewPath
        ]
        if let kind { entry["kind"] = kind }
        if let sourceTool { entry["sourceTool"] = sourceTool }
        return entry
    }

    private func writeManifest(_ entries: [[String: Any]]) throws -> URL {
        let url = tempDir.appendingPathComponent("manifest-\(UUID().uuidString).json")
        let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted])
        try data.write(to: url)
        return url
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

    private func fixtureURL(named name: String) throws -> URL {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(name),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Tests/Fixtures")
                .appendingPathComponent(name)
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        throw CyberMacError.notFound("Test fixture missing: \(name)")
    }
}
