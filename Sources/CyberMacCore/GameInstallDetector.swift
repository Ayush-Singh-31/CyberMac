import Foundation

public struct GameInstallDetector: Sendable {
    public init() {}

    public func detect(preferredAppPath: String? = nil) throws -> GameInstall {
        if let preferredAppPath, !preferredAppPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let preferredURL = PathSafety.expandedURL(from: preferredAppPath)
            if let install = inspect(appURL: preferredURL) {
                return install
            }
            throw CyberMacError.notFound("No supported Cyberpunk install at \(preferredURL.path)")
        }

        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let knownURL = applicationsURL.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        if let install = inspect(appURL: knownURL) {
            return install
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for appURL in contents where appURL.pathExtension == "app" {
            if let install = inspect(appURL: appURL) {
                return install
            }
        }

        throw CyberMacError.notFound("Cyberpunk 2077 Mac App Store install was not found in /Applications")
    }

    public func inspect(appURL: URL) -> GameInstall? {
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let receiptURL = contentsURL.appendingPathComponent("_MASReceipt/receipt")
        let archiveMacURL = dataURL.appendingPathComponent("archive/Mac", isDirectory: true)
        let r6URL = dataURL.appendingPathComponent("r6", isDirectory: true)

        guard FileManager.default.fileExists(atPath: executableURL.path),
              FileManager.default.fileExists(atPath: dataURL.path)
        else {
            return nil
        }

        let storefront: Storefront = FileManager.default.fileExists(atPath: receiptURL.path) ? .macAppStore : .unknown
        let displayName = readDisplayName(appURL: appURL) ?? appURL.deletingPathExtension().lastPathComponent

        return GameInstall(
            appURL: appURL,
            executableURL: executableURL,
            dataURL: dataURL,
            archiveMacURL: FileManager.default.fileExists(atPath: archiveMacURL.path) ? archiveMacURL : nil,
            r6URL: FileManager.default.fileExists(atPath: r6URL.path) ? r6URL : nil,
            storefront: storefront,
            displayName: displayName
        )
    }

    private func readDisplayName(appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else { return nil }

        return dict["CFBundleDisplayName"] as? String
            ?? dict["CFBundleName"] as? String
    }
}
