import Foundation

public struct CyberMacState: Codable, Sendable {
    public var launchWorkflow: LaunchWorkflowStatus?

    public init(launchWorkflow: LaunchWorkflowStatus? = nil) {
        self.launchWorkflow = launchWorkflow
    }
}

public struct StateStore: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func load() -> CyberMacState {
        do {
            return try loadValidated()
        } catch {
            logLoadFailure(error)
            return CyberMacState()
        }
    }

    public func loadValidated() throws -> CyberMacState {
        guard FileManager.default.fileExists(atPath: home.stateURL.path) else {
            return CyberMacState()
        }
        let data = try Data(contentsOf: home.stateURL)
        return try JSONDecoder.cybermac.decode(CyberMacState.self, from: data)
    }

    public func corruptionMessage() -> String? {
        do {
            _ = try loadValidated()
            return nil
        } catch {
            return "state.json could not be decoded: \(error.localizedDescription)"
        }
    }

    public func save(_ state: CyberMacState) throws {
        try home.bootstrap()
        let data = try JSONEncoder.cybermac.encode(state)
        try data.write(to: home.stateURL, options: [.atomic])
    }

    public func saveLaunchWorkflow(_ status: LaunchWorkflowStatus) throws {
        var state = load()
        state.launchWorkflow = status
        try save(state)
    }

    private func logLoadFailure(_ error: Error) {
        try? home.bootstrap()
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = home.logsURL.appendingPathComponent("state_load_failure_\(stamp).log")
        let message = """
        Failed to load CyberMac state.
        Path: \(home.stateURL.path)
        Error: \(error)
        """
        try? message.write(to: url, atomically: true, encoding: .utf8)
    }
}

public extension JSONEncoder {
    static var cybermac: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var cybermac: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
