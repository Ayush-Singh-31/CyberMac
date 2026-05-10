import Foundation

public struct ActivationCompileResult: Sendable {
    public let outputURL: URL
    public let stdout: String
    public let stderr: String
    public let command: String
}

public struct ActivationCompiler: Sendable {
    public static let timeoutMessage = "scc timed out. This usually means the cache mirror is invalid or the compiler entered a blocking file-access path."

    private let home: CyberMacHomeManager
    private let runtimeImporter: RuntimeArchiveImporter
    private let runner: ProcessRunner

    public init(home: CyberMacHomeManager, runner: ProcessRunner = ProcessRunner()) {
        self.home = home
        self.runtimeImporter = RuntimeArchiveImporter(home: home)
        self.runner = runner
    }

    public func commandDescription(outputURL: URL) throws -> String {
        let sccURL = try sccToolURL()
        return [
            PathSafety.shellDoubleQuoted(sccURL.path),
            "-compile",
            PathSafety.shellDoubleQuoted(home.overlayScriptsURL.path),
            "-outputCacheFile",
            PathSafety.shellDoubleQuoted(outputURL.path)
        ].joined(separator: " ")
    }

    public func compile(outputURL: URL, timeoutSeconds: TimeInterval = 60) throws -> ActivationCompileResult {
        let sccURL = try sccToolURL()
        try preflight(outputURL: outputURL, sccURL: sccURL)
        do {
            _ = try runner.run(
                executableURL: sccURL,
                arguments: ["-compile", "-h"],
                timeoutSeconds: 10,
                allowFailure: false
            )
            let result = try runner.run(
                executableURL: sccURL,
                arguments: ["-compile", home.overlayScriptsURL.path, "-outputCacheFile", outputURL.path],
                timeoutSeconds: timeoutSeconds,
                allowFailure: true
            )
            guard result.exitCode == 0 else {
                let detail = [result.stderr, result.stdout]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw CyberMacError.processFailed(
                    command: try commandDescription(outputURL: outputURL),
                    exitCode: result.exitCode,
                    stderr: detail
                )
            }
            guard FileManager.default.fileExists(atPath: outputURL.path),
                  try PathSafety.fileSize(url: outputURL) > 0
            else {
                throw CyberMacError.fileSystem("scc completed but did not produce a non-empty final.redscripts at \(outputURL.path)")
            }
            return ActivationCompileResult(
                outputURL: outputURL,
                stdout: result.stdout,
                stderr: result.stderr,
                command: try commandDescription(outputURL: outputURL)
            )
        } catch CyberMacError.processTimedOut {
            throw CyberMacError.processFailed(
                command: try commandDescription(outputURL: outputURL),
                exitCode: -1,
                stderr: Self.timeoutMessage
            )
        }
    }

    private func preflight(outputURL: URL, sccURL: URL) throws {
        guard FileManager.default.isExecutableFile(atPath: sccURL.path) else {
            throw CyberMacError.notFound("scc is missing or not executable: \(sccURL.path)")
        }
        guard FileManager.default.fileExists(atPath: home.overlayScriptsURL.path) else {
            throw CyberMacError.notFound("Overlay scripts directory missing: \(home.overlayScriptsURL.path)")
        }
        let mirrorURL = home.overlayCacheURL.appendingPathComponent("final.redscripts")
        guard FileManager.default.fileExists(atPath: mirrorURL.path) else {
            throw CyberMacError.notFound("Overlay cache mirror missing: \(mirrorURL.path)")
        }
        guard FileManager.default.isWritableFile(atPath: home.overlayCacheURL.path) else {
            throw CyberMacError.fileSystem("Overlay cache directory is not writable: \(home.overlayCacheURL.path)")
        }
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.isWritableFile(atPath: outputURL.deletingLastPathComponent().path) else {
            throw CyberMacError.fileSystem("Activation temp directory is not writable: \(outputURL.deletingLastPathComponent().path)")
        }
    }

    private func sccToolURL() throws -> URL {
        let status = runtimeImporter.redscriptStatus()
        guard let toolURL = status.toolURL else {
            throw CyberMacError.notFound("redscript scc was not found. Import the redscript macOS zip first.")
        }
        return toolURL
    }
}
