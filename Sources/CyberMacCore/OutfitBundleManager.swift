import Foundation

public struct OutfitBundleCreateRequest: Sendable {
    public let displayName: String
    public let targetArchive: String
    public let patchedArchiveURL: URL
    public let backupID: String
    public let affectedItemIDs: [String]
    public let affectedAssets: [String]
    public let optionalItemGrantModID: String?
    public let outputBundleURL: URL

    public init(
        displayName: String,
        targetArchive: String,
        patchedArchiveURL: URL,
        backupID: String,
        affectedItemIDs: [String],
        affectedAssets: [String],
        optionalItemGrantModID: String?,
        outputBundleURL: URL
    ) {
        self.displayName = displayName
        self.targetArchive = targetArchive
        self.patchedArchiveURL = patchedArchiveURL
        self.backupID = backupID
        self.affectedItemIDs = affectedItemIDs
        self.affectedAssets = affectedAssets
        self.optionalItemGrantModID = optionalItemGrantModID
        self.outputBundleURL = outputBundleURL
    }
}

public struct OutfitBundleCreateResult: Sendable {
    public let bundle: CyberMacOutfitBundle
    public let bundleURL: URL
    public let homeRegistrationURL: URL?

    public init(bundle: CyberMacOutfitBundle, bundleURL: URL, homeRegistrationURL: URL?) {
        self.bundle = bundle
        self.bundleURL = bundleURL
        self.homeRegistrationURL = homeRegistrationURL
    }
}

public struct OutfitBundleInstallPlan: Sendable {
    public let bundle: CyberMacOutfitBundle
    public let destinationPath: String
    public let sudoCommand: String
    public let preflightStatus: OfficialArchivePreflightStatus
    public let currentDestinationSHA256: String?
    public let warnings: [String]
}

public struct OutfitBundleRestorePlan: Sendable {
    public let bundle: CyberMacOutfitBundle
    public let restoreCommand: String
    public let verifyCommand: String
}

public struct OutfitBundleDisableGrantPlan: Sendable {
    public let modID: String
    public let disableCommand: String
    public let listModsCommand: String
}

public struct OutfitBundleManager: Sendable {
    public static let bundleFileExtension = "cybermacoutfit.json"

    private let home: CyberMacHomeManager
    private let officialArchiveBackup: OfficialArchiveBackupManager

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.officialArchiveBackup = OfficialArchiveBackupManager(home: home)
    }

    // MARK: - Create

    public func create(request: OutfitBundleCreateRequest) throws -> OutfitBundleCreateResult {
        try home.bootstrap()
        try Self.validateName(request.displayName)
        try Self.validateTargetArchive(request.targetArchive)
        let normalizedItemIDs = try Self.normalizeItemIDs(request.affectedItemIDs)
        let normalizedAssets = try Self.normalizeAssetPaths(request.affectedAssets)
        guard !request.backupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("--backup-id is required")
        }

        let patchedURL = request.patchedArchiveURL
        guard FileManager.default.fileExists(atPath: patchedURL.path) else {
            throw CyberMacError.notFound("Patched archive does not exist: \(patchedURL.path)")
        }
        let sha = try PathSafety.sha256(url: patchedURL)
        let size = try PathSafety.fileSize(url: patchedURL)

        let id = Self.makeBundleID(displayName: request.displayName)
        let bundle = CyberMacOutfitBundle(
            id: id,
            displayName: request.displayName,
            targetArchive: request.targetArchive,
            patchedArchivePath: patchedURL.path,
            patchedArchiveSHA256: sha,
            patchedArchiveSizeBytes: size,
            backupID: request.backupID,
            affectedItemIDs: normalizedItemIDs,
            affectedAssets: normalizedAssets,
            optionalItemGrantModID: Self.normalizeOptionalModID(request.optionalItemGrantModID),
            status: .staged,
            createdAt: Date()
        )

        let data = try JSONEncoder.cybermac.encode(bundle)
        try FileManager.default.createDirectory(
            at: request.outputBundleURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: request.outputBundleURL, options: [.atomic])

        let registrationURL = home.outfitBundlesURL.appendingPathComponent("\(id).json")
        try data.write(to: registrationURL, options: [.atomic])

        return OutfitBundleCreateResult(
            bundle: bundle,
            bundleURL: request.outputBundleURL,
            homeRegistrationURL: registrationURL
        )
    }

    // MARK: - Load / list

    public func load(bundleURL: URL) throws -> CyberMacOutfitBundle {
        guard FileManager.default.fileExists(atPath: bundleURL.path) else {
            throw CyberMacError.notFound("Outfit bundle not found: \(bundleURL.path)")
        }
        let data = try Data(contentsOf: bundleURL)
        do {
            return try JSONDecoder.cybermac.decode(CyberMacOutfitBundle.self, from: data)
        } catch {
            throw CyberMacError.invalidInput("Outfit bundle JSON could not be decoded: \(bundleURL.path): \(error.localizedDescription)")
        }
    }

    public func listRegistered() throws -> [CyberMacOutfitBundle] {
        try home.bootstrap()
        guard FileManager.default.fileExists(atPath: home.outfitBundlesURL.path) else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: home.outfitBundlesURL,
            includingPropertiesForKeys: nil
        )
        var bundles: [CyberMacOutfitBundle] = []
        for url in urls where url.pathExtension.lowercased() == "json" {
            if let bundle = try? load(bundleURL: url) {
                bundles.append(bundle)
            }
        }
        return bundles.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Install plan

    public func installPlan(
        bundle: CyberMacOutfitBundle,
        preferredGameAppPath: String? = nil
    ) throws -> OutfitBundleInstallPlan {
        let game = try GameInstallDetector().detect(preferredAppPath: preferredGameAppPath)
        let preflight = officialArchiveBackup.preflight(
            relativeArchivePath: bundle.targetArchive,
            gameInstall: game
        )
        guard let destinationPath = preflight.destinationPath else {
            throw CyberMacError.invalidInput("Could not resolve destination path for archive: \(bundle.targetArchive)")
        }

        let patchedURL = URL(fileURLWithPath: bundle.patchedArchivePath)
        guard FileManager.default.fileExists(atPath: patchedURL.path) else {
            throw CyberMacError.notFound("Patched archive missing on disk: \(bundle.patchedArchivePath)")
        }
        let currentSha = try PathSafety.sha256(url: patchedURL)
        var warnings: [String] = []
        if currentSha != bundle.patchedArchiveSHA256 {
            warnings.append("Patched archive SHA-256 has changed since the bundle was created. Expected \(bundle.patchedArchiveSHA256), found \(currentSha).")
        }
        if preflight.status == .blocked {
            warnings.append("Archive preflight blocked: \(preflight.reason ?? "unknown reason")")
        } else if preflight.status == .noBackup {
            warnings.append("No CyberMac backup found for the target archive. Run `cybermac archive-patch backup-official \(bundle.targetArchive)` before installing the patched archive.")
        } else if preflight.status == .missing {
            warnings.append("Target archive is missing on disk: \(destinationPath)")
        }

        let sudoCommand = "sudo cp \(PathSafety.shellQuoted(patchedURL.path)) \(PathSafety.shellQuoted(destinationPath))"

        return OutfitBundleInstallPlan(
            bundle: bundle,
            destinationPath: destinationPath,
            sudoCommand: sudoCommand,
            preflightStatus: preflight.status,
            currentDestinationSHA256: preflight.currentSHA256,
            warnings: warnings
        )
    }

    // MARK: - Restore plan

    public func restorePlan(
        bundle: CyberMacOutfitBundle,
        preferredGameAppPath: String? = nil
    ) throws -> OutfitBundleRestorePlan {
        let restoreCommand = try officialArchiveBackup.restoreDryRunCommand(
            backupID: bundle.backupID,
            preferredGameAppPath: preferredGameAppPath
        )
        return OutfitBundleRestorePlan(
            bundle: bundle,
            restoreCommand: restoreCommand,
            verifyCommand: "swift run cybermac archive-patch restore-official \(PathSafety.shellQuoted(bundle.backupID)) --verify"
        )
    }

    // MARK: - Disable grant plan

    public func disableGrantPlan(modID: String) throws -> OutfitBundleDisableGrantPlan {
        let trimmed = modID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("Missing <mod-id>. Usage: cybermac outfit-bundle disable-grant <mod-id>")
        }
        return OutfitBundleDisableGrantPlan(
            modID: trimmed,
            disableCommand: "swift run cybermac disable \(PathSafety.shellQuoted(trimmed))",
            listModsCommand: "swift run cybermac list-mods"
        )
    }

    // MARK: - Validation helpers

    static func validateName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("--name is required")
        }
    }

    static func validateTargetArchive(_ path: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("--target-archive is required")
        }
        guard trimmed.hasSuffix(".archive") else {
            throw CyberMacError.invalidInput("--target-archive must reference a .archive path: \(path)")
        }
        if trimmed.hasPrefix("/") {
            throw CyberMacError.invalidInput("--target-archive must be a relative path under the game bundle: \(path)")
        }
        if trimmed.contains("..") {
            throw CyberMacError.unsafePath("--target-archive contains traversal: \(path)")
        }
    }

    static func normalizeItemIDs(_ raw: [String]) throws -> [String] {
        guard !raw.isEmpty else {
            throw CyberMacError.invalidInput("At least one --item <Items.Some_Item_ID> is required")
        }
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CyberMacError.invalidInput("Item ID must not be empty")
            }
            guard trimmed.hasPrefix("Items.") else {
                throw CyberMacError.invalidInput("Item ID must start with 'Items.': \(value)")
            }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result.sorted()
    }

    static func normalizeAssetPaths(_ raw: [String]) throws -> [String] {
        guard !raw.isEmpty else {
            throw CyberMacError.invalidInput("At least one --asset <asset-path> is required")
        }
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CyberMacError.invalidInput("Asset path must not be empty")
            }
            if trimmed.hasPrefix("/") {
                throw CyberMacError.invalidInput("Asset path must be relative to the archive root: \(value)")
            }
            if trimmed.contains("..") {
                throw CyberMacError.unsafePath("Asset path contains traversal: \(value)")
            }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result.sorted()
    }

    static func normalizeOptionalModID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func makeBundleID(displayName: String, date: Date = Date()) -> String {
        return PathSafety.sanitizeModID(from: displayName, date: date)
    }
}

public enum OutfitBundleFormatter {
    public static func formatShow(_ bundle: CyberMacOutfitBundle) -> String {
        var lines: [String] = [
            "Outfit bundle",
            "ID: \(bundle.id)",
            "Name: \(bundle.displayName)",
            "Status: \(bundle.status.rawValue)",
            "Target archive: \(bundle.targetArchive)",
            "Patched archive: \(bundle.patchedArchivePath)",
            "Patched SHA-256: \(bundle.patchedArchiveSHA256)",
            "Patched size: \(bundle.patchedArchiveSizeBytes) bytes",
            "Backup ID: \(bundle.backupID)",
            "Created: \(bundle.createdAt)",
            "",
            "Item IDs (\(bundle.affectedItemIDs.count)):"
        ]
        for itemID in bundle.affectedItemIDs {
            lines.append("  - \(itemID)")
        }
        lines.append("")
        lines.append("Affected assets (\(bundle.affectedAssets.count)):")
        for asset in bundle.affectedAssets {
            lines.append("  - \(asset)")
        }
        if let modID = bundle.optionalItemGrantModID {
            lines.append("")
            lines.append("Item-grant helper mod id: \(modID)")
        }
        return lines.joined(separator: "\n")
    }

    public static func formatInstallPlan(_ plan: OutfitBundleInstallPlan) -> String {
        var lines: [String] = [
            "Outfit bundle install plan",
            "Bundle: \(plan.bundle.displayName) (\(plan.bundle.id))",
            "Target archive: \(plan.bundle.targetArchive)",
            "Destination: \(plan.destinationPath)",
            "Patched SHA-256: \(plan.bundle.patchedArchiveSHA256)",
            "Preflight status: \(plan.preflightStatus.rawValue)"
        ]
        if let currentSHA = plan.currentDestinationSHA256 {
            lines.append("Current destination SHA-256: \(currentSHA)")
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
        lines.append("")
        lines.append("CyberMac will not execute privileged commands. Verify after copying:")
        lines.append("  swift run cybermac archive-patch status \(PathSafety.shellQuoted(plan.bundle.targetArchive))")
        return lines.joined(separator: "\n")
    }

    public static func formatRestorePlan(_ plan: OutfitBundleRestorePlan) -> String {
        return [
            "Outfit bundle restore plan",
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

    public static func formatDisableGrantPlan(_ plan: OutfitBundleDisableGrantPlan) -> String {
        return [
            "Outfit bundle disable-grant plan",
            "Mod id: \(plan.modID)",
            "",
            "If you forgot the mod id, list installed mods:",
            plan.listModsCommand,
            "",
            "Run this to disable the grant helper:",
            plan.disableCommand,
            "",
            "Then re-activate so the change takes effect:",
            "  swift run cybermac activate --bundle-mode --game-app /path/to/Cyberpunk.app",
            "  # Run the printed sudo cp command(s).",
            "  swift run cybermac activate --verify --game-app /path/to/Cyberpunk.app"
        ].joined(separator: "\n")
    }
}
