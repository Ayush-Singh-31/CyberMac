import Foundation

enum BackgroundTaskRunner {
    static func run<Value: Sendable>(_ operation: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await Task.detached(priority: .userInitiated) {
            try operation()
        }.value
    }
}
