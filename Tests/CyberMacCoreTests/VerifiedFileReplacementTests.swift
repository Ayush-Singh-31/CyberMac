import Foundation
import XCTest
@testable import CyberMacCore

final class VerifiedFileReplacementTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CyberMac placement 'tests' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testReplacementUsesRenameAndPreservesSourceAndOldInode() throws {
        let source = root.appendingPathComponent("source ' $().archive")
        let target = root.appendingPathComponent("game.archive")
        let oldInode = root.appendingPathComponent("old-inode.archive")
        try Data("replacement".utf8).write(to: source)
        try Data("original".utf8).write(to: target)
        try FileManager.default.linkItem(at: target, to: oldInode)
        XCTAssertEqual(try run(source, target, hash: PathSafety.sha256(url: source)), 0)
        XCTAssertEqual(try Data(contentsOf: target), Data("replacement".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("replacement".utf8))
        XCTAssertEqual(try Data(contentsOf: oldInode), Data("original".utf8))
        try assertNoTemporaryClones()
    }

    func testHashFailureLeavesDestinationAndSourceUnchanged() throws {
        let source = root.appendingPathComponent("source.archive"), target = root.appendingPathComponent("game.archive")
        try Data("replacement".utf8).write(to: source)
        try Data("original".utf8).write(to: target)
        XCTAssertNotEqual(try run(source, target, hash: String(repeating: "0", count: 64)), 0)
        XCTAssertEqual(try Data(contentsOf: target), Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("replacement".utf8))
        try assertNoTemporaryClones()
    }

    func testFailedCloneLeavesExistingDestinationIntact() throws {
        let source = root.appendingPathComponent("unreadable.archive"), target = root.appendingPathComponent("game.archive")
        try Data("replacement".utf8).write(to: source)
        let hash = try PathSafety.sha256(url: source)
        try Data("original".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: source.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: source.path) }
        XCTAssertNotEqual(try run(source, target, hash: hash), 0)
        XCTAssertEqual(try Data(contentsOf: target), Data("original".utf8))
        try assertNoTemporaryClones()
    }

    func testRecoveryCanPlaceMissingDestination() throws {
        let source = root.appendingPathComponent("backup.archive"), target = root.appendingPathComponent("missing.archive")
        try Data("original".utf8).write(to: source)
        XCTAssertEqual(try run(source, target, hash: PathSafety.sha256(url: source)), 0)
        XCTAssertEqual(try Data(contentsOf: target), try Data(contentsOf: source))
        try assertNoTemporaryClones()
    }

    func testSymlinkDestinationIsRejected() throws {
        let source = root.appendingPathComponent("source.archive"), target = root.appendingPathComponent("game.archive")
        let other = root.appendingPathComponent("other.archive")
        try Data("replacement".utf8).write(to: source)
        try Data("original".utf8).write(to: other)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: other)
        XCTAssertNotEqual(try run(source, target, hash: PathSafety.sha256(url: source)), 0)
        XCTAssertEqual(try Data(contentsOf: other), Data("original".utf8))
        try assertNoTemporaryClones()
    }

    private func run(_ source: URL, _ target: URL, hash: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", VerifiedFileReplacement.command(source: source.path, target: target.path, sha256: hash, requiresAdministrator: false)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private func assertNoTemporaryClones() throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".cybermac-place.") })
    }
}
