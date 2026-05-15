import Foundation

public enum ModConversionGoal: String, Codable, Sendable, Equatable, CaseIterable {
    case clothing
    case skin
    case ui
    case unknown

    public static var acceptedValuesDescription: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

public enum ModConversionClass: String, Codable, Sendable, Equatable {
    case pureRedscriptSupported
    case legacyArchiveOnlyReplacerCandidate
    case archiveOnlyButLooseLoadingBlocked
    case archiveXLAddonClothing
    case tweakXLDataMod
    case equipmentEXOrCodewareDependent
    case redmodPackage
    case nativePluginOrCETDependent
    case mixedManualReview
    case notConvertibleWithoutFrameworks
    case unknown
}

public enum ModConversionFeasibility: String, Codable, Sendable, Equatable {
    case feasibleAsCurrentRedscript
    case possibleAsVanillaReplacementResearch
    case possibleAsOfflineDataPatchResearch
    case blockedByFrameworkRuntime
    case blockedByUnknownFormat
    case manualReviewRequired
}

public enum ModConversionFileCategory: String, Codable, Sendable, Equatable, CaseIterable {
    case archiveFiles = ".archive files"
    case archiveXLFiles = ".xl / .archive.xl files"
    case yamlFiles = ".yaml / .yml"
    case tweakFiles = ".tweak"
    case redscriptFiles = ".reds"
    case inputXMLFiles = "r6/input XML"
    case nativePluginCETFiles = "RED4ext/native plugin/CET files"
    case documentationImages = "documentation/images"
    case unknownFiles = "unknown files"
}

public struct ModConversionFileGroup: Sendable, Equatable {
    public let category: ModConversionFileCategory
    public let paths: [String]

    public init(category: ModConversionFileCategory, paths: [String]) {
        self.category = category
        self.paths = paths
    }
}

public struct ModConversionPackageSummary: Sendable, Equatable {
    public let zipPath: String
    public let displayName: String
    public let compatibility: CompatibilityStatus
    public let kind: ModKind
    public let sidecarInstallable: Bool
    public let archiveFileCount: Int
    public let redscriptFileCount: Int
    public let inputXMLCount: Int
    public let frameworkMarkers: [String]
    public let archiveLayoutMarkers: [String]

    public init(
        zipPath: String,
        displayName: String,
        compatibility: CompatibilityStatus,
        kind: ModKind,
        sidecarInstallable: Bool,
        archiveFileCount: Int,
        redscriptFileCount: Int,
        inputXMLCount: Int,
        frameworkMarkers: [String],
        archiveLayoutMarkers: [String]
    ) {
        self.zipPath = zipPath
        self.displayName = displayName
        self.compatibility = compatibility
        self.kind = kind
        self.sidecarInstallable = sidecarInstallable
        self.archiveFileCount = archiveFileCount
        self.redscriptFileCount = redscriptFileCount
        self.inputXMLCount = inputXMLCount
        self.frameworkMarkers = frameworkMarkers
        self.archiveLayoutMarkers = archiveLayoutMarkers
    }
}

public struct ModConversionAssessment: Sendable {
    public let goal: ModConversionGoal
    public let package: ModConversionPackageSummary
    public let fileGroups: [ModConversionFileGroup]
    public let conversionClass: ModConversionClass
    public let feasibility: ModConversionFeasibility
    public let interpretationLines: [String]
    public let feasibilityLines: [String]
    public let suggestedManualCommands: [String]
    public let suggestedCommandNotes: [String]
    public let phaseCWarningLines: [String]
    public let scannerReasons: [String]
    public let scannerFindings: [ModScanFinding]

    public init(
        goal: ModConversionGoal,
        package: ModConversionPackageSummary,
        fileGroups: [ModConversionFileGroup],
        conversionClass: ModConversionClass,
        feasibility: ModConversionFeasibility,
        interpretationLines: [String],
        feasibilityLines: [String],
        suggestedManualCommands: [String],
        suggestedCommandNotes: [String],
        phaseCWarningLines: [String],
        scannerReasons: [String],
        scannerFindings: [ModScanFinding]
    ) {
        self.goal = goal
        self.package = package
        self.fileGroups = fileGroups
        self.conversionClass = conversionClass
        self.feasibility = feasibility
        self.interpretationLines = interpretationLines
        self.feasibilityLines = feasibilityLines
        self.suggestedManualCommands = suggestedManualCommands
        self.suggestedCommandNotes = suggestedCommandNotes
        self.phaseCWarningLines = phaseCWarningLines
        self.scannerReasons = scannerReasons
        self.scannerFindings = scannerFindings
    }
}

public struct ModConversionAssessor: Sendable {
    private let scanner: ModArchiveScanner

    public init(scanner: ModArchiveScanner = ModArchiveScanner()) {
        self.scanner = scanner
    }

    public func assess(zipURL: URL, goal: ModConversionGoal = .unknown) throws -> ModConversionAssessment {
        let scan = try scanner.scan(zipURL: zipURL)
        let fileGroups = makeFileGroups(scan.allEntries)
        let classification = classify(scan: scan)
        let archiveLayoutMarkers = scan.dependencyMarkers.archiveMarkerLabels.filter { $0 != "input XML" }

        return ModConversionAssessment(
            goal: goal,
            package: ModConversionPackageSummary(
                zipPath: zipURL.path,
                displayName: scan.displayName,
                compatibility: scan.compatibilityStatus,
                kind: scan.kind,
                sidecarInstallable: scan.sidecarInstallable,
                archiveFileCount: scan.archiveEntries.count,
                redscriptFileCount: scan.redscriptEntries.count,
                inputXMLCount: scan.inputMappingEntries.count,
                frameworkMarkers: scan.dependencyMarkers.frameworkMarkerLabels,
                archiveLayoutMarkers: archiveLayoutMarkers
            ),
            fileGroups: fileGroups,
            conversionClass: classification.conversionClass,
            feasibility: classification.feasibility,
            interpretationLines: makeInterpretationLines(scan: scan, classification: classification),
            feasibilityLines: makeFeasibilityLines(scan: scan, classification: classification, goal: goal),
            suggestedManualCommands: makeSuggestedManualCommands(scan: scan),
            suggestedCommandNotes: makeSuggestedCommandNotes(scan: scan),
            phaseCWarningLines: [
                "Loose archive install is blocked by current probe results.",
                "Do not implement managed archive installer until a Mac-loaded patch path is proven."
            ],
            scannerReasons: scan.reasons,
            scannerFindings: scan.findings
        )
    }

    private func classify(scan: ModScanResult) -> Classification {
        let markers = scan.dependencyMarkers
        let hasFrameworkMarkers = !markers.frameworkMarkerLabels.isEmpty
        let hasArchiveMarkers = markers.hasArchiveFiles ||
            markers.hasArchivePCModPath ||
            markers.hasArchivePCContentPath ||
            markers.hasArchiveMacModPath ||
            markers.hasArchiveMacContentPath

        if !scan.redscriptEntries.isEmpty && (hasArchiveMarkers || hasFrameworkMarkers) {
            return Classification(conversionClass: .mixedManualReview, feasibility: .manualReviewRequired)
        }

        if (scan.kind == .redscript || scan.kind == .redscriptInput) && !hasArchiveMarkers && !hasFrameworkMarkers {
            return Classification(conversionClass: .pureRedscriptSupported, feasibility: .feasibleAsCurrentRedscript)
        }

        if markers.hasREDmod {
            return Classification(conversionClass: .redmodPackage, feasibility: .blockedByFrameworkRuntime)
        }

        if markers.hasArchiveXL {
            if containsArchiveXLManifest(scan.allEntries) {
                return Classification(conversionClass: .archiveXLAddonClothing, feasibility: .blockedByFrameworkRuntime)
            }
            return Classification(conversionClass: .notConvertibleWithoutFrameworks, feasibility: .blockedByFrameworkRuntime)
        }

        if markers.hasTweakXL {
            if containsTweakXLDataFile(scan.allEntries) {
                return Classification(conversionClass: .tweakXLDataMod, feasibility: .possibleAsOfflineDataPatchResearch)
            }
            return Classification(conversionClass: .notConvertibleWithoutFrameworks, feasibility: .blockedByFrameworkRuntime)
        }

        if markers.hasEquipmentEX || markers.hasCodeware {
            return Classification(conversionClass: .equipmentEXOrCodewareDependent, feasibility: .blockedByFrameworkRuntime)
        }

        if markers.hasCET || markers.hasNativePlugin || markers.hasRED4ext {
            return Classification(conversionClass: .nativePluginOrCETDependent, feasibility: .blockedByFrameworkRuntime)
        }

        if scan.kind == .archiveOnly && !scan.archiveEntries.isEmpty {
            return Classification(conversionClass: .legacyArchiveOnlyReplacerCandidate, feasibility: .possibleAsVanillaReplacementResearch)
        }

        if scan.kind == .archiveOnly {
            return Classification(conversionClass: .archiveOnlyButLooseLoadingBlocked, feasibility: .blockedByUnknownFormat)
        }

        if scan.kind == .mixed {
            return Classification(conversionClass: .mixedManualReview, feasibility: .manualReviewRequired)
        }

        return Classification(conversionClass: .unknown, feasibility: .blockedByUnknownFormat)
    }

    private func makeInterpretationLines(scan: ModScanResult, classification: Classification) -> [String] {
        switch classification.conversionClass {
        case .pureRedscriptSupported:
            return ["Pure redscript remains supported by CyberMac's current sidecar install path."]
        case .legacyArchiveOnlyReplacerCandidate:
            return [
                "This is a legacy archive-only replacer candidate, but loose archive loading is blocked by current probe results.",
                "It may be useful for future vanilla replacement research if assets can be mapped to Mac-loaded resources."
            ]
        case .archiveOnlyButLooseLoadingBlocked:
            return ["Archive layout markers were found, but CyberMac has no proven Mac loose archive loading path."]
        case .archiveXLAddonClothing:
            var lines = [
                "ArchiveXL markers imply add-on item registration and are not installable on native macOS without framework support.",
                "ArchiveXL add-on item behavior will be lost unless assets are converted into a vanilla replacement."
            ]
            if !scan.archiveEntries.isEmpty {
                lines.append("Asset extraction may still be worth researching because this package includes .archive files.")
            }
            return lines
        case .tweakXLDataMod:
            return [
                "TweakXL markers imply TweakDB/data changes and require framework support at runtime.",
                "This may inform future offline TweakDB patch research, but it is not currently installable."
            ]
        case .equipmentEXOrCodewareDependent:
            return ["Equipment-EX or Codeware markers make this package not convertible without framework/runtime support unless separable assets are identified manually."]
        case .redmodPackage:
            return ["REDmod package layout is not a CyberMac install target and requires separate conversion research."]
        case .nativePluginOrCETDependent:
            return ["CET, RED4ext, or native plugin markers require unsupported runtime/plugin support on native macOS."]
        case .mixedManualReview:
            return ["This package mixes redscript with archive or framework markers; CyberMac should not partially install it without manual review."]
        case .notConvertibleWithoutFrameworks:
            return ["Detected framework markers make this package not convertible without framework/runtime support."]
        case .unknown:
            return ["CyberMac does not recognize enough of this package layout to assess conversion safely."]
        }
    }

    private func makeFeasibilityLines(scan: ModScanResult, classification: Classification, goal: ModConversionGoal) -> [String] {
        switch classification.feasibility {
        case .feasibleAsCurrentRedscript:
            return ["Feasible with the current CyberMac redscript support. Goal context: \(goal.rawValue)."]
        case .possibleAsVanillaReplacementResearch:
            return [
                "Possible as vanilla replacement research only.",
                "Likely approach: extract assets from the mod archive, choose a vanilla garment/body/skin target, replace equivalent resource paths, then repack or patch a Mac-loaded archive.",
                "This would not preserve ArchiveXL add-on item behavior."
            ]
        case .possibleAsOfflineDataPatchResearch:
            return [
                "Possible as offline data patch research only.",
                "No runtime TweakXL support is assumed or provided by CyberMac."
            ]
        case .blockedByFrameworkRuntime:
            var lines = ["Blocked by missing framework/runtime support on native macOS."]
            if !scan.archiveEntries.isEmpty {
                lines.append("Manual asset extraction can still be investigated, but runtime item registration or scripts will not carry over automatically.")
            }
            return lines
        case .blockedByUnknownFormat:
            return ["Blocked because the package format or layout is unknown to CyberMac."]
        case .manualReviewRequired:
            return ["Manual review is required before any conversion research can be scoped safely."]
        }
    }

    private func makeSuggestedManualCommands(scan: ModScanResult) -> [String] {
        guard !scan.archiveEntries.isEmpty else {
            return []
        }

        return [
            "dotnet tool install -g WolvenKit.CLI",
            "wolvenkit.cli unbundle -p \"<archive-file>\" -o \"<output-folder>\""
        ]
    }

    private func makeSuggestedCommandNotes(scan: ModScanResult) -> [String] {
        if scan.archiveEntries.isEmpty {
            return ["No .archive files were detected, so no WolvenKit unbundle command is suggested."]
        }

        return [
            "Manual research commands only; CyberMac did not execute these commands.",
            "Replace <archive-file> with an extracted archive path from the downloaded package.",
            "Archive candidates inside this ZIP: \(scan.archiveEntries.joined(separator: ", "))"
        ]
    }

    private func makeFileGroups(_ paths: [String]) -> [ModConversionFileGroup] {
        var grouped: [ModConversionFileCategory: [String]] = [:]
        for path in paths where !path.hasSuffix("/") {
            grouped[categorize(path), default: []].append(path)
        }

        return ModConversionFileCategory.allCases.map { category in
            ModConversionFileGroup(category: category, paths: (grouped[category] ?? []).sorted())
        }
    }

    private func categorize(_ path: String) -> ModConversionFileCategory {
        let lower = path.lowercased()
        if lower.hasSuffix(".archive") {
            return .archiveFiles
        }
        if lower.hasSuffix(".archive.xl") || lower.hasSuffix(".xl") {
            return .archiveXLFiles
        }
        if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
            return .yamlFiles
        }
        if lower.hasSuffix(".tweak") {
            return .tweakFiles
        }
        if lower.hasSuffix(".reds") {
            return .redscriptFiles
        }
        if isInputMappingXML(lower) {
            return .inputXMLFiles
        }
        if isNativePluginCETOrRED4ext(lower) {
            return .nativePluginCETFiles
        }
        if isDocumentationImageOrMetadata(lower) {
            return .documentationImages
        }
        return .unknownFiles
    }

    private func containsArchiveXLManifest(_ paths: [String]) -> Bool {
        paths.map { $0.lowercased() }.contains { lower in
            lower.hasSuffix(".archive.xl") || lower.hasSuffix(".xl")
        }
    }

    private func containsTweakXLDataFile(_ paths: [String]) -> Bool {
        paths.map { $0.lowercased() }.contains { lower in
            lower.hasSuffix(".tweak") ||
                ((lower.hasSuffix(".yaml") || lower.hasSuffix(".yml")) && containsPathComponents(lower, ["r6", "tweaks"]))
        }
    }

    private func isInputMappingXML(_ lowerPath: String) -> Bool {
        if containsPathComponents(lowerPath, ["r6", "input"]) && lowerPath.hasSuffix(".xml") {
            return true
        }
        if lowerPath.hasSuffix("_input.xml") {
            return true
        }
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        return fileName == "inputcontexts.xml" ||
            fileName == "inputcontexts_mac.xml" ||
            fileName == "inputusermappings.xml"
    }

    private func isNativePluginCETOrRED4ext(_ lowerPath: String) -> Bool {
        if lowerPath.contains("cyber_engine_tweaks") || pathComponents(lowerPath).contains("cet") {
            return true
        }
        if lowerPath.contains("red4ext") || containsPathComponents(lowerPath, ["bin", "x64", "plugins"]) {
            return true
        }
        return [".dll", ".asi", ".exe", ".dylib", ".so"].contains { lowerPath.hasSuffix($0) }
    }

    private func isDocumentationImageOrMetadata(_ lowerPath: String) -> Bool {
        let allowedSuffixes = [
            ".txt", ".md", ".rtf", ".pdf", ".png", ".jpg", ".jpeg", ".webp",
            ".json", ".ini", ".url", ".webloc", ".nfo"
        ]
        let fileName = URL(fileURLWithPath: lowerPath).lastPathComponent
        if fileName == "readme" || fileName == "license" {
            return true
        }
        return allowedSuffixes.contains { lowerPath.hasSuffix($0) }
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
}

public enum ModConversionAssessmentFormatter {
    public static func format(_ assessment: ModConversionAssessment) -> String {
        var lines: [String] = []

        lines.append("Mod Conversion Lab assessment")
        lines.append("")
        lines.append("Package summary")
        lines.append("- Mod zip: \(PathSafety.redactUserPath(assessment.package.zipPath))")
        lines.append("- Display name: \(assessment.package.displayName)")
        lines.append("- Goal: \(assessment.goal.rawValue)")
        lines.append("- Scanner compatibility: \(assessment.package.compatibility.rawValue)")
        lines.append("- ModKind: \(assessment.package.kind.rawValue)")
        lines.append("- Sidecar installable: \(yesNo(assessment.package.sidecarInstallable))")
        lines.append("- Archive file count: \(assessment.package.archiveFileCount)")
        lines.append("- Redscript file count: \(assessment.package.redscriptFileCount)")
        lines.append("- Input XML count: \(assessment.package.inputXMLCount)")
        lines.append("- Dependency/framework markers: \(formatList(assessment.package.frameworkMarkers))")
        lines.append("- Archive/layout markers: \(formatList(assessment.package.archiveLayoutMarkers))")
        lines.append("")

        lines.append("File/layout inventory")
        for group in assessment.fileGroups {
            lines.append("\(group.category.rawValue):")
            if group.paths.isEmpty {
                lines.append("- none")
            } else {
                lines.append(contentsOf: group.paths.map { "- \($0)" })
            }
        }
        lines.append("")

        lines.append("Clothing/skin dependency interpretation")
        lines.append("- Conversion class: \(assessment.conversionClass.rawValue)")
        lines.append(contentsOf: assessment.interpretationLines.map { "- \($0)" })
        lines.append("")

        lines.append("Conversion feasibility")
        lines.append("- Feasibility: \(assessment.feasibility.rawValue)")
        lines.append(contentsOf: assessment.feasibilityLines.map { "- \($0)" })
        lines.append("")

        lines.append("Suggested next manual research commands")
        if assessment.suggestedManualCommands.isEmpty {
            lines.append("- none")
        } else {
            lines.append(contentsOf: assessment.suggestedManualCommands.map { "- \($0)" })
        }
        lines.append(contentsOf: assessment.suggestedCommandNotes.map { "- \($0)" })
        lines.append("")

        lines.append("Phase C warning")
        lines.append(contentsOf: assessment.phaseCWarningLines.map { "- \($0)" })

        if !assessment.scannerReasons.isEmpty || !assessment.scannerFindings.isEmpty {
            lines.append("")
            lines.append("Scanner notes")
            lines.append(contentsOf: assessment.scannerReasons.map { "- \($0)" })
            lines.append(contentsOf: assessment.scannerFindings.map { "- \($0.path): \($0.reason)" })
        }

        return lines.joined(separator: "\n")
    }

    private static func formatList(_ values: [String]) -> String {
        values.isEmpty ? "none" : values.joined(separator: ", ")
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private struct Classification {
    let conversionClass: ModConversionClass
    let feasibility: ModConversionFeasibility
}
