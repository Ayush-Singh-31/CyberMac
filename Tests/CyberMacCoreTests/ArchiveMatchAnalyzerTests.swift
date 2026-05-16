import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveMatchAnalyzerTests: XCTestCase {
    private var tempDir: URL!
    private var catalogDir: URL!
    private var dbURL: URL!
    private var workDir: URL!
    private var cp77toolsURL: URL!
    private var modArchiveURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveMatchAnalyzerTests-\(UUID().uuidString)", isDirectory: true)
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        workDir = tempDir.appendingPathComponent("work", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)

        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
        try "#!/bin/sh\nexit 0\n".write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)

        modArchiveURL = tempDir.appendingPathComponent("aa_MeleeHUD.archive")
        try "mod archive".write(to: modArchiveURL, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testReadySingleArchiveBuildsStageMergeCommand() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\hud_melee\\melee_hud.inkwidget
            base\\ui\\hud_melee\\melee_hint.inkwidget
            base\\ui\\other\\unrelated.inkwidget
            """
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/hud_melee/melee_hud.inkwidget": "mod hud",
                "base/ui/hud_melee/melee_hint.inkwidget": "mod hint"
            ]
        ])

        let result = try analyzer(tooling: tooling).analyze(request: makeRequest())

        XCTAssertEqual(result.readinessStatus, .readySingleArchive)
        XCTAssertEqual(result.modFileCount, 2)
        XCTAssertEqual(result.exactMatchCount, 2)
        XCTAssertEqual(result.unmatchedCount, 0)
        XCTAssertEqual(result.unmatchedModAssetPaths, [])
        XCTAssertEqual(result.requiredOfficialArchives, ["Data/archive/Mac/content/basegame_1_engine.archive"])
        XCTAssertEqual(result.matchesByOfficialArchive.count, 1)
        XCTAssertEqual(result.matchesByOfficialArchive[0].officialArchivePath, "Data/archive/Mac/content/basegame_1_engine.archive")
        XCTAssertEqual(result.matchesByOfficialArchive[0].matchedAssetPaths, [
            "base/ui/hud_melee/melee_hint.inkwidget",
            "base/ui/hud_melee/melee_hud.inkwidget"
        ])
        let command = try XCTUnwrap(result.suggestedStageMergeCommand)
        XCTAssertTrue(command.contains("cybermac archive-patch stage-merge Data/archive/Mac/content/basegame_1_engine.archive"))
        XCTAssertTrue(command.contains("--mod-archive \(modArchiveURL.path)"))
        XCTAssertTrue(command.contains("--work-dir \(workDir.appendingPathComponent("stage-merge", isDirectory: true).path)"))
        XCTAssertTrue(command.contains("--out \(workDir.appendingPathComponent("patched.archive").path)"))
        XCTAssertTrue(command.contains("--cp77tools \(cp77toolsURL.path)"))
    }

    func testReadyMultiArchiveListsRequiredArchives() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\hud_melee\\melee_hud.inkwidget\n"
        )
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: "ep1\\ui\\new_widget.inkwidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/hud_melee/melee_hud.inkwidget": "a",
                "ep1/ui/new_widget.inkwidget": "b"
            ]
        ])

        let result = try analyzer(tooling: tooling).analyze(request: makeRequest())

        XCTAssertEqual(result.readinessStatus, .readyMultiArchive)
        XCTAssertEqual(result.exactMatchCount, 2)
        XCTAssertEqual(result.unmatchedCount, 0)
        XCTAssertNil(result.suggestedStageMergeCommand)
        XCTAssertEqual(result.requiredOfficialArchives, [
            "Data/archive/Mac/content/basegame_1_engine.archive",
            "Data/archive/Mac/ep1/ep1_main.archive"
        ])
        let formatted = ArchiveMatchAnalysisFormatter.format(result)
        XCTAssertTrue(formatted.contains("Automatic single-archive staging is not enough yet."))
        XCTAssertTrue(formatted.contains("- Data/archive/Mac/content/basegame_1_engine.archive"))
        XCTAssertTrue(formatted.contains("- Data/archive/Mac/ep1/ep1_main.archive"))
    }

    func testPartialMatchReportsUnmatchedAndDoesNotSuggestInstall() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\hud_melee\\melee_hud.inkwidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/hud_melee/melee_hud.inkwidget": "matched",
                "base/ui/mod_only.inkwidget": "extra"
            ]
        ])

        let result = try analyzer(tooling: tooling).analyze(request: makeRequest(limit: 5))

        XCTAssertEqual(result.readinessStatus, .partialMatch)
        XCTAssertEqual(result.modFileCount, 2)
        XCTAssertEqual(result.exactMatchCount, 1)
        XCTAssertEqual(result.unmatchedCount, 1)
        XCTAssertEqual(result.unmatchedModAssetPaths, ["base/ui/mod_only.inkwidget"])
        XCTAssertNil(result.suggestedStageMergeCommand)
        XCTAssertTrue(result.requiredOfficialArchives.isEmpty)
        let formatted = ArchiveMatchAnalysisFormatter.format(result)
        XCTAssertTrue(formatted.contains("Loose archive loading remains blocked"))
    }

    func testNoMatchReturnsNoMatchStatus() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\other\\unrelated.inkwidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/mod_only_a.inkwidget": "a",
                "base/ui/mod_only_b.inkwidget": "b"
            ]
        ])

        let result = try analyzer(tooling: tooling).analyze(request: makeRequest(limit: 1))

        XCTAssertEqual(result.readinessStatus, .noMatch)
        XCTAssertEqual(result.exactMatchCount, 0)
        XCTAssertEqual(result.unmatchedCount, 2)
        XCTAssertEqual(result.unmatchedSampleCount, 1)
        XCTAssertEqual(result.unmatchedModAssetPaths, ["base/ui/mod_only_a.inkwidget"])
        XCTAssertTrue(result.matchesByOfficialArchive.isEmpty)
        XCTAssertNil(result.suggestedStageMergeCommand)
        let formatted = ArchiveMatchAnalysisFormatter.format(result)
        XCTAssertTrue(formatted.contains("No exact-path matches"))
        XCTAssertTrue(formatted.contains("(showing 1 of 2"))
    }

    func testMissingModArchiveRejected() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\anything.inkwidget\n"
        )
        try buildIndex()
        let missingModArchive = tempDir.appendingPathComponent("missing.archive")
        let request = makeRequest(modArchiveURL: missingModArchive)

        XCTAssertThrowsError(try analyzer().analyze(request: request)) { error in
            XCTAssertTrue(String(describing: error).contains("Mod archive does not exist"))
        }
    }

    func testMissingDatabaseRejected() throws {
        let request = makeRequest()

        XCTAssertThrowsError(try analyzer().analyze(request: request)) { error in
            XCTAssertTrue(String(describing: error).contains("Archive catalog index database does not exist"))
        }
    }

    func testExtractionToolingIsAbstracted() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\hud_melee\\melee_hud.inkwidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/hud_melee/melee_hud.inkwidget": "mod"
            ]
        ])

        _ = try analyzer(tooling: tooling).analyze(request: makeRequest())

        XCTAssertEqual(tooling.extractCallCount, 1)
        XCTAssertEqual(tooling.extractRequests.first?.sourceArchiveURL.path, modArchiveURL.path)
        XCTAssertEqual(
            tooling.extractRequests.first?.outputDirectoryURL.path,
            workDir.appendingPathComponent("mod", isDirectory: true).path
        )
    }

    func testRejectsExistingModExtractionDirectory() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "base\\ui\\hud_melee\\melee_hud.inkwidget\n"
        )
        try buildIndex()
        try FileManager.default.createDirectory(at: workDir.appendingPathComponent("mod", isDirectory: true), withIntermediateDirectories: true)

        XCTAssertThrowsError(try analyzer().analyze(request: makeRequest())) { error in
            XCTAssertTrue(String(describing: error).contains("Stage directory already exists"))
        }
    }

    func testCaseInsensitiveExactMatchAcrossSlashStyles() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: "Base\\UI\\HUD_Melee\\Melee_HUD.InkWidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/hud_melee/melee_hud.inkwidget": "mod hud"
            ]
        ])

        let result = try analyzer(tooling: tooling).analyze(request: makeRequest())

        XCTAssertEqual(result.readinessStatus, .readySingleArchive)
        XCTAssertEqual(result.exactMatchCount, 1)
    }

    func testFormatterOutputIsDeterministicWithMultipleArchives() throws {
        try writeCatalog(
            "Data_archive_Mac_content_basegame_1_engine.archive.txt",
            contents: """
            base\\ui\\shared_widget.inkwidget
            base\\ui\\hud_melee\\melee_hud.inkwidget
            """
        )
        try writeCatalog(
            "Data_archive_Mac_ep1_ep1_main.archive.txt",
            contents: "base\\ui\\shared_widget.inkwidget\n"
        )
        try buildIndex()
        let tooling = FakeMatchTooling(filesByArchivePath: [
            modArchiveURL.path: [
                "base/ui/shared_widget.inkwidget": "shared",
                "base/ui/hud_melee/melee_hud.inkwidget": "hud"
            ]
        ])

        let resultA = try analyzer(tooling: tooling).analyze(request: makeRequest())
        try FileManager.default.removeItem(at: workDir)
        let resultB = try analyzer(tooling: tooling).analyze(request: makeRequest())

        XCTAssertEqual(resultA.readinessStatus, .readySingleArchive)
        XCTAssertEqual(resultA.requiredOfficialArchives, ["Data/archive/Mac/content/basegame_1_engine.archive"])
        let formattedA = ArchiveMatchAnalysisFormatter.format(resultA)
        let formattedB = ArchiveMatchAnalysisFormatter.format(resultB)
        XCTAssertEqual(formattedA, formattedB)
    }

    private func analyzer(tooling: any OfficialArchiveSwapTooling = FakeMatchTooling()) -> ArchiveMatchAnalyzer {
        ArchiveMatchAnalyzer(tooling: tooling)
    }

    private func makeRequest(
        modArchiveURL: URL? = nil,
        limit: Int = ArchiveMatchAnalysisRequest.defaultUnmatchedLimit
    ) -> ArchiveMatchAnalysisRequest {
        ArchiveMatchAnalysisRequest(
            modArchiveURL: modArchiveURL ?? self.modArchiveURL,
            workDirectoryURL: workDir,
            cp77toolsURL: cp77toolsURL,
            databaseURL: dbURL,
            unmatchedLimit: limit
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
}

private final class FakeMatchTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    struct ExtractRequest {
        let sourceArchiveURL: URL
        let outputDirectoryURL: URL
    }

    private let filesByArchivePath: [String: [String: String]]
    private(set) var extractRequests: [ExtractRequest] = []

    var extractCallCount: Int { extractRequests.count }

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
                .replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/")
                .reduce(outputDirectoryURL) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        // not used by match-mod
    }
}
