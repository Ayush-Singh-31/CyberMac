import Foundation

/// One user-invoked Terminal test: verify installed bytes, establish a working
/// startup trace, record, launch normally, and retain evidence after game exit.
public struct EquipProbeRunner {
    public init() {}

    public func run(directory: URL, home: CyberMacHomeManager = CyberMacHomeManager()) throws -> URL {
        let manifestURL = directory.appendingPathComponent("probe.json")
        let attributes = try manifestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
              try PathSafety.fileSize(url: manifestURL) <= 64 * 1024,
              let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: String],
              ["2", "3"].contains(manifest["probeVersion"] ?? ""),
              let appPath = manifest["gameApp"], let compiledSHA = manifest["compiledSHA256"],
              compiledSHA.count == 64, compiledSHA.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw CyberMacError.invalidInput("Invalid or oversized probe manifest.")
        }
        let game = try GameInstallDetector().detect(preferredAppPath: appPath)
        let original = game.appURL.appendingPathComponent("Contents/Data/r6/cache/final.redscripts")
        let explicit = manifest["probeVersion"] == "3"
        let cache = try Self.scriptURL(game: game, manifest: manifest)
        try EquipProbePreparer.verify(game.executableURL, sha256: EquipProbePreparer.executableSHA)
        if explicit { try EquipProbePreparer.verify(original, sha256: EquipProbePreparer.originalSHA) }
        try EquipProbePreparer.verify(cache, sha256: compiledSHA)
        try EquipProbePreparer.verify(directory.appendingPathComponent("final.redscripts"), sha256: compiledSHA)
        try Self.requireClosedGame()
        let recorder = GameSessionLogRecorder(home: home)
        let session = try recorder.start(game: game)
        let folder = URL(fileURLWithPath: session.folderPath)
        var evidence = RunEvidence(startedAt: Date(), gameApp: appPath,
            executableSHA256: EquipProbePreparer.executableSHA, scriptSHA256BeforeLaunch: compiledSHA,
            scriptPath: cache.path, launchArguments: Self.launchArguments(app: game.appURL, script: cache, explicit: explicit))
        let control = folder.appendingPathComponent("cm-trace-\(UUID().uuidString.prefix(8))")
        let trace = ScriptCacheAccessTrace(controlName: control.lastPathComponent)
        var traceStarted = false
        do {
            try evidence.save(folder)
            try trace.start(); traceStarted = true
            try Data("trace control".utf8).write(to: control)
            defer { try? FileManager.default.removeItem(at: control) }
            let deadline = Date().addingTimeInterval(8)
            while !trace.snapshot().controlObserved && Date() < deadline && trace.isRunning {
                _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/stat"),
                    arguments: ["-f", "%z", control.path], timeoutSeconds: 2)
                Thread.sleep(forTimeInterval: 0.1)
            }
            guard trace.snapshot().controlObserved, trace.isRunning else {
                throw CyberMacError.unsupported("Startup file trace could not be verified. The game was not launched. \(trace.snapshot().diagnostics)")
            }
            // The control proves the tracer is receiving events before launch;
            // verify bytes again after that setup, immediately before opening.
            try EquipProbePreparer.verify(cache, sha256: compiledSHA)
            if explicit { try EquipProbePreparer.verify(original, sha256: EquipProbePreparer.originalSHA) }
            try Self.requireClosedGame()
            guard recorder.snapshot()?.status == .recording else {
                throw CyberMacError.fileSystem("The log recorder stopped before launch: \(recorder.snapshot()?.error ?? "source unavailable")")
            }
            evidence.launchRequestedAt = Date()
            evidence.trace = trace.snapshot()
            try evidence.save(folder)
            try recorder.addMarker("Probe v\(manifest["probeVersion"]!) verified before launch: script SHA-256 \(compiledSHA); path \(cache.path)")
            try recorder.addMarker("Startup file trace verified by control event. Opening \(game.appURL.lastPathComponent).")
            print("Recording and startup trace are ready. The game will launch now.")
            print("At the main menu, look for CYBERMAC SCRIPT EXECUTED / MENU in the version text.")
            print("Load a manual save, try one ordinary garment and one saved wardrobe outfit, then quit normally.")
            print("Keep your reference save slot untouched. This Terminal window will \(explicit ? "remove the auxiliary cache" : "restore the original scripts") after exit.")
            _ = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/open"),
                arguments: evidence.launchArguments, timeoutSeconds: TimeInterval(GameSessionLogRecorder.maximumSeconds))
            evidence.gameWaitEndedAt = Date()
            evidence.scriptSHA256AfterExit = try PathSafety.sha256(url: cache)
            if explicit { evidence.originalScriptSHA256AfterExit = try PathSafety.sha256(url: original) }
            try recorder.addMarker("Launch wait ended. Script SHA-256 after exit: \(evidence.scriptSHA256AfterExit!)")
            evidence.trace = trace.stop(); traceStarted = false
            evidence.logStatus = recorder.stop()?.status.rawValue
            evidence.endedAt = Date()
            try evidence.save(folder)
            guard evidence.scriptSHA256AfterExit == compiledSHA else {
                throw CyberMacError.unsupported("Game scripts changed during the test. Evidence saved; review before restoring.")
            }
            if explicit, evidence.originalScriptSHA256AfterExit != EquipProbePreparer.originalSHA {
                throw CyberMacError.unsupported("Original scripts changed during the test. Evidence saved; review before cleanup.")
            }
            guard evidence.logStatus == "stopped" || evidence.logStatus == "completed" else {
                throw CyberMacError.fileSystem("Recording ended with status \(evidence.logStatus ?? "unknown"). Partial evidence saved.")
            }
            print("Evidence saved: \(folder.path)")
            return folder
        } catch let failure {
            if traceStarted { evidence.trace = trace.stop() }
            evidence.logStatus = recorder.stop()?.status.rawValue
            evidence.error = String(describing: failure); evidence.endedAt = Date()
            do { try evidence.save(folder) }
            catch { throw CyberMacError.fileSystem("Probe failed: \(failure). Its report could not be saved: \(error)") }
            print("Partial evidence saved: \(folder.path)")
            throw failure
        }
    }

    static func scriptURL(game: GameInstall, manifest: [String: String]) throws -> URL {
        let directory = game.appURL.appendingPathComponent("Contents/Data/r6/cache")
        if manifest["probeVersion"] == "2" { return directory.appendingPathComponent("final.redscripts") }
        let auxiliary = directory.appendingPathComponent(EquipProbePreparer.auxiliaryFilename)
        guard manifest["probeVersion"] == "3", manifest["launchMode"] == "explicit-script-file",
              manifest["scriptPath"] == auxiliary.path else {
            throw CyberMacError.invalidInput("Explicit script probe must use its fixed auxiliary cache path.")
        }
        return auxiliary
    }

    static func launchArguments(app: URL, script: URL, explicit: Bool) -> [String] {
        // Exact 2.5 argv parser accepts '=' within one argument. A separate
        // absolute '/path' can instead be interpreted as an option prefix.
        ["-W", app.path] + (explicit ? ["--args", "-scriptsBlobPath=\(script.path)"] : [])
    }

    private static func requireClosedGame() throws {
        let processes = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-x", "Cyberpunk2077"], timeoutSeconds: 5, allowFailure: true)
        guard processes.exitCode == 1 else {
            throw CyberMacError.invalidInput(processes.exitCode == 0 ? "Close the game before starting this test." : "Could not determine whether the game is running.")
        }
    }

    private struct RunEvidence: Encodable {
        let startedAt: Date
        let gameApp: String
        let executableSHA256: String
        let scriptSHA256BeforeLaunch: String
        let scriptPath: String
        let launchArguments: [String]
        var launchRequestedAt: Date?
        var gameWaitEndedAt: Date?
        var scriptSHA256AfterExit: String?
        var originalScriptSHA256AfterExit: String?
        var endedAt: Date?
        var trace: ScriptCacheTraceEvidence?
        var logStatus: String?
        var error: String?
        let executionStatus = "Unverified by capture; direct MENU/HUD marker requires an in-game observation. File access alone is not execution."

        func save(_ folder: URL) throws {
            try JSONEncoder.cybermac.encode(self).write(to: folder.appendingPathComponent("probe-run.json"), options: .atomic)
        }
    }
}
