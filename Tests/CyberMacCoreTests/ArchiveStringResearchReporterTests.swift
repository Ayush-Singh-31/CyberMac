import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveStringResearchReporterTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var gameInstall: GameInstall!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveStringResearchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("CyberMac Home", isDirectory: true))
        gameInstall = try makeGameInstall()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testStringsReportFindsFixedArchivePathHitsAndStaysReadOnly() throws {
        try writeExecutable("""
        loader mounts archive/Mac/content/basegame_1_engine.archive
        loader mounts archive/Mac/ep1/ep1_2_gamedata.archive
        manifest catalog index toc bundle mount keystone addcont_keystone
        """)
        _ = try writeDataFile("config/archive_manifest.json", contents: #"{"path":"archive/Mac/content/basegame_2_mainmenu.archive"}"#)
        _ = try writeDataFile("cache/archive_index.bin", contents: "memoryresident_1_general archive/Mac/ep1")
        _ = try writeDataFile("archive/Mac/content/basegame_1_engine.archive", contents: "archive/Mac/mod pc/mod should not be scanned")
        try FileManager.default.createDirectory(
            at: gameInstall.dataURL.appendingPathComponent("archive/Mac/ep1", isDirectory: true),
            withIntermediateDirectories: true
        )
        try saveProbeState(records: [
            makeProbeRecord(id: "no-effect", result: .noEffect)
        ])
        let before = try recursiveRelativePaths(under: gameInstall.appURL)

        let report = ArchiveStringResearchReporter(home: home).makeReport(
            gameInstall: gameInstall,
            options: ArchiveStringResearchOptions(maxScannableFileBytes: 1024)
        )
        let formatted = ArchiveStringResearchReportFormatter.format(report)
        let after = try recursiveRelativePaths(under: gameInstall.appURL)

        XCTAssertEqual(before, after)
        XCTAssertTrue(report.hitGroups.contains { group in
            group.file == "MacOS/Cyberpunk2077" &&
                group.hits.contains { $0.term == "archive/Mac/content" } &&
                group.hits.contains { $0.term == "archive/Mac/ep1" } &&
                group.hits.contains { $0.term == "basegame_1_engine" } &&
                group.hits.contains { $0.term == "ep1_2_gamedata" }
        })
        XCTAssertTrue(report.hitGroups.contains { group in
            group.file == "Data/config/archive_manifest.json" &&
                group.hits.contains { $0.term == "basegame_2_mainmenu" }
        })
        XCTAssertTrue(report.highlights.fixedMacContentReferenced)
        XCTAssertTrue(report.highlights.fixedMacEp1Referenced)
        XCTAssertTrue(report.highlights.fixedArchivePathTermsFound.contains("archive/Mac/content"))
        XCTAssertTrue(report.highlights.fixedArchivePathTermsFound.contains("archive/Mac/ep1"))
        XCTAssertFalse(report.highlights.looseArchivePathTermsFound.contains("pc/mod"))
        XCTAssertFalse(report.highlights.looseArchivePathTermsFound.contains("Mac/mod"))
        XCTAssertTrue(report.highlights.registrationTermsFound.contains("manifest"))
        XCTAssertTrue(report.highlights.phaseCBlocked)
        XCTAssertFalse(report.highlights.anyProbeRecordedWorked)
        XCTAssertTrue(report.archiveDirectories.contains { $0.relativePath == "archive/Mac/content" && $0.exists })
        XCTAssertTrue(report.archiveDirectories.contains { $0.relativePath == "archive/Mac/ep1" && $0.exists })
        XCTAssertTrue(report.skippedFiles.contains { file in
            file.relativePath == "Data/archive/Mac/content/basegame_1_engine.archive" &&
                file.reason == ".archive contents are not scanned by default"
        })
        XCTAssertFalse(report.hitGroups.contains { $0.file.hasSuffix(".archive") })
        XCTAssertTrue(formatted.contains("archive/Mac/content or Mac/content in scanned strings: yes"))
        XCTAssertTrue(formatted.contains("archive/Mac/ep1 or Mac/ep1 in scanned strings: yes"))
        XCTAssertTrue(formatted.contains("Loose archive/mod path terms: none"))
        XCTAssertTrue(formatted.contains("Phase C blocked: no binary archive probe recorded worked"))
    }

    func testStringsReportSkipsOversizedBinaryCandidates() throws {
        try writeExecutable("archive/Mac/content")
        _ = try writeDataFile("cache/large_archive_index.bin", contents: String(repeating: "x", count: 64))

        let report = ArchiveStringResearchReporter(home: home).makeReport(
            gameInstall: gameInstall,
            options: ArchiveStringResearchOptions(maxScannableFileBytes: 16)
        )
        let formatted = ArchiveStringResearchReportFormatter.format(report)

        XCTAssertTrue(report.skippedFiles.contains { file in
            file.relativePath == "Data/cache/large_archive_index.bin" &&
                (file.reason?.contains("larger than scan cap of 16 bytes") ?? false)
        })
        XCTAssertFalse(report.hitGroups.contains { $0.file == "Data/cache/large_archive_index.bin" })
        XCTAssertTrue(formatted.contains("larger than scan cap of 16 bytes"))
    }

    func testReceiptIsExistenceOnlyAndWorkedProbeDoesNotMarkBlocked() throws {
        try writeExecutable("archive/Mac/content")
        let receiptURL = gameInstall.appURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        try FileManager.default.createDirectory(at: receiptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "private receipt bytes archive/Mac/mod".write(to: receiptURL, atomically: true, encoding: .utf8)
        try saveProbeState(records: [
            makeProbeRecord(id: "worked", result: .worked)
        ])

        let report = ArchiveStringResearchReporter(home: home).makeReport(gameInstall: gameInstall)

        XCTAssertTrue(report.skippedFiles.contains { file in
            file.relativePath == "_MASReceipt/receipt" &&
                file.reason == "existence and size reported only; receipt data not parsed"
        })
        XCTAssertFalse(report.hitGroups.contains { $0.file == "_MASReceipt/receipt" })
        XCTAssertTrue(report.highlights.anyProbeRecordedWorked)
        XCTAssertFalse(report.highlights.phaseCBlocked)
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try "<plist><dict></dict></plist>".write(
            to: contentsURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        return GameInstall(
            appURL: appURL,
            executableURL: executableURL,
            dataURL: dataURL,
            archiveMacURL: nil,
            r6URL: nil,
            storefront: .macAppStore,
            displayName: "Cyberpunk 2077"
        )
    }

    private func writeExecutable(_ contents: String) throws {
        try contents.write(to: gameInstall.executableURL, atomically: true, encoding: .utf8)
    }

    @discardableResult
    private func writeDataFile(_ relativePath: String, contents: String) throws -> URL {
        let url = gameInstall.dataURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeProbeRecord(id: String, result: ArchiveProbeUserResult) -> ArchiveProbeRecord {
        ArchiveProbeRecord(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            modArchivePath: tempDir.appendingPathComponent("\(id).zip").path,
            archiveFileName: "Fonts - IBM 3270.archive",
            archiveSHA256: PathSafety.sha256(string: id),
            candidateTargetPath: gameInstall.dataURL
                .appendingPathComponent("archive/Mac/content/Fonts - IBM 3270.archive")
                .path,
            commandPrinted: "",
            removalCommandPrinted: "",
            verifiedCopied: true,
            verifiedRemoved: true,
            userReportedResult: result
        )
    }

    private func saveProbeState(records: [ArchiveProbeRecord]) throws {
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.cybermac.encode(ArchiveProbeState(records: records))
        try data.write(to: home.archiveProbeStateURL, options: [.atomic])
    }

    private func recursiveRelativePaths(under root: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: []
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return try PathSafety.relativePath(of: url, in: root)
        }
        .sorted()
    }
}
