import Foundation
import XCTest
@testable import CyberMacCore

final class ArchiveSealResearchReporterTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var gameInstall: GameInstall!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveSealResearchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("CyberMac Home", isDirectory: true))
        gameInstall = try makeGameInstall()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testParsesCodeResourcesArchivesAndGroupsOfficialDirectories() throws {
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base")
        _ = try writeDataFile("archive/Mac/ep1/ep1.archive", contents: "ep1")
        _ = try writeDataFile("archive/pc/content/windows.archive", contents: "pc")
        _ = try writeDataFile("archive/Mac/ep1/ep1.addcont_keystone", contents: "key")
        try writeCodeResources(paths: [
            "Data/archive/Mac/content/basegame_1.archive",
            "Data/archive/Mac/ep1/ep1.archive",
            "Data/archive/pc/content/windows.archive",
            "Data/archive/Mac/ep1/ep1.addcont_keystone"
        ])

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveSealResearchReportFormatter.format(report)

        XCTAssertEqual(report.listedArchiveCount, 3)
        XCTAssertEqual(report.listedArchiveGroups.map(\.directory), [
            "Data/archive/Mac/content",
            "Data/archive/Mac/ep1",
            "anything else"
        ])
        XCTAssertTrue(report.listedArchiveGroups[0].entries.contains { $0.fileName == "basegame_1.archive" && $0.existsOnDisk })
        XCTAssertTrue(report.listedArchiveGroups[1].entries.contains { $0.fileName == "ep1.archive" && $0.existsOnDisk })
        XCTAssertTrue(report.listedArchiveGroups[2].entries.contains { $0.path == "Data/archive/pc/content/windows.archive" && $0.existsOnDisk })
        XCTAssertEqual(report.keystoneEntries.map(\.path), ["Data/archive/Mac/ep1/ep1.addcont_keystone"])
        XCTAssertTrue(formatted.contains("CodeResources archive entries"))
        XCTAssertTrue(formatted.contains("Data/archive/Mac/content:"))
        XCTAssertTrue(formatted.contains("Data/archive/Mac/ep1:"))
        XCTAssertTrue(formatted.contains("anything else:"))
        XCTAssertTrue(formatted.contains("ep1.addcont_keystone"))
    }

    func testDetectsOnDiskUnlistedProbeArchivesInLoosePaths() throws {
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base")
        _ = try writeDataFile("archive/Mac/mod/Fonts - IBM 3270.archive", contents: "probe")
        _ = try writeDataFile("archive/pc/content/Fonts - IBM 3270.archive", contents: "probe")
        try writeCodeResources(paths: ["Data/archive/Mac/content/basegame_1.archive"])

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveSealResearchReportFormatter.format(report)

        XCTAssertEqual(report.filesystemArchiveCount, 3)
        XCTAssertEqual(Set(report.unlistedFilesystemArchives.map(\.path)), [
            "Data/archive/Mac/mod/Fonts - IBM 3270.archive",
            "Data/archive/pc/content/Fonts - IBM 3270.archive"
        ])
        XCTAssertTrue(report.unlistedFilesystemArchives.allSatisfy(\.highlightedLoosePath))
        XCTAssertTrue(report.filesystemArchiveGroups.contains { group in
            group.directory == "Data/archive/Mac/mod" &&
                group.entries.contains { !$0.listedInCodeResources && $0.highlightedLoosePath }
        })
        XCTAssertTrue(formatted.contains("On-disk .archive files not listed in CodeResources: yes (2)."))
        XCTAssertTrue(formatted.contains("loose-path"))
    }

    func testDetectsCodeResourcesListedArchiveMissingOnDisk() throws {
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base")
        try writeCodeResources(paths: [
            "Data/archive/Mac/content/basegame_1.archive",
            "Data/archive/Mac/content/missing.archive"
        ])

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveSealResearchReportFormatter.format(report)

        XCTAssertEqual(report.missingListedArchives.map(\.path), ["Data/archive/Mac/content/missing.archive"])
        XCTAssertTrue(formatted.contains("CodeResources-listed .archive files missing on disk: yes (1)."))
        XCTAssertTrue(formatted.contains("Data/archive/Mac/content/missing.archive"))
    }

    func testRecommendationBlocksPhaseCWhenIBM3270AllFourNoEffectAndTargetsUnlisted() throws {
        let archiveFileName = "Fonts - IBM 3270.archive"
        try writeCodeResources(paths: ["Data/archive/Mac/content/basegame_1.archive"])
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base")
        let records = try ArchiveProbeCandidate.allCases.map { candidate in
            let targetURL = try writeDataFile("\(candidate.dataRelativePath)/\(archiveFileName)", contents: "probe")
            return makeProbeRecord(
                id: candidate.rawValue,
                archiveFileName: archiveFileName,
                targetURL: targetURL,
                result: .noEffect
            )
        }
        try saveProbeState(records: records)

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        let formatted = ArchiveSealResearchReportFormatter.format(report)

        XCTAssertTrue(report.probeSummary.ibm3270AllFourNoEffect)
        XCTAssertFalse(report.probeSummary.anyProbeRecordedWorked)
        XCTAssertTrue(report.probeSummary.allProbeTargetsUnlistedFromCodeResources)
        XCTAssertTrue(report.recommendationLines.contains {
            $0.contains("Keep Phase C blocked") && $0.contains("outside CodeResources")
        })
        XCTAssertTrue(formatted.contains("IBM 3270 all four no-effect: yes"))
        XCTAssertTrue(formatted.contains("All probe targets unlisted from CodeResources: yes"))
    }

    func testProbeWorkedRecommendationAllowsReconsideration() throws {
        let archiveFileName = "Experimental.archive"
        let targetURL = try writeDataFile("archive/Mac/mod/\(archiveFileName)", contents: "probe")
        try writeCodeResources(paths: [])
        try saveProbeState(records: [
            makeProbeRecord(
                id: "worked",
                archiveFileName: archiveFileName,
                targetURL: targetURL,
                result: .worked
            )
        ])

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)

        XCTAssertTrue(report.probeSummary.anyProbeRecordedWorked)
        XCTAssertTrue(report.recommendationLines.contains { $0.contains("Phase C may be reconsidered") })
    }

    func testReporterIsReadOnlyAndCreatesNoFilesUnderFakeApp() throws {
        _ = try writeDataFile("archive/Mac/content/basegame_1.archive", contents: "base")
        try writeCodeResources(paths: ["Data/archive/Mac/content/basegame_1.archive"])
        let before = try recursiveRelativePaths(under: gameInstall.appURL)

        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: gameInstall)
        _ = ArchiveSealResearchReportFormatter.format(report)
        let after = try recursiveRelativePaths(under: gameInstall.appURL)

        XCTAssertEqual(after, before)
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try writeInfoPlist(contentsURL: contentsURL)
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

    private func writeInfoPlist(contentsURL: URL) throws {
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleName": "Cyberpunk 2077"],
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
    }

    @discardableResult
    private func writeDataFile(_ relativePath: String, contents: String) throws -> URL {
        let url = gameInstall.dataURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func writeCodeResources(paths: [String]) throws {
        let url = gameInstall.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let files2 = Dictionary(uniqueKeysWithValues: paths.map { ($0, ["hash": "fixture"]) })
        let data = try PropertyListSerialization.data(fromPropertyList: ["files2": files2], format: .xml, options: 0)
        try data.write(to: url)
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
