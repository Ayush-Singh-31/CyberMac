import AppKit
import CyberMacCore
import Foundation

struct AppSnapshot: Sendable {
    let doctor: DoctorReport
    let cache: BundleCacheClassification?
    let mods: [InstalledModManifest]
    let backups: [BundleBackupManifest]
}

struct AppServiceContainer: Sendable {
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

        return AppSnapshot(
            doctor: report,
            cache: cache,
            mods: mods,
            backups: backups
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

    func backupDirectoryPath(id: String) -> String {
        BundleBackupManager(home: home).backupDirectory(id: id).path
    }

    func setMod(_ id: String, enabled: Bool) throws -> InstalledModManifest {
        let manager = ModStateManager(home: home)
        return enabled ? try manager.enable(id: id) : try manager.disable(id: id)
    }

    func uninstallMod(_ id: String) throws -> InstalledModManifest {
        try ModStateManager(home: home).uninstall(id: id)
    }

    func scanMod(url: URL) throws -> ModScanResult {
        try ModArchiveScanner().scan(zipURL: url)
    }

    func installMod(url: URL) throws -> InstalledModManifest {
        let game = try GameInstallDetector().detect()
        return try RedscriptModInstaller(home: home).install(zipURL: url, gameInstall: game)
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
