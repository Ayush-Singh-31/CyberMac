import Foundation

public struct ProcessResult: Sendable {
    public let executable: URL
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var commandDescription: String {
        ([executable.path] + arguments).joined(separator: " ")
    }
}

public struct ProcessRunner: Sendable {
    public init() {}

    @discardableResult
    public func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        allowFailure: Bool = false
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let stdoutReader = PipeReader(fileHandle: stdoutPipe.fileHandleForReading)
        let stderrReader = PipeReader(fileHandle: stderrPipe.fileHandleForReading)
        stdoutReader.start()
        stderrReader.start()

        process.waitUntilExit()

        let stdout = String(data: try stdoutReader.wait(), encoding: .utf8) ?? ""
        let stderr = String(data: try stderrReader.wait(), encoding: .utf8) ?? ""

        let result = ProcessResult(
            executable: executableURL,
            arguments: arguments,
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )

        if process.terminationStatus != 0 && !allowFailure {
            throw CyberMacError.processFailed(
                command: result.commandDescription,
                exitCode: process.terminationStatus,
                stderr: stderr
            )
        }

        return result
    }
}

private final class PipeReader: @unchecked Sendable {
    private let fileHandle: FileHandle
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var data = Data()
    private var readError: Error?

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func start() {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            do {
                let output = try self.fileHandle.readToEnd() ?? Data()
                self.lock.lock()
                self.data = output
                self.lock.unlock()
            } catch {
                self.lock.lock()
                self.readError = error
                self.lock.unlock()
            }
            self.group.leave()
        }
    }

    func wait() throws -> Data {
        group.wait()
        lock.lock()
        defer { lock.unlock() }
        if let readError {
            throw readError
        }
        return data
    }
}
