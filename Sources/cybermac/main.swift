import Foundation
import CyberMacCore

let app = CyberMacCLI(arguments: Array(CommandLine.arguments.dropFirst()))
app.run()

struct CyberMacCLI {
    let arguments: [String]
    let home = CyberMacHomeManager()

    func run() {
        do {
            try dispatch()
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    private func dispatch() throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }

        switch command {
        case "help", "--help", "-h":
            printHelp()
        case "init-home":
            try initHome()
        case "doctor":
            try doctor()
        case "import-redscript":
            try importRuntime(kind: .redscript)
        case "import-input-loader":
            try importRuntime(kind: .inputLoader)
        case "clear-quarantine":
            try clearQuarantine()
        case "probe-redscript":
            try probeRedscript()
        case "generate-launch-script":
            try generateLaunchScript()
        case "launch-test":
            try launchTest()
        case "scan":
            try scan()
        case "install":
            try install()
        case "cache-status":
            try cacheStatus()
        case "refresh-base-cache":
            try refreshBaseCache()
        case "activate":
            try activate()
        case "list-backups":
            try listBackups()
        case "restore":
            try restore()
        case "list-mods":
            try listMods()
        case "disable":
            try changeModState(action: .disable)
        case "enable":
            try changeModState(action: .enable)
        case "uninstall":
            try changeModState(action: .uninstall)
        case "diagnostics":
            try diagnostics()
        default:
            throw CyberMacError.invalidInput("Unknown command: \(command). Run `cybermac help`.")
        }
    }

    private func printHelp() {
        print("""
        CyberMac 0.1.0 core harness

        Usage:
          cybermac init-home
          cybermac doctor [--game-app /path/to/Cyberpunk.app]
          cybermac import-redscript /path/to/redscript-macos.zip
          cybermac import-input-loader /path/to/input-loader-macos.zip
          cybermac clear-quarantine
          cybermac probe-redscript [--compile] [--game-app /path/to/Cyberpunk.app]
          cybermac generate-launch-script [--game-app /path/to/Cyberpunk.app]
          cybermac launch-test [--run]
          cybermac scan /path/to/mod.zip
          cybermac install /path/to/mod.zip [--game-app /path/to/Cyberpunk.app]
          cybermac cache-status [--game-app /path/to/Cyberpunk.app]
          cybermac refresh-base-cache [--dry-run] [--game-app /path/to/Cyberpunk.app]
          cybermac activate --dry-run [--game-app /path/to/Cyberpunk.app]
          cybermac activate --bundle-mode [--game-app /path/to/Cyberpunk.app]
          cybermac activate --verify [--game-app /path/to/Cyberpunk.app]
          cybermac list-backups
          cybermac restore [--dry-run|--verify] <backup-id> [--game-app /path/to/Cyberpunk.app]
          cybermac list-mods
          cybermac disable <mod-id>
          cybermac enable <mod-id>
          cybermac uninstall <mod-id>
          cybermac diagnostics [--game-app /path/to/Cyberpunk.app]

        v0.1 keeps installs in the CyberMac sidecar. Bundle activation is experimental and prints sudo commands for the user to run manually.
        """)
    }

    private func initHome() throws {
        try home.bootstrap()
        print("CyberMac home ready: \(PathSafety.redactUserPath(home.homeURL.path))")
        print("Overlay scripts: \(PathSafety.redactUserPath(home.overlayScriptsURL.path))")
    }

    private func doctor() throws {
        try home.bootstrap()
        let detector = GameInstallDetector()
        let game = try detector.detect(preferredAppPath: optionValue("--game-app"))

        print("Game found: yes")
        print("Display name: \(game.displayName)")
        print("Storefront: \(game.storefront.rawValue)")
        print("App path: \(game.appURL.path)")
        print("Executable found: \(FileManager.default.fileExists(atPath: game.executableURL.path) ? "yes" : "no")")
        print("Data path found: \(FileManager.default.fileExists(atPath: game.dataURL.path) ? "yes" : "no")")
        print("archive/Mac found: \(game.archiveMacURL == nil ? "no" : "yes")")
        print("r6 found: \(game.r6URL == nil ? "no" : "yes")")
        print("Bundle write test: skipped by design")
        print("CyberMac app support path: \(PathSafety.redactUserPath(home.homeURL.path))")
        print("Overlay scripts path: \(PathSafety.redactUserPath(home.overlayScriptsURL.path))")

        let runtimes = RuntimeArchiveImporter(home: home)
        printRuntimeStatus(runtimes.redscriptStatus())
        printRuntimeStatus(runtimes.inputLoaderStatus())

        let launch = LaunchWorkflowVerifier(home: home).currentStoredStatus()
        print("Launch workflow: \(launch.state.rawValue) - \(launch.message)")
        if let stateWarning = StateStore(home: home).corruptionMessage() {
            print("State warning: \(stateWarning)")
        }
    }

    private func importRuntime(kind: RuntimeKind) throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing zip path")
        }
        try home.bootstrap()
        let zipURL = PathSafety.expandedURL(from: arguments[1])
        let importer = RuntimeArchiveImporter(home: home)
        let status: RuntimeStatus
        switch kind {
        case .redscript:
            status = try importer.importRedscript(zipURL: zipURL)
        case .inputLoader:
            status = try importer.importInputLoader(zipURL: zipURL)
        }
        printRuntimeStatus(status)
        if !status.quarantinedPaths.isEmpty {
            print("Quarantine detected. Run: cybermac clear-quarantine")
        }
    }

    private func clearQuarantine() throws {
        try home.bootstrap()
        let manager = QuarantineManager()
        for root in [home.redscriptRuntimeURL, home.inputLoaderRuntimeURL] {
            if FileManager.default.fileExists(atPath: root.path) {
                let result = try manager.clearQuarantine(under: root)
                print("Cleared quarantine under \(PathSafety.redactUserPath(root.path)) with exit code \(result.exitCode)")
            }
        }
    }

    private func probeRedscript() throws {
        try home.bootstrap()
        let verifier = LaunchWorkflowVerifier(home: home)
        if hasFlag("--compile") {
            let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
            let status = try verifier.compileProbe(gameInstall: game)
            print("Launch workflow: \(status.state.rawValue)")
            print(status.message)
        } else {
            let status = try verifier.checkFilesystemOnly()
            print("Filesystem probe: \(status.state.rawValue)")
            print(status.message)
            print("Run `cybermac probe-redscript --compile` after importing runtimes to test scc compilation.")
        }
    }

    private func generateLaunchScript() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let url = try LaunchScriptGenerator(home: home).generate(gameInstall: game)
        print("Generated launch script: \(PathSafety.redactUserPath(url.path))")
    }

    private func launchTest() throws {
        try home.bootstrap()
        guard FileManager.default.fileExists(atPath: home.launchScriptURL.path) else {
            throw CyberMacError.notFound("Launch script missing. Run `cybermac generate-launch-script` first.")
        }

        if hasFlag("--run") {
            let runner = ProcessRunner()
            _ = try runner.run(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: [home.launchScriptURL.path],
                allowFailure: false
            )
        } else {
            print("Dry run. Launch script exists:")
            print(PathSafety.redactUserPath(home.launchScriptURL.path))
            print("Run `cybermac launch-test --run` to execute it.")
        }
    }

    private func scan() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing mod zip path")
        }
        try home.bootstrap()
        let zipURL = PathSafety.expandedURL(from: arguments[1])
        let result = try ModArchiveScanner().scan(zipURL: zipURL)
        printScanResult(result)
    }

    private func install() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing mod zip path")
        }
        try home.bootstrap()
        let zipURL = PathSafety.expandedURL(from: arguments[1])
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let manifest = try RedscriptModInstaller(home: home).install(zipURL: zipURL, gameInstall: game)
        print("Mod installed into CyberMac sidecar.")
        print("Installed: \(manifest.displayName)")
        print("ID: \(manifest.id)")
        print("Status: \(manifest.status.rawValue), inactive")
        print("Reason: bundle activation has not been run.")
        print("Next: cybermac activate --dry-run")
    }

    private func cacheStatus() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let activation = ActivationManager(home: home)
        let state = try activation.updateBundleChangedFlag(gameInstall: game)
        let status = try BaseCacheManager(home: home).status(gameInstall: game)
        print("Game app: \(status.fingerprint.appPath)")
        print("Bundle target: \(status.bundleCacheURL.path)")
        print("Game fingerprint: \(status.fingerprint.id)")
        print("Bundle cache SHA-256: \(status.bundleCacheSHA256)")
        print("Base snapshot: \(status.snapshot == nil ? "missing" : "present")")
        if let snapshot = status.snapshot {
            print("Base snapshot SHA-256: \(snapshot.bundleCacheSHA256)")
        }
        let currentBundle: String
        if status.snapshot?.bundleCacheSHA256 == status.bundleCacheSHA256 {
            currentBundle = "vanilla"
        } else if state.activeBundleTargetHashes[status.bundleCacheURL.path] == status.bundleCacheSHA256 {
            currentBundle = "CyberMac active"
        } else if state.pendingExpectedHashes[status.bundleCacheURL.path] == status.bundleCacheSHA256 {
            currentBundle = "pending activation"
        } else {
            currentBundle = "unknown"
        }
        print("Current bundle: \(currentBundle)")
        print("Overlay mirror: \(status.mirrorExists ? "present" : "missing")")
        print("Activation state: \(state.activationState.rawValue)")
        print("Bundle changed since last activation: \(state.bundleChangedSinceLastActivation ? "yes" : "no")")
        if let reason = status.refusedRefreshReason {
            print("Refresh warning: \(reason)")
        }
    }

    private func refreshBaseCache() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let dryRun = hasFlag("--dry-run")
        let result = try BaseCacheManager(home: home).refreshBaseCache(gameInstall: game, dryRun: dryRun)
        print(dryRun ? "Base cache refresh dry run." : "Base cache snapshot refreshed.")
        print("Snapshot ID: \(result.snapshotID)")
        print("Snapshot path: \(result.snapshotURL.path)")
        print("Bundle cache SHA-256: \(result.metadata.bundleCacheSHA256)")
        print("Size: \(result.metadata.sizeBytes) bytes")
        print("Written: \(result.didWrite ? "yes" : "no")")
    }

    private func activate() throws {
        try home.bootstrap()
        let modes = ["--dry-run", "--bundle-mode", "--verify"].filter(hasFlag)
        guard modes.count == 1 else {
            throw CyberMacError.invalidInput("Use exactly one activation mode: --dry-run, --bundle-mode, or --verify")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let manager = ActivationManager(home: home)
        if hasFlag("--dry-run") {
            let result = try manager.dryRun(gameInstall: game)
            print("Game app: \(result.gameAppPath)")
            print("Bundle target: \(result.bundleTarget)")
            print("Base cache snapshot: \(result.baseSnapshotID)")
            print("Enabled mod ids: \(result.enabledModIDs.isEmpty ? "(none)" : result.enabledModIDs.joined(separator: ", "))")
            print("Compile command: \(result.compileCommand)")
            print("Temp output path: \(result.tempOutputPath)")
            print("Backup destination: \(result.backupDestination)")
            print("Sudo command shape: \(result.sudoCommandShape)")
        } else if hasFlag("--bundle-mode") {
            let result = try manager.activateBundleMode(gameInstall: game)
            print("Activation output generated.")
            print("Bundle target: \(result.bundleTarget)")
            print("Temp output path: \(result.tempOutputPath)")
            print("Generated SHA-256: \(result.generatedSHA256)")
            print("Backup ID: \(result.backup.id)")
            print("Backup prior state: \(result.backup.priorState.rawValue)")
            print("Run this command manually:")
            print(result.sudoCommand)
            print("Then verify:")
            print(result.verifyCommand)
        } else {
            let result = try manager.verify(gameInstall: game)
            if result.matched {
                print("Activation verified: active")
                print("Bundle target: \(result.bundleTarget)")
                print("SHA-256: \(result.actualSHA256 ?? "")")
            } else {
                print("Activation verify failed: outOfSync")
                print("Bundle target: \(result.bundleTarget)")
                print("Expected SHA-256: \(result.expectedSHA256 ?? "missing")")
                print("Actual SHA-256: \(result.actualSHA256 ?? "missing")")
            }
        }
    }

    private func listBackups() throws {
        try home.bootstrap()
        let backups = try BundleBackupManager(home: home).list()
        if backups.isEmpty {
            print("No CyberMac bundle backups found.")
            return
        }
        for backup in backups {
            print("\(backup.id) | \(backup.createdAt) | \(backup.priorState.rawValue) | \(backup.sha256 ?? "absent") | \(backup.gameFingerprintID)")
        }
    }

    private func restore() throws {
        try home.bootstrap()
        let ids = positionalArguments(after: "restore", excludingFlags: ["--dry-run", "--verify"])
        guard let id = ids.first else {
            throw CyberMacError.invalidInput("Missing backup id")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let manager = BundleBackupManager(home: home)
        if hasFlag("--verify") {
            let matched = try manager.verifyRestore(id: id, gameInstall: game)
            print(matched ? "Restore verified." : "Restore verify failed.")
        } else {
            let command = try manager.restoreCommand(id: id, gameInstall: game)
            print(hasFlag("--dry-run") ? "Restore dry run." : "Run this restore command manually:")
            print(command)
            print("Then verify:")
            print("swift run cybermac restore --verify \(id)")
        }
    }

    private func listMods() throws {
        try home.bootstrap()
        let mods = try ModStateManager(home: home).list()
        if mods.isEmpty {
            print("No CyberMac-managed mods installed.")
            return
        }
        for mod in mods {
            print("\(mod.id) | \(mod.displayName) | \(mod.status.rawValue) | \(mod.type.rawValue)")
        }
    }

    private enum ModAction { case disable, enable, uninstall }

    private func changeModState(action: ModAction) throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing mod id")
        }
        let id = arguments[1]
        let manager = ModStateManager(home: home)
        let manifest: InstalledModManifest
        switch action {
        case .disable:
            manifest = try manager.disable(id: id)
        case .enable:
            manifest = try manager.enable(id: id)
        case .uninstall:
            manifest = try manager.uninstall(id: id)
        }
        print("\(manifest.displayName): \(manifest.status.rawValue)")
    }

    private func diagnostics() throws {
        try home.bootstrap()
        let game = try? GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let url = try DiagnosticsExporter(home: home).export(gameInstall: game)
        print("Diagnostic report exported: \(PathSafety.redactUserPath(url.path))")
    }

    private func printRuntimeStatus(_ status: RuntimeStatus) {
        print("\(status.kind.rawValue): \(status.installed ? "installed" : "missing")")
        print("  root: \(PathSafety.redactUserPath(status.rootURL.path))")
        print("  tool: \(status.toolURL.map { PathSafety.redactUserPath($0.path) } ?? "missing")")
        print("  version: \(status.version ?? "unknown")")
        print("  quarantined paths: \(status.quarantinedPaths.count)")
        for note in status.notes {
            print("  note: \(note)")
        }
    }

    private func printScanResult(_ result: ModScanResult) {
        print("Name: \(result.displayName)")
        print("Status: \(result.compatibilityStatus.rawValue)")
        print("Sidecar installable: \(result.sidecarInstallable ? "yes" : "no")")
        if let reason = result.installBlockReason {
            print("Install block: \(reason)")
        }
        print("Type: \(result.kind.rawValue)")
        print("Reasons:")
        for reason in result.reasons {
            print("- \(reason)")
        }
        if !result.findings.isEmpty {
            print("Findings:")
            for finding in result.findings {
                print("- \(finding.path): \(finding.reason)")
            }
        }
        if !result.redscriptEntries.isEmpty {
            print("Redscript files:")
            for entry in result.redscriptEntries {
                print("- \(entry)")
            }
        }
        if !result.archiveEntries.isEmpty {
            print("Archive files:")
            for entry in result.archiveEntries {
                print("- \(entry)")
            }
        }
    }

    private func optionValue(_ name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func hasFlag(_ name: String) -> Bool {
        arguments.contains(name)
    }

    private func positionalArguments(after command: String, excludingFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst() {
            if skipNext {
                skipNext = false
                continue
            }
            if argument == "--game-app" {
                skipNext = true
                continue
            }
            if excludingFlags.contains(argument) || argument == command {
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }
}
