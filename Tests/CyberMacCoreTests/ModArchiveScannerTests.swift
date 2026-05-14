import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class ModArchiveScannerTests: XCTestCase {
    private var tempDir: URL!
    private let scanner = ModArchiveScanner()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testModKindDecodesLegacyArchiveAsArchiveOnly() throws {
        let decoded = try JSONDecoder().decode(ModKind.self, from: Data(#""archive""#.utf8))

        XCTAssertEqual(decoded, .archiveOnly)
    }

    func testModKindEncodesArchiveOnlyUsingNewCaseName() throws {
        let encoded = try JSONEncoder().encode(ModKind.archiveOnly)

        XCTAssertEqual(String(data: encoded, encoding: .utf8), #""archiveOnly""#)
    }

    func testRedscriptOnlyArchiveIsSupportedAndSidecarInstallable() throws {
        let zipURL = try makeZip(named: "redscript-only.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("README.md")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .supported)
        XCTAssertTrue(result.sidecarInstallable)
        XCTAssertNil(result.installBlockReason)
        XCTAssertEqual(result.kind, .redscript)
        XCTAssertEqual(result.redscriptEntries, ["r6/scripts/example/main.reds"])
        XCTAssertFalse(result.dependencyMarkers.hasArchiveFiles)
        XCTAssertTrue(result.dependencyMarkers.frameworkMarkerLabels.isEmpty)
    }

    func testRedscriptWithInputXmlIsSupportedWithInputPatch() throws {
        let zipURL = try makeZip(named: "InsaneCyberdeck-26690-2-1-1768948688.zip", entries: [
            .file("r6/scripts/InsaneCyberdeck.reds"),
            .file("r6/input/insanecyberdeck_input.xml", contents: "<bindings />"),
            .file("README.md")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .supported)
        XCTAssertTrue(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .redscriptInput)
        XCTAssertTrue(result.requiresInputMappingPatch)
        XCTAssertEqual(result.inputMappingEntries, ["r6/input/insanecyberdeck_input.xml"])
        XCTAssertTrue(result.dependencyMarkers.hasInputMappingXML)
    }

    func testGenericXmlIsNotTreatedAsHarmlessDocumentation() throws {
        let zipURL = try makeZip(named: "redscript-generic-xml.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("config/settings.xml", contents: "<settings />")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "config/settings.xml")
    }

    func testInputXmlWithoutRedscriptIsUntested() throws {
        let zipURL = try makeZip(named: "input-only.zip", entries: [
            .file("r6/input/insanecyberdeck_input.xml", contents: "<bindings />")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertFalse(result.requiresInputMappingPatch)
        XCTAssertEqual(result.inputMappingEntries, ["r6/input/insanecyberdeck_input.xml"])
    }

    func testScanDoesNotCarryLaunchWorkflowState() throws {
        let zipURL = try makeZip(named: "redscript-unverified.zip", entries: [
            .file("r6/scripts/example/main.reds")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .supported)
        XCTAssertTrue(result.sidecarInstallable)
        XCTAssertNil(result.installBlockReason)
    }

    func testCetSubstringInsideNormalWordsDoesNotFlagUnsupported() throws {
        let zipURL = try makeZip(named: "facet-concrete.zip", entries: [
            .file("r6/scripts/facet/concrete_accept_secret_ricochet.reds")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .supported)
        XCTAssertTrue(result.sidecarInstallable)
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testLuaOutsideCyberEngineTweaksPathIsUntestedNotUnsupported() throws {
        let zipURL = try makeZip(named: "tooling-lua.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("author-tools/build.lua")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "author-tools/build.lua")
    }

    func testLuaUnderCyberEngineTweaksPathIsUnsupported() throws {
        let zipURL = try makeZip(named: "cet-lua.zip", entries: [
            .file("bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .unsupported)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua")
        XCTAssertTrue(result.dependencyMarkers.hasCET)
    }

    func testYamlOutsideTweaksPathIsUntestedNotUnsupported() throws {
        let zipURL = try makeZip(named: "config-yaml.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("config/settings.yaml")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "config/settings.yaml")
        XCTAssertFalse(result.dependencyMarkers.hasTweakXL)
    }

    func testYamlUnderTweaksPathIsUnsupported() throws {
        let zipURL = try makeZip(named: "tweakxl-yaml.zip", entries: [
            .file("r6/tweaks/example.yaml")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .unsupported)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "r6/tweaks/example.yaml")
        XCTAssertTrue(result.dependencyMarkers.hasTweakXL)
    }

    func testTweakFileIsUnsupportedTweakXL() throws {
        let zipURL = try makeZip(named: "tweakxl-tweak.zip", entries: [
            .file("r6/tweaks/example.tweak")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasTweakXL)
    }

    func testSymlinkEntriesAreSurfacedAsUntestedFindings() throws {
        let zipURL = try makeZip(named: "symlink.zip", entries: [
            .symlink("r6/scripts/link.reds", target: "../../game.reds")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "r6/scripts/link.reds")
        XCTAssertEqual(result.findings.first?.reason, "Symlink entries are not installed by CyberMac v0.1")
    }

    func testArchiveOnlyModIsUntested() throws {
        let zipURL = try makeZip(named: "archive-only.zip", entries: [
            .file("archive/pc/mod/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .archiveOnly)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveFiles)
        XCTAssertTrue(result.dependencyMarkers.hasArchivePCModPath)
    }

    func testArchiveMacModPathIsDetectedAsArchiveOnly() throws {
        let zipURL = try makeZip(named: "archive-mac.zip", entries: [
            .file("archive/Mac/mod/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .archiveOnly)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveFiles)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveMacModPath)
    }

    func testArchivePCContentPathIsDetectedAsArchiveOnly() throws {
        let zipURL = try makeZip(named: "archive-pc-content.zip", entries: [
            .file("archive/pc/content/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .archiveOnly)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveFiles)
        XCTAssertTrue(result.dependencyMarkers.hasArchivePCContentPath)
    }

    func testArchiveMacContentPathIsDetectedAsArchiveOnly() throws {
        let zipURL = try makeZip(named: "archive-mac-content.zip", entries: [
            .file("archive/Mac/content/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .archiveOnly)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveFiles)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveMacContentPath)
    }

    func testArchiveXLManifestFileIsUnsupportedFrameworkStack() throws {
        let zipURL = try makeZip(named: "archivexl-manifest.zip", entries: [
            .file("r6/archives/example.archive.xl")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasArchiveXL)
    }

    func testXLFileIsUnsupportedArchiveXL() throws {
        let zipURL = try makeZip(named: "archivexl-xl.zip", entries: [
            .file("r6/archives/example.xl")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasArchiveXL)
    }

    func testArchiveXLSubstringMarkersAreUnsupportedFrameworkStack() throws {
        for markerPath in ["docs/archive-xl-readme.txt", "docs/archivexl-readme.txt"] {
            let zipURL = try makeZip(named: "\(UUID().uuidString).zip", entries: [
                .file(markerPath)
            ])

            let result = try scanner.scan(zipURL: zipURL)

            assertUnsupportedFramework(result, marker: \.hasArchiveXL)
        }
    }

    func testRED4extPluginPathIsUnsupported() throws {
        let zipURL = try makeZip(named: "red4ext-plugin.zip", entries: [
            .file("red4ext/plugins/example/plugin.dll")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasRED4ext)
        XCTAssertTrue(result.dependencyMarkers.hasNativePlugin)
    }

    func testCodewareMarkerIsUnsupported() throws {
        let zipURL = try makeZip(named: "codeware-marker.zip", entries: [
            .file("docs/codeware-readme.txt")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasCodeware)
    }

    func testTweakXLSubstringMarkersAreUnsupportedFrameworkStack() throws {
        for markerPath in ["docs/tweak-xl-readme.txt", "docs/tweakxl-readme.txt"] {
            let zipURL = try makeZip(named: "\(UUID().uuidString).zip", entries: [
                .file(markerPath)
            ])

            let result = try scanner.scan(zipURL: zipURL)

            assertUnsupportedFramework(result, marker: \.hasTweakXL)
        }
    }

    func testEquipmentEXMarkerIsUnsupported() throws {
        let zipURL = try makeZip(named: "equipment-ex-marker.zip", entries: [
            .file("docs/equipment_ex_notes.txt")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasEquipmentEX)
    }

    func testCETPathIsUnsupported() throws {
        let zipURL = try makeZip(named: "cet-path.zip", entries: [
            .file("bin/x64/plugins/cyber_engine_tweaks/mods/example/init.lua")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasCET)
    }

    func testStandaloneREDmodMetadataFilesAreNotUnsupported() throws {
        for metadataPath in ["metadata.json", "info.json"] {
            let zipURL = try makeZip(named: "\(UUID().uuidString).zip", entries: [
                .file(metadataPath, contents: "{}")
            ])

            let result = try scanner.scan(zipURL: zipURL)

            XCTAssertEqual(result.compatibilityStatus, .untested)
            XCTAssertFalse(result.sidecarInstallable)
            XCTAssertEqual(result.kind, .unknown)
            XCTAssertFalse(result.dependencyMarkers.hasREDmod)
            XCTAssertTrue(result.dependencyMarkers.frameworkMarkerLabels.isEmpty)
        }
    }

    func testNestedNonRootModsPathIsNotREDmod() throws {
        let zipURL = try makeZip(named: "nested-docs-mods.zip", entries: [
            .file("docs/mods/example/readme.txt")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .unknown)
        XCTAssertFalse(result.dependencyMarkers.hasREDmod)
        XCTAssertTrue(result.dependencyMarkers.frameworkMarkerLabels.isEmpty)
    }

    func testREDmodLikePackageIsUnsupported() throws {
        let zipURL = try makeZip(named: "redmod-like.zip", entries: [
            .file("mods/example/info.json"),
            .file("mods/example/archives/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasREDmod)
    }

    func testNativePluginExtensionsAreUnsupported() throws {
        let zipURL = try makeZip(named: "native-plugins.zip", entries: [
            .file("bin/x64/plugins/example.dll"),
            .file("bin/x64/plugins/example.asi"),
            .file("tools/setup.exe"),
            .file("native/example.dylib")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasNativePlugin)
    }

    func testSOFileIsUnsupportedNativePlugin() throws {
        let zipURL = try makeZip(named: "native-so.zip", entries: [
            .file("native/example.so")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        assertUnsupportedFramework(result, marker: \.hasNativePlugin)
        XCTAssertEqual(result.findings.first?.path, "native/example.so")
    }

    func testMixedRedscriptAndArchiveIsConservativeAndNotInstallable() throws {
        let zipURL = try makeZip(named: "mixed-redscript-archive.zip", entries: [
            .file("r6/scripts/example/main.reds"),
            .file("archive/pc/mod/example.archive")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .untested)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.kind, .mixed)
        XCTAssertTrue(result.dependencyMarkers.hasArchiveFiles)
    }

    private func assertUnsupportedFramework(
        _ result: ModScanResult,
        marker: KeyPath<ModDependencyMarkers, Bool>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.compatibilityStatus, .unsupported, file: file, line: line)
        XCTAssertFalse(result.sidecarInstallable, file: file, line: line)
        XCTAssertEqual(result.kind, .frameworkStack, file: file, line: line)
        XCTAssertTrue(result.dependencyMarkers[keyPath: marker], file: file, line: line)
    }

    private enum ZipEntry {
        case file(String, contents: String = "content")
        case symlink(String, target: String)
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
            case .symlink(let path, let target):
                let data = Data(target.utf8)
                try archive.addEntry(with: path, type: .symlink, uncompressedSize: Int64(data.count)) { position, size in
                    let start = Int(position)
                    let end = min(start + size, data.count)
                    return data.subdata(in: start..<end)
                }
            }
        }

        return zipURL
    }
}
