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
    private var activeTasks: [(id: UUID, task: AppTask)] = []
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
        do {
            clearStaleCurrentTaskIfNeeded()
            try await withCurrentTask(.refreshing) {
                try await loadSnapshot()
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Refresh failed", message: String(describing: error))
        }
    }

    func launchGame() async {
        do {
            try await withCurrentTask(.launching) {
                let container = self.container
                let plan = try await BackgroundTaskRunner.run {
                    try container.makeLaunchPlan()
                }
                try Task.checkCancellation()
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
                try Task.checkCancellation()
                lastError = nil
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Launch failed", message: String(describing: error))
        }
    }

    func showActivationDryRun() async {
        do {
            try await withCurrentTask(.preparingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.activationDryRun()
                }
                try Task.checkCancellation()
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
            }
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Dry run failed", error: error)
        }
    }

    func generateActivation() async {
        do {
            try await withCurrentTask(.preparingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.generateActivation()
                }
                try Task.checkCancellation()
                commandToRun = activationCommandPanel(for: result)
                lastError = nil
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Activation failed", error: error)
        }
    }

    func verifyActivation() async {
        do {
            try await withCurrentTask(.verifyingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyActivation()
                }
                try Task.checkCancellation()
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
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Verify activation failed", error: error)
        }
    }

    func prepareRestore(backupID: String) async {
        do {
            try await withCurrentTask(.preparingRestore) {
                let container = self.container
                let command = try await BackgroundTaskRunner.run {
                    try container.restoreCommand(id: backupID)
                }
                try Task.checkCancellation()
                pendingRestoreBackupID = backupID
                commandToRun = ManualCommand(title: "Run this in Terminal", command: command)
                lastError = nil
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Restore command failed", message: String(describing: error))
        }
    }

    func prepareLatestVanillaRestore() async {
        do {
            try await withCurrentTask(.preparingRestore) {
                let container = self.container
                let prepared = try await BackgroundTaskRunner.run {
                    try container.prepareLatestVanillaRestoreCommand()
                }
                try Task.checkCancellation()
                pendingRestoreBackupID = prepared.backup.id
                commandToRun = ManualCommand(title: "Manual restore required", command: prepared.command)
                lastError = nil
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "No vanilla backup found", message: String(describing: error))
        }
    }

    func verifyRestore() async {
        guard let pendingRestoreBackupID else {
            lastError = UserFacingError(title: "No restore pending", message: "Choose a backup and prepare its restore command first.")
            return
        }
        do {
            try await withCurrentTask(.verifyingRestore) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyRestore(id: pendingRestoreBackupID)
                }
                try Task.checkCancellation()
                commandToRun = ManualCommand(title: "Restore verification", command: RestoreVerificationFormatter.format(result))
                lastError = nil
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Verify restore failed", message: String(describing: error))
        }
    }

    func setMod(_ mod: InstalledModManifest, enabled: Bool) async {
        do {
            try await withCurrentTask(.changingModState) {
                let container = self.container
                _ = try await BackgroundTaskRunner.run {
                    try container.setMod(mod.id, enabled: enabled)
                }
                try Task.checkCancellation()
                lastError = nil
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Mod update failed", message: String(describing: error))
        }
    }

    func scanMod(url: URL) async {
        do {
            try await withCurrentTask(.scanningMod) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.scanMod(url: url)
                }
                try Task.checkCancellation()
                scannedArchiveURL = url
                scanResult = result
                lastError = nil
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Scan failed", message: String(describing: error))
        }
    }

    func installScannedMod() async {
        guard let scannedArchiveURL else {
            lastError = UserFacingError(title: "No mod selected", message: "Drop a supported redscript mod archive first.")
            return
        }
        do {
            try await withCurrentTask(.installingMod) {
                let container = self.container
                _ = try await BackgroundTaskRunner.run {
                    try container.installMod(url: scannedArchiveURL)
                }
                try Task.checkCancellation()
                scanResult = nil
                self.scannedArchiveURL = nil
                lastError = nil
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Install failed", message: String(describing: error))
        }
    }

    func uninstallMod(_ mod: InstalledModManifest) async {
        do {
            try await withCurrentTask(.changingModState) {
                let container = self.container
                _ = try await BackgroundTaskRunner.run {
                    try container.uninstallMod(mod.id)
                }
                try Task.checkCancellation()
                lastError = nil
                await refreshAfterStateChange()
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Uninstall failed", message: String(describing: error))
        }
    }

    func exportDiagnostics() async {
        do {
            try await withCurrentTask(.exportingDiagnostics) {
                let container = self.container
                let url = try await BackgroundTaskRunner.run {
                    try container.exportDiagnostics()
                }
                try Task.checkCancellation()
                commandToRun = ManualCommand(title: "Diagnostic report exported", command: url.path)
                lastError = nil
            }
        } catch is CancellationError {
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
        do {
            try await withCurrentTask(.refreshing) {
                let container = self.container
                try await BackgroundTaskRunner.run {
                    try container.clearTemporaryActivationOutputs()
                }
                try Task.checkCancellation()
                lastError = nil
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Clear temporary files failed", message: String(describing: error))
        }
    }

    private func loadSnapshot() async throws {
        let container = self.container
        let snapshot = try await BackgroundTaskRunner.run {
            try container.loadSnapshot()
        }
        try Task.checkCancellation()
        doctor = snapshot.doctor
        cache = snapshot.cache
        mods = snapshot.mods
        backups = snapshot.backups
        lastError = nil
    }

    private func refreshAfterStateChange() async {
        do {
            try await loadSnapshot()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Refresh failed", message: String(describing: error))
        }
    }

    private func withCurrentTask<Value>(
        _ task: AppTask,
        operation: () async throws -> Value
    ) async throws -> Value {
        let taskID = beginCurrentTask(task)
        return try await withTaskCancellationHandler {
            defer { finishCurrentTask(taskID) }
            return try await operation()
        } onCancel: {
            Task { @MainActor in
                self.finishCurrentTask(taskID)
            }
        }
    }

    private func beginCurrentTask(_ task: AppTask) -> UUID {
        clearStaleCurrentTaskIfNeeded()
        let taskID = UUID()
        activeTasks.append((id: taskID, task: task))
        currentTask = task
        return taskID
    }

    private func finishCurrentTask(_ taskID: UUID) {
        activeTasks.removeAll { $0.id == taskID }
        currentTask = activeTasks.last?.task
    }

    private func clearStaleCurrentTaskIfNeeded() {
        guard currentTask != nil, activeTasks.isEmpty else { return }
        currentTask = nil
    }

    private func activationCommandPanel(for result: ActivationBundleModeResult) -> ManualCommand {
        ManualCommand(
            title: "Activation generated",
            command: """
            Activation output generated.

            Temporary output:
            \(result.tempOutputPath)

            Generated SHA-256:
            \(result.generatedSHA256)

            Backup:
            \(result.backup.id)

            Bundle target:
            \(result.bundleTarget)

            Manual copy command:
            \(result.sudoCommand)

            Verify after copying:
            \(result.verifyCommand)
            """
        )
    }

    private func showActivationError(title: String, error: Error) {
        let message = String(describing: error)
        commandToRun = ManualCommand(
            title: title,
            command: """
            \(title)

            \(message)
            """
        )
        lastError = UserFacingError(title: title, message: message)
    }
}
