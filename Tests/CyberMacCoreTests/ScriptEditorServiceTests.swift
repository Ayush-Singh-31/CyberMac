import Foundation
import XCTest
@testable import CyberMacCore

final class ScriptEditorServiceTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var manifestStore: ManifestStore!
    private var service: ScriptEditorService!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacScriptEditorTests-\(UUID().uuidString)", isDirectory: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        manifestStore = ManifestStore(home: home)
        service = ScriptEditorService(home: home)
        try home.bootstrap()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testListsOnlyRedsFilesInsideInstalledMod() throws {
        let id = "redburrito"
        let script = scriptURL(id: id, relativePath: "nested/RedBurrito.reds")
        let text = scriptURL(id: id, relativePath: "notes.txt")
        let backup = scriptURL(id: id, relativePath: "RedBurrito.reds.bak.20260513-153012")
        let hidden = scriptURL(id: id, relativePath: ".hidden.reds")
        try write("script", to: script)
        try write("notes", to: text)
        try write("backup", to: backup)
        try write("hidden", to: hidden)
        try saveManifest(id: id, installedPaths: [script, text, backup, hidden])

        let files = try service.listEditableScripts(modID: id)

        XCTAssertEqual(files.map(\.relativePath), ["nested/RedBurrito.reds"])
    }

    func testLoadReadsUtf8Script() throws {
        let id = "load-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        let contents = "public class LoadMod {}\n"
        try write(contents, to: script)
        try saveManifest(id: id, installedPaths: [script])

        XCTAssertEqual(try service.loadScript(modID: id, relativePath: "main.reds"), contents)
    }

    func testSaveCreatesTimestampedBackup() throws {
        let id = "backup-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        try write("original", to: script)
        try saveManifest(id: id, installedPaths: [script])

        let result = try service.saveScript(modID: id, relativePath: "main.reds", contents: "edited")
        let backupURL = URL(fileURLWithPath: result.backupPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), "original")
        XCTAssertNotNil(backupURL.lastPathComponent.range(of: #"^main\.reds\.bak\.\d{8}-\d{6}$"#, options: .regularExpression))
    }

    func testSaveWritesNewContents() throws {
        let id = "write-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        try write("original", to: script)
        try saveManifest(id: id, installedPaths: [script])

        _ = try service.saveScript(modID: id, relativePath: "main.reds", contents: "edited")

        XCTAssertEqual(try String(contentsOf: script, encoding: .utf8), "edited")
    }

    func testSaveMarksActivationOutOfSync() throws {
        let id = "state-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        try write("original", to: script)
        try saveManifest(id: id, installedPaths: [script])
        try StateStore(home: home).save(CyberMacState(
            activationState: .active,
            activeModIDs: [id],
            pendingExpectedHashes: ["/tmp/final.redscripts": "hash"]
        ))

        _ = try service.saveScript(modID: id, relativePath: "main.reds", contents: "edited")
        let state = try StateStore(home: home).loadValidated()

        XCTAssertEqual(state.activationState, .outOfSync)
        XCTAssertTrue(state.pendingExpectedHashes.isEmpty)
    }

    func testRejectsFileOutsideOverlay() throws {
        let id = "escape-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        try write("script", to: script)
        try saveManifest(id: id, installedPaths: [script])

        XCTAssertThrowsError(try service.loadScript(modID: id, relativePath: "../../outside.reds")) { error in
            guard case ScriptEditorError.fileOutsideOverlay = error else {
                XCTFail("Expected fileOutsideOverlay, got \(error)")
                return
            }
        }
    }

    func testRejectsUnsupportedExtension() throws {
        let id = "extension-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        try write("script", to: script)
        try saveManifest(id: id, installedPaths: [script])

        XCTAssertThrowsError(try service.loadScript(modID: id, relativePath: "notes.txt")) { error in
            guard case ScriptEditorError.unsupportedExtension = error else {
                XCTFail("Expected unsupportedExtension, got \(error)")
                return
            }
        }
    }

    func testRejectsLargeFile() throws {
        let id = "large-mod"
        let script = scriptURL(id: id, relativePath: "main.reds")
        let large = String(repeating: "a", count: ScriptEditorService.maxScriptBytes + 1)
        try write(large, to: script)
        try saveManifest(id: id, installedPaths: [script])

        XCTAssertThrowsError(try service.loadScript(modID: id, relativePath: "main.reds")) { error in
            guard case ScriptEditorError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
        XCTAssertThrowsError(try service.saveScript(modID: id, relativePath: "main.reds", contents: large)) { error in
            guard case ScriptEditorError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
    }

    func testRejectsSymlinkEscapingOverlay() throws {
        let id = "symlink-mod"
        let link = scriptURL(id: id, relativePath: "link.reds")
        let outside = tempDir.appendingPathComponent("outside.reds")
        try write("outside", to: outside)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        } catch {
            throw XCTSkip("Symlink creation is unavailable in this environment: \(error)")
        }
        try saveManifest(id: id, installedPaths: [link])

        XCTAssertThrowsError(try service.loadScript(modID: id, relativePath: "link.reds")) { error in
            guard case ScriptEditorError.fileOutsideOverlay = error else {
                XCTFail("Expected fileOutsideOverlay, got \(error)")
                return
            }
        }
        XCTAssertThrowsError(try service.saveScript(modID: id, relativePath: "link.reds", contents: "edited")) { error in
            guard case ScriptEditorError.fileOutsideOverlay = error else {
                XCTFail("Expected fileOutsideOverlay, got \(error)")
                return
            }
        }
    }

    func testDoesNotTouchBundlePaths() throws {
        let id = "bundle-mod"
        let bundlePath = "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/scripts/main.reds"
        try saveManifest(id: id, records: [
            InstalledFileRecord(sourceInArchive: "r6/scripts/main.reds", installedPath: bundlePath, sizeBytes: 0, sha256: "")
        ])

        XCTAssertTrue(try service.listEditableScripts(modID: id).isEmpty)
        XCTAssertThrowsError(try service.loadScript(modID: id, relativePath: bundlePath)) { error in
            guard case ScriptEditorError.fileOutsideOverlay = error else {
                XCTFail("Expected fileOutsideOverlay, got \(error)")
                return
            }
        }
        XCTAssertThrowsError(try service.saveScript(modID: id, relativePath: bundlePath, contents: "edited")) { error in
            guard case ScriptEditorError.fileOutsideOverlay = error else {
                XCTFail("Expected fileOutsideOverlay, got \(error)")
                return
            }
        }
    }

    private func scriptURL(id: String, relativePath: String) -> URL {
        home.overlayScriptsURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(relativePath)
    }

    private func saveManifest(id: String, installedPaths: [URL]) throws {
        let records = try installedPaths.map { url in
            InstalledFileRecord(
                sourceInArchive: "r6/scripts/\(url.lastPathComponent)",
                installedPath: url.path,
                sizeBytes: FileManager.default.fileExists(atPath: url.path) ? try PathSafety.fileSize(url: url) : 0,
                sha256: FileManager.default.fileExists(atPath: url.path) ? try PathSafety.sha256(url: url) : ""
            )
        }
        try saveManifest(id: id, records: records)
    }

    private func saveManifest(id: String, records: [InstalledFileRecord]) throws {
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscript,
            status: .enabled,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077.app",
            installMode: "sidecar_overlay",
            installedFiles: records,
            detectedDependencies: ["redscript"],
            compatibilityStatus: .supported
        )
        try manifestStore.save(manifest)
    }

    private func write(_ string: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}
