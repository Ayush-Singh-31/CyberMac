import Foundation

public enum ArchiveProbeUserResult: String, Codable, Sendable, Equatable {
    case worked
    case noEffect = "no-effect"
    case gameFailedToLaunch = "game-failed-to-launch"
    case unknown
}

public enum ArchiveProbeCandidate: String, Codable, Sendable, Equatable, CaseIterable {
    case macMod = "mac-mod"
    case macContent = "mac-content"
    case pcMod = "pc-mod"
    case pcContent = "pc-content"

    public var dataRelativePath: String {
        switch self {
        case .macMod:
            return "archive/Mac/mod"
        case .macContent:
            return "archive/Mac/content"
        case .pcMod:
            return "archive/pc/mod"
        case .pcContent:
            return "archive/pc/content"
        }
    }

    public static var acceptedValuesDescription: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

public struct ArchiveProbeRecord: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: Date
    public let modArchivePath: String
    public let archiveFileName: String
    public let archiveSHA256: String
    public let candidateTargetPath: String
    public let commandPrinted: String
    public let removalCommandPrinted: String
    public var verifiedCopied: Bool
    public var verifiedRemoved: Bool
    public var userReportedResult: ArchiveProbeUserResult?

    public init(
        id: String,
        createdAt: Date,
        modArchivePath: String,
        archiveFileName: String,
        archiveSHA256: String,
        candidateTargetPath: String,
        commandPrinted: String,
        removalCommandPrinted: String,
        verifiedCopied: Bool = false,
        verifiedRemoved: Bool = false,
        userReportedResult: ArchiveProbeUserResult? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modArchivePath = modArchivePath
        self.archiveFileName = archiveFileName
        self.archiveSHA256 = archiveSHA256
        self.candidateTargetPath = candidateTargetPath
        self.commandPrinted = commandPrinted
        self.removalCommandPrinted = removalCommandPrinted
        self.verifiedCopied = verifiedCopied
        self.verifiedRemoved = verifiedRemoved
        self.userReportedResult = userReportedResult
    }
}

public struct ArchiveProbeState: Codable, Sendable, Equatable {
    public var records: [ArchiveProbeRecord]

    public init(records: [ArchiveProbeRecord] = []) {
        self.records = records
    }
}
