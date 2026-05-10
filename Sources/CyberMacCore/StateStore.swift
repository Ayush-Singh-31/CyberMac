import Foundation

public struct CyberMacState: Codable, Sendable {
    public var launchWorkflow: LaunchWorkflowStatus?
    public var activationState: ActivationState
    public var bundleChangedSinceLastActivation: Bool
    public var activeModIDs: [String]
    public var pendingExpectedHashes: [String: String]
    public var activeBundleTargetHashes: [String: String]
    public var baseCacheSnapshotID: String?
    public var lastBackupID: String?
    public var pendingActivation: PendingActivation?

    public init(
        launchWorkflow: LaunchWorkflowStatus? = nil,
        activationState: ActivationState = .requiresBundleActivation,
        bundleChangedSinceLastActivation: Bool = false,
        activeModIDs: [String] = [],
        pendingExpectedHashes: [String: String] = [:],
        activeBundleTargetHashes: [String: String] = [:],
        baseCacheSnapshotID: String? = nil,
        lastBackupID: String? = nil,
        pendingActivation: PendingActivation? = nil
    ) {
        self.launchWorkflow = launchWorkflow
        self.activationState = activationState
        self.bundleChangedSinceLastActivation = bundleChangedSinceLastActivation
        self.activeModIDs = activeModIDs
        self.pendingExpectedHashes = pendingExpectedHashes
        self.activeBundleTargetHashes = activeBundleTargetHashes
        self.baseCacheSnapshotID = baseCacheSnapshotID
        self.lastBackupID = lastBackupID
        self.pendingActivation = pendingActivation
    }

    private enum CodingKeys: String, CodingKey {
        case launchWorkflow
        case activationState
        case bundleChangedSinceLastActivation
        case activeModIDs
        case pendingExpectedHashes
        case activeBundleTargetHashes
        case baseCacheSnapshotID
        case lastBackupID
        case pendingActivation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launchWorkflow = try container.decodeIfPresent(LaunchWorkflowStatus.self, forKey: .launchWorkflow)
        self.activationState = try container.decodeIfPresent(ActivationState.self, forKey: .activationState) ?? .requiresBundleActivation
        self.bundleChangedSinceLastActivation = try container.decodeIfPresent(Bool.self, forKey: .bundleChangedSinceLastActivation) ?? false
        self.activeModIDs = try container.decodeIfPresent([String].self, forKey: .activeModIDs) ?? []
        self.pendingExpectedHashes = try container.decodeIfPresent([String: String].self, forKey: .pendingExpectedHashes) ?? [:]
        self.activeBundleTargetHashes = try container.decodeIfPresent([String: String].self, forKey: .activeBundleTargetHashes) ?? [:]
        self.baseCacheSnapshotID = try container.decodeIfPresent(String.self, forKey: .baseCacheSnapshotID)
        self.lastBackupID = try container.decodeIfPresent(String.self, forKey: .lastBackupID)
        self.pendingActivation = try container.decodeIfPresent(PendingActivation.self, forKey: .pendingActivation)
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

    public func markActivationOutOfSync() throws {
        var state = load()
        state.activationState = .outOfSync
        state.pendingExpectedHashes = [:]
        state.pendingActivation = nil
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
