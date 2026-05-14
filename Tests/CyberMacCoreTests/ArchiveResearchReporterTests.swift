import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveResearchReporterTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var gameInstall: GameInstall!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveResearchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("CyberMac Home", isDirectory: true))
        gameInstall = try makeGameInstall()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testReportDetectsCandidateDirectoriesArchivesMetadataAndLeftoverProbeFilesReadOnly() throws {
        for candidate in ArchiveProbeCandidate.allCases {
            try FileManager.default.createDirectory(at: candidateDirectory(candidate), withIntermediateDirectories: true)
        }
        let baseArchive = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base archive")
        let leftoverProbe = try writeDataFile("archive/Mac/mod/Fonts - IBM 3270.archive", contents: "probe archive")
        let manifest = try writeDataFile("archive/Mac/content/archive_manifest.json", contents: #"{"archives":[]}"#)
        let index = try writeDataFile("cache/archive_index.bin", contents: "index")
        _ = try writeDataFile("r6/config/catalog.db", contents: "catalog")
        try FileManager.default.createDirectory(
            at: gameInstall.dataURL.appendingPathComponent("archive/bundles/example.archivebundle", isDirectory: true),
            withIntermediateDirectories: true
        )
        try saveProbeState(records: [
            makeProbeRecord(
                id: "mac-mod-leftover",
                archiveFileName: "Fonts - IBM 3270.archive",
                targetURL: leftoverProbe,
                result: .noEffect
            )
        ])
        let before = try recursiveRelativePaths(under: gameInstall.appURL)

        let report = ArchiveResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveResearchReportFormatter.format(report)
        let after = try recursiveRelativePaths(under: gameInstall.appURL)

        XCTAssertEqual(before, after)
        XCTAssertEqual(report.candidateDirectories.count, 4)
        XCTAssertTrue(report.candidateDirectories.allSatisfy(\.exists))
        XCTAssertEqual(
            report.candidateDirectories.first { $0.relativePath == ArchiveProbeCandidate.macMod.dataRelativePath }?.leftoverProbeFiles,
            ["Fonts - IBM 3270.archive"]
        )
        XCTAssertTrue(report.archiveTreeEntries.contains { $0.relativePath == "Mac/content/basegame_1.archive" })
        XCTAssertTrue(report.archiveTreeEntries.contains { $0.relativePath == "Mac/mod/Fonts - IBM 3270.archive" })
        XCTAssertTrue(report.archiveTreeEntries.contains { $0.relativePath == "Mac/content/archive_manifest.json" })
        XCTAssertTrue(report.existingArchiveGroups.contains { group in
            group.directory == "Mac/content" && group.archives.contains { $0.relativePath == "Mac/content/basegame_1.archive" }
        })
        XCTAssertTrue(report.existingArchiveGroups.contains { group in
            group.directory == "Mac/mod" && group.archives.contains { $0.relativePath == "Mac/mod/Fonts - IBM 3270.archive" }
        })
        XCTAssertTrue(report.metadataMatches.contains { entry in
            entry.relativePath == "archive/Mac/content/archive_manifest.json" &&
                entry.sha256 == (try? PathSafety.sha256(url: manifest))
        })
        XCTAssertTrue(report.metadataMatches.contains { entry in
            entry.relativePath == "cache/archive_index.bin" &&
                entry.sha256 == (try? PathSafety.sha256(url: index))
        })
        XCTAssertTrue(report.metadataMatches.contains { $0.relativePath == "archive/bundles/example.archivebundle" && $0.kind == .directory })
        XCTAssertFalse(report.metadataMatches.contains { $0.relativePath == "archive/Mac/content/basegame_1.archive" })
        XCTAssertNil(report.archiveTreeEntries.first { $0.relativePath == "Mac/content/basegame_1.archive" }?.sha256)
        XCTAssertTrue(formatted.contains("Known candidate directories"))
        XCTAssertTrue(formatted.contains("leftover probe files: Fonts - IBM 3270.archive"))
        XCTAssertTrue(formatted.contains("archive/Mac/content/archive_manifest.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: baseArchive.path))
    }

    func testProbeSummaryGroupsRecordsAndBlocksPhaseCForIBM3270NoEffectAcrossAllCandidates() throws {
        let archiveFileName = "Fonts - IBM 3270.archive"
        let records = ArchiveProbeCandidate.allCases.map { candidate in
            makeProbeRecord(
                id: candidate.rawValue,
                archiveFileName: archiveFileName,
                targetURL: candidateDirectory(candidate).appendingPathComponent(archiveFileName),
                result: .noEffect
            )
        }
        try saveProbeState(records: records)

        let report = ArchiveResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveResearchReportFormatter.format(report)

        XCTAssertEqual(report.probeState.totalProbes, 4)
        XCTAssertEqual(report.probeState.resultCounts, [ArchiveResearchCount(name: "no-effect", count: 4)])
        XCTAssertEqual(report.probeState.recordsByArchiveFile.first?.name, archiveFileName)
        XCTAssertEqual(report.probeState.recordsByArchiveFile.first?.total, 4)
        XCTAssertEqual(Set(report.probeState.recordsByCandidatePath.map(\.name)), Set(ArchiveProbeCandidate.allCases.map(\.dataRelativePath)))
        XCTAssertTrue(report.probeState.ibm3270AllFourNoEffect)
        XCTAssertFalse(report.probeState.anyProbeRecordedWorked)
        XCTAssertTrue(formatted.contains("IBM 3270 all four no-effect: yes"))
        XCTAssertTrue(formatted.contains("Any probe recorded worked: no"))
        XCTAssertTrue(formatted.contains("Phase C blocked: archive-only installer should remain blocked"))
        XCTAssertTrue(formatted.contains("The next research question is how the Mac build indexes or registers archive files."))
        XCTAssertTrue(formatted.contains("Archive/framework scanning remains useful, but archive-only installation is not validated."))
    }

    func testCorruptProbeStateIsReportedWithoutBlockingBundleScan() throws {
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        try "{not json".write(to: home.archiveProbeStateURL, atomically: true, encoding: .utf8)
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base archive")

        let report = ArchiveResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveResearchReportFormatter.format(report)

        XCTAssertTrue(report.probeState.stateExists)
        XCTAssertNotNil(report.probeState.loadError)
        XCTAssertEqual(report.probeState.totalProbes, 0)
        XCTAssertTrue(report.archiveTreeEntries.contains { $0.relativePath == "Mac/content/basegame_1.archive" })
        XCTAssertTrue(formatted.contains("State decode error:"))
        XCTAssertTrue(formatted.contains("Mac/content/basegame_1.archive"))
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)
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

    @discardableResult
    private func writeDataFile(_ relativePath: String, contents: String) throws -> URL {
        let url = gameInstall.dataURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func candidateDirectory(_ candidate: ArchiveProbeCandidate) -> URL {
        candidate.dataRelativePath
            .split(separator: "/")
            .reduce(gameInstall.dataURL) { partial, component in
                partial.appendingPathComponent(String(component), isDirectory: true)
            }
    }

    private func makeProbeRecord(
        id: String,
        archiveFileName: String,
        targetURL: URL,
        result: ArchiveProbeUserResult
    ) -> ArchiveProbeRecord {
        ArchiveProbeRecord(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            modArchivePath: tempDir.appendingPathComponent("\(id).zip").path,
            archiveFileName: archiveFileName,
            archiveSHA256: PathSafety.sha256(string: "\(id)-\(archiveFileName)"),
            candidateTargetPath: targetURL.path,
            commandPrinted: "",
            removalCommandPrinted: "",
            verifiedCopied: true,
            verifiedRemoved: false,
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
