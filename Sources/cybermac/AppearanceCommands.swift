import Foundation
import CyberMacCore

enum AppearanceCommands {
    static func run(_ arguments: [String]) throws {
        guard let action = arguments.first, ["inspect", "stage", "verify", "prepare-delivery", "verify-delivery"].contains(action) else {
            throw CyberMacError.invalidInput("Use appearance inspect, stage, verify, prepare-delivery or verify-delivery.")
        }
        var values: [String: String] = [:]
        var flags = Set<String>()
        var positional: [String] = []
        var i = 1
        while i < arguments.count {
            let token = arguments[i]
            if ["--json", "--restore"].contains(token) { flags.insert(token) }
            else if ["--game-app", "--home", "--archive-entry", "--redscript-zip"].contains(token) {
                guard i + 1 < arguments.count, !arguments[i+1].hasPrefix("--"), values[token] == nil else {
                    throw CyberMacError.invalidInput("Missing or repeated value for \(token)")
                }
                i += 1; values[token] = arguments[i]
            } else if token.hasPrefix("--") { throw CyberMacError.invalidInput("Unknown appearance option: \(token)") }
            else { positional.append(token) }
            i += 1
        }
        guard positional.count == 1 else { throw CyberMacError.invalidInput("Specify one mod path or experiment ID.") }
        guard action == "inspect" || values["--archive-entry"] == nil,
              ["verify", "verify-delivery"].contains(action) || !flags.contains("--restore"),
              action == "prepare-delivery" || values["--redscript-zip"] == nil else {
            throw CyberMacError.invalidInput("--archive-entry is for inspect; --restore is for verification; --redscript-zip is for prepare-delivery.")
        }
        let home = CyberMacHomeManager(homeURL: values["--home"].map(PathSafety.expandedURL))
        let manager = AppearancePatchManager(home: home)
        let game = try GameInstallDetector().detect(preferredAppPath: values["--game-app"])
        switch action {
        case "inspect":
            let plan = try manager.inspect(packageURL: PathSafety.expandedURL(from: positional[0]), game: game,
                                           archiveEntry: values["--archive-entry"])
            if flags.contains("--json") { try json(plan); return }
            print("Appearance mod inspection — feminine V / clothing research")
            print("Experiment: \(plan.id)")
            print("Game: \(plan.gameVersion) (\(plan.gameBuild)), \(game.storefront.rawValue)")
            print("Package: \(plan.packageName)")
            print("Selected archive: \(plan.selectedArchiveEntry)")
            print("Resources: \(plan.recordCount); sealed archives inspected: \(plan.officialArchiveCount)")
            for target in plan.targets { print("  \(target.relativePath): \(target.resourceHashes.count) replacements") }
            print("New resources: \(plan.unmatchedResources.count)")
            if let target = plan.newResourceTarget { print("New resource destination: \(target)") }
            print("Unresolved dependencies: \(plan.unresolvedDependencies.count)")
            print("Existing item IDs: \(plan.itemIDs.joined(separator: ", "))")
            print("Ready to stage: \(plan.canStage ? "yes" : "no")")
            print("Gameplay: unverified")
            for warning in plan.warnings { print("  \(warning)") }
        case "stage":
            let stage = try manager.stage(id: positional[0], game: game)
            if flags.contains("--json") { try json(stage); return }
            print("Verified appearance archives staged. Game files were not changed.")
            print("Experiment: \(stage.planID)")
            for file in stage.files {
                print("\n\(file.relativePath): \(file.resourceCount) replacement resources")
                print("Output SHA-256: \(file.stagedSHA256)")
                print("Backup: \(file.backupID)")
                print("Manual install:\n\(file.installCommand)")
                print("Manual restore:\n\(file.restoreCommand)")
            }
            print("\nUse appearance verify with the same --home after manual installation or restoration.")
            print("A matching file hash is not proof of a visible in-game result.")
        case "prepare-delivery":
            guard let runtime = values["--redscript-zip"] else {
                throw CyberMacError.invalidInput("Specify --redscript-zip /path/to/redscript-v0.5.32-macos.zip (or newer).")
            }
            let delivery = try manager.prepareItemDelivery(id: positional[0], game: game, runtimeZipURL: PathSafety.expandedURL(from: runtime))
            if flags.contains("--json") { try json(delivery); return }
            print("Clothing inventory helper compiled with redscript \(delivery.runtimeVersion). Game files were not changed.")
            print("Package: \(delivery.packageName)")
            print("Items delivered on loading V: \(delivery.itemIDs.count); already-owned items are skipped.")
            print("Manual install:\n\(delivery.installCommand)")
            print("Manual restore:\n\(delivery.restoreCommand)")
            print("Use appearance verify-delivery with the same --home. Runtime delivery remains unverified until tested in-game.")
        default:
            let result = action == "verify-delivery"
                ? try manager.verifyItemDelivery(id: positional[0], game: game, restore: flags.contains("--restore"))
                : try manager.verify(id: positional[0], game: game, restore: flags.contains("--restore"))
            if flags.contains("--json") { try json(result) }
            else {
                print("\(result.mode.capitalized) files matched: \(result.matched ? "yes" : "no")")
                for path in result.fileMatches.keys.sorted() { print("  \(path): \(result.fileMatches[path] == true ? "matched" : "different")") }
                print("Gameplay: unverified")
            }
            guard result.matched else { throw CyberMacError.fileSystem("Expected archive hashes do not match the game.") }
        }
    }
    private static func json<T: Encodable>(_ value: T) throws {
        print(String(decoding: try JSONEncoder.cybermac.encode(value), as: UTF8.self))
    }
}
