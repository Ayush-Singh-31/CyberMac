@testable import CyberMacApp
@testable import CyberMacCore
import Foundation
import XCTest

@MainActor
final class CyberMacAppStateTests: XCTestCase {
    func testGenerateActivationSuccessClearsTaskAndShowsCommand() async {
        let service = FakeAppService()
        service.generateActivationResult = .success(makeActivationResult())
        let appState = CyberMacAppState(container: service)

        await appState.generateActivation()

        XCTAssertNil(appState.currentTask)
        XCTAssertNil(appState.lastError)
        XCTAssertEqual(appState.commandToRun?.title, "Activation generated")
        XCTAssertTrue(appState.commandToRun?.displayCommand.contains("Manual copy command:") == true)
        XCTAssertEqual(service.generateActivationCallCount, 1)
        XCTAssertEqual(service.loadSnapshotCallCount, 1)
    }

    func testGenerateActivationFailureClearsTaskAndSurfacesError() async {
        let service = FakeAppService()
        service.generateActivationResult = .failure(FakeError.activationFailed)
        let appState = CyberMacAppState(container: service)

        await appState.generateActivation()

        XCTAssertNil(appState.currentTask)
        XCTAssertEqual(appState.lastError?.title, "Activation failed")
        XCTAssertEqual(appState.commandToRun?.title, "Activation failed")
        XCTAssertEqual(service.generateActivationCallCount, 1)
        XCTAssertEqual(service.loadSnapshotCallCount, 0)
    }

    func testGenerateActivationIgnoresDuplicateWhileBusy() async throws {
        let service = FakeAppService()
        let release = DispatchSemaphore(value: 0)
        service.generateActivationHandler = {
            _ = release.wait(timeout: .now() + 3)
            return makeActivationResult()
        }
        let appState = CyberMacAppState(container: service)

        let first = Task { await appState.generateActivation() }
        try await waitForCondition {
            service.generateActivationCallCount == 1 && appState.currentTask == .preparingActivation
        }
        XCTAssertEqual(appState.currentTask, .preparingActivation)

        let second = Task { await appState.generateActivation() }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(service.generateActivationCallCount, 1)

        release.signal()
        await first.value
        await second.value

        XCTAssertNil(appState.currentTask)
        XCTAssertEqual(service.generateActivationCallCount, 1)
    }

    func testSearchArchiveIndexPassesFiltersToService() async throws {
        let service = FakeAppService()
        let expected = AssetPreviewSearchReport(
            query: "crosshair",
            databasePath: "/tmp/archive-index.sqlite",
            extensionFilter: "xbm",
            archiveFilter: "Data/archive/Mac/content/basegame_1_engine.archive",
            categoryFilter: "ui",
            excludedCategoryFilter: nil,
            onlyWithPreview: true,
            limit: 50,
            matches: []
        )
        service.searchArchiveIndexResult = .success(expected)
        let appState = CyberMacAppState(container: service)

        let report = try await appState.searchArchiveIndex(
            query: "crosshair",
            categoryFilter: "ui",
            excludedCategoryFilter: nil,
            extensionFilter: "xbm",
            archiveFilter: "Data/archive/Mac/content/basegame_1_engine.archive",
            onlyWithPreview: true,
            limit: 50
        )

        XCTAssertEqual(report.query, "crosshair")
        let calls = service.searchArchiveIndexCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first, FakeAppService.RecordedSearch(
            query: "crosshair",
            categoryFilter: "ui",
            excludedCategoryFilter: nil,
            extensionFilter: "xbm",
            archiveFilter: "Data/archive/Mac/content/basegame_1_engine.archive",
            onlyWithPreview: true,
            limit: 50
        ))
    }

    func testSearchArchiveIndexPassesAnyVisualExclusionThrough() async throws {
        let service = FakeAppService()
        service.searchArchiveIndexResult = .success(AssetPreviewSearchReport(
            query: "menu",
            databasePath: "/tmp/archive-index.sqlite",
            extensionFilter: nil,
            archiveFilter: nil,
            categoryFilter: nil,
            excludedCategoryFilter: "audio",
            onlyWithPreview: false,
            limit: 50,
            matches: []
        ))
        let appState = CyberMacAppState(container: service)

        _ = try await appState.searchArchiveIndex(
            query: "menu",
            categoryFilter: nil,
            excludedCategoryFilter: "audio",
            extensionFilter: nil,
            archiveFilter: nil,
            onlyWithPreview: false,
            limit: 50
        )

        let call = try XCTUnwrap(service.searchArchiveIndexCalls.first)
        XCTAssertNil(call.categoryFilter)
        XCTAssertEqual(call.excludedCategoryFilter, "audio")
        XCTAssertFalse(call.onlyWithPreview)
    }

    private func waitForCondition(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let step: UInt64 = 20_000_000
        var elapsed: UInt64 = 0
        while elapsed < timeoutNanoseconds {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: step)
            elapsed += step
        }
        XCTFail("Timed out waiting for condition")
    }
}

private enum FakeError: Error {
    case activationFailed
    case unexpectedCall
}

private final class FakeAppService: AppServiceProviding, @unchecked Sendable {
    private let lock = NSLock()
    var generateActivationResult: Result<ActivationBundleModeResult, Error> = .success(makeActivationResult())
    var generateActivationHandler: (() throws -> ActivationBundleModeResult)?
    private var _generateActivationCallCount = 0
    private var _loadSnapshotCallCount = 0

    var generateActivationCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _generateActivationCallCount
    }

    var loadSnapshotCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _loadSnapshotCallCount
    }

    func loadSnapshot() throws -> AppSnapshot {
        lock.lock()
        _loadSnapshotCallCount += 1
        lock.unlock()
        return Self.snapshot()
    }

    func generateActivation() throws -> ActivationBundleModeResult {
        lock.lock()
        _generateActivationCallCount += 1
        let handler = generateActivationHandler
        let result = generateActivationResult
        lock.unlock()

        if let handler {
            return try handler()
        }
        return try result.get()
    }

    func makeLaunchPlan() throws -> LaunchGamePlan { throw FakeError.unexpectedCall }
    func launchGame(plan: LaunchGamePlan) throws { throw FakeError.unexpectedCall }
    func activationDryRun() throws -> ActivationDryRunResult { throw FakeError.unexpectedCall }
    func verifyActivation() throws -> ActivationVerifyResult { throw FakeError.unexpectedCall }
    func restoreCommand(id: String) throws -> String { throw FakeError.unexpectedCall }
    func prepareLatestVanillaRestoreCommand() throws -> (backup: BundleBackupManifest, command: String) { throw FakeError.unexpectedCall }
    func verifyRestore(id: String) throws -> RestoreVerificationResult { throw FakeError.unexpectedCall }
    func prepareInputPatch(modID: String?) throws -> InputPatchPrepareResult { throw FakeError.unexpectedCall }
    func verifyInputPatch() throws -> InputPatchVerifyResult { throw FakeError.unexpectedCall }
    func restoreInputConfigCommand(id: String) throws -> [String] { throw FakeError.unexpectedCall }
    func verifyInputConfigRestore(id: String) throws -> InputConfigRestoreVerificationResult { throw FakeError.unexpectedCall }
    func backupDirectoryPath(id: String) -> String { "/tmp/\(id)" }
    func inputStatus() throws -> InputPatchStatus { throw FakeError.unexpectedCall }
    func listInputBackups() throws -> [InputConfigBackupManifest] { throw FakeError.unexpectedCall }
    func inputBackupDirectoryPath(id: String) -> String { "/tmp/input/\(id)" }
    func invalidateGameInstall() { }
    func setMod(_ id: String, enabled: Bool) throws -> InstalledModManifest { throw FakeError.unexpectedCall }
    func renameMod(_ id: String, displayName: String) throws -> InstalledModManifest { throw FakeError.unexpectedCall }
    func uninstallMod(_ id: String) throws -> InstalledModManifest { throw FakeError.unexpectedCall }
    func deleteMod(_ id: String) throws -> ModDeleteResult { throw FakeError.unexpectedCall }
    func scanMod(url: URL) throws -> ModScanResult { throw FakeError.unexpectedCall }
    func installMod(url: URL) throws -> InstalledModManifest { throw FakeError.unexpectedCall }
    func listEditableScripts(modID: String) throws -> [EditableScriptFile] { throw FakeError.unexpectedCall }
    func loadScript(modID: String, relativePath: String) throws -> String { throw FakeError.unexpectedCall }
    func saveScript(modID: String, relativePath: String, contents: String) throws -> ScriptSaveResult { throw FakeError.unexpectedCall }
    func exportDiagnostics() throws -> URL { throw FakeError.unexpectedCall }
    func revealCyberMacFolder() throws { throw FakeError.unexpectedCall }
    func revealGameApp() throws { throw FakeError.unexpectedCall }
    func clearTemporaryActivationOutputs() throws { throw FakeError.unexpectedCall }
    func archiveIndexStatsIfAvailable() -> ArchiveCatalogIndexStatsReport? { nil }
    func assetPreviewStatsIfAvailable() -> AssetPreviewStatsReport? { nil }

    struct RecordedSearch: Equatable {
        let query: String
        let categoryFilter: String?
        let excludedCategoryFilter: String?
        let extensionFilter: String?
        let archiveFilter: String?
        let onlyWithPreview: Bool
        let limit: Int
    }

    private var _searchArchiveIndexCalls: [RecordedSearch] = []
    var searchArchiveIndexCalls: [RecordedSearch] {
        lock.lock()
        defer { lock.unlock() }
        return _searchArchiveIndexCalls
    }
    var searchArchiveIndexResult: Result<AssetPreviewSearchReport, Error> = .failure(FakeError.unexpectedCall)

    func searchArchiveIndexWithPreviews(
        query: String,
        categoryFilter: String?,
        excludedCategoryFilter: String?,
        extensionFilter: String?,
        archiveFilter: String?,
        onlyWithPreview: Bool,
        limit: Int
    ) throws -> AssetPreviewSearchReport {
        lock.lock()
        _searchArchiveIndexCalls.append(RecordedSearch(
            query: query,
            categoryFilter: categoryFilter,
            excludedCategoryFilter: excludedCategoryFilter,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            onlyWithPreview: onlyWithPreview,
            limit: limit
        ))
        let result = searchArchiveIndexResult
        lock.unlock()
        return try result.get()
    }

    private static func snapshot() -> AppSnapshot {
        AppSnapshot(
            doctor: DoctorReport(
                game: GameInstallSummary(
                    found: true,
                    edition: "Cyberpunk 2077",
                    storefront: Storefront.macAppStore.rawValue,
                    appPath: "/Applications/Cyberpunk 2077: Ultimate.app",
                    dataPath: "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data",
                    bundleTarget: "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/cache/final.redscripts",
                    executableFound: true,
                    dataPathFound: true
                ),
                runtime: RuntimeSummary(
                    redscript: RuntimeToolSummary(
                        installed: true,
                        toolFound: true,
                        version: nil,
                        rootPath: "/runtime/redscript",
                        toolPath: "/runtime/redscript/scc",
                        quarantinedPathCount: 0,
                        notes: []
                    ),
                    inputLoader: RuntimeToolSummary(
                        installed: true,
                        toolFound: true,
                        version: nil,
                        rootPath: "/runtime/input-loader",
                        toolPath: "/runtime/input-loader/inputloader.pl",
                        quarantinedPathCount: 0,
                        notes: []
                    )
                ),
                cache: CacheSummary(
                    baseSnapshotPresent: true,
                    currentBundle: .vanilla,
                    bundleTarget: "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/cache/final.redscripts",
                    bundleCacheSHA256: "base-sha",
                    baseSnapshotSHA256: "base-sha",
                    overlayMirrorPresent: true
                ),
                activation: ActivationSummary(
                    state: .outOfSync,
                    enabledMods: 1,
                    activeModIDs: [],
                    bundleChangedSinceLastActivation: false,
                    manualPrivilegedWriteRequired: true,
                    safeToProceedToActivation: true,
                    nextStep: "Run cybermac activate --bundle-mode."
                ),
                warnings: [],
                legacyProbe: nil
            ),
            cache: nil,
            mods: [],
            backups: [],
            inputStatus: nil,
            inputBackups: [],
            warnings: []
        )
    }
}

private func makeActivationResult() -> ActivationBundleModeResult {
    ActivationBundleModeResult(
        bundleTarget: "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/cache/final.redscripts",
        tempOutputPath: "/Users/example/Library/Application Support/CyberMac/tmp/activation-test/final.redscripts",
        generatedSHA256: "generated-sha",
        backup: BundleBackupManifest(
            id: "backup-id",
            createdAt: Date(),
            gameAppPath: "/Applications/Cyberpunk 2077: Ultimate.app",
            bundleTarget: "/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/cache/final.redscripts",
            priorState: .present,
            sha256: "base-sha",
            sizeBytes: 12,
            gameFingerprintID: "fingerprint"
        ),
        compileCommand: "/runtime/scc -compile",
        sudoCommand: "sudo cp \"/tmp/final.redscripts\" \"/Applications/Cyberpunk 2077: Ultimate.app/Contents/Data/r6/cache/final.redscripts\"",
        verifyCommand: "swift run cybermac activate --verify"
    )
}
