import Foundation

public enum Storefront: String, Codable, Sendable {
    case macAppStore = "Mac App Store"
    case unknown = "Unknown"
}

public struct GameInstall: Codable, Sendable {
    public let appURL: URL
    public let executableURL: URL
    public let dataURL: URL
    public let archiveMacURL: URL?
    public let r6URL: URL?
    public let storefront: Storefront
    public let displayName: String

    public init(appURL: URL, executableURL: URL, dataURL: URL, archiveMacURL: URL?, r6URL: URL?, storefront: Storefront, displayName: String) {
        self.appURL = appURL
        self.executableURL = executableURL
        self.dataURL = dataURL
        self.archiveMacURL = archiveMacURL
        self.r6URL = r6URL
        self.storefront = storefront
        self.displayName = displayName
    }
}

public enum RuntimeKind: String, Codable, Sendable {
    case redscript
    case inputLoader
}

public struct RuntimeStatus: Codable, Sendable {
    public let kind: RuntimeKind
    public let rootURL: URL
    public let installed: Bool
    public let toolURL: URL?
    public let version: String?
    public let quarantinedPaths: [URL]
    public let notes: [String]

    public init(kind: RuntimeKind, rootURL: URL, installed: Bool, toolURL: URL?, version: String? = nil, quarantinedPaths: [URL], notes: [String]) {
        self.kind = kind
        self.rootURL = rootURL
        self.installed = installed
        self.toolURL = toolURL
        self.version = version
        self.quarantinedPaths = quarantinedPaths
        self.notes = notes
    }
}

public enum CompatibilityStatus: String, Codable, Sendable {
    case supported = "Supported"
    case unsupported = "Unsupported"
    case untested = "Untested"
}
