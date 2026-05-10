import Foundation
import ZIPFoundation

public struct ModArchiveScanner: Sendable {
    public init() {}

    public func scan(zipURL: URL, launchWorkflowVerified: Bool) throws -> ModScanResult {
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw CyberMacError.notFound("Mod archive does not exist: \(zipURL.path)")
        }
        guard zipURL.pathExtension.lowercased() == "zip" else {
            throw CyberMacError.invalidInput("v0.1 scanner currently accepts .zip files only")
        }
        try PathSafety.validateArchiveSize(zipURL)
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }

        var allEntries: [String] = []
        var redscriptEntries: [String] = []
        var archiveEntries: [String] = []
        var unsupportedFindings: [ModScanFinding] = []
        var untestedFindings: [ModScanFinding] = []
        var entryCount = 0

        for entry in archive {
            entryCount += 1
            guard entryCount <= PathSafety.maxArchiveEntries else {
                throw CyberMacError.invalidInput("Archive has too many entries: limit is \(PathSafety.maxArchiveEntries)")
            }
            try PathSafety.validateArchivePath(entry.path)
            let path = entry.path
            let lower = path.lowercased()
            allEntries.append(path)

            switch entry.type {
            case .directory:
                continue
            case .symlink:
                untestedFindings.append(ModScanFinding(path: path, reason: "Symlink entries are not installed by CyberMac v0.1"))
                continue
            case .file:
                break
            }

            if lower.hasSuffix(".reds") {
                redscriptEntries.append(path)
                continue
            }

            if lower.hasSuffix(".archive") {
                archiveEntries.append(path)
                untestedFindings.append(ModScanFinding(path: path, reason: "Archive-based mods are not installed by CyberMac v0.1"))
                continue
            }

            if lower.hasSuffix(".dll") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Windows DLL plugin detected"))
                continue
            }

            if lower.hasSuffix(".asi") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "ASI plugin detected"))
                continue
            }

            if lower.hasSuffix(".lua") {
                if containsPathComponents(lower, ["bin", "x64", "plugins", "cyber_engine_tweaks"]) {
                    unsupportedFindings.append(ModScanFinding(path: path, reason: "Cyber Engine Tweaks Lua script detected"))
                } else {
                    untestedFindings.append(ModScanFinding(path: path, reason: "Lua script outside a known CET path"))
                }
                continue
            }

            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
                if containsPathComponents(lower, ["r6", "tweaks"]) {
                    unsupportedFindings.append(ModScanFinding(path: path, reason: "TweakXL r6/tweaks file detected"))
                } else {
                    untestedFindings.append(ModScanFinding(path: path, reason: "YAML file outside a known TweakXL path"))
                }
                continue
            }

            if containsPathComponents(lower, ["bin", "x64", "plugins"]) {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "bin/x64 plugin marker detected"))
                continue
            }

            if lower.contains("red4ext") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "RED4ext marker detected"))
                continue
            }

            if lower.contains("cyber_engine_tweaks") || pathComponents(lower).contains("cet") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Cyber Engine Tweaks marker detected"))
                continue
            }

            if lower.contains("archivexl") || lower.contains("archive-xl") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "ArchiveXL marker detected"))
                continue
            }

            if lower.contains("tweakxl") || lower.contains("tweak-xl") || containsPathComponents(lower, ["r6", "tweaks"]) {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "TweakXL marker detected"))
                continue
            }

            if lower.contains("codeware") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Codeware marker detected"))
                continue
            }

            if isDocumentationOrMetadata(lower) {
                continue
            }

            untestedFindings.append(ModScanFinding(path: path, reason: "Unknown file type or layout"))
        }

        let displayName = zipURL.deletingPathExtension().lastPathComponent
        let kind = determineKind(redscriptEntries: redscriptEntries, archiveEntries: archiveEntries, allEntries: allEntries)
        let status: CompatibilityStatus
        let installable: Bool
        let installBlockReason: String?
        var reasons: [String] = []
        var findings: [ModScanFinding] = []

        if !unsupportedFindings.isEmpty {
            status = .unsupported
            installable = false
            installBlockReason = "Known unsupported dependency or Windows modding marker detected"
            reasons.append("Known unsupported dependency or Windows modding marker detected")
            findings = unsupportedFindings + untestedFindings
        } else if !redscriptEntries.isEmpty && archiveEntries.isEmpty && untestedFindings.isEmpty {
            status = .supported
            if launchWorkflowVerified {
                installable = true
                installBlockReason = nil
                reasons.append("Found only .reds script files plus normal documentation or metadata")
                reasons.append("No CET, RED4ext, ArchiveXL, TweakXL, Codeware, DLL, or ASI markers detected")
                reasons.append("Launch workflow is verified")
            } else {
                installable = false
                installBlockReason = "CyberMac redscript launch workflow is not verified yet"
                reasons.append("Found redscript-only files plus normal documentation or metadata")
                reasons.append("No CET, RED4ext, ArchiveXL, TweakXL, Codeware, DLL, or ASI markers detected")
            }
            findings = []
        } else if redscriptEntries.isEmpty && !archiveEntries.isEmpty && unsupportedFindings.isEmpty {
            status = .untested
            installable = false
            installBlockReason = "Archive-based mods are not installed by CyberMac v0.1"
            reasons.append("Archive-based mods are not installed by CyberMac v0.1")
            findings = untestedFindings
        } else {
            status = .untested
            installable = false
            installBlockReason = "CyberMac v0.1 does not have a safe install rule for this archive layout"
            reasons.append("CyberMac v0.1 does not have a safe install rule for this archive layout")
            findings = untestedFindings
        }

        return ModScanResult(
            archiveURL: zipURL,
            displayName: displayName,
            compatibilityStatus: status,
            installable: installable,
            installBlockReason: installBlockReason,
            kind: kind,
            reasons: reasons,
            findings: findings,
            redscriptEntries: redscriptEntries.sorted(),
            archiveEntries: archiveEntries.sorted(),
            allEntries: allEntries.sorted()
        )
    }

    private func determineKind(redscriptEntries: [String], archiveEntries: [String], allEntries: [String]) -> ModKind {
        if !redscriptEntries.isEmpty && archiveEntries.isEmpty { return .redscript }
        if redscriptEntries.isEmpty && !archiveEntries.isEmpty { return .archive }
        if !redscriptEntries.isEmpty && !archiveEntries.isEmpty { return .mixed }
        return allEntries.isEmpty ? .unknown : .unknown
    }

    private func pathComponents(_ lowerPath: String) -> [String] {
        lowerPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func containsPathComponents(_ lowerPath: String, _ wanted: [String]) -> Bool {
        let components = pathComponents(lowerPath)
        guard !wanted.isEmpty, components.count >= wanted.count else { return false }
        for start in 0...(components.count - wanted.count) {
            if Array(components[start..<(start + wanted.count)]) == wanted {
                return true
            }
        }
        return false
    }

    private func isDocumentationOrMetadata(_ lowerPath: String) -> Bool {
        let allowedSuffixes = [
            ".txt", ".md", ".rtf", ".pdf", ".png", ".jpg", ".jpeg", ".webp",
            ".json", ".ini", ".url", ".webloc", ".nfo", ".xml"
        ]
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        if fileName == "manifest.json" || fileName == "readme" || fileName == "license" { return true }
        return allowedSuffixes.contains { lowerPath.hasSuffix($0) }
    }
}
