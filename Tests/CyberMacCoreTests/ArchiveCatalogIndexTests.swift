import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveCatalogIndexTests: XCTestCase {
    private var tempDir: URL!
    private var catalogDir: URL!
    private var dbURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveCatalogIndexTests-\(UUID().uuidString)", isDirectory: true)
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBuildCreatesReadableSQLiteIndex() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\gameplay\\gui\\main_menu.inkatlas
            base\\gameplay\\vehicles\\quadra.mesh
            """
        )

        let report = try buildIndex()
        let stats = try ArchiveCatalogIndexStore().stats(databaseURL: dbURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
        XCTAssertEqual(report.archiveCount, 1)
        XCTAssertEqual(report.assetRowCount, 2)
        XCTAssertEqual(stats.archiveCount, 1)
        XCTAssertEqual(stats.assetRowCount, 2)
    }

    func testSearchByQuery() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\gameplay\\gui\\main_menu.inkatlas
            base\\gameplay\\vehicles\\quadra.mesh
            """
        )
        try buildIndex()

        let report = try search(query: "quadra")

        XCTAssertEqual(report.matches.map(\.assetPath), ["base\\gameplay\\vehicles\\quadra.mesh"])
        XCTAssertEqual(report.matches.first?.archivePath, "Data/archive/Mac/content/basegame_1_engine.archive")
    }

    func testSearchIsCaseInsensitive() throws {
        try writeCatalog(
            "basegame_2_mainmenu.archive.txt",
            contents: "base\\ui\\Main_Menu_Background.XBM\n"
        )
        try buildIndex()

        let report = try search(query: "main_menu_background")

        XCTAssertEqual(report.matches.count, 1)
        XCTAssertEqual(report.matches.first?.assetPath, "base\\ui\\Main_Menu_Background.XBM")
        XCTAssertEqual(report.matches.first?.assetExtension, "xbm")
    }

    func testSearchFiltersByExtension() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\menu_background.xbm
            base\\ui\\menu_layout.inkatlas
            """
        )
        try buildIndex()

        let report = try search(query: "menu", extensionFilter: ".xbm")

        XCTAssertEqual(report.matches.map(\.assetPath), ["base\\ui\\menu_background.xbm"])
        XCTAssertEqual(report.extensionFilter, "xbm")
    }

    func testSearchFiltersByArchive() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\shared_menu_asset.xbm\n"
        )
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: "ep1\\ui\\shared_menu_asset.xbm\n"
        )
        try buildIndex()

        let report = try search(
            query: "shared_menu_asset",
            archiveFilter: "Data/archive/Mac/ep1/ep1_main.archive"
        )

        XCTAssertEqual(report.matches.map(\.archivePath), ["Data/archive/Mac/ep1/ep1_main.archive"])
        XCTAssertEqual(report.matches.map(\.assetPath), ["ep1\\ui\\shared_menu_asset.xbm"])
    }

    func testSearchFiltersByCategory() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\gameplay\\gui\\main_menu.inkatlas
            base\\gameplay\\vehicles\\quadra.mesh
            base\\sound\\menu_click.wem
            """
        )
        try buildIndex()

        let uiReport = try search(query: "base", categoryFilter: "ui")
        let audioReport = try search(query: "base", categoryFilter: "audio")

        XCTAssertEqual(uiReport.matches.map(\.assetPath), ["base\\gameplay\\gui\\main_menu.inkatlas"])
        XCTAssertEqual(uiReport.matches.first?.category, "ui")
        XCTAssertEqual(audioReport.matches.map(\.assetPath), ["base\\sound\\menu_click.wem"])
        XCTAssertEqual(audioReport.matches.first?.category, "audio")
    }

    func testTattooCategoryRecognizesBothSingularAndPluralPaths() throws {
        // The category guess used to match only "/tattoo/"; real CDPR paths
        // also use "/tattoos/" (plural). Both should classify as tattoo.
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\characters\\common\\character_customisation_items\\tattoos\\body\\textures\\tattoo_body__customisation_01_d01.xbm
            base\\characters\\common\\tattoo\\arm\\arm_tattoo.xbm
            """
        )
        try buildIndex()

        let tattooReport = try search(query: "tattoo", categoryFilter: "tattoo")
        XCTAssertEqual(tattooReport.matches.count, 2)
        for match in tattooReport.matches {
            XCTAssertEqual(match.category, "tattoo")
        }
    }

    func testStatsReturnsExpectedCounts() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\gameplay\\gui\\main_menu.inkatlas
            base\\gameplay\\vehicles\\quadra.mesh
            """
        )
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: """
            ep1\\sound\\menu_click.wem
            ep1\\worlds\\city\\block.mesh
            """
        )
        try buildIndex()

        let stats = try ArchiveCatalogIndexStore().stats(databaseURL: dbURL)

        XCTAssertEqual(stats.archiveCount, 2)
        XCTAssertEqual(stats.assetRowCount, 4)
        XCTAssertEqual(stats.countsByExtension, [
            ArchiveCatalogIndexCount(value: "mesh", count: 2),
            ArchiveCatalogIndexCount(value: "inkatlas", count: 1),
            ArchiveCatalogIndexCount(value: "wem", count: 1)
        ])
        XCTAssertEqual(stats.countsByArchive, [
            ArchiveCatalogIndexCount(value: "Data/archive/Mac/content/basegame_1_engine.archive", count: 2),
            ArchiveCatalogIndexCount(value: "Data/archive/Mac/ep1/ep1_main.archive", count: 2)
        ])
        XCTAssertEqual(stats.countsByCategory, [
            ArchiveCatalogIndexCount(value: "audio", count: 1),
            ArchiveCatalogIndexCount(value: "ui", count: 1),
            ArchiveCatalogIndexCount(value: "vehicle", count: 1),
            ArchiveCatalogIndexCount(value: "world", count: 1)
        ])
    }

    func testRebuildReplacesStaleDatabaseContent() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\old_asset.xbm\n"
        )
        try buildIndex()

        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\new_asset.xbm\n"
        )
        let rebuildReport = try buildIndex()

        XCTAssertEqual(rebuildReport.assetRowCount, 1)
        XCTAssertTrue(try search(query: "old_asset").matches.isEmpty)
        XCTAssertEqual(try search(query: "new_asset").matches.map(\.assetPath), ["base\\ui\\new_asset.xbm"])
    }

    func testDuplicateAssetRowsAreIgnoredCleanly() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\duplicate_asset.xbm
            base\\ui\\duplicate_asset.xbm
            """
        )

        let report = try buildIndex()
        let searchReport = try search(query: "duplicate_asset")

        XCTAssertEqual(report.assetRowCount, 1)
        XCTAssertEqual(report.duplicateAssetRowCount, 1)
        XCTAssertEqual(searchReport.totalMatchCount, 1)
        XCTAssertEqual(searchReport.matches.map(\.assetPath), ["base\\ui\\duplicate_asset.xbm"])
    }

    func testUnknownArchivePathsAreRetained() throws {
        try writeCatalog(
            "loose-list.txt",
            contents: "base\\worlds\\city\\unknown_source.mesh\n"
        )
        try buildIndex()

        let report = try search(query: "unknown_source")
        let stats = try ArchiveCatalogIndexStore().stats(databaseURL: dbURL)

        XCTAssertEqual(report.matches.map(\.archivePath), ["unknown:loose-list.txt"])
        XCTAssertEqual(stats.countsByArchive, [
            ArchiveCatalogIndexCount(value: "unknown:loose-list.txt", count: 1)
        ])
    }

    @discardableResult
    private func buildIndex() throws -> ArchiveCatalogIndexBuildReport {
        try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))
    }

    private func search(
        query: String,
        extensionFilter: String? = nil,
        archiveFilter: String? = nil,
        categoryFilter: String? = nil,
        limit: Int = 50
    ) throws -> ArchiveCatalogIndexSearchReport {
        try ArchiveCatalogIndexStore().search(options: ArchiveCatalogIndexSearchOptions(
            query: query,
            databaseURL: dbURL,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            categoryFilter: categoryFilter,
            limit: limit
        ))
    }

    private func writeCatalog(_ relativePath: String, contents: String) throws {
        let url = catalogDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
