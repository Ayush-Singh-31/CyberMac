import Foundation

/// A compiled, temporary inventory helper. Preparation never installs into the game.
public struct AppearanceItemDelivery: Codable, Sendable {
    public let planID: String
    public let createdAt: Date
    public let gameAppPath: String
    public let gameFingerprint: String
    public let packageName: String
    public let itemIDs: [String]
    public let runtimeVersion: String
    public let runtimeArchiveSHA256: String
    public let workspacePath: String
    public let helperZipPath: String
    public let compiledPath: String
    public let compiledSHA256: String
    public let backupID: String
    public let backupPath: String
    public let originalSHA256: String
    public let installCommand: String
    public let restoreCommand: String
    public let gameplayVerified: Bool
}
