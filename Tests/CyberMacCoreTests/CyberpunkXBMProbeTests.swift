import Foundation
import XCTest
@testable import CyberMacCore

final class CyberpunkXBMProbeTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacCyberpunkXBMProbeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRejectsMissingFile() {
        let missing = tempDir.appendingPathComponent("does-not-exist.xbm")
        XCTAssertThrowsError(try CyberpunkXBMProbe().probe(fileURL: missing)) { error in
            guard case CyberMacError.notFound = error else {
                XCTFail("Expected notFound, got \(error)")
                return
            }
        }
    }

    func testRejectsDirectoryPath() throws {
        let directory = tempDir.appendingPathComponent("a-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertThrowsError(try CyberpunkXBMProbe().probe(fileURL: directory)) { error in
            guard case CyberMacError.invalidInput = error else {
                XCTFail("Expected invalidInput, got \(error)")
                return
            }
        }
    }

    func testIdentifiesEmptyFile() throws {
        let url = tempDir.appendingPathComponent("empty.xbm")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .empty)
        XCTAssertFalse(result.isCyberpunkXBM)
        XCTAssertEqual(result.fileSize, 0)
        XCTAssertEqual(result.firstBytesHex, "")
        XCTAssertNil(result.cr2wHeader)
        XCTAssertTrue(result.discoveredMarkers.isEmpty)
        XCTAssertFalse(result.metadataDecoded)
    }

    func testIdentifiesX11XBMFixtureAsNotCyberpunk() throws {
        let url = try fixtureURL(named: "cyberpunk-xbm/sample-x11.xbm")
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .textXBM)
        XCTAssertFalse(result.isCyberpunkXBM)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertNil(result.cr2wHeader)
        XCTAssertTrue(result.notes.contains { $0.contains("X11") })
    }

    func testIdentifiesPlainTextAsNonXBM() throws {
        let url = tempDir.appendingPathComponent("notes.txt")
        try "hello world this is just text content".write(to: url, atomically: true, encoding: .utf8)
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .text)
        XCTAssertFalse(result.isCyberpunkXBM)
    }

    func testReadsFirstBytesFromBinaryFixture() throws {
        let url = tempDir.appendingPathComponent("blob.bin")
        let bytes: [UInt8] = (0..<128).map { UInt8($0 & 0xFF) }
        try Data(bytes).write(to: url)
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .unknownBinary)
        XCTAssertFalse(result.isCyberpunkXBM)
        XCTAssertEqual(result.fileSize, UInt64(bytes.count))
        // First 64 bytes hex, space-separated → 64 tokens
        let tokens = result.firstBytesHex.split(separator: " ")
        XCTAssertEqual(tokens.count, CyberpunkXBMProbe.firstBytesPreviewLength)
        XCTAssertEqual(tokens.first, "00")
        XCTAssertEqual(tokens.last, "3f")
    }

    func testDoesNotCrashOnTruncatedUnknownBinary() throws {
        let url = tempDir.appendingPathComponent("truncated.bin")
        try Data([0x00, 0x01, 0x02]).write(to: url)
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .unknownBinary)
        XCTAssertFalse(result.isCyberpunkXBM)
        XCTAssertNil(result.cr2wHeader)
    }

    func testDoesNotCrashOnTruncatedCR2W() throws {
        let url = tempDir.appendingPathComponent("truncated-cr2w.xbm")
        // Magic only, header parse should be defensive
        try Data(CyberpunkXBMProbe.cr2wMagicBytes).write(to: url)
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .cyberpunkXBM)
        XCTAssertTrue(result.isCyberpunkXBM)
        XCTAssertNotNil(result.cr2wHeader)
        XCTAssertTrue(result.cr2wHeader?.magicPresent ?? false)
        XCTAssertNil(result.cr2wHeader?.version)
        XCTAssertTrue(result.cr2wHeader?.tableEntries.isEmpty ?? false)
        XCTAssertFalse(result.metadataDecoded)
    }

    func testParsesSyntheticCR2WHeaderAndMarkers() throws {
        let url = tempDir.appendingPathComponent("synthetic-cr2w.xbm")
        try Self.makeSyntheticCR2WFixture().write(to: url)

        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        XCTAssertEqual(result.classification, .cyberpunkXBM)
        XCTAssertTrue(result.isCyberpunkXBM)
        let header = try XCTUnwrap(result.cr2wHeader)
        XCTAssertTrue(header.magicPresent)
        XCTAssertEqual(header.version, 195)
        XCTAssertEqual(header.flags, 0)
        XCTAssertEqual(header.buildVersion, 9000)
        XCTAssertEqual(header.fileSize, 0x1234)
        XCTAssertEqual(header.bufferSize, 0x100)
        XCTAssertEqual(header.numChunks, 1)
        XCTAssertEqual(header.tableEntries.count, 10)
        XCTAssertEqual(header.tableEntries[0].offset, 0xAA)
        XCTAssertEqual(header.tableEntries[0].count, 0xBB)
        XCTAssertEqual(header.tableEntries[0].crc32, 0xCC)
        XCTAssertTrue(result.discoveredMarkers.contains("CBitmapTexture"))
        XCTAssertTrue(result.discoveredMarkers.contains("ETextureRawFormat"))
        XCTAssertTrue(result.discoveredMarkers.contains("rendRenderTextureResource"))
        // Markers found, but values are not yet decoded.
        XCTAssertFalse(result.metadataDecoded)
        XCTAssertTrue(result.notes.contains { $0.contains("Metadata not decoded yet") })
    }

    func testFormatterProducesStableDiagnosticHeader() throws {
        let url = tempDir.appendingPathComponent("synthetic-cr2w.xbm")
        try Self.makeSyntheticCR2WFixture().write(to: url)

        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        let formatted = CyberpunkXBMProbeFormatter.format(result)
        XCTAssertTrue(formatted.hasPrefix("Cyberpunk XBM probe"))
        XCTAssertTrue(formatted.contains("Classification: cyberpunk-xbm"))
        XCTAssertTrue(formatted.contains("Is Cyberpunk XBM: yes"))
        XCTAssertTrue(formatted.contains("CR2W header:"))
        XCTAssertTrue(formatted.contains("Discovered markers:"))
        XCTAssertTrue(formatted.contains("Notes:"))
    }

    func testFormatterReportsAbsenceCleanlyForUnknownBinary() throws {
        let url = tempDir.appendingPathComponent("blob.bin")
        try Data([0x10, 0x20, 0x30, 0x40]).write(to: url)
        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        let formatted = CyberpunkXBMProbeFormatter.format(result)
        XCTAssertTrue(formatted.contains("Classification: unknown-binary"))
        XCTAssertTrue(formatted.contains("Is Cyberpunk XBM: no"))
        XCTAssertFalse(formatted.contains("CR2W header:"))
        XCTAssertFalse(formatted.contains("Discovered markers:"))
    }

    func testJSONOutputIsValidAndContainsKeyFields() throws {
        let url = tempDir.appendingPathComponent("synthetic-cr2w.xbm")
        try Self.makeSyntheticCR2WFixture().write(to: url)

        let result = try CyberpunkXBMProbe().probe(fileURL: url)
        let json = try CyberpunkXBMProbeFormatter.formatJSON(result)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let dict = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(dict["classification"] as? String, "cyberpunk-xbm")
        XCTAssertEqual(dict["isCyberpunkXBM"] as? Bool, true)
        XCTAssertNotNil(dict["cr2wHeader"])
        XCTAssertNotNil(dict["discoveredMarkers"])
        XCTAssertNotNil(dict["firstBytesHex"])
    }

    // MARK: - Helpers

    private func fixtureURL(named name: String) throws -> URL {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(name),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Tests/Fixtures")
                .appendingPathComponent(name)
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        throw CyberMacError.notFound("Test fixture missing: \(name)")
    }

    /// Builds a synthetic CR2W-shaped blob: magic + plausible header fields + 10 table entries
    /// + a payload containing well-known REDengine texture marker strings. This intentionally
    /// avoids real game data; it exists only to exercise our probe.
    private static func makeSyntheticCR2WFixture() -> Data {
        var data = Data()
        // 0x00 magic "CR2W"
        data.append(contentsOf: CyberpunkXBMProbe.cr2wMagicBytes)
        // 0x04 version = 195
        data.append(u32LE(195))
        // 0x08 flags = 0
        data.append(u32LE(0))
        // 0x0C timestamp = 0
        data.append(u32LE(0))
        data.append(u32LE(0))
        // 0x14 buildVersion = 9000
        data.append(u32LE(9000))
        // 0x18 fileSize = 0x1234
        data.append(u32LE(0x1234))
        // 0x1C bufferSize = 0x100
        data.append(u32LE(0x100))
        // 0x20 crc32 = 0xDEADBEEF
        data.append(u32LE(0xDEADBEEF))
        // 0x24 numChunks = 1
        data.append(u32LE(1))
        // 0x28..  10 × { offset, count, crc32 }
        for i in 0..<10 {
            data.append(u32LE(UInt32(0xAA + i)))
            data.append(u32LE(UInt32(0xBB + i)))
            data.append(u32LE(UInt32(0xCC + i)))
        }
        // Payload with marker strings somewhere after the header.
        let payload = "CBitmapTexture\u{00}ETextureRawFormat\u{00}rendRenderTextureResource\u{00}width\u{00}height\u{00}"
        data.append(Data(payload.utf8))
        // Pad to ~512 bytes so first-bytes-hex isn't truncated to less than 64.
        if data.count < 512 {
            data.append(Data(repeating: 0, count: 512 - data.count))
        }
        return data
    }

    private static func u32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }
}
