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
        guard FileManager.default.fileExists(atPath: home.stateURL.path),
              let data = try? Data(contentsOf: home.stateURL),
              let state = try? JSONDecoder.cybermac.decode(CyberMacState.self, from: data)
        else {
            return CyberMacState()
        }
        return state
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
