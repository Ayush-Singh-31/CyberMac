import Foundation
import XCTest
@testable import CyberMacCore

final class VisualReplacementPlannerTests: XCTestCase {
    private let relativeArchivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
    private let targetAssetPath = "base/ui/crosshair.xbm"
    private let otherAssetPath = "base/ui/other.xbm"

    private var tempDir: URL!
    private var catalogDir: URL!
    private var dbURL: URL!
    private var home: CyberMacHomeManager!
    private var cp77toolsURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacVisualReplacementTests-\(UUID().uuidString)", isDirectory: true)
        catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("out", isDirectory: true), withIntermediateDirectories: true)

        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
        try "#!/bin/sh\nexit 0\n".write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testPlanRejectsUnknownOfficialArchive() throws {
        try buildIndex(archivePath: relativeArchivePath, assetPaths: [targetAssetPath])
        let replacementURL = try writeFile("replacement.xbm", contents: "replacement texture")

        XCTAssertThrowsError(
            try makePlanReport(
                targetArchivePath: "Data/archive/Mac/content/not_in_index.archive",
                replacementFileURL: replacementURL
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("Target archive is not indexed"))
        }
    }

    func testPlanRejectsMissingTargetAsset() throws {
        try buildIndex(archivePath: relativeArchivePath, assetPaths: [otherAssetPath])
        let replacementURL = try writeFile("replacement.xbm", contents: "replacement texture")

        XCTAssertThrowsError(try makePlanReport(replacementFileURL: replacementURL)) { error in
            XCTAssertTrue(String(describing: error).contains("Target asset is not indexed"))
        }
    }

    func testPlanRejectsMissingReplacementFile() throws {
        try buildIndex(archivePath: relativeArchivePath, assetPaths: [targetAssetPath])
        let missingReplacementURL = tempDir.appendingPathComponent("missing.xbm")

        XCTAssertThrowsError(try makePlanReport(replacementFileURL: missingReplacementURL)) { error in
            XCTAssertTrue(String(describing: error).contains("Replacement file does not exist"))
        }
    }

    func testPlanRejectsExtensionMismatch() throws {
        try buildIndex(archivePath: relativeArchivePath, assetPaths: [targetAssetPath])
        let replacementURL = try writeFile("replacement.mesh", contents: "replacement mesh")

        XCTAssertThrowsError(try makePlanReport(replacementFileURL: replacementURL)) { error in
            XCTAssertTrue(String(describing: error).contains("Replacement extension must match"))
        }
    }

    func testPlanWritesDeterministicJSONWithTargetAndReplacementMetadata() throws {
        try buildIndex(archivePath: relativeArchivePath, assetPaths: [targetAssetPath])
        let previewURL = try writeFile("preview.png", contents: "png")
        _ = try AssetPreviewRegistry().register(options: AssetPreviewRegisterOptions(
            databaseURL: dbURL,
            archivePath: relativeArchivePath,
            assetPath: targetAssetPath,
            previewURL: previewURL,
            kind: AssetPreviewKind.textureThumbnail,
            sourceTool: AssetPreviewSourceTool.cybermacXBMPreviewExport
        ))
        let replacementURL = try writeFile("replacement.xbm", contents: "replacement texture")
        let firstPlanURL = tempDir.appendingPathComponent("plan-a.json")
        let secondPlanURL = tempDir.appendingPathComponent("plan-b.json")

        let firstReport = try makePlanReport(replacementFileURL: replacementURL, outputPlanURL: firstPlanURL)
        let secondReport = try makePlanReport(replacementFileURL: replacementURL, outputPlanURL: secondPlanURL)

        XCTAssertEqual(try String(contentsOf: firstPlanURL, encoding: .utf8), try String(contentsOf: secondPlanURL, encoding: .utf8))
        XCTAssertEqual(firstReport.plan, secondReport.plan)
        XCTAssertEqual(firstReport.plan.target.archivePath, relativeArchivePath)
        XCTAssertEqual(firstReport.plan.target.assetPath, targetAssetPath)
        XCTAssertEqual(firstReport.plan.target.assetExtension, "xbm")
        XCTAssertEqual(firstReport.plan.target.category, "ui")
        XCTAssertEqual(firstReport.plan.target.previewCount, 1)
        XCTAssertEqual(firstReport.plan.target.firstPreviewPath, previewURL.standardizedFileURL.path)
        XCTAssertEqual(firstReport.plan.replacement.sha256, try PathSafety.sha256(url: replacementURL))
        XCTAssertEqual(firstReport.plan.replacement.sizeBytes, try PathSafety.fileSize(url: replacementURL))

        let formatted = VisualReplacementPlanFormatter.format(firstReport)
        XCTAssertTrue(formatted.contains("Target archive: \(relativeArchivePath)"))
        XCTAssertTrue(formatted.contains("Target preview count: 1"))
        XCTAssertTrue(formatted.contains("Replacement SHA-256: \(try PathSafety.sha256(url: replacementURL))"))
        XCTAssertTrue(formatted.contains("No archive was patched or installed."))
    }

    func testStageReplacesOneExactFileAndDoesNotMutateSourceArchive() throws {
        let game = try makeGameInstall()
        let backup = try OfficialArchiveBackupManager(home: home).backup(
            relativeArchivePath: relativeArchivePath,
            gameInstall: game
        )
        let sourceArchiveURL = archiveURL(gameInstall: game)
        let sourceSHABefore = try PathSafety.sha256(url: sourceArchiveURL)
        let replacementURL = try writeFile("replacement.xbm", contents: "replacement texture")
        let planURL = try writePlan(replacementFileURL: replacementURL)
        let tooling = FakeVisualReplacementTooling(filesByArchivePath: [
            sourceArchiveURL.path: [
                targetAssetPath: "original texture",
                otherAssetPath: "other texture"
            ]
        ])
        let outputArchiveURL = tempDir.appendingPathComponent("out/staged.archive")

        let result = try makeStager(tooling: tooling).stage(request: makeStageRequest(
            planURL: planURL,
            sourceArchiveURL: sourceArchiveURL,
            outputArchiveURL: outputArchiveURL
        ))

        XCTAssertEqual(tooling.packedFiles[targetAssetPath], "replacement texture")
        XCTAssertEqual(tooling.packedFiles[otherAssetPath], "other texture")
        XCTAssertEqual(result.originalAssetSHA256, PathSafety.sha256(string: "original texture"))
        XCTAssertEqual(result.replacementSHA256, PathSafety.sha256(string: "replacement texture"))
        XCTAssertEqual(result.outputArchivePath, outputArchiveURL.path)
        XCTAssertEqual(result.outputArchiveSHA256, try PathSafety.sha256(url: outputArchiveURL))
        XCTAssertEqual(sourceSHABefore, try PathSafety.sha256(url: sourceArchiveURL))

        let formatted = VisualReplacementStageFormatter.format(result)
        XCTAssertTrue(formatted.contains("Manual install command:"))
        XCTAssertTrue(formatted.contains("sudo cp \(PathSafety.shellQuoted(outputArchiveURL.path))"))
        XCTAssertTrue(formatted.contains(PathSafety.shellQuoted(sourceArchiveURL.path)))
        XCTAssertTrue(formatted.contains("CyberMac status/preflight commands:"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch status \(relativeArchivePath)"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch preflight \(relativeArchivePath)"))
        XCTAssertTrue(formatted.contains("swift run cybermac archive-patch restore-official \(backup.backupID) --dry-run"))
    }

    func testStageRefusesTraversalPathsInPlan() throws {
        let sourceArchiveURL = try writeFile("basegame_1_engine.archive", contents: "source archive")
        let replacementURL = try writeFile("replacement.xbm", contents: "replacement texture")
        let maliciousPlan = VisualReplacementPlan(
            target: VisualReplacementPlanTarget(
                archivePath: relativeArchivePath,
                assetPath: "../crosshair.xbm",
                assetExtension: "xbm",
                category: "ui",
                previewCount: 0,
                firstPreviewPath: nil
            ),
            replacement: VisualReplacementPlanReplacement(
                filePath: replacementURL.path,
                fileExtension: "xbm",
                sha256: try PathSafety.sha256(url: replacementURL),
                sizeBytes: try PathSafety.fileSize(url: replacementURL)
            ),
            workDirectoryPath: tempDir.appendingPathComponent("planned-work", isDirectory: true).path,
            databasePath: dbURL.path
        )
        let planURL = tempDir.appendingPathComponent("malicious-plan.json")
        try JSONEncoder.cybermac.encode(maliciousPlan).write(to: planURL, options: [.atomic])

        XCTAssertThrowsError(
            try makeStager().stage(request: makeStageRequest(planURL: planURL, sourceArchiveURL: sourceArchiveURL))
        ) { error in
            XCTAssertTrue(String(describing: error).contains("traversal"))
        }
    }

    private func makePlanReport(
        targetArchivePath: String? = nil,
        targetAssetPath: String? = nil,
        replacementFileURL: URL,
        outputPlanURL: URL? = nil
    ) throws -> VisualReplacementPlanReport {
        try VisualReplacementPlanner().plan(request: VisualReplacementPlanRequest(
            targetArchivePath: targetArchivePath ?? relativeArchivePath,
            targetAssetPath: targetAssetPath ?? self.targetAssetPath,
            replacementFileURL: replacementFileURL,
            workDirectoryURL: tempDir.appendingPathComponent("planned-work", isDirectory: true),
            outputPlanURL: outputPlanURL ?? tempDir.appendingPathComponent("plan.json"),
            databaseURL: dbURL
        ))
    }

    private func makeStager(tooling: any OfficialArchiveSwapTooling = FakeVisualReplacementTooling()) -> VisualReplacementStager {
        VisualReplacementStager(home: home, tooling: tooling, stageIDProvider: { "test-stage-\(UUID().uuidString)" })
    }

    private func makeStageRequest(
        planURL: URL,
        sourceArchiveURL: URL,
        outputArchiveURL: URL? = nil
    ) -> VisualReplacementStageRequest {
        VisualReplacementStageRequest(
            planURL: planURL,
            sourceArchiveURL: sourceArchiveURL,
            workDirectoryURL: tempDir.appendingPathComponent("stage-work", isDirectory: true),
            outputArchiveURL: outputArchiveURL ?? tempDir.appendingPathComponent("out/staged-\(UUID().uuidString).archive"),
            cp77toolsURL: cp77toolsURL
        )
    }

    private func writePlan(replacementFileURL: URL) throws -> URL {
        let plan = VisualReplacementPlan(
            target: VisualReplacementPlanTarget(
                archivePath: relativeArchivePath,
                assetPath: targetAssetPath,
                assetExtension: "xbm",
                category: "ui",
                previewCount: 0,
                firstPreviewPath: nil
            ),
            replacement: VisualReplacementPlanReplacement(
                filePath: replacementFileURL.path,
                fileExtension: "xbm",
                sha256: try PathSafety.sha256(url: replacementFileURL),
                sizeBytes: try PathSafety.fileSize(url: replacementFileURL)
            ),
            workDirectoryPath: tempDir.appendingPathComponent("planned-work", isDirectory: true).path,
            databasePath: dbURL.path
        )
        let planURL = tempDir.appendingPathComponent("stage-plan.json")
        try JSONEncoder.cybermac.encode(plan).write(to: planURL, options: [.atomic])
        return planURL
    }

    private func buildIndex(archivePath: String, assetPaths: [String]) throws {
        let catalogURL = catalogDir.appendingPathComponent(archivePath.replacingOccurrences(of: "/", with: "_") + ".txt")
        try FileManager.default.createDirectory(at: catalogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try assetPaths.joined(separator: "\n").write(to: catalogURL, atomically: true, encoding: .utf8)
        _ = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))
    }

    private func writeFile(_ relativePath: String, contents: String) throws -> URL {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
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

private final class FakeVisualReplacementTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    private let filesByArchivePath: [String: [String: String]]
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
