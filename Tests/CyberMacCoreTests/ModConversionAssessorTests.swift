import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class ModConversionAssessorTests: XCTestCase {
    private var tempDir: URL!
    private let assessor = ModConversionAssessor()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacModConversionAssessorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testArchiveOnlyBecomesLegacyReplacerResearchCandidateWithLooseLoadingBlockedWarning() throws {
        let zipURL = try makeZip(named: "jacket-replacer.zip", entries: [
            .file("archive/pc/mod/jacket.archive")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .clothing)
        let formatted = ModConversionAssessmentFormatter.format(assessment)

        XCTAssertEqual(assessment.conversionClass, .legacyArchiveOnlyReplacerCandidate)
        XCTAssertEqual(assessment.feasibility, .possibleAsVanillaReplacementResearch)
        XCTAssertTrue(formatted.contains("loose archive loading is blocked"))
        XCTAssertTrue(formatted.contains("Loose archive install is blocked by current probe results."))
        XCTAssertTrue(formatted.contains("dotnet tool install -g WolvenKit.CLI"))
        XCTAssertTrue(formatted.contains("CyberMac did not execute these commands"))
    }

    func testArchiveXLClothingLayoutIsFrameworkBlockedButAssetExtractionCandidate() throws {
        let zipURL = try makeZip(named: "archivexl-clothing.zip", entries: [
            .file("archive/pc/mod/neon_jacket.archive"),
            .file("r6/archives/neon_jacket.archive.xl"),
            .file("README.md")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .clothing)
        let formatted = ModConversionAssessmentFormatter.format(assessment)

        XCTAssertEqual(assessment.conversionClass, .archiveXLAddonClothing)
        XCTAssertEqual(assessment.feasibility, .blockedByFrameworkRuntime)
        XCTAssertTrue(formatted.contains("Asset extraction may still be worth researching"))
        XCTAssertTrue(formatted.contains("add-on item behavior will be lost"))
        XCTAssertEqual(paths(in: assessment, category: .archiveFiles), ["archive/pc/mod/neon_jacket.archive"])
        XCTAssertEqual(paths(in: assessment, category: .archiveXLFiles), ["r6/archives/neon_jacket.archive.xl"])
    }

    func testTweakXLYamlAndTweakPackageBecomesTweakXLDataMod() throws {
        let zipURL = try makeZip(named: "tweakxl-data.zip", entries: [
            .file("r6/tweaks/skin.yaml"),
            .file("r6/tweaks/colors.tweak")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .skin)
        let formatted = ModConversionAssessmentFormatter.format(assessment)

        XCTAssertEqual(assessment.conversionClass, .tweakXLDataMod)
        XCTAssertEqual(assessment.feasibility, .possibleAsOfflineDataPatchResearch)
        XCTAssertTrue(formatted.contains("offline TweakDB patch research"))
        XCTAssertEqual(paths(in: assessment, category: .yamlFiles), ["r6/tweaks/skin.yaml"])
        XCTAssertEqual(paths(in: assessment, category: .tweakFiles), ["r6/tweaks/colors.tweak"])
    }

    func testEquipmentEXOrCodewarePackageBecomesDependentClass() throws {
        let zipURL = try makeZip(named: "equipment-codeware.zip", entries: [
            .file("docs/equipment_ex_notes.txt"),
            .file("docs/codeware-readme.txt")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .clothing)

        XCTAssertEqual(assessment.conversionClass, .equipmentEXOrCodewareDependent)
        XCTAssertEqual(assessment.feasibility, .blockedByFrameworkRuntime)
        XCTAssertTrue(assessment.package.frameworkMarkers.contains("Equipment-EX"))
        XCTAssertTrue(assessment.package.frameworkMarkers.contains("Codeware"))
    }

    func testCETNativePluginPackageBecomesNativePluginOrCETDependent() throws {
        let zipURL = try makeZip(named: "cet-native.zip", entries: [
            .file("bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua"),
            .file("bin/x64/plugins/example.dll")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .ui)

        XCTAssertEqual(assessment.conversionClass, .nativePluginOrCETDependent)
        XCTAssertEqual(assessment.feasibility, .blockedByFrameworkRuntime)
        XCTAssertTrue(assessment.package.frameworkMarkers.contains("CET"))
        XCTAssertTrue(assessment.package.frameworkMarkers.contains("native plugin"))
        XCTAssertEqual(Set(paths(in: assessment, category: .nativePluginCETFiles)), [
            "bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua",
            "bin/x64/plugins/example.dll"
        ])
    }

    func testMixedArchiveAndRedscriptRequiresManualReview() throws {
        let zipURL = try makeZip(named: "mixed.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("archive/pc/mod/example.archive")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .unknown)

        XCTAssertEqual(assessment.conversionClass, .mixedManualReview)
        XCTAssertEqual(assessment.feasibility, .manualReviewRequired)
    }

    func testPureRedscriptRemainsSupported() throws {
        let zipURL = try makeZip(named: "redscript.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("README.md")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .ui)
        let formatted = ModConversionAssessmentFormatter.format(assessment)

        XCTAssertEqual(assessment.conversionClass, .pureRedscriptSupported)
        XCTAssertEqual(assessment.feasibility, .feasibleAsCurrentRedscript)
        XCTAssertTrue(assessment.package.sidecarInstallable)
        XCTAssertTrue(formatted.contains("Pure redscript remains supported"))
        XCTAssertTrue(formatted.contains("Loose archive install is blocked by current probe results."))
    }

    func testFormatterIncludesManualWolvenKitCommandsButDoesNotExecuteThem() throws {
        let zipURL = try makeZip(named: "manual-commands.zip", entries: [
            .file("archive/pc/mod/skin.archive")
        ])

        let assessment = try assessor.assess(zipURL: zipURL, goal: .skin)
        let formatted = ModConversionAssessmentFormatter.format(assessment)

        XCTAssertTrue(assessment.suggestedManualCommands.contains("dotnet tool install -g WolvenKit.CLI"))
        XCTAssertTrue(assessment.suggestedManualCommands.contains("wolvenkit.cli unbundle -p \"<archive-file>\" -o \"<output-folder>\""))
        XCTAssertTrue(formatted.contains("Manual research commands only; CyberMac did not execute these commands."))
    }

    func testAssessmentDoesNotWriteToFakeGameApp() throws {
        let fakeGameApp = tempDir.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: fakeGameApp.appendingPathComponent("Contents/Data/archive/Mac/content", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "fixture".write(
            to: fakeGameApp.appendingPathComponent("Contents/Data/archive/Mac/content/basegame.archive"),
            atomically: true,
            encoding: .utf8
        )
        let before = try recursiveRelativePaths(under: fakeGameApp)
        let zipURL = try makeZip(named: "read-only.zip", entries: [
            .file("archive/pc/mod/replacer.archive")
        ])

        _ = try assessor.assess(zipURL: zipURL, goal: .clothing)
        let after = try recursiveRelativePaths(under: fakeGameApp)

        XCTAssertEqual(after, before)
    }

    private func paths(in assessment: ModConversionAssessment, category: ModConversionFileCategory) -> [String] {
        assessment.fileGroups.first { $0.category == category }?.paths ?? []
    }

    private enum ZipEntry {
        case file(String, contents: String = "content")
    }

    private func makeZip(named name: String, entries: [ZipEntry]) throws -> URL {
        let zipURL = tempDir.appendingPathComponent(name)
        let archive = try Archive(url: zipURL, accessMode: .create)

        for entry in entries {
            switch entry {
            case .file(let path, let contents):
                let data = Data(contents.utf8)
                try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                    let start = Int(position)
                    let end = min(start + size, data.count)
                    return data.subdata(in: start..<end)
                }
            }
        }

        return zipURL
    }

    private func recursiveRelativePaths(under root: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: []
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return try PathSafety.relativePath(of: url, in: root)
        }
        .sorted()
    }
}
