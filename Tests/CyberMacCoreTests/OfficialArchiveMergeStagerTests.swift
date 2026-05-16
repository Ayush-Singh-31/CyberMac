import Foundation
import XCTest
@testable import CyberMacCore

final class OfficialArchiveMergeStagerTests: XCTestCase {
    private let relativeArchivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
    private let matchedAssetPath = "base/ui/melee_hud.inkwidget"
    private let secondMatchedAssetPath = "base/ui/melee_hint.inkwidget"
    private let unmatchedAssetPath = "base/ui/mod_only.inkwidget"

    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var backupManager: OfficialArchiveBackupManager!
    private var cp77toolsURL: URL!
    private var modArchiveURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacOfficialArchiveMergeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        backupManager = OfficialArchiveBackupManager(home: home)
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("out", isDirectory: true),
            withIntermediateDirectories: true
        )
        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
        try "#!/bin/sh\nexit 0\n".write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)
        modArchiveURL = tempDir.appendingPathComponent("aa_MeleeHUD.archive")
        try "mod archive".write(to: modArchiveURL, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRejectsNonOfficialArchivePath() throws {
        let game = try makeGameInstall()
        let request = makeRequest(relativeArchivePath: "Data/archive/Mac/mod/bad.archive")

        XCTAssertThrowsError(try makeStager().stage(request: request, gameInstall: game))
    }

    func testRejectsMissingBackup() throws {
        let game = try makeGameInstall()

        XCTAssertThrowsError(try makeStager().stage(request: makeRequest(), gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("No matching CyberMac official archive backup exists"))
        }
    }

    func testRejectsModifiedCurrentArchive() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        try "modified archive".write(to: archiveURL(gameInstall: game), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try makeStager().stage(request: makeRequest(), gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("MODIFIED"))
        }
    }

    func testRejectsMissingModArchive() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let missingModArchiveURL = tempDir.appendingPathComponent("missing.archive")

        XCTAssertThrowsError(
            try makeStager().stage(
                request: makeRequest(modArchiveURL: missingModArchiveURL),
                gameInstall: game
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("Mod archive does not exist"))
        }
    }

    func testHandlesNoExactMatchesWithoutCreatingOutput() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let outputURL = tempDir.appendingPathComponent("out/no-matches.archive")
        let tooling = FakeArchiveMergeTooling(filesByArchivePath: [
            archiveURL(gameInstall: game).path: [
                matchedAssetPath: "official original"
            ],
            modArchiveURL.path: [
                unmatchedAssetPath: "mod replacement"
            ]
        ])

        XCTAssertThrowsError(
            try makeStager(tooling: tooling).stage(
                request: makeRequest(outputArchiveURL: outputURL),
                gameInstall: game
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("No exact path matches"))
        }
        XCTAssertFalse(tooling.didPack)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testReplacesExactPathMatches() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveMergeTooling(filesByArchivePath: [
            archiveURL(gameInstall: game).path: [
                matchedAssetPath: "official original",
                secondMatchedAssetPath: "second official original",
                "base/ui/official_only.inkwidget": "official only"
            ],
            modArchiveURL.path: [
                matchedAssetPath: "mod replacement",
                secondMatchedAssetPath: "second mod replacement"
            ]
        ])
        let outputURL = tempDir.appendingPathComponent("out/staged-merge.archive")

        let result = try makeStager(tooling: tooling).stage(
            request: makeRequest(outputArchiveURL: outputURL),
            gameInstall: game
        )

        XCTAssertEqual(result.modFileCount, 2)
        XCTAssertEqual(result.exactMatchCount, 2)
        XCTAssertEqual(result.replacements.map(\.assetPath), [secondMatchedAssetPath, matchedAssetPath])
        XCTAssertEqual(result.replacements[0].originalSHA256, PathSafety.sha256(string: "second official original"))
        XCTAssertEqual(result.replacements[0].replacementSHA256, PathSafety.sha256(string: "second mod replacement"))
        XCTAssertEqual(tooling.packedFiles[matchedAssetPath], "mod replacement")
        XCTAssertEqual(tooling.packedFiles[secondMatchedAssetPath], "second mod replacement")
        XCTAssertEqual(tooling.packedFiles["base/ui/official_only.inkwidget"], "official only")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(result.outputArchiveSHA256, try PathSafety.sha256(url: outputURL))
    }

    func testReportsUnmatchedFiles() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveMergeTooling(filesByArchivePath: [
            archiveURL(gameInstall: game).path: [
                matchedAssetPath: "official original"
            ],
            modArchiveURL.path: [
                matchedAssetPath: "mod replacement",
                unmatchedAssetPath: "mod only"
            ]
        ])

        let result = try makeStager(tooling: tooling).stage(
            request: makeRequest(),
            gameInstall: game
        )
        let formatted = OfficialArchiveMergeStageFormatter.format(result)

        XCTAssertEqual(result.unmatchedModAssetPaths, [unmatchedAssetPath])
        XCTAssertTrue(formatted.contains("Unmatched mod files:"))
        XCTAssertTrue(formatted.contains("- \(unmatchedAssetPath)"))
    }

    func testFormatterPrintsManualInstallCommand() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveMergeTooling(filesByArchivePath: [
            archiveURL(gameInstall: game).path: [
                matchedAssetPath: "official original"
            ],
            modArchiveURL.path: [
                matchedAssetPath: "mod replacement"
            ]
        ])
        let outputURL = tempDir.appendingPathComponent("out/manual-command.archive")

        let result = try makeStager(tooling: tooling).stage(
            request: makeRequest(outputArchiveURL: outputURL),
            gameInstall: game
        )
        let formatted = OfficialArchiveMergeStageFormatter.format(result)

        XCTAssertTrue(formatted.contains("Manual install command:"))
        XCTAssertTrue(formatted.contains("sudo cp \(PathSafety.shellQuoted(outputURL.path))"))
        XCTAssertTrue(formatted.contains(PathSafety.shellQuoted(archiveURL(gameInstall: game).path)))
    }

    func testFormatterPrintsStatusAndPreflightVerifyCommands() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveMergeTooling(filesByArchivePath: [
            archiveURL(gameInstall: game).path: [
                matchedAssetPath: "official original"
            ],
            modArchiveURL.path: [
                matchedAssetPath: "mod replacement"
            ]
        ])

        let result = try makeStager(tooling: tooling).stage(
            request: makeRequest(outputArchiveURL: tempDir.appendingPathComponent("out/verify-command.archive")),
            gameInstall: game
        )
        let formatted = OfficialArchiveMergeStageFormatter.format(result)

        XCTAssertTrue(formatted.contains("CyberMac verification commands:"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch status \(relativeArchivePath)"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch preflight \(relativeArchivePath)"))
    }

    private func makeStager(tooling: any OfficialArchiveSwapTooling = FakeArchiveMergeTooling()) -> OfficialArchiveMergeStager {
        OfficialArchiveMergeStager(home: home, tooling: tooling)
    }

    private func makeRequest(
        relativeArchivePath: String? = nil,
        modArchiveURL: URL? = nil,
        outputArchiveURL: URL? = nil
    ) -> OfficialArchiveMergeStageRequest {
        OfficialArchiveMergeStageRequest(
            relativeArchivePath: relativeArchivePath ?? self.relativeArchivePath,
            modArchiveURL: modArchiveURL ?? self.modArchiveURL,
            workDirectoryURL: tempDir.appendingPathComponent("work-\(UUID().uuidString)", isDirectory: true),
            outputArchiveURL: outputArchiveURL ?? tempDir.appendingPathComponent("out/staged-\(UUID().uuidString).archive"),
            cp77toolsURL: cp77toolsURL
        )
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077 Test.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        let archiveURL = archiveURL(contentsURL: contentsURL)
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "official archive".write(to: archiveURL, atomically: true, encoding: .utf8)
        try writeCodeResources(contentsURL: contentsURL)

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

    private func writeCodeResources(contentsURL: URL) throws {
        let codeSignatureURL = contentsURL.appendingPathComponent("_CodeSignature", isDirectory: true)
        try FileManager.default.createDirectory(at: codeSignatureURL, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "files2": [
                relativeArchivePath: ["hash": "fixture"]
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: codeSignatureURL.appendingPathComponent("CodeResources"), options: [.atomic])
    }

    private func archiveURL(gameInstall: GameInstall) -> URL {
        archiveURL(contentsURL: gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true))
    }

    private func archiveURL(contentsURL: URL) -> URL {
        relativeArchivePath.split(separator: "/").reduce(contentsURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}

private final class FakeArchiveMergeTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    private let filesByArchivePath: [String: [String: String]]
    private(set) var didPack = false
    private(set) var packedFiles: [String: String] = [:]

    init(filesByArchivePath: [String: [String: String]] = [:]) {
        self.filesByArchivePath = filesByArchivePath
    }

    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        for (assetPath, contents) in filesByArchivePath[sourceArchiveURL.path, default: [:]] {
            let url = assetPath
                .replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/")
                .reduce(outputDirectoryURL) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        didPack = true
        packedFiles = try files(under: extractedDirectoryURL)
        try FileManager.default.createDirectory(at: outputArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let packedSummary = packedFiles
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "\n")
        try packedSummary.write(to: outputArchiveURL, atomically: true, encoding: .utf8)
    }

    private func files(under rootURL: URL) throws -> [String: String] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return [:]
        }

        var result: [String: String] = [:]
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            result[relativePath] = try String(contentsOf: url, encoding: .utf8)
        }
        return result
    }
}
