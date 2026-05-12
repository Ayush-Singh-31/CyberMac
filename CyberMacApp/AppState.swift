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
    let displayCommand: String

    init(title: String, command: String) {
        self.title = title
        self.displayCommand = command
    }
}

enum AppTask: Equatable, Sendable {
    case refreshing
    case launching
    case preparingActivation
    case verifyingActivation
    case preparingInputPatch
    case verifyingInputPatch
    case preparingRestore
    case verifyingRestore
    case preparingInputRestore
    case verifyingInputRestore
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
        case .preparingInputPatch:
            return "Preparing input patch..."
        case .verifyingInputPatch:
            return "Verifying input patch..."
        case .preparingRestore:
            return "Preparing restore command..."
        case .verifyingRestore:
            return "Verifying restore..."
        case .preparingInputRestore:
            return "Preparing input restore command..."
        case .verifyingInputRestore:
            return "Verifying input restore..."
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
    @Published var inputStatus: InputPatchStatus?
    @Published var inputBackups: [InputConfigBackupManifest] = []
    @Published var scanResult: ModScanResult?
    @Published var scannedArchiveURL: URL?
    @Published var currentTask: AppTask?
    @Published var lastError: UserFacingError?
    @Published var commandToRun: ManualCommand?
    @Published var pendingRestoreBackupID: String?
    @Published var pendingInputConfigBackupID: String?
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
            let result = try await withCurrentTask(.preparingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.activationDryRun()
                }
                try Task.checkCancellation()
                return result
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
            warnIfCommandAndCurrentTaskOverlap(context: "showActivationDryRun")
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Dry run failed", error: error)
        }
    }

    func generateActivation() async {
        activationDebugLog("[ActivationUI] start generate")
        do {
            let result = try await withCurrentTask(.preparingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.generateActivation()
                }
                try Task.checkCancellation()
                activationDebugLog("[ActivationUI] core activation returned")
                return result
            }
            commandToRun = activationCommandPanel(for: result)
            activationDebugLog("[ActivationUI] command stored")
            lastError = nil
            activationDebugLog("[ActivationUI] currentTask cleared")
            warnIfCommandAndCurrentTaskOverlap(context: "generateActivation")
            await refreshPreservingCommand()
            activationDebugLog("[ActivationUI] refresh complete")
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Activation failed", error: error)
        }
    }

    func verifyActivation() async {
        do {
            let result = try await withCurrentTask(.verifyingActivation) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyActivation()
                }
                try Task.checkCancellation()
                return result
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
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "verifyActivation")
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            showActivationError(title: "Verify activation failed", error: error)
        }
    }

    func prepareInputPatch(modID: String? = nil) async {
        do {
            let result = try await withCurrentTask(.preparingInputPatch) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.prepareInputPatch(modID: modID)
                }
                try Task.checkCancellation()
                return result
            }
            commandToRun = ManualCommand(
                title: "Manual input patch required",
                command: """
                Input patch prepared.

                Generated files:
                \(result.generatedContextPath)
                \(result.generatedUserMappingsPath)

                Backup:
                \(result.backupID)

                Manual copy commands:
                \(result.sudoCommands.joined(separator: "\n"))

                Verify after copying:
                \(result.verifyCommand)
                """
            )
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "prepareInputPatch")
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Input patch failed", message: String(describing: error))
        }
    }

    func verifyInputPatch() async {
        do {
            let result = try await withCurrentTask(.verifyingInputPatch) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyInputPatch()
                }
                try Task.checkCancellation()
                return result
            }
            if result.matched {
                commandToRun = ManualCommand(title: "Input patch verified", command: "Input patch verified: active")
                lastError = nil
            } else {
                commandToRun = ManualCommand(
                    title: "Input patch not verified",
                    command: inputPatchMismatchText(result)
                )
            }
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "verifyInputPatch")
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Verify input patch failed", message: String(describing: error))
        }
    }

    func prepareRestore(backupID: String) async {
        do {
            let command = try await withCurrentTask(.preparingRestore) {
                let container = self.container
                let command = try await BackgroundTaskRunner.run {
                    try container.restoreCommand(id: backupID)
                }
                try Task.checkCancellation()
                return command
            }
            pendingRestoreBackupID = backupID
            commandToRun = ManualCommand(title: "Run this in Terminal", command: command)
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "prepareRestore")
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Restore command failed", message: String(describing: error))
        }
    }

    func prepareLatestVanillaRestore() async {
        do {
            let prepared = try await withCurrentTask(.preparingRestore) {
                let container = self.container
                let prepared = try await BackgroundTaskRunner.run {
                    try container.prepareLatestVanillaRestoreCommand()
                }
                try Task.checkCancellation()
                return prepared
            }
            pendingRestoreBackupID = prepared.backup.id
            commandToRun = ManualCommand(title: "Manual restore required", command: prepared.command)
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "prepareLatestVanillaRestore")
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
            let result = try await withCurrentTask(.verifyingRestore) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyRestore(id: pendingRestoreBackupID)
                }
                try Task.checkCancellation()
                return result
            }
            commandToRun = ManualCommand(title: "Restore verification", command: RestoreVerificationFormatter.format(result))
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "verifyRestore")
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Verify restore failed", message: String(describing: error))
        }
    }

    func prepareInputConfigRestore(backupID: String) async {
        do {
            let commands = try await withCurrentTask(.preparingInputRestore) {
                let container = self.container
                let commands = try await BackgroundTaskRunner.run {
                    try container.restoreInputConfigCommand(id: backupID)
                }
                try Task.checkCancellation()
                return commands
            }
            pendingInputConfigBackupID = backupID
            commandToRun = ManualCommand(title: "Manual input config restore required", command: commands.joined(separator: "\n"))
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "prepareInputConfigRestore")
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Input restore command failed", message: String(describing: error))
        }
    }

    func verifyInputConfigRestore() async {
        guard let pendingInputConfigBackupID else {
            lastError = UserFacingError(title: "No input restore pending", message: "Choose an input config backup and prepare its restore command first.")
            return
        }
        do {
            let result = try await withCurrentTask(.verifyingInputRestore) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.verifyInputConfigRestore(id: pendingInputConfigBackupID)
                }
                try Task.checkCancellation()
                return result
            }
            commandToRun = ManualCommand(title: "Input restore verification", command: inputRestoreVerificationText(result))
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "verifyInputConfigRestore")
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Verify input restore failed", message: String(describing: error))
        }
    }

    func setMod(_ mod: InstalledModManifest, enabled: Bool) async {
        let action = enabled ? "enable" : "disable"
        modDebugLog("[ModsUI] start \(action) \(mod.id)")
        do {
            _ = try await withCurrentTask(.changingModState) {
                let container = self.container
                let manifest = try await BackgroundTaskRunner.run {
                    try container.setMod(mod.id, enabled: enabled)
                }
                try Task.checkCancellation()
                modDebugLog("[ModsUI] core \(action) returned \(mod.id)")
                return manifest
            }
            modDebugLog("[ModsUI] currentTask cleared")
            lastError = nil
            if let refreshError = await refreshAfterStateChange() {
                modDebugLog("[ModsUI] refresh failed: \(refreshError)")
            } else {
                modDebugLog("[ModsUI] refresh complete")
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
            _ = try await withCurrentTask(.installingMod) {
                let container = self.container
                let manifest = try await BackgroundTaskRunner.run {
                    try container.installMod(url: scannedArchiveURL)
                }
                try Task.checkCancellation()
                return manifest
            }
            scanResult = nil
            self.scannedArchiveURL = nil
            lastError = nil
            await refreshAfterStateChange()
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Install failed", message: String(describing: error))
        }
    }

    func uninstallMod(_ mod: InstalledModManifest) async {
        modDebugLog("[ModsUI] start uninstall \(mod.id)")
        do {
            _ = try await withCurrentTask(.changingModState) {
                let container = self.container
                let manifest = try await BackgroundTaskRunner.run {
                    try container.uninstallMod(mod.id)
                }
                try Task.checkCancellation()
                modDebugLog("[ModsUI] core uninstall returned \(mod.id)")
                return manifest
            }
            modDebugLog("[ModsUI] currentTask cleared")
            lastError = nil
            if let refreshError = await refreshAfterStateChange() {
                modDebugLog("[ModsUI] refresh failed: \(refreshError)")
            } else {
                modDebugLog("[ModsUI] refresh complete")
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Uninstall failed", message: String(describing: error))
        }
    }

    func deleteMod(_ mod: InstalledModManifest) async {
        modDebugLog("[ModsUI] start delete \(mod.id)")
        do {
            _ = try await withCurrentTask(.changingModState) {
                let container = self.container
                let result = try await BackgroundTaskRunner.run {
                    try container.deleteMod(mod.id)
                }
                try Task.checkCancellation()
                modDebugLog("[ModsUI] core delete returned \(mod.id)")
                return result
            }
            modDebugLog("[ModsUI] currentTask cleared")
            lastError = nil
            if let refreshError = await refreshAfterStateChange() {
                modDebugLog("[ModsUI] refresh failed: \(refreshError)")
            } else {
                modDebugLog("[ModsUI] refresh complete")
            }
        } catch is CancellationError {
        } catch {
            lastError = UserFacingError(title: "Delete failed", message: String(describing: error))
        }
    }

    func exportDiagnostics() async {
        do {
            let url = try await withCurrentTask(.exportingDiagnostics) {
                let container = self.container
                let url = try await BackgroundTaskRunner.run {
                    try container.exportDiagnostics()
                }
                try Task.checkCancellation()
                return url
            }
            commandToRun = ManualCommand(title: "Diagnostic report exported", command: url.path)
            lastError = nil
            warnIfCommandAndCurrentTaskOverlap(context: "exportDiagnostics")
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
        inputStatus = snapshot.inputStatus
        inputBackups = snapshot.inputBackups
        lastError = nil
    }

    @discardableResult
    private func refreshAfterStateChange() async -> Error? {
        do {
            try await loadSnapshot()
            return nil
        } catch is CancellationError {
            return CancellationError()
        } catch {
            lastError = UserFacingError(title: "Refresh failed", message: String(describing: error))
            return error
        }
    }

    private func refreshPreservingCommand() async {
        await refreshAfterStateChange()
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
        warnIfCommandAndCurrentTaskOverlap(context: title)
    }

    private func activationDebugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func modDebugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func warnIfCommandAndCurrentTaskOverlap(context: String) {
        #if DEBUG
        if commandToRun != nil, currentTask != nil {
            NSLog("%@", "[AppState] warning: commandToRun and currentTask are both set after \(context)")
        }
        #endif
    }

    private func inputPatchMismatchText(_ result: InputPatchVerifyResult) -> String {
        var lines: [String] = ["Input patch verify failed.", ""]
        for target in result.mismatches {
            lines.append("Target:")
            lines.append(target)
            lines.append("Expected:")
            lines.append(result.expectedHashes[target] ?? "missing")
            lines.append("Actual:")
            lines.append(result.actualHashes[target] ?? "missing")
            lines.append("")
        }
        lines.append("Likely cause:")
        lines.append("The printed sudo copy command has not been run yet, or a different file was copied.")
        return lines.joined(separator: "\n")
    }

    private func inputRestoreVerificationText(_ result: InputConfigRestoreVerificationResult) -> String {
        var lines: [String] = []
        lines.append(result.matched ? "Input config restore verified." : "Input config restore verify failed.")
        lines.append("Backup ID: \(result.backupID)")
        for file in result.fileResults {
            lines.append("")
            lines.append(file.role.rawValue)
            switch file.status {
            case .verified(let target):
                lines.append("Verified: \(target)")
            case .hashMismatch(let expected, let actual, let target):
                lines.append("Target: \(target)")
                lines.append("Expected: \(expected)")
                lines.append("Actual: \(actual)")
            case .expectedAbsentButFileExists(let target, let actualHash):
                lines.append("Expected absent but file exists: \(target)")
                lines.append("Actual SHA-256: \(actualHash)")
            case .expectedPresentButFileMissing(let target):
                lines.append("Expected present but file is missing: \(target)")
            case .staleBackup(let expectedFingerprint, let actualFingerprint):
                lines.append("Stale backup")
                lines.append("Expected fingerprint: \(expectedFingerprint)")
                lines.append("Actual fingerprint: \(actualFingerprint)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
