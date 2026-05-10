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
    }

    func testYamlUnderTweaksPathIsUnsupported() throws {
        let zipURL = try makeZip(named: "tweakxl-yaml.zip", entries: [
            .file("r6/tweaks/example.yaml")
        ])

        let result = try scanner.scan(zipURL: zipURL)

        XCTAssertEqual(result.compatibilityStatus, .unsupported)
        XCTAssertFalse(result.sidecarInstallable)
        XCTAssertEqual(result.findings.first?.path, "r6/tweaks/example.yaml")
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
        XCTAssertEqual(result.kind, .archive)
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
