import Foundation

public struct CyberMacHomeManager: Sendable {
    public let homeURL: URL

    public init(homeURL: URL? = nil) {
        if let homeURL {
            self.homeURL = homeURL
        } else {
            self.homeURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("CyberMac", isDirectory: true)
        }
    }

    public var configURL: URL { homeURL.appendingPathComponent("config", isDirectory: true) }
    public var runtimeURL: URL { homeURL.appendingPathComponent("runtime", isDirectory: true) }
    public var redscriptRuntimeURL: URL { runtimeURL.appendingPathComponent("redscript", isDirectory: true) }
    public var inputLoaderRuntimeURL: URL { runtimeURL.appendingPathComponent("input-loader", isDirectory: true) }
    public var overlayURL: URL { homeURL.appendingPathComponent("game-overlay", isDirectory: true) }
    public var overlayScriptsURL: URL { overlayURL.appendingPathComponent("r6/scripts", isDirectory: true) }
    public var overlayInputURL: URL { overlayURL.appendingPathComponent("r6/input", isDirectory: true) }
    public var overlayCacheURL: URL { overlayURL.appendingPathComponent("r6/cache", isDirectory: true) }
    public var baseCacheURL: URL { homeURL.appendingPathComponent("base-cache", isDirectory: true) }
    public var backupsURL: URL { homeURL.appendingPathComponent("backups", isDirectory: true) }
    public var inputPatchBackupsURL: URL { backupsURL.appendingPathComponent("input-config", isDirectory: true) }
    public var officialArchiveBackupsURL: URL { backupsURL.appendingPathComponent("official-archives", isDirectory: true) }
    public var tmpURL: URL { homeURL.appendingPathComponent("tmp", isDirectory: true) }
    public var generatedURL: URL { homeURL.appendingPathComponent("generated", isDirectory: true) }
    public var launchScriptURL: URL { generatedURL.appendingPathComponent("launch_modded.sh") }
    public var manifestsURL: URL { homeURL.appendingPathComponent("manifests", isDirectory: true) }
    public var disabledURL: URL { homeURL.appendingPathComponent("disabled", isDirectory: true) }
    public var logsURL: URL { homeURL.appendingPathComponent("logs", isDirectory: true) }
    public var scanCacheURL: URL { homeURL.appendingPathComponent("scan-cache", isDirectory: true) }
    public var diagnosticsURL: URL { homeURL.appendingPathComponent("diagnostics", isDirectory: true) }
    public var stateURL: URL { configURL.appendingPathComponent("state.json") }
    public var inputPatchStateURL: URL { configURL.appendingPathComponent("input-patches.json") }
    public var archiveProbeStateURL: URL { configURL.appendingPathComponent("archive-probe-state.json") }
    public var archiveProbeTmpURL: URL { tmpURL.appendingPathComponent("archive-probe", isDirectory: true) }
    public var archiveIndexURL: URL { homeURL.appendingPathComponent("archive-index", isDirectory: true) }
    public var archiveIndexDatabaseURL: URL { archiveIndexURL.appendingPathComponent("archive-index.sqlite") }

    public func bootstrap() throws {
        let directories = [
            homeURL,
            configURL,
            runtimeURL,
            redscriptRuntimeURL,
            inputLoaderRuntimeURL,
            overlayURL,
            overlayScriptsURL,
            overlayInputURL,
            overlayCacheURL,
            baseCacheURL,
            backupsURL,
            inputPatchBackupsURL,
            officialArchiveBackupsURL,
            tmpURL,
            archiveProbeTmpURL,
            generatedURL,
            manifestsURL,
            disabledURL,
            logsURL,
            scanCacheURL,
            diagnosticsURL,
            archiveIndexURL
        ]
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
