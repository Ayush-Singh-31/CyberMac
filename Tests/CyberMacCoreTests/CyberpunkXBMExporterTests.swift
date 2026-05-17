import Foundation
import XCTest
import ImageIO
import SQLite3
@testable import CyberMacCore

final class CyberpunkXBMExporterTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacCyberpunkXBMExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Happy path

    func testExportsSyntheticBC3XBMFixtureToPNG() throws {
        let fixture = SyntheticExportableXBM.makeBC3SolidRed4x4()
        let xbmURL = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: xbmURL)

        let pngURL = tempDir.appendingPathComponent("generated/preview.png")
        let result = try CyberpunkXBMExporter().export(
            fileURL: xbmURL,
            options: CyberpunkXBMExportOptions(outputURL: pngURL, debug: true)
        )

        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 4)
        XCTAssertEqual(result.compressionName, "TCM_DXTAlpha")
        XCTAssertEqual(result.decoderUsed, "BC3")
        XCTAssertEqual(result.mipCount, 1)
        XCTAssertEqual(result.topMipBytesDecoded, 16)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(pngURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 4)
    }

    func testParsesRealCBitmapTextureChunkHeadWithLeadingObjectMarker() throws {
        let nameLookup = realChunkHeadNameLookup()
        let chunkBytes = Data([
            0x00,
            0x02, 0x00, 0x03, 0x00, 0x06, 0x00, 0x00, 0x00, 0x04, 0x00,
            0x05, 0x00, 0x06, 0x00, 0x08, 0x00, 0x00, 0x00, 0x38, 0x01, 0x00, 0x00,
            0x07, 0x00, 0x06, 0x00, 0x08, 0x00, 0x00, 0x00, 0x18, 0x01, 0x00, 0x00,
            0x08, 0x00, 0x09, 0x00, 0x36, 0x00, 0x00, 0x00,
            0x00,
            0x0a, 0x00, 0x0b, 0x00, 0x06, 0x00, 0x00, 0x00, 0x0c, 0x00,
            0x0d, 0x00, 0x0e, 0x00, 0x06, 0x00, 0x00, 0x00, 0x0f, 0x00,
            0x10, 0x00, 0x11, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00,
            0x12, 0x00, 0x11, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00,
            0x13, 0x00, 0x11, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00
        ])
        var debugNotes: [String] = []

        let properties = CyberpunkXBMExporter.parsePropertyRecords(
            chunkBytes: chunkBytes,
            nameLookup: nameLookup,
            debug: true,
            debugNotes: &debugNotes
        )

        XCTAssertEqual(properties.first(where: { $0.name == "width" })?.uint32Value, 312)
        XCTAssertEqual(properties.first(where: { $0.name == "height" })?.uint32Value, 280)

        let setup = try XCTUnwrap(properties.first(where: { $0.name == "setup" }))
        let compression = try XCTUnwrap(setup.children.first(where: { $0.name == "compression" })?.uint16Value)
        let group = try XCTUnwrap(setup.children.first(where: { $0.name == "group" })?.uint16Value)
        XCTAssertEqual(nameLookup[Int(compression)], "TCM_DXTAlpha")
        XCTAssertEqual(nameLookup[Int(group)], "TEXG_Generic_UI")
        XCTAssertEqual(setup.children.first(where: { $0.name == "isGamma" })?.boolValue, true)
        XCTAssertEqual(setup.children.first(where: { $0.name == "hasMipchain" })?.boolValue, false)
        XCTAssertFalse(debugNotes.contains(where: { $0.contains("overruns chunk") }))
    }

    func testParsesNestedSetupStructRecords() throws {
        let nameLookup: [Int: String] = [
            1: "setup",
            2: "CBitmapTextureSetup",
            3: "group",
            4: "ETextureGroup",
            5: "TEXG_Generic_UI",
            6: "compression",
            7: "ETextureCompression",
            8: "TCM_DXTAlpha",
            9: "hasMipchain",
            10: "Bool"
        ]
        var setupValue = Data([0x00])
        setupValue.append(propertyRecord(nameID: 3, typeID: 4, value: u16LE(5)))
        setupValue.append(propertyRecord(nameID: 6, typeID: 7, value: u16LE(8)))
        setupValue.append(propertyRecord(nameID: 9, typeID: 10, value: Data([0x00])))
        setupValue.append(propertyTerminator())

        var chunkBytes = Data([0x00])
        chunkBytes.append(propertyRecord(nameID: 1, typeID: 2, value: setupValue))
        chunkBytes.append(propertyTerminator())
        var debugNotes: [String] = []

        let properties = CyberpunkXBMExporter.parsePropertyRecords(
            chunkBytes: chunkBytes,
            nameLookup: nameLookup,
            debug: true,
            debugNotes: &debugNotes
        )

        let setup = try XCTUnwrap(properties.first(where: { $0.name == "setup" }))
        XCTAssertEqual(setup.children.first(where: { $0.name == "group" })?.uint16Value, 5)
        XCTAssertEqual(setup.children.first(where: { $0.name == "compression" })?.uint16Value, 8)
        XCTAssertEqual(setup.children.first(where: { $0.name == "hasMipchain" })?.boolValue, false)
        XCTAssertFalse(debugNotes.contains(where: { $0.contains("overruns chunk") }))
    }

    // MARK: - Failure paths

    func testFailsClearlyOnUnsupportedCompression() throws {
        // TCM_QualityR maps to BC4, which still has no decoder wired up.
        let fixture = SyntheticExportableXBM.makeWithCompressionName("TCM_QualityR", width: 4, height: 4)
        let xbmURL = tempDir.appendingPathComponent("unsupported.xbm")
        try fixture.data.write(to: xbmURL)

        let pngURL = tempDir.appendingPathComponent("out.png")
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(outputURL: pngURL)
            )
        ) { error in
            guard let failure = error as? CyberpunkXBMExportFailure else {
                XCTFail("Expected CyberpunkXBMExportFailure, got \(error)")
                return
            }
            XCTAssertEqual(failure.detectedCompressionName, "TCM_QualityR")
            XCTAssertTrue(failure.reason.contains("Unsupported compression"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: pngURL.path))
    }

    func testQualityColorMapsToBC7Decoder() throws {
        XCTAssertEqual(CyberpunkXBMCompression.qualityColor.decoderName, "BC7")
        XCTAssertEqual(CyberpunkXBMCompression(rawName: "TCM_QualityColor"), .qualityColor)
    }

    func testExportsSyntheticBC7XBMFixtureToPNG() throws {
        // 4×4 BC7 block (16 bytes). The pixel content is whatever bcdec
        // produces for this input; we only check decoder selection, output
        // shape, and that a PNG lands on disk.
        let block = Data(repeating: 0x40, count: CyberpunkXBMBC7Decoder.blockByteSize)
        let fixture = SyntheticExportableXBM.makeWithRawPayload(
            compressionName: "TCM_QualityColor",
            width: 4,
            height: 4,
            payload: block
        )
        let xbmURL = tempDir.appendingPathComponent("synthetic-bc7.xbm")
        try fixture.data.write(to: xbmURL)
        let pngURL = tempDir.appendingPathComponent("generated/bc7.png")

        let result = try CyberpunkXBMExporter().export(
            fileURL: xbmURL,
            options: CyberpunkXBMExportOptions(outputURL: pngURL, debug: true)
        )

        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 4)
        XCTAssertEqual(result.compressionName, "TCM_QualityColor")
        XCTAssertEqual(result.decoderUsed, "BC7")
        XCTAssertEqual(result.topMipBytesDecoded, 16)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(pngURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 4)
    }

    func testFailsClearlyOnBC7PayloadSmallerThanTopMip() throws {
        // Claim 64×64 (needs 4096 bytes for BC7 top mip) but supply only 16.
        let fixture = SyntheticExportableXBM.makeWithRawPayload(
            compressionName: "TCM_QualityColor",
            width: 64,
            height: 64,
            payload: Data(count: 16)
        )
        let xbmURL = tempDir.appendingPathComponent("bc7-short.xbm")
        try fixture.data.write(to: xbmURL)
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(outputURL: tempDir.appendingPathComponent("out.png"))
            )
        ) { error in
            guard let failure = error as? CyberpunkXBMExportFailure else {
                XCTFail("Expected CyberpunkXBMExportFailure, got \(error)")
                return
            }
            XCTAssertTrue(failure.reason.contains("BC7 top mip"))
        }
    }

    func testFailsClearlyOnNonCyberpunkInput() throws {
        let xbmURL = tempDir.appendingPathComponent("plain.txt")
        try "hello".write(to: xbmURL, atomically: true, encoding: .utf8)
        let pngURL = tempDir.appendingPathComponent("out.png")
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(outputURL: pngURL)
            )
        ) { error in
            guard let failure = error as? CyberpunkXBMExportFailure else {
                XCTFail("Expected CyberpunkXBMExportFailure, got \(error)")
                return
            }
            XCTAssertTrue(failure.reason.contains("Not a Cyberpunk"))
        }
    }

    func testDoesNotCrashOnMalformedPayload() throws {
        // BC3-shaped metadata claims 64x64 (needs 4096 bytes) but payload only carries 16.
        let fixture = SyntheticExportableXBM.makeBC3WithDimensions(width: 64, height: 64, payloadBytes: 16)
        let xbmURL = tempDir.appendingPathComponent("malformed.xbm")
        try fixture.data.write(to: xbmURL)
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(outputURL: tempDir.appendingPathComponent("out.png"))
            )
        ) { error in
            guard let failure = error as? CyberpunkXBMExportFailure else {
                XCTFail("Expected CyberpunkXBMExportFailure, got \(error)")
                return
            }
            XCTAssertTrue(failure.reason.contains("BC3 top mip") || failure.reason.contains("compressed"))
        }
    }

    func testFailsClearlyOnMissingMetadata() throws {
        // CBitmapTexture chunk exists but its property records are empty.
        let fixture = SyntheticExportableXBM.makeBC3SolidRed4x4(omittingProperties: true)
        let xbmURL = tempDir.appendingPathComponent("no-meta.xbm")
        try fixture.data.write(to: xbmURL)
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(outputURL: tempDir.appendingPathComponent("out.png"))
            )
        ) { error in
            guard let failure = error as? CyberpunkXBMExportFailure else {
                XCTFail("Expected CyberpunkXBMExportFailure, got \(error)")
                return
            }
            XCTAssertTrue(failure.reason.contains("width/height"))
        }
    }

    // MARK: - --register integration

    func testRegisterPathCallsAssetPreviewRegistryWhenArchiveAndAssetProvided() throws {
        let fixture = SyntheticExportableXBM.makeBC3SolidRed4x4()
        let xbmURL = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: xbmURL)
        let pngURL = tempDir.appendingPathComponent("generated/preview.png")

        let archivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
        let assetPath = "base\\gameplay\\gui\\widgets\\crosshair\\master_crosshair.xbm"
        let catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        let catalogURL = catalogDir.appendingPathComponent("Data_archive_Mac_content_basegame_1_engine.archive.txt")
        try assetPath.write(to: catalogURL, atomically: true, encoding: .utf8)

        let dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        _ = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))

        let result = try CyberpunkXBMExporter().export(
            fileURL: xbmURL,
            options: CyberpunkXBMExportOptions(
                outputURL: pngURL,
                register: true,
                archivePath: archivePath,
                assetPath: assetPath,
                databaseURL: dbURL
            )
        )

        XCTAssertTrue(result.registered)
        let report = try XCTUnwrap(result.registerReport)
        XCTAssertEqual(report.previewKind, AssetPreviewKind.textureThumbnail)
        XCTAssertEqual(report.sourceTool, CyberpunkXBMExportOptions.defaultSourceTool)
        XCTAssertTrue(report.inserted)
    }

    func testRegisterRejectsMissingArchiveOrAssetPath() throws {
        let fixture = SyntheticExportableXBM.makeBC3SolidRed4x4()
        let xbmURL = tempDir.appendingPathComponent("synthetic.xbm")
        try fixture.data.write(to: xbmURL)
        let pngURL = tempDir.appendingPathComponent("preview.png")
        XCTAssertThrowsError(
            try CyberpunkXBMExporter().export(
                fileURL: xbmURL,
                options: CyberpunkXBMExportOptions(
                    outputURL: pngURL,
                    register: true,
                    archivePath: nil,
                    assetPath: nil
                )
            )
        ) { error in
            guard case CyberMacError.invalidInput(let message) = error else {
                XCTFail("Expected invalidInput, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("--register"))
        }
    }

    private func realChunkHeadNameLookup() -> [Int: String] {
        [
            2: "cookingPlatform",
            3: "ECookingPlatform",
            4: "PLATFORM_Mac",
            5: "width",
            6: "Uint32",
            7: "height",
            8: "setup",
            9: "CBitmapTextureSetup",
            10: "group",
            11: "ETextureGroup",
            12: "TEXG_Generic_UI",
            13: "compression",
            14: "ETextureCompression",
            15: "TCM_DXTAlpha",
            16: "isStreamable",
            17: "Bool",
            18: "hasMipchain",
            19: "isGamma"
        ]
    }

    private func propertyRecord(nameID: UInt16, typeID: UInt16, value: Data) -> Data {
        var data = Data()
        data.append(u16LE(nameID))
        data.append(u16LE(typeID))
        data.append(u32LE(UInt32(4 + value.count)))
        data.append(value)
        return data
    }

    private func propertyTerminator() -> Data {
        var data = Data()
        data.append(u16LE(0))
        data.append(u16LE(0))
        data.append(u32LE(0))
        return data
    }

    private func u16LE(_ value: UInt16) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 2)
    }

    private func u32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }
}

// MARK: - Synthetic CR2W fixture w/ real BC3 payload

private struct SyntheticExportableXBM {
    let data: Data
    let width: UInt32
    let height: UInt32
    let compressionName: String

    static func makeBC3SolidRed4x4(omittingProperties: Bool = false) -> SyntheticExportableXBM {
        // One BC3 block — solid opaque red, 4×4.
        let block: [UInt8] = [
            0xFF, 0xFF,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0xF8, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]
        return make(
            width: 4,
            height: 4,
            mipCount: 1,
            compressionName: "TCM_DXTAlpha",
            payload: Data(block),
            omittingProperties: omittingProperties
        )
    }

    static func makeBC3WithDimensions(width: UInt32, height: UInt32, payloadBytes: Int) -> SyntheticExportableXBM {
        let payload = Data(repeating: 0xAA, count: payloadBytes)
        return make(
            width: width,
            height: height,
            mipCount: 1,
            compressionName: "TCM_DXTAlpha",
            payload: payload,
            omittingProperties: false
        )
    }

    static func makeWithCompressionName(_ compressionName: String, width: UInt32, height: UInt32) -> SyntheticExportableXBM {
        let payload = Data(count: 64)
        return make(
            width: width,
            height: height,
            mipCount: 1,
            compressionName: compressionName,
            payload: payload,
            omittingProperties: false
        )
    }

    static func makeWithRawPayload(compressionName: String, width: UInt32, height: UInt32, payload: Data) -> SyntheticExportableXBM {
        return make(
            width: width,
            height: height,
            mipCount: 1,
            compressionName: compressionName,
            payload: payload,
            omittingProperties: false
        )
    }

    /// Builds a CR2W-shaped buffer:
    ///   [0x00..0x9F]  CR2W header
    ///   string pool (table[0])
    ///   name entries (table[1])
    ///   chunk entries (table[4])
    ///   CBitmapTexture chunk property records
    ///   trailing payload
    /// Properties use the {u16 nameId, u16 typeId, u32 size, value...} layout,
    /// where value.count == size - 4, terminated by nameId == 0.
    private static func make(
        width: UInt32,
        height: UInt32,
        mipCount: UInt32,
        compressionName: String,
        payload: Data,
        omittingProperties: Bool
    ) -> SyntheticExportableXBM {
        // String pool: collect all strings we need.
        let stringEntries: [String] = [
            "CBitmapTexture",
            "width",
            "height",
            "mipCount",
            "compression",
            "Uint32",
            "Uint16",
            "Uint8",
            "ETextureCompression",
            compressionName
        ]
        var stringPool = Data()
        var offsets: [String: UInt32] = [:]
        for entry in stringEntries {
            offsets[entry] = UInt32(stringPool.count)
            stringPool.append(Data(entry.utf8))
            stringPool.append(0)
        }

        // Name table: [stringOffset:u32, hash:u32]. nameIndex 0 is reserved as
        // the "null" terminator slot in CP77; we put a placeholder there so real names
        // start at index 1+.
        let names: [String] = stringEntries
        var nameEntries: [(stringOffset: UInt32, hash: UInt32)] = []
        // Reserve index 0 — pointing into the pool's first string is fine.
        nameEntries.append((offsets[names[0]]!, 0))
        for name in names {
            nameEntries.append((offsets[name]!, 0))
        }
        // nameID lookup: 1-based mapping into stringEntries.
        var nameID: [String: UInt16] = [:]
        for (i, name) in names.enumerated() {
            nameID[name] = UInt16(i + 1)
        }

        // Build the chunk property record bytes.
        var chunkProperties = Data()
        func appendProperty(name: String, typeName: String, value: Data) {
            chunkProperties.append(u16LE(nameID[name]!))
            chunkProperties.append(u16LE(nameID[typeName]!))
            chunkProperties.append(u32LE(UInt32(4 + value.count)))
            chunkProperties.append(value)
        }
        if !omittingProperties {
            appendProperty(name: "width", typeName: "Uint32", value: u32LE(width))
            appendProperty(name: "height", typeName: "Uint32", value: u32LE(height))
            appendProperty(name: "mipCount", typeName: "Uint8", value: Data([UInt8(min(255, mipCount))]))
            // compression: u16 referencing the enum-value name (e.g. TCM_DXTAlpha).
            appendProperty(name: "compression", typeName: "ETextureCompression", value: u16LE(nameID[compressionName]!))
        }
        // Terminator
        chunkProperties.append(u16LE(0))
        chunkProperties.append(u16LE(0))
        chunkProperties.append(u32LE(0))

        // Layout offsets.
        let headerSize = 0xA0
        let stringsOffset = headerSize
        let namesOffset = stringsOffset + stringPool.count
        let namesByteLength = nameEntries.count * CyberpunkXBMInspector.nameEntrySize
        let chunksOffset = namesOffset + namesByteLength
        let chunkCount = 1
        let chunksByteLength = chunkCount * CyberpunkXBMInspector.chunkEntrySize
        let chunkDataOffset = chunksOffset + chunksByteLength
        let chunkDataSize = chunkProperties.count
        let headerFileSize = chunkDataOffset + chunkDataSize
        let totalBytes = headerFileSize + payload.count

        var data = Data()
        // 0x00 magic "CR2W"
        data.append(contentsOf: CyberpunkXBMProbe.cr2wMagicBytes)
        // 0x04 version
        data.append(u32LE(195))
        // 0x08 flags
        data.append(u32LE(0))
        // 0x0C timestamp u64
        data.append(u32LE(0))
        data.append(u32LE(0))
        // 0x14 buildVersion
        data.append(u32LE(9000))
        // 0x18 fileSize
        data.append(u32LE(UInt32(headerFileSize)))
        // 0x1C bufferSize
        data.append(u32LE(0))
        // 0x20 crc32
        data.append(u32LE(0xDEADBEEF))
        // 0x24 numChunks
        data.append(u32LE(UInt32(chunkCount)))
        // 0x28.. 10 × table headers
        let tableHeaders: [(offset: UInt32, count: UInt32, crc32: UInt32)] = [
            (UInt32(stringsOffset), UInt32(stringPool.count), 0),
            (UInt32(namesOffset), UInt32(nameEntries.count), 0),
            (0, 0, 0),
            (0, 0, 0),
            (UInt32(chunksOffset), UInt32(chunkCount), 0),
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
        precondition(data.count == headerSize)

        // String pool
        data.append(stringPool)
        // Name entries
        for entry in nameEntries {
            data.append(u32LE(entry.stringOffset))
            data.append(u32LE(entry.hash))
        }
        // Chunk entry: u16 classNameID, u16 objectFlags, u32 parentID,
        //              u32 dataSize, u32 dataOffset, u32 templateField, u32 crc32
        let classNameID = nameID["CBitmapTexture"]!
        data.append(u16LE(classNameID))
        data.append(u16LE(0))             // objectFlags
        data.append(u32LE(0xFFFFFFFF))    // parentID
        data.append(u32LE(UInt32(chunkDataSize)))
        data.append(u32LE(UInt32(chunkDataOffset)))
        data.append(u32LE(0))             // templateField
        data.append(u32LE(0))             // crc32
        precondition(data.count == chunkDataOffset)

        // Chunk data (property records)
        data.append(chunkProperties)
        precondition(data.count == headerFileSize)

        // Trailing payload
        data.append(payload)
        precondition(data.count == totalBytes)

        return SyntheticExportableXBM(
            data: data,
            width: width,
            height: height,
            compressionName: compressionName
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
