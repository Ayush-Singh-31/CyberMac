import Foundation
import XCTest
@testable import CyberMacCore

final class OfficialArchiveBackupManagerTests: XCTestCase {
    private let contentRelativePath = "Data/archive/Mac/content/basegame_2_mainmenu.archive"
    private let ep1RelativePath = "Data/archive/Mac/ep1/ep1_main.archive"

    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var manager: OfficialArchiveBackupManager!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacOfficialArchiveBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("CyberMac Home", isDirectory: true))
        manager = OfficialArchiveBackupManager(home: home)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBackupSucceedsForCodeResourcesListedContentArchive() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath],
            codeResourcesSection: "files2"
        )

        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(metadata.relativeArchivePath, contentRelativePath)
        XCTAssertEqual(metadata.originalFileName, "basegame_2_mainmenu.archive")
        XCTAssertEqual(metadata.originalSize, UInt64("official content archive".utf8.count))
        XCTAssertEqual(metadata.originalSHA256, try PathSafety.sha256(url: archiveURL(relativePath: contentRelativePath, gameInstall: game)))
        XCTAssertTrue(metadata.codeResourcesListed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.backupFilePath))
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: metadata.backupFilePath)), metadata.originalSHA256)
    }

    func testBackupSucceedsForCodeResourcesListedEP1Archive() throws {
        let game = try makeGameInstall(
            archiveFiles: [ep1RelativePath: "official ep1 archive"],
            codeResourcesPaths: [ep1RelativePath],
            codeResourcesSection: "files"
        )

        let metadata = try manager.backup(relativeArchivePath: ep1RelativePath, gameInstall: game)

        XCTAssertEqual(metadata.relativeArchivePath, ep1RelativePath)
        XCTAssertEqual(metadata.originalFileName, "ep1_main.archive")
        XCTAssertTrue(metadata.codeResourcesListed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.backupFilePath))
    }

    func testBackupRejectsDataArchivePCMod() throws {
        let game = try makeGameInstall(
            archiveFiles: ["Data/archive/pc/mod/bad.archive": "bad"],
            codeResourcesPaths: ["Data/archive/pc/mod/bad.archive"]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: "Data/archive/pc/mod/bad.archive", gameInstall: game))
    }

    func testBackupRejectsDataArchivePCContent() throws {
        let game = try makeGameInstall(
            archiveFiles: ["Data/archive/pc/content/bad.archive": "bad"],
            codeResourcesPaths: ["Data/archive/pc/content/bad.archive"]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: "Data/archive/pc/content/bad.archive", gameInstall: game))
    }

    func testBackupRejectsDataArchiveMacMod() throws {
        let game = try makeGameInstall(
            archiveFiles: ["Data/archive/Mac/mod/bad.archive": "bad"],
            codeResourcesPaths: ["Data/archive/Mac/mod/bad.archive"]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: "Data/archive/Mac/mod/bad.archive", gameInstall: game))
    }

    func testBackupRejectsPathTraversal() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: "Data/archive/Mac/content/../ep1/bad.archive", gameInstall: game))
    }

    func testBackupRejectsAbsolutePath() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: "/Data/archive/Mac/content/basegame.archive", gameInstall: game))
    }

    func testBackupRejectsNonArchiveFile() throws {
        let textRelativePath = "Data/archive/Mac/content/readme.txt"
        let game = try makeGameInstall(
            archiveFiles: [textRelativePath: "not an archive"],
            codeResourcesPaths: [textRelativePath]
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: textRelativePath, gameInstall: game))
    }

    func testBackupRejectsArchiveNotListedInCodeResources() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: []
        )

        XCTAssertThrowsError(try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game))
    }

    func testListBackupsReportsStoredMetadata() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let backups = try manager.list()

        XCTAssertEqual(backups.map(\.backupID), [metadata.backupID])
        XCTAssertLessThan(abs(try XCTUnwrap(backups.first?.createdAt).timeIntervalSince(metadata.createdAt)), 1)
        XCTAssertEqual(backups.first?.relativeArchivePath, contentRelativePath)
        XCTAssertEqual(backups.first?.originalSize, metadata.originalSize)
        XCTAssertEqual(backups.first?.originalSHA256, metadata.originalSHA256)
        XCTAssertEqual(backups.first?.gameAppPath, game.appURL.path)
    }

    func testRestoreDryRunPrintsManualSudoCpOnly() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let command = try manager.restoreDryRunCommand(backupID: metadata.backupID)

        let expectedDestination = archiveURL(relativePath: contentRelativePath, gameInstall: game)
        XCTAssertEqual(
            command,
            "sudo cp \(PathSafety.shellQuoted(metadata.backupFilePath)) \(PathSafety.shellQuoted(expectedDestination.path))"
        )
        XCTAssertEqual(command.components(separatedBy: "\n").count, 1)
        XCTAssertFalse(command.contains("mkdir"))
        XCTAssertFalse(command.contains("rm -f"))
    }

    func testRestoreVerifyPassesWhenDestinationHashMatchesBackupHash() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let result = try manager.verifyRestore(backupID: metadata.backupID)

        XCTAssertTrue(result.matched)
        XCTAssertEqual(result.currentSHA256, metadata.originalSHA256)
        XCTAssertEqual(result.expectedSHA256, metadata.originalSHA256)
    }

    func testRestoreVerifyFailsWhenDestinationHashDiffers() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        let result = try manager.verifyRestore(backupID: metadata.backupID)

        XCTAssertFalse(result.matched)
        XCTAssertNotEqual(result.currentSHA256, metadata.originalSHA256)
        XCTAssertEqual(result.expectedSHA256, metadata.originalSHA256)
    }

    func testTamperedMetadataBackupFilePathOutsideBackupRootIsRejected() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        let outsideURL = tempDir.appendingPathComponent("outside.archive")
        try "outside backup".write(to: outsideURL, atomically: true, encoding: .utf8)
        let tampered = OfficialArchiveBackupMetadata(
            backupID: metadata.backupID,
            createdAt: metadata.createdAt,
            gameAppPath: metadata.gameAppPath,
            relativeArchivePath: metadata.relativeArchivePath,
            originalArchivePath: metadata.originalArchivePath,
            originalFileName: metadata.originalFileName,
            originalSize: metadata.originalSize,
            originalSHA256: metadata.originalSHA256,
            codeResourcesListed: metadata.codeResourcesListed,
            backupFilePath: outsideURL.path
        )
        try saveTamperedMetadata(tampered)

        XCTAssertThrowsError(try manager.restoreDryRunCommand(backupID: metadata.backupID)) { error in
            guard case CyberMacError.unsafePath = error else {
                XCTFail("Expected unsafePath, got \(error)")
                return
            }
        }
    }

    func testTamperedMetadataRelativeArchivePathOutsideAllowedDirectoriesIsRejected() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        let tampered = OfficialArchiveBackupMetadata(
            backupID: metadata.backupID,
            createdAt: metadata.createdAt,
            gameAppPath: metadata.gameAppPath,
            relativeArchivePath: "Data/archive/pc/content/basegame_2_mainmenu.archive",
            originalArchivePath: metadata.originalArchivePath,
            originalFileName: metadata.originalFileName,
            originalSize: metadata.originalSize,
            originalSHA256: metadata.originalSHA256,
            codeResourcesListed: metadata.codeResourcesListed,
            backupFilePath: metadata.backupFilePath
        )
        try saveTamperedMetadata(tampered)

        XCTAssertThrowsError(try manager.restoreDryRunCommand(backupID: metadata.backupID)) { error in
            guard case CyberMacError.unsafePath = error else {
                XCTFail("Expected unsafePath, got \(error)")
                return
            }
        }
    }

    func testBackupListDryRunAndVerifyDoNotModifyGameBundleFiles() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let before = try gameBundleSnapshot(gameInstall: game)

        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        _ = try manager.list()
        _ = try manager.restoreDryRunCommand(backupID: metadata.backupID)
        _ = try manager.verifyRestore(backupID: metadata.backupID)

        XCTAssertEqual(try gameBundleSnapshot(gameInstall: game), before)
    }

    private func makeGameInstall(
        archiveFiles: [String: String],
        codeResourcesPaths: [String],
        codeResourcesSection: String = "files2"
    ) throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077 \(UUID().uuidString).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        for (relativePath, contents) in archiveFiles {
            let fileURL = appending(relativePath: relativePath, to: contentsURL)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        try writeCodeResources(contentsURL: contentsURL, listedPaths: codeResourcesPaths, section: codeResourcesSection)

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

    private func writeCodeResources(contentsURL: URL, listedPaths: [String], section: String) throws {
        let codeSignatureURL = contentsURL.appendingPathComponent("_CodeSignature", isDirectory: true)
        try FileManager.default.createDirectory(at: codeSignatureURL, withIntermediateDirectories: true)
        let entries = Dictionary(uniqueKeysWithValues: listedPaths.map { path in
            (path, ["hash": "fixture"])
        })
        let plist: [String: Any] = [section: entries]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: codeSignatureURL.appendingPathComponent("CodeResources"), options: [.atomic])
    }

    private func archiveURL(relativePath: String, gameInstall: GameInstall) -> URL {
        appending(relativePath: relativePath, to: gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true))
    }

    private func appending(relativePath: String, to rootURL: URL) -> URL {
        relativePath.split(separator: "/").reduce(rootURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }

    private func saveTamperedMetadata(_ metadata: OfficialArchiveBackupMetadata) throws {
        let metadataURL = manager
            .backupDirectory(backupID: metadata.backupID)
            .appendingPathComponent("metadata.json")
        let data = try JSONEncoder.cybermac.encode(metadata)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private func gameBundleSnapshot(gameInstall: GameInstall) throws -> [String: String] {
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: contentsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var snapshot: [String: String] = [:]
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = try PathSafety.relativePath(of: url, in: contentsURL)
            snapshot[relativePath] = try PathSafety.sha256(url: url)
        }
        return snapshot
    }
}
