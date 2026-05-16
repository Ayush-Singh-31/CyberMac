import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveCatalogSearcherTests: XCTestCase {
    private var tempDir: URL!
    private var catalogDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveCatalogTests-\(UUID().uuidString)", isDirectory: true)
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBasicQueryMatch() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\gameplay\\gui\\main_menu.inkatlas
            base\\gameplay\\vehicles\\quadra.mesh
            """
        )

        let report = try search(query: "main_menu")

        XCTAssertEqual(report.matches, [
            ArchiveCatalogSearchMatch(
                archivePath: "Data/archive/Mac/content/basegame_1_engine.archive",
                assetPath: "base\\gameplay\\gui\\main_menu.inkatlas",
                assetExtension: "inkatlas",
                sourceCatalogFile: "Data_archive_Mac_content_basegame_1_engine.archive.txt"
            )
        ])
    }

    func testCaseInsensitiveMatch() throws {
        try writeCatalog(
            "basegame_2_mainmenu.archive.txt",
            contents: "base\\ui\\Main_Menu_Background.XBM\n"
        )

        let report = try search(query: "main_menu_background")

        XCTAssertEqual(report.matches.count, 1)
        XCTAssertEqual(report.matches.first?.assetPath, "base\\ui\\Main_Menu_Background.XBM")
        XCTAssertEqual(report.matches.first?.assetExtension, "xbm")
    }

    func testExtensionFilter() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\menu_background.xbm
            base\\ui\\menu_layout.inkatlas
            """
        )

        let report = try search(query: "menu", extensionFilter: "xbm")

        XCTAssertEqual(report.matches.map(\.assetPath), ["base\\ui\\menu_background.xbm"])
    }

    func testArchiveFilterWhereInferable() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\shared_menu_asset.xbm\n"
        )
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: "ep1\\ui\\shared_menu_asset.xbm\n"
        )

        let report = try search(
            query: "shared_menu_asset",
            archiveFilter: "Data/archive/Mac/ep1/ep1_main.archive"
        )

        XCTAssertEqual(report.matches.map(\.archivePath), ["Data/archive/Mac/ep1/ep1_main.archive"])
        XCTAssertEqual(report.matches.map(\.assetPath), ["ep1\\ui\\shared_menu_asset.xbm"])
    }

    func testLimitBehavior() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\menu_c.xbm
            base\\ui\\menu_a.xbm
            base\\ui\\menu_b.xbm
            """
        )

        let report = try search(query: "menu_", limit: 2)

        XCTAssertEqual(report.totalMatchCount, 3)
        XCTAssertEqual(report.matches.map(\.assetPath), [
            "base\\ui\\menu_a.xbm",
            "base\\ui\\menu_b.xbm"
        ])
    }

    func testNoResultsBehavior() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\menu_background.xbm\n"
        )

        let report = try search(query: "does_not_exist")
        let formatted = ArchiveCatalogSearchFormatter.format(report)

        XCTAssertTrue(report.matches.isEmpty)
        XCTAssertTrue(formatted.contains("No archive catalog matches found for query: does_not_exist"))
    }

    func testDeterministicOrdering() throws {
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: """
            ep1\\ui\\z_menu.xbm
            ep1\\ui\\a_menu.xbm
            """
        )
        try writeCatalog(
            "Data_archive_Mac_content_basegame_2_mainmenu.archive.txt",
            contents: "base\\ui\\b_menu.xbm\n"
        )
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\c_menu.xbm\n"
        )

        let report = try search(query: "menu")

        XCTAssertEqual(report.matches.map { "\($0.archivePath ?? "unknown")|\($0.assetPath)" }, [
            "Data/archive/Mac/content/basegame_1_engine.archive|base\\ui\\c_menu.xbm",
            "Data/archive/Mac/content/basegame_2_mainmenu.archive|base\\ui\\b_menu.xbm",
            "Data/archive/Mac/ep1/ep1_main.archive|ep1\\ui\\a_menu.xbm",
            "Data/archive/Mac/ep1/ep1_main.archive|ep1\\ui\\z_menu.xbm"
        ])
    }

    private func search(
        query: String,
        extensionFilter: String? = nil,
        archiveFilter: String? = nil,
        limit: Int = 50
    ) throws -> ArchiveCatalogSearchReport {
        try ArchiveCatalogSearcher().search(options: ArchiveCatalogSearchOptions(
            query: query,
            catalogDirectory: catalogDir,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            limit: limit
        ))
    }

    private func writeCatalog(_ relativePath: String, contents: String) throws {
        let url = catalogDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
