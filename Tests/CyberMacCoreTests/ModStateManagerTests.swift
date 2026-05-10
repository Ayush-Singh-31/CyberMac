import Foundation
import XCTest
@testable import CyberMacCore

final class ModStateManagerTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var manifestStore: ManifestStore!
    private var manager: ModStateManager!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacStateTests-\(UUID().uuidString)", isDirectory: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        manifestStore = ManifestStore(home: home)
        manager = ModStateManager(home: home)
        try home.bootstrap()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDisableEnableAndUninstallOperateOnlyOnManifestFiles() throws {
        let id = "managed-mod"
        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let managedURL = enabledRoot.appendingPathComponent("nested/main.reds")
        let untrackedURL = enabledRoot.appendingPathComponent("untracked.reds")
        try write("managed", to: managedURL)
        try write("user file", to: untrackedURL)
        try saveManifest(id: id, status: .enabled, installedPath: managedURL.path)

        var manifest = try manager.disable(id: id)

        let disabledURL = home.disabledURL.appendingPathComponent(id, isDirectory: true).appendingPathComponent("nested/main.reds")
        XCTAssertEqual(manifest.status, .disabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: disabledURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untrackedURL.path))

        manifest = try manager.enable(id: id)

        XCTAssertEqual(manifest.status, .enabled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disabledURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untrackedURL.path))

        manifest = try manager.uninstall(id: id)

        XCTAssertEqual(manifest.status, .uninstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untrackedURL.path))
    }

    func testDisableFailsWhenManifestFileIsMissingAndDoesNotFlipStatus() throws {
        let id = "missing-mod"
        let missingURL = home.overlayScriptsURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("main.reds")
        try saveManifest(id: id, status: .enabled, installedPath: missingURL.path)

        XCTAssertThrowsError(try manager.disable(id: id))
        XCTAssertEqual(try manifestStore.load(id: id).status, .enabled)
    }

    private func saveManifest(id: String, status: InstalledModStatus, installedPath: String) throws {
        let record = InstalledFileRecord(
            sourceInArchive: "r6/scripts/main.reds",
            installedPath: installedPath,
            sizeBytes: 0,
            sha256: ""
        )
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscript,
            status: status,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077.app",
            installMode: "sidecar_overlay",
            installedFiles: [record],
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
