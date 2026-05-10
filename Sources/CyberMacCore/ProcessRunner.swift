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
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

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
