import Foundation
import CyberMacCore

enum StandaloneClothingCommands {
    static func run(_ args: [String]) throws {
        guard args.first == "prepare" else {
            throw CyberMacError.invalidInput("Use clothing prepare --compiler <redscript-cli> --original-scripts <verified-original> --out-dir <new-folder> [--game-app <app>] [--lucy-assets <manifest> --original-appearance <existing-original-archive>].")
        }
        let allowed: Set<String> = ["--compiler", "--original-scripts", "--out-dir", "--game-app", "--lucy-assets", "--original-appearance"]
        var values: [String: String] = [:]
        var index = 1
        while index < args.count {
            let key = args[index]
            guard allowed.contains(key), values[key] == nil, index + 1 < args.count,
                  !args[index + 1].hasPrefix("--") else { throw CyberMacError.invalidInput("Unknown, missing or repeated clothing option: \(key)") }
            values[key] = args[index + 1]; index += 2
        }
        guard let compiler = values["--compiler"], let original = values["--original-scripts"], let output = values["--out-dir"] else {
            throw CyberMacError.invalidInput("Clothing preparation needs --compiler, --original-scripts and --out-dir.")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: values["--game-app"])
        let folder = try StandaloneClothingPreparer().prepare(game: game, compiler: PathSafety.expandedURL(from: compiler),
            originalScripts: PathSafety.expandedURL(from: original), output: PathSafety.expandedURL(from: output),
            lucyAssets: values["--lucy-assets"].map(PathSafety.expandedURL(from:)),
            originalAppearance: values["--original-appearance"].map(PathSafety.expandedURL(from:)))
        print("Four independent clothing records and their inventory/equipment helper are prepared. No game files changed.")
        print("Run: \(folder.appendingPathComponent("Run New Clothing.command").path)")
        print("The command installs, launches, adds the new pieces and requests equipment on save load, then restores originals after exit.")
        print(values["--lucy-assets"] == nil
            ? "The pieces retain vanilla visuals and icons. Record acceptance, inventory labels and equipment still need the combined gameplay test."
            : "The four duplicates use isolated Lucy outfit assets for feminine V. Original inventory icons remain; gameplay is unverified.")
        print("Keep your reference save untouched; a saved custom item needs its record installed on future launches.")
    }
}
