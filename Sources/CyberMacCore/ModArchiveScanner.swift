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
        var nonContentEntries: [String] = []

        for entry in archive {
            try PathSafety.validateArchivePath(entry.path)
            guard entry.type == .file else { continue }
            let path = entry.path
            let lower = path.lowercased()
            allEntries.append(path)

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
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Lua script detected, likely CET-dependent"))
                continue
            }

            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "YAML tweak file detected, likely TweakXL-dependent"))
                continue
            }

            if lower.contains("bin/x64") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "bin/x64 marker detected"))
                continue
            }

            if lower.contains("red4ext") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "RED4ext marker detected"))
                continue
            }

            if lower.contains("cyber_engine_tweaks") || lower.contains("cet") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Cyber Engine Tweaks marker detected"))
                continue
            }

            if lower.contains("archivexl") || lower.contains("archive-xl") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "ArchiveXL marker detected"))
                continue
            }

            if lower.contains("tweakxl") || lower.contains("tweak-xl") || lower.contains("r6/tweaks") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "TweakXL marker detected"))
                continue
            }

            if lower.contains("codeware") {
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Codeware marker detected"))
                continue
            }

            if isDocumentationOrMetadata(lower) {
                nonContentEntries.append(path)
                continue
            }

            untestedFindings.append(ModScanFinding(path: path, reason: "Unknown file type or layout"))
        }

        let displayName = zipURL.deletingPathExtension().lastPathComponent
        let kind = determineKind(redscriptEntries: redscriptEntries, archiveEntries: archiveEntries, allEntries: allEntries)
        let status: CompatibilityStatus
        var reasons: [String] = []
        var findings: [ModScanFinding] = []

        if !unsupportedFindings.isEmpty {
            status = .unsupported
            reasons.append("Known unsupported dependency or Windows modding marker detected")
            findings = unsupportedFindings + untestedFindings
        } else if !redscriptEntries.isEmpty && archiveEntries.isEmpty && untestedFindings.isEmpty {
            if launchWorkflowVerified {
                status = .supported
                reasons.append("Found only .reds script files plus normal documentation or metadata")
                reasons.append("No CET, RED4ext, ArchiveXL, TweakXL, Codeware, DLL, or ASI markers detected")
                reasons.append("Launch workflow is verified")
            } else {
                status = .untested
                reasons.append("Found redscript-only files, but the CyberMac redscript launch workflow is not verified yet")
            }
            findings = []
        } else if redscriptEntries.isEmpty && !archiveEntries.isEmpty && unsupportedFindings.isEmpty {
            status = .untested
            reasons.append("Archive-based mods are not installed by CyberMac v0.1")
            findings = untestedFindings
        } else {
            status = .untested
            reasons.append("CyberMac v0.1 does not have a safe install rule for this archive layout")
            findings = untestedFindings
        }

        return ModScanResult(
            archiveURL: zipURL,
            displayName: displayName,
            compatibilityStatus: status,
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
