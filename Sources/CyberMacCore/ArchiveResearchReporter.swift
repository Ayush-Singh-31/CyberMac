import Foundation

public struct ArchiveResearchOptions: Sendable, Equatable {
    public let maxArchiveTreeDepth: Int
    public let maxEntriesPerSection: Int
    public let metadataHashMaxBytes: UInt64

    public init(
        maxArchiveTreeDepth: Int = 5,
        maxEntriesPerSection: Int = 300,
        metadataHashMaxBytes: UInt64 = 1_048_576
    ) {
        self.maxArchiveTreeDepth = max(0, maxArchiveTreeDepth)
        self.maxEntriesPerSection = max(1, maxEntriesPerSection)
        self.metadataHashMaxBytes = metadataHashMaxBytes
    }

    public static let `default` = ArchiveResearchOptions()
}

public enum ArchiveResearchEntryKind: String, Sendable, Equatable {
    case directory
    case file
    case symlink
    case other
}

public struct ArchiveResearchFileEntry: Sendable, Equatable {
    public let relativePath: String
    public let kind: ArchiveResearchEntryKind
    public let depth: Int
    public let sizeBytes: UInt64?
    public let modificationDate: Date?
    public let sha256: String?
    public let sha256Note: String?

    public init(
        relativePath: String,
        kind: ArchiveResearchEntryKind,
        depth: Int,
        sizeBytes: UInt64?,
        modificationDate: Date?,
        sha256: String?,
        sha256Note: String?
    ) {
        self.relativePath = relativePath
        self.kind = kind
        self.depth = depth
        self.sizeBytes = sizeBytes
        self.modificationDate = modificationDate
        self.sha256 = sha256
        self.sha256Note = sha256Note
    }
}

public struct ArchiveResearchCandidateDirectory: Sendable, Equatable {
    public let relativePath: String
    public let absolutePath: String
    public let exists: Bool
    public let leftoverProbeFiles: [String]

    public init(relativePath: String, absolutePath: String, exists: Bool, leftoverProbeFiles: [String]) {
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.exists = exists
        self.leftoverProbeFiles = leftoverProbeFiles
    }
}

public struct ArchiveResearchArchiveGroup: Sendable, Equatable {
    public let directory: String
    public let archives: [ArchiveResearchFileEntry]

    public init(directory: String, archives: [ArchiveResearchFileEntry]) {
        self.directory = directory
        self.archives = archives
    }
}

public struct ArchiveResearchCount: Sendable, Equatable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct ArchiveResearchArchiveProbeGroup: Sendable, Equatable {
    public let name: String
    public let total: Int
    public let resultCounts: [ArchiveResearchCount]

    public init(name: String, total: Int, resultCounts: [ArchiveResearchCount]) {
        self.name = name
        self.total = total
        self.resultCounts = resultCounts
    }
}

public struct ArchiveResearchProbeStateSummary: Sendable, Equatable {
    public let statePath: String
    public let stateExists: Bool
    public let loadError: String?
    public let totalProbes: Int
    public let resultCounts: [ArchiveResearchCount]
    public let recordsByArchiveFile: [ArchiveResearchArchiveProbeGroup]
    public let recordsByCandidatePath: [ArchiveResearchArchiveProbeGroup]
    public let ibm3270AllFourNoEffect: Bool
    public let anyProbeRecordedWorked: Bool

    public init(
        statePath: String,
        stateExists: Bool,
        loadError: String?,
        totalProbes: Int,
        resultCounts: [ArchiveResearchCount],
        recordsByArchiveFile: [ArchiveResearchArchiveProbeGroup],
        recordsByCandidatePath: [ArchiveResearchArchiveProbeGroup],
        ibm3270AllFourNoEffect: Bool,
        anyProbeRecordedWorked: Bool
    ) {
        self.statePath = statePath
        self.stateExists = stateExists
        self.loadError = loadError
        self.totalProbes = totalProbes
        self.resultCounts = resultCounts
        self.recordsByArchiveFile = recordsByArchiveFile
        self.recordsByCandidatePath = recordsByCandidatePath
        self.ibm3270AllFourNoEffect = ibm3270AllFourNoEffect
        self.anyProbeRecordedWorked = anyProbeRecordedWorked
    }
}

public struct ArchiveResearchReport: Sendable, Equatable {
    public let generatedAt: Date
    public let gameAppPath: String
    public let dataPath: String
    public let archiveRootPath: String
    public let archiveRootExists: Bool
    public let archiveTreeEntries: [ArchiveResearchFileEntry]
    public let archiveTreeTruncated: Bool
    public let candidateDirectories: [ArchiveResearchCandidateDirectory]
    public let existingArchiveGroups: [ArchiveResearchArchiveGroup]
    public let existingArchivesTruncated: Bool
    public let metadataMatches: [ArchiveResearchFileEntry]
    public let metadataMatchesTruncated: Bool
    public let probeState: ArchiveResearchProbeStateSummary
    public let recommendationLines: [String]
    public let scanWarnings: [String]

    public init(
        generatedAt: Date,
        gameAppPath: String,
        dataPath: String,
        archiveRootPath: String,
        archiveRootExists: Bool,
        archiveTreeEntries: [ArchiveResearchFileEntry],
        archiveTreeTruncated: Bool,
        candidateDirectories: [ArchiveResearchCandidateDirectory],
        existingArchiveGroups: [ArchiveResearchArchiveGroup],
        existingArchivesTruncated: Bool,
        metadataMatches: [ArchiveResearchFileEntry],
        metadataMatchesTruncated: Bool,
        probeState: ArchiveResearchProbeStateSummary,
        recommendationLines: [String],
        scanWarnings: [String]
    ) {
        self.generatedAt = generatedAt
        self.gameAppPath = gameAppPath
        self.dataPath = dataPath
        self.archiveRootPath = archiveRootPath
        self.archiveRootExists = archiveRootExists
        self.archiveTreeEntries = archiveTreeEntries
        self.archiveTreeTruncated = archiveTreeTruncated
        self.candidateDirectories = candidateDirectories
        self.existingArchiveGroups = existingArchiveGroups
        self.existingArchivesTruncated = existingArchivesTruncated
        self.metadataMatches = metadataMatches
        self.metadataMatchesTruncated = metadataMatchesTruncated
        self.probeState = probeState
        self.recommendationLines = recommendationLines
        self.scanWarnings = scanWarnings
    }
}

public struct ArchiveResearchReporter: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func makeReport(
        gameInstall: GameInstall,
        options: ArchiveResearchOptions = .default,
        generatedAt: Date = Date()
    ) -> ArchiveResearchReport {
        let archiveRoot = gameInstall.dataURL.appendingPathComponent("archive", isDirectory: true)
        let archiveRootExists = isDirectory(archiveRoot)
        var warnings: [String] = []

        let probeStateLoad = loadProbeState()
        let tree = archiveRootExists
            ? collectArchiveTree(root: archiveRoot, options: options, warnings: &warnings)
            : ListingResult(entries: [], truncated: false)
        let existingArchives = archiveRootExists
            ? collectExistingArchives(root: archiveRoot, options: options, warnings: &warnings)
            : ListingResult(entries: [], truncated: false)
        let metadataMatches = collectMetadataMatches(root: gameInstall.dataURL, options: options, warnings: &warnings)
        let probeSummary = makeProbeSummary(from: probeStateLoad)

        return ArchiveResearchReport(
            generatedAt: generatedAt,
            gameAppPath: gameInstall.appURL.path,
            dataPath: gameInstall.dataURL.path,
            archiveRootPath: archiveRoot.path,
            archiveRootExists: archiveRootExists,
            archiveTreeEntries: tree.entries,
            archiveTreeTruncated: tree.truncated,
            candidateDirectories: makeCandidateDirectoryReports(gameInstall: gameInstall, records: probeStateLoad.records),
            existingArchiveGroups: groupArchives(existingArchives.entries),
            existingArchivesTruncated: existingArchives.truncated,
            metadataMatches: metadataMatches.entries,
            metadataMatchesTruncated: metadataMatches.truncated,
            probeState: probeSummary,
            recommendationLines: makeRecommendationLines(probeSummary),
            scanWarnings: warnings.sorted()
        )
    }

    private func loadProbeState() -> ProbeStateLoad {
        let url = home.archiveProbeStateURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ProbeStateLoad(path: url.path, exists: false, records: [], error: nil)
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder.cybermac.decode(ArchiveProbeState.self, from: data)
            return ProbeStateLoad(path: url.path, exists: true, records: state.records, error: nil)
        } catch {
            return ProbeStateLoad(path: url.path, exists: true, records: [], error: String(describing: error))
        }
    }

    private func makeCandidateDirectoryReports(gameInstall: GameInstall, records: [ArchiveProbeRecord]) -> [ArchiveResearchCandidateDirectory] {
        ArchiveProbeCandidate.allCases.map { candidate in
            let directory = candidate.dataRelativePath
                .split(separator: "/")
                .reduce(gameInstall.dataURL) { partial, component in
                    partial.appendingPathComponent(String(component), isDirectory: true)
                }
            let leftovers = records.compactMap { record -> String? in
                let targetURL = URL(fileURLWithPath: record.candidateTargetPath)
                guard targetURL.lastPathComponent == record.archiveFileName,
                      isContained(targetURL, in: directory),
                      FileManager.default.fileExists(atPath: targetURL.path)
                else {
                    return nil
                }
                return record.archiveFileName
            }
            .uniquedSorted()

            return ArchiveResearchCandidateDirectory(
                relativePath: candidate.dataRelativePath,
                absolutePath: directory.path,
                exists: isDirectory(directory),
                leftoverProbeFiles: leftovers
            )
        }
    }

    private func makeProbeSummary(from load: ProbeStateLoad) -> ArchiveResearchProbeStateSummary {
        let records = load.records
        let resultCounts = makeResultCounts(records)
        let byArchive = makeProbeGroups(records: records) { $0.archiveFileName }
        let byCandidate = makeProbeGroups(records: records) { record in
            candidateDisplayPath(forTargetPath: record.candidateTargetPath)
        }
        let ibmRecords = records.filter { record in
            record.archiveFileName.lowercased().contains("ibm 3270")
        }
        let expectedCandidates = Set(ArchiveProbeCandidate.allCases.map(\.dataRelativePath))
        let ibmNoEffectCandidates = Set(
            ibmRecords
                .filter { $0.userReportedResult == .noEffect }
                .map { candidateDisplayPath(forTargetPath: $0.candidateTargetPath) }
                .filter { expectedCandidates.contains($0) }
        )
        let ibmAllNoEffect = !ibmRecords.isEmpty &&
            ibmRecords.allSatisfy { $0.userReportedResult == .noEffect } &&
            ibmNoEffectCandidates == expectedCandidates

        return ArchiveResearchProbeStateSummary(
            statePath: load.path,
            stateExists: load.exists,
            loadError: load.error,
            totalProbes: records.count,
            resultCounts: resultCounts,
            recordsByArchiveFile: byArchive,
            recordsByCandidatePath: byCandidate,
            ibm3270AllFourNoEffect: ibmAllNoEffect,
            anyProbeRecordedWorked: records.contains { $0.userReportedResult == .worked }
        )
    }

    private func makeRecommendationLines(_ probeSummary: ArchiveResearchProbeStateSummary) -> [String] {
        var lines: [String] = []
        if probeSummary.ibm3270AllFourNoEffect && !probeSummary.anyProbeRecordedWorked {
            lines.append("Phase C blocked: archive-only installer should remain blocked because the IBM 3270 binary probes covered all four candidate paths with no-effect and no probe recorded worked.")
        } else if probeSummary.anyProbeRecordedWorked {
            lines.append("Phase C blocked pending review: at least one probe recorded worked, but archive-only installation still needs separate validation before implementation.")
        } else {
            lines.append("Phase C blocked: archive-only installer should remain blocked until a binary probe is shown to work across candidate paths.")
        }
        lines.append("The next research question is how the Mac build indexes or registers archive files.")
        lines.append("Archive/framework scanning remains useful, but archive-only installation is not validated.")
        return lines
    }

    private func collectArchiveTree(root: URL, options: ArchiveResearchOptions, warnings: inout [String]) -> ListingResult {
        var result = ListingResult(entries: [], truncated: false)
        walkDirectory(
            root: root,
            directory: root,
            depth: 0,
            maxDepth: options.maxArchiveTreeDepth,
            maxEntries: options.maxEntriesPerSection,
            include: { _, _ in true },
            hashMetadataFiles: true,
            hashLimit: options.metadataHashMaxBytes,
            result: &result,
            warnings: &warnings
        )
        return result
    }

    private func collectExistingArchives(root: URL, options: ArchiveResearchOptions, warnings: inout [String]) -> ListingResult {
        var result = ListingResult(entries: [], truncated: false)
        walkDirectory(
            root: root,
            directory: root,
            depth: 0,
            maxDepth: Int.max,
            maxEntries: options.maxEntriesPerSection,
            include: { url, values in
                values.isRegularFile == true && url.pathExtension.lowercased() == "archive"
            },
            hashMetadataFiles: false,
            hashLimit: options.metadataHashMaxBytes,
            result: &result,
            warnings: &warnings
        )
        return result
    }

    private func collectMetadataMatches(root: URL, options: ArchiveResearchOptions, warnings: inout [String]) -> ListingResult {
        var result = ListingResult(entries: [], truncated: false)
        walkDirectory(
            root: root,
            directory: root,
            depth: 0,
            maxDepth: Int.max,
            maxEntries: options.maxEntriesPerSection,
            include: { url, values in
                guard values.isSymbolicLink != true else { return false }
                if values.isRegularFile == true {
                    return isMetadataLike(url)
                }
                return values.isDirectory == true && url.pathExtension.lowercased() == "archivebundle"
            },
            hashMetadataFiles: true,
            hashLimit: options.metadataHashMaxBytes,
            result: &result,
            warnings: &warnings
        )
        return result
    }

    private func walkDirectory(
        root: URL,
        directory: URL,
        depth: Int,
        maxDepth: Int,
        maxEntries: Int,
        include: (URL, URLResourceValues) -> Bool,
        hashMetadataFiles: Bool,
        hashLimit: UInt64,
        result: inout ListingResult,
        warnings: inout [String]
    ) {
        guard result.entries.count < maxEntries else {
            result.truncated = true
            return
        }

        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            )
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
        } catch {
            warnings.append("Could not list \(PathSafety.redactUserPath(directory.path)): \(error.localizedDescription)")
            return
        }

        for child in children {
            guard result.entries.count < maxEntries else {
                result.truncated = true
                return
            }

            let values: URLResourceValues
            do {
                values = try child.resourceValues(forKeys: resourceKeys)
            } catch {
                warnings.append("Could not read attributes for \(PathSafety.redactUserPath(child.path)): \(error.localizedDescription)")
                continue
            }

            let childDepth = depth + 1
            let kind = entryKind(values)
            if childDepth <= maxDepth && include(child, values) {
                result.entries.append(makeEntry(
                    url: child,
                    root: root,
                    values: values,
                    kind: kind,
                    depth: childDepth,
                    hashMetadataFiles: hashMetadataFiles,
                    hashLimit: hashLimit
                ))
            }

            guard values.isDirectory == true, values.isSymbolicLink != true else {
                continue
            }
            if childDepth >= maxDepth {
                if directoryHasChildren(child) {
                    result.truncated = true
                }
                continue
            }
            walkDirectory(
                root: root,
                directory: child,
                depth: childDepth,
                maxDepth: maxDepth,
                maxEntries: maxEntries,
                include: include,
                hashMetadataFiles: hashMetadataFiles,
                hashLimit: hashLimit,
                result: &result,
                warnings: &warnings
            )
        }
    }

    private func makeEntry(
        url: URL,
        root: URL,
        values: URLResourceValues,
        kind: ArchiveResearchEntryKind,
        depth: Int,
        hashMetadataFiles: Bool,
        hashLimit: UInt64
    ) -> ArchiveResearchFileEntry {
        let sizeBytes = values.fileSize.map { UInt64(max($0, 0)) }
        let shouldHash = hashMetadataFiles &&
            kind == .file &&
            isMetadataLike(url) &&
            url.pathExtension.lowercased() != "archive"
        let sha: String?
        let note: String?
        if shouldHash, let sizeBytes, sizeBytes <= hashLimit {
            sha = try? PathSafety.sha256(url: url)
            note = sha == nil ? "sha256 unavailable" : nil
        } else if shouldHash, let sizeBytes, sizeBytes > hashLimit {
            sha = nil
            note = "sha256 skipped: file larger than \(hashLimit) bytes"
        } else {
            sha = nil
            note = nil
        }

        return ArchiveResearchFileEntry(
            relativePath: relativePath(of: url, in: root),
            kind: kind,
            depth: depth,
            sizeBytes: sizeBytes,
            modificationDate: values.contentModificationDate,
            sha256: sha,
            sha256Note: note
        )
    }

    private func groupArchives(_ entries: [ArchiveResearchFileEntry]) -> [ArchiveResearchArchiveGroup] {
        let grouped = Dictionary(grouping: entries) { entry -> String in
            let parts = entry.relativePath.split(separator: "/").map(String.init)
            guard parts.count > 1 else { return "." }
            return parts.dropLast().joined(separator: "/")
        }
        return grouped.keys.sorted().map { directory in
            ArchiveResearchArchiveGroup(
                directory: directory,
                archives: (grouped[directory] ?? []).sorted { $0.relativePath < $1.relativePath }
            )
        }
    }

    private func makeResultCounts(_ records: [ArchiveProbeRecord]) -> [ArchiveResearchCount] {
        let counts = Dictionary(grouping: records) { record in
            record.userReportedResult?.rawValue ?? "none"
        }
        let preferredOrder = ["worked", "no-effect", "game-failed-to-launch", "unknown", "none"]
        return preferredOrder
            .filter { counts[$0] != nil }
            .map { ArchiveResearchCount(name: $0, count: counts[$0]?.count ?? 0) }
    }

    private func makeProbeGroups(
        records: [ArchiveProbeRecord],
        grouping: (ArchiveProbeRecord) -> String
    ) -> [ArchiveResearchArchiveProbeGroup] {
        let grouped = Dictionary(grouping: records, by: grouping)
        return grouped.keys.sorted().map { name in
            let records = grouped[name] ?? []
            return ArchiveResearchArchiveProbeGroup(
                name: name,
                total: records.count,
                resultCounts: makeResultCounts(records)
            )
        }
    }

    private func candidateDisplayPath(forTargetPath path: String) -> String {
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        guard let contentsIndex = components.firstIndex(of: "Contents"),
              components.indices.contains(contentsIndex + 1),
              components[contentsIndex + 1] == "Data",
              components.count > contentsIndex + 3
        else {
            return PathSafety.redactUserPath(URL(fileURLWithPath: path).deletingLastPathComponent().path)
        }

        let firstDataComponent = contentsIndex + 2
        let directoryComponents = components[firstDataComponent..<(components.count - 1)]
        return directoryComponents.joined(separator: "/")
    }

    private func relativePath(of url: URL, in root: URL) -> String {
        (try? PathSafety.relativePath(of: url, in: root)) ?? url.lastPathComponent
    }

    private func entryKind(_ values: URLResourceValues) -> ArchiveResearchEntryKind {
        if values.isSymbolicLink == true {
            return .symlink
        }
        if values.isDirectory == true {
            return .directory
        }
        if values.isRegularFile == true {
            return .file
        }
        return .other
    }

    private func directoryHasChildren(_ url: URL) -> Bool {
        ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [])) ?? []).isEmpty == false
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func isContained(_ url: URL, in root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return targetPath.hasPrefix(prefix)
    }
}

public enum ArchiveResearchReportFormatter {
    public static func format(_ report: ArchiveResearchReport) -> String {
        var lines: [String] = []
        let formatter = ISO8601DateFormatter()

        lines.append("Archive research report")
        lines.append("Generated: \(formatter.string(from: report.generatedAt))")
        lines.append("Game app: \(PathSafety.redactUserPath(report.gameAppPath))")
        lines.append("Data path: \(PathSafety.redactUserPath(report.dataPath))")
        lines.append("Archive root: \(PathSafety.redactUserPath(report.archiveRootPath)) (\(report.archiveRootExists ? "exists" : "missing"))")
        lines.append("")

        lines.append("Archive directory tree")
        if report.archiveTreeEntries.isEmpty {
            lines.append("- No entries found.")
        } else {
            lines.append(contentsOf: report.archiveTreeEntries.map(formatEntry))
        }
        if report.archiveTreeTruncated {
            lines.append("- Output truncated by max-depth or max-entries safeguard.")
        }
        lines.append("")

        lines.append("Known candidate directories")
        for candidate in report.candidateDirectories {
            let leftovers = candidate.leftoverProbeFiles.isEmpty ? "none" : candidate.leftoverProbeFiles.joined(separator: ", ")
            lines.append("- \(candidate.relativePath): \(candidate.exists ? "exists" : "missing"); leftover probe files: \(leftovers)")
        }
        lines.append("")

        lines.append("Existing game archives")
        if report.existingArchiveGroups.isEmpty {
            lines.append("- No .archive files found under Contents/Data/archive.")
        } else {
            for group in report.existingArchiveGroups {
                lines.append("\(group.directory):")
                for archive in group.archives {
                    lines.append(formatEntry(archive))
                }
            }
        }
        if report.existingArchivesTruncated {
            lines.append("- Archive listing truncated by max-entries safeguard.")
        }
        lines.append("")

        lines.append("Archive index/cache/manifest-like files")
        if report.metadataMatches.isEmpty {
            lines.append("- No metadata/cache/index-like files found.")
        } else {
            lines.append(contentsOf: report.metadataMatches.map(formatEntry))
        }
        if report.metadataMatchesTruncated {
            lines.append("- Metadata listing truncated by max-entries safeguard.")
        }
        lines.append("")

        lines.append("Probe-state summary")
        lines.append("- State file: \(report.probeState.stateExists ? "present" : "missing") at \(PathSafety.redactUserPath(report.probeState.statePath))")
        if let error = report.probeState.loadError {
            lines.append("- State decode error: \(error)")
        }
        lines.append("- Total probes: \(report.probeState.totalProbes)")
        lines.append("- Result counts: \(formatCounts(report.probeState.resultCounts))")
        lines.append("- Records by archive file:")
        appendProbeGroups(report.probeState.recordsByArchiveFile, to: &lines)
        lines.append("- Records by candidate path:")
        appendProbeGroups(report.probeState.recordsByCandidatePath, to: &lines)
        lines.append("- IBM 3270 all four no-effect: \(yesNo(report.probeState.ibm3270AllFourNoEffect))")
        lines.append("- Any probe recorded worked: \(yesNo(report.probeState.anyProbeRecordedWorked))")
        lines.append("")

        lines.append("Recommendation")
        lines.append(contentsOf: report.recommendationLines.map { "- \($0)" })

        if !report.scanWarnings.isEmpty {
            lines.append("")
            lines.append("Scan warnings")
            lines.append(contentsOf: report.scanWarnings.map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }

    private static func appendProbeGroups(_ groups: [ArchiveResearchArchiveProbeGroup], to lines: inout [String]) {
        if groups.isEmpty {
            lines.append("  - none")
            return
        }
        for group in groups {
            lines.append("  - \(group.name): \(group.total) (\(formatCounts(group.resultCounts)))")
        }
    }

    private static func formatEntry(_ entry: ArchiveResearchFileEntry) -> String {
        let indent = String(repeating: "  ", count: max(0, entry.depth - 1))
        var suffix: [String] = []
        if let sizeBytes = entry.sizeBytes {
            suffix.append("\(sizeBytes) bytes")
        }
        if let modificationDate = entry.modificationDate {
            suffix.append("modified \(ISO8601DateFormatter().string(from: modificationDate))")
        }
        if let sha = entry.sha256 {
            suffix.append("sha256 \(sha)")
        }
        if let note = entry.sha256Note {
            suffix.append(note)
        }
        let path = entry.kind == .directory ? "\(entry.relativePath)/" : entry.relativePath
        let detail = suffix.isEmpty ? "" : " (\(suffix.joined(separator: ", ")))"
        return "- \(indent)\(path)\(detail)"
    }

    private static func formatCounts(_ counts: [ArchiveResearchCount]) -> String {
        if counts.isEmpty {
            return "none"
        }
        return counts.map { "\($0.name) \($0.count)" }.joined(separator: ", ")
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private struct ProbeStateLoad {
    let path: String
    let exists: Bool
    let records: [ArchiveProbeRecord]
    let error: String?
}

private struct ListingResult {
    var entries: [ArchiveResearchFileEntry]
    var truncated: Bool
}

private let resourceKeys: Set<URLResourceKey> = [
    .isDirectoryKey,
    .isRegularFileKey,
    .isSymbolicLinkKey,
    .fileSizeKey,
    .contentModificationDateKey
]

private func isMetadataLike(_ url: URL) -> Bool {
    let fileName = url.lastPathComponent.lowercased()
    let ext = url.pathExtension.lowercased()
    if ext == "archive" {
        return false
    }

    let nameMarkers = ["archive", "toc", "index", "manifest", "cache", "catalog"]
    if nameMarkers.contains(where: { fileName.contains($0) }) {
        return true
    }

    let metadataExtensions: Set<String> = ["json", "bin", "db", "idx", "toc", "manifest", "archivebundle"]
    return metadataExtensions.contains(ext)
}

private extension Array where Element == String {
    func uniquedSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
