import Foundation
import XCTest
@testable import CyberMacCore

final class GameSessionLogRecorderTests: XCTestCase {
    private var root: URL!
    private var home: CyberMacHomeManager!
    private var game: GameInstall!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CyberMac session tests \(UUID().uuidString)")
        home = CyberMacHomeManager(homeURL: root.appendingPathComponent("home"))
        let app = root.appendingPathComponent("Game.app"), contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": "2.5.0", "CFBundleVersion": "fixture-build"], format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        game = GameInstall(appURL: app, executableURL: contents.appendingPathComponent("MacOS/Game"), dataURL: contents.appendingPathComponent("Data"), archiveMacURL: contents.appendingPathComponent("Data/archive/Mac"), r6URL: nil, storefront: .macAppStore, displayName: "Fixture")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testStreamsDataAndPersistsActualOutcome() throws {
        let recorder = fixture("printf 'game-event\\n'; printf 'source-note' >&2")
        _ = try recorder.start(game: game)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.gameBuild, "fixture-build")
        XCTAssertEqual(try contents(result), "game-event\n")
        XCTAssertEqual(result.capturedBytes, "game-event\n".utf8.count)
        XCTAssertEqual(try recorder.recent().first?.status, .completed)
        XCTAssertTrue(result.limitations.contains { $0.contains("no internal engine instrumentation") })
    }

    func testByteLimitStopsSourceAndKeepsOutputBounded() throws {
        let recorder = fixture("printf '012345678901234567890123456789'; exec /bin/sleep 10", limit: 16)
        _ = try recorder.start(game: game)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .sizeLimitReached)
        XCTAssertEqual(result.capturedBytes, 16)
        XCTAssertEqual(try contents(result), "0123456789012345")
        XCTAssertThrowsError(try recorder.addMarker("after limit"))
    }

    func testCaptureContinuesBeyondPreviousTenMiBLimitAndReportRemainsReadable() throws {
        let count = 11_000_000
        let recorder = GameSessionLogRecorder(home: home,
            command: (URL(fileURLWithPath: "/usr/bin/head"), ["-c", String(count), "/dev/zero"]),
            byteLimit: GameSessionLogRecorder.maximumBytes)
        _ = try recorder.start(game: game)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.capturedBytes, count)
        XCTAssertEqual(try PathSafety.fileSize(url: URL(fileURLWithPath: result.folderPath).appendingPathComponent("capture.log")), UInt64(count))
        XCTAssertEqual(try recorder.recent().first?.capturedBytes, count)
    }

    func testFailureRetainsSourceErrorAndDoesNotReportEmptySuccess() throws {
        let recorder = fixture("printf 'permission denied by source' >&2; exit 7")
        _ = try recorder.start(game: game)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.error?.contains("permission denied by source") == true)
        XCTAssertEqual(try recorder.recent().first?.status, .failed)
    }

    func testSizeLimitForcesSourceThatIgnoresTerminationToStop() throws {
        let recorder = fixture("trap '' TERM; printf '01234567890123456789'; exec /bin/sleep 10", limit: 16)
        _ = try recorder.start(game: game)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .sizeLimitReached)
        XCTAssertEqual(result.capturedBytes, 16)
        XCTAssertFalse(recorder.isRecording)
    }

    func testStopDrainsMarkersAndReleasesCaptureLock() throws {
        let first = fixture("exec /bin/sleep 10")
        XCTAssertThrowsError(try first.addMarker("not started"))
        _ = try first.start(game: game)
        let second = fixture("printf 'next-session'")
        XCTAssertThrowsError(try second.start(game: game))
        XCTAssertThrowsError(try first.start(game: game))
        XCTAssertThrowsError(try first.addMarker("multiple\nlines"))
        try first.addMarker("equipped Lucy jacket")
        let stopped = try XCTUnwrap(first.stop())
        XCTAssertEqual(stopped.status, .stopped)
        XCTAssertTrue(try contents(stopped).contains("equipped Lucy jacket"))
        XCTAssertFalse(first.isRecording)
        _ = try second.start(game: game)
        XCTAssertEqual(try finished(second).status, .completed)
    }

    func testFailedLaunchReleasesLockAndPersistsFailure() throws {
        let missing = GameSessionLogRecorder(home: home, command: (root.appendingPathComponent("missing-executable"), []), byteLimit: 1024)
        XCTAssertThrowsError(try missing.start(game: game))
        XCTAssertFalse(missing.isRecording)
        XCTAssertEqual(missing.snapshot()?.status, .failed)
        let next = fixture("printf 'recovered'")
        _ = try next.start(game: game)
        XCTAssertEqual(try finished(next).status, .completed)
    }

    func testRetentionRemovesOnlyOldManagedSessions() throws {
        let unrelated = home.logsURL.appendingPathComponent("game-sessions/user-notes")
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        var ids: [String] = []
        let recorder = fixture("printf 'event'")
        for _ in 0..<5 {
            ids.append(try recorder.start(game: game).id)
            _ = try finished(recorder)
        }
        let recent = try recorder.recent()
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(Set(recent.map(\.id)), Set(ids.suffix(3)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testDurationAndGameMetadataAreValidatedBeforeCreatingSession() throws {
        let recorder = fixture("printf 'event'")
        XCTAssertThrowsError(try recorder.start(game: game, seconds: 0))
        XCTAssertThrowsError(try recorder.start(game: game, seconds: 3601))
        try Data("invalid plist".utf8).write(to: game.appURL.appendingPathComponent("Contents/Info.plist"))
        XCTAssertThrowsError(try recorder.start(game: game))
        XCTAssertTrue(try recorder.recent().isEmpty)
    }

    func testInvalidStoredReportIsAnErrorAndDoesNotPruneEvidence() throws {
        let recorder = fixture("printf 'keep-this-evidence'")
        _ = try recorder.start(game: game)
        let report = try finished(recorder)
        let metadata = URL(fileURLWithPath: report.folderPath).appendingPathComponent("report.json")
        try Data(repeating: 65, count: 65_537).write(to: metadata)
        XCTAssertThrowsError(try recorder.recent())
        XCTAssertThrowsError(try recorder.start(game: game))
        XCTAssertEqual(try contents(report), "keep-this-evidence")
    }

    func testRealMacOSLogSourceCompletesBoundedCapture() throws {
        let recorder = GameSessionLogRecorder(home: home)
        _ = try recorder.start(game: game, seconds: 1)
        let result = try finished(recorder)
        XCTAssertEqual(result.status, .completed, result.error ?? "")
        XCTAssertLessThanOrEqual(result.capturedBytes, GameSessionLogRecorder.maximumBytes)
        XCTAssertEqual(try recorder.recent().first?.status, .completed)
    }

    private func fixture(_ script: String, limit: Int = 1024 * 1024) -> GameSessionLogRecorder {
        GameSessionLogRecorder(home: home, command: (URL(fileURLWithPath: "/bin/sh"), ["-c", script]), byteLimit: limit)
    }
    private func finished(_ recorder: GameSessionLogRecorder) throws -> GameSessionLogReport {
        let deadline = Date().addingTimeInterval(6)
        while recorder.isRecording && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        if recorder.isRecording { _ = recorder.stop(); XCTFail("Capture did not finish before deadline") }
        return try XCTUnwrap(recorder.snapshot())
    }
    private func contents(_ report: GameSessionLogReport) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: report.folderPath).appendingPathComponent("capture.log"), encoding: .utf8)
    }
}
