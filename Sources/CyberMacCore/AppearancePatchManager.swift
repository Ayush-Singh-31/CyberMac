import Foundation
import ZIPFoundation

public struct AppearanceArchiveTarget: Codable, Equatable, Sendable {
    public let relativePath: String
    public let resourceHashes: [String]
    public let indexFingerprint: String
    public let originalSize: UInt64
    public let sealedSHA256: String?
}

public struct AppearancePatchPlan: Codable, Sendable {
    public let id: String
    public let createdAt: Date
    public let gameAppPath: String
    public let gameVersion: String
    public let gameBuild: String
    public let gameFingerprint: String
    public let packageName: String
    public let selectedArchiveEntry: String
    public let sourceSHA256: String
    public let recordCount: Int
    public let officialArchiveCount: Int
    public let targets: [AppearanceArchiveTarget]
    public let unmatchedResources: [String]
    public let newResourceTarget: String?
    public let unresolvedDependencies: [String]
    public let itemIDs: [String]
    public let warnings: [String]
    public var canStage: Bool {
        recordCount > 0 && !targets.isEmpty && (unmatchedResources.isEmpty || newResourceTarget != nil) && unresolvedDependencies.isEmpty &&
        targets.allSatisfy { $0.sealedSHA256 != nil }
    }
}

public struct AppearanceStagedArchive: Codable, Sendable {
    public let relativePath: String
    public let stagedPath: String
    public let stagedSHA256: String
    public let backupID: String
    public let backupPath: String
    public let originalSHA256: String
    public let resourceCount: Int
    public internal(set) var installCommand: String
    public internal(set) var restoreCommand: String
}

public struct AppearancePatchStage: Codable, Sendable {
    public let planID: String
    public let createdAt: Date
    public let gameFingerprint: String
    public let gameAppPath: String
    public internal(set) var files: [AppearanceStagedArchive]
    public let gameplayVerified: Bool
}

public struct AppearancePatchVerification: Codable, Sendable {
    public let planID: String
    public let mode: String
    public let matched: Bool
    public let fileMatches: [String: Bool]
    public let gameplayVerified: Bool
}

/// Research workflow: inspect real archives, stage verified replacements, print manual commands.
/// Every write stays under CyberMac's home. This manager never writes to the game.
public struct AppearancePatchManager: Sendable {
    public let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager) { self.home = home }

    public func inspect(packageURL: URL, game: GameInstall, archiveEntry: String? = nil) throws -> AppearancePatchPlan {
        try validateHome(game)
        try PathSafety.validateArchiveSize(packageURL)
        let id = UUID().uuidString.lowercased()
        let folder = try directory(id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: folder) } }
        let destination = folder.appendingPathComponent("source.archive")
        let selected: String
        var items = Set<String>()
        if packageURL.pathExtension.lowercased() == "archive" {
            let attributes = try packageURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw CyberMacError.unsafePath("Source archive must be a regular file.") }
            selected = packageURL.lastPathComponent
            try FileManager.default.copyItem(at: packageURL, to: destination)
        } else {
            guard packageURL.pathExtension.lowercased() == "zip" else {
                throw CyberMacError.invalidInput("Choose a .zip clothing package or a .archive file.")
            }
            let scan = try ModArchiveScanner().scan(zipURL: packageURL)
            guard scan.dependencyMarkers.frameworkMarkerLabels.isEmpty, scan.redscriptEntries.isEmpty,
                  scan.inputMappingEntries.isEmpty, scan.kind == .archiveOnly else {
                throw CyberMacError.unsupported("This workflow accepts archive-only appearance replacements. Framework or script packages need a separate compatible runtime.")
            }
            if let archiveEntry {
                guard scan.archiveEntries.contains(archiveEntry) else { throw CyberMacError.invalidInput("Selected archive entry is not in this package.") }
                selected = archiveEntry
            } else {
                guard scan.archiveEntries.count == 1, let first = scan.archiveEntries.first else {
                    throw CyberMacError.invalidInput("Package contains \(scan.archiveEntries.count) archive variants. Select one with --archive-entry; do not enable every alternative.")
                }
                selected = first
            }
            let zip = try Archive(url: packageURL, accessMode: .read)
            guard let entry = zip[selected], entry.type == .file,
                  entry.uncompressedSize <= PathSafety.maxArchiveBytes else {
                throw CyberMacError.invalidInput("Selected archive is missing, unsafe or exceeds the size limit.")
            }
            _ = try zip.extract(entry, to: destination)
            for text in zip where text.type == .file && text.path.lowercased().hasSuffix("codes.txt") && text.uncompressedSize <= 64 * 1024 {
                var data = Data()
                _ = try zip.extract(text, consumer: { data.append($0) })
                if let contents = String(data: data, encoding: .utf8),
                   let regex = try? NSRegularExpression(pattern: #"Items\.[A-Za-z0-9_]+"#) {
                    for match in regex.matches(in: contents, range: NSRange(contents.startIndex..., in: contents)) {
                        if let range = Range(match.range, in: contents) { items.insert(String(contents[range])) }
                    }
                }
            }
        }
        let plan = try makePlan(id: id, game: game, packageName: packageURL.lastPathComponent,
                                selected: selected, itemIDs: items.sorted())
        try save(plan, to: folder.appendingPathComponent("plan.json"))
        complete = true
        return plan
    }

    public func loadPlan(_ id: String) throws -> AppearancePatchPlan {
        let plan = try JSONDecoder.cybermac.decode(AppearancePatchPlan.self, from: Data(contentsOf: try directory(id).appendingPathComponent("plan.json")))
        guard plan.id == id else { throw CyberMacError.invalidInput("Appearance plan ID mismatch.") }
        return plan
    }

    public func recentPlans(limit: Int = 20) throws -> [AppearancePatchPlan] {
        let root = home.generatedURL.appendingPathComponent("appearance", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .compactMap { try? loadPlan($0.lastPathComponent) }
            .sorted { $0.createdAt > $1.createdAt }.prefix(max(0, min(limit, 100))).map { $0 }
    }

    /// Compile only this package's item grants in a separate workspace, preserving the original cache.
    public func prepareItemDelivery(id: String, game: GameInstall, runtimeZipURL: URL) throws -> AppearanceItemDelivery {
        try validateHome(game)
        let plan = try loadPlan(id)
        let fingerprint = try BaseCacheManager(home: home).fingerprint(gameInstall: game).id
        guard plan.canStage, plan.gameAppPath == game.appURL.path, plan.gameFingerprint == fingerprint else {
            throw CyberMacError.unsupported("The game changed since inspection. Inspect the clothing package again.")
        }
        let items = try RedscriptItemGrantGenerator.normalizeItemIDs(plan.itemIDs)
        let folder = try directory(id)
        guard try PathSafety.sha256(url: folder.appendingPathComponent("source.archive")) == plan.sourceSHA256 else {
            throw CyberMacError.unsupported("The clothing source changed. Inspect it again.")
        }
        let deliveryRoot = folder.appendingPathComponent("item-delivery", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: deliveryRoot.path) else {
            throw CyberMacError.invalidInput("Item delivery is already prepared. Inspect again for a new experiment.")
        }
        let (target, originalSHA) = try sealedScriptCache(game)
        guard try PathSafety.sha256(url: target) == originalSHA else {
            throw CyberMacError.unsupported("The script cache differs from the game's resource seal. Restore the original before preparing a clothing helper.")
        }
        try FileManager.default.createDirectory(at: deliveryRoot, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: deliveryRoot) } }
        let workspace = CyberMacHomeManager(homeURL: deliveryRoot.appendingPathComponent("workspace"))
        let runtimeHash = try PathSafety.sha256(url: runtimeZipURL)
        let runtime = try RuntimeArchiveImporter(home: workspace).importRedscript(zipURL: runtimeZipURL)
        guard Self.supportsItemDelivery(runtime.version) else {
            throw CyberMacError.unsupported("Game 2.5 needs redscript 0.5.32 or newer. Import the official Mac release with its original versioned filename.")
        }
        _ = try BaseCacheManager(home: workspace).refreshBaseCache(gameInstall: game, dryRun: false)
        let zip = deliveryRoot.appendingPathComponent("ClothingItemDelivery.zip")
        _ = try RedscriptItemGrantGenerator().generate(request: .init(itemIDs: items, outputZipURL: zip, modName: "CyberMac Clothing Delivery"))
        _ = try RedscriptModInstaller(home: workspace).install(zipURL: zip, gameInstall: game)
        let activation = try ActivationManager(home: workspace).activateBundleMode(gameInstall: game)
        let backups = BundleBackupManager(home: workspace)
        let backup = backups.backupDirectory(id: activation.backup.id).appendingPathComponent("final.redscripts")
        guard activation.backup.sha256 == originalSHA,
              try PathSafety.sha256(url: backup) == originalSHA,
              try PathSafety.sha256(url: target) == originalSHA,
              try PathSafety.sha256(url: folder.appendingPathComponent("source.archive")) == plan.sourceSHA256,
              try PathSafety.sha256(url: runtimeZipURL) == runtimeHash else {
            throw CyberMacError.unsupported("Game, clothing source, backup or runtime changed during compilation. Prepare a new experiment.")
        }
        let result = AppearanceItemDelivery(
            planID: id, createdAt: Date(), gameAppPath: game.appURL.path, gameFingerprint: fingerprint,
            packageName: plan.packageName, itemIDs: items, runtimeVersion: runtime.version ?? "Unknown",
            runtimeArchiveSHA256: runtimeHash, workspacePath: workspace.homeURL.path, helperZipPath: zip.path,
            compiledPath: activation.tempOutputPath, compiledSHA256: activation.generatedSHA256,
            backupID: activation.backup.id, backupPath: backup.path, originalSHA256: originalSHA,
            installCommand: VerifiedFileReplacement.command(source: activation.tempOutputPath, target: target.path, sha256: activation.generatedSHA256),
            restoreCommand: VerifiedFileReplacement.command(source: backup.path, target: target.path, sha256: originalSHA), gameplayVerified: false)
        try save(result, to: deliveryRoot.appendingPathComponent("delivery.json"))
        complete = true
        return result
    }

    public func loadItemDelivery(_ id: String) throws -> AppearanceItemDelivery {
        let url = try directory(id).appendingPathComponent("item-delivery/delivery.json")
        var result = try JSONDecoder.cybermac.decode(AppearanceItemDelivery.self, from: Data(contentsOf: url))
        guard result.planID == id else { throw CyberMacError.invalidInput("Item delivery plan ID mismatch.") }
        let target = URL(fileURLWithPath: result.gameAppPath).appendingPathComponent("Contents/Data/r6/cache/final.redscripts").path
        result.installCommand = VerifiedFileReplacement.command(source: result.compiledPath, target: target, sha256: result.compiledSHA256)
        result.restoreCommand = VerifiedFileReplacement.command(source: result.backupPath, target: target, sha256: result.originalSHA256)
        return result
    }

    public func verifyItemDelivery(id: String, game: GameInstall, restore: Bool = false) throws -> AppearancePatchVerification {
        try validateHome(game)
        let delivery = try loadItemDelivery(id)
        let plan = try loadPlan(id)
        let fingerprint = try BaseCacheManager(home: home).fingerprint(gameInstall: game).id
        guard delivery.gameAppPath == game.appURL.path, delivery.gameFingerprint == fingerprint,
              plan.gameFingerprint == fingerprint, delivery.itemIDs == plan.itemIDs else {
            throw CyberMacError.unsupported("This item helper belongs to another game or appearance plan.")
        }
        let root = try directory(id).appendingPathComponent("item-delivery/workspace", isDirectory: true)
        guard delivery.workspacePath == root.path else { throw CyberMacError.unsafePath("Item helper workspace path changed.") }
        let compiled = URL(fileURLWithPath: delivery.compiledPath)
        let backup = URL(fileURLWithPath: delivery.backupPath)
        for file in [compiled, backup] {
            try PathSafety.validateContainedPath(file.resolvingSymlinksInPath(), in: root)
        }
        let (target, originalSHA) = try sealedScriptCache(game)
        let workspace = CyberMacHomeManager(homeURL: root)
        let backups = BundleBackupManager(home: workspace)
        let metadata = try backups.load(id: delivery.backupID)
        guard backup.standardizedFileURL.path == backups.backupDirectory(id: delivery.backupID)
                .appendingPathComponent("final.redscripts").standardizedFileURL.path,
              metadata.gameFingerprintID == fingerprint, metadata.gameAppPath == game.appURL.path,
              metadata.bundleTarget == target.path, metadata.sha256 == originalSHA,
              delivery.originalSHA256 == originalSHA,
              try PathSafety.sha256(url: backup) == originalSHA,
              try PathSafety.sha256(url: compiled) == delivery.compiledSHA256 else {
            throw CyberMacError.invalidInput("Prepared helper or original script backup failed integrity verification.")
        }
        let matched = try PathSafety.sha256(url: target) == (restore ? originalSHA : delivery.compiledSHA256)
        let result = AppearancePatchVerification(planID: id, mode: restore ? "delivery-restore" : "delivery-install",
            matched: matched, fileMatches: ["Data/r6/cache/final.redscripts": matched], gameplayVerified: false)
        try save(result, to: try directory(id).appendingPathComponent("item-delivery/\(result.mode)-verification.json"))
        return result
    }

    static func supportsItemDelivery(_ runtimeVersion: String?) -> Bool {
        guard let runtimeVersion, !runtimeVersion.contains("-"),
              runtimeVersion.split(separator: ".").allSatisfy({ Int($0) != nil }) else { return false }
        return runtimeVersion.compare("0.5.32", options: .numeric) != .orderedAscending
    }

    private func sealedScriptCache(_ game: GameInstall) throws -> (URL, String) {
        let contents = game.appURL.appendingPathComponent("Contents")
        let relative = "Data/r6/cache/final.redscripts"
        let target = contents.appendingPathComponent(relative)
        try PathSafety.validateContainedPath(target.resolvingSymlinksInPath(), in: contents.resolvingSymlinksInPath())
        let attributes = try target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        let seal = try PropertyListSerialization.propertyList(from: Data(contentsOf: contents.appendingPathComponent("_CodeSignature/CodeResources")), format: nil) as? [String: Any]
        let files = seal?["files2"] as? [String: Any]
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
              let record = files?[relative] as? [String: Any], let hash = record["hash2"] as? Data, hash.count == 32 else {
            throw CyberMacError.unsupported("The game needs an original, sealed script cache for this clothing helper.")
        }
        return (target, hash.map { String(format: "%02x", $0) }.joined())
    }

    public func stage(id: String, game: GameInstall) throws -> AppearancePatchStage {
        try validateHome(game)
        let plan = try loadPlan(id)
        let folder = try directory(id)
        let stageFolder = folder.appendingPathComponent("staged", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageFolder.path) else {
            throw CyberMacError.invalidInput("This plan already has staged output. Inspect again to create a new experiment.")
        }
        let current = try makePlan(id: id, game: game, packageName: plan.packageName,
                                   selected: plan.selectedArchiveEntry, itemIDs: plan.itemIDs)
        guard current.canStage, current.sourceSHA256 == plan.sourceSHA256,
              current.gameFingerprint == plan.gameFingerprint, current.targets == plan.targets,
              current.newResourceTarget == plan.newResourceTarget,
              current.unmatchedResources == plan.unmatchedResources,
              current.unresolvedDependencies == plan.unresolvedDependencies else {
            throw CyberMacError.unsupported("Plan is blocked or its game/source changed. Inspect again; new assets need one unambiguous destination and dependencies must resolve.")
        }
        let contents = game.appURL.appendingPathComponent("Contents", isDirectory: true)
        // Verify all original files against the game's resource seal before making outputs.
        for target in plan.targets {
            let url = try officialURL(target.relativePath, contents: contents)
            guard try PathSafety.sha256(url: url) == target.sealedSHA256 else {
                throw CyberMacError.unsupported("\(target.relativePath) differs from the installed game's resource seal. Restore the original before staging.")
            }
        }
        let donor = try NativeArchive.read(folder.appendingPathComponent("source.archive"))
        let backupManager = OfficialArchiveBackupManager(home: home)
        var files: [AppearanceStagedArchive] = []
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: stageFolder) } }
        for target in plan.targets {
            let original = try officialURL(target.relativePath, contents: contents)
            let existing = try backupManager.list().first {
                $0.gameAppPath == game.appURL.path && $0.relativeArchivePath == target.relativePath &&
                    $0.originalSHA256 == target.sealedSHA256 && $0.originalSize == target.originalSize
            }
            let backup = try existing ?? backupManager.backup(relativeArchivePath: target.relativePath, gameInstall: game)
            guard backup.originalSHA256 == target.sealedSHA256 else {
                throw CyberMacError.unsupported("Game archive changed during backup. Inspect again.")
            }
            let baselineURL = try backupManager.backupFileURL(backupID: backup.backupID)
            guard try PathSafety.sha256(url: baselineURL) == target.sealedSHA256 else {
                throw CyberMacError.unsupported("Backup content differs from the resource seal. No patch can be prepared from it.")
            }
            let baseline = try NativeArchive.read(baselineURL)
            let output = stageFolder.appendingPathComponent(target.relativePath)
            let hashes = Set(target.resourceHashes.compactMap { UInt64($0.dropFirst(2), radix: 16) })
            let insertions = target.relativePath == plan.newResourceTarget
                ? Set(plan.unmatchedResources.compactMap { UInt64($0.dropFirst(2), radix: 16) }) : []
            _ = try NativeArchive.stageReplacing(source: donor, target: baseline, hashes: hashes, insertionHashes: insertions, output: output)
            let digest = try PathSafety.sha256(url: output)
            files.append(AppearanceStagedArchive(
                relativePath: target.relativePath, stagedPath: output.path, stagedSHA256: digest,
                backupID: backup.backupID, backupPath: baselineURL.path, originalSHA256: backup.originalSHA256,
                resourceCount: hashes.count + insertions.count,
                installCommand: VerifiedFileReplacement.command(source: output.path, target: original.path, sha256: digest),
                restoreCommand: VerifiedFileReplacement.command(source: baselineURL.path, target: original.path, sha256: backup.originalSHA256)
            ))
        }
        guard try PathSafety.sha256(url: folder.appendingPathComponent("source.archive")) == plan.sourceSHA256 else {
            throw CyberMacError.unsupported("Source changed during staging. Inspect it again.")
        }
        for target in plan.targets {
            guard try PathSafety.sha256(url: officialURL(target.relativePath, contents: contents)) == target.sealedSHA256 else {
                throw CyberMacError.unsupported("Game changed during staging. Inspect it again.")
            }
        }
        let result = AppearancePatchStage(planID: id, createdAt: Date(), gameFingerprint: plan.gameFingerprint,
                                          gameAppPath: game.appURL.path, files: files, gameplayVerified: false)
        try save(result, to: folder.appendingPathComponent("stage.json"))
        complete = true
        return result
    }

    public func loadStage(_ id: String) throws -> AppearancePatchStage {
        var stage = try JSONDecoder.cybermac.decode(AppearancePatchStage.self, from: Data(contentsOf: try directory(id).appendingPathComponent("stage.json")))
        guard stage.planID == id else { throw CyberMacError.invalidInput("Appearance stage ID mismatch.") }
        stage.files = stage.files.map { file in
            var updated = file
            let target = URL(fileURLWithPath: stage.gameAppPath).appendingPathComponent("Contents/\(file.relativePath)").path
            updated.installCommand = VerifiedFileReplacement.command(source: file.stagedPath, target: target, sha256: file.stagedSHA256)
            updated.restoreCommand = VerifiedFileReplacement.command(source: file.backupPath, target: target, sha256: file.originalSHA256)
            return updated
        }
        return stage
    }

    public func verify(id: String, game: GameInstall, restore: Bool = false) throws -> AppearancePatchVerification {
        try validateHome(game)
        let stage = try loadStage(id)
        let plan = try loadPlan(id)
        guard stage.gameAppPath == game.appURL.path, plan.gameAppPath == stage.gameAppPath,
              plan.gameFingerprint == stage.gameFingerprint,
              stage.gameFingerprint == (try BaseCacheManager(home: home).fingerprint(gameInstall: game)).id else {
            throw CyberMacError.unsupported("This experiment belongs to another game installation or version.")
        }
        let seals = try sealedArchives(game)
        let contents = game.appURL.appendingPathComponent("Contents", isDirectory: true)
        var results: [String: Bool] = [:]
        guard !stage.files.isEmpty, Set(stage.files.map(\.relativePath)).count == stage.files.count,
              Set(stage.files.map(\.relativePath)) == Set(plan.targets.map(\.relativePath)) else {
            throw CyberMacError.invalidInput("Staged files do not match the appearance plan.")
        }
        let backupManager = OfficialArchiveBackupManager(home: home)
        for file in stage.files {
            guard let sealedHash = seals[file.relativePath]?.sha256, sealedHash == file.originalSHA256 else {
                throw CyberMacError.unsafePath("Original hash does not match the game's resource seal.")
            }
            let expectedOutput = try directory(id).appendingPathComponent("staged/\(file.relativePath)")
            try PathSafety.validateContainedPath(expectedOutput.resolvingSymlinksInPath(), in: try directory(id))
            let backup = try backupManager.load(backupID: file.backupID)
            let backupURL = try backupManager.backupFileURL(backupID: file.backupID)
            guard file.stagedPath == expectedOutput.path, file.backupPath == backupURL.path,
                  backup.gameAppPath == game.appURL.path, backup.relativeArchivePath == file.relativePath,
                  backup.originalSHA256 == sealedHash,
                  try PathSafety.sha256(url: backupURL) == sealedHash,
                  try PathSafety.sha256(url: expectedOutput) == file.stagedSHA256 else {
                throw CyberMacError.invalidInput("Prepared archive or original backup failed integrity verification.")
            }
            let url = try officialURL(file.relativePath, contents: contents)
            results[file.relativePath] = try PathSafety.sha256(url: url) == (restore ? file.originalSHA256 : file.stagedSHA256)
        }
        let result = AppearancePatchVerification(planID: id, mode: restore ? "restore" : "install",
                                                  matched: results.values.allSatisfy { $0 }, fileMatches: results, gameplayVerified: false)
        try save(result, to: try directory(id).appendingPathComponent(restore ? "restore-verification.json" : "install-verification.json"))
        return result
    }

    private func makePlan(id: String, game: GameInstall, packageName: String, selected: String, itemIDs: [String]) throws -> AppearancePatchPlan {
        let sourceURL = try directory(id).appendingPathComponent("source.archive")
        let sourceAttributes = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard sourceAttributes.isRegularFile == true, sourceAttributes.isSymbolicLink != true else { throw CyberMacError.unsafePath("Staged source is not a regular file.") }
        let donor = try NativeArchive.read(sourceURL)
        let donorHashes = Set(donor.records.map(\.hash))
        guard donorHashes.count == donor.records.count, !donorHashes.isEmpty else {
            throw CyberMacError.invalidInput("Mod archive is empty or contains duplicate resource hashes.")
        }
        var missingDependencies = Set(donor.dependencies).subtracting(donorHashes)
        var unmatched = donorHashes
        let seals = try sealedArchives(game)
        let contents = game.appURL.appendingPathComponent("Contents", isDirectory: true)
        var targets: [AppearanceArchiveTarget] = []
        for path in seals.keys.sorted() {
            try autoreleasepool {
                let url = try officialURL(path, contents: contents)
                let archive = try NativeArchive.read(url)
                var matches = Set<UInt64>()
                for record in archive.records {
                    missingDependencies.remove(record.hash)
                    if donorHashes.contains(record.hash) { matches.insert(record.hash); unmatched.remove(record.hash) }
                }
                if !matches.isEmpty {
                    targets.append(AppearanceArchiveTarget(relativePath: path, resourceHashes: matches.sorted().map(NativeArchive.hex),
                                                           indexFingerprint: archive.indexFingerprint, originalSize: archive.actualSize,
                                                           sealedSHA256: seals[path]?.sha256))
                }
            }
        }
        let info = try Data(contentsOf: contents.appendingPathComponent("Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any]
        return AppearancePatchPlan(
            id: id, createdAt: Date(), gameAppPath: game.appURL.path,
            gameVersion: plist?["CFBundleShortVersionString"] as? String ?? "Unknown",
            gameBuild: plist?["CFBundleVersion"] as? String ?? "Unknown",
            gameFingerprint: try BaseCacheManager(home: home).fingerprint(gameInstall: game).id,
            packageName: packageName, selectedArchiveEntry: selected,
            sourceSHA256: try PathSafety.sha256(url: sourceURL), recordCount: donor.records.count,
            officialArchiveCount: seals.count, targets: targets, unmatchedResources: unmatched.sorted().map(NativeArchive.hex),
            newResourceTarget: !unmatched.isEmpty && targets.count == 1 ? targets.first?.relativePath : nil,
            unresolvedDependencies: missingDependencies.sorted().map(NativeArchive.hex), itemIDs: itemIDs,
            warnings: ["Experimental appearance replacement; gameplay is unverified.",
                       "Resource matches do not prove body/refit compatibility or that the correct garment is equipped.",
                       "Staging creates backups and separate outputs. Game installation and restore are manual."]
        )
    }

    private struct Seal { let sha256: String? }
    private func sealedArchives(_ game: GameInstall) throws -> [String: Seal] {
        let contents = game.appURL.appendingPathComponent("Contents", isDirectory: true)
        let data = try Data(contentsOf: contents.appendingPathComponent("_CodeSignature/CodeResources"))
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let files = plist["files2"] as? [String: Any] else {
            throw CyberMacError.invalidInput("Game resource seal is missing its files2 table.")
        }
        var result: [String: Seal] = [:]
        for (path, value) in files where path.hasPrefix("Data/archive/Mac/") && path.hasSuffix(".archive") {
            _ = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(path)
            let hash = (value as? [String: Any])?["hash2"] as? Data
            result[path] = Seal(sha256: hash?.count == 32 ? hash?.map { String(format: "%02x", $0) }.joined() : nil)
        }
        guard !result.isEmpty else { throw CyberMacError.notFound("No sealed Mac archives found in this installation.") }
        return result
    }

    private func officialURL(_ path: String, contents: URL) throws -> URL {
        _ = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(path)
        let url = contents.appendingPathComponent(path)
        try PathSafety.validateContainedPath(url.resolvingSymlinksInPath(), in: contents.resolvingSymlinksInPath())
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CyberMacError.unsafePath("Official archive is not a regular file.") }
        return url
    }
    private func validateHome(_ game: GameInstall) throws {
        let root = home.homeURL.resolvingSymlinksInPath().standardizedFileURL.path
        let app = game.appURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard root != app, !root.hasPrefix(app + "/") else { throw CyberMacError.unsafePath("CyberMac workspace must be outside the game app.") }
        for managed in [home.generatedURL, home.officialArchiveBackupsURL] {
            let resolved = managed.resolvingSymlinksInPath().standardizedFileURL
            try PathSafety.validateContainedPath(resolved, in: home.homeURL.resolvingSymlinksInPath())
            guard resolved.path != app, !resolved.path.hasPrefix(app + "/") else { throw CyberMacError.unsafePath("Managed folders must not point into the game.") }
        }
    }
    private func directory(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw CyberMacError.invalidInput("Invalid appearance experiment ID.") }
        let root = home.generatedURL.appendingPathComponent("appearance", isDirectory: true)
        let result = root.appendingPathComponent(id, isDirectory: true)
        try PathSafety.validateContainedPath(result.resolvingSymlinksInPath(), in: root.resolvingSymlinksInPath())
        return result
    }
    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try JSONEncoder.cybermac.encode(value).write(to: url, options: .atomic)
    }
}
