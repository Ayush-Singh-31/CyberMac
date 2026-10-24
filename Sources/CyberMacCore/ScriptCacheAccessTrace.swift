import Foundation
import Darwin

struct ScriptCacheTraceEvidence: Encodable, Sendable {
    var startedAt: Date?
    var endedAt: Date?
    var controlObserved = false
    var gameEventCount = 0
    var scriptRows: [String] = []
    var incomplete = false
    var diagnostics = ""
    var exitCode: Int32?
    let durationSeconds = 180
}

/// Filter before persistence: unrelated filesystem activity is discarded. A
/// matching open is access evidence, never proof that bytecode executed.
struct ScriptCacheTraceFilter {
    let controlName: String
    var evidence = ScriptCacheTraceEvidence()
    private var pending = Data()
    private var skippingLongLine = false

    mutating func consume(_ chunk: Data) {
        for byte in chunk {
            if byte == 10 {
                if !skippingLongLine { line(String(decoding: pending, as: UTF8.self)) }
                pending.removeAll(keepingCapacity: true); skippingLongLine = false
            } else if pending.count < 64 * 1024 && !skippingLongLine { pending.append(byte) }
            else { evidence.incomplete = true; skippingLongLine = true; pending.removeAll(keepingCapacity: true) }
        }
    }

    mutating func finish() {
        if !pending.isEmpty || skippingLongLine { evidence.incomplete = true }
        pending.removeAll()
    }

    private mutating func line(_ text: String) {
        if text.contains(controlName) { evidence.controlObserved = true }
        let sender = text.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        let isGame = sender == "Cyberpunk2077" || (sender.hasPrefix("Cyberpunk2077.") &&
            !sender.dropFirst("Cyberpunk2077.".count).isEmpty &&
            sender.dropFirst("Cyberpunk2077.".count).allSatisfy(\.isNumber))
        if isGame {
            evidence.gameEventCount += 1
            if text.lowercased().contains("redscripts") {
                if evidence.scriptRows.count < 256 && text.utf8.count <= 4096 { evidence.scriptRows.append(text) }
                else { evidence.incomplete = true }
            }
        }
        let lower = text.lowercased()
        if lower.contains("dropped") || lower.contains("lost events") || lower.contains("buffer overflow") {
            evidence.incomplete = true
        }
    }
}

/// Invoked only by the user's Terminal test command after `sudo -v`. Captures
/// startup for three minutes. No passwords, injection, signing or game writes.
final class ScriptCacheAccessTrace: @unchecked Sendable {
    private let lock = NSLock()
    private let readers = DispatchGroup()
    private let ended = DispatchGroup()
    private let source = Process()
    private let command: (URL, [String])?
    private var filter: ScriptCacheTraceFilter

    // Alternate source is internal, for isolated pipe/lifecycle tests only.
    init(controlName: String, command: (URL, [String])? = nil) {
        filter = ScriptCacheTraceFilter(controlName: controlName); self.command = command
    }

    func start() throws {
        source.executableURL = command?.0 ?? URL(fileURLWithPath: "/usr/bin/sudo")
        // Named fs_usage filters may resolve only existing processes. Trace
        // before launch and filter in memory, so the first open cannot be missed.
        source.arguments = command?.1 ?? ["-n", "/usr/bin/fs_usage", "-w", "-f", "filesys", "-t", "180"]
        source.standardInput = FileHandle.nullDevice
        let output = Pipe(), errors = Pipe()
        source.standardOutput = output; source.standardError = errors
        ended.enter()
        lock.withLock { filter.evidence.startedAt = Date() }
        source.terminationHandler = { [weak self, ended] process in
            if let self {
                self.lock.withLock {
                    self.filter.evidence.endedAt = Date()
                    self.filter.evidence.exitCode = process.terminationStatus
                }
            }
            ended.leave()
        }
        do { try source.run() }
        catch { ended.leave(); throw error }
        read(output.fileHandleForReading, errors: false)
        read(errors.fileHandleForReading, errors: true)
    }

    var isRunning: Bool { source.isRunning }
    func snapshot() -> ScriptCacheTraceEvidence { lock.withLock { filter.evidence } }

    func stop() -> ScriptCacheTraceEvidence {
        if source.isRunning { source.terminate() }
        if ended.wait(timeout: .now() + 2) == .timedOut {
            if source.isRunning { Darwin.kill(source.processIdentifier, SIGKILL) }
            if ended.wait(timeout: .now() + 2) == .timedOut {
                lock.withLock { filter.evidence.incomplete = true }
            }
        }
        if readers.wait(timeout: .now() + 1) == .timedOut {
            lock.withLock { filter.evidence.incomplete = true }
        }
        return lock.withLock {
            if source.isRunning { filter.evidence.incomplete = true }
            else { filter.evidence.exitCode = source.terminationStatus }
            return filter.evidence
        }
    }

    private func read(_ handle: FileHandle, errors: Bool) {
        readers.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            defer { try? handle.close(); readers.leave() }
            var bytes = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = bytes.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count) }
                if count == 0 { break }
                if count < 0 {
                    if errno == EINTR { continue }
                    lock.withLock { filter.evidence.incomplete = true }; break
                }
                lock.withLock {
                    if errors {
                        filter.evidence.incomplete = true
                        let remaining = 16 * 1024 - filter.evidence.diagnostics.utf8.count
                        filter.evidence.diagnostics += String(decoding: bytes.prefix(max(0, min(count, remaining))), as: UTF8.self)
                    } else { filter.consume(Data(bytes.prefix(count))) }
                }
            }
            if !errors { lock.withLock { filter.finish() } }
        }
    }
}
