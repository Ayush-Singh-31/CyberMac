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
        case "archive-probe":
            try archiveProbe()
        case "archive-research":
            try archiveResearch()
        case "archive-catalog":
            try archiveCatalog()
        case "archive-patch":
            try archivePatch()
        case "mod-lab":
            try modLab()
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
        case "rename", "rename-mod":
            try renameMod()
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
          cybermac archive-probe prepare /path/to/mod.zip [--candidate mac-mod|mac-content|pc-mod|pc-content] [--game-app /path/to/Cyberpunk.app]
          cybermac archive-probe verify-copy <probe-id>
          cybermac archive-probe verify-removal <probe-id>
          cybermac archive-probe record-result <probe-id> worked|no-effect|game-failed-to-launch|unknown
          cybermac archive-probe list
          cybermac archive-research report [--game-app /path/to/Cyberpunk.app]
          cybermac archive-research strings [--game-app /path/to/Cyberpunk.app]
          cybermac archive-research seal [--game-app /path/to/Cyberpunk.app]
          cybermac archive-catalog search <query> --catalog-dir <path> [--ext xbm] [--archive <relative-archive-path>] [--limit 50]
          cybermac archive-catalog index build --catalog-dir <path> [--out <path>]
          cybermac archive-catalog index search <query> [--db <path>] [--ext xbm] [--archive <relative-archive-path>] [--category ui] [--limit 50]
          cybermac archive-catalog index stats [--db <path>]
          cybermac archive-patch backup-official <relative-archive-path> [--game-app /path/to/Cyberpunk.app]
          cybermac archive-patch status <relative-archive-path> [--game-app /path/to/Cyberpunk.app]
          cybermac archive-patch preflight <relative-archive-path> [--game-app /path/to/Cyberpunk.app]
          cybermac archive-patch manual-plan <relative-archive-path> [--game-app /path/to/Cyberpunk.app]
          cybermac archive-patch stage-swap <relative-archive-path> --target-asset <asset-path> --donor-asset <asset-path> --work-dir <path> --out <output.archive> --cp77tools <path>
          cybermac archive-patch stage-merge <relative-archive-path> --mod-archive <path> --work-dir <path> --out <output.archive> --cp77tools <path>
          cybermac archive-patch list-backups
          cybermac archive-patch restore-official <backup-id> [--dry-run|--verify] [--game-app /path/to/Cyberpunk.app]
          cybermac mod-lab assess <mod.zip> [--goal clothing|skin|ui|unknown]
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
          cybermac rename <mod-id> <new display name>
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

    private func archiveProbe() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing archive-probe subcommand")
        }

        switch arguments[1] {
        case "prepare":
            try archiveProbePrepare()
        case "verify-copy":
            try archiveProbeVerifyCopy()
        case "verify-removal":
            try archiveProbeVerifyRemoval()
        case "record-result":
            try archiveProbeRecordResult()
        case "list":
            try archiveProbeList()
        default:
            throw CyberMacError.invalidInput("Unknown archive-probe subcommand: \(arguments[1])")
        }
    }

    private func archiveProbePrepare() throws {
        let positionals = archiveProbePositionals(valueFlags: ["--candidate", "--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-probe prepare <mod.zip> [--candidate mac-mod|mac-content|pc-mod|pc-content] [--game-app /path/to/Cyberpunk.app]")
        }

        let candidate: ArchiveProbeCandidate
        if let candidateValue = optionValue("--candidate") {
            guard let parsed = ArchiveProbeCandidate(rawValue: candidateValue) else {
                throw CyberMacError.invalidInput("Unknown archive probe candidate: \(candidateValue). Expected one of: \(ArchiveProbeCandidate.acceptedValuesDescription)")
            }
            candidate = parsed
        } else {
            candidate = .macMod
        }

        try home.bootstrap()
        let zipURL = PathSafety.expandedURL(from: positionals[0])
        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let record = try ArchiveProbeManager(home: home).prepare(zipURL: zipURL, gameInstall: game, candidate: candidate)
        printArchiveProbePrepare(record)
    }

    private func archiveProbeVerifyCopy() throws {
        let positionals = archiveProbePositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-probe verify-copy <probe-id> [--game-app /path/to/Cyberpunk.app]")
        }

        let result = try ArchiveProbeManager(home: home).verifyCopy(id: positionals[0])
        if result.matched {
            print("Archive probe copy verified.")
            print("Probe ID: \(result.record.id)")
            print("Target: \(result.record.candidateTargetPath)")
            print("SHA-256: \(result.expectedSHA256)")
        } else {
            print("Archive probe copy not verified.")
            print("Probe ID: \(result.record.id)")
            print("Target: \(result.record.candidateTargetPath)")
            if result.targetExists {
                print("Expected SHA-256: \(result.expectedSHA256)")
                print("Actual SHA-256: \(result.actualSHA256 ?? "unknown")")
            } else {
                print("Target file is missing.")
            }
        }
    }

    private func archiveProbeVerifyRemoval() throws {
        let positionals = archiveProbePositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-probe verify-removal <probe-id> [--game-app /path/to/Cyberpunk.app]")
        }

        let result = try ArchiveProbeManager(home: home).verifyRemoval(id: positionals[0])
        if result.removed {
            print("Archive probe removal verified.")
            print("Probe ID: \(result.record.id)")
            print("Target absent: \(result.record.candidateTargetPath)")
        } else {
            print("Archive probe removal not verified.")
            print("Probe ID: \(result.record.id)")
            print("Target still exists: \(result.record.candidateTargetPath)")
            print("Run the printed removal command manually, then verify removal again.")
        }
    }

    private func archiveProbeRecordResult() throws {
        let positionals = archiveProbePositionals(valueFlags: ["--game-app"])
        guard positionals.count == 2 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-probe record-result <probe-id> worked|no-effect|game-failed-to-launch|unknown")
        }
        guard let result = ArchiveProbeUserResult(rawValue: positionals[1]) else {
            throw CyberMacError.invalidInput("Unknown archive probe result: \(positionals[1]). Expected worked, no-effect, game-failed-to-launch, or unknown.")
        }

        let record = try ArchiveProbeManager(home: home).recordResult(id: positionals[0], result: result)
        print("Archive probe result recorded.")
        printArchiveProbeSummary(record)
    }

    private func archiveProbeList() throws {
        let records = try ArchiveProbeManager(home: home).list()
        guard !records.isEmpty else {
            print("No archive probe records found.")
            return
        }

        for record in records {
            printArchiveProbeSummary(record)
        }
    }

    private func archiveResearch() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing archive-research subcommand")
        }

        switch arguments[1] {
        case "report":
            try archiveResearchReport()
        case "strings":
            try archiveResearchStrings()
        case "seal":
            try archiveResearchSeal()
        default:
            throw CyberMacError.invalidInput("Unknown archive-research subcommand: \(arguments[1])")
        }
    }

    private func archiveResearchReport() throws {
        let positionals = archiveResearchPositionals(valueFlags: ["--game-app"])
        guard positionals.isEmpty else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-research report [--game-app /path/to/Cyberpunk.app]")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let report = ArchiveResearchReporter(home: home).makeReport(gameInstall: game)
        print(ArchiveResearchReportFormatter.format(report))
    }

    private func archiveResearchStrings() throws {
        let positionals = archiveResearchPositionals(valueFlags: ["--game-app"])
        guard positionals.isEmpty else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-research strings [--game-app /path/to/Cyberpunk.app]")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let report = ArchiveStringResearchReporter(home: home).makeReport(gameInstall: game)
        print(ArchiveStringResearchReportFormatter.format(report))
    }

    private func archiveResearchSeal() throws {
        let positionals = archiveResearchPositionals(valueFlags: ["--game-app"])
        guard positionals.isEmpty else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-research seal [--game-app /path/to/Cyberpunk.app]")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let report = ArchiveSealResearchReporter(home: home).makeReport(gameInstall: game)
        print(ArchiveSealResearchReportFormatter.format(report))
    }

    private func archiveCatalog() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing archive-catalog subcommand")
        }

        switch arguments[1] {
        case "search":
            try archiveCatalogSearch()
        case "index":
            try archiveCatalogIndex()
        default:
            throw CyberMacError.invalidInput("Unknown archive-catalog subcommand: \(arguments[1])")
        }
    }

    private func archiveCatalogSearch() throws {
        let positionals = archiveCatalogPositionals(valueFlags: ["--catalog-dir", "--ext", "--archive", "--limit"])
        guard positionals.count == 1, let catalogDirectoryPath = optionValue("--catalog-dir") else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-catalog search <query> --catalog-dir <path> [--ext xbm] [--archive <relative-archive-path>] [--limit 50]")
        }

        let limit: Int
        if let rawLimit = optionValue("--limit") {
            guard let parsedLimit = Int(rawLimit) else {
                throw CyberMacError.invalidInput("Archive catalog limit must be an integer: \(rawLimit)")
            }
            limit = parsedLimit
        } else {
            limit = 50
        }

        let report = try ArchiveCatalogSearcher().search(options: ArchiveCatalogSearchOptions(
            query: positionals[0],
            catalogDirectory: PathSafety.expandedURL(from: catalogDirectoryPath),
            extensionFilter: optionValue("--ext"),
            archiveFilter: optionValue("--archive"),
            limit: limit
        ))
        print(ArchiveCatalogSearchFormatter.format(report))
    }

    private func archiveCatalogIndex() throws {
        guard arguments.count >= 3 else {
            throw CyberMacError.invalidInput("Missing archive-catalog index subcommand")
        }

        switch arguments[2] {
        case "build":
            try archiveCatalogIndexBuild()
        case "search":
            try archiveCatalogIndexSearch()
        case "stats":
            try archiveCatalogIndexStats()
        default:
            throw CyberMacError.invalidInput("Unknown archive-catalog index subcommand: \(arguments[2])")
        }
    }

    private func archiveCatalogIndexBuild() throws {
        let positionals = archiveCatalogIndexPositionals(valueFlags: ["--catalog-dir", "--out"])
        guard positionals.isEmpty, let catalogDirectoryPath = optionValue("--catalog-dir") else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-catalog index build --catalog-dir <path> [--out <path>]")
        }

        let outputDatabase = optionValue("--out").map(PathSafety.expandedURL) ?? ArchiveCatalogIndexDefaults.databaseURL
        let report = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: PathSafety.expandedURL(from: catalogDirectoryPath),
            outputDatabase: outputDatabase
        ))
        print(ArchiveCatalogIndexBuildFormatter.format(report))
    }

    private func archiveCatalogIndexSearch() throws {
        let positionals = archiveCatalogIndexPositionals(valueFlags: ["--db", "--ext", "--archive", "--category", "--limit"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-catalog index search <query> [--db <path>] [--ext xbm] [--archive <relative-archive-path>] [--category ui] [--limit 50]")
        }

        let limit = try archiveCatalogIndexLimit()
        let databaseURL = optionValue("--db").map(PathSafety.expandedURL) ?? ArchiveCatalogIndexDefaults.databaseURL
        let report = try ArchiveCatalogIndexStore().search(options: ArchiveCatalogIndexSearchOptions(
            query: positionals[0],
            databaseURL: databaseURL,
            extensionFilter: optionValue("--ext"),
            archiveFilter: optionValue("--archive"),
            categoryFilter: optionValue("--category"),
            limit: limit
        ))
        print(ArchiveCatalogIndexSearchFormatter.format(report))
    }

    private func archiveCatalogIndexStats() throws {
        let positionals = archiveCatalogIndexPositionals(valueFlags: ["--db"])
        guard positionals.isEmpty else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-catalog index stats [--db <path>]")
        }

        let databaseURL = optionValue("--db").map(PathSafety.expandedURL) ?? ArchiveCatalogIndexDefaults.databaseURL
        let report = try ArchiveCatalogIndexStore().stats(databaseURL: databaseURL)
        print(ArchiveCatalogIndexStatsFormatter.format(report))
    }

    private func archiveCatalogIndexLimit() throws -> Int {
        guard let rawLimit = optionValue("--limit") else {
            return 50
        }
        guard let parsedLimit = Int(rawLimit) else {
            throw CyberMacError.invalidInput("Archive catalog index limit must be an integer: \(rawLimit)")
        }
        return parsedLimit
    }

    private func archivePatch() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing archive-patch subcommand")
        }

        switch arguments[1] {
        case "backup-official":
            try archivePatchBackupOfficial()
        case "status":
            try archivePatchStatus()
        case "preflight":
            try archivePatchPreflight()
        case "manual-plan":
            try archivePatchManualPlan()
        case "stage-swap":
            try archivePatchStageSwap()
        case "stage-merge":
            try archivePatchStageMerge()
        case "list-backups":
            try archivePatchListBackups()
        case "restore-official":
            try archivePatchRestoreOfficial()
        default:
            throw CyberMacError.invalidInput("Unknown archive-patch subcommand: \(arguments[1])")
        }
    }

    private func archivePatchBackupOfficial() throws {
        let positionals = archivePatchPositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch backup-official <relative-archive-path> [--game-app /path/to/Cyberpunk.app]")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: optionValue("--game-app"))
        let metadata = try OfficialArchiveBackupManager(home: home).backup(
            relativeArchivePath: positionals[0],
            gameInstall: game
        )

        print("Official archive backup created.")
        print("Backup ID: \(metadata.backupID)")
        print("Source path: \(metadata.originalArchivePath)")
        print("Backup path: \(metadata.backupFilePath)")
        print("Size: \(metadata.originalSize) bytes")
        print("SHA-256: \(metadata.originalSHA256)")
        print("CodeResources listed: \(yesNo(metadata.codeResourcesListed))")
    }

    private func archivePatchStatus() throws {
        let positionals = archivePatchPositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch status <relative-archive-path> [--game-app /path/to/Cyberpunk.app]")
        }

        let status = try OfficialArchiveBackupManager(home: home).status(
            relativeArchivePath: positionals[0],
            preferredGameAppPath: optionValue("--game-app")
        )
        print(status.rawValue)
    }

    private func archivePatchPreflight() throws {
        let positionals = archivePatchPositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch preflight <relative-archive-path> [--game-app /path/to/Cyberpunk.app]")
        }

        let result = OfficialArchiveBackupManager(home: home).preflight(
            relativeArchivePath: positionals[0],
            preferredGameAppPath: optionValue("--game-app")
        )
        print(OfficialArchivePreflightFormatter.format(result))
    }

    private func archivePatchManualPlan() throws {
        let positionals = archivePatchPositionals(valueFlags: ["--game-app"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch manual-plan <relative-archive-path> [--game-app /path/to/Cyberpunk.app]")
        }

        let result = OfficialArchiveBackupManager(home: home).preflight(
            relativeArchivePath: positionals[0],
            preferredGameAppPath: optionValue("--game-app")
        )
        print(OfficialArchiveManualPlanFormatter.format(result))
    }

    private func archivePatchStageSwap() throws {
        let valueFlags: Set<String> = ["--target-asset", "--donor-asset", "--work-dir", "--out", "--cp77tools"]
        let positionals = archivePatchPositionals(valueFlags: valueFlags)
        guard positionals.count == 1,
              let targetAsset = optionValue("--target-asset"),
              let donorAsset = optionValue("--donor-asset"),
              let workDirectoryPath = optionValue("--work-dir"),
              let outputArchivePath = optionValue("--out"),
              let cp77toolsPath = optionValue("--cp77tools")
        else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch stage-swap <relative-archive-path> --target-asset <asset-path> --donor-asset <asset-path> --work-dir <path> --out <output.archive> --cp77tools <path>")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: nil)
        let request = OfficialArchiveSwapStageRequest(
            relativeArchivePath: positionals[0],
            targetAssetPath: targetAsset,
            donorAssetPath: donorAsset,
            workDirectoryURL: PathSafety.expandedURL(from: workDirectoryPath),
            outputArchiveURL: PathSafety.expandedURL(from: outputArchivePath),
            cp77toolsURL: PathSafety.expandedURL(from: cp77toolsPath)
        )
        let result = try OfficialArchiveSwapStager(home: home).stage(request: request, gameInstall: game)
        print(OfficialArchiveSwapStageFormatter.format(result))
    }

    private func archivePatchStageMerge() throws {
        let valueFlags: Set<String> = ["--mod-archive", "--work-dir", "--out", "--cp77tools"]
        let positionals = archivePatchPositionals(valueFlags: valueFlags)
        guard positionals.count == 1,
              let modArchivePath = optionValue("--mod-archive"),
              let workDirectoryPath = optionValue("--work-dir"),
              let outputArchivePath = optionValue("--out"),
              let cp77toolsPath = optionValue("--cp77tools")
        else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch stage-merge <relative-archive-path> --mod-archive <path> --work-dir <path> --out <output.archive> --cp77tools <path>")
        }

        let game = try GameInstallDetector().detect(preferredAppPath: nil)
        let request = OfficialArchiveMergeStageRequest(
            relativeArchivePath: positionals[0],
            modArchiveURL: PathSafety.expandedURL(from: modArchivePath),
            workDirectoryURL: PathSafety.expandedURL(from: workDirectoryPath),
            outputArchiveURL: PathSafety.expandedURL(from: outputArchivePath),
            cp77toolsURL: PathSafety.expandedURL(from: cp77toolsPath)
        )
        let result = try OfficialArchiveMergeStager(home: home).stage(request: request, gameInstall: game)
        print(OfficialArchiveMergeStageFormatter.format(result))
    }

    private func archivePatchListBackups() throws {
        let positionals = archivePatchPositionals(valueFlags: ["--game-app"])
        guard positionals.isEmpty else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch list-backups")
        }

        let backups = try OfficialArchiveBackupManager(home: home).list()
        guard !backups.isEmpty else {
            print("No CyberMac official archive backups found.")
            return
        }

        for backup in backups {
            print("\(backup.backupID) | \(backup.createdAt) | \(backup.relativeArchivePath) | \(backup.originalSize) bytes | \(backup.originalSHA256) | \(backup.gameAppPath)")
        }
    }

    private func archivePatchRestoreOfficial() throws {
        let modes = ["--dry-run", "--verify"].filter(hasFlag)
        if modes.isEmpty {
            print("Usage: cybermac archive-patch restore-official <backup-id> [--dry-run|--verify] [--game-app /path/to/Cyberpunk.app]")
            print("Restore requires either --dry-run to print the manual sudo cp command or --verify to verify a manual restore.")
            return
        }
        guard modes.count == 1 else {
            throw CyberMacError.invalidInput("Use exactly one restore mode: --dry-run or --verify")
        }

        let positionals = archivePatchPositionals(valueFlags: ["--game-app"], excludingFlags: ["--dry-run", "--verify"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac archive-patch restore-official <backup-id> [--dry-run|--verify] [--game-app /path/to/Cyberpunk.app]")
        }

        let manager = OfficialArchiveBackupManager(home: home)
        if hasFlag("--dry-run") {
            print(try manager.restoreDryRunCommand(backupID: positionals[0], preferredGameAppPath: optionValue("--game-app")))
        } else {
            let result = try manager.verifyRestore(backupID: positionals[0], preferredGameAppPath: optionValue("--game-app"))
            if result.matched {
                print("PASS")
                print("Destination: \(result.destinationPath)")
                print("SHA-256: \(result.currentSHA256)")
            } else {
                print("FAIL")
                print("Destination: \(result.destinationPath)")
                print("Current SHA-256: \(result.currentSHA256)")
                print("Expected SHA-256: \(result.expectedSHA256)")
            }
        }
    }

    private func modLab() throws {
        guard arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Missing mod-lab subcommand")
        }

        switch arguments[1] {
        case "assess":
            try modLabAssess()
        default:
            throw CyberMacError.invalidInput("Unknown mod-lab subcommand: \(arguments[1])")
        }
    }

    private func modLabAssess() throws {
        let positionals = modLabPositionals(valueFlags: ["--goal"])
        guard positionals.count == 1 else {
            throw CyberMacError.invalidInput("Usage: cybermac mod-lab assess <mod.zip> [--goal clothing|skin|ui|unknown]")
        }

        let goal: ModConversionGoal
        if let goalValue = optionValue("--goal") {
            guard let parsed = ModConversionGoal(rawValue: goalValue) else {
                throw CyberMacError.invalidInput("Unknown mod-lab goal: \(goalValue). Expected one of: \(ModConversionGoal.acceptedValuesDescription)")
            }
            goal = parsed
        } else {
            goal = .unknown
        }

        let zipURL = PathSafety.expandedURL(from: positionals[0])
        let assessment = try ModConversionAssessor().assess(zipURL: zipURL, goal: goal)
        print(ModConversionAssessmentFormatter.format(assessment))
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

    private func renameMod() throws {
        guard arguments.count >= 3 else {
            throw CyberMacError.invalidInput("Usage: cybermac rename <mod-id> <new display name>")
        }
        let id = arguments[1]
        let displayName = arguments.dropFirst(2).joined(separator: " ")
        let manifest = try ModStateManager(home: home).rename(id: id, displayName: displayName)
        print("Renamed mod.")
        print("ID: \(manifest.id)")
        print("Name: \(manifest.displayName)")
    }

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

    private func printArchiveProbePrepare(_ record: ArchiveProbeRecord) {
        print("Archive probe prepared.")
        print("Experimental probe only: this does not enable managed archive mod support.")
        print("Probe ID: \(record.id)")
        print("Archive file: \(record.archiveFileName)")
        print("SHA-256: \(record.archiveSHA256)")
        print("Candidate target: \(record.candidateTargetPath)")
        print("")
        print("Manual copy commands:")
        print(record.commandPrinted)
        print("")
        print("Manual removal command:")
        print(record.removalCommandPrinted)
        print("")
        print("Next steps:")
        print("1. Run the printed copy commands manually in Terminal.")
        print("2. Launch the game manually.")
        print("3. Check whether the archive replacer has a visible effect.")
        print("4. Run: swift run cybermac archive-probe verify-copy \(record.id)")
        print("5. Remove the file using the printed removal command.")
        print("6. Run: swift run cybermac archive-probe verify-removal \(record.id)")
        print("7. Run: swift run cybermac archive-probe record-result \(record.id) worked|no-effect|game-failed-to-launch|unknown")
    }

    private func printArchiveProbeSummary(_ record: ArchiveProbeRecord) {
        print("\(record.id) | \(record.createdAt) | \(record.archiveFileName) | \(record.candidateTargetPath) | copied: \(yesNo(record.verifiedCopied)) | removed: \(yesNo(record.verifiedRemoved)) | result: \(record.userReportedResult?.rawValue ?? "none")")
    }

    private func printScanResult(_ result: ModScanResult) {
        print("Name: \(result.displayName)")
        print("Status: \(result.displayStatusLabel)")
        print("Compatibility: \(result.compatibilityStatus.rawValue)")
        print("Type: \(result.kind.displayName)")
        print("Sidecar installable: \(result.sidecarInstallable ? "yes" : "no")")
        if let reason = result.installBlockReason {
            print("Install block: \(reason)")
        }
        print("Detected archive files: \(result.archiveEntries.count)")
        print("Detected input XML files: \(result.inputMappingEntries.count)")
        let frameworkMarkers = result.dependencyMarkers.frameworkMarkerLabels
        print("Dependency/framework markers: \(frameworkMarkers.isEmpty ? "none" : frameworkMarkers.joined(separator: ", "))")
        let archiveMarkers = result.dependencyMarkers.archiveMarkerLabels.filter { $0 != "input XML" }
        print("Archive/layout markers: \(archiveMarkers.isEmpty ? "none" : archiveMarkers.joined(separator: ", "))")
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

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private func archiveProbePositionals(valueFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(2) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }

    private func archiveResearchPositionals(valueFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(2) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }

    private func archiveCatalogPositionals(valueFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(2) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }

    private func archiveCatalogIndexPositionals(valueFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(3) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }

    private func archivePatchPositionals(valueFlags: Set<String>, excludingFlags: Set<String> = []) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(2) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if excludingFlags.contains(argument) {
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
    }

    private func modLabPositionals(valueFlags: Set<String>) -> [String] {
        var values: [String] = []
        var skipNext = false
        for argument in arguments.dropFirst(2) {
            if skipNext {
                skipNext = false
                continue
            }
            if valueFlags.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("--") {
                continue
            }
            values.append(argument)
        }
        return values
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
