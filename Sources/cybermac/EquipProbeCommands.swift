import Foundation
import CyberMacCore

enum EquipProbeCommands {
    static func run(_ arguments: [String]) throws {
        if arguments.first == "run" {
            guard arguments.count == 3, arguments[1] == "--directory" else {
                throw CyberMacError.invalidInput("Use redscript equip-probe run --directory <prepared-directory>.")
            }
            _ = try EquipProbeRunner().run(directory: PathSafety.expandedURL(from: arguments[2]))
            return
        }
        guard arguments.first == "prepare" else {
            throw CyberMacError.invalidInput("Use redscript equip-probe prepare --compiler <redscript-cli> --original-cache <existing-restore-copy> --out-dir <new-directory> --item <Items.ID> [--item <Items.ID>] [--game-app <app>].")
        }
        var values: [String: String] = [:]
        var items: [String] = []
        var i = 1
        let allowed: Set<String> = ["--compiler", "--original-cache", "--out-dir", "--item", "--game-app"]
        while i < arguments.count {
            let flag = arguments[i]
            guard allowed.contains(flag), i + 1 < arguments.count,
                  !arguments[i + 1].hasPrefix("--"), flag == "--item" || values[flag] == nil else {
                throw CyberMacError.invalidInput("Missing, repeated or unknown equip probe option: \(flag)")
            }
            if flag == "--item" { items.append(arguments[i + 1]) }
            else { values[flag] = arguments[i + 1] }
            i += 2
        }
        guard let compiler = values["--compiler"], let original = values["--original-cache"], let output = values["--out-dir"] else {
            throw CyberMacError.invalidInput("Equip probe preparation requires --compiler, --original-cache and --out-dir.")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: values["--game-app"])
        let directory = try EquipProbePreparer().prepare(game: game,
            compiler: PathSafety.expandedURL(from: compiler), originalCache: PathSafety.expandedURL(from: original),
            outputDirectory: PathSafety.expandedURL(from: output), itemIDs: items,
            commandLineTool: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL)
        print("Read-only equip probe compiled. No game files changed and no new backup made.")
        print("Prepared files: \(directory.path)")
        print("With the game fully closed, run Run Equip Probe.command from this directory.")
        print("That command installs, verifies the startup trace, starts recording, launches normally, and restores after exit.")
        print("Look for CYBERMAC SCRIPT EXECUTED / MENU at the main menu, then try clothing and a saved wardrobe outfit.")
        print("Runtime remains unverified until this test. Keep your reference save slot untouched.")
    }
}
