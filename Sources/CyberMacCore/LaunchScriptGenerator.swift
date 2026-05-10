import Foundation

public struct LaunchScriptGenerator: Sendable {
    private let home: CyberMacHomeManager
    private let runtimeImporter: RuntimeArchiveImporter

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.runtimeImporter = RuntimeArchiveImporter(home: home)
    }

    public func generate(gameInstall: GameInstall) throws -> URL {
        try home.bootstrap()
        let redscriptStatus = runtimeImporter.redscriptStatus()
        let inputLoaderStatus = runtimeImporter.inputLoaderStatus()

        guard let sccURL = redscriptStatus.toolURL else {
            throw CyberMacError.notFound("redscript scc was not found. Import the redscript macOS zip first.")
        }
        guard let inputLoaderURL = inputLoaderStatus.toolURL else {
            throw CyberMacError.notFound("inputloader.pl was not found. Import the input-loader macOS zip first.")
        }

        let script = """
        #!/bin/zsh
        set -euo pipefail

        GAME_APP=\(PathSafety.shellQuoted(gameInstall.appURL.path))
        GAME_BIN=\(PathSafety.shellQuoted(gameInstall.executableURL.path))
        GAME_DATA=\(PathSafety.shellQuoted(gameInstall.dataURL.path))

        CYBERMAC_HOME=\(PathSafety.shellQuoted(home.homeURL.path))
        REDSCRIPT_SCC=\(PathSafety.shellQuoted(sccURL.path))
        INPUT_LOADER=\(PathSafety.shellQuoted(inputLoaderURL.path))
        SCRIPT_DIR=\(PathSafety.shellQuoted(home.overlayScriptsURL.path))

        echo "CyberMac: compiling redscript overlay at $SCRIPT_DIR"
        cd "$GAME_DATA"
        "$REDSCRIPT_SCC" -compile "$SCRIPT_DIR"

        echo "CyberMac: running input loader"
        perl "$INPUT_LOADER"

        echo "CyberMac: launching Cyberpunk 2077"
        exec "$GAME_BIN" "$@"
        """

        try FileManager.default.createDirectory(at: home.generatedURL, withIntermediateDirectories: true)
        try script.write(to: home.launchScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.launchScriptURL.path)
        return home.launchScriptURL
    }
}
