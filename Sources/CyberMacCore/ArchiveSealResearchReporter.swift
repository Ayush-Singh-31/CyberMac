import Foundation

public struct ArchiveSealCodeResourceEntry: Sendable, Equatable {
    public let path: String
    public let directory: String
    public let fileName: String
    public let existsOnDisk: Bool
    public let sizeBytes: UInt64?

    public init(path: String, directory: String, fileName: String, existsOnDisk: Bool, sizeBytes: UInt64?) {
        self.path = path
        self.directory = directory
        self.fileName = fileName
        self.existsOnDisk = existsOnDisk
        self.sizeBytes = sizeBytes
    }
}

public struct ArchiveSealCodeResourceGroup: Sendable, Equatable {
    public let directory: String
    public let entries: [ArchiveSealCodeResourceEntry]

    public init(directory: String, entries: [ArchiveSealCodeResourceEntry]) {
        self.directory = directory
        self.entries = entries
    }
}

public struct ArchiveSealKeystoneEntry: Sendable, Equatable {
    public let path: String
    public let existsOnDisk: Bool
    public let sizeBytes: UInt64?

    public init(path: String, existsOnDisk: Bool, sizeBytes: UInt64?) {
        self.path = path
        self.existsOnDisk = existsOnDisk
        self.sizeBytes = sizeBytes
    }
}

public struct ArchiveSealFilesystemEntry: Sendable, Equatable {
    public let path: String
    public let directory: String
    public let fileName: String
    public let sizeBytes: UInt64?
    public let listedInCodeResources: Bool
    public let highlightedLoosePath: Bool

    public init(
        path: String,
        directory: String,
        fileName: String,
        sizeBytes: UInt64?,
        listedInCodeResources: Bool,
        highlightedLoosePath: Bool
    ) {
        self.path = path
        self.directory = directory
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.listedInCodeResources = listedInCodeResources
        self.highlightedLoosePath = highlightedLoosePath
    }
}

public struct ArchiveSealFilesystemGroup: Sendable, Equatable {
    public let directory: String
    public let entries: [ArchiveSealFilesystemEntry]

    public init(directory: String, entries: [ArchiveSealFilesystemEntry]) {
        self.directory = directory
        self.entries = entries
    }
}

public struct ArchiveSealProbeSummary: Sendable, Equatable {
    public let statePath: String
    public let stateExists: Bool
    public let loadError: String?
    public let totalProbes: Int
    public let ibm3270AllFourNoEffect: Bool
    public let anyProbeRecordedWorked: Bool
    public let allProbeTargetsUnlistedFromCodeResources: Bool

    public init(
        statePath: String,
        stateExists: Bool,
        loadError: String?,
        totalProbes: Int,
        ibm3270AllFourNoEffect: Bool,
        anyProbeRecordedWorked: Bool,
        allProbeTargetsUnlistedFromCodeResources: Bool
    ) {
        self.statePath = statePath
        self.stateExists = stateExists
        self.loadError = loadError
        self.totalProbes = totalProbes
        self.ibm3270AllFourNoEffect = ibm3270AllFourNoEffect
        self.anyProbeRecordedWorked = anyProbeRecordedWorked
        self.allProbeTargetsUnlistedFromCodeResources = allProbeTargetsUnlistedFromCodeResources
    }
}

public struct ArchiveSealResearchReport: Sendable, Equatable {
    public let generatedAt: Date
    public let gameAppPath: String
    public let contentsPath: String
    public let codeResourcesPath: String
    public let codeResourcesExists: Bool
    public let codeResourcesLoadError: String?
    public let listedArchiveCount: Int
    public let listedArchiveGroups: [ArchiveSealCodeResourceGroup]
    public let keystoneEntries: [ArchiveSealKeystoneEntry]
    public let filesystemArchiveCount: Int
    public let filesystemArchiveGroups: [ArchiveSealFilesystemGroup]
    public let unlistedFilesystemArchives: [ArchiveSealFilesystemEntry]
    public let missingListedArchives: [ArchiveSealCodeResourceEntry]
    public let probeSummary: ArchiveSealProbeSummary
    public let sealSummaryLines: [String]
    public let recommendationLines: [String]
    public let scanWarnings: [String]

    public init(
        generatedAt: Date,
        gameAppPath: String,
        contentsPath: String,
        codeResourcesPath: String,
        codeResourcesExists: Bool,
        codeResourcesLoadError: String?,
        listedArchiveCount: Int,
        listedArchiveGroups: [ArchiveSealCodeResourceGroup],
        keystoneEntries: [ArchiveSealKeystoneEntry],
        filesystemArchiveCount: Int,
        filesystemArchiveGroups: [ArchiveSealFilesystemGroup],
        unlistedFilesystemArchives: [ArchiveSealFilesystemEntry],
        missingListedArchives: [ArchiveSealCodeResourceEntry],
        probeSummary: ArchiveSealProbeSummary,
        sealSummaryLines: [String],
        recommendationLines: [String],
        scanWarnings: [String]
    ) {
        self.generatedAt = generatedAt
        self.gameAppPath = gameAppPath
        self.contentsPath = contentsPath
        self.codeResourcesPath = codeResourcesPath
        self.codeResourcesExists = codeResourcesExists
        self.codeResourcesLoadError = codeResourcesLoadError
        self.listedArchiveCount = listedArchiveCount
        self.listedArchiveGroups = listedArchiveGroups
        self.keystoneEntries = keystoneEntries
        self.filesystemArchiveCount = filesystemArchiveCount
        self.filesystemArchiveGroups = filesystemArchiveGroups
        self.unlistedFilesystemArchives = unlistedFilesystemArchives
        self.missingListedArchives = missingListedArchives
        self.probeSummary = probeSummary
        self.sealSummaryLines = sealSummaryLines
        self.recommendationLines = recommendationLines
        self.scanWarnings = scanWarnings
    }
}

public struct ArchiveSealResearchReporter: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func makeReport(gameInstall: GameInstall, generatedAt: Date = Date()) -> ArchiveSealResearchReport {
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        let codeResourcesURL = contentsURL.appendingPathComponent("_CodeSignature/CodeResources")
        let archiveRootURL = contentsURL.appendingPathComponent("Data/archive", isDirectory: true)
        var warnings: [String] = []

        let codeResourcesLoad = loadCodeResourcesEntries(codeResourcesURL)
        let codeResourcePaths = Set(codeResourcesLoad.paths)
        let listedArchives = makeListedArchiveEntries(paths: codeResourcesLoad.paths, contentsURL: contentsURL)
        let filesystemArchives = collectFilesystemArchiveEntries(
            archiveRootURL: archiveRootURL,
            contentsURL: contentsURL,
            listedPaths: codeResourcePaths,
            warnings: &warnings
        )
        let keystoneEntries = codeResourcesLoad.paths
            .filter { $0.lowercased().contains("keystone") && !$0.lowercased().hasSuffix(".archive") }
            .sorted()
            .map { path in
                let url = contentsURL.appendingPathComponent(path)
                return ArchiveSealKeystoneEntry(
                    path: path,
                    existsOnDisk: FileManager.default.fileExists(atPath: url.path),
                    sizeBytes: fileSize(url)
                )
            }

        let unlistedFilesystemArchives = filesystemArchives.filter { !$0.listedInCodeResources }
        let missingListedArchives = listedArchives.filter { !$0.existsOnDisk }
        let probeLoad = loadProbeState()
        let probeSummary = makeProbeSummary(records: probeLoad.records, load: probeLoad, listedPaths: codeResourcePaths, contentsURL: contentsURL)
        let sealSummaryLines = makeSealSummaryLines(
            unlistedFilesystemArchives: unlistedFilesystemArchives,
            missingListedArchives: missingListedArchives
        )
        let recommendationLines = makeRecommendationLines(
            probeSummary: probeSummary,
            unlistedFilesystemArchives: unlistedFilesystemArchives
        )

        return ArchiveSealResearchReport(
            generatedAt: generatedAt,
            gameAppPath: gameInstall.appURL.path,
            contentsPath: contentsURL.path,
            codeResourcesPath: codeResourcesURL.path,
            codeResourcesExists: codeResourcesLoad.exists,
            codeResourcesLoadError: codeResourcesLoad.error,
            listedArchiveCount: listedArchives.count,
            listedArchiveGroups: groupListedArchives(listedArchives),
            keystoneEntries: keystoneEntries,
            filesystemArchiveCount: filesystemArchives.count,
            filesystemArchiveGroups: groupFilesystemArchives(filesystemArchives),
            unlistedFilesystemArchives: unlistedFilesystemArchives,
            missingListedArchives: missingListedArchives,
            probeSummary: probeSummary,
            sealSummaryLines: sealSummaryLines,
            recommendationLines: recommendationLines,
            scanWarnings: warnings.sorted()
        )
    }

    private func loadCodeResourcesEntries(_ url: URL) -> CodeResourcesLoad {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CodeResourcesLoad(exists: false, paths: [], error: nil)
        }

        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dictionary = plist as? [String: Any] else {
                return CodeResourcesLoad(exists: true, paths: [], error: "CodeResources is not a property-list dictionary.")
            }

            var paths = Set<String>()
            for key in ["files", "files2"] {
                if let files = dictionary[key] as? [String: Any] {
                    paths.formUnion(files.keys.map(normalizedCodeResourcePath))
                }
            }
            return CodeResourcesLoad(exists: true, paths: paths.sorted(), error: nil)
        } catch {
            return CodeResourcesLoad(exists: true, paths: [], error: String(describing: error))
        }
    }

    private func makeListedArchiveEntries(paths: [String], contentsURL: URL) -> [ArchiveSealCodeResourceEntry] {
        paths
            .filter { $0.lowercased().hasSuffix(".archive") }
            .sorted()
            .map { path in
                let url = contentsURL.appendingPathComponent(path)
                return ArchiveSealCodeResourceEntry(
                    path: path,
                    directory: listedArchiveGroupDirectory(path),
                    fileName: URL(fileURLWithPath: path).lastPathComponent,
                    existsOnDisk: FileManager.default.fileExists(atPath: url.path),
                    sizeBytes: fileSize(url)
                )
            }
    }

    private func collectFilesystemArchiveEntries(
        archiveRootURL: URL,
        contentsURL: URL,
        listedPaths: Set<String>,
        warnings: inout [String]
    ) -> [ArchiveSealFilesystemEntry] {
        guard FileManager.default.fileExists(atPath: archiveRootURL.path) else {
            return []
        }
        guard let enumerator = FileManager.default.enumerator(
            at: archiveRootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            warnings.append("Could not enumerate \(PathSafety.redactUserPath(archiveRootURL.path)).")
            return []
        }

        var entries: [ArchiveSealFilesystemEntry] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, url.pathExtension.lowercased() == "archive" else {
                    continue
                }
                let contentsRelative = normalizedCodeResourcePath((try? PathSafety.relativePath(of: url, in: contentsURL)) ?? url.lastPathComponent)
                let directory = actualCodeResourceDirectory(contentsRelative)
                entries.append(ArchiveSealFilesystemEntry(
                    path: contentsRelative,
                    directory: directory,
                    fileName: url.lastPathComponent,
                    sizeBytes: values.fileSize.map { UInt64(max($0, 0)) },
                    listedInCodeResources: listedPaths.contains(contentsRelative),
                    highlightedLoosePath: isHighlightedLoosePath(contentsRelative)
                ))
            } catch {
                warnings.append("Could not read archive attributes for \(PathSafety.redactUserPath(url.path)): \(error.localizedDescription)")
            }
        }
        return entries.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func loadProbeState() -> ArchiveSealProbeLoad {
        let url = home.archiveProbeStateURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ArchiveSealProbeLoad(path: url.path, exists: false, records: [], error: nil)
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder.cybermac.decode(ArchiveProbeState.self, from: data)
            return ArchiveSealProbeLoad(path: url.path, exists: true, records: state.records, error: nil)
        } catch {
            return ArchiveSealProbeLoad(path: url.path, exists: true, records: [], error: String(describing: error))
        }
    }

    private func makeProbeSummary(
        records: [ArchiveProbeRecord],
        load: ArchiveSealProbeLoad,
        listedPaths: Set<String>,
        contentsURL: URL
    ) -> ArchiveSealProbeSummary {
        let expectedCandidates = Set(ArchiveProbeCandidate.allCases.map(\.dataRelativePath))
        let ibmRecords = records.filter { $0.archiveFileName.lowercased().contains("ibm 3270") }
        let ibmNoEffectCandidates = Set(
            ibmRecords
                .filter { $0.userReportedResult == .noEffect }
                .map { candidateDisplayPath(forTargetPath: $0.candidateTargetPath) }
                .filter { expectedCandidates.contains($0) }
        )
        let ibmAllNoEffect = !ibmRecords.isEmpty &&
            ibmRecords.allSatisfy { $0.userReportedResult == .noEffect } &&
            ibmNoEffectCandidates == expectedCandidates
        let probeTargets = records.map { URL(fileURLWithPath: $0.candidateTargetPath) }
        let allProbeTargetsUnlisted = !probeTargets.isEmpty && probeTargets.allSatisfy { targetURL in
            guard let relative = try? PathSafety.relativePath(of: targetURL, in: contentsURL) else {
                return true
            }
            return !listedPaths.contains(normalizedCodeResourcePath(relative))
        }

        return ArchiveSealProbeSummary(
            statePath: load.path,
            stateExists: load.exists,
            loadError: load.error,
            totalProbes: records.count,
            ibm3270AllFourNoEffect: ibmAllNoEffect,
            anyProbeRecordedWorked: records.contains { $0.userReportedResult == .worked },
            allProbeTargetsUnlistedFromCodeResources: allProbeTargetsUnlisted
        )
    }

    private func makeSealSummaryLines(
        unlistedFilesystemArchives: [ArchiveSealFilesystemEntry],
        missingListedArchives: [ArchiveSealCodeResourceEntry]
    ) -> [String] {
        [
            "On-disk .archive files not listed in CodeResources: \(unlistedFilesystemArchives.isEmpty ? "no" : "yes (\(unlistedFilesystemArchives.count))").",
            "CodeResources-listed .archive files missing on disk: \(missingListedArchives.isEmpty ? "no" : "yes (\(missingListedArchives.count))").",
            "CodeResources alone does not prove game-loader behavior, but unlisted loose archives being ignored is consistent with a fixed resource/archive list hypothesis."
        ]
    }

    private func makeRecommendationLines(
        probeSummary: ArchiveSealProbeSummary,
        unlistedFilesystemArchives: [ArchiveSealFilesystemEntry]
    ) -> [String] {
        if probeSummary.anyProbeRecordedWorked {
            return ["Phase C may be reconsidered: at least one archive probe recorded worked, but this read-only seal analysis still does not implement or validate archive installation."]
        }

        if probeSummary.ibm3270AllFourNoEffect && probeSummary.allProbeTargetsUnlistedFromCodeResources {
            return ["Keep Phase C blocked: IBM 3270 probes were no-effect across all four loose paths and their loose archive targets are outside CodeResources."]
        }

        if !unlistedFilesystemArchives.isEmpty {
            return ["Keep Phase C blocked: unlisted loose archives are present, and this command only supports the fixed resource/archive list hypothesis rather than archive installation."]
        }

        return ["Keep Phase C blocked: this command is read-only research and does not validate archive-only installation."]
    }

    private func groupListedArchives(_ entries: [ArchiveSealCodeResourceEntry]) -> [ArchiveSealCodeResourceGroup] {
        let grouped = Dictionary(grouping: entries, by: \.directory)
        return orderedGroupDirectories(Array(grouped.keys)).map { directory in
            ArchiveSealCodeResourceGroup(
                directory: directory,
                entries: (grouped[directory] ?? []).sorted { $0.path < $1.path }
            )
        }
    }

    private func groupFilesystemArchives(_ entries: [ArchiveSealFilesystemEntry]) -> [ArchiveSealFilesystemGroup] {
        let grouped = Dictionary(grouping: entries, by: \.directory)
        return orderedGroupDirectories(Array(grouped.keys)).map { directory in
            ArchiveSealFilesystemGroup(
                directory: directory,
                entries: (grouped[directory] ?? []).sorted { $0.path < $1.path }
            )
        }
    }

    private func orderedGroupDirectories(_ directories: [String]) -> [String] {
        let priority = ["Data/archive/Mac/content", "Data/archive/Mac/ep1"]
        return directories.sorted { lhs, rhs in
            let lhsRank = priority.firstIndex(of: lhs) ?? priority.count
            let rhsRank = priority.firstIndex(of: rhs) ?? priority.count
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
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
}

public enum ArchiveSealResearchReportFormatter {
    public static func format(_ report: ArchiveSealResearchReport) -> String {
        var lines: [String] = []
        let formatter = ISO8601DateFormatter()

        lines.append("Archive resource-seal research report")
        lines.append("Generated: \(formatter.string(from: report.generatedAt))")
        lines.append("Game app: \(PathSafety.redactUserPath(report.gameAppPath))")
        lines.append("Contents path: \(PathSafety.redactUserPath(report.contentsPath))")
        lines.append("CodeResources: \(report.codeResourcesExists ? "present" : "missing") at \(PathSafety.redactUserPath(report.codeResourcesPath))")
        if let error = report.codeResourcesLoadError {
            lines.append("CodeResources decode error: \(error)")
        }
        lines.append("")

        lines.append("CodeResources archive entries")
        lines.append("- Total .archive entries: \(report.listedArchiveCount)")
        lines.append("- Fixed signed archive resource list: \(report.listedArchiveCount > 0 ? "yes" : "no")")
        if report.listedArchiveGroups.isEmpty {
            lines.append("- No .archive entries listed in CodeResources.")
        } else {
            appendListedGroups(report.listedArchiveGroups, to: &lines)
        }
        lines.append("")

        lines.append("CodeResources keystone entries")
        if report.keystoneEntries.isEmpty {
            lines.append("- No keystone entries found.")
        } else {
            for entry in report.keystoneEntries {
                lines.append("- \(entry.path) [\(entry.existsOnDisk ? "exists" : "missing")\(formatSize(entry.sizeBytes))]")
            }
        }
        lines.append("")

        lines.append("Filesystem archive entries")
        lines.append("- Total .archive files under Contents/Data/archive: \(report.filesystemArchiveCount)")
        if report.filesystemArchiveGroups.isEmpty {
            lines.append("- No .archive files found under Contents/Data/archive.")
        } else {
            appendFilesystemGroups(report.filesystemArchiveGroups, to: &lines)
        }
        lines.append("")

        lines.append("Seal mismatch summary")
        lines.append(contentsOf: report.sealSummaryLines.map { "- \($0)" })
        if !report.unlistedFilesystemArchives.isEmpty {
            lines.append("- Unlisted files:")
            for entry in report.unlistedFilesystemArchives {
                let marker = entry.highlightedLoosePath ? " loose-path" : ""
                lines.append("  - \(entry.path)\(marker)")
            }
        }
        if !report.missingListedArchives.isEmpty {
            lines.append("- Missing listed files:")
            for entry in report.missingListedArchives {
                lines.append("  - \(entry.path)")
            }
        }
        lines.append("")

        lines.append("Probe integration")
        lines.append("- State file: \(report.probeSummary.stateExists ? "present" : "missing") at \(PathSafety.redactUserPath(report.probeSummary.statePath))")
        if let error = report.probeSummary.loadError {
            lines.append("- State decode error: \(error)")
        }
        lines.append("- Total probes: \(report.probeSummary.totalProbes)")
        lines.append("- IBM 3270 all four no-effect: \(yesNo(report.probeSummary.ibm3270AllFourNoEffect))")
        lines.append("- Any probe recorded worked: \(yesNo(report.probeSummary.anyProbeRecordedWorked))")
        lines.append("- All probe targets unlisted from CodeResources: \(yesNo(report.probeSummary.allProbeTargetsUnlistedFromCodeResources))")
        lines.append("")

        lines.append("Recommendation")
        lines.append(contentsOf: report.recommendationLines.map { "- \($0)" })
        lines.append("- No archive install, activation, backup, restore, sidecar archive path, sudo, codesign, or game-bundle write behavior is performed by this command.")

        if !report.scanWarnings.isEmpty {
            lines.append("")
            lines.append("Scan warnings")
            lines.append(contentsOf: report.scanWarnings.map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }

    private static func appendListedGroups(_ groups: [ArchiveSealCodeResourceGroup], to lines: inout [String]) {
        for group in groups {
            lines.append("\(group.directory):")
            for entry in group.entries {
                lines.append("- \(entry.fileName) [\(entry.existsOnDisk ? "exists" : "missing")\(formatSize(entry.sizeBytes))]")
            }
        }
    }

    private static func appendFilesystemGroups(_ groups: [ArchiveSealFilesystemGroup], to lines: inout [String]) {
        for group in groups {
            lines.append("\(group.directory):")
            for entry in group.entries {
                var flags = [entry.listedInCodeResources ? "listed" : "unlisted"]
                if entry.highlightedLoosePath && !entry.listedInCodeResources {
                    flags.append("loose-path")
                }
                lines.append("- \(entry.fileName) [\(flags.joined(separator: ", "))\(formatSize(entry.sizeBytes))]")
            }
        }
    }

    private static func formatSize(_ sizeBytes: UInt64?) -> String {
        guard let sizeBytes else { return "" }
        return ", \(sizeBytes) bytes"
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private struct CodeResourcesLoad {
    let exists: Bool
    let paths: [String]
    let error: String?
}

private struct ArchiveSealProbeLoad {
    let path: String
    let exists: Bool
    let records: [ArchiveProbeRecord]
    let error: String?
}

private func normalizedCodeResourcePath(_ path: String) -> String {
    var value = path.replacingOccurrences(of: "\\", with: "/")
    while value.hasPrefix("./") {
        value.removeFirst(2)
    }
    while value.hasPrefix("/") {
        value.removeFirst()
    }
    return value
}

private func listedArchiveGroupDirectory(_ path: String) -> String {
    let directory = actualCodeResourceDirectory(path)
    if directory == "Data/archive/Mac/content" || directory == "Data/archive/Mac/ep1" {
        return directory
    }
    return "anything else"
}

private func actualCodeResourceDirectory(_ path: String) -> String {
    let normalized = normalizedCodeResourcePath(path)
    let url = URL(fileURLWithPath: normalized)
    let directory = url.deletingLastPathComponent().relativePath
    return directory.isEmpty || directory == "." ? "anything else" : directory
}

private func isHighlightedLoosePath(_ contentsRelativePath: String) -> Bool {
    let dataRelativeDirectory = actualCodeResourceDirectory(contentsRelativePath)
        .replacingOccurrences(of: "Data/", with: "")
        .lowercased()
    let highlighted: Set<String> = [
        "archive/mac/mod",
        "archive/mac/content",
        "archive/pc/mod",
        "archive/pc/content"
    ]
    return highlighted.contains(dataRelativeDirectory)
}

private func fileSize(_ url: URL) -> UInt64? {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
          values.isRegularFile == true,
          let fileSize = values.fileSize
    else {
        return nil
    }
    return UInt64(max(fileSize, 0))
}
