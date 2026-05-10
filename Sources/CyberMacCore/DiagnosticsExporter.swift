import Foundation

public struct DiagnosticsExporter: Sendable {
    private let home: CyberMacHomeManager
    private let runtimeImporter: RuntimeArchiveImporter
    private let manifestStore: ManifestStore
    private let launchVerifier: LaunchWorkflowVerifier

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.runtimeImporter = RuntimeArchiveImporter(home: home)
        self.manifestStore = ManifestStore(home: home)
        self.launchVerifier = LaunchWorkflowVerifier(home: home)
    }

    public func makeReport(gameInstall: GameInstall?) -> DiagnosticReport {
        let redscript = runtimeImporter.redscriptStatus()
        let inputLoader = runtimeImporter.inputLoaderStatus()
        let launch = launchVerifier.currentStoredStatus()
        let state = StateStore(home: home).load()
        let installedMods = (try? manifestStore.list()) ?? []

        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let arch = Self.machineArchitecture()

        return DiagnosticReport(
            generatedAt: Date(),
            cyberMacVersion: "0.1.0",
            macOS: osString,
            architecture: arch,
            gameFound: gameInstall != nil,
            storefront: gameInstall?.storefront.rawValue ?? Storefront.unknown.rawValue,
            gameAppPath: gameInstall.map { PathSafety.redactUserPath($0.appURL.path) },
            executableExists: gameInstall.map { FileManager.default.fileExists(atPath: $0.executableURL.path) } ?? false,
            dataPathExists: gameInstall.map { FileManager.default.fileExists(atPath: $0.dataURL.path) } ?? false,
            cyberMacHome: PathSafety.redactUserPath(home.homeURL.path),
            redscriptRuntime: runtimeSummary(redscript),
            inputLoaderRuntime: runtimeSummary(inputLoader),
            launchWorkflow: "\(launch.state.rawValue): \(launch.message)",
            activationState: state.activationState.rawValue,
            bundleChangedSinceLastActivation: state.bundleChangedSinceLastActivation,
            activeModIDs: state.activeModIDs,
            baseCacheSnapshotID: state.baseCacheSnapshotID,
            lastBackupID: state.lastBackupID,
            installedManagedMods: installedMods.filter { $0.status != .uninstalled }.count,
            notes: buildNotes(redscript: redscript, inputLoader: inputLoader)
        )
    }

    public func export(gameInstall: GameInstall?) throws -> URL {
        try home.bootstrap()
        let report = makeReport(gameInstall: gameInstall)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = home.diagnosticsURL.appendingPathComponent("diagnostic_\(stamp).json")
        let data = try JSONEncoder.cybermac.encode(report)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func runtimeSummary(_ status: RuntimeStatus) -> String {
        if !status.installed { return "missing" }
        var parts = ["installed"]
        if let version = status.version {
            parts.append("version \(version)")
        }
        if status.toolURL == nil {
            parts.append("required tool missing")
        }
        if !status.quarantinedPaths.isEmpty {
            parts.append("quarantined")
        }
        return parts.joined(separator: ", ")
    }

    private func buildNotes(redscript: RuntimeStatus, inputLoader: RuntimeStatus) -> [String] {
        var notes: [String] = []
        notes.append(contentsOf: redscript.notes.map { "redscript: \($0)" })
        notes.append(contentsOf: inputLoader.notes.map { "input-loader: \($0)" })
        if let message = StateStore(home: home).corruptionMessage() {
            notes.append(message)
        }
        if !redscript.quarantinedPaths.isEmpty {
            notes.append("redscript has \(redscript.quarantinedPaths.count) quarantined path(s)")
        }
        if !inputLoader.quarantinedPaths.isEmpty {
            notes.append("input-loader has \(inputLoader.quarantinedPaths.count) quarantined path(s)")
        }
        return notes
    }

    private static func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
