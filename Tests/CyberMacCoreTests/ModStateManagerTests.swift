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

        let disabledURL = home.disabledURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("nested/main.reds")
        XCTAssertEqual(manifest.status, .disabled)
        XCTAssertEqual(StateStore(home: home).load().activationState, .outOfSync)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: disabledURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untrackedURL.path))

        manifest = try manager.enable(id: id)

        XCTAssertEqual(manifest.status, .enabled)
        XCTAssertEqual(StateStore(home: home).load().activationState, .outOfSync)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disabledURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untrackedURL.path))

        manifest = try manager.uninstall(id: id)

        XCTAssertEqual(manifest.status, .uninstalled)
        XCTAssertEqual(StateStore(home: home).load().activationState, .outOfSync)
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

    func testDisableRollsBackPartialMoveWhenLaterFileFails() throws {
        let id = "rollback-mod"
        let enabledRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let first = enabledRoot.appendingPathComponent("first.reds")
        let second = enabledRoot.appendingPathComponent("second.reds")
        let disabledSecond = home.disabledURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("second.reds")
        try write("first", to: first)
        try write("second", to: second)
        try write("conflict", to: disabledSecond)
        try saveManifest(id: id, status: .enabled, installedPaths: [first.path, second.path])

        XCTAssertThrowsError(try manager.disable(id: id))

        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertEqual(try manifestStore.load(id: id).status, .enabled)
    }

    func testInputMappingFilesMoveWithModAndMarkInputOutOfSync() throws {
        let id = "input-mod"
        let scriptRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let inputRoot = home.overlayInputURL.appendingPathComponent(id, isDirectory: true)
        let script = scriptRoot.appendingPathComponent("main.reds")
        let input = inputRoot.appendingPathComponent("insanecyberdeck_input.xml")
        try write("script", to: script)
        try write("<bindings />", to: input)
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscriptInput,
            status: .enabled,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077.app",
            installMode: "sidecar_overlay",
            installedFiles: [
                InstalledFileRecord(sourceInArchive: "r6/scripts/main.reds", installedPath: script.path, sizeBytes: 0, sha256: "")
            ],
            inputMappingFiles: [
                InstalledFileRecord(sourceInArchive: "r6/input/insanecyberdeck_input.xml", installedPath: input.path, sizeBytes: 0, sha256: "")
            ],
            inputPatchState: .active,
            requiresInputMappingPatch: true,
            detectedDependencies: ["redscript", "input-mapping"],
            compatibilityStatus: .supported
        )
        try manifestStore.save(manifest)
        try StateStore(home: home).save(CyberMacState(activeInputPatchModIDs: [id], activeInputTargetHashes: ["/tmp/inputContexts_mac.xml": "hash"]))

        let disabled = try manager.disable(id: id)

        let disabledInput = home.disabledURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("input", isDirectory: true)
            .appendingPathComponent("insanecyberdeck_input.xml")
        XCTAssertEqual(disabled.inputPatchState, .outOfSync)
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: disabledInput.path))
        XCTAssertTrue(StateStore(home: home).load().activeInputPatchModIDs.isEmpty)
    }

    func testDeletePermanentlyRemovesManifestAndSidecarFiles() throws {
        let id = "delete-mod"
        let scriptRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let inputRoot = home.overlayInputURL.appendingPathComponent(id, isDirectory: true)
        let disabledRoot = home.disabledURL.appendingPathComponent(id, isDirectory: true)
        let script = scriptRoot.appendingPathComponent("nested/main.reds")
        let input = inputRoot.appendingPathComponent("bindings.xml")
        let disabledFile = disabledRoot.appendingPathComponent("scripts/old.reds")
        try write("script", to: script)
        try write("<bindings />", to: input)
        try write("disabled", to: disabledFile)
        try saveInputManifest(id: id, status: .enabled, scriptPath: script.path, inputPath: input.path)

        let result = try manager.deletePermanently(id: id)

        XCTAssertEqual(result.modID, id)
        XCTAssertTrue(result.deletedPaths.contains(scriptRoot.path))
        XCTAssertTrue(result.deletedPaths.contains(inputRoot.path))
        XCTAssertTrue(result.deletedPaths.contains(disabledRoot.path))
        XCTAssertTrue(result.deletedPaths.contains(manifestStore.manifestURL(id: id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: scriptRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: inputRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disabledRoot.path))
        XCTAssertThrowsError(try manifestStore.load(id: id))
    }

    func testDeletePermanentlyRefusesPathsOutsideCyberMacHome() throws {
        let id = "unsafe-delete-mod"
        let safeRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let safeScript = safeRoot.appendingPathComponent("main.reds")
        let outside = tempDir.appendingPathComponent("outside.reds")
        try write("safe", to: safeScript)
        try write("outside", to: outside)
        try saveManifest(id: id, status: .enabled, installedPath: outside.path)

        XCTAssertThrowsError(try manager.deletePermanently(id: id)) { error in
            guard case CyberMacError.unsafePath = error else {
                XCTFail("Expected unsafePath, got \(error)")
                return
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: safeScript.path))
        XCTAssertNoThrow(try manifestStore.load(id: id))
    }

    func testDeletePermanentlyMarksActivationOutOfSyncWhenNeeded() throws {
        let id = "activated-delete-mod"
        let scriptRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let script = scriptRoot.appendingPathComponent("main.reds")
        try write("script", to: script)
        try saveManifest(id: id, status: .enabled, installedPath: script.path)
        try StateStore(home: home).save(CyberMacState(
            activationState: .active,
            activeModIDs: [id],
            pendingExpectedHashes: ["/tmp/final.redscripts": "hash"],
            pendingActivation: PendingActivation(
                createdAt: Date(),
                gameAppPath: "/Applications/Cyberpunk 2077.app",
                bundleTarget: "/tmp/final.redscripts",
                tempOutputPath: "/tmp/generated.redscripts",
                backupID: "backup",
                baseCacheSnapshotID: "snapshot",
                activeModIDs: [id],
                expectedHashes: ["/tmp/final.redscripts": "hash"]
            )
        ))

        let result = try manager.deletePermanently(id: id)
        let state = StateStore(home: home).load()

        XCTAssertTrue(result.activationMarkedOutOfSync)
        XCTAssertEqual(state.activationState, .outOfSync)
        XCTAssertNil(state.pendingActivation)
        XCTAssertTrue(state.pendingExpectedHashes.isEmpty)
    }

    func testDeletePermanentlyHandlesInputMappingFiles() throws {
        let id = "delete-input-mod"
        let otherID = "other-input-mod"
        let script = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true).appendingPathComponent("main.reds")
        let input = home.overlayInputURL.appendingPathComponent(id, isDirectory: true).appendingPathComponent("bindings.xml")
        let otherScript = home.overlayScriptsURL.appendingPathComponent(otherID, isDirectory: true).appendingPathComponent("main.reds")
        let otherInput = home.overlayInputURL.appendingPathComponent(otherID, isDirectory: true).appendingPathComponent("bindings.xml")
        try write("script", to: script)
        try write("<bindings />", to: input)
        try write("other", to: otherScript)
        try write("<bindings />", to: otherInput)
        try saveInputManifest(id: id, status: .disabled, scriptPath: script.path, inputPath: input.path)
        try saveInputManifest(id: otherID, status: .enabled, scriptPath: otherScript.path, inputPath: otherInput.path, inputPatchState: .active)
        try StateStore(home: home).save(CyberMacState(
            pendingInputPatch: PendingInputPatch(
                id: "patch",
                createdAt: Date(),
                gameAppPath: "/Applications/Cyberpunk 2077.app",
                modIDs: [id, otherID],
                targetHashes: ["/tmp/inputContexts.xml": "hash"],
                generatedFiles: ["/tmp/inputContexts.xml": "/tmp/generated.xml"],
                backupID: "backup",
                sudoCommands: []
            ),
            activeInputPatchModIDs: [id, otherID],
            activeInputTargetHashes: ["/tmp/inputContexts.xml": "hash"]
        ))

        let result = try manager.deletePermanently(id: id)
        let state = StateStore(home: home).load()

        XCTAssertTrue(result.inputPatchMarkedOutOfSync)
        XCTAssertThrowsError(try manifestStore.load(id: id))
        XCTAssertNil(state.pendingInputPatch)
        XCTAssertTrue(state.activeInputPatchModIDs.isEmpty)
        XCTAssertEqual(try manifestStore.load(id: otherID).inputPatchState, .outOfSync)
    }

    func testDeletePermanentlyNoopsCleanlyForMissingFilesButExistingManifest() throws {
        let id = "missing-delete-mod"
        let missingScript = home.overlayScriptsURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("main.reds")
        try saveManifest(id: id, status: .enabled, installedPath: missingScript.path)

        let result = try manager.deletePermanently(id: id)

        XCTAssertEqual(result.modID, id)
        XCTAssertFalse(result.missingPaths.isEmpty)
        XCTAssertThrowsError(try manifestStore.load(id: id))
    }

    private func saveManifest(id: String, status: InstalledModStatus, installedPath: String) throws {
        try saveManifest(id: id, status: status, installedPaths: [installedPath])
    }

    private func saveManifest(id: String, status: InstalledModStatus, installedPaths: [String]) throws {
        let record = InstalledFileRecord(
            sourceInArchive: "r6/scripts/main.reds",
            installedPath: installedPaths[0],
            sizeBytes: 0,
            sha256: ""
        )
        let records = installedPaths.enumerated().map { index, path in
            InstalledFileRecord(
                sourceInArchive: "r6/scripts/file\(index).reds",
                installedPath: path,
                sizeBytes: 0,
                sha256: ""
            )
        }
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscript,
            status: status,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077.app",
            installMode: "sidecar_overlay",
            installedFiles: installedPaths.count == 1 ? [record] : records,
            detectedDependencies: ["redscript"],
            compatibilityStatus: .supported
        )
        try manifestStore.save(manifest)
    }

    private func saveInputManifest(
        id: String,
        status: InstalledModStatus,
        scriptPath: String,
        inputPath: String,
        inputPatchState: InputPatchState = .required
    ) throws {
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscriptInput,
            status: status,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077.app",
            installMode: "sidecar_overlay",
            installedFiles: [
                InstalledFileRecord(sourceInArchive: "r6/scripts/main.reds", installedPath: scriptPath, sizeBytes: 0, sha256: "")
            ],
            inputMappingFiles: [
                InstalledFileRecord(sourceInArchive: "r6/input/bindings.xml", installedPath: inputPath, sizeBytes: 0, sha256: "")
            ],
            inputPatchState: inputPatchState,
            requiresInputMappingPatch: true,
            detectedDependencies: ["redscript", "input-mapping"],
            compatibilityStatus: .supported
        )
        try manifestStore.save(manifest)
    }

    private func write(_ string: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}
