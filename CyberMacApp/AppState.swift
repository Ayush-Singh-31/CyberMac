import CyberMacCore
import Foundation
import Observation
import os

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

struct AppTask: Equatable, Sendable {
    let title: String

    static let refreshing            = AppTask(title: "Refreshing CyberMac state…")
    static let launching             = AppTask(title: "Launching Cyberpunk 2077…")
    static let preparingActivation   = AppTask(title: "Preparing activation output…")
    static let verifyingActivation   = AppTask(title: "Verifying activation…")
    static let preparingInputPatch   = AppTask(title: "Preparing input patch…")
    static let verifyingInputPatch   = AppTask(title: "Verifying input patch…")
    static let preparingRestore      = AppTask(title: "Preparing restore command…")
    static let verifyingRestore      = AppTask(title: "Verifying restore…")
    static let preparingInputRestore = AppTask(title: "Preparing input restore command…")
    static let verifyingInputRestore = AppTask(title: "Verifying input restore…")
    static let changingModState      = AppTask(title: "Updating mod state…")
    static let renamingMod           = AppTask(title: "Renaming mod…")
    static let exportingDiagnostics  = AppTask(title: "Exporting diagnostics…")
    static let scanningMod           = AppTask(title: "Scanning mod archive…")
    static let installingMod         = AppTask(title: "Installing mod…")
    static let loadingScript         = AppTask(title: "Loading script…")
    static let savingScript          = AppTask(title: "Saving script…")
}

extension Logger {
    static let activation = Logger(subsystem: "com.cybermac.app", category: "activation")
    static let mods       = Logger(subsystem: "com.cybermac.app", category: "mods")
    static let state      = Logger(subsystem: "com.cybermac.app", category: "state")
}

@MainActor
@Observable
final class CyberMacAppState {
    var doctor: DoctorReport?
    var cache: BundleCacheClassification?
    var mods: [InstalledModManifest] = []
    var backups: [BundleBackupManifest] = []
    var inputStatus: InputPatchStatus?
    var inputBackups: [InputConfigBackupManifest] = []
    var outfitProfiles: [OutfitProfileSummary] = []
    var outfitBundles: [CyberMacOutfitBundle] = []
    var scanResult: ModScanResult?
    var scannedArchiveURL: URL?
    var currentTask: AppTask?
    var lastError: UserFacingError?
    var commandToRun: ManualCommand?
    var pendingRestoreBackupID: String?
    var pendingInputConfigBackupID: String?
    var snapshotWarnings: [SnapshotWarning] = []

    var developerMode: Bool {
        didSet { UserDefaults.standard.set(developerMode, forKey: Self.developerModeKey) }
    }

    var inputLoaderWarningDismissed: Bool {
        didSet { UserDefaults.standard.set(inputLoaderWarningDismissed, forKey: Self.inputLoaderWarningDismissedKey) }
    }

    var showRawHashes: Bool {
        didSet { UserDefaults.standard.set(showRawHashes, forKey: Self.showRawHashesKey) }
    }

    @ObservationIgnored private let container: any AppServiceProviding
    @ObservationIgnored private var currentTaskID: UUID?
    private static let developerModeKey = "CyberMacDeveloperMode"
    private static let inputLoaderWarningDismissedKey = "CyberMacInputLoaderWarningDismissed"
    private static let showRawHashesKey = "CyberMacShowRawHashes"

    init(container: any AppServiceProviding = AppServiceContainer()) {
        self.container = container
        self.developerMode = UserDefaults.standard.bool(forKey: Self.developerModeKey)
        self.inputLoaderWarningDismissed = UserDefaults.standard.bool(forKey: Self.inputLoaderWarningDismissedKey)
        self.showRawHashes = UserDefaults.standard.bool(forKey: Self.showRawHashesKey)
    }

    // MARK: - High-level commands

    func refresh() async {
        await runTask(.refreshing, failureTitle: "Refresh failed") { [container] in
            try container.loadSnapshot()
        } onSuccess: { snapshot in
            self.apply(snapshot: snapshot)
        }
    }

    func launchGame() async {
        await runTask(.launching, failureTitle: "Launch failed") { [container] in
            let plan = try container.makeLaunchPlan()
            return plan
        } onSuccess: { plan in
            guard plan.canLaunch else {
                self.lastError = UserFacingError(
                    title: "Launch blocked",
                    message: plan.refusalReason ?? "CyberMac does not consider this bundle state safe to launch."
                )
                return
            }
            do {
                try self.container.launchGame(plan: plan)
            } catch {
                self.lastError = UserFacingError(title: "Launch failed", message: String(describing: error))
            }
        }
    }

    func showActivationDryRun() async {
        await runTask(.preparingActivation, failureTitle: "Dry run failed") { [container] in
            try container.activationDryRun()
        } onSuccess: { result in
            self.commandToRun = ManualCommand(
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
        } onError: { error in
            self.commandToRun = ManualCommand(
                title: "Dry run failed",
                command: "Dry run failed\n\n\(String(describing: error))"
            )
        }
    }

    func generateActivation() async {
        Logger.activation.debug("start generate")
        await runTask(.preparingActivation, failureTitle: "Activation failed", refreshAfter: true) { [container] in
            try container.generateActivation()
        } onSuccess: { result in
            self.commandToRun = self.activationCommandPanel(for: result)
            Logger.activation.debug("command stored")
        } onError: { error in
            self.commandToRun = ManualCommand(
                title: "Activation failed",
                command: "Activation failed\n\n\(String(describing: error))"
            )
        }
    }

    func verifyActivation() async {
        await runTask(.verifyingActivation, failureTitle: "Verify activation failed", refreshAfter: true) { [container] in
            try container.verifyActivation()
        } onSuccess: { result in
            if result.matched {
                self.commandToRun = ManualCommand(
                    title: "Activation verified",
                    command: "Activation verified.\nSHA-256: \(result.actualSHA256 ?? "")"
                )
            } else {
                self.commandToRun = ManualCommand(
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
        } onError: { error in
            self.commandToRun = ManualCommand(
                title: "Verify activation failed",
                command: "Verify activation failed\n\n\(String(describing: error))"
            )
        }
    }

    func prepareInputPatch(modID: String? = nil) async {
        await runTask(.preparingInputPatch, failureTitle: "Input patch failed", refreshAfter: true) { [container] in
            try container.prepareInputPatch(modID: modID)
        } onSuccess: { result in
            self.commandToRun = ManualCommand(
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
        }
    }

    func verifyInputPatch() async {
        await runTask(.verifyingInputPatch, failureTitle: "Verify input patch failed", refreshAfter: true) { [container] in
            try container.verifyInputPatch()
        } onSuccess: { result in
            if result.matched {
                self.commandToRun = ManualCommand(title: "Input patch verified", command: "Input patch verified: active")
            } else {
                self.commandToRun = ManualCommand(
                    title: "Input patch not verified",
                    command: self.inputPatchMismatchText(result)
                )
            }
        }
    }

    func prepareRestore(backupID: String) async {
        await runTask(.preparingRestore, failureTitle: "Restore command failed") { [container] in
            try container.restoreCommand(id: backupID)
        } onSuccess: { command in
            self.pendingRestoreBackupID = backupID
            self.commandToRun = ManualCommand(title: "Run this in Terminal", command: command)
        }
    }

    func prepareLatestVanillaRestore() async {
        await runTask(.preparingRestore, failureTitle: "No vanilla backup found") { [container] in
            try container.prepareLatestVanillaRestoreCommand()
        } onSuccess: { prepared in
            self.pendingRestoreBackupID = prepared.backup.id
            self.commandToRun = ManualCommand(title: "Manual restore required", command: prepared.command)
        }
    }

    func verifyRestore() async {
        guard let pendingRestoreBackupID else {
            lastError = UserFacingError(title: "No restore pending", message: "Choose a backup and prepare its restore command first.")
            return
        }
        await runTask(.verifyingRestore, failureTitle: "Verify restore failed", refreshAfter: true) { [container] in
            try container.verifyRestore(id: pendingRestoreBackupID)
        } onSuccess: { result in
            self.commandToRun = ManualCommand(title: "Restore verification", command: RestoreVerificationFormatter.format(result))
        }
    }

    func prepareInputConfigRestore(backupID: String) async {
        await runTask(.preparingInputRestore, failureTitle: "Input restore command failed") { [container] in
            try container.restoreInputConfigCommand(id: backupID)
        } onSuccess: { commands in
            self.pendingInputConfigBackupID = backupID
            self.commandToRun = ManualCommand(title: "Manual input config restore required", command: commands.joined(separator: "\n"))
        }
    }

    func verifyInputConfigRestore() async {
        guard let pendingInputConfigBackupID else {
            lastError = UserFacingError(title: "No input restore pending", message: "Choose an input config backup and prepare its restore command first.")
            return
        }
        await runTask(.verifyingInputRestore, failureTitle: "Verify input restore failed", refreshAfter: true) { [container] in
            try container.verifyInputConfigRestore(id: pendingInputConfigBackupID)
        } onSuccess: { result in
            self.commandToRun = ManualCommand(title: "Input restore verification", command: self.inputRestoreVerificationText(result))
        }
    }

    func setMod(_ mod: InstalledModManifest, enabled: Bool) async {
        let action = enabled ? "enable" : "disable"
        Logger.mods.debug("start \(action, privacy: .public) \(mod.id, privacy: .public)")
        await runTask(.changingModState, failureTitle: "Mod update failed", refreshAfter: true) { [container] in
            try container.setMod(mod.id, enabled: enabled)
        }
    }

    @discardableResult
    func renameMod(_ mod: InstalledModManifest, displayName: String) async -> Bool {
        Logger.mods.debug("start rename \(mod.id, privacy: .public)")
        return await runTask(.renamingMod, failureTitle: "Rename failed", refreshAfter: true) { [container] in
            try container.renameMod(mod.id, displayName: displayName)
        }
    }

    func scanMod(url: URL) async {
        await runTask(.scanningMod, failureTitle: "Scan failed") { [container] in
            try container.scanMod(url: url)
        } onSuccess: { result in
            self.scannedArchiveURL = url
            self.scanResult = result
        }
    }

    func installScannedMod() async {
        guard let scannedArchiveURL else {
            lastError = UserFacingError(title: "No mod selected", message: "Drop a supported redscript mod archive first.")
            return
        }
        await runTask(.installingMod, failureTitle: "Install failed", refreshAfter: true) { [container] in
            try container.installMod(url: scannedArchiveURL)
        } onSuccess: { _ in
            self.scanResult = nil
            self.scannedArchiveURL = nil
        }
    }

    func listEditableScripts(for modID: String) async -> [EditableScriptFile] {
        var files: [EditableScriptFile] = []
        await runTask(.loadingScript, failureTitle: "Script list failed") { [container] in
            try container.listEditableScripts(modID: modID)
        } onSuccess: { result in
            files = result
        }
        return files
    }

    func loadScript(modID: String, relativePath: String) async throws -> String {
        try await runTaskThrowing(.loadingScript, failureTitle: "Script load failed") { [container] in
            try container.loadScript(modID: modID, relativePath: relativePath)
        }
    }

    func saveScript(modID: String, relativePath: String, contents: String) async throws -> ScriptSaveResult {
        let result = try await runTaskThrowing(.savingScript, failureTitle: "Script save failed") { [container] in
            try container.saveScript(modID: modID, relativePath: relativePath, contents: contents)
        }
        await refreshAfterStateChange()
        return result
    }

    func uninstallMod(_ mod: InstalledModManifest) async {
        Logger.mods.debug("start uninstall \(mod.id, privacy: .public)")
        await runTask(.changingModState, failureTitle: "Uninstall failed", refreshAfter: true) { [container] in
            try container.uninstallMod(mod.id)
        }
    }

    func deleteMod(_ mod: InstalledModManifest) async {
        Logger.mods.debug("start delete \(mod.id, privacy: .public)")
        await runTask(.changingModState, failureTitle: "Delete failed", refreshAfter: true) { [container] in
            try container.deleteMod(mod.id)
        }
    }

    func exportDiagnostics() async {
        await runTask(.exportingDiagnostics, failureTitle: "Export failed") { [container] in
            try container.exportDiagnostics()
        } onSuccess: { url in
            self.commandToRun = ManualCommand(title: "Diagnostic report exported", command: url.path)
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
        await runTask(.refreshing, failureTitle: "Clear temporary files failed") { [container] in
            try container.clearTemporaryActivationOutputs()
        }
    }

    func invalidateGameInstall() {
        container.invalidateGameInstall()
    }

    func loadArchiveIndexStats() async -> ArchiveCatalogIndexStatsReport? {
        let container = self.container
        return (try? await BackgroundTaskRunner.run { container.archiveIndexStatsIfAvailable() }) ?? nil
    }

    func loadAssetPreviewStats() async -> AssetPreviewStatsReport? {
        let container = self.container
        return (try? await BackgroundTaskRunner.run { container.assetPreviewStatsIfAvailable() }) ?? nil
    }

    func searchArchiveIndex(
        query: String,
        categoryFilter: String?,
        excludedCategoryFilter: String?,
        extensionFilter: String?,
        archiveFilter: String?,
        onlyWithPreview: Bool,
        limit: Int
    ) async throws -> AssetPreviewSearchReport {
        let container = self.container
        return try await BackgroundTaskRunner.run {
            try container.searchArchiveIndexWithPreviews(
                query: query,
                categoryFilter: categoryFilter,
                excludedCategoryFilter: excludedCategoryFilter,
                extensionFilter: extensionFilter,
                archiveFilter: archiveFilter,
                onlyWithPreview: onlyWithPreview,
                limit: limit
            )
        }
    }

    // MARK: - Internals

    private func apply(snapshot: AppSnapshot) {
        doctor = snapshot.doctor
        cache = snapshot.cache
        mods = snapshot.mods
        backups = snapshot.backups
        inputStatus = snapshot.inputStatus
        inputBackups = snapshot.inputBackups
        outfitProfiles = snapshot.outfitProfiles
        outfitBundles = snapshot.outfitBundles
        snapshotWarnings = snapshot.warnings
    }

    func setOutfitPiece(profileID: String, pieceID: String, enabled: Bool) async {
        await runTask(.changingModState, failureTitle: "Outfit piece update failed", refreshAfter: true) { [container] in
            try container.setOutfitPiece(profileID: profileID, pieceID: pieceID, enabled: enabled)
        }
    }

    func showOutfitProfileInstallCommand(profileID: String) async {
        await runTask(.preparingActivation, failureTitle: "Outfit profile install command failed") { [container] in
            try container.makeOutfitProfileInstallPlan(profileID: profileID)
        } onSuccess: { plan in
            self.commandToRun = ManualCommand(
                title: "Install outfit profile: \(plan.profile.displayName)",
                command: Self.outfitProfileInstallCommandText(plan)
            )
        }
    }

    func showOutfitProfileRestoreCommand(profileID: String) async {
        await runTask(.preparingRestore, failureTitle: "Outfit profile restore command failed") { [container] in
            try container.outfitProfileRestoreCommand(profileID: profileID)
        } onSuccess: { command in
            self.commandToRun = ManualCommand(
                title: "Restore official archive: \(profileID)",
                command: command
            )
        }
    }

    func showOutfitProfileGrantCommand(profileID: String, displayName: String) {
        let safeName = profileID
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        commandToRun = ManualCommand(
            title: "Generate grant helper: \(displayName)",
            command: """
            swift run cybermac outfit profile grant-items \\
              --profile \(PathSafety.shellQuoted(profileID)) \\
              --out "$HOME/Desktop/\(safeName)-item-grant.zip" \\
              --mod-name \(PathSafety.shellQuoted("\(safeName)_grant"))
            """
        )
    }

    func showOutfitInstallCommand(for bundle: CyberMacOutfitBundle) async {
        await runTask(.preparingActivation, failureTitle: "Outfit install command failed") { [container] in
            try container.makeOutfitBundleUIPlans(bundle)
        } onSuccess: { plans in
            self.commandToRun = ManualCommand(
                title: "Install outfit archive: \(bundle.displayName)",
                command: Self.outfitInstallCommandText(plans.install)
            )
        }
    }

    func showOutfitRestoreCommand(for bundle: CyberMacOutfitBundle) async {
        await runTask(.preparingRestore, failureTitle: "Outfit restore command failed") { [container] in
            try container.makeOutfitBundleUIPlans(bundle)
        } onSuccess: { plans in
            if let restore = plans.restore {
                self.commandToRun = ManualCommand(
                    title: "Restore official archive: \(bundle.displayName)",
                    command: Self.outfitRestoreCommandText(restore)
                )
            } else {
                self.lastError = UserFacingError(
                    title: "Restore unavailable",
                    message: "No backup metadata found for backup id \(bundle.backupID). Use `cybermac archive-patch list-backups` to confirm."
                )
            }
        }
    }

    func showOutfitDisableGrantCommand(for bundle: CyberMacOutfitBundle) async {
        guard let modID = bundle.optionalItemGrantModID else {
            lastError = UserFacingError(
                title: "No grant helper recorded",
                message: "This outfit bundle does not record an item-grant helper mod id. Disable manually from the Mods panel."
            )
            return
        }
        await runTask(.changingModState, failureTitle: "Outfit disable-grant command failed") { [container] in
            try container.makeOutfitBundleUIPlans(bundle)
        } onSuccess: { plans in
            if let disable = plans.disableGrant {
                self.commandToRun = ManualCommand(
                    title: "Disable item-grant helper: \(modID)",
                    command: Self.outfitDisableGrantCommandText(disable)
                )
            } else {
                self.lastError = UserFacingError(
                    title: "Disable grant unavailable",
                    message: "Could not build a disable command for \(modID)."
                )
            }
        }
    }

    private static func outfitInstallCommandText(_ plan: OutfitBundleInstallPlan) -> String {
        var lines: [String] = []
        lines.append("Bundle: \(plan.bundle.displayName) (\(plan.bundle.id))")
        lines.append("Target archive: \(plan.bundle.targetArchive)")
        lines.append("Destination: \(plan.destinationPath)")
        lines.append("Patched SHA-256: \(plan.bundle.patchedArchiveSHA256)")
        lines.append("Preflight status: \(plan.preflightStatus.rawValue)")
        if let current = plan.currentDestinationSHA256 {
            lines.append("Current destination SHA-256: \(current)")
        }
        if !plan.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in plan.warnings {
                lines.append("  - \(warning)")
            }
        }
        lines.append("")
        lines.append("Run this manually:")
        lines.append(plan.sudoCommand)
        return lines.joined(separator: "\n")
    }

    private static func outfitProfileInstallCommandText(_ plan: OutfitInstallPlan) -> String {
        [
            "Profile: \(plan.profile.displayName) (\(plan.profile.id))",
            "Target archive: \(plan.profile.targetArchiveRelativePath)",
            "Destination: \(plan.destinationArchivePath)",
            "Built archive: \(plan.builtArchivePath)",
            "Built SHA-256: \(plan.builtArchiveSHA256)",
            "",
            "Run this manually:",
            plan.manualInstallCommand,
            "",
            "Then verify:",
            plan.statusCommand,
            plan.preflightCommand
        ].joined(separator: "\n")
    }

    private static func outfitRestoreCommandText(_ plan: OutfitBundleRestorePlan) -> String {
        [
            "Bundle: \(plan.bundle.displayName) (\(plan.bundle.id))",
            "Backup ID: \(plan.bundle.backupID)",
            "Target archive: \(plan.bundle.targetArchive)",
            "",
            "Run this manually to restore the official archive:",
            plan.restoreCommand,
            "",
            "Then verify:",
            plan.verifyCommand
        ].joined(separator: "\n")
    }

    private static func outfitDisableGrantCommandText(_ plan: OutfitBundleDisableGrantPlan) -> String {
        [
            "Mod id: \(plan.modID)",
            "",
            "Run this to disable the grant helper:",
            plan.disableCommand,
            "",
            "Then re-activate so the change takes effect:",
            "  swift run cybermac activate --bundle-mode --game-app /path/to/Cyberpunk.app",
            "  # Run the printed sudo copy command(s).",
            "  swift run cybermac activate --verify --game-app /path/to/Cyberpunk.app"
        ].joined(separator: "\n")
    }

    @discardableResult
    private func refreshAfterStateChange() async -> Error? {
        do {
            let container = self.container
            let snapshot = try await BackgroundTaskRunner.run { try container.loadSnapshot() }
            try Task.checkCancellation()
            apply(snapshot: snapshot)
            return nil
        } catch is CancellationError {
            return CancellationError()
        } catch {
            lastError = UserFacingError(title: "Refresh failed", message: String(describing: error))
            return error
        }
    }

    @discardableResult
    private func runTask<Value: Sendable>(
        _ task: AppTask,
        failureTitle: String,
        refreshAfter: Bool = false,
        body: @escaping @Sendable () throws -> Value,
        onSuccess: (Value) -> Void = { _ in },
        onError: (Error) -> Void = { _ in }
    ) async -> Bool {
        guard let taskID = beginCurrentTask(task) else { return false }
        do {
            let value = try await BackgroundTaskRunner.run(body)
            try Task.checkCancellation()
            finishCurrentTask(taskID)
            onSuccess(value)
            lastError = nil
            if refreshAfter {
                await refreshAfterStateChange()
            }
            return true
        } catch is CancellationError {
            finishCurrentTask(taskID)
            return false
        } catch {
            finishCurrentTask(taskID)
            lastError = UserFacingError(title: failureTitle, message: String(describing: error))
            onError(error)
            return false
        }
    }

    private func runTaskThrowing<Value: Sendable>(
        _ task: AppTask,
        failureTitle: String,
        body: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        guard let taskID = beginCurrentTask(task) else {
            throw CancellationError()
        }
        do {
            let value = try await BackgroundTaskRunner.run(body)
            try Task.checkCancellation()
            finishCurrentTask(taskID)
            lastError = nil
            return value
        } catch let error as CancellationError {
            finishCurrentTask(taskID)
            throw error
        } catch {
            finishCurrentTask(taskID)
            lastError = UserFacingError(title: failureTitle, message: String(describing: error))
            throw error
        }
    }

    private func beginCurrentTask(_ task: AppTask) -> UUID? {
        guard currentTask == nil else { return nil }
        let id = UUID()
        currentTaskID = id
        currentTask = task
        return id
    }

    private func finishCurrentTask(_ id: UUID) {
        guard currentTaskID == id else { return }
        currentTaskID = nil
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
