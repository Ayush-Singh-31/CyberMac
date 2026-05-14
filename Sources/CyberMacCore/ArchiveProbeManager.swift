import Foundation
import ZIPFoundation

public struct ArchiveProbeCopyVerificationResult: Sendable, Equatable {
    public let record: ArchiveProbeRecord
    public let targetExists: Bool
    public let matched: Bool
    public let expectedSHA256: String
    public let actualSHA256: String?

    public init(record: ArchiveProbeRecord, targetExists: Bool, matched: Bool, expectedSHA256: String, actualSHA256: String?) {
        self.record = record
        self.targetExists = targetExists
        self.matched = matched
        self.expectedSHA256 = expectedSHA256
        self.actualSHA256 = actualSHA256
    }
}

public struct ArchiveProbeRemovalVerificationResult: Sendable, Equatable {
    public let record: ArchiveProbeRecord
    public let targetExists: Bool
    public let removed: Bool

    public init(record: ArchiveProbeRecord, targetExists: Bool, removed: Bool) {
        self.record = record
        self.targetExists = targetExists
        self.removed = removed
    }
}

public struct ArchiveProbeManager: Sendable {
    private let home: CyberMacHomeManager
    private let scanner: ModArchiveScanner

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.scanner = ModArchiveScanner()
    }

    public func prepare(zipURL: URL, gameInstall: GameInstall, candidate: ArchiveProbeCandidate = .macMod) throws -> ArchiveProbeRecord {
        try home.bootstrap()
        let scan = try scanner.scan(zipURL: zipURL)
        let archivePath = try validatedProbeArchivePath(scan)
        let archiveFileName = URL(fileURLWithPath: archivePath).lastPathComponent
        guard archiveFileName.lowercased().hasSuffix(".archive") else {
            throw CyberMacError.invalidInput("Archive probe source is not a .archive file: \(archivePath)")
        }

        var state = try loadState()
        let id = uniqueProbeID(existingRecords: state.records)
        let probeDirectory = home.archiveProbeTmpURL.appendingPathComponent(id, isDirectory: true)
        let extractedArchiveURL = probeDirectory.appendingPathComponent(archiveFileName)
        try PathSafety.validateContainedPath(probeDirectory, in: home.archiveProbeTmpURL)
        try PathSafety.validateContainedPath(extractedArchiveURL, in: probeDirectory)

        do {
            try FileManager.default.createDirectory(at: probeDirectory, withIntermediateDirectories: true)
            try extractArchiveFile(from: zipURL, archivePath: archivePath, to: extractedArchiveURL)

            let archiveSHA256 = try PathSafety.sha256(url: extractedArchiveURL)
            let candidateDirectory = try targetDirectory(for: candidate, gameInstall: gameInstall)
            let targetURL = candidateDirectory.appendingPathComponent(archiveFileName)
            try PathSafety.validateContainedPath(targetURL, in: candidateDirectory)

            let copyCommands = [
                "sudo mkdir -p \(PathSafety.shellQuoted(candidateDirectory.path))",
                "sudo cp \(PathSafety.shellQuoted(extractedArchiveURL.path)) \(PathSafety.shellQuoted(targetURL.path))"
            ].joined(separator: "\n")
            let removalCommand = "sudo rm -f \(PathSafety.shellQuoted(targetURL.path))"

            let record = ArchiveProbeRecord(
                id: id,
                createdAt: Date(),
                modArchivePath: zipURL.path,
                archiveFileName: archiveFileName,
                archiveSHA256: archiveSHA256,
                candidateTargetPath: targetURL.path,
                commandPrinted: copyCommands,
                removalCommandPrinted: removalCommand
            )
            state.records.append(record)
            try saveState(state)
            return record
        } catch {
            try? FileManager.default.removeItem(at: probeDirectory)
            throw error
        }
    }

    public func verifyCopy(id: String) throws -> ArchiveProbeCopyVerificationResult {
        var state = try loadState()
        let index = try recordIndex(id: id, in: state.records)
        var record = state.records[index]
        let targetURL = try validatedPersistedTargetURL(for: record)

        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            record.verifiedCopied = false
            state.records[index] = record
            try saveState(state)
            return ArchiveProbeCopyVerificationResult(
                record: record,
                targetExists: false,
                matched: false,
                expectedSHA256: record.archiveSHA256,
                actualSHA256: nil
            )
        }

        let actualSHA256 = try PathSafety.sha256(url: targetURL)
        let matched = actualSHA256 == record.archiveSHA256
        record.verifiedCopied = matched
        state.records[index] = record
        try saveState(state)
        return ArchiveProbeCopyVerificationResult(
            record: record,
            targetExists: true,
            matched: matched,
            expectedSHA256: record.archiveSHA256,
            actualSHA256: actualSHA256
        )
    }

    public func verifyRemoval(id: String) throws -> ArchiveProbeRemovalVerificationResult {
        var state = try loadState()
        let index = try recordIndex(id: id, in: state.records)
        var record = state.records[index]
        let targetURL = try validatedPersistedTargetURL(for: record)
        let targetExists = FileManager.default.fileExists(atPath: targetURL.path)
        record.verifiedRemoved = !targetExists
        state.records[index] = record
        try saveState(state)
        return ArchiveProbeRemovalVerificationResult(record: record, targetExists: targetExists, removed: !targetExists)
    }

    public func recordResult(id: String, result: ArchiveProbeUserResult) throws -> ArchiveProbeRecord {
        var state = try loadState()
        let index = try recordIndex(id: id, in: state.records)
        var record = state.records[index]
        record.userReportedResult = result
        state.records[index] = record
        try saveState(state)
        return record
    }

    public func list() throws -> [ArchiveProbeRecord] {
        try loadState().records.sorted { $0.createdAt > $1.createdAt }
    }

    public func targetDirectory(for candidate: ArchiveProbeCandidate, gameInstall: GameInstall) throws -> URL {
        let directory = candidate.dataRelativePath
            .split(separator: "/")
            .reduce(gameInstall.dataURL) { partial, component in
                partial.appendingPathComponent(String(component), isDirectory: true)
            }
        try PathSafety.validateContainedPath(directory, in: gameInstall.dataURL)
        return directory
    }

    private func loadState() throws -> ArchiveProbeState {
        guard FileManager.default.fileExists(atPath: home.archiveProbeStateURL.path) else {
            return ArchiveProbeState()
        }
        let data = try Data(contentsOf: home.archiveProbeStateURL)
        return try JSONDecoder.cybermac.decode(ArchiveProbeState.self, from: data)
    }

    private func saveState(_ state: ArchiveProbeState) throws {
        try home.bootstrap()
        let data = try JSONEncoder.cybermac.encode(state)
        try data.write(to: home.archiveProbeStateURL, options: [.atomic])
    }

    private func validatedPersistedTargetURL(for record: ArchiveProbeRecord) throws -> URL {
        let rawPath = record.candidateTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPath.isEmpty else {
            throw tamperedTargetPath("Persisted target path is empty.")
        }
        guard rawPath.hasPrefix("/") else {
            throw tamperedTargetPath("Persisted target path is not absolute: \(record.candidateTargetPath)")
        }
        guard !containsControlCharacter(rawPath) else {
            throw tamperedTargetPath("Persisted target path contains control characters.")
        }
        let rawComponents = rawPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !rawComponents.contains("..") else {
            throw tamperedTargetPath("Persisted target path contains traversal: \(record.candidateTargetPath)")
        }
        guard isPlainArchiveFileName(record.archiveFileName) else {
            throw tamperedTargetPath("Persisted archive file name is invalid: \(record.archiveFileName)")
        }

        let targetURL = URL(fileURLWithPath: rawPath).standardizedFileURL
        guard targetURL.lastPathComponent == record.archiveFileName else {
            throw tamperedTargetPath("Persisted target file name does not match \(record.archiveFileName): \(record.candidateTargetPath)")
        }
        guard isApprovedCandidateTarget(targetURL, archiveFileName: record.archiveFileName) else {
            throw tamperedTargetPath("Persisted target path is outside approved archive probe directories: \(record.candidateTargetPath)")
        }
        return targetURL
    }

    private func isPlainArchiveFileName(_ fileName: String) -> Bool {
        guard !fileName.isEmpty,
              fileName.lowercased().hasSuffix(".archive"),
              !fileName.contains("/"),
              !fileName.contains("\\"),
              !containsControlCharacter(fileName),
              fileName != ".",
              fileName != ".."
        else {
            return false
        }
        return URL(fileURLWithPath: fileName).lastPathComponent == fileName
    }

    private func isApprovedCandidateTarget(_ targetURL: URL, archiveFileName: String) -> Bool {
        let components = targetURL.pathComponents
        guard components.last == archiveFileName else { return false }

        for appIndex in components.indices where components[appIndex].lowercased().hasSuffix(".app") {
            for candidate in ArchiveProbeCandidate.allCases {
                let expectedTail = ["Contents", "Data"] +
                    candidate.dataRelativePath.split(separator: "/").map(String.init) +
                    [archiveFileName]
                let startIndex = appIndex + 1
                guard components.count == startIndex + expectedTail.count else { continue }
                if Array(components[startIndex..<components.count]) == expectedTail {
                    return true
                }
            }
        }
        return false
    }

    private func containsControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private func tamperedTargetPath(_ message: String) -> CyberMacError {
        CyberMacError.unsafePath("Archive probe target path is invalid or tampered. \(message)")
    }

    private func validatedProbeArchivePath(_ scan: ModScanResult) throws -> String {
        guard scan.kind == .archiveOnly,
              scan.compatibilityStatus == .untested,
              !scan.sidecarInstallable
        else {
            throw CyberMacError.unsupported("Archive probe accepts only pure archive-only packages. Scan kind: \(scan.kind.rawValue), status: \(scan.compatibilityStatus.rawValue)")
        }
        guard scan.redscriptEntries.isEmpty else {
            throw CyberMacError.unsupported("Archive probe refuses packages containing redscript files.")
        }
        guard scan.inputMappingEntries.isEmpty,
              !scan.requiresInputMappingPatch,
              !scan.dependencyMarkers.hasInputMappingXML
        else {
            throw CyberMacError.unsupported("Archive probe refuses packages containing input XML.")
        }
        guard !hasUnsupportedMarkers(scan.dependencyMarkers) else {
            throw CyberMacError.unsupported("Archive probe refuses framework, native plugin, or REDmod packages.")
        }
        guard scan.archiveEntries.count == 1 else {
            throw CyberMacError.unsupported("Archive probe requires exactly one .archive file; found \(scan.archiveEntries.count).")
        }

        let archivePath = scan.archiveEntries[0]
        let disallowedFindings = scan.findings.filter { finding in
            !(finding.path == archivePath && finding.reason.contains("Archive asset file detected"))
        }
        guard disallowedFindings.isEmpty else {
            let summary = disallowedFindings.map { "\($0.path): \($0.reason)" }.joined(separator: "; ")
            throw CyberMacError.unsupported("Archive probe refuses packages with uncontrolled extra content: \(summary)")
        }
        return archivePath
    }

    private func hasUnsupportedMarkers(_ markers: ModDependencyMarkers) -> Bool {
        markers.hasArchiveXL ||
            markers.hasTweakXL ||
            markers.hasRED4ext ||
            markers.hasCodeware ||
            markers.hasCET ||
            markers.hasEquipmentEX ||
            markers.hasREDmod ||
            markers.hasNativePlugin
    }

    private func extractArchiveFile(from zipURL: URL, archivePath: String, to targetURL: URL) throws {
        let zipArchive: Archive
        do {
            zipArchive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        for entry in zipArchive where entry.path == archivePath {
            try PathSafety.validateArchivePath(entry.path)
            guard entry.type == .file else {
                throw CyberMacError.invalidInput("Archive probe source is not a file: \(entry.path)")
            }
            _ = try zipArchive.extract(entry, to: targetURL)
            return
        }
        throw CyberMacError.notFound("Archive entry not found after scan: \(archivePath)")
    }

    private func uniqueProbeID(existingRecords: [ArchiveProbeRecord]) -> String {
        let base = Self.makeProbeID()
        let existingIDs = Set(existingRecords.map(\.id))
        if !existingIDs.contains(base),
           !FileManager.default.fileExists(atPath: home.archiveProbeTmpURL.appendingPathComponent(base, isDirectory: true).path) {
            return base
        }
        return "\(base)-\(UUID().uuidString.prefix(8))"
    }

    private static func makeProbeID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return "archive-probe-\(formatter.string(from: date))"
    }

    private func recordIndex(id: String, in records: [ArchiveProbeRecord]) throws -> Int {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw CyberMacError.notFound("Archive probe record not found: \(id)")
        }
        return index
    }
}
