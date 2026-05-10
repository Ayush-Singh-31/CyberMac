import Foundation

public enum CyberMacError: Error, CustomStringConvertible, LocalizedError {
    case notFound(String)
    case invalidInput(String)
    case unsafePath(String)
    case unsupported(String)
    case processFailed(command: String, exitCode: Int32, stderr: String)
    case fileSystem(String)

    public var description: String {
        switch self {
        case .notFound(let message):
            return "Not found: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .unsafePath(let message):
            return "Unsafe path: \(message)"
        case .unsupported(let message):
            return "Unsupported: \(message)"
        case .processFailed(let command, let exitCode, let stderr):
            let cleanError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Process failed: \(command) exited with \(exitCode)" + (cleanError.isEmpty ? "" : "\n\(cleanError)")
        case .fileSystem(let message):
            return "Filesystem error: \(message)"
        }
    }

    public var errorDescription: String? { description }
}
