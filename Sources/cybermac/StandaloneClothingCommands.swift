import Foundation
import CyberMacCore

enum StandaloneClothingCommands {
    static func run(_ args: [String]) throws {
        if args.first == "inspect-import" || args.first == "prepare-import" {
            var values: [String: String] = [:]
            var index = 1
            let allowed: Set<String> = ["--zip", "--game-app", "--home", "--records", "--out"]
            while index < args.count {
                guard allowed.contains(args[index]), values[args[index]] == nil, index + 1 < args.count else {
                    throw CyberMacError.invalidInput("Invalid clothing import option.")
                }
                values[args[index]] = args[index + 1]; index += 2
            }
            guard let zip = values["--zip"] else { throw CyberMacError.invalidInput("Choose --zip <clothing.zip>.") }
            let home = CyberMacHomeManager(homeURL: values["--home"].map(PathSafety.expandedURL(from:)))
            let package = try ModPackageRouter(home: home).retain(PathSafety.expandedURL(from: zip))
            let game = try GameInstallDetector().detect(preferredAppPath: values["--game-app"])
            let manager = ClothingAdditionInstaller(home: home)
            if args.first == "inspect-import" {
                let data = try JSONEncoder.cybermac.encode(manager.contents(package, game: game))
                print(String(decoding: data, as: UTF8.self))
                return
            }
            guard let raw = values["--records"], let out = values["--out"] else { throw CyberMacError.invalidInput("Use --records <comma-separated IDs> --out <plan.json>. Preparation does not install game files.") }
            switch try manager.prepare(package, records: raw.split(separator: ",").map(String.init), game: game) {
            case .prepared(let transaction, let appearanceID):
                struct Plan: Encodable { let transaction: ModInstallTransaction; let appearanceID: String? }
                try JSONEncoder.cybermac.encode(Plan(transaction: transaction, appearanceID: appearanceID)).write(to: PathSafety.expandedURL(from: out), options: .atomic)
                print("Selected clothing prepared; game files are unchanged. Plan: \(out)")
            case .needsSetup(let message), .blocked(let message): throw CyberMacError.unsupported(message)
            default: throw CyberMacError.unsupported("Clothing preparation did not produce an install plan.")
            }
            return
        }
        if args.first == "register" {
            guard args.count == 3, args[1] == "--workspace" else { throw CyberMacError.invalidInput("Use clothing register --workspace <icon-wardrobe>.") }
            let wardrobe = try ClothingWardrobeManager().register(workspace: PathSafety.expandedURL(from: args[2]))
            print("\(wardrobe.items.count) clothing pieces registered in the app. Existing large files referenced; no game files changed.")
            return
        }
        if args.first == "icons" {
            let allowed: Set<String> = ["--workspace", "--icons", "--out-dir", "--game-app"]
            var options: [String: String] = [:]
            var i = 1
            while i < args.count {
                guard allowed.contains(args[i]), options[args[i]] == nil, i + 1 < args.count,
                      !args[i + 1].hasPrefix("--") else { throw CyberMacError.invalidInput("Invalid clothing icons option.") }
                options[args[i]] = args[i + 1]; i += 2
            }
            guard let workspace = options["--workspace"], let icons = options["--icons"], let output = options["--out-dir"] else {
                throw CyberMacError.invalidInput("Use clothing icons --workspace <working-wardrobe> --icons <icons.json> --out-dir <new-folder>.")
            }
            let game = try GameInstallDetector().detect(preferredAppPath: options["--game-app"])
            let root = try StandaloneClothingPreparer().prepareIcons(game: game, workspace: PathSafety.expandedURL(from: workspace),
                iconsURL: PathSafety.expandedURL(from: icons), output: PathSafety.expandedURL(from: output))
            try StandaloneClothingPreparer().writeClothingChooser(game: game, output: root,
                commandLineTool: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL)
            print("Rendered icon wardrobe prepared: \(root.path). No game files changed; icons require a gameplay check.")
            return
        }
        let refresh = args.first == "refresh"
        let select = args.first == "select"
        guard args.first == "prepare" || refresh || select else {
            throw CyberMacError.invalidInput("Use clothing prepare --compiler <redscript-cli> --original-scripts <verified-original> --out-dir <new-folder> [--game-app <app>] [--lucy-assets <manifest> --original-appearance <existing-original-archive>].")
        }
        let allowed: Set<String> = select ? ["--out-dir", "--game-app", "--group", "--records"] : (refresh ? ["--out-dir", "--game-app"] : ["--compiler", "--original-scripts", "--out-dir", "--game-app", "--lucy-assets", "--original-appearance", "--assets", "--restore-from"])
        var values: [String: String] = [:]
        var index = 1
        while index < args.count {
            let key = args[index]
            guard allowed.contains(key), values[key] == nil, index + 1 < args.count,
                  !args[index + 1].hasPrefix("--") else { throw CyberMacError.invalidInput("Unknown, missing or repeated clothing option: \(key)") }
            values[key] = args[index + 1]; index += 2
        }
        guard let output = values["--out-dir"] else { throw CyberMacError.invalidInput("Clothing commands need --out-dir.") }
        let game = try GameInstallDetector().detect(preferredAppPath: values["--game-app"])
        if select {
            guard (values["--group"] == nil) != (values["--records"] == nil) else {
                throw CyberMacError.invalidInput("Use --group jinguji|lucy|both|none or --records <comma-separated item IDs>.")
            }
            if let group = values["--group"] {
                try StandaloneClothingPreparer().selectClothes(game: game, output: PathSafety.expandedURL(from: output), group: group)
            } else if let raw = values["--records"] {
                try StandaloneClothingPreparer().selectClothes(game: game, output: PathSafety.expandedURL(from: output),
                    records: raw.isEmpty ? [] : raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init))
            }
            print("Clothing selection prepared without auto-equipping. No game files changed.")
            return
        }
        if refresh {
            try StandaloneClothingPreparer().refreshCommands(game: game, output: PathSafety.expandedURL(from: output))
            print("Launch and recovery commands updated. Existing payloads and restore files reused; no game files changed.")
            return
        }
        guard let compiler = values["--compiler"], let original = values["--original-scripts"] else {
            throw CyberMacError.invalidInput("Clothing preparation needs --compiler and --original-scripts.")
        }
        let folder = try StandaloneClothingPreparer().prepare(game: game, compiler: PathSafety.expandedURL(from: compiler),
            originalScripts: PathSafety.expandedURL(from: original), output: PathSafety.expandedURL(from: output),
            lucyAssets: values["--lucy-assets"].map(PathSafety.expandedURL(from:)),
            originalAppearance: values["--original-appearance"].map(PathSafety.expandedURL(from:)),
            assetsManifest: values["--assets"].map(PathSafety.expandedURL(from:)),
            reuseRestoreManifest: values["--restore-from"].map(PathSafety.expandedURL(from:)))
        if values["--assets"] != nil {
            try StandaloneClothingPreparer().writeClothingChooser(game: game, output: folder,
                commandLineTool: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL)
            print("Lucy and Jinguji wardrobe prepared. No game files changed.")
            print("Run: \(folder.appendingPathComponent("Choose Clothes and Play.command").path)")
            print("Choose Jinguji, Lucy, both or no new grants. Equip the pieces yourself; active wardrobe outfits may hide them.")
            print("Jinguji gameplay is unverified. Keep your reference save untouched.")
            return
        }
        print("Four independent clothing records and their inventory/equipment helper are prepared. No game files changed.")
        print("Run: \(folder.appendingPathComponent("Run New Clothing.command").path)")
        print("The command installs, launches, adds the new pieces and requests equipment on save load, then restores originals after exit.")
        print(values["--lucy-assets"] == nil
            ? "The pieces retain vanilla visuals and icons. Record acceptance, inventory labels and equipment still need the combined gameplay test."
            : "The four duplicates use isolated Lucy outfit assets for feminine V. Original inventory icons remain; gameplay is unverified.")
        print("Keep your reference save untouched; a saved custom item needs its record installed on future launches.")
    }
}
