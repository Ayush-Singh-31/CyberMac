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

    func testPreflightReportsPristineWhenCurrentHashMatchesNewestMatchingBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .pristine)
        XCTAssertEqual(result.relativeArchivePath, contentRelativePath)
        XCTAssertEqual(result.gameAppPath, game.appURL.path)
        XCTAssertEqual(result.destinationPath, archiveURL(relativePath: contentRelativePath, gameInstall: game).path)
        XCTAssertTrue(result.codeResourcesListed)
        XCTAssertEqual(result.currentSize, metadata.originalSize)
        XCTAssertEqual(result.currentSHA256, metadata.originalSHA256)
        XCTAssertEqual(result.newestBackupID, metadata.backupID)
        XCTAssertEqual(result.expectedOriginalSize, metadata.originalSize)
        XCTAssertEqual(result.expectedOriginalSHA256, metadata.originalSHA256)
        XCTAssertNil(result.manualRestoreCommand)
        XCTAssertNil(result.suggestedBackupCommand)
        XCTAssertTrue(OfficialArchivePreflightFormatter.format(result).contains("Status: PRISTINE"))
    }

    func testPreflightReportsModifiedWhenCurrentHashDiffersFromNewestMatchingBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .modified)
        XCTAssertNotEqual(result.currentSHA256, metadata.originalSHA256)
        XCTAssertEqual(result.expectedOriginalSHA256, metadata.originalSHA256)
        XCTAssertEqual(
            result.manualRestoreCommand,
            "sudo cp \(PathSafety.shellQuoted(metadata.backupFilePath)) \(PathSafety.shellQuoted(archiveURL(relativePath: contentRelativePath, gameInstall: game).path))"
        )
        XCTAssertTrue(OfficialArchivePreflightFormatter.format(result).contains("Manual restore command:"))
    }

    func testPreflightReportsMissingWhenArchiveIsAbsentButBackupExists() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try FileManager.default.removeItem(at: archiveURL(relativePath: contentRelativePath, gameInstall: game))

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .missing)
        XCTAssertNil(result.currentSize)
        XCTAssertNil(result.currentSHA256)
        XCTAssertEqual(result.newestBackupID, metadata.backupID)
        XCTAssertEqual(
            result.manualRestoreCommand,
            "sudo cp \(PathSafety.shellQuoted(metadata.backupFilePath)) \(PathSafety.shellQuoted(archiveURL(relativePath: contentRelativePath, gameInstall: game).path))"
        )
    }

    func testPreflightReportsNoBackupWhenListedArchiveExistsWithoutMatchingBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .noBackup)
        XCTAssertTrue(result.codeResourcesListed)
        XCTAssertNotNil(result.currentSHA256)
        XCTAssertNil(result.newestBackupID)
        XCTAssertNil(result.manualRestoreCommand)
        XCTAssertEqual(
            result.suggestedBackupCommand,
            "swift run cybermac archive-patch backup-official \(contentRelativePath)"
        )
    }

    func testPreflightRejectsAbsolutePaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        assertPreflightBlocked(relativeArchivePath: "/Data/archive/Mac/content/basegame.archive", gameInstall: game)
    }

    func testPreflightRejectsTraversalPaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        assertPreflightBlocked(relativeArchivePath: "Data/archive/Mac/content/../ep1/bad.archive", gameInstall: game)
    }

    func testPreflightRejectsNonArchivePaths() throws {
        let textRelativePath = "Data/archive/Mac/content/readme.txt"
        let game = try makeGameInstall(
            archiveFiles: [textRelativePath: "not an archive"],
            codeResourcesPaths: [textRelativePath]
        )

        assertPreflightBlocked(relativeArchivePath: textRelativePath, gameInstall: game)
    }

    func testPreflightRejectsDataArchiveMacMod() throws {
        let relativePath = "Data/archive/Mac/mod/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertPreflightBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testPreflightRejectsDataArchivePCMod() throws {
        let relativePath = "Data/archive/pc/mod/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertPreflightBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testPreflightRejectsDataArchivePCContent() throws {
        let relativePath = "Data/archive/pc/content/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertPreflightBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testPreflightRejectsArchiveNotListedInCodeResources() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: []
        )

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertFalse(result.codeResourcesListed)
        XCTAssertTrue(result.reason?.contains("CodeResources") == true)
        XCTAssertNil(result.manualRestoreCommand)
    }

    func testPreflightUsesNewestMatchingBackupWhenMultipleBackupsExistForSameRelativePath() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "old archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let oldBackup = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "new archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)
        let newBackup = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try saveTamperedMetadata(copyMetadata(oldBackup, createdAt: Date(timeIntervalSince1970: 10)))
        try saveTamperedMetadata(copyMetadata(newBackup, createdAt: Date(timeIntervalSince1970: 20)))

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .pristine)
        XCTAssertEqual(result.newestBackupID, newBackup.backupID)
        XCTAssertEqual(result.expectedOriginalSHA256, newBackup.originalSHA256)
    }

    func testPreflightIgnoresBackupsForDifferentRelativeArchivePaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [
                contentRelativePath: "official content archive",
                ep1RelativePath: "official ep1 archive"
            ],
            codeResourcesPaths: [contentRelativePath, ep1RelativePath]
        )
        _ = try manager.backup(relativeArchivePath: ep1RelativePath, gameInstall: game)

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(result.status, .noBackup)
        XCTAssertNil(result.newestBackupID)
        XCTAssertNil(result.expectedOriginalSHA256)
    }

    func testPreflightPrintsManualRestoreCommandOnlyForModifiedOrMissingWithMatchingBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [
                contentRelativePath: "official content archive",
                ep1RelativePath: "official ep1 archive"
            ],
            codeResourcesPaths: [contentRelativePath, ep1RelativePath]
        )
        _ = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let pristine = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)
        let modified = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        try FileManager.default.removeItem(at: archiveURL(relativePath: contentRelativePath, gameInstall: game))
        let missing = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        let noBackup = manager.preflight(relativeArchivePath: ep1RelativePath, gameInstall: game)

        XCTAssertEqual(pristine.status, .pristine)
        XCTAssertNil(pristine.manualRestoreCommand)
        XCTAssertFalse(OfficialArchivePreflightFormatter.format(pristine).contains("Manual restore command:"))
        XCTAssertEqual(modified.status, .modified)
        XCTAssertNotNil(modified.manualRestoreCommand)
        XCTAssertTrue(OfficialArchivePreflightFormatter.format(modified).contains("Manual restore command:"))
        XCTAssertEqual(missing.status, .missing)
        XCTAssertNotNil(missing.manualRestoreCommand)
        XCTAssertTrue(OfficialArchivePreflightFormatter.format(missing).contains("Manual restore command:"))
        XCTAssertEqual(noBackup.status, .noBackup)
        XCTAssertNil(noBackup.manualRestoreCommand)
        XCTAssertFalse(OfficialArchivePreflightFormatter.format(noBackup).contains("Manual restore command:"))
    }

    func testPreflightPrintsSuggestedBackupCommandForNoBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        let formatted = OfficialArchivePreflightFormatter.format(
            manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        )

        XCTAssertTrue(formatted.contains("Status: NO_BACKUP"))
        XCTAssertTrue(formatted.contains("Suggested backup command:"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch backup-official \(contentRelativePath)"))
    }

    func testPreflightRejectsTamperedMetadataBackupFilePathOutsideBackupRootBeforePrintingRestoreCommand() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        let outsideURL = tempDir.appendingPathComponent("outside-preflight.archive")
        try "outside backup".write(to: outsideURL, atomically: true, encoding: .utf8)
        try saveTamperedMetadata(copyMetadata(metadata, backupFilePath: outsideURL.path))
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        let result = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        let formatted = OfficialArchivePreflightFormatter.format(result)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertNil(result.manualRestoreCommand)
        XCTAssertFalse(formatted.contains("Manual restore command:"))
        XCTAssertFalse(formatted.contains("sudo cp"))
    }

    func testStatusAcceptsOfficialPath() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertEqual(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game), .unknownBackup)
    }

    func testStatusRejectsNonOfficialPaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let rejectedPaths = [
            "Data/archive/Mac/mod/bad.archive",
            "Data/archive/pc/mod/bad.archive",
            "Data/archive/pc/content/bad.archive",
            "Data/archive/Mac/content/readme.txt",
            "Data/archive/Mac/content/nested/bad.archive",
            "Data/archive/Mac/texture/bad.archive"
        ]

        for relativePath in rejectedPaths {
            XCTAssertThrowsError(try manager.status(relativeArchivePath: relativePath, gameInstall: game), relativePath)
        }
    }

    func testStatusRejectsTraversal() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertThrowsError(try manager.status(relativeArchivePath: "Data/archive/Mac/content/../ep1/bad.archive", gameInstall: game))
    }

    func testStatusRejectsArchiveNotListedInCodeResources() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: []
        )

        XCTAssertThrowsError(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game))
    }

    func testStatusMissingArchiveReportsMissing() throws {
        let game = try makeGameInstall(
            archiveFiles: [:],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertEqual(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game), .missing)
    }

    func testStatusNoMatchingBackupReportsUnknownBackup() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        XCTAssertEqual(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game), .unknownBackup)
    }

    func testStatusMatchingBackupHashReportsPristine() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        _ = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertEqual(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game), .pristine)
    }

    func testStatusDifferingHashReportsModified() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        _ = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        XCTAssertEqual(try manager.status(relativeArchivePath: contentRelativePath, gameInstall: game), .modified)
    }

    func testManualPlanRejectsAbsolutePaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: "/Data/archive/Mac/content/basegame.archive", gameInstall: game)
    }

    func testManualPlanRejectsTraversalPaths() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: "Data/archive/Mac/content/../ep1/bad.archive", gameInstall: game)
    }

    func testManualPlanRejectsNonArchivePaths() throws {
        let textRelativePath = "Data/archive/Mac/content/readme.txt"
        let game = try makeGameInstall(
            archiveFiles: [textRelativePath: "not an archive"],
            codeResourcesPaths: [textRelativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: textRelativePath, gameInstall: game)
    }

    func testManualPlanRejectsDataArchiveMacMod() throws {
        let relativePath = "Data/archive/Mac/mod/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testManualPlanRejectsDataArchivePCMod() throws {
        let relativePath = "Data/archive/pc/mod/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testManualPlanRejectsDataArchivePCContent() throws {
        let relativePath = "Data/archive/pc/content/bad.archive"
        let game = try makeGameInstall(
            archiveFiles: [relativePath: "bad"],
            codeResourcesPaths: [relativePath]
        )

        assertManualPlanBlocked(relativeArchivePath: relativePath, gameInstall: game)
    }

    func testManualPlanRejectsArchiveNotListedInCodeResources() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: []
        )

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Status: BLOCKED"))
        XCTAssertTrue(formatted.contains("Validation failed."))
        XCTAssertTrue(formatted.contains("CodeResources"))
        XCTAssertFalse(formatted.contains("Manual experiment checklist:"))
        XCTAssertFalse(formatted.contains("Manual restore command:"))
    }

    func testManualPlanPrintsPristineChecklistWithBackupIDAndHash() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Official archive manual patch plan"))
        XCTAssertTrue(formatted.contains("Status: PRISTINE"))
        XCTAssertTrue(formatted.contains("Backup ID: \(metadata.backupID)"))
        XCTAssertTrue(formatted.contains("Backup SHA-256: \(metadata.originalSHA256)"))
        XCTAssertTrue(formatted.contains("Archive is safe to use as a baseline."))
        XCTAssertTrue(formatted.contains("Manual experiment checklist:"))
    }

    func testManualPlanPristineIncludesPreflightBeforeAndAfterCopy() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        _ = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Run preflight and confirm PRISTINE:"))
        XCTAssertTrue(formatted.contains("Run preflight again before copying."))
        XCTAssertTrue(formatted.contains("Run preflight again and expect MODIFIED:"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch preflight \(contentRelativePath)"))
    }

    func testManualPlanPristineIncludesRestoreVerifyFinalPreflightAndWarnings() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch restore-official \(metadata.backupID) --dry-run"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch restore-official \(metadata.backupID) --verify"))
        XCTAssertTrue(formatted.contains("Run preflight again and expect PRISTINE:"))
        XCTAssertTrue(formatted.contains("Warnings:"))
        XCTAssertTrue(formatted.contains("Do not test clothing yet."))
        XCTAssertTrue(formatted.contains("Do not patch basegame_4_appearance.archive or gamedata archives yet."))
        XCTAssertTrue(formatted.contains("CyberMac should not automate WolvenKit or sudo copy operations."))
    }

    func testManualPlanNoBackupPrintsBackupCommandAndNoPatchSteps() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Status: NO_BACKUP"))
        XCTAssertTrue(formatted.contains("Do not patch yet."))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch backup-official \(contentRelativePath)"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch preflight \(contentRelativePath)"))
        XCTAssertFalse(formatted.contains("Manual experiment checklist:"))
        XCTAssertFalse(formatted.contains("Make one tiny visible UI/menu change only."))
    }

    func testManualPlanModifiedPrintsManualRestoreCommandAndNoPatchSteps() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Status: MODIFIED"))
        XCTAssertTrue(formatted.contains("Do not begin a new experiment."))
        XCTAssertTrue(formatted.contains("Manual restore command:"))
        XCTAssertTrue(formatted.contains("sudo cp \(PathSafety.shellQuoted(metadata.backupFilePath))"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch restore-official \(metadata.backupID) --verify"))
        XCTAssertFalse(formatted.contains("Manual experiment checklist:"))
        XCTAssertFalse(formatted.contains("Make one tiny visible UI/menu change only."))
    }

    func testManualPlanMissingPrintsManualRestoreCommandWhenBackupExistsAndNoPatchSteps() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        try FileManager.default.removeItem(at: archiveURL(relativePath: contentRelativePath, gameInstall: game))

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Status: MISSING"))
        XCTAssertTrue(formatted.contains("Do not launch or patch."))
        XCTAssertTrue(formatted.contains("Official archive is missing."))
        XCTAssertTrue(formatted.contains("Manual restore command:"))
        XCTAssertTrue(formatted.contains("sudo cp \(PathSafety.shellQuoted(metadata.backupFilePath))"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch restore-official \(metadata.backupID) --verify"))
        XCTAssertFalse(formatted.contains("Manual experiment checklist:"))
        XCTAssertFalse(formatted.contains("Make one tiny visible UI/menu change only."))
    }

    func testManualPlanRejectsTamperedMetadataBackupFilePathOutsideBackupRootBeforePrintingRestoreCommand() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        let outsideURL = tempDir.appendingPathComponent("outside-manual-plan.archive")
        try "outside backup".write(to: outsideURL, atomically: true, encoding: .utf8)
        try saveTamperedMetadata(copyMetadata(metadata, backupFilePath: outsideURL.path))
        try "changed archive".write(to: archiveURL(relativePath: contentRelativePath, gameInstall: game), atomically: true, encoding: .utf8)

        let formatted = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)

        XCTAssertTrue(formatted.contains("Status: BLOCKED"))
        XCTAssertTrue(formatted.contains("Validation failed."))
        XCTAssertFalse(formatted.contains("Manual restore command:"))
        XCTAssertFalse(formatted.contains("sudo cp"))
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

    func testManualPlanPreflightListDryRunAndVerifyDoNotModifyGameBundleFilesOrBackupMetadata() throws {
        let game = try makeGameInstall(
            archiveFiles: [contentRelativePath: "official content archive"],
            codeResourcesPaths: [contentRelativePath]
        )
        let before = try gameBundleSnapshot(gameInstall: game)

        let metadata = try manager.backup(relativeArchivePath: contentRelativePath, gameInstall: game)
        let backupMetadataBefore = try backupMetadataSnapshot()
        _ = manualPlan(relativeArchivePath: contentRelativePath, gameInstall: game)
        _ = manager.preflight(relativeArchivePath: contentRelativePath, gameInstall: game)
        _ = try manager.list()
        _ = try manager.restoreDryRunCommand(backupID: metadata.backupID)
        _ = try manager.verifyRestore(backupID: metadata.backupID)

        XCTAssertEqual(try gameBundleSnapshot(gameInstall: game), before)
        XCTAssertEqual(try backupMetadataSnapshot(), backupMetadataBefore)
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

    private func copyMetadata(
        _ metadata: OfficialArchiveBackupMetadata,
        createdAt: Date? = nil,
        relativeArchivePath: String? = nil,
        backupFilePath: String? = nil
    ) -> OfficialArchiveBackupMetadata {
        OfficialArchiveBackupMetadata(
            backupID: metadata.backupID,
            createdAt: createdAt ?? metadata.createdAt,
            gameAppPath: metadata.gameAppPath,
            relativeArchivePath: relativeArchivePath ?? metadata.relativeArchivePath,
            originalArchivePath: metadata.originalArchivePath,
            originalFileName: metadata.originalFileName,
            originalSize: metadata.originalSize,
            originalSHA256: metadata.originalSHA256,
            codeResourcesListed: metadata.codeResourcesListed,
            backupFilePath: backupFilePath ?? metadata.backupFilePath
        )
    }

    private func assertPreflightBlocked(
        relativeArchivePath: String,
        gameInstall: GameInstall,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = manager.preflight(relativeArchivePath: relativeArchivePath, gameInstall: gameInstall)
        XCTAssertEqual(result.status, .blocked, file: file, line: line)
        XCTAssertNil(result.manualRestoreCommand, file: file, line: line)
    }

    private func assertManualPlanBlocked(
        relativeArchivePath: String,
        gameInstall: GameInstall,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let formatted = manualPlan(relativeArchivePath: relativeArchivePath, gameInstall: gameInstall)
        XCTAssertTrue(formatted.contains("Status: BLOCKED"), file: file, line: line)
        XCTAssertTrue(formatted.contains("Validation failed."), file: file, line: line)
        XCTAssertTrue(formatted.contains("No experiment plan printed."), file: file, line: line)
        XCTAssertFalse(formatted.contains("Manual experiment checklist:"), file: file, line: line)
        XCTAssertFalse(formatted.contains("Manual restore command:"), file: file, line: line)
    }

    private func manualPlan(relativeArchivePath: String, gameInstall: GameInstall) -> String {
        OfficialArchiveManualPlanFormatter.format(
            manager.preflight(relativeArchivePath: relativeArchivePath, gameInstall: gameInstall)
        )
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

    private func backupMetadataSnapshot() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: home.officialArchiveBackupsURL.path),
              let enumerator = FileManager.default.enumerator(
                  at: home.officialArchiveBackupsURL,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              )
        else {
            return [:]
        }

        var snapshot: [String: String] = [:]
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = try PathSafety.relativePath(of: url, in: home.officialArchiveBackupsURL)
            snapshot[relativePath] = try PathSafety.sha256(url: url)
        }
        return snapshot
    }
}
