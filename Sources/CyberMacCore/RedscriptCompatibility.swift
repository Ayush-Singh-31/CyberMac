import Foundation

public enum RedscriptCompatibility {
    public static func gameVersion(_ game: GameInstall) throws -> String? {
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: game.appURL.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
        return info?["CFBundleShortVersionString"] as? String
    }

    public static func setupIssue(runtimeVersion: String?, gameVersion: String?) -> String? {
        guard let gameVersion, gameVersion.compare("2.5", options: .numeric) != .orderedAscending else { return nil }
        guard let runtimeVersion, !runtimeVersion.contains("-"),
              runtimeVersion.split(separator: ".").count >= 3,
              runtimeVersion.split(separator: ".").allSatisfy({ Int($0) != nil }) else {
            return "Cyberpunk \(gameVersion) needs the macOS redscript 0.5.32 release or newer. Drop the original versioned release ZIP so CyberMac can verify its version, then retry."
        }
        guard runtimeVersion.compare("0.5.32", options: .numeric) != .orderedAscending else {
            return "redscript \(runtimeVersion) cannot read Cyberpunk \(gameVersion)'s script cache. Drop the official macOS redscript 0.5.32 release or newer, then retry. Your game files have not been changed."
        }
        return nil
    }
}
