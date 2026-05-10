import Foundation
import XCTest
@testable import CyberMacCore

final class ActivationPipelineTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacActivationTests-\(UUID().uuidString)", isDirectory: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        try home.bootstrap()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBaseCacheRefreshStoresMetadataAndCopiesDisposableMirror() throws {
        let game = try makeGameApp(cacheContents: "vanilla-cache")
        let manager = BaseCacheManager(home: home)

        let dryRun = try manager.refreshBaseCache(gameInstall: game, dryRun: true)
        XCTAssertFalse(dryRun.didWrite)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dryRun.snapshotURL.path))

        let result = try manager.refreshBaseCache(gameInstall: game, dryRun: false)
        XCTAssertTrue(result.didWrite)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.snapshotURL.path))
        XCTAssertEqual(result.metadata.bundleCacheSHA256, try PathSafety.sha256(url: manager.bundleCacheURL(gameInstall: game)))
        XCTAssertEqual(result.metadata.sizeBytes, UInt64("vanilla-cache".utf8.count))

        try write("old timestamp", to: home.overlayCacheURL.appendingPathComponent("final.redscripts.ts"))
        try write("old backup", to: home.overlayCacheURL.appendingPathComponent("final.redscripts.bk"))
        let mirror = try manager.copySnapshotToOverlay(snapshotID: result.snapshotID)
        XCTAssertEqual(try String(contentsOf: mirror, encoding: .utf8), "vanilla-cache")
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.overlayCacheURL.appendingPathComponent("final.redscripts.ts").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.overlayCacheURL.appendingPathComponent("final.redscripts.bk").path))
    }

    func testBaseCacheRefreshRefusesCurrentCyberMacGeneratedBundleCache() throws {
        let game = try makeGameApp(cacheContents: "generated-cache")
        let manager = BaseCacheManager(home: home)
        let target = manager.bundleCacheURL(gameInstall: game)
        let generatedHash = try PathSafety.sha256(url: target)
        try StateStore(home: home).save(CyberMacState(activeBundleTargetHashes: [target.path: generatedHash]))

        XCTAssertThrowsError(try manager.refreshBaseCache(gameInstall: game, dryRun: false)) { error in
            XCTAssertTrue(String(describing: error).contains("CyberMac-generated"))
        }
    }

    func testFingerprintCacheReusesMatchingTupleAndInvalidatesOnSizeChange() throws {
        let target = tempDir.appendingPathComponent("cache-target.bin")
        try write("abc", to: target)
        let store = FingerprintCacheStore(home: home)
        let fake = "cached-sha"
        try store.save(FingerprintCacheFile(entries: [
            target.path: FingerprintCacheEntry(
                path: target.path,
                sizeBytes: try PathSafety.fileSize(url: target),
                modificationTime: try PathSafety.modificationDate(url: target)?.timeIntervalSince1970,
                sha256: fake
            )
        ]))

        XCTAssertEqual(try store.sha256(url: target), fake)

        try write("abcd", to: target)
        XCTAssertEqual(try store.sha256(url: target), try PathSafety.sha256(url: target))
        XCTAssertNotEqual(try store.sha256(url: target), fake)
    }

    func testBundleBackupSupportsPresentAndAbsentPriorStateAndStaleRefusal() throws {
        let game = try makeGameApp(cacheContents: "vanilla-cache")
        let otherGame = try makeGameApp(name: "Other.app", cacheContents: "other-cache", executableContents: "different-exe")
        let baseManager = BaseCacheManager(home: home)
        let fingerprint = try baseManager.fingerprint(gameInstall: game)
        let backupManager = BundleBackupManager(home: home)

        let present = try backupManager.backup(gameInstall: game, fingerprintID: fingerprint.id)
        XCTAssertEqual(present.priorState, .present)
        XCTAssertEqual(present.sha256, try PathSafety.sha256(url: baseManager.bundleCacheURL(gameInstall: game)))
        XCTAssertTrue(try backupManager.restoreCommand(id: present.id, gameInstall: game).contains("sudo cp"))
        XCTAssertThrowsError(try backupManager.restoreCommand(id: present.id, gameInstall: otherGame)) { error in
            XCTAssertTrue(String(describing: error).contains("stale"))
        }

        try FileManager.default.removeItem(at: baseManager.bundleCacheURL(gameInstall: game))
        let absent = try backupManager.backup(gameInstall: game, fingerprintID: fingerprint.id)
        XCTAssertEqual(absent.priorState, .absent)
        XCTAssertNil(absent.sha256)
        XCTAssertTrue(try backupManager.restoreCommand(id: absent.id, gameInstall: game).contains("sudo rm -f"))
        XCTAssertTrue(try backupManager.verifyRestore(id: absent.id, gameInstall: game))
    }

    func testActivationDryRunBundleModeAndVerifyUseOnlyFinalRedscriptsBundleTarget() throws {
        let game = try makeGameApp(cacheContents: "vanilla-cache")
        try installFakeSCC()
        try saveEnabledManifest(id: "example_mod")
        let base = try BaseCacheManager(home: home).refreshBaseCache(gameInstall: game, dryRun: false)
        let manager = ActivationManager(home: home)

        let dryRun = try manager.dryRun(gameInstall: game)
        XCTAssertEqual(dryRun.baseSnapshotID, base.snapshotID)
        XCTAssertEqual(dryRun.enabledModIDs, ["example_mod"])
        XCTAssertTrue(dryRun.compileCommand.contains("-outputCacheFile"))
        XCTAssertTrue(dryRun.compileCommand.contains("\""))
        XCTAssertTrue(dryRun.sudoCommandShape.contains("/r6/cache/final.redscripts\""))
        XCTAssertFalse(dryRun.sudoCommandShape.contains("final.redscripts.ts"))
        XCTAssertFalse(dryRun.sudoCommandShape.contains("final.redscripts.bk"))
        XCTAssertFalse(dryRun.sudoCommandShape.contains("/r6/scripts/"))

        let activated = try manager.activateBundleMode(gameInstall: game)
        XCTAssertTrue(FileManager.default.fileExists(atPath: activated.tempOutputPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.overlayCacheURL.appendingPathComponent("final.redscripts.ts").path))
        XCTAssertTrue(activated.sudoCommand.contains("sudo cp"))
        XCTAssertFalse(activated.sudoCommand.contains("final.redscripts.ts"))
        XCTAssertFalse(activated.sudoCommand.contains("final.redscripts.bk"))
        XCTAssertFalse(activated.sudoCommand.contains("/r6/scripts/"))

        try FileManager.default.removeItem(at: BaseCacheManager(home: home).bundleCacheURL(gameInstall: game))
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: activated.tempOutputPath),
            to: BaseCacheManager(home: home).bundleCacheURL(gameInstall: game)
        )
        let verified = try manager.verify(gameInstall: game)
        XCTAssertTrue(verified.matched)
        let state = StateStore(home: home).load()
        XCTAssertEqual(state.activationState, .active)
        XCTAssertEqual(state.activeModIDs, ["example_mod"])
        XCTAssertEqual(state.activeBundleTargetHashes[BaseCacheManager(home: home).bundleCacheURL(gameInstall: game).path], activated.generatedSHA256)
    }

    func testActivationDryRunRefusesWhenBundleChangedFlagIsSet() throws {
        let game = try makeGameApp(cacheContents: "vanilla-cache")
        try installFakeSCC()
        _ = try BaseCacheManager(home: home).refreshBaseCache(gameInstall: game, dryRun: false)
        try StateStore(home: home).save(CyberMacState(bundleChangedSinceLastActivation: true))

        XCTAssertThrowsError(try ActivationManager(home: home).dryRun(gameInstall: game)) { error in
            XCTAssertTrue(String(describing: error).contains("Bundle changed"))
        }
    }

    func testActivationCompilerFailsForMissingMirrorAndTimesOut() throws {
        let game = try makeGameApp(cacheContents: "vanilla-cache")
        _ = game
        try installFakeSCC(mode: .sleeping)
        let output = home.tmpURL.appendingPathComponent("activation-timeout/final.redscripts")
        try FileManager.default.createDirectory(at: home.overlayScriptsURL, withIntermediateDirectories: true)
        try write("mirror", to: home.overlayCacheURL.appendingPathComponent("final.redscripts"))

        XCTAssertThrowsError(try ActivationCompiler(home: home).compile(outputURL: output, timeoutSeconds: 0.2)) { error in
            XCTAssertTrue(String(describing: error).contains(ActivationCompiler.timeoutMessage))
        }

        try FileManager.default.removeItem(at: home.overlayCacheURL.appendingPathComponent("final.redscripts"))
        try installFakeSCC()
        XCTAssertThrowsError(try ActivationCompiler(home: home).compile(outputURL: output, timeoutSeconds: 1)) { error in
            XCTAssertTrue(String(describing: error).contains("Overlay cache mirror missing"))
        }
    }

    private enum FakeSCCMode {
        case normal
        case sleeping
    }

    private func makeGameApp(
        name: String = "Cyberpunk 2077: Ultimate.app",
        cacheContents: String,
        executableContents: String = "game-executable"
    ) throws -> GameInstall {
        let app = tempDir.appendingPathComponent(name, isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let data = contents.appendingPathComponent("Data", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let receiptDir = contents.appendingPathComponent("_MASReceipt", isDirectory: true)
        let cache = data.appendingPathComponent("r6/cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: receiptDir, withIntermediateDirectories: true)
        let executable = macOS.appendingPathComponent("Cyberpunk2077")
        try write(executableContents, to: executable)
        try write("receipt-\(name)", to: receiptDir.appendingPathComponent("receipt"))
        try write(cacheContents, to: cache.appendingPathComponent("final.redscripts"))
        let plist: [String: String] = [
            "CFBundleIdentifier": "com.cdprojektred.cyberpunk2077",
            "CFBundleShortVersionString": "2.2",
            "CFBundleVersion": "100"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        return GameInstall(
            appURL: app,
            executableURL: executable,
            dataURL: data,
            archiveMacURL: nil,
            r6URL: data.appendingPathComponent("r6", isDirectory: true),
            storefront: .macAppStore,
            displayName: "Cyberpunk 2077"
        )
    }

    private func installFakeSCC(mode: FakeSCCMode = .normal) throws {
        let scc = home.redscriptRuntimeURL.appendingPathComponent("engine/tools/scc")
        try FileManager.default.createDirectory(at: scc.deletingLastPathComponent(), withIntermediateDirectories: true)
        let body: String
        switch mode {
        case .normal:
            body = """
            #!/bin/sh
            if [ "$1" = "-compile" ] && [ "$2" = "-h" ]; then
              echo "compile help"
              exit 0
            fi
            scripts=""
            out=""
            while [ "$#" -gt 0 ]; do
              case "$1" in
                -compile)
                  shift
                  scripts="$1"
                  ;;
                -outputCacheFile)
                  shift
                  out="$1"
                  ;;
              esac
              shift
            done
            cache_dir="$(dirname "$scripts")/cache"
            if [ ! -f "$cache_dir/final.redscripts" ]; then
              echo "Could not copy the base script cache file" >&2
              exit 1
            fi
            echo "timestamp" > "$cache_dir/final.redscripts.ts"
            mkdir -p "$(dirname "$out")"
            cat "$cache_dir/final.redscripts" > "$out"
            echo "compiled" >> "$out"
            """
        case .sleeping:
            body = """
            #!/bin/sh
            if [ "$1" = "-compile" ] && [ "$2" = "-h" ]; then
              echo "compile help"
              exit 0
            fi
            sleep 5
            """
        }
        try write(body, to: scc)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scc.path)
    }

    private func saveEnabledManifest(id: String) throws {
        let modRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let script = modRoot.appendingPathComponent("main.reds")
        try write("script", to: script)
        let manifest = InstalledModManifest(
            id: id,
            displayName: id,
            type: .redscript,
            status: .enabled,
            sourceArchive: "/tmp/\(id).zip",
            installedAt: Date(),
            gameAppPath: "/tmp/Cyberpunk.app",
            installMode: "sidecar_overlay",
            installedFiles: [
                InstalledFileRecord(sourceInArchive: "r6/scripts/main.reds", installedPath: script.path, sizeBytes: 6, sha256: try PathSafety.sha256(url: script))
            ],
            detectedDependencies: ["redscript"],
            compatibilityStatus: .supported
        )
        try ManifestStore(home: home).save(manifest)
    }

    private func write(_ string: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}
