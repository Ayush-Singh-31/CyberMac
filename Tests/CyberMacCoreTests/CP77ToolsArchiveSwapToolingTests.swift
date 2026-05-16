import Foundation
import XCTest
@testable import CyberMacCore

final class CP77ToolsArchiveSwapToolingTests: XCTestCase {
    private var tempDir: URL!
    private var cp77toolsURL: URL!
    private var argvLogURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacCP77ToolsArchiveSwapToolingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        argvLogURL = tempDir.appendingPathComponent("argv.log")
        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testExtractArgumentsHaveExpectedShape() {
        let archiveURL = URL(fileURLWithPath: "/tmp/mod/aa_MeleeHUD.archive")
        let outDir = URL(fileURLWithPath: "/tmp/work/mod", isDirectory: true)

        let args = CP77ToolsArchiveSwapTooling.extractArguments(
            sourceArchiveURL: archiveURL,
            outputDirectoryURL: outDir
        )

        XCTAssertEqual(args, ["unbundle", "/tmp/mod/aa_MeleeHUD.archive", "--outpath", "/tmp/work/mod"])
    }

    func testPackArgumentsHaveExpectedShape() {
        let extractedDir = URL(fileURLWithPath: "/tmp/work/official", isDirectory: true)
        let outDir = URL(fileURLWithPath: "/tmp/work/packed", isDirectory: true)

        let args = CP77ToolsArchiveSwapTooling.packArguments(
            extractedDirectoryURL: extractedDir,
            outputDirectoryURL: outDir
        )

        XCTAssertEqual(args, ["pack", "/tmp/work/official", "--outpath", "/tmp/work/packed"])
    }

    func testExtractInvokesCp77ToolsWithExpectedArgv() throws {
        try writeArgvCaptureScript(exitCode: 0)
        let archiveURL = tempDir.appendingPathComponent("mod.archive")
        try "mod".write(to: archiveURL, atomically: true, encoding: .utf8)
        let outDir = tempDir.appendingPathComponent("mod-out", isDirectory: true)

        try CP77ToolsArchiveSwapTooling().extractArchive(
            cp77toolsURL: cp77toolsURL,
            sourceArchiveURL: archiveURL,
            outputDirectoryURL: outDir
        )

        let argv = try capturedArgv()
        XCTAssertEqual(argv, [
            "unbundle",
            archiveURL.path,
            "--outpath",
            outDir.path
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outDir.path))
    }

    func testPackInvokesCp77ToolsWithExpectedArgv() throws {
        try writeArgvCaptureScript(exitCode: 0)
        let extractedDir = tempDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        let outputArchive = tempDir.appendingPathComponent("packed/out.archive")

        try CP77ToolsArchiveSwapTooling().packArchive(
            cp77toolsURL: cp77toolsURL,
            extractedDirectoryURL: extractedDir,
            outputArchiveURL: outputArchive
        )

        let argv = try capturedArgv()
        XCTAssertEqual(argv, [
            "pack",
            extractedDir.path,
            "--outpath",
            outputArchive.deletingLastPathComponent().path
        ])
    }

    func testExtractFailurePropagatesArgvStdoutAndStderr() throws {
        try writeFailingScript(
            stdout: "scanning aa_MeleeHUD.archive",
            stderr: "fatal: header mismatch",
            exitCode: 128
        )
        let archiveURL = tempDir.appendingPathComponent("mod.archive")
        try "mod".write(to: archiveURL, atomically: true, encoding: .utf8)
        let outDir = tempDir.appendingPathComponent("mod-out", isDirectory: true)

        XCTAssertThrowsError(
            try CP77ToolsArchiveSwapTooling().extractArchive(
                cp77toolsURL: cp77toolsURL,
                sourceArchiveURL: archiveURL,
                outputDirectoryURL: outDir
            )
        ) { error in
            let description = String(describing: error)
            XCTAssertTrue(description.contains("exited with 128"), description)
            XCTAssertTrue(description.contains("unbundle"), description)
            XCTAssertTrue(description.contains(archiveURL.path), description)
            XCTAssertTrue(description.contains("--outpath"), description)
            XCTAssertTrue(description.contains(outDir.path), description)
            XCTAssertTrue(description.contains("argv:"), description)
            XCTAssertTrue(description.contains("[unbundle]"), description)
            XCTAssertTrue(description.contains("stdout:"), description)
            XCTAssertTrue(description.contains("scanning aa_MeleeHUD.archive"), description)
            XCTAssertTrue(description.contains("stderr:"), description)
            XCTAssertTrue(description.contains("fatal: header mismatch"), description)
        }
    }

    func testDisplayCommandShellQuotesPathsForReporting() {
        let executable = URL(fileURLWithPath: "/Applications/Path With Spaces/cp77tools")
        let archive = "/Users/test/mods/aa MeleeHUD.archive"
        let outDir = "/Users/test/work/mod"

        let display = CP77ToolsErrorFormatter.displayCommand(
            executable: executable,
            arguments: ["unbundle", archive, "--outpath", outDir]
        )

        XCTAssertEqual(
            display,
            "'/Applications/Path With Spaces/cp77tools' 'unbundle' '/Users/test/mods/aa MeleeHUD.archive' '--outpath' '/Users/test/work/mod'"
        )
    }

    private func capturedArgv() throws -> [String] {
        let raw = try String(contentsOf: argvLogURL, encoding: .utf8)
        return raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .dropLast() // trailing newline produces an empty trailing element
            .map { $0 }
    }

    private func writeArgvCaptureScript(exitCode: Int) throws {
        let script = """
        #!/bin/sh
        : > \(PathSafety.shellQuoted(argvLogURL.path))
        for arg in "$@"; do
            printf '%s\\n' "$arg" >> \(PathSafety.shellQuoted(argvLogURL.path))
        done
        exit \(exitCode)
        """
        try script.write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)
    }

    private func writeFailingScript(stdout: String, stderr: String, exitCode: Int) throws {
        let script = """
        #!/bin/sh
        printf '%s\\n' \(PathSafety.shellQuoted(stdout))
        printf '%s\\n' \(PathSafety.shellQuoted(stderr)) 1>&2
        exit \(exitCode)
        """
        try script.write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)
    }
}
