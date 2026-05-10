import Foundation

public struct LaunchWorkflowVerifier: Sendable {
    private let home: CyberMacHomeManager
    private let runner: ProcessRunner
    private let runtimeImporter: RuntimeArchiveImporter
    private let stateStore: StateStore

    public init(home: CyberMacHomeManager, runner: ProcessRunner = ProcessRunner()) {
        self.home = home
        self.runner = runner
        self.runtimeImporter = RuntimeArchiveImporter(home: home)
        self.stateStore = StateStore(home: home)
    }

    public func checkFilesystemOnly() throws -> LaunchWorkflowStatus {
        try home.bootstrap()
        let redscript = runtimeImporter.redscriptStatus()
        let inputLoader = runtimeImporter.inputLoaderStatus()

        var failures: [String] = []
        if redscript.toolURL == nil { failures.append("redscript scc missing") }
        if inputLoader.toolURL == nil { failures.append("inputloader.pl missing") }
        if !FileManager.default.fileExists(atPath: home.overlayScriptsURL.path) { failures.append("overlay scripts folder missing") }
        if !redscript.quarantinedPaths.isEmpty { failures.append("redscript runtime has quarantine attributes") }
        if !inputLoader.quarantinedPaths.isEmpty { failures.append("input-loader runtime has quarantine attributes") }

        if failures.isEmpty {
            return LaunchWorkflowStatus(state: .notVerified, checkedAt: Date(), message: "Filesystem prerequisites are present. Compile verification has not been run.")
        }
        return LaunchWorkflowStatus(state: .failed, checkedAt: Date(), message: failures.joined(separator: "; "))
    }

    public func compileProbe(gameInstall: GameInstall) throws -> LaunchWorkflowStatus {
        try home.bootstrap()
        let redscript = runtimeImporter.redscriptStatus()
        guard let sccURL = redscript.toolURL else {
            let status = LaunchWorkflowStatus(state: .failed, checkedAt: Date(), message: "redscript scc missing")
            try stateStore.saveLaunchWorkflow(status)
            return status
        }

        let result = try runner.run(
            executableURL: sccURL,
            arguments: ["-compile", home.overlayScriptsURL.path],
            currentDirectoryURL: gameInstall.dataURL,
            allowFailure: true
        )

        if result.exitCode == 0 {
            let status = LaunchWorkflowStatus(state: .verified, checkedAt: Date(), message: "scc compile probe completed successfully")
            try stateStore.saveLaunchWorkflow(status)
            return status
        }

        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = [stderr, stdout].filter { !$0.isEmpty }.joined(separator: "\n")
        let status = LaunchWorkflowStatus(state: .failed, checkedAt: Date(), message: detail.isEmpty ? "scc compile probe failed with exit code \(result.exitCode)" : detail)
        try stateStore.saveLaunchWorkflow(status)
        return status
    }

    public func currentStoredStatus() -> LaunchWorkflowStatus {
        stateStore.load().launchWorkflow ?? LaunchWorkflowStatus(state: .notVerified, checkedAt: Date(), message: "Launch workflow has not been verified")
    }
}
