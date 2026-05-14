import Foundation

public extension ModKind {
    var displayName: String {
        switch self {
        case .redscript:
            return "redscript"
        case .redscriptInput:
            return "redscript + input mapping"
        case .archiveOnly:
            return "archive-only"
        case .frameworkStack:
            return "framework stack"
        case .mixed:
            return "mixed"
        case .unknown:
            return "unknown"
        }
    }
}

public extension ModScanResult {
    var displayStatusLabel: String {
        if kind == .archiveOnly && compatibilityStatus == .untested {
            return "Experimental archive-only"
        }
        if kind == .frameworkStack {
            return "Unsupported framework"
        }
        return requiresInputMappingPatch ? "Supported with input patch" : compatibilityStatus.rawValue
    }
}

public extension ModDependencyMarkers {
    var frameworkMarkerLabels: [String] {
        var labels: [String] = []
        if hasArchiveXL { labels.append("ArchiveXL") }
        if hasTweakXL { labels.append("TweakXL") }
        if hasRED4ext { labels.append("RED4ext") }
        if hasCodeware { labels.append("Codeware") }
        if hasCET { labels.append("CET") }
        if hasEquipmentEX { labels.append("Equipment-EX") }
        if hasREDmod { labels.append("REDmod") }
        if hasNativePlugin { labels.append("native plugin") }
        return labels
    }

    var archiveMarkerLabels: [String] {
        var labels: [String] = []
        if hasArchiveFiles { labels.append(".archive files") }
        if hasArchivePCModPath { labels.append("archive/pc/mod") }
        if hasArchivePCContentPath { labels.append("archive/pc/content") }
        if hasArchiveMacModPath { labels.append("archive/Mac/mod") }
        if hasArchiveMacContentPath { labels.append("archive/Mac/content") }
        if hasInputMappingXML { labels.append("input XML") }
        return labels
    }
}

public struct BackupDisplaySummary: Sendable {
    public let title: String
    public let subtitle: String
    public let detail: String
    public let safeLabel: String
    public let technicalDetails: [(label: String, value: String)]

    public init(title: String, subtitle: String, detail: String, safeLabel: String, technicalDetails: [(label: String, value: String)]) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.safeLabel = safeLabel
        self.technicalDetails = technicalDetails
    }
}

public enum BackupDisplayFormatter {
    public static func summary(for backup: BundleBackupManifest, developerMode: Bool) -> BackupDisplaySummary {
        let title = backup.priorState == .present ? "Vanilla backup" : "Missing-cache backup"
        let detail = backup.priorState == .present ? "Before CyberMac activation" : "Restores a missing bundle cache state"
        let safeLabel = backup.priorState == .present ? "Safe restore point" : "Advanced restore point"

        var technicalDetails: [(label: String, value: String)] = []
        if developerMode {
            technicalDetails = [
                ("Backup ID", backup.id),
                ("SHA", backup.sha256 ?? "absent"),
                ("Game fingerprint", backup.gameFingerprintID),
                ("Bundle target", backup.bundleTarget),
                ("Game app", backup.gameAppPath)
            ]
        }

        return BackupDisplaySummary(
            title: title,
            subtitle: backup.createdAt.formatted(date: .abbreviated, time: .shortened),
            detail: detail,
            safeLabel: safeLabel,
            technicalDetails: technicalDetails
        )
    }
}

public enum ModDisplayFormatter {
    public static func displayName(for manifest: InstalledModManifest) -> String {
        cleanup(manifest.displayName)
    }

    public static func cleanup(_ rawName: String) -> String {
        let withoutExtension = rawName.replacingOccurrences(of: #"\.zip$"#, with: "", options: .regularExpression)
        let withoutTrailingNumbers = withoutExtension.replacingOccurrences(
            of: #"(?i)(?:[-_ ]+\d+){2,}(?:[-_ ][a-f0-9]{8,})?$"#,
            with: "",
            options: .regularExpression
        )
        let words = withoutTrailingNumbers
            .replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
        guard !words.isEmpty else { return rawName }
        return words.map { word in
            guard let first = word.first else { return word }
            return String(first).uppercased() + String(word.dropFirst())
        }.joined(separator: " ")
    }
}
