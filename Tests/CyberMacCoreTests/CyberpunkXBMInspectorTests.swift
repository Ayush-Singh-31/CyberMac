import Foundation
import XCTest
@testable import CyberMacCore

final class CyberpunkXBMInspectorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacCyberpunkXBMInspectorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - High-level inspect()

    func testRejectsMissingFile() {
        let missing = tempDir.appendingPathComponent("nope.xbm")
        XCTAssertThrowsError(try CyberpunkXBMInspector().inspect(fileURL: missing)) { error in
            guard case CyberMacError.notFound = error else {
                XCTFail("Expected notFound, got \(error)")
                return
            }
        }
    }

    func testClassifiesNonCyberpunkXBMClearly() throws {
        let url = tempDir.appendingPathComponent("plain.txt")
        try "this is not a cyberpunk xbm".write(to: url, atomically: true, encoding: .utf8)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        XCTAssertFalse(result.isCyberpunkXBM)
        XCTAssertNil(result.tableDirectory)
        XCTAssertNil(result.stringTable)
        XCTAssertNil(result.nameTable)
        XCTAssertTrue(result.chunks.isEmpty)
        XCTAssertTrue(result.notes.contains { $0.contains("Inspector skipped CR2W parsing") })
    }

    func testDoesNotCrashOnTruncatedCR2W() throws {
        let url = tempDir.appendingPathComponent("truncated-cr2w.xbm")
        try Data(CyberpunkXBMProbe.cr2wMagicBytes).write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        XCTAssertTrue(result.isCyberpunkXBM)
        XCTAssertNotNil(result.cr2wHeader)
        // Header doesn't extend far enough for a real table directory.
        XCTAssertNotNil(result.tableDirectory)
        XCTAssertTrue(result.tableDirectory?.tables.allSatisfy { $0.isEmpty } ?? false)
        XCTAssertNil(result.stringTable)
        XCTAssertNil(result.nameTable)
        XCTAssertTrue(result.chunks.isEmpty)
    }

    func testSyntheticCR2WIdentifiesTextureMarkersAndPayload() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)

        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        XCTAssertTrue(result.isCyberpunkXBM)

        // Table directory is deterministic.
        let directory = try XCTUnwrap(result.tableDirectory)
        XCTAssertEqual(directory.tables.count, 10)
        XCTAssertEqual(directory.tables[0].kindGuess, .strings)
        XCTAssertEqual(directory.tables[0].offset, UInt32(fixture.stringsOffset))
        XCTAssertEqual(directory.tables[0].count, UInt32(fixture.stringsByteLength))
        XCTAssertEqual(directory.tables[1].kindGuess, .names)
        XCTAssertEqual(directory.tables[1].count, UInt32(fixture.nameEntries.count))
        XCTAssertEqual(directory.tables[4].kindGuess, .chunks)
        XCTAssertEqual(directory.tables[4].count, UInt32(fixture.chunks.count))

        // Strings.
        let strings = try XCTUnwrap(result.stringTable)
        XCTAssertEqual(strings.regionOffset, UInt32(fixture.stringsOffset))
        XCTAssertEqual(strings.totalStrings, fixture.expectedStrings.count)
        XCTAssertEqual(strings.strings.map(\.value), fixture.expectedStrings)

        // Names.
        let names = try XCTUnwrap(result.nameTable)
        XCTAssertEqual(names.entries.count, fixture.nameEntries.count)
        XCTAssertEqual(names.entries.map(\.value), fixture.nameEntries.map { $0.expectedValue })

        // Chunks.
        XCTAssertEqual(result.chunks.count, fixture.chunks.count)
        XCTAssertEqual(result.chunks[0].className, "CBitmapTexture")
        XCTAssertEqual(result.chunks[0].dataOffset, fixture.chunks[0].dataOffset)
        XCTAssertEqual(result.chunks[0].dataSize, fixture.chunks[0].dataSize)

        // Markers.
        XCTAssertTrue(result.textureMarkersFound.contains("CBitmapTexture"))
        XCTAssertTrue(result.textureMarkersFound.contains("rendRenderTextureBlobPC"))
        XCTAssertTrue(result.textureMarkersFound.contains("width"))
        XCTAssertTrue(result.textureMarkersFound.contains("height"))

        // Candidate metadata fields.
        let widthField = try XCTUnwrap(result.candidateMetadataFields.first { $0.name == "width" })
        XCTAssertTrue(widthField.foundInStrings)
        let mipField = try XCTUnwrap(result.candidateMetadataFields.first { $0.name == "mipCount" })
        XCTAssertTrue(mipField.foundInStrings)

        // Payload region (header fileSize < actual file size).
        XCTAssertEqual(result.candidatePayloadRegions.count, 1)
        let region = try XCTUnwrap(result.candidatePayloadRegions.first)
        XCTAssertEqual(region.source, "trailing-after-cr2w-fileSize")
        XCTAssertEqual(region.offset, UInt64(fixture.headerFileSize))
        XCTAssertEqual(region.size, UInt64(fixture.totalBytes) - UInt64(fixture.headerFileSize))
    }

    func testTableDirectoryParsingRemainsDeterministic() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let first = try CyberpunkXBMInspector().inspect(fileURL: url)
        let second = try CyberpunkXBMInspector().inspect(fileURL: url)
        XCTAssertEqual(first.tableDirectory, second.tableDirectory)
        XCTAssertEqual(first.stringTable, second.stringTable)
        XCTAssertEqual(first.nameTable, second.nameTable)
        XCTAssertEqual(first.chunks, second.chunks)
        XCTAssertEqual(first.candidatePayloadRegions, second.candidatePayloadRegions)
    }

    // MARK: - Formatter dump limits

    func testDumpStringsObeysLimit() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)

        let limited = CyberpunkXBMInspectionFormatter.format(
            result,
            options: CyberpunkXBMInspectionFormatOptions(dumpStrings: true, limit: 2)
        )
        // Counts string-dump rows ("  [@" prefix is only used for string entries).
        let stringLines = limited.split(separator: "\n").filter { $0.hasPrefix("  [@") }
        XCTAssertEqual(stringLines.count, 2)
        XCTAssertTrue(limited.contains("more)"))
    }

    func testDumpNamesObeysLimit() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)

        let limited = CyberpunkXBMInspectionFormatter.format(
            result,
            options: CyberpunkXBMInspectionFormatOptions(dumpNames: true, limit: 1)
        )
        let nameLines = limited.split(separator: "\n").filter { $0.contains("stringOffset=") }
        XCTAssertEqual(nameLines.count, 1)
    }

    func testDumpChunksObeysLimit() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)

        XCTAssertGreaterThanOrEqual(result.chunks.count, 2)
        let limited = CyberpunkXBMInspectionFormatter.format(
            result,
            options: CyberpunkXBMInspectionFormatOptions(dumpChunks: true, limit: 1)
        )
        let chunkLines = limited.split(separator: "\n").filter { $0.contains("dataOffset=") }
        XCTAssertEqual(chunkLines.count, 1)
        XCTAssertTrue(limited.contains("more)"))
    }

    func testHumanFormatterOutputIsStable() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        let formatted = CyberpunkXBMInspectionFormatter.format(result)
        XCTAssertTrue(formatted.hasPrefix("Cyberpunk XBM inspect"))
        XCTAssertTrue(formatted.contains("Classification: cyberpunk-xbm"))
        XCTAssertTrue(formatted.contains("Table directory:"))
        XCTAssertTrue(formatted.contains("Strings: decoded="))
        XCTAssertTrue(formatted.contains("Names: decoded="))
        XCTAssertTrue(formatted.contains("Chunks: decoded="))
        XCTAssertTrue(formatted.contains("Texture markers"))
        XCTAssertTrue(formatted.contains("Candidate metadata fields:"))
        XCTAssertTrue(formatted.contains("Candidate payload regions:"))
        XCTAssertTrue(formatted.contains("Notes:"))
    }

    func testJSONFormatterOutputIsValid() throws {
        let fixture = SyntheticXBMFixture.make()
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        let json = try CyberpunkXBMInspectionFormatter.formatJSON(result)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let dict = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(dict["isCyberpunkXBM"] as? Bool, true)
        XCTAssertEqual(dict["probeClassification"] as? String, "cyberpunk-xbm")
        XCTAssertNotNil(dict["tableDirectory"])
        XCTAssertNotNil(dict["stringTable"])
        XCTAssertNotNil(dict["nameTable"])
        XCTAssertNotNil(dict["chunks"])
        XCTAssertNotNil(dict["candidateMetadataFields"])
        XCTAssertNotNil(dict["candidatePayloadRegions"])
    }

    // MARK: - Payload region reporting

    func testReportsTrailingPayloadWhenHeaderFileSizeIsSmallerThanActual() throws {
        let fixture = SyntheticXBMFixture.make()
        XCTAssertLessThan(fixture.headerFileSize, fixture.totalBytes)
        let url = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: url)
        let result = try CyberpunkXBMInspector().inspect(fileURL: url)
        let region = try XCTUnwrap(result.candidatePayloadRegions.first)
        XCTAssertEqual(region.offset, UInt64(fixture.headerFileSize))
        XCTAssertEqual(region.size, UInt64(fixture.totalBytes - fixture.headerFileSize))
    }

    // MARK: - Negative confirmation: no export behavior exists

    func testInspectorDoesNotExposeAnyExportEntryPoint() {
        // This is intentionally a structural test: if/when a PNG/DDS export type appears,
        // it should be added to the explicit deny-list below and gated behind a separate
        // PR with format-decoding evidence.
        let exportTypeNames = [
            "CyberpunkXBMExporter",
            "CyberpunkXBMPNGExporter",
            "CyberpunkXBMDecoder"
        ]
        for name in exportTypeNames {
            XCTAssertNil(NSClassFromString(name), "Unexpected export type present: \(name)")
        }
    }
}

// MARK: - Synthetic fixture builder

private struct SyntheticXBMFixture {
    let data: Data
    let stringsOffset: Int
    let stringsByteLength: Int
    let nameEntries: [(stringOffset: UInt32, hash: UInt32, expectedValue: String)]
    let chunks: [(classNameID: UInt16, dataOffset: UInt32, dataSize: UInt32)]
    let headerFileSize: Int
    let totalBytes: Int
    let expectedStrings: [String]

    static func make() -> SyntheticXBMFixture {
        // String pool layout: each entry is a null-terminated UTF-8 string.
        // Offsets within the pool are recorded so name entries can point at them.
        let entries: [String] = [
            "CBitmapTexture",
            "rendRenderTextureResource",
            "rendRenderTextureBlobPC",
            "ETextureCompression",
            "GpuWrapApieTextureGroup",
            "setup",
            "width",
            "height",
            "compression",
            "mipCount"
        ]
        var stringPool = Data()
        var offsets: [String: UInt32] = [:]
        for entry in entries {
            offsets[entry] = UInt32(stringPool.count)
            stringPool.append(Data(entry.utf8))
            stringPool.append(0)
        }

        let nameEntries: [(stringOffset: UInt32, hash: UInt32, expectedValue: String)] = [
            (offsets["CBitmapTexture"]!, 0x1111_1111, "CBitmapTexture"),
            (offsets["rendRenderTextureResource"]!, 0x2222_2222, "rendRenderTextureResource"),
            (offsets["rendRenderTextureBlobPC"]!, 0x3333_3333, "rendRenderTextureBlobPC"),
            (offsets["ETextureCompression"]!, 0x4444_4444, "ETextureCompression"),
            (offsets["GpuWrapApieTextureGroup"]!, 0x5555_5555, "GpuWrapApieTextureGroup")
        ]
        let chunks: [(classNameID: UInt16, dataOffset: UInt32, dataSize: UInt32)] = [
            (0, 1024, 256),  // refers to nameEntries[0] = CBitmapTexture
            (1, 1300, 128),  // refers to nameEntries[1] = rendRenderTextureResource
            (2, 1500, 200)   // refers to nameEntries[2] = rendRenderTextureBlobPC
        ]

        // Layout (matching CR2W parser expectations):
        // 0x00..0x9F header = 40-byte fixed prefix + 120-byte table directory.
        let headerSize = 0xA0
        let stringsOffset = headerSize
        let namesOffset = stringsOffset + stringPool.count
        let namesByteLength = nameEntries.count * CyberpunkXBMInspector.nameEntrySize
        let chunksOffset = namesOffset + namesByteLength
        let chunksByteLength = chunks.count * CyberpunkXBMInspector.chunkEntrySize
        // Headers report fileSize = end-of-metadata (just past chunk table).
        let headerFileSize = chunksOffset + chunksByteLength
        // Tack on a payload region after fileSize so the inspector reports a trailing buffer.
        let trailingPayloadBytes = 2048
        let totalBytes = headerFileSize + trailingPayloadBytes

        var data = Data()
        // 0x00 magic "CR2W"
        data.append(contentsOf: CyberpunkXBMProbe.cr2wMagicBytes)
        // 0x04 version
        data.append(u32LE(195))
        // 0x08 flags
        data.append(u32LE(0))
        // 0x0C u64 timestamp
        data.append(u32LE(0))
        data.append(u32LE(0))
        // 0x14 buildVersion
        data.append(u32LE(9000))
        // 0x18 fileSize (header field)
        data.append(u32LE(UInt32(headerFileSize)))
        // 0x1C bufferSize
        data.append(u32LE(0))
        // 0x20 crc32
        data.append(u32LE(0xDEADBEEF))
        // 0x24 numChunks
        data.append(u32LE(UInt32(chunks.count)))
        // 0x28.. 10 × table headers (offset, count, crc32)
        let tableHeaders: [(offset: UInt32, count: UInt32, crc32: UInt32)] = [
            (UInt32(stringsOffset), UInt32(stringPool.count), 0xAA00),
            (UInt32(namesOffset), UInt32(nameEntries.count), 0xAA01),
            (0, 0, 0),
            (0, 0, 0),
            (UInt32(chunksOffset), UInt32(chunks.count), 0xAA04),
            (0, 0, 0),
            (0, 0, 0),
            (0, 0, 0),
            (0, 0, 0),
            (0, 0, 0)
        ]
        for entry in tableHeaders {
            data.append(u32LE(entry.offset))
            data.append(u32LE(entry.count))
            data.append(u32LE(entry.crc32))
        }
        precondition(data.count == headerSize, "Synthetic header size drift: \(data.count)")

        // String pool
        data.append(stringPool)
        // Name entries
        for entry in nameEntries {
            data.append(u32LE(entry.stringOffset))
            data.append(u32LE(entry.hash))
        }
        // Chunk entries: u16 classNameID, u16 objectFlags, u32 parentID, u32 dataSize,
        //                u32 dataOffset, u32 templateField, u32 crc32  → 24 bytes
        for chunk in chunks {
            data.append(u16LE(chunk.classNameID))
            data.append(u16LE(0))            // objectFlags
            data.append(u32LE(0xFFFFFFFF))   // parentID
            data.append(u32LE(chunk.dataSize))
            data.append(u32LE(chunk.dataOffset))
            data.append(u32LE(0))            // templateField
            data.append(u32LE(0xCCCC_CCCC))  // crc32
        }
        precondition(data.count == headerFileSize, "Synthetic metadata size drift: \(data.count) vs \(headerFileSize)")

        // Trailing payload (zero-padded — represents the would-be texture blob).
        data.append(Data(repeating: 0xAA, count: trailingPayloadBytes))
        precondition(data.count == totalBytes)

        return SyntheticXBMFixture(
            data: data,
            stringsOffset: stringsOffset,
            stringsByteLength: stringPool.count,
            nameEntries: nameEntries,
            chunks: chunks,
            headerFileSize: headerFileSize,
            totalBytes: totalBytes,
            expectedStrings: entries
        )
    }

    private static func u16LE(_ value: UInt16) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 2)
    }

    private static func u32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }
}
