import CyberMacCore
import Darwin
import Foundation
import XCTest

final class ProcessRunnerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacProcessRunnerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    func testTimeoutDoesNotHangWhenDescendantKeepsPipeOpen() throws {
        let scriptURL = tempDir.appendingPathComponent("hold-pipe-open.sh")
        let childPIDURL = tempDir.appendingPathComponent("child.pid")
        let body = """
        #!/bin/sh
        ( trap '' TERM; while :; do echo child-output; sleep 1; done ) &
        echo $! > \(PathSafety.shellDoubleQuoted(childPIDURL.path))
        echo parent-start
        sleep 20
        """
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let completed = expectation(description: "ProcessRunner timeout returns")
        let errorBox = ErrorBox()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try ProcessRunner().run(
                    executableURL: scriptURL,
                    arguments: [],
                    timeoutSeconds: 0.2
                )
            } catch {
                errorBox.set(error)
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 3)
        killChildProcess(from: childPIDURL)

        let error = errorBox.value()

        guard let cyberMacError = error as? CyberMacError,
              case .processTimedOut = cyberMacError
        else {
            return XCTFail("Expected processTimedOut, got \(String(describing: error))")
        }
    }

    private func killChildProcess(from pidURL: URL) {
        guard let pidText = try? String(contentsOf: pidURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidText)
        else {
            return
        }
        Darwin.kill(pid, SIGKILL)
    }
}

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?

    func set(_ error: Error) {
        lock.lock()
        self.error = error
        lock.unlock()
    }

    func value() -> Error? {
        lock.lock()
        defer { lock.unlock() }
        return error
    }
}
