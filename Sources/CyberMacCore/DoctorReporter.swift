import Foundation

public struct DoctorReporter: Sendable {
    private let home: CyberMacHomeManager
    private let detector: GameInstallDetector
    private let runtimeImporter: RuntimeArchiveImporter
    private let resolver: BundleStateResolver
    private let stateStore: StateStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.detector = GameInstallDetector()
        self.runtimeImporter = RuntimeArchiveImporter(home: home)
        self.resolver = BundleStateResolver(home: home)
        self.stateStore = StateStore(home: home)
    }

    public func makeReport(preferredAppPath: String? = nil, developerMode: Bool = false) throws -> DoctorReport {
        try home.bootstrap()

        let redscriptStatus = runtimeImporter.redscriptStatus()
        let inputLoaderStatus = runtimeImporter.inputLoaderStatus()
        let runtime = RuntimeSummary(
            redscript: Self.runtimeToolSummary(redscriptStatus),
            inputLoader: Self.runtimeToolSummary(inputLoaderStatus)
        )

        var warnings = buildRuntimeWarnings(redscript: redscriptStatus, inputLoader: inputLoaderStatus)
        if let stateWarning = stateStore.corruptionMessage() {
            warnings.append(DoctorWarning(code: "state-corrupt", message: stateWarning))
        }

        let game: GameInstall
        do {
            game = try detector.detect(preferredAppPath: preferredAppPath)
        } catch {
            warnings.append(DoctorWarning(code: "game-missing", message: String(describing: error)))
            let inputStatus = try? InputMappingManager(home: home).status(gameInstall: nil)
            return DoctorReport(
                game: GameInstallSummary(
                    found: false,
                    edition: nil,
                    storefront: Storefront.unknown.rawValue,
                    appPath: nil,
                    dataPath: nil,
                    bundleTarget: nil,
                    executableFound: false,
                    dataPathFound: false
                ),
                runtime: runtime,
                cache: CacheSummary(
                    baseSnapshotPresent: false,
                    currentBundle: .missing,
                    bundleTarget: nil,
                    bundleCacheSHA256: nil,
                    baseSnapshotSHA256: nil,
                    overlayMirrorPresent: FileManager.default.fileExists(atPath: home.overlayCacheURL.appendingPathComponent("final.redscripts").path)
                ),
                activation: ActivationSummary(
                    state: .requiresBundleActivation,
                    enabledMods: 0,
                    activeModIDs: [],
                    bundleChangedSinceLastActivation: false,
                    manualPrivilegedWriteRequired: true,
                    safeToProceedToActivation: false,
                    nextStep: "Choose a supported Cyberpunk 2077 app."
                ),
                inputMappings: inputStatus,
                warnings: warnings,
                legacyProbe: developerMode ? legacyProbe() : nil
            )
        }

        let bundleSnapshot = try resolver.snapshot(gameInstall: game)
        let inputStatus = try? InputMappingManager(home: home).status(gameInstall: game)
        if !bundleSnapshot.bundle.overlayMirrorPresent {
            warnings.append(DoctorWarning(code: "overlay-mirror-missing", message: "Overlay cache mirror is missing. Activation will recreate it from the base snapshot."))
        }
        if bundleSnapshot.bundle.baseSnapshotSHA256 == nil {
            warnings.append(DoctorWarning(code: "base-cache-missing", message: "Base cache snapshot is missing. Run cybermac refresh-base-cache before activation."))
        }
        if bundleSnapshot.bundle.kind == .externallyChanged {
            warnings.append(DoctorWarning(code: "bundle-external", message: "Bundle final.redscripts does not match the base snapshot or last CyberMac activation."))
        } else if bundleSnapshot.bundle.kind == .missing {
            warnings.append(DoctorWarning(code: "bundle-missing", message: "Bundle final.redscripts is missing."))
        }

        return DoctorReport(
            game: GameInstallSummary(
                found: true,
                edition: game.displayName,
                storefront: game.storefront.rawValue,
                appPath: game.appURL.path,
                dataPath: game.dataURL.path,
                bundleTarget: bundleSnapshot.bundle.targetPath,
                executableFound: FileManager.default.fileExists(atPath: game.executableURL.path),
                dataPathFound: FileManager.default.fileExists(atPath: game.dataURL.path)
            ),
            runtime: runtime,
            cache: CacheSummary(
                baseSnapshotPresent: bundleSnapshot.bundle.baseSnapshotSHA256 != nil,
                currentBundle: bundleSnapshot.bundle.kind,
                bundleTarget: bundleSnapshot.bundle.targetPath,
                bundleCacheSHA256: bundleSnapshot.bundle.currentSHA256,
                baseSnapshotSHA256: bundleSnapshot.bundle.baseSnapshotSHA256,
                overlayMirrorPresent: bundleSnapshot.bundle.overlayMirrorPresent
            ),
            activation: ActivationSummary(
                state: bundleSnapshot.activationState,
                enabledMods: bundleSnapshot.enabledMods.count,
                activeModIDs: bundleSnapshot.activeModIDs,
                bundleChangedSinceLastActivation: bundleSnapshot.bundleChangedSinceLastActivation,
                manualPrivilegedWriteRequired: true,
                safeToProceedToActivation: !bundleSnapshot.activationBlocked && bundleSnapshot.bundle.baseSnapshotSHA256 != nil,
                nextStep: bundleSnapshot.nextStep
            ),
            inputMappings: inputStatus,
            warnings: warnings,
            legacyProbe: developerMode ? legacyProbe() : nil
        )
    }

    private static func runtimeToolSummary(_ status: RuntimeStatus) -> RuntimeToolSummary {
        RuntimeToolSummary(
            installed: status.installed,
            toolFound: status.toolURL != nil,
            version: status.version,
            rootPath: status.rootURL.path,
            toolPath: status.toolURL?.path,
            quarantinedPathCount: status.quarantinedPaths.count,
            notes: status.notes
        )
    }

    private func buildRuntimeWarnings(redscript: RuntimeStatus, inputLoader: RuntimeStatus) -> [DoctorWarning] {
        var warnings: [DoctorWarning] = []
        for note in redscript.notes {
            warnings.append(DoctorWarning(code: "redscript", message: note))
        }
        for note in inputLoader.notes {
            warnings.append(DoctorWarning(code: "input-loader", message: note))
        }
        if !redscript.quarantinedPaths.isEmpty {
            warnings.append(DoctorWarning(code: "redscript-quarantine", message: "redscript has \(redscript.quarantinedPaths.count) quarantined path(s)."))
        }
        if !inputLoader.quarantinedPaths.isEmpty {
            warnings.append(DoctorWarning(code: "input-loader-quarantine", message: "input-loader has \(inputLoader.quarantinedPaths.count) quarantined path(s)."))
        }
        return warnings
    }

    private func legacyProbe() -> LegacyProbeSummary {
        let launch = LaunchWorkflowVerifier(home: home).currentStoredStatus()
        return LegacyProbeSummary(
            sidecarOnlyLaunchProbeEnabled: false,
            state: launch.state.rawValue,
            message: launch.message,
            reason: "replaced by cache-mirror activation pipeline"
        )
    }
}

public enum DoctorReportFormatter {
    public static func format(_ report: DoctorReport, developerMode: Bool = false) -> String {
        var lines: [String] = []
        lines.append("CyberMac doctor")
        lines.append("")
        lines.append("Game")
        lines.append("  Found: \(yesNo(report.game.found))")
        if let edition = report.game.edition {
            lines.append("  Edition: \(edition)")
        }
        lines.append("  Storefront: \(report.game.storefront)")
        if let appPath = report.game.appPath {
            lines.append("  App path: \(appPath)")
        }
        if let dataPath = report.game.dataPath {
            lines.append("  Data path: \(dataPath)")
        }
        if let bundleTarget = report.game.bundleTarget {
            lines.append("  Bundle target: \(bundleTarget)")
        }
        lines.append("")
        lines.append("Runtime")
        lines.append("  redscript: \(report.runtime.redscript.installed ? "installed" : "missing")")
        lines.append("  scc: \(report.runtime.redscript.toolFound ? "found" : "missing")\(versionSuffix(report.runtime.redscript.version))")
        lines.append("  input-loader: \(report.runtime.inputLoader.installed ? "installed" : "missing")")
        for note in report.runtime.inputLoader.notes {
            lines.append("  input-loader warning: \(note)")
        }
        for note in report.runtime.redscript.notes {
            lines.append("  redscript warning: \(note)")
        }
        lines.append("")
        lines.append("Cache")
        lines.append("  Base snapshot: \(report.cache.baseSnapshotPresent ? "present" : "missing")")
        lines.append("  Current bundle: \(report.cache.currentBundle.displayName)")
        if let bundleHash = report.cache.bundleCacheSHA256 {
            lines.append("  Bundle cache SHA-256: \(bundleHash)")
        }
        if let baseHash = report.cache.baseSnapshotSHA256 {
            lines.append("  Base snapshot SHA-256: \(baseHash)")
        }
        lines.append("  Overlay mirror: \(report.cache.overlayMirrorPresent ? "present" : "missing")")
        lines.append("")
        lines.append("Activation")
        lines.append("  State: \(report.activation.state.rawValue)")
        lines.append("  Enabled mods: \(report.activation.enabledMods)")
        lines.append("  Bundle changed since last activation: \(report.activation.bundleChangedSinceLastActivation ? "yes" : "no")")
        lines.append("  Manual privileged write: \(report.activation.manualPrivilegedWriteRequired ? "required for future activations" : "not required")")
        lines.append("  Safe to proceed to activation: \(yesNo(report.activation.safeToProceedToActivation))")
        lines.append("  Next step: \(report.activation.nextStep)")
        if let input = report.inputMappings {
            lines.append("")
            lines.append("Input mappings")
            lines.append("  Required mods: \(input.requiredModCount)")
            lines.append("  Pending input patch: \(input.pendingInputPatch?.id ?? "none")")
            lines.append("  Active input patch mods: \(input.activeInputPatchModIDs.isEmpty ? "none" : input.activeInputPatchModIDs.joined(separator: ", "))")
            lines.append("  Target inputContexts: \(input.targetInputContextsPath ?? "unknown")")
            lines.append("  Target inputUserMappings: \(input.targetInputUserMappingsPath ?? "unknown")")
            lines.append("  Next step: \(input.nextStep)")
        }

        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings")
            for warning in report.warnings {
                lines.append("  - \(warning.message)")
            }
        }

        if developerMode, let legacy = report.legacyProbe {
            lines.append("")
            lines.append("Legacy probe")
            lines.append("  Sidecar-only launch probe: \(legacy.sidecarOnlyLaunchProbeEnabled ? "enabled" : "disabled")")
            lines.append("  Stored state: \(legacy.state)")
            lines.append("  Stored message: \(legacy.message)")
            lines.append("  Reason: \(legacy.reason)")
        }

        return lines.joined(separator: "\n")
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func versionSuffix(_ version: String?) -> String {
        guard let version else { return "" }
        return ", \(version)"
    }
}
