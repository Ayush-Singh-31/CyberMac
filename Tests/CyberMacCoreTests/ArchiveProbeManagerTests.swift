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

    func testPrepareRefusesAdditionalFrameworkAndPackageMarkers() throws {
        let cases: [(String, [ZipEntry])] = [
            ("codeware.zip", [.file("r6/scripts/codeware/init.reds")]),
            ("equipment-ex.zip", [.file("archive/pc/mod/equipment-ex.archive")]),
            ("cet.zip", [.file("bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua")]),
            ("redmod.zip", [.file("mods/example/info.json")]),
            ("input-xml.zip", [.file("r6/input/inputContexts.xml")])
        ]

        for (name, entries) in cases {
            let zipURL = try makeZip(named: name, entries: entries)
            XCTAssertThrowsError(try manager.prepare(zipURL: zipURL, gameInstall: gameInstall), "Expected prepare to refuse \(name)")
        }
    }

    func testPrepareRefusesArchiveWithUnknownExtraContent() throws {
        let zipURL = try makeZip(named: "archive-extra-content.zip", entries: [
            .file("archive/pc/mod/example.archive"),
            .file("config/settings.dat")
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
        XCTAssertEqual(record.candidateTargetPath, expectedTargetPath(fileName: "example.archive", candidate: .macMod))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedArchiveURL(for: record).path))
        XCTAssertTrue(try ManifestStore(home: home).list().isEmpty)
    }

    func testDefaultCandidateIsMacMod() throws {
        let zipURL = try makeZip(named: "default-candidate.zip", entries: [
            .file("archive/pc/mod/default.archive")
        ])

        let record = try manager.prepare(zipURL: zipURL, gameInstall: gameInstall)

        XCTAssertEqual(record.candidateTargetPath, expectedTargetPath(fileName: "default.archive", candidate: .macMod))
    }

    func testEachCandidateMapsToExpectedTargetDirectory() throws {
        let candidates: [ArchiveProbeCandidate] = [.macMod, .macContent, .pcMod, .pcContent]

        for candidate in candidates {
            let zipURL = try makeZip(named: "\(candidate.rawValue)-\(UUID().uuidString).zip", entries: [
                .file("archive/pc/mod/probe.archive")
            ])

            let record = try manager.prepare(zipURL: zipURL, gameInstall: gameInstall, candidate: candidate)

            XCTAssertEqual(
                record.candidateTargetPath,
                expectedTargetPath(fileName: "probe.archive", candidate: candidate),
                "Unexpected target for \(candidate.rawValue)"
            )
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

    func testVerifyCopyRejectsTamperedTargetPathOutsideApprovedDirectories() throws {
        let record = try prepareSingleArchive()
        let outsideURL = tempDir.appendingPathComponent("outside-target.archive")
        try "outside content".write(to: outsideURL, atomically: true, encoding: .utf8)
        let tampered = try saveTamperedRecord(record, candidateTargetPath: outsideURL.path)

        XCTAssertThrowsUnsafePath(try manager.verifyCopy(id: tampered.id))
    }

    func testVerifyRemovalRejectsTamperedTargetPathOutsideApprovedDirectories() throws {
        let record = try prepareSingleArchive()
        let outsideURL = tempDir.appendingPathComponent("outside-removal-target.archive")
        try "outside content".write(to: outsideURL, atomically: true, encoding: .utf8)
        let tampered = try saveTamperedRecord(record, candidateTargetPath: outsideURL.path)

        XCTAssertThrowsUnsafePath(try manager.verifyRemoval(id: tampered.id))
    }

    func testVerifyRejectsUnrelatedDirectoryWithArchivePathSuffix() throws {
        let record = try prepareSingleArchive()
        let unrelatedURL = tempDir
            .appendingPathComponent("unrelated", isDirectory: true)
            .appendingPathComponent("archive/Mac/mod/example.archive")
        try FileManager.default.createDirectory(at: unrelatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "outside content".write(to: unrelatedURL, atomically: true, encoding: .utf8)
        let tampered = try saveTamperedRecord(record, candidateTargetPath: unrelatedURL.path)

        XCTAssertThrowsUnsafePath(try manager.verifyCopy(id: tampered.id))
    }

    func testVerifyRejectsRawTraversalInPersistedTargetPath() throws {
        let record = try prepareSingleArchive()
        let traversalPath = gameInstall.dataURL.path + "/archive/Mac/mod/../mod/example.archive"
        let tampered = try saveTamperedRecord(record, candidateTargetPath: traversalPath)

        XCTAssertThrowsUnsafePath(try manager.verifyRemoval(id: tampered.id))
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

    private func expectedTargetPath(fileName: String, candidate: ArchiveProbeCandidate) -> String {
        let candidateDirectory = candidate.dataRelativePath
            .split(separator: "/")
            .reduce(gameInstall.dataURL) { partial, component in
                partial.appendingPathComponent(String(component), isDirectory: true)
            }
        return candidateDirectory.appendingPathComponent(fileName).path
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

    private func saveTamperedRecord(_ record: ArchiveProbeRecord, candidateTargetPath: String) throws -> ArchiveProbeRecord {
        let tampered = ArchiveProbeRecord(
            id: record.id,
            createdAt: record.createdAt,
            modArchivePath: record.modArchivePath,
            archiveFileName: record.archiveFileName,
            archiveSHA256: record.archiveSHA256,
            candidateTargetPath: candidateTargetPath,
            commandPrinted: record.commandPrinted,
            removalCommandPrinted: record.removalCommandPrinted,
            verifiedCopied: record.verifiedCopied,
            verifiedRemoved: record.verifiedRemoved,
            userReportedResult: record.userReportedResult
        )
        try home.bootstrap()
        let data = try JSONEncoder.cybermac.encode(ArchiveProbeState(records: [tampered]))
        try data.write(to: home.archiveProbeStateURL, options: [.atomic])
        return tampered
    }

    private func XCTAssertThrowsUnsafePath<T>(
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case CyberMacError.unsafePath(let message) = error else {
                XCTFail("Expected CyberMacError.unsafePath, got \(error)", file: file, line: line)
                return
            }
            XCTAssertTrue(message.contains("Archive probe target path"), file: file, line: line)
        }
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
