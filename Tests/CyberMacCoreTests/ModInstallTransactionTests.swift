import Foundation
import XCTest
@testable import CyberMacCore

final class ModInstallTransactionTests: XCTestCase {
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
