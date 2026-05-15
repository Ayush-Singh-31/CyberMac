import AppKit
import CyberMacCore
import Foundation

struct AppSnapshot: Sendable {
    let doctor: DoctorReport
    let cache: BundleCacheClassification?
    let mods: [InstalledModManifest]
    let backups: [BundleBackupManifest]
    let inputStatus: InputPatchStatus?
    let inputBackups: [InputConfigBackupManifest]
}

protocol AppServiceProviding: Sendable {
    func loadSnapshot() throws -> AppSnapshot
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
}

struct AppServiceContainer: AppServiceProviding {
    let home: CyberMacHomeManager

    init(home: CyberMacHomeManager = CyberMacHomeManager()) {
        self.home = home
    }

    func loadSnapshot() throws -> AppSnapshot {
        try home.bootstrap()
        let report = try DoctorReporter(home: home).makeReport()
        let game = try? GameInstallDetector().detect()
        let cache = try game.map { try BundleStateResolver(home: home).classify(gameInstall: $0) }
        let mods = (try? ModStateManager(home: home).list()) ?? []
        let backups = (try? BundleBackupManager(home: home).list()) ?? []
        let inputStatus = try? InputMappingManager(home: home).status(gameInstall: game)
        let inputBackups = (try? InputConfigBackupManager(home: home).list()) ?? []

        return AppSnapshot(
            doctor: report,
            cache: cache,
            mods: mods,
            backups: backups,
            inputStatus: inputStatus,
            inputBackups: inputBackups
        )
    }

    func makeLaunchPlan() throws -> LaunchGamePlan {
        try LaunchGameManager(home: home).makeLaunchPlan(policy: .default)
    }

    func launchGame(plan: LaunchGamePlan) throws {
        try LaunchGameManager(home: home).launch(plan: plan, waitUntilExit: false)
    }

    func activationDryRun() throws -> ActivationDryRunResult {
        let game = try GameInstallDetector().detect()
        return try ActivationManager(home: home).dryRun(gameInstall: game)
    }

    func generateActivation() throws -> ActivationBundleModeResult {
        let game = try GameInstallDetector().detect()
        return try ActivationManager(home: home).activateBundleMode(gameInstall: game)
    }

    func verifyActivation() throws -> ActivationVerifyResult {
        let game = try GameInstallDetector().detect()
        return try ActivationManager(home: home).verify(gameInstall: game)
    }

    func restoreCommand(id: String) throws -> String {
        let game = try GameInstallDetector().detect()
        return try BundleBackupManager(home: home).restoreCommand(id: id, gameInstall: game)
    }

    func prepareLatestVanillaRestoreCommand() throws -> (backup: BundleBackupManifest, command: String) {
        let game = try GameInstallDetector().detect()
        return try BundleBackupManager(home: home).latestVanillaRestoreCommand(gameInstall: game)
    }

    func verifyRestore(id: String) throws -> RestoreVerificationResult {
        let game = try GameInstallDetector().detect()
        return try BundleBackupManager(home: home).verifyRestore(id: id, gameInstall: game)
    }

    func inputStatus() throws -> InputPatchStatus {
        let game = try? GameInstallDetector().detect()
        return try InputMappingManager(home: home).status(gameInstall: game)
    }

    func prepareInputPatch(modID: String?) throws -> InputPatchPrepareResult {
        let game = try GameInstallDetector().detect()
        return try InputMappingManager(home: home).preparePatch(gameInstall: game, modIDs: modID.map { [$0] })
    }

    func verifyInputPatch() throws -> InputPatchVerifyResult {
        let game = try GameInstallDetector().detect()
        return try InputMappingManager(home: home).verifyPatch(gameInstall: game)
    }

    func listInputBackups() throws -> [InputConfigBackupManifest] {
        try InputConfigBackupManager(home: home).list()
    }

    func restoreInputConfigCommand(id: String) throws -> [String] {
        let game = try GameInstallDetector().detect()
        return try InputConfigBackupManager(home: home).restoreCommands(id: id, gameInstall: game)
    }

    func verifyInputConfigRestore(id: String) throws -> InputConfigRestoreVerificationResult {
        let game = try GameInstallDetector().detect()
        return try InputConfigBackupManager(home: home).verifyRestore(id: id, gameInstall: game)
    }

    func backupDirectoryPath(id: String) -> String {
        BundleBackupManager(home: home).backupDirectory(id: id).path
    }

    func inputBackupDirectoryPath(id: String) -> String {
        InputConfigBackupManager(home: home).backupDirectory(id: id).path
    }

    func setMod(_ id: String, enabled: Bool) throws -> InstalledModManifest {
        let manager = ModStateManager(home: home)
        return enabled ? try manager.enable(id: id) : try manager.disable(id: id)
    }

    func renameMod(_ id: String, displayName: String) throws -> InstalledModManifest {
        try ModStateManager(home: home).rename(id: id, displayName: displayName)
    }

    func uninstallMod(_ id: String) throws -> InstalledModManifest {
        try ModStateManager(home: home).uninstall(id: id)
    }

    func deleteMod(_ id: String) throws -> ModDeleteResult {
        try ModStateManager(home: home).deletePermanently(id: id)
    }

    func scanMod(url: URL) throws -> ModScanResult {
        try ModArchiveScanner().scan(zipURL: url)
    }

    func installMod(url: URL) throws -> InstalledModManifest {
        let game = try GameInstallDetector().detect()
        return try RedscriptModInstaller(home: home).install(zipURL: url, gameInstall: game)
    }

    func listEditableScripts(modID: String) throws -> [EditableScriptFile] {
        try ScriptEditorService(home: home).listEditableScripts(modID: modID)
    }

    func loadScript(modID: String, relativePath: String) throws -> String {
        try ScriptEditorService(home: home).loadScript(modID: modID, relativePath: relativePath)
    }

    func saveScript(modID: String, relativePath: String, contents: String) throws -> ScriptSaveResult {
        try ScriptEditorService(home: home).saveScript(modID: modID, relativePath: relativePath, contents: contents)
    }

    func exportDiagnostics() throws -> URL {
        let game = try? GameInstallDetector().detect()
        return try DiagnosticsExporter(home: home).export(gameInstall: game)
    }

    func revealCyberMacFolder() throws {
        try home.bootstrap()
        NSWorkspace.shared.activateFileViewerSelecting([home.homeURL])
    }

    func revealGameApp() throws {
        let game = try GameInstallDetector().detect()
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
}
