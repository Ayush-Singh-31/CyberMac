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
        } catch let exit as SilentExit {
            Foundation.exit(exit.code)
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
        case "launch-game":
            try launchGame()
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
        case "input-status":
            try inputStatus()
        case "prepare-input-patch":
            try prepareInputPatch()
        case "verify-input-patch":
            try verifyInputPatch()
        case "list-input-backups":
            try listInputBackups()
        case "restore-input-config":
            try restoreInputConfig()
        case "list-backups":
            try listBackups()
        case "restore":
            try restore()
        case "restore-vanilla":
            try restoreVanilla()
        case "list-mods":
            try listMods()
        case "disable":
            try changeModState(action: .disable)
        case "enable":
            try changeModState(action: .enable)
        case "uninstall":
            try changeModState(action: .uninstall)
        case "delete-mod":
            try deleteMod()
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
          cybermac launch-game [--vanilla-ok|--require-active] [--show-command] [--game-app /path/to/Cyberpunk.app]
          cybermac scan /path/to/mod.zip
          cybermac install /path/to/mod.zip [--game-app /path/to/Cyberpunk.app]
          cybermac cache-status [--game-app /path/to/Cyberpunk.app]
          cybermac refresh-base-cache [--dry-run] [--game-app /path/to/Cyberpunk.app]
          cybermac activate --dry-run [--game-app /path/to/Cyberpunk.app]
          cybermac activate --bundle-mode [--game-app /path/to/Cyberpunk.app]
          cybermac activate --verify [--game-app /path/to/Cyberpunk.app]
          cybermac input-status [--game-app /path/to/Cyberpunk.app]
          cybermac prepare-input-patch [<mod-id>] [--game-app /path/to/Cyberpunk.app]
          cybermac verify-input-patch [--game-app /path/to/Cyberpunk.app]
          cybermac list-input-backups
          cybermac restore-input-config [--dry-run|--verify] <backup-id> [--game-app /path/to/Cyberpunk.app]
          cybermac list-backups
          cybermac restore [--dry-run|--verify] <backup-id> [--game-app /path/to/Cyberpunk.app]
          cybermac restore-vanilla [--dry-run|--verify] [--game-app /path/to/Cyberpunk.app]
          cybermac list-mods
          cybermac disable <mod-id>
          cybermac enable <mod-id>
          cybermac uninstall <mod-id>
          cybermac delete-mod <mod-id>
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
        let developerMode = hasFlag("--developer") || hasFlag("--developer-mode")
        let report = try DoctorReporter(home: home).makeReport(preferredAppPath: optionValue("--game-app"), developerMode: developerMode)
        print(DoctorReportFormatter.format(report, developerMode: developerMode))
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

    private func launchGame() throws {
        try home.bootstrap()
        let policy: LaunchPolicy
        if hasFlag("--vanilla-ok") && hasFlag("--require-active") {
            throw CyberMacError.invalidInput("Use only one launch policy: --vanilla-ok or --require-active")
        } else if hasFlag("--vanilla-ok") {
            policy = .vanillaOK
        } else if hasFlag("--require-active") {
            policy = .requireActive
        } else {
            policy = .default
        }

        let manager = LaunchGameManager(home: home)
        let plan = try manager.makeLaunchPlan(policy: policy, preferredAppPath: optionValue("--game-app"))
        if hasFlag("--show-command") {
            print(plan.commandPreview)
            return
        }

        guard plan.canLaunch else {
            printLaunchRefusal(plan)
            throw SilentExit(code: 1)
        }

        print("Launching Cyberpunk 2077.")
        print("Current bundle: \(plan.bundleKind.displayName)")
        print("Enabled mods: \(plan.enabledMods.count)")
        for warning in plan.warnings {
            print("Warning: \(warning)")
        }
        try manager.launch(plan: plan)
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
        if manifest.requiresInputMappingPatch {
            print("Input patch required: yes")
            print("Next: cybermac activate --dry-run, then cybermac prepare-input-patch \(manifest.id)")
        } else {
            print("Next: cybermac activate --dry-run")
        }
    }

    private func cacheStatus() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let snapshot = try BundleStateResolver(home: home).snapshot(gameInstall: game)
        let fingerprint = try BaseCacheManager(home: home).fingerprint(gameInstall: game)
        print("Game app: \(fingerprint.appPath)")
        print("Bundle target: \(snapshot.bundle.targetPath)")
        print("Game fingerprint: \(fingerprint.id)")
        print("Bundle cache SHA-256: \(snapshot.bundle.currentSHA256 ?? "missing")")
        print("Base snapshot: \(snapshot.bundle.baseSnapshotSHA256 == nil ? "missing" : "present")")
        if let baseHash = snapshot.bundle.baseSnapshotSHA256 {
            print("Base snapshot SHA-256: \(baseHash)")
        }
        print("Current bundle: \(snapshot.bundle.kind.displayName)")
        print("Overlay mirror: \(snapshot.bundle.overlayMirrorPresent ? "present" : "missing")")
        print("Enabled mods: \(snapshot.enabledMods.count)")
        print("Activation state: \(snapshot.activationState.rawValue)")
        print("Bundle changed since last activation: \(snapshot.bundleChangedSinceLastActivation ? "yes" : "no")")
        print("Next step: \(snapshot.nextStep)")
        if snapshot.bundle.kind == .cyberMacActive {
            let status = try? BaseCacheManager(home: home).status(gameInstall: game)
            if let reason = status?.refusedRefreshReason {
                print("Refresh warning: \(reason)")
            }
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

    private func inputStatus() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let status = try InputMappingManager(home: home).status(gameInstall: game)
        print("Input mappings")
        print("  Required mods: \(status.requiredModCount)")
        print("  Active input patch mods: \(status.activeInputPatchModIDs.count)")
        print("  Pending input patch: \(status.pendingInputPatch?.id ?? "none")")
        print("  Target inputContexts: \(status.targetInputContextsPath ?? "unknown")")
        print("  Target inputUserMappings: \(status.targetInputUserMappingsPath ?? "unknown")")
        print("  Next step: \(status.nextStep)")
        if !status.requiredMods.isEmpty {
            print("Required mod IDs:")
            for mod in status.requiredMods {
                print("- \(mod.id)")
            }
        }
    }

    private func prepareInputPatch() throws {
        try home.bootstrap()
        let ids = positionalArguments(after: "prepare-input-patch", excludingFlags: [])
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let result = try InputMappingManager(home: home).preparePatch(gameInstall: game, modIDs: ids.isEmpty ? nil : [ids[0]])
        print("Input patch prepared.")
        print("Mods:")
        for id in result.modIDs {
            print("- \(id)")
        }
        print("")
        print("Generated files:")
        print("- \(result.generatedContextPath)")
        print("- \(result.generatedUserMappingsPath)")
        print("")
        print("Backup ID:")
        print(result.backupID)
        print("")
        print("Run these commands manually:")
        for command in result.sudoCommands {
            print(command)
        }
        print("")
        print("Then verify:")
        print(result.verifyCommand)
    }

    private func verifyInputPatch() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let result = try InputMappingManager(home: home).verifyPatch(gameInstall: game)
        if result.matched {
            print("Input patch verified: active")
            print("Patched files:")
            for target in result.expectedHashes.keys.sorted() {
                print("- \(URL(fileURLWithPath: target).lastPathComponent)")
            }
        } else {
            print("Input patch verify failed.")
            print("")
            for target in result.mismatches {
                print("Target:")
                print(target)
                print("Expected:")
                print(result.expectedHashes[target] ?? "missing")
                print("Actual:")
                print(result.actualHashes[target] ?? "missing")
                print("")
            }
            print("Likely cause:")
            print("The printed sudo copy command has not been run yet, or a different file was copied.")
        }
    }

    private func listInputBackups() throws {
        try home.bootstrap()
        let backups = try InputConfigBackupManager(home: home).list()
        if backups.isEmpty {
            print("No CyberMac input config backups found.")
            return
        }
        for backup in backups {
            let files = backup.files.map { URL(fileURLWithPath: $0.bundlePath).lastPathComponent }.joined(separator: ", ")
            print("\(backup.id) | \(backup.createdAt) | \(files) | \(backup.gameFingerprintID)")
        }
    }

    private func restoreInputConfig() throws {
        try home.bootstrap()
        let ids = positionalArguments(after: "restore-input-config", excludingFlags: ["--dry-run", "--verify"])
        guard let id = ids.first else {
            throw CyberMacError.invalidInput("Missing input config backup id")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let manager = InputConfigBackupManager(home: home)
        if hasFlag("--verify") {
            let result = try manager.verifyRestore(id: id, gameInstall: game)
            print(formatInputConfigRestore(result))
        } else {
            let commands = try manager.restoreCommands(id: id, gameInstall: game)
            print(hasFlag("--dry-run") ? "Input config restore dry run." : "Run these input config restore commands manually:")
            for command in commands {
                print(command)
            }
            print("Then verify:")
            print("swift run cybermac restore-input-config --verify \(id)")
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
            let result = try manager.verifyRestore(id: id, gameInstall: game)
            print(RestoreVerificationFormatter.format(result))
        } else {
            let command = try manager.restoreCommand(id: id, gameInstall: game)
            print(hasFlag("--dry-run") ? "Restore dry run." : "Run this restore command manually:")
            print(command)
            print("Then verify:")
            print("swift run cybermac restore --verify \(id)")
        }
    }

    private func restoreVanilla() throws {
        try home.bootstrap()
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let manager = BundleBackupManager(home: home)
        guard let backup = try manager.latestVanillaBackup(for: game) else {
            throw CyberMacError.notFound("No vanilla backup found for the current game fingerprint and base cache snapshot.")
        }

        if hasFlag("--verify") {
            let result = try manager.verifyRestore(id: backup.id, gameInstall: game)
            let vanillaResult = RestoreVerificationResult(
                backupID: result.backupID,
                status: result.status,
                restoreCommand: result.restoreCommand,
                verifyCommand: "swift run cybermac restore-vanilla --verify"
            )
            print(RestoreVerificationFormatter.format(vanillaResult))
        } else {
            let command = try manager.restoreCommand(id: backup.id, gameInstall: game)
            print(hasFlag("--dry-run") ? "Restore vanilla dry run." : "Run this restore command manually:")
            print("Backup ID: \(backup.id)")
            print(command)
            print("Then verify:")
            print("swift run cybermac restore-vanilla --verify")
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
            var parts = ["\(mod.id)", mod.displayName, mod.status.rawValue, mod.type.displayName]
            if mod.requiresInputMappingPatch {
                parts.append("input: \(mod.inputPatchState.rawValue)")
            }
            print(parts.joined(separator: " | "))
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

    private func deleteMod() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing mod id")
        }
        let result = try ModStateManager(home: home).deletePermanently(id: arguments[1])
        print("Deleted mod from CyberMac: \(result.modID)")
        print("Deleted paths: \(result.deletedPaths.count)")
        if !result.missingPaths.isEmpty {
            print("Already missing paths: \(result.missingPaths.count)")
        }
        if result.activationMarkedOutOfSync {
            print("Activation state: outOfSync")
        }
        if result.inputPatchMarkedOutOfSync {
            print("Input patch state: outOfSync")
        }
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
        print("Status: \(result.displayStatusLabel)")
        print("Sidecar installable: \(result.sidecarInstallable ? "yes" : "no")")
        if let reason = result.installBlockReason {
            print("Install block: \(reason)")
        }
        print("Type: \(result.kind.displayName)")
        print("Input patch required: \(result.requiresInputMappingPatch ? "yes" : "no")")
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
        if !result.inputMappingEntries.isEmpty {
            print("Input mapping files:")
            for entry in result.inputMappingEntries {
                print("- \(entry)")
            }
        }
    }

    private func formatInputConfigRestore(_ result: InputConfigRestoreVerificationResult) -> String {
        var lines: [String] = []
        lines.append(result.matched ? "Input config restore verified." : "Input config restore verify failed.")
        lines.append("Backup ID: \(result.backupID)")
        for file in result.fileResults {
            lines.append("")
            lines.append(file.role.rawValue)
            switch file.status {
            case .verified(let target):
                lines.append("  Verified: \(target)")
            case .hashMismatch(let expected, let actual, let target):
                lines.append("  Target: \(target)")
                lines.append("  Expected: \(expected)")
                lines.append("  Actual: \(actual)")
            case .expectedAbsentButFileExists(let target, let actualHash):
                lines.append("  Expected absent but file exists: \(target)")
                lines.append("  Actual SHA-256: \(actualHash)")
            case .expectedPresentButFileMissing(let target):
                lines.append("  Expected present but file is missing: \(target)")
            case .staleBackup(let expectedFingerprint, let actualFingerprint):
                lines.append("  Stale backup")
                lines.append("  Expected fingerprint: \(expectedFingerprint)")
                lines.append("  Actual fingerprint: \(actualFingerprint)")
            }
        }
        if !result.matched {
            lines.append("")
            lines.append("Likely cause:")
            lines.append("The printed sudo restore command has not been run yet, or a different file was copied.")
        }
        lines.append("")
        lines.append("Verify command:")
        lines.append(result.verifyCommand)
        return lines.joined(separator: "\n")
    }

    private func printLaunchRefusal(_ plan: LaunchGamePlan) {
        if plan.bundleKind == .vanilla && !plan.enabledMods.isEmpty {
            print("Game is currently vanilla, but CyberMac has enabled mods that have not been activated.")
            print("")
            print("Enabled mods:")
            for mod in plan.enabledMods {
                print("- \(mod.displayName)")
            }
            print("")
            print("Launch anyway:")
            print("  cybermac launch-game --vanilla-ok")
            print("")
            print("Activate first:")
            print("  cybermac activate --bundle-mode")
            return
        }

        print("Refusing to launch from CyberMac.")
        print("")
        print("Reason:")
        print("  \(plan.refusalReason ?? "Current state is not safe to launch through CyberMac.")")
        if plan.bundleKind == .externallyChanged {
            print("")
            print("You can still launch manually from Finder, but CyberMac will not mark this state as safe.")
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

private struct SilentExit: Error {
    let code: Int32
}
