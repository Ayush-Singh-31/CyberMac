import Foundation

public struct ArchiveStringResearchOptions: Sendable, Equatable {
    public let maxScannableFileBytes: UInt64
    public let contextBytes: Int
    public let searchTerms: [String]

    public init(
        maxScannableFileBytes: UInt64 = 256 * 1024 * 1024,
        contextBytes: Int = 56,
        searchTerms: [String] = ArchiveStringResearchOptions.defaultSearchTerms
    ) {
        self.maxScannableFileBytes = maxScannableFileBytes
        self.contextBytes = max(8, contextBytes)
        self.searchTerms = searchTerms
    }

    public static let `default` = ArchiveStringResearchOptions()

    public static let defaultSearchTerms: [String] = [
        ".archive",
        "archive/",
        "archive\\",
        "archive/Mac/content",
        "archive/Mac/ep1",
        "archive/Mac/mod",
        "archive/pc/mod",
        "archive/pc/content",
        "Mac/content",
        "Mac/ep1",
        "Mac/mod",
        "pc/mod",
        "pc/content",
        "basegame_2_mainmenu",
        "basegame_1_engine",
        "memoryresident_1_general",
        "ep1_2_gamedata",
        "addcont_keystone",
        "keystone",
        "manifest",
        "catalog",
        "index",
        "toc",
        "bundle",
        "mount",
        "redmod",
        "mod"
    ]
}

public enum ArchiveStringResearchFileStatus: String, Sendable, Equatable {
    case scanned
    case skipped
    case missing
}

public struct ArchiveStringResearchFile: Sendable, Equatable {
    public let relativePath: String
    public let role: String
    public let status: ArchiveStringResearchFileStatus
    public let sizeBytes: UInt64?
    public let reason: String?

    public init(
        relativePath: String,
        role: String,
        status: ArchiveStringResearchFileStatus,
        sizeBytes: UInt64?,
        reason: String?
    ) {
        self.relativePath = relativePath
        self.role = role
        self.status = status
        self.sizeBytes = sizeBytes
        self.reason = reason
    }
}

public struct ArchiveStringHit: Sendable, Equatable {
    public let term: String
    public let occurrences: Int
    public let context: String?
    public let tags: [String]

    public init(term: String, occurrences: Int, context: String?, tags: [String]) {
        self.term = term
        self.occurrences = occurrences
        self.context = context
        self.tags = tags
    }
}

public struct ArchiveStringFileHits: Sendable, Equatable {
    public let file: String
    public let hits: [ArchiveStringHit]

    public init(file: String, hits: [ArchiveStringHit]) {
        self.file = file
        self.hits = hits
    }
}

public struct ArchiveStringArchiveDirectory: Sendable, Equatable {
    public let relativePath: String
    public let exists: Bool
    public let fileCount: Int
    public let directoryCount: Int

    public init(relativePath: String, exists: Bool, fileCount: Int, directoryCount: Int) {
        self.relativePath = relativePath
        self.exists = exists
        self.fileCount = fileCount
        self.directoryCount = directoryCount
    }
}

public struct ArchiveStringResearchHighlights: Sendable, Equatable {
    public let fixedMacContentReferenced: Bool
    public let fixedMacEp1Referenced: Bool
    public let fixedArchivePathTermsFound: [String]
    public let looseArchivePathTermsFound: [String]
    public let registrationTermsFound: [String]
    public let anyProbeRecordedWorked: Bool
    public let phaseCBlocked: Bool

    public init(
        fixedMacContentReferenced: Bool,
        fixedMacEp1Referenced: Bool,
        fixedArchivePathTermsFound: [String],
        looseArchivePathTermsFound: [String],
        registrationTermsFound: [String],
        anyProbeRecordedWorked: Bool,
        phaseCBlocked: Bool
    ) {
        self.fixedMacContentReferenced = fixedMacContentReferenced
        self.fixedMacEp1Referenced = fixedMacEp1Referenced
        self.fixedArchivePathTermsFound = fixedArchivePathTermsFound
        self.looseArchivePathTermsFound = looseArchivePathTermsFound
        self.registrationTermsFound = registrationTermsFound
        self.anyProbeRecordedWorked = anyProbeRecordedWorked
        self.phaseCBlocked = phaseCBlocked
    }
}

public struct ArchiveStringResearchReport: Sendable, Equatable {
    public let generatedAt: Date
    public let gameAppPath: String
    public let contentsPath: String
    public let scannedFiles: [ArchiveStringResearchFile]
    public let skippedFiles: [ArchiveStringResearchFile]
    public let missingFiles: [ArchiveStringResearchFile]
    public let hitGroups: [ArchiveStringFileHits]
    public let archiveDirectories: [ArchiveStringArchiveDirectory]
    public let highlights: ArchiveStringResearchHighlights
    public let recommendationLines: [String]

    public init(
        generatedAt: Date,
        gameAppPath: String,
        contentsPath: String,
        scannedFiles: [ArchiveStringResearchFile],
        skippedFiles: [ArchiveStringResearchFile],
        missingFiles: [ArchiveStringResearchFile],
        hitGroups: [ArchiveStringFileHits],
        archiveDirectories: [ArchiveStringArchiveDirectory],
        highlights: ArchiveStringResearchHighlights,
        recommendationLines: [String]
    ) {
        self.generatedAt = generatedAt
        self.gameAppPath = gameAppPath
        self.contentsPath = contentsPath
        self.scannedFiles = scannedFiles
        self.skippedFiles = skippedFiles
        self.missingFiles = missingFiles
        self.hitGroups = hitGroups
        self.archiveDirectories = archiveDirectories
        self.highlights = highlights
        self.recommendationLines = recommendationLines
    }
}

public struct ArchiveStringResearchReporter: Sendable {
    private let home: CyberMacHomeManager

    public init(home: CyberMacHomeManager) {
        self.home = home
    }

    public func makeReport(
        gameInstall: GameInstall,
        options: ArchiveStringResearchOptions = .default,
        generatedAt: Date = Date()
    ) -> ArchiveStringResearchReport {
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        var scanned: [ArchiveStringResearchFile] = []
        var skipped: [ArchiveStringResearchFile] = []
        var missing: [ArchiveStringResearchFile] = []
        var hitGroups: [ArchiveStringFileHits] = []

        let fixedCandidates: [(URL, String, FixedScanPolicy)] = [
            (gameInstall.executableURL, "main executable", .scan),
            (contentsURL.appendingPathComponent("Info.plist"), "app metadata", .scan),
            (contentsURL.appendingPathComponent("_CodeSignature/CodeResources"), "app code signature resources", .scan),
            (contentsURL.appendingPathComponent("_MASReceipt/receipt"), "Mac App Store receipt", .receiptExistsOnly)
        ]

        for candidate in fixedCandidates {
            inspectFile(
                candidate.0,
                relativeRoot: contentsURL,
                role: candidate.1,
                policy: candidate.2,
                options: options,
                scanned: &scanned,
                skipped: &skipped,
                missing: &missing,
                hitGroups: &hitGroups
            )
        }

        inspectDataSideCandidates(
            dataURL: gameInstall.dataURL,
            contentsURL: contentsURL,
            options: options,
            scanned: &scanned,
            skipped: &skipped,
            hitGroups: &hitGroups
        )

        let archiveDirectories = inspectArchiveDirectories(dataURL: gameInstall.dataURL)
        let anyWorked = loadProbeRecords().contains { $0.userReportedResult == .worked }
        let highlights = makeHighlights(hitGroups: hitGroups, anyProbeRecordedWorked: anyWorked)

        return ArchiveStringResearchReport(
            generatedAt: generatedAt,
            gameAppPath: gameInstall.appURL.path,
            contentsPath: contentsURL.path,
            scannedFiles: scanned.sorted { $0.relativePath < $1.relativePath },
            skippedFiles: skipped.sorted { $0.relativePath < $1.relativePath },
            missingFiles: missing.sorted { $0.relativePath < $1.relativePath },
            hitGroups: hitGroups.sorted { $0.file < $1.file },
            archiveDirectories: archiveDirectories,
            highlights: highlights,
            recommendationLines: makeRecommendationLines(highlights: highlights)
        )
    }

    private func inspectDataSideCandidates(
        dataURL: URL,
        contentsURL: URL,
        options: ArchiveStringResearchOptions,
        scanned: inout [ArchiveStringResearchFile],
        skipped: inout [ArchiveStringResearchFile],
        hitGroups: inout [ArchiveStringFileHits]
    ) {
        guard let enumerator = FileManager.default.enumerator(
            at: dataURL,
            includingPropertiesForKeys: Array(candidateResourceKeys),
            options: []
        ) else {
            return
        }

        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: candidateResourceKeys)
            } catch {
                let file = makeFile(
                    url,
                    relativeRoot: contentsURL,
                    role: "data-side candidate",
                    status: .skipped,
                    sizeBytes: nil,
                    reason: "could not read file attributes: \(error.localizedDescription)"
                )
                skipped.append(file)
                continue
            }

            if values.isDirectory == true {
                continue
            }
            if values.isSymbolicLink == true {
                skipped.append(makeFile(
                    url,
                    relativeRoot: contentsURL,
                    role: "data-side candidate",
                    status: .skipped,
                    sizeBytes: values.fileSize.map { UInt64(max($0, 0)) },
                    reason: "symlink skipped"
                ))
                continue
            }

            let ext = url.pathExtension.lowercased()
            if ext == "archive" {
                skipped.append(makeFile(
                    url,
                    relativeRoot: contentsURL,
                    role: "archive asset",
                    status: .skipped,
                    sizeBytes: values.fileSize.map { UInt64(max($0, 0)) },
                    reason: ".archive contents are not scanned by default"
                ))
                continue
            }
            guard dataSideExtensions.contains(ext) else {
                continue
            }

            inspectFile(
                url,
                relativeRoot: contentsURL,
                role: "data-side \(ext) file",
                policy: .scan,
                options: options,
                scanned: &scanned,
                skipped: &skipped,
                missing: nil,
                hitGroups: &hitGroups
            )
        }
    }

    private func inspectFile(
        _ url: URL,
        relativeRoot: URL,
        role: String,
        policy: FixedScanPolicy,
        options: ArchiveStringResearchOptions,
        scanned: inout [ArchiveStringResearchFile],
        skipped: inout [ArchiveStringResearchFile],
        missing: UnsafeMutablePointer<[ArchiveStringResearchFile]>?,
        hitGroups: inout [ArchiveStringFileHits]
    ) {
        let attributes: URLResourceValues
        do {
            attributes = try url.resourceValues(forKeys: candidateResourceKeys)
        } catch {
            missing?.pointee.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .missing,
                sizeBytes: nil,
                reason: "not present"
            ))
            return
        }

        let sizeBytes = attributes.fileSize.map { UInt64(max($0, 0)) }
        guard attributes.isRegularFile == true else {
            skipped.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .skipped,
                sizeBytes: sizeBytes,
                reason: "not a regular file"
            ))
            return
        }

        if policy == .receiptExistsOnly {
            skipped.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .skipped,
                sizeBytes: sizeBytes,
                reason: "existence and size reported only; receipt data not parsed"
            ))
            return
        }

        if url.pathExtension.lowercased() == "archive" {
            skipped.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .skipped,
                sizeBytes: sizeBytes,
                reason: ".archive contents are not scanned by default"
            ))
            return
        }

        guard let sizeBytes, sizeBytes <= options.maxScannableFileBytes else {
            skipped.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .skipped,
                sizeBytes: sizeBytes,
                reason: "larger than scan cap of \(options.maxScannableFileBytes) bytes"
            ))
            return
        }

        let file = makeFile(
            url,
            relativeRoot: relativeRoot,
            role: role,
            status: .scanned,
            sizeBytes: sizeBytes,
            reason: nil
        )

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let hits = findHits(in: data, terms: options.searchTerms, contextBytes: options.contextBytes)
            scanned.append(file)
            if !hits.isEmpty {
                hitGroups.append(ArchiveStringFileHits(file: file.relativePath, hits: hits))
            }
        } catch {
            skipped.append(makeFile(
                url,
                relativeRoot: relativeRoot,
                role: role,
                status: .skipped,
                sizeBytes: sizeBytes,
                reason: "could not read file: \(error.localizedDescription)"
            ))
        }
    }

    private func inspectArchiveDirectories(dataURL: URL) -> [ArchiveStringArchiveDirectory] {
        let archiveRoot = dataURL.appendingPathComponent("archive", isDirectory: true)
        var directories: [URL] = [
            archiveRoot.appendingPathComponent("Mac/content", isDirectory: true),
            archiveRoot.appendingPathComponent("Mac/ep1", isDirectory: true)
        ]

        let rootChildren = (try? FileManager.default.contentsOfDirectory(
            at: archiveRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
        directories.append(contentsOf: rootChildren.filter { isDirectory($0) })

        let macURL = archiveRoot.appendingPathComponent("Mac", isDirectory: true)
        let macChildren = (try? FileManager.default.contentsOfDirectory(
            at: macURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
        directories.append(contentsOf: macChildren.filter { isDirectory($0) })

        return Dictionary(grouping: directories, by: { relativePath(of: $0, in: dataURL) })
            .keys
            .sorted()
            .map { relative in
                let url = dataURL.appendingPathComponent(relative, isDirectory: true)
                let counts = directoryChildCounts(url)
                return ArchiveStringArchiveDirectory(
                    relativePath: relative,
                    exists: isDirectory(url),
                    fileCount: counts.files,
                    directoryCount: counts.directories
                )
            }
    }

    private func loadProbeRecords() -> [ArchiveProbeRecord] {
        let url = home.archiveProbeStateURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder.cybermac.decode(ArchiveProbeState.self, from: data)
        else {
            return []
        }
        return state.records
    }

    private func findHits(in data: Data, terms: [String], contextBytes: Int) -> [ArchiveStringHit] {
        terms.compactMap { term in
            let termData = Data(term.utf8)
            guard !termData.isEmpty else { return nil }

            var occurrences = 0
            var firstContext: String?
            var searchStart = data.startIndex
            while searchStart < data.endIndex,
                  let range = data.range(of: termData, options: [], in: searchStart..<data.endIndex) {
                occurrences += 1
                if firstContext == nil {
                    firstContext = safeContext(in: data, around: range, contextBytes: contextBytes)
                }
                let nextStart = range.lowerBound + 1
                if nextStart >= data.endIndex {
                    break
                }
                searchStart = nextStart
            }

            guard occurrences > 0 else { return nil }
            return ArchiveStringHit(
                term: term,
                occurrences: occurrences,
                context: firstContext,
                tags: tags(for: term)
            )
        }
    }

    private func makeHighlights(hitGroups: [ArchiveStringFileHits], anyProbeRecordedWorked: Bool) -> ArchiveStringResearchHighlights {
        let terms = Set(hitGroups.flatMap { group in group.hits.map(\.term) })
        let fixedTerms = terms.intersection(fixedArchivePathTerms)
        let looseTerms = terms.intersection(looseArchivePathTerms)
        let registrationTerms = terms.intersection(registrationTerms)

        return ArchiveStringResearchHighlights(
            fixedMacContentReferenced: terms.contains("Mac/content") || terms.contains("archive/Mac/content"),
            fixedMacEp1Referenced: terms.contains("Mac/ep1") || terms.contains("archive/Mac/ep1"),
            fixedArchivePathTermsFound: Array(fixedTerms).sorted(),
            looseArchivePathTermsFound: Array(looseTerms).sorted(),
            registrationTermsFound: Array(registrationTerms).sorted(),
            anyProbeRecordedWorked: anyProbeRecordedWorked,
            phaseCBlocked: !anyProbeRecordedWorked
        )
    }

    private func makeRecommendationLines(highlights: ArchiveStringResearchHighlights) -> [String] {
        var lines: [String] = []
        if highlights.phaseCBlocked {
            lines.append("Phase C blocked: no binary archive probe recorded worked, so loose archive-only installation remains unvalidated.")
        } else {
            lines.append("Phase C still requires review: this command only searches loader strings and does not install or validate archive mods.")
        }
        lines.append("Use fixed-path and registration-string hits to guide the next archive loading research step.")
        lines.append("No archive install, activation, backup, restore, or game-bundle write behavior is performed by this command.")
        return lines
    }

    private func makeFile(
        _ url: URL,
        relativeRoot: URL,
        role: String,
        status: ArchiveStringResearchFileStatus,
        sizeBytes: UInt64?,
        reason: String?
    ) -> ArchiveStringResearchFile {
        ArchiveStringResearchFile(
            relativePath: relativePath(of: url, in: relativeRoot),
            role: role,
            status: status,
            sizeBytes: sizeBytes,
            reason: reason
        )
    }

    private func relativePath(of url: URL, in root: URL) -> String {
        (try? PathSafety.relativePath(of: url, in: root)) ?? url.lastPathComponent
    }

    private func safeContext(in data: Data, around range: Range<Data.Index>, contextBytes: Int) -> String {
        let lower = max(data.startIndex, range.lowerBound - contextBytes)
        let upper = min(data.endIndex, range.upperBound + contextBytes)
        var result = ""
        result.reserveCapacity(upper - lower)

        for byte in data[lower..<upper] {
            switch byte {
            case 32...126:
                result.append(Character(UnicodeScalar(Int(byte))!))
            case 9, 10, 13:
                result.append(" ")
            default:
                result.append(".")
            }
        }
        return result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }

    private func tags(for term: String) -> [String] {
        var result: [String] = []
        if fixedArchivePathTerms.contains(term) {
            result.append("fixed-path")
        }
        if looseArchivePathTerms.contains(term) {
            result.append("loose-mod-path")
        }
        if registrationTerms.contains(term) {
            result.append("registration")
        }
        return result
    }

    private func directoryChildCounts(_ url: URL) -> (files: Int, directories: Int) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            return (0, 0)
        }
        var files = 0
        var directories = 0
        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                directories += 1
            } else if values?.isRegularFile == true {
                files += 1
            }
        }
        return (files, directories)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

public enum ArchiveStringResearchReportFormatter {
    public static func format(_ report: ArchiveStringResearchReport) -> String {
        var lines: [String] = []
        let formatter = ISO8601DateFormatter()

        lines.append("Archive loading string research")
        lines.append("Generated: \(formatter.string(from: report.generatedAt))")
        lines.append("Game app: \(PathSafety.redactUserPath(report.gameAppPath))")
        lines.append("Contents: \(PathSafety.redactUserPath(report.contentsPath))")
        lines.append("")

        lines.append("Highlights")
        lines.append("- archive/Mac/content or Mac/content in scanned strings: \(yesNo(report.highlights.fixedMacContentReferenced))")
        lines.append("- archive/Mac/ep1 or Mac/ep1 in scanned strings: \(yesNo(report.highlights.fixedMacEp1Referenced))")
        lines.append("- Fixed archive path terms: \(joined(report.highlights.fixedArchivePathTermsFound))")
        lines.append("- Loose archive/mod path terms: \(joined(report.highlights.looseArchivePathTermsFound))")
        lines.append("- Registration/index terms: \(joined(report.highlights.registrationTermsFound))")
        lines.append("- Any probe recorded worked: \(yesNo(report.highlights.anyProbeRecordedWorked))")
        lines.append("- Phase C archive-only install: \(report.highlights.phaseCBlocked ? "blocked" : "requires review")")
        lines.append("")

        lines.append("Archive directories")
        if report.archiveDirectories.isEmpty {
            lines.append("- No archive directories found.")
        } else {
            for directory in report.archiveDirectories {
                lines.append("- \(directory.relativePath): \(directory.exists ? "exists" : "missing"); files \(directory.fileCount), directories \(directory.directoryCount)")
            }
        }
        lines.append("")

        lines.append("Files scanned")
        appendFiles(report.scannedFiles, emptyMessage: "No files scanned.", to: &lines)
        lines.append("")

        lines.append("Files skipped")
        appendFiles(report.skippedFiles, emptyMessage: "No files skipped.", to: &lines)
        lines.append("")

        if !report.missingFiles.isEmpty {
            lines.append("Files missing")
            appendFiles(report.missingFiles, emptyMessage: "No files missing.", to: &lines)
            lines.append("")
        }

        lines.append("Hits by file")
        if report.hitGroups.isEmpty {
            lines.append("- No string hits found.")
        } else {
            for group in report.hitGroups {
                lines.append("\(group.file):")
                for hit in group.hits {
                    let tags = hit.tags.isEmpty ? "" : " [\(hit.tags.joined(separator: ", "))]"
                    lines.append("  - \(hit.term): \(hit.occurrences) occurrence(s)\(tags)")
                    if let context = hit.context, !context.isEmpty {
                        lines.append("    context: \(context)")
                    }
                }
            }
        }
        lines.append("")

        lines.append("Recommendation")
        lines.append(contentsOf: report.recommendationLines.map { "- \($0)" })

        return lines.joined(separator: "\n")
    }

    private static func appendFiles(_ files: [ArchiveStringResearchFile], emptyMessage: String, to lines: inout [String]) {
        if files.isEmpty {
            lines.append("- \(emptyMessage)")
            return
        }
        for file in files {
            var parts = ["- \(file.relativePath)", file.role]
            if let sizeBytes = file.sizeBytes {
                parts.append("\(sizeBytes) bytes")
            }
            if let reason = file.reason {
                parts.append(reason)
            }
            lines.append(parts.joined(separator: " | "))
        }
    }

    private static func joined(_ values: [String]) -> String {
        values.isEmpty ? "none" : values.joined(separator: ", ")
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private enum FixedScanPolicy {
    case scan
    case receiptExistsOnly
}

private let candidateResourceKeys: Set<URLResourceKey> = [
    .isDirectoryKey,
    .isRegularFileKey,
    .isSymbolicLinkKey,
    .fileSizeKey
]

private let dataSideExtensions: Set<String> = [
    "json",
    "bin",
    "cache",
    "toc",
    "idx",
    "manifest",
    "db"
]

private let fixedArchivePathTerms: Set<String> = [
    "archive/Mac/content",
    "archive/Mac/ep1",
    "Mac/content",
    "Mac/ep1"
]

private let looseArchivePathTerms: Set<String> = [
    "archive/Mac/mod",
    "archive/pc/mod",
    "archive/pc/content",
    "Mac/mod",
    "pc/mod",
    "pc/content"
]

private let registrationTerms: Set<String> = [
    ".archive",
    "archive/",
    "archive\\",
    "manifest",
    "catalog",
    "index",
    "toc",
    "bundle",
    "mount",
    "redmod"
]
