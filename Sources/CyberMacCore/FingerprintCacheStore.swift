import Foundation

public struct FingerprintCacheEntry: Codable, Equatable, Sendable {
    public let path: String
    public let sizeBytes: UInt64
    public let modificationTime: TimeInterval?
    public let sha256: String

    public init(path: String, sizeBytes: UInt64, modificationTime: TimeInterval?, sha256: String) {
        self.path = path
        self.sizeBytes = sizeBytes
        self.modificationTime = modificationTime
        self.sha256 = sha256
    }
}

public struct FingerprintCacheFile: Codable, Equatable, Sendable {
    public var entries: [String: FingerprintCacheEntry]

    public init(entries: [String: FingerprintCacheEntry] = [:]) {
        self.entries = entries
    }
}

public struct FingerprintCacheStore: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public var cacheURL: URL {
        home.configURL.appendingPathComponent("fingerprint-cache.json")
    }

    public func sha256(url: URL) throws -> String {
        let path = url.path
        let size = try PathSafety.fileSize(url: url)
        let modificationTime = try PathSafety.modificationDate(url: url)?.timeIntervalSince1970
        var cache = load()
        if let entry = cache.entries[path],
           entry.sizeBytes == size,
           entry.modificationTime == modificationTime {
            return entry.sha256
        }

        let sha = try PathSafety.sha256(url: url)
        cache.entries[path] = FingerprintCacheEntry(
            path: path,
            sizeBytes: size,
            modificationTime: modificationTime,
            sha256: sha
        )
        try save(cache)
        return sha
    }

    public func load() -> FingerprintCacheFile {
        guard FileManager.default.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder.cybermac.decode(FingerprintCacheFile.self, from: data)
        else {
            return FingerprintCacheFile()
        }
        return cache
    }

    public func save(_ cache: FingerprintCacheFile) throws {
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.cybermac.encode(cache)
        try data.write(to: cacheURL, options: [.atomic])
    }
}
