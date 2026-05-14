import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class ArchiveProbeManagerTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var manager: ArchiveProbeManager!
    private var gameInstall: GameInstall!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacArchiveProbeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("CyberMac Home", isDirectory: true))
        manager = ArchiveProbeManager(home: home)
        gameInstall = try makeGameInstall(name: "Cyberpunk 2077: Ultimate.app")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testPrepareRefusesMissingAndNonZipFiles() throws {
        XCTAssertThrowsError(try manager.prepare(
            zipURL: tempDir.appendingPathComponent("missing.zip"),
            gameInstall: gameInstall
        ))

        let textURL = tempDir.appendingPathComponent("not-a-zip.txt")
        try "not a zip".write(to: textURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try manager.prepare(zipURL: textURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesRedscriptOnlyZip() throws {
        let zipURL = try makeZip(named: "redscript.zip", entries: [
            .file("r6/scripts/main.reds")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesMixedRedscriptAndArchiveZip() throws {
        let zipURL = try makeZip(named: "mixed.zip", entries: [
            .file("r6/scripts/main.reds"),
            .file("archive/pc/mod/example.archive")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesArchiveXLZip() throws {
        let zipURL = try makeZip(named: "archivexl.zip", entries: [
            .file("r6/archives/example.archive.xl")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesTweakXLZip() throws {
        let zipURL = try makeZip(named: "tweakxl.zip", entries: [
            .file("r6/tweaks/example.yaml")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesRED4extNativePluginZip() throws {
        let zipURL = try makeZip(named: "red4ext-native.zip", entries: [
            .file("red4ext/plugins/example/plugin.dll")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareRefusesMultipleArchiveFiles() throws {
        let zipURL = try makeZip(named: "multiple-archives.zip", entries: [
            .file("archive/pc/mod/one.archive"),
            .file("archive/pc/mod/two.archive")
        ])

        XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall))
    }

    func testPrepareAcceptsPureSingleArchiveOnlyZipAndCreatesNoManifest() throws {
        let zipURL = try makeZip(named: "archive-only.zip", entries: [
            .file("archive/pc/mod/example.archive"),
            .file("README.md")
        ])

        let record = try manager.prepare(zipURL: zipURL, gameInstall: gameInstall)

        XCTAssertEqual(record.archiveFileName, "example.archive")
        XCTAssertFalse(record.archiveSHA256.isEmpty)
        XCTAssertTrue(record.candidateTargetPath.hasSuffix("Contents/Data/archive/Mac/mod/example.archive"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedArchiveURL(for: record).path))
        XCTAssertTrue(try ManifestStore(home: home).list().isEmpty)
    }

    func testDefaultCandidateIsMacMod() throws {
        let zipURL = try makeZip(named: "default-candidate.zip", entries: [
            .file("archive/pc/mod/default.archive")
        ])

        let record = try manager.prepare(zipURL: zipURL, gameInstall: gameInstall)

        XCTAssertTrue(record.candidateTargetPath.hasSuffix("Contents/Data/archive/Mac/mod/default.archive"))
    }

    func testEachCandidateMapsToExpectedTargetDirectory() throws {
        let expectations: [(ArchiveProbeCandidate, String)] = [
            (.macMod, "Contents/Data/archive/Mac/mod/probe.archive"),
            (.macContent, "Contents/Data/archive/Mac/content/probe.archive"),
            (.pcMod, "Contents/Data/archive/pc/mod/probe.archive"),
            (.pcContent, "Contents/Data/archive/pc/content/probe.archive")
        ]

        for (candidate, suffix) in expectations {
            let zipURL = try makeZip(named: "\(candidate.rawValue)-\(UUID().uuidString).zip", entries: [
                .file("archive/pc/mod/probe.archive")
            ])

            let record = try manager.prepare(zipURL: zipURL, gameInstall: gameInstall, candidate: candidate)

            XCTAssertTrue(record.candidateTargetPath.hasSuffix(suffix), "Unexpected target for \(candidate.rawValue): \(record.candidateTargetPath)")
        }
    }

    func testGeneratedCommandsUseManualSudoAndSafeQuoting() throws {
        let quotedGame = try makeGameInstall(name: "Cyberpunk 2077: Ultimate \"QA\" (Test).app")
        let zipURL = try makeZip(named: "quoted.zip", entries: [
            .file("archive/pc/mod/quote \"x\" test.archive")
        ])

        let record = try manager.prepare(zipURL: zipURL, gameInstall: quotedGame)

        XCTAssertTrue(record.commandPrinted.contains("sudo mkdir -p \""))
        XCTAssertTrue(record.commandPrinted.contains("sudo cp \""))
        XCTAssertTrue(record.removalCommandPrinted.contains("sudo rm -f \""))
        XCTAssertTrue(record.commandPrinted.contains("Cyberpunk 2077: Ultimate \\\"QA\\\" (Test).app"))
        XCTAssertTrue(record.commandPrinted.contains("quote \\\"x\\\" test.archive"))
        XCTAssertEqual(record.commandPrinted.components(separatedBy: "\n").count, 2)
    }

    func testVerifyCopyPassesWhenTargetHashMatches() throws {
        let record = try prepareSingleArchive()
        try copyExtractedArchiveToTarget(record)

        let result = try manager.verifyCopy(id: record.id)

        XCTAssertTrue(result.targetExists)
        XCTAssertTrue(result.matched)
        XCTAssertTrue(result.record.verifiedCopied)
        XCTAssertEqual(result.actualSHA256, record.archiveSHA256)
    }

    func testVerifyCopyFailsWhenTargetIsMissing() throws {
        let record = try prepareSingleArchive()

        let result = try manager.verifyCopy(id: record.id)

        XCTAssertFalse(result.targetExists)
        XCTAssertFalse(result.matched)
        XCTAssertFalse(result.record.verifiedCopied)
        XCTAssertNil(result.actualSHA256)
    }

    func testVerifyCopyFailsWhenTargetHashMismatches() throws {
        let record = try prepareSingleArchive()
        let targetURL = URL(fileURLWithPath: record.candidateTargetPath)
        try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "different content".write(to: targetURL, atomically: true, encoding: .utf8)

        let result = try manager.verifyCopy(id: record.id)

        XCTAssertTrue(result.targetExists)
        XCTAssertFalse(result.matched)
        XCTAssertFalse(result.record.verifiedCopied)
        XCTAssertNotEqual(result.actualSHA256, record.archiveSHA256)
    }

    func testVerifyRemovalPassesOnlyWhenTargetAbsent() throws {
        let record = try prepareSingleArchive()

        let absentResult = try manager.verifyRemoval(id: record.id)
        XCTAssertTrue(absentResult.removed)
        XCTAssertFalse(absentResult.targetExists)
        XCTAssertTrue(absentResult.record.verifiedRemoved)

        try copyExtractedArchiveToTarget(record)
        let presentResult = try manager.verifyRemoval(id: record.id)
        XCTAssertFalse(presentResult.removed)
        XCTAssertTrue(presentResult.targetExists)
        XCTAssertFalse(presentResult.record.verifiedRemoved)
    }

    func testRecordResultPersistsAcceptedUserResults() throws {
        let record = try prepareSingleArchive()

        for result in ArchiveProbeUserResult.allCasesForTests {
            let updated = try manager.recordResult(id: record.id, result: result)
            XCTAssertEqual(updated.userReportedResult, result)
            XCTAssertEqual(try ArchiveProbeManager(home: home).list().first { $0.id == record.id }?.userReportedResult, result)
        }
    }

    func testArchiveProbeStatePersistsAndReloads() throws {
        let record = try prepareSingleArchive()
        let reloaded = try ArchiveProbeManager(home: home).list()

        XCTAssertTrue(FileManager.default.fileExists(atPath: home.archiveProbeStateURL.path))
        XCTAssertTrue(reloaded.contains { $0.id == record.id })
    }

    private func prepareSingleArchive() throws -> ArchiveProbeRecord {
        let zipURL = try makeZip(named: "\(UUID().uuidString).zip", entries: [
            .file("archive/pc/mod/example.archive")
        ])
        return try manager.prepare(zipURL: zipURL, gameInstall: gameInstall)
    }

    private func copyExtractedArchiveToTarget(_ record: ArchiveProbeRecord) throws {
        let sourceURL = extractedArchiveURL(for: record)
        let targetURL = URL(fileURLWithPath: record.candidateTargetPath)
        try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    }

    private func extractedArchiveURL(for record: ArchiveProbeRecord) -> URL {
        home.archiveProbeTmpURL
            .appendingPathComponent(record.id, isDirectory: true)
            .appendingPathComponent(record.archiveFileName)
    }

    private func makeGameInstall(name: String) throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent(name, isDirectory: true)
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

    private enum ZipEntry {
        case file(String, contents: String = "content")
    }

    private func makeZip(named name: String, entries: [ZipEntry]) throws -> URL {
        let zipURL = tempDir.appendingPathComponent(name)
        let archive = try Archive(url: zipURL, accessMode: .create)

        for entry in entries {
            switch entry {
            case .file(let path, let contents):
                let data = Data(contents.utf8)
                try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                    let start = Int(position)
                    let end = min(start + size, data.count)
                    return data.subdata(in: start..<end)
                }
            }
        }

        return zipURL
    }
}

private extension ArchiveProbeUserResult {
    static var allCasesForTests: [ArchiveProbeUserResult] {
        [.worked, .noEffect, .gameFailedToLaunch, .unknown]
    }
}
