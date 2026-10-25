import Foundation
import XCTest
@testable import CyberMacCore

final class StandaloneClothingRestoreTests: XCTestCase {
    private struct Fixture {
        let root: URL
        let files: [StandaloneClothingPreparer.File]
        let auxiliary: URL
        let source: String
        let environment: [String: String]
        let hashLog: URL

        func run(replaceBeforePlacement: Bool = false) throws -> ProcessResult {
            var env = environment
            if replaceBeforePlacement { env["CYBERMAC_TEST_REPLACE_TARGET"] = files[0].target }
            return try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-c", source],
                environment: env, timeoutSeconds: 10, allowFailure: true)
        }
    }

    private func fixture(originalStates: [Bool]) throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Restore ' $() \(UUID().uuidString)")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let executable = root.appendingPathComponent("game"), scripts = root.appendingPathComponent("scripts")
        try Data("fixture executable".utf8).write(to: executable)
        try Data("fixture scripts".utf8).write(to: scripts)
        let auxiliary = root.appendingPathComponent("auxiliary.redscripts")
        try Data("fixture helper".utf8).write(to: auxiliary)
        var files: [StandaloneClothingPreparer.File] = []
        for (index, original) in originalStates.enumerated() {
            let target = root.appendingPathComponent("game-\(index).archive")
            let backup = root.appendingPathComponent("original-\(index).archive")
            let originalData = Data("original \(index)".utf8), stagedData = Data("staged \(index)".utf8)
            try originalData.write(to: backup)
            try (original ? originalData : stagedData).write(to: target)
            files.append(.init(target: target.path, original: backup.path,
                originalSHA256: PathSafety.sha256(data: originalData), staged: root.appendingPathComponent("absent-\(index)").path,
                stagedSHA256: PathSafety.sha256(data: stagedData)))
        }
        let fakeSudo = bin.appendingPathComponent("sudo")
        let sudoSource = #"""
#!/bin/sh
if [ "$1" = '-v' ]; then
  if [ -n "${CYBERMAC_TEST_REPLACE_TARGET:-}" ]; then
    printf '%s' 'intervening change' > "$CYBERMAC_TEST_REPLACE_TARGET.next"
    /bin/mv "$CYBERMAC_TEST_REPLACE_TARGET.next" "$CYBERMAC_TEST_REPLACE_TARGET"
  fi
  exit 0
fi
if [ "$1" = '/usr/sbin/chown' ]; then exit 0; fi
exec "$@"
"""#
        let hasher = bin.appendingPathComponent("count-hashes")
        try Data(sudoSource.utf8).write(to: fakeSudo)
        try Data("#!/bin/sh\nprintf '%s\\n' \"$4\" >> \"$CYBERMAC_TEST_HASH_LOG\"\nexec /usr/bin/openssl \"$@\"\n".utf8).write(to: hasher)
        for file in [fakeSudo, hasher] { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path) }
        let source = StandaloneClothingPreparer.restoreScript(files: files, executable: executable, scripts: scripts,
            auxiliary: auxiliary, compiledSHA: try PathSafety.sha256(url: auxiliary))
            .replacingOccurrences(of: EquipProbePreparer.executableSHA, with: try PathSafety.sha256(url: executable))
            .replacingOccurrences(of: EquipProbePreparer.originalSHA, with: try PathSafety.sha256(url: scripts))
            .replacingOccurrences(of: "/usr/bin/pgrep -x Cyberpunk2077", with: "/bin/sh -c 'exit 1'")
            .replacingOccurrences(of: "/usr/bin/openssl", with: "\"$CYBERMAC_TEST_HASHER\"")
        let hashLog = root.appendingPathComponent("hashes.txt")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = bin.path + ":/usr/bin:/bin"
        environment["CYBERMAC_TEST_HASHER"] = hasher.path
        environment["CYBERMAC_TEST_HASH_LOG"] = hashLog.path
        return Fixture(root: root, files: files, auxiliary: auxiliary, source: source, environment: environment, hashLog: hashLog)
    }

    func testMixedRecoveryRestoresAndReadsCurrentContentOnlyOnceBeforePlacement() throws {
        let f = try fixture(originalStates: [false, true, false, true])
        defer { try? FileManager.default.removeItem(at: f.root) }
        let result = try f.run()
        XCTAssertEqual(result.exitCode, 0, result.stderr)
        let hashes = try String(contentsOf: f.hashLog, encoding: .utf8).split(separator: "\n").map(String.init)
        for (index, file) in f.files.enumerated() {
            XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.originalSHA256)
            // Changed targets get one preflight hash and one post-placement hash.
            XCTAssertEqual(hashes.filter { $0 == file.target }.count, index.isMultiple(of: 2) ? 2 : 1)
            XCTAssertEqual(hashes.filter { $0 == file.original }.count, index.isMultiple(of: 2) ? 1 : 0)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.auxiliary.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: f.root.path).contains { $0.hasPrefix(".cybermac-place.") })
    }

    func testAlreadyOriginalNeedsNeitherRestoreCopiesNorAdministrator() throws {
        let f = try fixture(originalStates: [true, true, true, true])
        defer { try? FileManager.default.removeItem(at: f.root) }
        for file in f.files { try FileManager.default.removeItem(atPath: file.original) }
        try FileManager.default.removeItem(at: f.auxiliary)
        // A sudo call would fail even if it were merely a credential refresh.
        try Data("#!/bin/sh\nexit 97\n".utf8).write(to: f.root.appendingPathComponent("bin/sudo"))
        let result = try f.run()
        XCTAssertEqual(result.exitCode, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("You can close this window"))
    }

    func testUnknownCurrentFileOrBadRestoreCopyStopsBeforeAnyReplacement() throws {
        for corruptBackup in [false, true] {
            let f = try fixture(originalStates: [false, false, false, false])
            defer { try? FileManager.default.removeItem(at: f.root) }
            let corrupted = corruptBackup ? f.files[2].original : f.files[2].target
            try Data("unexpected".utf8).write(to: URL(fileURLWithPath: corrupted))
            let before = try f.files.map { try Data(contentsOf: URL(fileURLWithPath: $0.target)) }
            let result = try f.run()
            XCTAssertNotEqual(result.exitCode, 0)
            XCTAssertEqual(try f.files.map { try Data(contentsOf: URL(fileURLWithPath: $0.target)) }, before)
            XCTAssertTrue(FileManager.default.fileExists(atPath: f.auxiliary.path))
        }
    }

    func testInterveningReplacementStopsRecoveryBeforeWrites() throws {
        let f = try fixture(originalStates: [false, false, false, false])
        defer { try? FileManager.default.removeItem(at: f.root) }
        let result = try f.run(replaceBeforePlacement: true)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("changed after verification"))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: f.files[0].target)), Data("intervening change".utf8))
        for file in f.files.dropFirst() {
            XCTAssertEqual(try PathSafety.sha256(url: URL(fileURLWithPath: file.target)), file.stagedSHA256)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.auxiliary.path))
    }
}
