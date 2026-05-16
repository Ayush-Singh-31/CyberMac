import Foundation
import XCTest
@testable import CyberMacCore

final class OfficialArchiveSwapStagerTests: XCTestCase {
    private let relativeArchivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
    private let targetAssetPath = "base/ui/crosshair.xbm"
    private let donorAssetPath = "base/ui/menu_icon.xbm"

    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var backupManager: OfficialArchiveBackupManager!
    private var cp77toolsURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacOfficialArchiveSwapTests-\(UUID().uuidString)", isDirectory: true)
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

    func testRejectsMissingTargetAsset() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveSwapTooling(extractedFiles: [
            donorAssetPath: "donor"
        ])

        XCTAssertThrowsError(try makeStager(tooling: tooling).stage(request: makeRequest(), gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("Target asset does not exist"))
        }
    }

    func testRejectsMissingDonorAsset() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveSwapTooling(extractedFiles: [
            targetAssetPath: "target"
        ])

        XCTAssertThrowsError(try makeStager(tooling: tooling).stage(request: makeRequest(), gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("Donor asset does not exist"))
        }
    }

    func testRejectsExtensionMismatch() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let request = makeRequest(donorAssetPath: "base/ui/menu_icon.mesh")

        XCTAssertThrowsError(try makeStager().stage(request: request, gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("extensions must match"))
        }
    }

    func testProducesStagedOutputInFakeToolMode() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveSwapTooling(extractedFiles: [
            targetAssetPath: "target original",
            donorAssetPath: "donor replacement"
        ])
        let outputURL = tempDir.appendingPathComponent("out/staged.archive")
        let request = makeRequest(outputArchiveURL: outputURL)

        let result = try makeStager(tooling: tooling).stage(request: request, gameInstall: game)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(result.targetOriginalSHA256, PathSafety.sha256(string: "target original"))
        XCTAssertEqual(result.donorSHA256, PathSafety.sha256(string: "donor replacement"))
        XCTAssertEqual(result.outputArchivePath, outputURL.path)
        XCTAssertEqual(result.outputArchiveSHA256, try PathSafety.sha256(url: outputURL))
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "packed archive")
    }

    func testFormatterPrintsManualInstallAndVerifyCommands() throws {
        let game = try makeGameInstall()
        _ = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        let tooling = FakeArchiveSwapTooling(extractedFiles: [
            targetAssetPath: "target original",
            donorAssetPath: "donor replacement"
        ])
        let outputURL = tempDir.appendingPathComponent("out/staged.archive")

        let result = try makeStager(tooling: tooling).stage(
            request: makeRequest(outputArchiveURL: outputURL),
            gameInstall: game
        )
        let formatted = OfficialArchiveSwapStageFormatter.format(result)

        XCTAssertTrue(formatted.contains("Manual install command:"))
        XCTAssertTrue(formatted.contains("sudo cp \(PathSafety.shellQuoted(outputURL.path))"))
        XCTAssertTrue(formatted.contains(PathSafety.shellQuoted(archiveURL(gameInstall: game).path)))
        XCTAssertTrue(formatted.contains("Verification command:"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch status \(relativeArchivePath)"))
    }

    private func makeStager(tooling: any OfficialArchiveSwapTooling = FakeArchiveSwapTooling()) -> OfficialArchiveSwapStager {
        OfficialArchiveSwapStager(
            home: home,
            tooling: tooling,
            stageIDProvider: { "test-stage" }
        )
    }

    private func makeRequest(
        relativeArchivePath: String? = nil,
        targetAssetPath: String? = nil,
        donorAssetPath: String? = nil,
        outputArchiveURL: URL? = nil
    ) -> OfficialArchiveSwapStageRequest {
        OfficialArchiveSwapStageRequest(
            relativeArchivePath: relativeArchivePath ?? self.relativeArchivePath,
            targetAssetPath: targetAssetPath ?? self.targetAssetPath,
            donorAssetPath: donorAssetPath ?? self.donorAssetPath,
            workDirectoryURL: tempDir.appendingPathComponent("work", isDirectory: true),
            outputArchiveURL: outputArchiveURL ?? tempDir.appendingPathComponent("out/staged.archive"),
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

private final class FakeArchiveSwapTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    private let extractedFiles: [String: String]

    init(extractedFiles: [String: String] = [:]) {
        self.extractedFiles = extractedFiles
    }

    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        for (assetPath, contents) in extractedFiles {
            let normalizedAssetPath = assetPath.replacingOccurrences(of: "\\", with: "/")
            let url = normalizedAssetPath.split(separator: "/").reduce(outputDirectoryURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        try FileManager.default.createDirectory(at: outputArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "packed archive".write(to: outputArchiveURL, atomically: true, encoding: .utf8)
    }
}
