import Foundation
import CyberMacCore

enum BodyCommands {
    static func run(_ arguments: [String]) throws {
        guard arguments.first == "prepare", arguments.count >= 2 else {
            throw CyberMacError.invalidInput("Use body prepare <body.zip> --variant neutral|shoulders|player|shared --out <plan.json> [--home <directory>].")
        }
        var options: [String: String] = [:]
        var index = 2
        while index < arguments.count {
            let key = arguments[index]
            guard ["--variant", "--out", "--home", "--game-app"].contains(key), index + 1 < arguments.count,
                  !arguments[index + 1].hasPrefix("--"), options[key] == nil else {
                throw CyberMacError.invalidInput("Invalid body option: \(key)")
            }
            options[key] = arguments[index + 1]; index += 2
        }
        guard let mode = options["--variant"], ["neutral", "shoulders", "player", "shared"].contains(mode), let output = options["--out"] else {
            throw CyberMacError.invalidInput("Specify --variant neutral|shoulders|player|shared and --out <plan.json>.")
        }
        let home = CyberMacHomeManager(homeURL: options["--home"].map(PathSafety.expandedURL))
        let game = try GameInstallDetector().detect(preferredAppPath: options["--game-app"])
        let package = PathSafety.expandedURL(from: arguments[1])
        let choices = try BodyModInstaller.variants(for: package)
        guard ["player", "shared"].contains(mode) == (choices != BodyModInstaller.variants) else {
            throw CyberMacError.invalidInput("Use player|shared for an authored body preset, or neutral|shoulders for the Unique V framework.")
        }
        let variant = choices[["neutral", "player"].contains(mode) ? 0 : 1]
        let installer = AutomaticModInstaller(home: home)
        guard case .prepared(let transaction, let identity) = try installer.prepare(package, variant: variant, game: game) else {
            throw CyberMacError.unsupported("Body conversion did not prepare an installation.")
        }
        struct Plan: Encodable { let transaction: ModInstallTransaction; let appearanceID: String?; let variant: String }
        let destination = PathSafety.expandedURL(from: output)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.cybermac.encode(Plan(transaction: transaction, appearanceID: identity, variant: variant)).write(to: destination, options: .atomic)
        print("Body prepared and verified structurally: \(variant). Game files were not changed.")
        print("Install plan: \(destination.path)")
        print("Game archives: \(transaction.files.count). Visible in-game result still needs checking.")
    }
}
