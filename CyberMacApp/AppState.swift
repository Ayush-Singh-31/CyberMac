import Combine
import CyberMacCore
import Foundation

struct UserFacingError: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

struct ManualCommand: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let command: String
}

enum AppTask: Equatable, Sendable {
    case refreshing
    case launching
    case preparingActivation
    case verifyingActivation
    case preparingRestore
    case verifyingRestore
    case changingModState
    case exportingDiagnostics
    case scanningMod
    case installingMod

    var title: String {
        switch self {
        case .refreshing:
            return "Refreshing CyberMac state..."
        case .launching:
            return "Launching Cyberpunk 2077..."
        case .preparingActivation:
            return "Preparing activation output..."
        case .verifyingActivation:
            return "Verifying activation..."
        case .preparingRestore:
            return "Preparing restore command..."
        case .verifyingRestore:
            return "Verifying restore..."
        case .changingModState:
            return "Updating mod state..."
        case .exportingDiagnostics:
            return "Exporting diagnostics..."
        case .scanningMod:
            return "Scanning mod archive..."
        case .installingMod:
            return "Installing mod..."
        }
    }
}

@MainActor
final class CyberMacAppState: ObservableObject {
    @Published var doctor: DoctorReport?
    @Published var cache: BundleCacheClassification?
    @Published var mods: [InstalledModManifest] = []
    @Published var backups: [BundleBackupManifest] = []
    @Published var scanResult: ModScanResult?
    @Published var scannedArchiveURL: URL?
    @Published var currentTask: AppTask?
    @Published var lastError: UserFacingError?
    @Published var commandToRun: ManualCommand?
    @Published var pendingRestoreBackupID: String?
    @Published var developerMode: Bool {
        didSet {
            UserDefaults.standard.set(developerMode, forKey: Self.developerModeKey)
        }
    }
    @Published var inputLoaderWarningDismissed: Bool {
        didSet {
            UserDefaults.standard.set(inputLoaderWarningDismissed, forKey: Self.inputLoaderWarningDismissedKey)
        }
    }
    @Published var showRawHashes: Bool {
        didSet {
            UserDefaults.standard.set(showRawHashes, forKey: Self.showRawHashesKey)
        }
    }

    private let container: AppServiceContainer
    private static let developerModeKey = "CyberMacDeveloperMode"
    private static let inputLoaderWarningDismissedKey = "CyberMacInputLoaderWarningDismissed"
    private static let showRawHashesKey = "CyberMacShowRawHashes"

    init(container: AppServiceContainer = AppServiceContainer()) {
        self.container = container
        self.developerMode = UserDefaults.standard.bool(forKey: Self.developerModeKey)
        self.inputLoaderWarningDismissed = UserDefaults.standard.bool(forKey: Self.inputLoaderWarningDismissedKey)
        self.showRawHashes = UserDefaults.standard.bool(forKey: Self.showRawHashesKey)
    }

    func refresh() async {
        currentTask = .refreshing
        defer { currentTask = nil }

        do {
            let container = self.container
            let snapshot = try await BackgroundTaskRunner.run {
                try container.loadSnapshot()
            }
            doctor = snapshot.doctor
            cache = snapshot.cache
            mods = snapshot.mods
            backups = snapshot.backups
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Refresh failed", message: String(describing: error))
        }
    }

    func launchGame() async {
        currentTask = .launching
        defer { currentTask = nil }

        do {
            let container = self.container
            let plan = try await BackgroundTaskRunner.run {
                try container.makeLaunchPlan()
            }
            guard plan.canLaunch else {
                lastError = UserFacingError(
                    title: "Launch blocked",
                    message: plan.refusalReason ?? "CyberMac does not consider this bundle state safe to launch."
                )
                return
            }
            try await BackgroundTaskRunner.run {
                try container.launchGame(plan: plan)
            }
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Launch failed", message: String(describing: error))
        }
    }

    func showActivationDryRun() async {
        currentTask = .preparingActivation
        defer { currentTask = nil }

        do {
            let container = self.container
            let result = try await BackgroundTaskRunner.run {
                try container.activationDryRun()
            }
            commandToRun = ManualCommand(
                title: "Activation dry run",
                command: """
                Base cache snapshot:
                \(result.baseSnapshotID)

                Enabled mod ids:
                \(result.enabledModIDs.isEmpty ? "(none)" : result.enabledModIDs.joined(separator: ", "))

                Compile command:
                \(result.compileCommand)

                Manual copy shape:
                \(result.sudoCommandShape)
                """
            )
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Dry run failed", message: String(describing: error))
        }
    }

    func generateActivation() async {
        currentTask = .preparingActivation
        defer { currentTask = nil }

        do {
            let container = self.container
            let result = try await BackgroundTaskRunner.run {
                try container.generateActivation()
            }
            commandToRun = ManualCommand(title: "Run this in Terminal", command: result.sudoCommand)
            lastError = nil
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Activation failed", message: String(describing: error))
        }
    }

    func verifyActivation() async {
        currentTask = .verifyingActivation
        defer { currentTask = nil }

        do {
            let container = self.container
            let result = try await BackgroundTaskRunner.run {
                try container.verifyActivation()
            }
            if result.matched {
                commandToRun = ManualCommand(title: "Activation verified", command: "Activation verified.\nSHA-256: \(result.actualSHA256 ?? "")")
                lastError = nil
            } else {
                commandToRun = ManualCommand(
                    title: "Activation not verified",
                    command: """
                    Activation verify failed.

                    Bundle target:
                    \(result.bundleTarget)

                    Expected SHA-256:
                    \(result.expectedSHA256 ?? "missing")

                    Actual SHA-256:
                    \(result.actualSHA256 ?? "missing")
                    """
                )
            }
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Verify activation failed", message: String(describing: error))
        }
    }

    func prepareRestore(backupID: String) async {
        currentTask = .preparingRestore
        defer { currentTask = nil }

        do {
            let container = self.container
            let command = try await BackgroundTaskRunner.run {
                try container.restoreCommand(id: backupID)
            }
            pendingRestoreBackupID = backupID
            commandToRun = ManualCommand(title: "Run this in Terminal", command: command)
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Restore command failed", message: String(describing: error))
        }
    }

    func prepareLatestVanillaRestore() async {
        currentTask = .preparingRestore
        defer { currentTask = nil }

        do {
            let container = self.container
            let prepared = try await BackgroundTaskRunner.run {
                try container.prepareLatestVanillaRestoreCommand()
            }
            pendingRestoreBackupID = prepared.backup.id
            commandToRun = ManualCommand(title: "Manual restore required", command: prepared.command)
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "No vanilla backup found", message: String(describing: error))
        }
    }

    func verifyRestore() async {
        guard let pendingRestoreBackupID else {
            lastError = UserFacingError(title: "No restore pending", message: "Choose a backup and prepare its restore command first.")
            return
        }
        currentTask = .verifyingRestore
        defer { currentTask = nil }

        do {
            let container = self.container
            let result = try await BackgroundTaskRunner.run {
                try container.verifyRestore(id: pendingRestoreBackupID)
            }
            commandToRun = ManualCommand(title: "Restore verification", command: RestoreVerificationFormatter.format(result))
            lastError = nil
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Verify restore failed", message: String(describing: error))
        }
    }

    func setMod(_ mod: InstalledModManifest, enabled: Bool) async {
        currentTask = .changingModState
        defer { currentTask = nil }

        do {
            let container = self.container
            _ = try await BackgroundTaskRunner.run {
                try container.setMod(mod.id, enabled: enabled)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Mod update failed", message: String(describing: error))
        }
    }

    func scanMod(url: URL) async {
        currentTask = .scanningMod
        defer { currentTask = nil }

        do {
            let container = self.container
            let result = try await BackgroundTaskRunner.run {
                try container.scanMod(url: url)
            }
            scannedArchiveURL = url
            scanResult = result
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Scan failed", message: String(describing: error))
        }
    }

    func installScannedMod() async {
        guard let scannedArchiveURL else {
            lastError = UserFacingError(title: "No mod selected", message: "Drop a supported redscript mod archive first.")
            return
        }
        currentTask = .installingMod
        defer { currentTask = nil }

        do {
            let container = self.container
            _ = try await BackgroundTaskRunner.run {
                try container.installMod(url: scannedArchiveURL)
            }
            scanResult = nil
            self.scannedArchiveURL = nil
            lastError = nil
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Install failed", message: String(describing: error))
        }
    }

    func uninstallMod(_ mod: InstalledModManifest) async {
        currentTask = .changingModState
        defer { currentTask = nil }

        do {
            let container = self.container
            _ = try await BackgroundTaskRunner.run {
                try container.uninstallMod(mod.id)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = UserFacingError(title: "Uninstall failed", message: String(describing: error))
        }
    }

    func exportDiagnostics() async {
        currentTask = .exportingDiagnostics
        defer { currentTask = nil }

        do {
            let container = self.container
            let url = try await BackgroundTaskRunner.run {
                try container.exportDiagnostics()
            }
            commandToRun = ManualCommand(title: "Diagnostic report exported", command: url.path)
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Export failed", message: String(describing: error))
        }
    }

    func dismissInputLoaderWarning() {
        inputLoaderWarningDismissed = true
    }

    func backupDirectoryPath(id: String) -> String {
        container.backupDirectoryPath(id: id)
    }

    func revealCyberMacFolder() {
        do {
            try container.revealCyberMacFolder()
        } catch {
            lastError = UserFacingError(title: "Reveal failed", message: String(describing: error))
        }
    }

    func revealGameApp() {
        do {
            try container.revealGameApp()
        } catch {
            lastError = UserFacingError(title: "Reveal failed", message: String(describing: error))
        }
    }

    func clearTemporaryActivationOutputs() async {
        currentTask = .refreshing
        defer { currentTask = nil }

        do {
            let container = self.container
            try await BackgroundTaskRunner.run {
                try container.clearTemporaryActivationOutputs()
            }
            lastError = nil
        } catch {
            lastError = UserFacingError(title: "Clear temporary files failed", message: String(describing: error))
        }
    }
}
