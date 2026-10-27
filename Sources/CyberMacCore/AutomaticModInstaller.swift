import Foundation

public enum ModInstallPreparation: Sendable {
    case ready(String)
    case runtimeReady(String)
    case needsSetup(String)
    case blocked(String)
    case choices([String])
    case clothingSelectionRequired
    case prepared(ModInstallTransaction, appearanceID: String?)
}

public struct AutomaticModInstaller: Sendable {
    public let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    public func prepare(_ url: URL, variant: String? = nil, clothingRecords: [String]? = nil, game gameOverride: GameInstall? = nil) throws -> ModInstallPreparation {
        let route = try ModPackageRouter(home: home).route(url)
        if let clothingRecords {
            let clothing: Bool
            switch route {
            case .clothing: clothing = true
            case .appearance: clothing = url.pathExtension.lowercased() == "zip"
            default: clothing = false
            }
            guard clothing else {
                throw CyberMacError.unsupported("This package has no prepared clothing selection. Its variants need conversion first.")
            }
            if let current = try ClothingWardrobeManager(home: home).current(),
               try ClothingWardrobeManager(home: home).sessionStatus(workspace: current.workspace)?.isActive == true {
                return .blocked("Finish the active clothing session before installing more clothes.")
            }
            let game = try gameOverride ?? GameInstallDetector().detect()
            return try ClothingAdditionInstaller(home: home).prepare(url, records: clothingRecords, game: game)
        }
        if case .runtime = route {
            // Runtime imports do not change the game or clothing selection.
        } else {
            let wardrobe = ClothingWardrobeManager(home: home)
            if let current = try wardrobe.current(), try wardrobe.sessionStatus(workspace: current.workspace)?.isActive == true {
                return .blocked("Wait for the clothing session to finish and restore its files before installing another mod.")
            }
        }
        switch route {
        case .blocked(let reason): return .blocked(reason)
        case .runtime(let kind):
            if kind == .redscript, let game = gameOverride ?? (try? GameInstallDetector().detect()),
               let issue = RedscriptCompatibility.setupIssue(runtimeVersion: RuntimeArchiveImporter.versionString(from: url.deletingPathExtension().lastPathComponent), gameVersion: try RedscriptCompatibility.gameVersion(game)) {
                return .needsSetup(issue)
            }
            let importer = RuntimeArchiveImporter(home: home)
            _ = try kind == .redscript ? importer.importRedscript(zipURL: url) : importer.importInputLoader(zipURL: url)
            return .runtimeReady("\(kind == .redscript ? "redscript" : "Input loader") imported. Continuing any mods waiting for setup.")
        case .clothing:
            return .clothingSelectionRequired
        case .scripts:
            return try prepareScripts(url, game: gameOverride)
        case .appearance(let variants):
            if variants.count > 1 && variant == nil { return .choices(variants) }
            let game = try gameOverride ?? GameInstallDetector().detect()
            let manager = AppearancePatchManager(home: home)
            let plan = try manager.inspect(packageURL: url, game: game, archiveEntry: variant)
            guard plan.canStage else {
                return .blocked((plan.warnings + ["This package has unresolved assets, dependencies, or no verified destination in your game. It needs a conversion recipe before it can be installed."]).joined(separator: "\n"))
            }
            let stage = try manager.stage(id: plan.id, game: game)
            let files = stage.files.map { file in
                ModInstallTransaction.File(source: file.stagedPath,
                    target: game.appURL.appendingPathComponent("Contents/\(file.relativePath)").path,
                    backup: file.backupPath, originalSHA256: file.originalSHA256, installedSHA256: file.stagedSHA256)
            }
            return .prepared(try ModInstallTransaction(game: game, files: files), appearanceID: plan.id)
        }
    }

    private func prepareScripts(_ url: URL, game gameOverride: GameInstall?) throws -> ModInstallPreparation {
        let game = try gameOverride ?? GameInstallDetector().detect()
        let store = ManifestStore(home: home)
        let installed: InstalledModManifest
        if let previous = try store.list().first(where: { $0.sourceArchive == url.path && $0.status != .uninstalled }) {
            installed = previous.status == .enabled ? previous : try ModStateManager(home: home).enable(id: previous.id)
        } else {
            installed = try RedscriptModInstaller(home: home).install(zipURL: url, gameInstall: game)
        }
        let runtime = RuntimeArchiveImporter(home: home).redscriptStatus()
        guard runtime.installed else {
            return .needsSetup("Mod added to your library. Drop the macOS redscript release ZIP here to finish installation.")
        }
        if let issue = RedscriptCompatibility.setupIssue(runtimeVersion: runtime.version, gameVersion: try RedscriptCompatibility.gameVersion(game)) {
            return .needsSetup(issue)
        }
        guard runtime.quarantinedPaths.isEmpty else {
            return .blocked("Mod added. The redscript tool is quarantined by macOS. Resolve it in Privacy & Security, then Retry.")
        }
        let base = BaseCacheManager(home: home)
        if try base.status(gameInstall: game).snapshot == nil {
            // A fresh install must start from the resource seal, never an
            // arbitrary current cache (which might be a clothing helper).
            let contents = game.appURL.appendingPathComponent("Contents")
            let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: contents.appendingPathComponent("_CodeSignature/CodeResources")), format: nil) as? [String: Any]
            let entry = (seal?["files2"] as? [String: Any])?["Data/r6/cache/final.redscripts"] as? [String: Any]
            guard let digest = entry?["hash2"] as? Data, digest.count == 32,
                  try PathSafety.sha256(url: base.bundleCacheURL(gameInstall: game)) == digest.map({ String(format: "%02x", $0) }).joined() else {
                return .blocked("Mod added. Restore the original script cache before the first automatic installation. An active clothing session must finish first.")
            }
            _ = try base.refreshBaseCache(gameInstall: game, dryRun: false)
        }
        let activation: ActivationBundleModeResult
        do {
            activation = try ActivationManager(home: home).activateBundleMode(gameInstall: game)
        } catch {
            // A failed new import must not poison every later compilation.
            // Keep its source for retry, but preserve mods already active in game.
            if !StateStore(home: home).load().activeModIDs.contains(installed.id) {
                do {
                    _ = try ModStateManager(home: home).disable(id: installed.id)
                } catch let cleanupError {
                    throw CyberMacError.fileSystem("\(error)\nCould not disable the failed import: \(cleanupError). Disable \(installed.displayName) in Library before retrying another mod.")
                }
            }
            throw error
        }
        guard let originalScriptHash = activation.backup.sha256 else {
            throw CyberMacError.invalidInput("The script backup has no verified digest.")
        }
        var files = [ModInstallTransaction.File(source: activation.tempOutputPath, target: activation.bundleTarget,
            backup: BundleBackupManager(home: home).backupDirectory(id: activation.backup.id).appendingPathComponent("final.redscripts").path,
            originalSHA256: originalScriptHash, installedSHA256: activation.generatedSHA256)]
        if try store.list().contains(where: { $0.status == .enabled && $0.requiresInputMappingPatch }) {
            let input = try InputMappingManager(home: home).preparePatch(gameInstall: game)
            let backup = try InputConfigBackupManager(home: home).load(id: input.backupID)
            for file in backup.files {
                guard let path = file.backupPath, let original = file.sha256, let expected = input.expectedHashes[file.bundlePath] else {
                    throw CyberMacError.invalidInput("An input configuration backup is incomplete.")
                }
                let source = file.role == .inputContexts ? input.generatedContextPath : input.generatedUserMappingsPath
                files.append(.init(source: source, target: file.bundlePath, backup: path, originalSHA256: original, installedSHA256: expected))
            }
        }
        return .prepared(try ModInstallTransaction(game: game, files: files), appearanceID: nil)
    }

    public func verify(_ transaction: ModInstallTransaction, appearanceID: String?, game gameOverride: GameInstall? = nil) throws {
        try transaction.verify()
        let game = try gameOverride ?? GameInstallDetector().detect(preferredAppPath: transaction.gameApp)
        if let appearanceID {
            if appearanceID.hasPrefix(ClothingAdditionInstaller.verificationPrefix) {
                try ClothingAdditionInstaller(home: home).verify(id: String(appearanceID.dropFirst(ClothingAdditionInstaller.verificationPrefix.count)), game: game)
            } else {
                guard try AppearancePatchManager(home: home).verify(id: appearanceID, game: game).matched else {
                    throw CyberMacError.fileSystem("Appearance installation verification failed.")
                }
            }
        } else {
            let state = StateStore(home: home).load()
            if state.pendingActivation != nil {
                guard try ActivationManager(home: home).verify(gameInstall: game).matched else {
                    throw CyberMacError.fileSystem("Script activation verification failed.")
                }
            } else if state.activationState != .active || state.activeBundleTargetHashes[transaction.files[0].target] != transaction.files[0].installedSHA256 {
                throw CyberMacError.fileSystem("This installation is no longer the active script configuration. Inspect it again.")
            }
            if transaction.files.count > 1 && state.pendingInputPatch != nil {
                guard try InputMappingManager(home: home).verifyPatch(gameInstall: game).matched else {
                    throw CyberMacError.fileSystem("Input patch verification failed.")
                }
            }
        }
    }
}
