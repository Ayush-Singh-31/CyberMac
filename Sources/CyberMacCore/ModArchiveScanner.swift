import Foundation
import ZIPFoundation

public struct ModArchiveScanner: Sendable {
    public init() {}

    public func scan(zipURL: URL) throws -> ModScanResult {
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
        var inputMappingEntries: [String] = []
        var unsupportedFindings: [ModScanFinding] = []
        var untestedFindings: [ModScanFinding] = []
        var dependencyMarkers = ModDependencyMarkers()
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
            updatePathMarkers(
                lowerPath: lower,
                originalPath: path,
                markers: &dependencyMarkers,
                unsupportedFindings: &unsupportedFindings
            )

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

            if isInputMappingXML(lower) {
                inputMappingEntries.append(path)
                dependencyMarkers.hasInputMappingXML = true
                continue
            }

            if lower.hasSuffix(".archive") {
                dependencyMarkers.hasArchiveFiles = true
                archiveEntries.append(path)
                untestedFindings.append(ModScanFinding(path: path, reason: "Archive asset file detected; archive installation is scan-only in Phase A"))
                continue
            }

            if lower.hasSuffix(".archive.xl") || lower.hasSuffix(".xl") {
                dependencyMarkers.hasArchiveXL = true
                unsupportedFindings.append(ModScanFinding(path: path, reason: "ArchiveXL .xl file detected"))
                continue
            }

            if lower.hasSuffix(".tweak") {
                dependencyMarkers.hasTweakXL = true
                unsupportedFindings.append(ModScanFinding(path: path, reason: "TweakXL .tweak file detected"))
                continue
            }

            if isNativePluginFile(lower) {
                dependencyMarkers.hasNativePlugin = true
                unsupportedFindings.append(ModScanFinding(path: path, reason: "Native or Windows plugin binary detected"))
                continue
            }

            if lower.hasSuffix(".lua") {
                if isCETPath(lower) {
                    dependencyMarkers.hasCET = true
                    unsupportedFindings.append(ModScanFinding(path: path, reason: "Cyber Engine Tweaks Lua script detected"))
                } else {
                    untestedFindings.append(ModScanFinding(path: path, reason: "Lua script outside a known CET path"))
                }
                continue
            }

            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
                if containsPathComponents(lower, ["r6", "tweaks"]) {
                    dependencyMarkers.hasTweakXL = true
                    unsupportedFindings.append(ModScanFinding(path: path, reason: "TweakXL r6/tweaks file detected"))
                } else {
                    untestedFindings.append(ModScanFinding(path: path, reason: "YAML file outside a known TweakXL path"))
                }
                continue
            }

            if isDocumentationOrMetadata(lower) {
                continue
            }

            untestedFindings.append(ModScanFinding(path: path, reason: "Unknown file type or layout"))
        }

        let displayName = zipURL.deletingPathExtension().lastPathComponent
        let kind = determineKind(
            redscriptEntries: redscriptEntries,
            inputMappingEntries: inputMappingEntries,
            markers: dependencyMarkers,
            allEntries: allEntries
        )
        let status: CompatibilityStatus
        let sidecarInstallable: Bool
        let installBlockReason: String?
        let requiresInputMappingPatch: Bool
        var reasons: [String] = []
        var findings: [ModScanFinding] = []

        if hasUnsupportedMarkers(dependencyMarkers) {
            status = .unsupported
            sidecarInstallable = false
            installBlockReason = "Unsupported framework, native plugin, or REDmod marker detected"
            requiresInputMappingPatch = false
            reasons.append("Unsupported framework mod. Detected \(unsupportedMarkerLabels(dependencyMarkers).joined(separator: ", ")).")
            reasons.append("CyberMac currently supports redscript and input XML patching only.")
            findings = unsupportedFindings + untestedFindings
        } else if !redscriptEntries.isEmpty && !inputMappingEntries.isEmpty && !hasArchiveMarkers(dependencyMarkers) && untestedFindings.isEmpty {
            status = .supported
            sidecarInstallable = true
            installBlockReason = nil
            requiresInputMappingPatch = true
            reasons.append("Found redscript files plus Cyberpunk input mapping XML")
            reasons.append("Input config patch is required before keybinds will work")
            reasons.append("No CET, RED4ext, ArchiveXL, TweakXL, Codeware, Equipment-EX, REDmod, native plugin, or symlink markers detected")
            findings = []
        } else if !redscriptEntries.isEmpty && inputMappingEntries.isEmpty && !hasArchiveMarkers(dependencyMarkers) && untestedFindings.isEmpty {
            status = .supported
            sidecarInstallable = true
            installBlockReason = nil
            requiresInputMappingPatch = false
            reasons.append("Found redscript-only files plus normal documentation or metadata")
            reasons.append("No CET, RED4ext, ArchiveXL, TweakXL, Codeware, Equipment-EX, REDmod, native plugin, or symlink markers detected")
            findings = []
        } else if kind == .archiveOnly {
            status = .untested
            sidecarInstallable = false
            installBlockReason = "Archive-only asset mods are scan-only in Phase A"
            requiresInputMappingPatch = false
            reasons.append("Archive-only asset mod detected")
            reasons.append("CyberMac can identify this package, but archive installation is not enabled until a Mac archive load-path probe succeeds.")
            findings = untestedFindings
        } else if kind == .mixed {
            status = .untested
            sidecarInstallable = false
            installBlockReason = "Mixed redscript/archive packages are not partially installed in Phase A"
            requiresInputMappingPatch = false
            reasons.append("Mixed redscript/archive package detected")
            reasons.append("CyberMac will not partially install mixed archive packages in Phase A.")
            findings = untestedFindings
        } else {
            status = .untested
            sidecarInstallable = false
            installBlockReason = "CyberMac v0.1 does not have a safe install rule for this archive layout"
            requiresInputMappingPatch = false
            reasons.append("CyberMac v0.1 does not have a safe install rule for this archive layout")
            findings = untestedFindings
        }

        return ModScanResult(
            archiveURL: zipURL,
            displayName: displayName,
            compatibilityStatus: status,
            sidecarInstallable: sidecarInstallable,
            installBlockReason: installBlockReason,
            kind: kind,
            reasons: reasons,
            findings: findings,
            redscriptEntries: redscriptEntries.sorted(),
            archiveEntries: archiveEntries.sorted(),
            inputMappingEntries: inputMappingEntries.sorted(),
            dependencyMarkers: dependencyMarkers,
            requiresInputMappingPatch: requiresInputMappingPatch,
            allEntries: allEntries.sorted()
        )
    }

    private func determineKind(redscriptEntries: [String], inputMappingEntries: [String], markers: ModDependencyMarkers, allEntries: [String]) -> ModKind {
        if hasUnsupportedMarkers(markers) { return .frameworkStack }
        if !redscriptEntries.isEmpty && !inputMappingEntries.isEmpty && !hasArchiveMarkers(markers) { return .redscriptInput }
        if !redscriptEntries.isEmpty && !hasArchiveMarkers(markers) { return .redscript }
        if !redscriptEntries.isEmpty && hasArchiveMarkers(markers) { return .mixed }
        if redscriptEntries.isEmpty && hasArchiveMarkers(markers) { return .archiveOnly }
        return allEntries.isEmpty ? .unknown : .unknown
    }

    private func updatePathMarkers(
        lowerPath: String,
        originalPath: String,
        markers: inout ModDependencyMarkers,
        unsupportedFindings: inout [ModScanFinding]
    ) {
        if containsPathComponents(lowerPath, ["archive", "pc", "mod"]) {
            markers.hasArchivePCModPath = true
        }
        if containsPathComponents(lowerPath, ["archive", "pc", "content"]) {
            markers.hasArchivePCContentPath = true
        }
        if containsPathComponents(lowerPath, ["archive", "mac", "mod"]) {
            markers.hasArchiveMacModPath = true
        }
        if containsPathComponents(lowerPath, ["archive", "mac", "content"]) {
            markers.hasArchiveMacContentPath = true
        }
        if lowerPath.contains("archivexl") || lowerPath.contains("archive-xl") {
            markers.hasArchiveXL = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "ArchiveXL marker detected"))
        }
        if lowerPath.contains("tweakxl") || lowerPath.contains("tweak-xl") || containsPathComponents(lowerPath, ["r6", "tweaks"]) {
            markers.hasTweakXL = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "TweakXL marker detected"))
        }
        if lowerPath.contains("red4ext") {
            markers.hasRED4ext = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "RED4ext marker detected"))
        }
        if containsPathComponents(lowerPath, ["red4ext", "plugins"]) {
            markers.hasNativePlugin = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "RED4ext native plugin path detected"))
        }
        if lowerPath.contains("codeware") {
            markers.hasCodeware = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "Codeware marker detected"))
        }
        if lowerPath.contains("equipment-ex") || lowerPath.contains("equipmentex") || lowerPath.contains("equipment_ex") {
            markers.hasEquipmentEX = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "Equipment-EX marker detected"))
        }
        if isCETPath(lowerPath) {
            markers.hasCET = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "Cyber Engine Tweaks marker detected"))
        }
        if containsPathComponents(lowerPath, ["bin", "x64", "plugins"]) {
            markers.hasNativePlugin = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "bin/x64 plugin marker detected"))
        }
        if isREDmodPath(lowerPath) {
            markers.hasREDmod = true
            unsupportedFindings.append(ModScanFinding(path: originalPath, reason: "REDmod package marker detected"))
        }
    }

    private func hasArchiveMarkers(_ markers: ModDependencyMarkers) -> Bool {
        markers.hasArchiveFiles ||
            markers.hasArchivePCModPath ||
            markers.hasArchivePCContentPath ||
            markers.hasArchiveMacModPath ||
            markers.hasArchiveMacContentPath
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

    private func unsupportedMarkerLabels(_ markers: ModDependencyMarkers) -> [String] {
        var labels: [String] = []
        if markers.hasArchiveXL { labels.append("ArchiveXL") }
        if markers.hasTweakXL { labels.append("TweakXL") }
        if markers.hasRED4ext { labels.append("RED4ext") }
        if markers.hasCodeware { labels.append("Codeware") }
        if markers.hasCET { labels.append("CET") }
        if markers.hasEquipmentEX { labels.append("Equipment-EX") }
        if markers.hasREDmod { labels.append("REDmod") }
        if markers.hasNativePlugin { labels.append("native plugin") }
        return labels
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

    private func isCETPath(_ lowerPath: String) -> Bool {
        lowerPath.contains("cyber_engine_tweaks") || pathComponents(lowerPath).contains("cet")
    }

    private func isREDmodPath(_ lowerPath: String) -> Bool {
        let components = pathComponents(lowerPath)
        if components.first == "mods" { return true }
        if containsPathComponents(lowerPath, ["r6", "config", "redsuserhints"]) { return true }
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        return (fileName == "info.json" || fileName == "metadata.json") && components.first == "mods"
    }

    private func isNativePluginFile(_ lowerPath: String) -> Bool {
        [".dll", ".asi", ".exe", ".dylib", ".so"].contains { lowerPath.hasSuffix($0) }
    }

    private func isInputMappingXML(_ lowerPath: String) -> Bool {
        if containsPathComponents(lowerPath, ["r6", "input"]) && lowerPath.hasSuffix(".xml") {
            return true
        }
        if lowerPath.hasSuffix("_input.xml") {
            return true
        }
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        if fileName == "inputcontexts.xml" || fileName == "inputcontexts_mac.xml" || fileName == "inputusermappings.xml" {
            return true
        }
        return false
    }

    private func isDocumentationOrMetadata(_ lowerPath: String) -> Bool {
        let allowedSuffixes = [
            ".txt", ".md", ".rtf", ".pdf", ".png", ".jpg", ".jpeg", ".webp",
            ".json", ".ini", ".url", ".webloc", ".nfo"
        ]
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        if fileName == "manifest.json" || fileName == "readme" || fileName == "license" { return true }
        return allowedSuffixes.contains { lowerPath.hasSuffix($0) }
    }
}
