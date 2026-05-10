import Foundation

public struct ManifestStore: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func save(_ manifest: InstalledModManifest) throws {
        try home.bootstrap()
        let url = manifestURL(id: manifest.id)
        let data = try JSONEncoder.cybermac.encode(manifest)
        try data.write(to: url, options: [.atomic])
    }

    public func load(id: String) throws -> InstalledModManifest {
        let url = manifestURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CyberMacError.notFound("Manifest not found for mod id: \(id)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.cybermac.decode(InstalledModManifest.self, from: data)
    }

    public func list() throws -> [InstalledModManifest] {
        guard FileManager.default.fileExists(atPath: home.manifestsURL.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: home.manifestsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { try JSONDecoder.cybermac.decode(InstalledModManifest.self, from: Data(contentsOf: $0)) }
            .sorted { $0.installedAt > $1.installedAt }
    }

    public func manifestURL(id: String) -> URL {
        home.manifestsURL.appendingPathComponent("\(id).json")
    }
}
