import Foundation
import XCTest
@testable import CyberMacCore

final class CyberpunkXBMBatchExporterTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacXBMBatchExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Filename / resolver helpers

    func testEncodedPreviewFileNameJoinsPathPartsWithDoubleUnderscore() {
        let name = CyberpunkXBMBatchExporter.encodedPreviewFileName(
            forAssetPath: "base\\gameplay\\gui\\crosshair.xbm"
        )
        XCTAssertEqual(name, "base__gameplay__gui__crosshair.xbm.png")
    }

    func testEncodedPreviewFileNameStripsParentReferences() {
        let name = CyberpunkXBMBatchExporter.encodedPreviewFileName(
            forAssetPath: "base/../../escape.xbm"
        )
        // ".." segments are dropped, leaving "base__escape.xbm.png".
        XCTAssertEqual(name, "base__escape.xbm.png")
    }

    func testEncodedPreviewFileNameFallsBackForEmptyPath() {
        XCTAssertEqual(CyberpunkXBMBatchExporter.encodedPreviewFileName(forAssetPath: ""), "unnamed.png")
    }

    func testResolveInputURLConvertsBackslashesAndAppendsToRoot() {
        let root = URL(fileURLWithPath: "/tmp/extracted")
        let resolved = CyberpunkXBMBatchExporter.resolveInputURL(
            extractedRoot: root,
            assetPath: "base\\foo\\bar.xbm"
        )
        XCTAssertEqual(resolved.path, "/tmp/extracted/base/foo/bar.xbm")
    }

    // MARK: - Failure classification

    func testFailureKindMappingFromExporterKind() {
        XCTAssertEqual(CyberpunkXBMBatchExportFailureKind.from(.unsupportedCompression), .unsupportedCompression)
        XCTAssertEqual(CyberpunkXBMBatchExportFailureKind.from(.streamedTopMipMissing), .streamedTopMipMissing)
        XCTAssertEqual(CyberpunkXBMBatchExportFailureKind.from(.missingKrakenLibrary), .missingKrakenLibrary)
        XCTAssertEqual(CyberpunkXBMBatchExportFailureKind.from(.decodeFailure), .decodeFailure)
    }

    // MARK: - End-to-end against a synthetic catalog index

    func testBatchExportRunsAgainstCatalogIndexAndClassifiesOutcomes() throws {
        let archivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
        // Three asset paths: one that resolves to a real synthetic BC3 xbm,
        // one whose file is intentionally missing on disk, and one that's
        // a non-CR2W file (decode failure).
        let validAssetPath = "base\\gameplay\\gui\\crosshair.xbm"
        let missingAssetPath = "base\\gameplay\\gui\\missing_crosshair.xbm"
        let brokenAssetPath = "base\\gameplay\\gui\\not_cr2w.xbm"

        let catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        let catalogFile = catalogDir.appendingPathComponent("Data_archive_Mac_content_basegame_1_engine.archive.txt")
        let catalogText = [validAssetPath, missingAssetPath, brokenAssetPath].joined(separator: "\n") + "\n"
        try catalogText.write(to: catalogFile, atomically: true, encoding: .utf8)

        let dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        _ = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))

        // Lay out the extracted root: drop a synthetic BC3 xbm at the valid
        // path and a junk file at the broken path; skip the missing one.
        let extractedRoot = tempDir.appendingPathComponent("extracted", isDirectory: true)
        let bc3Fixture = BatchExportSyntheticXBM.makeBC3SolidRed4x4()
        let validURL = extractedRoot.appendingPathComponent("base/gameplay/gui/crosshair.xbm")
        try FileManager.default.createDirectory(at: validURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bc3Fixture.write(to: validURL)
        let brokenURL = extractedRoot.appendingPathComponent("base/gameplay/gui/not_cr2w.xbm")
        try Data("not a cr2w file".utf8).write(to: brokenURL)

        let outDir = tempDir.appendingPathComponent("previews", isDirectory: true)
        let report = try CyberpunkXBMBatchExporter().run(options: CyberpunkXBMBatchExportOptions(
            archivePath: archivePath,
            extractedRoot: extractedRoot,
            outputDirectory: outDir,
            databaseURL: dbURL,
            debug: true
        ))

        XCTAssertEqual(report.totalMatched, 3)
        XCTAssertEqual(report.totalProcessed, 3)
        XCTAssertEqual(report.exportedCount, 1)
        XCTAssertEqual(report.failureCountsByKind[.missingFile], 1)
        XCTAssertEqual(report.failureCountsByKind[.decodeFailure], 1)

        let entriesByAsset = Dictionary(uniqueKeysWithValues: report.entries.map { ($0.assetPath, $0) })

        let validEntry = try XCTUnwrap(entriesByAsset[validAssetPath])
        guard case .exported = validEntry.outcome else {
            return XCTFail("Expected exported outcome for valid xbm, got \(validEntry.outcome)")
        }
        XCTAssertEqual(validEntry.decoderUsed, "BC3")
        XCTAssertEqual(validEntry.width, 4)
        XCTAssertEqual(validEntry.height, 4)
        XCTAssertTrue(FileManager.default.fileExists(atPath: validEntry.previewPath))
        XCTAssertTrue(validEntry.previewPath.hasSuffix("base__gameplay__gui__crosshair.xbm.png"))

        let missingEntry = try XCTUnwrap(entriesByAsset[missingAssetPath])
        guard case .failed(let missingKind, _) = missingEntry.outcome else {
            return XCTFail("Expected failure for missing file")
        }
        XCTAssertEqual(missingKind, .missingFile)

        let brokenEntry = try XCTUnwrap(entriesByAsset[brokenAssetPath])
        guard case .failed(let brokenKind, _) = brokenEntry.outcome else {
            return XCTFail("Expected failure for non-CR2W input")
        }
        XCTAssertEqual(brokenKind, .decodeFailure)
    }

    func testBatchExportSkipsExistingWhenFlagIsSet() throws {
        let archivePath = "Data/archive/Mac/content/basegame_1_engine.archive"
        let assetPath = "base\\gameplay\\gui\\crosshair.xbm"

        let catalogDir = tempDir.appendingPathComponent("catalogs", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        try assetPath.write(
            to: catalogDir.appendingPathComponent("Data_archive_Mac_content_basegame_1_engine.archive.txt"),
            atomically: true,
            encoding: .utf8
        )

        let dbURL = tempDir.appendingPathComponent("archive-index.sqlite")
        _ = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))

        let extractedRoot = tempDir.appendingPathComponent("extracted", isDirectory: true)
        let inputURL = extractedRoot.appendingPathComponent("base/gameplay/gui/crosshair.xbm")
        try FileManager.default.createDirectory(at: inputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try BatchExportSyntheticXBM.makeBC3SolidRed4x4().write(to: inputURL)

        let outDir = tempDir.appendingPathComponent("previews", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let preExistingPNG = outDir.appendingPathComponent("base__gameplay__gui__crosshair.xbm.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: preExistingPNG) // bytes that aren't a valid PNG body

        let report = try CyberpunkXBMBatchExporter().run(options: CyberpunkXBMBatchExportOptions(
            archivePath: archivePath,
            extractedRoot: extractedRoot,
            outputDirectory: outDir,
            databaseURL: dbURL,
            skipExisting: true
        ))

        XCTAssertEqual(report.exportedCount, 0)
        XCTAssertEqual(report.skippedCount, 1)

        let preservedBytes = try Data(contentsOf: preExistingPNG)
        XCTAssertEqual(preservedBytes, Data([0x89, 0x50, 0x4E, 0x47]),
                       "skip-existing must not overwrite the pre-existing preview")
    }

    func testBatchExportThrowsForMissingExtractedRoot() {
        let options = CyberpunkXBMBatchExportOptions(
            archivePath: "Data/archive/Mac/content/basegame_1_engine.archive",
            extractedRoot: tempDir.appendingPathComponent("does-not-exist"),
            outputDirectory: tempDir.appendingPathComponent("previews")
        )
        XCTAssertThrowsError(try CyberpunkXBMBatchExporter().run(options: options))
    }

    // MARK: - Compact output

    func testCompactFormatterHidesSuccessfulPerAssetSpam() {
        let report = makeReportWithMixedOutcomes()
        let compact = CyberpunkXBMBatchExportFormatter.format(report, debug: false)
        XCTAssertTrue(compact.contains("Exported: 2"))
        XCTAssertTrue(compact.contains("Failed: 1"))
        // Compact omits successes and skips from the per-asset detail.
        XCTAssertFalse(compact.contains("base\\good_one.xbm"))
        XCTAssertFalse(compact.contains("base\\good_two.xbm"))
        XCTAssertFalse(compact.contains("base\\skipped.xbm"))
        XCTAssertFalse(compact.contains("Per-asset detail"))
        // But it still surfaces failures.
        XCTAssertTrue(compact.contains("base\\bad.xbm"))
        XCTAssertTrue(compact.contains("decode failure"))
    }

    func testDebugFormatterKeepsFullPerAssetDetail() {
        let report = makeReportWithMixedOutcomes()
        let debug = CyberpunkXBMBatchExportFormatter.format(report, debug: true)
        XCTAssertTrue(debug.contains("Per-asset detail"))
        XCTAssertTrue(debug.contains("base\\good_one.xbm"))
        XCTAssertTrue(debug.contains("base\\good_two.xbm"))
        XCTAssertTrue(debug.contains("base\\skipped.xbm"))
        XCTAssertTrue(debug.contains("base\\bad.xbm"))
    }

    func testCompactFormatterCapsFailuresAtCompactLimit() {
        let totalFailures = CyberpunkXBMBatchExportFormatter.compactFailureExampleLimit + 5
        var entries: [CyberpunkXBMBatchExportEntry] = []
        for index in 0..<totalFailures {
            entries.append(CyberpunkXBMBatchExportEntry(
                assetPath: "base\\failure_\(index).xbm",
                archivePath: "Data/archive/Mac/content/basegame.archive",
                resolvedInputPath: "/tmp/failure_\(index).xbm",
                previewPath: "/tmp/out/failure_\(index).png",
                outcome: .failed(.decodeFailure, reason: "synthetic")
            ))
        }
        let report = CyberpunkXBMBatchExportReport(
            archivePath: "Data/archive/Mac/content/basegame.archive",
            extractedRootPath: "/tmp/extracted",
            outputDirectoryPath: "/tmp/out",
            databasePath: nil,
            query: ".xbm",
            category: nil,
            limit: 1000,
            totalMatched: totalFailures,
            totalProcessed: totalFailures,
            entries: entries,
            exportedCount: 0,
            skippedCount: 0,
            failureCountsByKind: [.decodeFailure: totalFailures],
            registeredCount: 0
        )
        let compact = CyberpunkXBMBatchExportFormatter.format(report, debug: false)
        // First N failures are printed verbatim...
        XCTAssertTrue(compact.contains("base\\failure_0.xbm"))
        XCTAssertTrue(compact.contains("base\\failure_\(CyberpunkXBMBatchExportFormatter.compactFailureExampleLimit - 1).xbm"))
        // ...everything past the cap is summarised, not enumerated.
        XCTAssertFalse(compact.contains("base\\failure_\(CyberpunkXBMBatchExportFormatter.compactFailureExampleLimit + 4).xbm"))
        XCTAssertTrue(compact.contains("and 5 more"))
    }

    private func makeReportWithMixedOutcomes() -> CyberpunkXBMBatchExportReport {
        let entries: [CyberpunkXBMBatchExportEntry] = [
            CyberpunkXBMBatchExportEntry(
                assetPath: "base\\good_one.xbm",
                archivePath: "Data/archive/Mac/content/basegame.archive",
                resolvedInputPath: "/tmp/good_one.xbm",
                previewPath: "/tmp/out/good_one.png",
                outcome: .exported,
                width: 256, height: 128, compressionName: "TCM_DXTAlpha", decoderUsed: "BC3"
            ),
            CyberpunkXBMBatchExportEntry(
                assetPath: "base\\good_two.xbm",
                archivePath: "Data/archive/Mac/content/basegame.archive",
                resolvedInputPath: "/tmp/good_two.xbm",
                previewPath: "/tmp/out/good_two.png",
                outcome: .exported,
                width: 512, height: 512, compressionName: "TCM_QualityColor", decoderUsed: "BC7"
            ),
            CyberpunkXBMBatchExportEntry(
                assetPath: "base\\skipped.xbm",
                archivePath: "Data/archive/Mac/content/basegame.archive",
                resolvedInputPath: "/tmp/skipped.xbm",
                previewPath: "/tmp/out/skipped.png",
                outcome: .skippedExisting
            ),
            CyberpunkXBMBatchExportEntry(
                assetPath: "base\\bad.xbm",
                archivePath: "Data/archive/Mac/content/basegame.archive",
                resolvedInputPath: "/tmp/bad.xbm",
                previewPath: "/tmp/out/bad.png",
                outcome: .failed(.decodeFailure, reason: "synthetic decode failure")
            )
        ]
        return CyberpunkXBMBatchExportReport(
            archivePath: "Data/archive/Mac/content/basegame.archive",
            extractedRootPath: "/tmp/extracted",
            outputDirectoryPath: "/tmp/out",
            databasePath: nil,
            query: ".xbm",
            category: nil,
            limit: 1000,
            totalMatched: 4,
            totalProcessed: 4,
            entries: entries,
            exportedCount: 2,
            skippedCount: 1,
            failureCountsByKind: [.decodeFailure: 1],
            registeredCount: 0
        )
    }
}

/// Re-exports the synthetic BC3 fixture from the exporter tests so this
/// suite can stand on its own without depending on the other file's
/// private helper.
private enum BatchExportSyntheticXBM {
    static func makeBC3SolidRed4x4() -> Data {
        // CR2W layout was reverse-engineered for `CyberpunkXBMExporterTests`;
        // we re-use the same construction here verbatim.
        let block: [UInt8] = [
            0xFF, 0xFF,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0xF8, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]
        return SyntheticXBMBuilder.make(
            width: 4,
            height: 4,
            mipCount: 1,
            compressionName: "TCM_DXTAlpha",
            payload: Data(block)
        )
    }
}

private enum SyntheticXBMBuilder {
    static func make(width: UInt32, height: UInt32, mipCount: UInt32, compressionName: String, payload: Data) -> Data {
        let stringEntries: [String] = [
            "CBitmapTexture", "width", "height", "mipCount", "compression",
            "Uint32", "Uint16", "Uint8", "ETextureCompression", compressionName
        ]
        var stringPool = Data()
        var offsets: [String: UInt32] = [:]
        for entry in stringEntries {
            offsets[entry] = UInt32(stringPool.count)
            stringPool.append(Data(entry.utf8))
            stringPool.append(0)
        }
        let names: [String] = stringEntries
        var nameEntries: [(stringOffset: UInt32, hash: UInt32)] = []
        nameEntries.append((offsets[names[0]]!, 0))
        for name in names {
            nameEntries.append((offsets[name]!, 0))
        }
        var nameID: [String: UInt16] = [:]
        for (i, name) in names.enumerated() {
            nameID[name] = UInt16(i + 1)
        }
        var chunkProperties = Data()
        func appendProperty(name: String, typeName: String, value: Data) {
            chunkProperties.append(u16LE(nameID[name]!))
            chunkProperties.append(u16LE(nameID[typeName]!))
            chunkProperties.append(u32LE(UInt32(4 + value.count)))
            chunkProperties.append(value)
        }
        appendProperty(name: "width", typeName: "Uint32", value: u32LE(width))
        appendProperty(name: "height", typeName: "Uint32", value: u32LE(height))
        appendProperty(name: "mipCount", typeName: "Uint8", value: Data([UInt8(min(255, mipCount))]))
        appendProperty(name: "compression", typeName: "ETextureCompression", value: u16LE(nameID[compressionName]!))
        chunkProperties.append(u16LE(0))
        chunkProperties.append(u16LE(0))
        chunkProperties.append(u32LE(0))

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

        var data = Data()
        data.append(contentsOf: CyberpunkXBMProbe.cr2wMagicBytes)
        data.append(u32LE(195))
        data.append(u32LE(0))
        data.append(u32LE(0)); data.append(u32LE(0))
        data.append(u32LE(9000))
        data.append(u32LE(UInt32(headerFileSize)))
        data.append(u32LE(0))
        data.append(u32LE(0xDEADBEEF))
        data.append(u32LE(UInt32(chunkCount)))
        let tableHeaders: [(UInt32, UInt32, UInt32)] = [
            (UInt32(stringsOffset), UInt32(stringPool.count), 0),
            (UInt32(namesOffset), UInt32(nameEntries.count), 0),
            (0, 0, 0), (0, 0, 0),
            (UInt32(chunksOffset), UInt32(chunkCount), 0),
            (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0)
        ]
        for (offset, count, crc) in tableHeaders {
            data.append(u32LE(offset))
            data.append(u32LE(count))
            data.append(u32LE(crc))
        }
        data.append(stringPool)
        for entry in nameEntries {
            data.append(u32LE(entry.stringOffset))
            data.append(u32LE(entry.hash))
        }
        let classNameID = nameID["CBitmapTexture"]!
        data.append(u16LE(classNameID))
        data.append(u16LE(0))
        data.append(u32LE(0xFFFFFFFF))
        data.append(u32LE(UInt32(chunkDataSize)))
        data.append(u32LE(UInt32(chunkDataOffset)))
        data.append(u32LE(0))
        data.append(u32LE(0))
        data.append(chunkProperties)
        data.append(payload)
        return data
    }

    static func u16LE(_ value: UInt16) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 2)
    }
    static func u32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }
}
