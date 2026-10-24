import Foundation
import Darwin

public struct GameSessionLogReport: Codable, Sendable {
    public enum Status: String, Codable, Sendable { case recording, stopped, completed, sizeLimitReached, failed }
    public let id: String
    public let startedAt: Date
    public var endedAt: Date?
    public var status: Status
    public var capturedBytes: Int
    public var error: String?
    public let gameVersion: String
    public let gameBuild: String
    public let folderPath: String
    public let limitations: [String]
}

/// One explicitly started, read-only capture per home. Mutable state is protected
/// by `lock`; pipe readers write bounded chunks, never a whole session in memory.
public final class GameSessionLogRecorder: @unchecked Sendable {
    public static let shared = GameSessionLogRecorder(home: CyberMacHomeManager())
    public static let maximumBytes = 10 * 1024 * 1024
    public static let retainedSessions = 3
    public static let maximumSeconds = 3600
    public static let predicate = "process == \"Cyberpunk2077\" OR subsystem BEGINSWITH \"com.cybermac.\""

    private let home: CyberMacHomeManager
    private let command: (URL, [String])?
    private let byteLimit: Int
    private let lock = NSLock()
    private var process: Process?
    private var handle: FileHandle?
    private var completion: DispatchGroup?
    private var report: GameSessionLogReport?
    private var sourceError = Data()
    private var requestedStop = false
    private var lockDescriptor: Int32 = -1

    public convenience init(home: CyberMacHomeManager) {
        self.init(home: home, command: nil, byteLimit: Self.maximumBytes)
    }

    // Injectable source is internal and only used by isolated process tests.
    init(home: CyberMacHomeManager, command: (URL, [String])?, byteLimit: Int) {
        self.home = home; self.command = command; self.byteLimit = byteLimit
    }

    public var isRecording: Bool { lock.withLock { process != nil } }
    public func snapshot() -> GameSessionLogReport? { lock.withLock { report } }

    @discardableResult
    public func start(game: GameInstall, seconds: Int = maximumSeconds) throws -> GameSessionLogReport {
        try lock.withLock {
            guard process == nil else { throw CyberMacError.invalidInput("A session is already recording or stopping.") }
            guard (1...Self.maximumSeconds).contains(seconds) else { throw CyberMacError.invalidInput("Capture duration must be between 1 and 3600 seconds.") }
            let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: game.appURL.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
            guard let version = info?["CFBundleShortVersionString"] as? String, !version.isEmpty,
                  let build = info?["CFBundleVersion"] as? String, !build.isEmpty else {
                throw CyberMacError.invalidInput("The game's version and build could not be read.")
            }
            let root = home.logsURL.appendingPathComponent("game-sessions", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let descriptor = Darwin.open(root.appendingPathComponent(".capture-lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                Darwin.close(descriptor)
                throw CyberMacError.invalidInput("Another CyberMac window or process is recording this workspace.")
            }
            lockDescriptor = descriptor
            report = nil
            do {
                let folders = try sessionFolders(root)
                let id = UUID().uuidString.lowercased()
                let folder = root.appendingPathComponent(id, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                report = GameSessionLogReport(id: id, startedAt: Date(), status: .recording, capturedBytes: 0,
                    gameVersion: version, gameBuild: build, folderPath: folder.path,
                    limitations: ["Available macOS and CyberMac messages only; no internal engine instrumentation.",
                                  "Private game-container files and inventory/equip events are not captured.",
                                  "An empty stream does not establish that the game or a mod worked.",
                                  "Local files only. Capture stops after \(seconds) seconds or \(byteLimit) bytes."])
                let logURL = folder.appendingPathComponent("capture.log")
                guard FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                    throw CyberMacError.fileSystem("Could not create the session log.")
                }
                handle = try FileHandle(forWritingTo: logURL)
                sourceError = Data(); requestedStop = false
                try persist()
                // Keep the old evidence if creating the new session report fails.
                for folder in folders.dropFirst(Self.retainedSessions - 1) { try FileManager.default.removeItem(at: folder) }
                let source = Process(), output = Pipe(), errors = Pipe()
                source.executableURL = command?.0 ?? URL(fileURLWithPath: "/usr/bin/log")
                // Existing CyberMac activation/state messages use debug level.
                source.arguments = command?.1 ?? ["stream", "--style", "ndjson", "--level", "debug", "--timeout", String(seconds), "--predicate", Self.predicate]
                source.standardOutput = output; source.standardError = errors
                let readers = DispatchGroup(), done = DispatchGroup()
                done.enter(); completion = done
                source.terminationHandler = { [weak self] ended in
                    let drained = readers.wait(timeout: .now() + 2) == .success
                    self?.finish(exitCode: ended.terminationStatus, drained: drained)
                    done.leave()
                }
                process = source
                readers.enter(); readers.enter()
                do { try source.run() }
                catch { process = nil; completion = nil; throw error }
                read(output.fileHandleForReading, readers: readers, isError: false)
                read(errors.fileHandleForReading, readers: readers, isError: true)
                return report!
            } catch {
                try? handle?.close(); handle = nil
                report?.status = .failed; report?.error = String(describing: error); report?.endedAt = Date()
                try? persist()
                releaseLock()
                throw error
            }
        }
    }

    public func addMarker(_ text: String) throws {
        let marker = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !marker.isEmpty, marker.utf8.count <= 512,
              !marker.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw CyberMacError.invalidInput("Use a single-line marker of at most 512 bytes.")
        }
        guard append(Data("\n[CyberMac marker \(ISO8601DateFormatter().string(from: Date()))] \(marker)\n".utf8), allOrNothing: true) else {
            throw CyberMacError.fileSystem(snapshot()?.error ?? "The marker was not saved: recording has stopped or the session is full.")
        }
    }

    @discardableResult
    public func stop() -> GameSessionLogReport? {
        let active = lock.withLock { () -> (Process, DispatchGroup)? in
            guard let process, let completion else { return nil }
            requestedStop = true
            return (process, completion)
        }
        if let (source, done) = active {
            if source.isRunning { source.terminate() }
            if done.wait(timeout: .now() + 2) == .timedOut {
                if source.isRunning { Darwin.kill(source.processIdentifier, SIGKILL) }
                if done.wait(timeout: .now() + 2) == .timedOut {
                    lock.withLock {
                        report?.status = .failed; report?.error = "The log source did not stop before the deadline."
                    }
                }
            }
        }
        return snapshot()
    }

    public func recent() throws -> [GameSessionLogReport] {
        try lock.withLock {
            let root = home.logsURL.appendingPathComponent("game-sessions", isDirectory: true)
            guard FileManager.default.fileExists(atPath: root.path) else { return [] }
            return try sessionFolders(root).map(readReport)
        }
    }

    private func read(_ pipe: FileHandle, readers: DispatchGroup, isError: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer { try? pipe.close(); readers.leave() }
            // Foundation's length-based read can wait for the entire chunk on a
            // pipe. POSIX read returns as soon as bytes arrive, so small bursts
            // reach the size limiter and markers promptly.
            var buffer = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = buffer.withUnsafeMutableBytes { Darwin.read(pipe.fileDescriptor, $0.baseAddress, $0.count) }
                if count == 0 { return }
                if count < 0 {
                    if errno == EINTR { continue }
                    self?.fail("Reading the log source failed: \(NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))")
                    return
                }
                guard let self else { return }
                let bytes = Data(buffer.prefix(count))
                if isError { self.lock.withLock { self.sourceError = Data((self.sourceError + bytes).suffix(4096)) } }
                else { self.append(bytes) }
            }
        }
    }

    @discardableResult
    private func append(_ bytes: Data, allOrNothing: Bool = false) -> Bool {
        let result = lock.withLock { () -> (Bool, Process?) in
            guard let current = report, current.status == .recording, let handle else { return (false, nil) }
            do {
                let remaining = byteLimit - current.capturedBytes
                if allOrNothing && bytes.count > remaining { return (false, nil) }
                let chunk = bytes.prefix(remaining)
                try handle.write(contentsOf: chunk)
                report?.capturedBytes += chunk.count
                if bytes.count >= remaining { report?.status = .sizeLimitReached; return (chunk.count == bytes.count, process) }
                return (true, nil)
            } catch {
                report?.status = .failed; report?.error = "Writing the session log failed: \(error)"
                return (false, process)
            }
        }
        if let terminate = result.1 { Self.requestTermination(terminate) }
        return result.0
    }

    private func fail(_ message: String) {
        let source = lock.withLock { () -> Process? in
            report?.status = .failed; report?.error = message
            return process
        }
        if let source { Self.requestTermination(source) }
    }

    private func finish(exitCode: Int32, drained: Bool) {
        lock.withLock {
            guard report != nil else { return }
            if report?.status == .recording {
                if !drained { report?.status = .failed; report?.error = "The log source exited before its output finished draining." }
                else if requestedStop { report?.status = .stopped }
                else if exitCode == 0 { report?.status = .completed }
                else {
                    report?.status = .failed
                    report?.error = "Log source exited with status \(exitCode): \(String(decoding: sourceError, as: UTF8.self))"
                }
            }
            report?.endedAt = Date()
            do { try handle?.synchronize(); try handle?.close(); handle = nil; try persist() }
            catch { report?.status = .failed; report?.error = "Could not save the session log: \(error)"; try? handle?.close(); handle = nil }
            process = nil; completion = nil; releaseLock()
        }
    }

    private func persist() throws {
        guard let report else { return }
        try JSONEncoder.cybermac.encode(report).write(to: URL(fileURLWithPath: report.folderPath).appendingPathComponent("report.json"), options: [.atomic])
    }

    private func sessionFolders(_ root: URL) throws -> [URL] {
        let entries = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.creationDateKey, .isSymbolicLinkKey, .isDirectoryKey], options: [.skipsHiddenFiles])
        var sessions: [(url: URL, created: Date)] = []
        for folder in entries {
            guard UUID(uuidString: folder.lastPathComponent) != nil else { continue }
            let values = try folder.resourceValues(forKeys: [.creationDateKey, .isSymbolicLinkKey, .isDirectoryKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
            _ = try readReport(folder)
            guard let created = values.creationDate else {
                throw CyberMacError.fileSystem("Could not determine the age of a saved session.")
            }
            sessions.append((folder, created))
        }
        sessions.sort {
            $0.created == $1.created ? $0.url.lastPathComponent > $1.url.lastPathComponent : $0.created > $1.created
        }
        return sessions.map(\.url)
    }

    private func readReport(_ folder: URL) throws -> GameSessionLogReport {
        let file = folder.appendingPathComponent("report.json")
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              try PathSafety.fileSize(url: file) <= 64 * 1024 else {
            throw CyberMacError.invalidInput("Session report is not a bounded regular file.")
        }
        let decoded = try JSONDecoder.cybermac.decode(GameSessionLogReport.self, from: Data(contentsOf: file))
        guard decoded.id == folder.lastPathComponent,
              URL(fileURLWithPath: decoded.folderPath).standardizedFileURL.path == folder.standardizedFileURL.path,
              (0...Self.maximumBytes).contains(decoded.capturedBytes) else {
            throw CyberMacError.invalidInput("Session report does not match its folder or size limits.")
        }
        return decoded
    }

    private func releaseLock() {
        if lockDescriptor >= 0 { Darwin.close(lockDescriptor); lockDescriptor = -1 }
    }

    private static func requestTermination(_ source: Process) {
        guard source.isRunning else { return }
        source.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if source.isRunning { Darwin.kill(source.processIdentifier, SIGKILL) }
        }
    }

    deinit { if let process { Self.requestTermination(process) }; try? handle?.close(); releaseLock() }
}
