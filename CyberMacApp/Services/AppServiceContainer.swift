import AppKit
import CyberMacCore
import Foundation

struct SnapshotWarning: Sendable, Identifiable {
    let id = UUID()
    let area: String
    let message: String
}

struct AppSnapshot: Sendable {
    let doctor: DoctorReport
    let cache: BundleCacheClassification?
    let mods: [InstalledModManifest]
    let backups: [BundleBackupManifest]
    let inputStatus: InputPatchStatus?
    let inputBackups: [InputConfigBackupManifest]
    let warnings: [SnapshotWarning]
}

protocol AppServiceProviding: Sendable {
    func loadSnapshot() throws -> AppSnapshot
    func invalidateGameInstall()
    func makeLaunchPlan() throws -> LaunchGamePlan
    func launchGame(plan: LaunchGamePlan) throws
    func activationDryRun() throws -> ActivationDryRunResult
    func generateActivation() throws -> ActivationBundleModeResult
    func verifyActivation() throws -> ActivationVerifyResult
    func restoreCommand(id: String) throws -> String
    func prepareLatestVanillaRestoreCommand() throws -> (backup: BundleBackupManifest, command: String)
    func verifyRestore(id: String) throws -> RestoreVerificationResult
    func prepareInputPatch(modID: String?) throws -> InputPatchPrepareResult
    func verifyInputPatch() throws -> InputPatchVerifyResult
    func restoreInputConfigCommand(id: String) throws -> [String]
    func verifyInputConfigRestore(id: String) throws -> InputConfigRestoreVerificationResult
    func backupDirectoryPath(id: String) -> String
    func inputStatus() throws -> InputPatchStatus
    func listInputBackups() throws -> [InputConfigBackupManifest]
    func inputBackupDirectoryPath(id: String) -> String
    func setMod(_ id: String, enabled: Bool) throws -> InstalledModManifest
    func renameMod(_ id: String, displayName: String) throws -> InstalledModManifest
    func uninstallMod(_ id: String) throws -> InstalledModManifest
    func deleteMod(_ id: String) throws -> ModDeleteResult
    func scanMod(url: URL) throws -> ModScanResult
    func installMod(url: URL) throws -> InstalledModManifest
    func listEditableScripts(modID: String) throws -> [EditableScriptFile]
    func loadScript(modID: String, relativePath: String) throws -> String
    func saveScript(modID: String, relativePath: String, contents: String) throws -> ScriptSaveResult
    func exportDiagnostics() throws -> URL
    func revealCyberMacFolder() throws
    func revealGameApp() throws
    func clearTemporaryActivationOutputs() throws
    func archiveIndexStatsIfAvailable() -> ArchiveCatalogIndexStatsReport?
    func assetPreviewStatsIfAvailable() -> AssetPreviewStatsReport?
    func searchArchiveIndexWithPreviews(
        query: String,
        categoryFilter: String?,
        excludedCategoryFilter: String?,
        extensionFilter: String?,
        archiveFilter: String?,
        onlyWithPreview: Bool,
        limit: Int
    ) throws -> AssetPreviewSearchReport
}

final class GameInstallCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: GameInstall?
    private let detector: GameInstallDetector

    init(detector: GameInstallDetector = GameInstallDetector()) {
        self.detector = detector
    }

    func resolve() throws -> GameInstall {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let install = try detector.detect()
        cached = install
        return install
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cached = nil
    }
}

struct AppServiceContainer: AppServiceProviding {
    let home: CyberMacHomeManager
    private let gameInstallCache: GameInstallCache
    private let modState: ModStateManager
    private let bundleBackup: BundleBackupManager
    private let inputBackup: InputConfigBackupManager
    private let inputMapping: InputMappingManager
    private let activation: ActivationManager
    private let launch: LaunchGameManager
    private let scriptEditor: ScriptEditorService
    private let modScanner: ModArchiveScanner
    private let modInstaller: RedscriptModInstaller
    private let doctor: DoctorReporter
    private let diagnostics: DiagnosticsExporter
    private let bundleState: BundleStateResolver

    init(home: CyberMacHomeManager = CyberMacHomeManager()) {
        self.home = home
        self.gameInstallCache = GameInstallCache()
        self.modState = ModStateManager(home: home)
        self.bundleBackup = BundleBackupManager(home: home)
        self.inputBackup = InputConfigBackupManager(home: home)
        self.inputMapping = InputMappingManager(home: home)
        self.activation = ActivationManager(home: home)
        self.launch = LaunchGameManager(home: home)
        self.scriptEditor = ScriptEditorService(home: home)
        self.modScanner = ModArchiveScanner()
        self.modInstaller = RedscriptModInstaller(home: home)
        self.doctor = DoctorReporter(home: home)
        self.diagnostics = DiagnosticsExporter(home: home)
        self.bundleState = BundleStateResolver(home: home)
    }

    func invalidateGameInstall() {
        gameInstallCache.invalidate()
    }

    private func currentGameInstall() throws -> GameInstall {
        try gameInstallCache.resolve()
    }

    private func currentGameInstallIfAvailable() -> GameInstall? {
        try? gameInstallCache.resolve()
    }

    func loadSnapshot() throws -> AppSnapshot {
        try home.bootstrap()
        let report = try doctor.makeReport()
        let game = currentGameInstallIfAvailable()

        var warnings: [SnapshotWarning] = []

        let cache: BundleCacheClassification?
        if let game {
            do {
                cache = try bundleState.classify(gameInstall: game)
            } catch {
                cache = nil
                warnings.append(SnapshotWarning(area: "cache", message: String(describing: error)))
            }
        } else {
            cache = nil
        }

        let mods: [InstalledModManifest]
        do {
            mods = try modState.list()
        } catch {
            mods = []
            warnings.append(SnapshotWarning(area: "mods", message: String(describing: error)))
        }

        let backups: [BundleBackupManifest]
        do {
            backups = try bundleBackup.list()
        } catch {
            backups = []
            warnings.append(SnapshotWarning(area: "backups", message: String(describing: error)))
        }

        let inputStatus: InputPatchStatus?
        do {
            inputStatus = try inputMapping.status(gameInstall: game)
        } catch {
            inputStatus = nil
            warnings.append(SnapshotWarning(area: "input-status", message: String(describing: error)))
        }

        let inputBackups: [InputConfigBackupManifest]
        do {
            inputBackups = try inputBackup.list()
        } catch {
            inputBackups = []
            warnings.append(SnapshotWarning(area: "input-backups", message: String(describing: error)))
        }

        return AppSnapshot(
            doctor: report,
            cache: cache,
            mods: mods,
            backups: backups,
            inputStatus: inputStatus,
            inputBackups: inputBackups,
            warnings: warnings
        )
    }

    func makeLaunchPlan() throws -> LaunchGamePlan {
        try launch.makeLaunchPlan(policy: .default)
    }

    func launchGame(plan: LaunchGamePlan) throws {
        try launch.launch(plan: plan, waitUntilExit: false)
    }

    func activationDryRun() throws -> ActivationDryRunResult {
        let game = try currentGameInstall()
        return try activation.dryRun(gameInstall: game)
    }

    func generateActivation() throws -> ActivationBundleModeResult {
        let game = try currentGameInstall()
        return try activation.activateBundleMode(gameInstall: game)
    }

    func verifyActivation() throws -> ActivationVerifyResult {
        let game = try currentGameInstall()
        return try activation.verify(gameInstall: game)
    }

    func restoreCommand(id: String) throws -> String {
        let game = try currentGameInstall()
        return try bundleBackup.restoreCommand(id: id, gameInstall: game)
    }

    func prepareLatestVanillaRestoreCommand() throws -> (backup: BundleBackupManifest, command: String) {
        let game = try currentGameInstall()
        return try bundleBackup.latestVanillaRestoreCommand(gameInstall: game)
    }

    func verifyRestore(id: String) throws -> RestoreVerificationResult {
        let game = try currentGameInstall()
        let manager = bundleBackup
        let result = try manager.verifyRestore(id: id, gameInstall: game)
        try manager.reconcileAfterVerifiedRestore(id: id, gameInstall: game, result: result)
        return result
    }

    func inputStatus() throws -> InputPatchStatus {
        let game = currentGameInstallIfAvailable()
        return try inputMapping.status(gameInstall: game)
    }

    func prepareInputPatch(modID: String?) throws -> InputPatchPrepareResult {
        let game = try currentGameInstall()
        return try inputMapping.preparePatch(gameInstall: game, modIDs: modID.map { [$0] })
    }

    func verifyInputPatch() throws -> InputPatchVerifyResult {
        let game = try currentGameInstall()
        return try inputMapping.verifyPatch(gameInstall: game)
    }

    func listInputBackups() throws -> [InputConfigBackupManifest] {
        try inputBackup.list()
    }

    func restoreInputConfigCommand(id: String) throws -> [String] {
        let game = try currentGameInstall()
        return try inputBackup.restoreCommands(id: id, gameInstall: game)
    }

    func verifyInputConfigRestore(id: String) throws -> InputConfigRestoreVerificationResult {
        let game = try currentGameInstall()
        return try inputBackup.verifyRestore(id: id, gameInstall: game)
    }

    func backupDirectoryPath(id: String) -> String {
        bundleBackup.backupDirectory(id: id).path
    }

    func inputBackupDirectoryPath(id: String) -> String {
        inputBackup.backupDirectory(id: id).path
    }

    func setMod(_ id: String, enabled: Bool) throws -> InstalledModManifest {
        let manager = modState
        return enabled ? try manager.enable(id: id) : try manager.disable(id: id)
    }

    func renameMod(_ id: String, displayName: String) throws -> InstalledModManifest {
        try modState.rename(id: id, displayName: displayName)
    }

    func uninstallMod(_ id: String) throws -> InstalledModManifest {
        try modState.uninstall(id: id)
    }

    func deleteMod(_ id: String) throws -> ModDeleteResult {
        try modState.deletePermanently(id: id)
    }

    func scanMod(url: URL) throws -> ModScanResult {
        try modScanner.scan(zipURL: url)
    }

    func installMod(url: URL) throws -> InstalledModManifest {
        let game = try currentGameInstall()
        return try modInstaller.install(zipURL: url, gameInstall: game)
    }

    func listEditableScripts(modID: String) throws -> [EditableScriptFile] {
        try scriptEditor.listEditableScripts(modID: modID)
    }

    func loadScript(modID: String, relativePath: String) throws -> String {
        try scriptEditor.loadScript(modID: modID, relativePath: relativePath)
    }

    func saveScript(modID: String, relativePath: String, contents: String) throws -> ScriptSaveResult {
        try scriptEditor.saveScript(modID: modID, relativePath: relativePath, contents: contents)
    }

    func exportDiagnostics() throws -> URL {
        let game = currentGameInstallIfAvailable()
        return try diagnostics.export(gameInstall: game)
    }

    func revealCyberMacFolder() throws {
        try home.bootstrap()
        NSWorkspace.shared.activateFileViewerSelecting([home.homeURL])
    }

    func revealGameApp() throws {
        let game = try currentGameInstall()
        NSWorkspace.shared.activateFileViewerSelecting([game.appURL])
    }

    func clearTemporaryActivationOutputs() throws {
        try home.bootstrap()
        guard FileManager.default.fileExists(atPath: home.tmpURL.path) else { return }
        let urls = try FileManager.default.contentsOfDirectory(at: home.tmpURL, includingPropertiesForKeys: nil)
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }

    func archiveIndexStatsIfAvailable() -> ArchiveCatalogIndexStatsReport? {
        let url = home.archiveIndexDatabaseURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? ArchiveCatalogIndexStore().stats(databaseURL: url)
    }

    func assetPreviewStatsIfAvailable() -> AssetPreviewStatsReport? {
        let url = home.archiveIndexDatabaseURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? AssetPreviewRegistry().stats(databaseURL: url)
    }

    func searchArchiveIndexWithPreviews(
        query: String,
        categoryFilter: String?,
        excludedCategoryFilter: String?,
        extensionFilter: String?,
        archiveFilter: String?,
        onlyWithPreview: Bool,
        limit: Int
    ) throws -> AssetPreviewSearchReport {
        try AssetPreviewRegistry().search(options: AssetPreviewSearchOptions(
            query: query,
            databaseURL: home.archiveIndexDatabaseURL,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            categoryFilter: categoryFilter,
            excludedCategoryFilter: excludedCategoryFilter,
            onlyWithPreview: onlyWithPreview,
            limit: limit
        ))
    }
}
