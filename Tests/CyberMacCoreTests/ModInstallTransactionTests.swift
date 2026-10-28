import Foundation
import XCTest
@testable import CyberMacCore

final class ModInstallTransactionTests: XCTestCase {
    func testSystemInstallHistoryAcceptsMacAdminGroupPermissionsAndRejectsUntrustedWriters() {
        XCTAssertTrue(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 80, mode: 0o100664))
        XCTAssertTrue(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 0, mode: 0o100664))
        XCTAssertTrue(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 20, mode: 0o100644))
        XCTAssertFalse(ModInstallerPackage.trustedHistoryMetadata(owner: 501, group: 80, mode: 0o100664))
        XCTAssertFalse(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 20, mode: 0o100664))
        XCTAssertFalse(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 80, mode: 0o100666))
        XCTAssertFalse(ModInstallerPackage.trustedHistoryMetadata(owner: 0, group: 80, mode: 0o120664))
    }
    func testScriptOnlyPackageSuccessUsesExactIdentifierFromInstallerHistory() throws {
        let identifier = "com.cybermac.mod-files.test-unique-id"
        func history(_ ids: [String], process: String = "Installer") throws -> Data {
            try PropertyListSerialization.data(fromPropertyList: [["packageIdentifiers": ids, "processName": process]], format: .binary, options: 0)
        }
        XCTAssertTrue(ModInstallerPackage.successRecorded(identifier: identifier, history: try history([identifier])))
        XCTAssertFalse(ModInstallerPackage.successRecorded(identifier: identifier, history: try history([identifier + "-other"])))
        XCTAssertFalse(ModInstallerPackage.successRecorded(identifier: identifier, history: try history([identifier], process: "Other")))
        XCTAssertFalse(ModInstallerPackage.successRecorded(identifier: identifier, history: Data("invalid plist".utf8)))
    }
    private var root: URL!
    private var game: GameInstall!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("Install ' $() \(UUID().uuidString)")
        let app = root.appendingPathComponent("Fixture.app")
        let data = app.appendingPathComponent("Contents/Data")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        game = GameInstall(appURL: app, executableURL: app.appendingPathComponent("Contents/MacOS/FakeCP77"),
            dataURL: data, archiveMacURL: nil, r6URL: nil, storefront: .unknown, displayName: "Fixture")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testInstallAndRestoreMultipleFilesWithLiteralShellCharacters() throws {
        let files = try fixtures()
        let plan = try ModInstallTransaction(game: game, files: files)
        XCTAssertEqual(try run(plan, reportFailure: true), 0)
        XCTAssertNoThrow(try plan.verify())
        XCTAssertEqual(try run(plan.reversed(), reportFailure: true), 0)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
    }
    func testNativeInstallAndRestorePreserveSourcesBackupsAndOldInode() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let oldInode = root.appendingPathComponent("old-inode")
        try FileManager.default.linkItem(atPath: files[0].target, toPath: oldInode.path)
        try NativeModInstallTransaction(plan: plan).apply(replace: nativeReplace)
        XCTAssertNoThrow(try plan.verify())
        XCTAssertEqual(try PathSafety.sha256(url: oldInode), files[0].originalSHA256)
        for file in files {
            XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.source)), file.installedSHA256)
            XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.backup)), file.originalSHA256)
        }
        try NativeModInstallTransaction(plan: plan.reversed()).apply(replace: nativeReplace)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
        try assertNoNativePayloads()
    }
    func testNativePermissionDenialLeavesOriginalAndDoesNotAttemptRollback() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        var calls = 0
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan).apply { _, _ in
            calls += 1
            throw NSError(domain: NSPOSIXErrorDomain, code: 1)
        })
        XCTAssertEqual(calls, 1)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
        try assertNoNativePayloads()
    }
    func testNativeSecondFailureRollsBackFirstReplacement() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        var calls = 0
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan).apply { target, payload in
            calls += 1
            if calls == 2 { throw NSError(domain: NSPOSIXErrorDomain, code: 1) }
            try nativeReplace(target, payload)
        })
        XCTAssertEqual(calls, 3)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
        try assertNoNativePayloads()
    }
    func testNativeErrorAfterRenameStillRestoresOriginal() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        var calls = 0
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan).apply { target, payload in
            calls += 1
            try nativeReplace(target, payload)
            if calls == 1 { throw NSError(domain: NSPOSIXErrorDomain, code: 1) }
        })
        XCTAssertEqual(calls, 2)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
        try assertNoNativePayloads()
    }
    func testNativeFailedRecoveryKeepsBackupAndReportsUnverifiedState() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        var calls = 0
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan).apply { target, payload in
            calls += 1
            if calls > 1 { throw NSError(domain: NSPOSIXErrorDomain, code: 1) }
            try nativeReplace(target, payload)
        }) { error in
            XCTAssertTrue(String(describing: error).contains("Automatic recovery could not be verified"))
        }
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[0].backup)), files[0].originalSHA256)
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[1].target)), files[1].originalSHA256)
        try assertNoNativePayloads()
    }
    func testNativePreflightRechecksEveryFileAfterAuthorization() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let prepared = try NativeModInstallTransaction(plan: plan)
        try Data("external change".utf8).write(to: URL(fileURLWithPath: files[1].source))
        var calls = 0
        XCTAssertThrowsError(try prepared.apply { _, _ in calls += 1 })
        XCTAssertEqual(calls, 0)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
    }
    func testNativePreflightRejectsSymlinkAndCorruptBackup() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let saved = root.appendingPathComponent("saved-original")
        try FileManager.default.moveItem(atPath: files[0].target, toPath: saved.path)
        try FileManager.default.createSymbolicLink(atPath: files[0].target, withDestinationPath: saved.path)
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan))
        try FileManager.default.removeItem(atPath: files[0].target)
        try FileManager.default.moveItem(at: saved, to: URL(fileURLWithPath: files[0].target))
        try Data("bad backup".utf8).write(to: URL(fileURLWithPath: files[1].backup))
        XCTAssertThrowsError(try NativeModInstallTransaction(plan: plan))
    }
    func testNativePreflightRejectsRedirectedParentAfterAuthorization() throws {
        var files = try fixtures()
        let original = root.appendingPathComponent("source 0")
        let alias = root.appendingPathComponent("source-alias")
        let folder = root.appendingPathComponent("other-source")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.copyItem(at: original, to: folder.appendingPathComponent(original.lastPathComponent))
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        files[0] = .init(source: alias.appendingPathComponent(original.lastPathComponent).path,
            target: files[0].target, backup: files[0].backup,
            originalSHA256: files[0].originalSHA256, installedSHA256: files[0].installedSHA256)
        let prepared = try NativeModInstallTransaction(plan: ModInstallTransaction(game: game, files: files))
        try FileManager.default.removeItem(at: alias)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
        var calls = 0
        XCTAssertThrowsError(try prepared.apply { _, _ in calls += 1 })
        XCTAssertEqual(calls, 0)
    }
    func testInstallerPackageContainsOnlyPlannedFilesAndChecksBeforePlacement() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let package = try ModInstallerPackage.build(plan: plan, under: root.appendingPathComponent("packages"))
        try package.verifyPackage()
        let expanded = root.appendingPathComponent("expanded")
        _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/sbin/pkgutil"),
            arguments: ["--expand-full", package.url.path, expanded.path], timeoutSeconds: 30)
        let payload = expanded.appendingPathComponent("Payload"), scripts = expanded.appendingPathComponent("Scripts")
        let payloadFiles = FileManager.default.enumerator(at: payload, includingPropertiesForKeys: [.isRegularFileKey])!
        var actualFiles: [String] = []
        while let url = payloadFiles.nextObject() as? URL {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                actualFiles.append(try PathSafety.relativePath(of: url, in: payload))
            }
        }
        XCTAssertEqual(Set(actualFiles), Set(files.map { String($0.target.dropFirst()) }))
        let runner = ProcessRunner(), shell = URL(fileURLWithPath: "/bin/sh")
        XCTAssertEqual(try runner.run(executableURL: shell, arguments: [scripts.appendingPathComponent("preinstall").path, package.url.path, "/", "/"], timeoutSeconds: 10).exitCode, 0)
        for file in files {
            XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256)
            let staged = payload.appendingPathComponent(String(file.target.dropFirst()))
            XCTAssertEqual(try PathSafety.sha256(url: staged), file.installedSHA256)
            let clone = root.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: staged, to: clone)
            try nativeReplace(URL(fileURLWithPath: file.target), clone)
        }
        XCTAssertEqual(try runner.run(executableURL: shell, arguments: [scripts.appendingPathComponent("postinstall").path, package.url.path, "/", "/"], timeoutSeconds: 10).exitCode, 0)
        XCTAssertNoThrow(try plan.verify())
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.backup)), file.originalSHA256) }
    }
    func testInstallerPackageRejectsChangedTargetAndChangedPackage() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let package = try ModInstallerPackage.build(plan: plan, under: root.appendingPathComponent("packages"))
        try Data("external change".utf8).write(to: URL(fileURLWithPath: files[1].target))
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: [package.directory.appendingPathComponent("Scripts/preinstall").path, package.url.path, "/", "/"], timeoutSeconds: 10, allowFailure: true)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[0].target)), files[0].originalSHA256)
        try Data("changed package".utf8).write(to: package.url)
        XCTAssertThrowsError(try package.verifyPackage())
    }
    func testLargeArchiveInstallBuildsTinyPackageWithoutCopyingArchiveIntoPayload() throws {
        var files = try fixtures()
        let invalid = try ModInstallTransaction(game: game, files: files)
        let source = try FileHandle(forWritingTo: URL(fileURLWithPath: files[0].source))
        try source.truncate(atOffset: PathSafety.maxArchiveBytes + 1)
        try source.close()
        XCTAssertThrowsError(try ModInstallerPackage.build(plan: invalid, under: root.appendingPathComponent("rejected-packages")))
        let first = files[0]
        files[0] = .init(source: first.source, target: first.target, backup: first.backup, originalSHA256: first.originalSHA256,
                         installedSHA256: try PathSafety.sha256(url: URL(fileURLWithPath: first.source)))
        let plan = try ModInstallTransaction(game: game, files: files)
        let package = try ModInstallerPackage.build(plan: plan, under: root.appendingPathComponent("packages"))
        XCTAssertLessThan(try PathSafety.fileSize(url: package.url), 1024 * 1024)
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.directory.appendingPathComponent("Payload").path))
        XCTAssertEqual(try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-n", package.directory.appendingPathComponent("Scripts/postinstall").path], timeoutSeconds: 5).exitCode, 0)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
    }
    private func nativeReplace(_ target: URL, _ payload: URL) throws {
        _ = try FileManager.default.replaceItemAt(target, withItemAt: payload, backupItemName: nil, options: [])
    }
    private func assertNoNativePayloads() throws {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            XCTAssertFalse(url.lastPathComponent.hasPrefix(".cybermac-place."), url.path)
        }
    }
    func testChangedSecondTargetLeavesEveryTargetUntouched() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        try Data("external change".utf8).write(to: URL(fileURLWithPath: files[1].target))
        XCTAssertNotEqual(try run(plan), 0)
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[0].target)), files[0].originalSHA256)
        XCTAssertEqual(try String(contentsOfFile: files[1].target, encoding: .utf8), "external change")
    }
    func testCorruptBackupPreventsAnyGameWrite() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        try Data("corrupt".utf8).write(to: URL(fileURLWithPath: files[1].backup))
        XCTAssertNotEqual(try run(plan), 0)
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[0].target)), files[0].originalSHA256)
    }
    func testSecondPlacementFailureRollsBackFirst() throws {
        var files = try fixtures()
        let folder = root.appendingPathComponent("read-only")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appendingPathComponent("payload")
        try FileManager.default.copyItem(atPath: files[1].source, toPath: source.path)
        files[1] = .init(source: source.path, target: files[1].target, backup: files[1].backup,
            originalSHA256: files[1].originalSHA256, installedSHA256: files[1].installedSHA256)
        let plan = try ModInstallTransaction(game: game, files: files)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        XCTAssertNotEqual(try run(plan), 0)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
    }
    func testDeniedFirstReplacementDoesNotReportFailedRollbackForUnchangedFile() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let folder = URL(fileURLWithPath: files[0].target).deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", plan.command(requiresAdministrator: false)], timeoutSeconds: 10, allowFailure: true)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.stderr.contains("Automatic rollback failed"), result.stderr)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
    }
    func testPreflightChecksFilesWithoutReplacingThem() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let runner = ProcessRunner(), shell = URL(fileURLWithPath: "/bin/sh")
        XCTAssertEqual(try runner.run(executableURL: shell, arguments: ["-c", plan.preflightCommand()], timeoutSeconds: 10).exitCode, 0)
        for file in files { XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256) }
        try Data("external change".utf8).write(to: URL(fileURLWithPath: files[1].target))
        XCTAssertNotEqual(try runner.run(executableURL: shell, arguments: ["-c", plan.preflightCommand()], timeoutSeconds: 10, allowFailure: true).exitCode, 0)
        XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: files[0].target)), files[0].originalSHA256)
    }
    func testInvalidTargetAndDuplicateDestinationsAreRejected() throws {
        let files = try fixtures()
        XCTAssertThrowsError(try ModInstallTransaction(game: game, files: [files[0], files[0]]))
        let outside = ModInstallTransaction.File(source: files[0].source, target: root.appendingPathComponent("outside").path,
            backup: files[0].backup, originalSHA256: files[0].originalSHA256, installedSHA256: files[0].installedSHA256)
        XCTAssertThrowsError(try ModInstallTransaction(game: game, files: [outside]))
    }
    func testSymlinkTargetIsRefusedBeforeWrite() throws {
        let files = try fixtures(), plan = try ModInstallTransaction(game: game, files: files)
        let other = root.appendingPathComponent("other")
        try FileManager.default.moveItem(atPath: files[0].target, toPath: other.path)
        try FileManager.default.createSymbolicLink(atPath: files[0].target, withDestinationPath: other.path)
        XCTAssertNotEqual(try run(plan), 0)
        XCTAssertEqual(try PathSafety.sha256(url: other), files[0].originalSHA256)
    }
    private func fixtures() throws -> [ModInstallTransaction.File] {
        try ["r6/cache/final.redscripts", "r6/config/inputUserMappings.xml"].enumerated().map { index, relative in
            let source = root.appendingPathComponent("source \(index)"), backup = root.appendingPathComponent("backup \(index)")
            let target = game.dataURL.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("new \(index)".utf8).write(to: source)
            try Data("old \(index)".utf8).write(to: backup)
            try FileManager.default.copyItem(at: backup, to: target)
            return .init(source: source.path, target: target.path, backup: backup.path,
                originalSHA256: try PathSafety.sha256(url: backup), installedSHA256: try PathSafety.sha256(url: source))
        }
    }
    private func run(_ plan: ModInstallTransaction, reportFailure: Bool = false) throws -> Int32 {
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", plan.command(requiresAdministrator: false)], timeoutSeconds: 10, allowFailure: true)
        if reportFailure { XCTAssertEqual(result.exitCode, 0, result.stderr) }
        return result.exitCode
    }
}
