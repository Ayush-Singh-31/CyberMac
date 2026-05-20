import Foundation
import XCTest
@testable import CyberMacCore

final class AddonProbeTweakDBCloneRecordStagerTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacTweakDBCloneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testStagedCloneCopiesRecordTableEntryAndFlatKeys() throws {
        let fixture = try makeCloneFixture(name: "clone-basic.bin")
        let outDir = tempDir.appendingPathComponent("clone-basic-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))

        XCTAssertEqual(report.sourceRecord, "Items.Source")
        XCTAssertEqual(report.newRecord, "Items.Clone")
        XCTAssertEqual(report.sourceRecordTypeName, "Item")
        XCTAssertTrue(report.conclusions.contains(.stagedCloneProduced))
        XCTAssertTrue(report.conclusions.contains(.stagedCloneParsed))
        XCTAssertTrue(report.conclusions.contains(.newRecordResolved))
        XCTAssertTrue(report.conclusions.contains(.overrideFlatsResolved))
        XCTAssertTrue(report.conclusions.contains(.checksumUnverified))
        XCTAssertTrue(report.conclusions.contains(.writerIncomplete))
        XCTAssertFalse(report.conclusions.contains(.failed))

        let appearance = try XCTUnwrap(report.clonedFlats.first { $0.property == "appearanceName" })
        XCTAssertEqual(appearance.typeName, "CName")
        XCTAssertEqual(appearance.sourceValueIndex, 0)
        XCTAssertEqual(appearance.newValueIndex, 0)
        XCTAssertFalse(appearance.valueAppended)
        XCTAssertNil(appearance.overrideKind)

        let displayName = try XCTUnwrap(report.clonedFlats.first { $0.property == "displayName" })
        XCTAssertEqual(displayName.typeName, "gamedataLocKeyWrapper")
        XCTAssertEqual(displayName.sourceValueIndex, 0)
        XCTAssertEqual(displayName.newValueIndex, 0)

        let icon = try XCTUnwrap(report.clonedFlats.first { $0.property == "icon" })
        XCTAssertEqual(icon.typeName, "TweakDBID")

        let quality = try XCTUnwrap(report.clonedFlats.first { $0.property == "quality" })
        XCTAssertEqual(quality.typeName, "Int32")

        XCTAssertEqual(report.appliedOverrides.count, 0)
        XCTAssertEqual(report.verificationStatus, "newRecordResolvedInStagedFile")
        XCTAssertEqual(report.verification?.knownFlatCount, 4)
        XCTAssertEqual(report.verification?.recordTableEntry?.recordTypeName, "Item")
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.stagedFilePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.reportPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.summaryPath))
    }

    func testCNameOverrideReusesExistingValueIndex() throws {
        let fixture = try makeCloneFixture(name: "clone-cname-reuse.bin")
        let outDir = tempDir.appendingPathComponent("clone-cname-reuse-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .cName(property: "appearanceName", value: "appearance_source")
            ]
        ))

        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "appearanceName" })
        XCTAssertEqual(override.overrideKind, "cName")
        XCTAssertEqual(override.newValueIndex, 0)
        XCTAssertFalse(override.valueAppended)
        XCTAssertFalse(override.unresolved)

        let clonedAppearance = try XCTUnwrap(report.clonedFlats.first { $0.property == "appearanceName" })
        XCTAssertEqual(clonedAppearance.newValueIndex, 0)
        XCTAssertFalse(clonedAppearance.valueAppended)
        XCTAssertEqual(clonedAppearance.overrideKind, "cName")
    }

    func testCNameOverrideAppendsNewValueIndex() throws {
        let fixture = try makeCloneFixture(name: "clone-cname-append.bin")
        let outDir = tempDir.appendingPathComponent("clone-cname-append-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .cName(property: "appearanceName", value: "cybermac_probe_appearance")
            ]
        ))

        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "appearanceName" })
        XCTAssertTrue(override.valueAppended)
        XCTAssertEqual(override.newValueIndex, fixture.initialCNameValueCount)
        XCTAssertEqual(override.valueSummary, "\"cybermac_probe_appearance\"")

        let clonedAppearance = try XCTUnwrap(report.clonedFlats.first { $0.property == "appearanceName" })
        XCTAssertEqual(clonedAppearance.newValueIndex, fixture.initialCNameValueCount)
        XCTAssertTrue(clonedAppearance.valueAppended)
        XCTAssertEqual(clonedAppearance.overrideKind, "cName")
        XCTAssertTrue(report.conclusions.contains(.newRecordResolved))
        XCTAssertTrue(report.conclusions.contains(.overrideFlatsResolved))

        let appearanceFlat = try XCTUnwrap(report.verification?.knownFlats.first { $0.property == "appearanceName" })
        XCTAssertEqual(appearanceFlat.valueSummary, "\"cybermac_probe_appearance\"")
    }

    func testStringOverrideAddsNewFlatForUnclonedProperty() throws {
        let fixture = try makeCloneFixture(name: "clone-string.bin")
        let outDir = tempDir.appendingPathComponent("clone-string-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .string(property: "localizedDescription", value: "hello")
            ]
        ))

        XCTAssertFalse(report.clonedFlats.contains { $0.property == "localizedDescription" })
        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "localizedDescription" })
        XCTAssertEqual(override.typeName, "String")
        XCTAssertTrue(override.valueAppended)
        XCTAssertEqual(override.newValueIndex, fixture.initialStringValueCount)

        let descFlat = try XCTUnwrap(report.verification?.knownFlats.first { $0.property == "localizedDescription" })
        XCTAssertEqual(descFlat.typeName, "String")
        XCTAssertEqual(descFlat.valueSummary, "\"hello\"")
    }

    func testTweakDBIDOverrideAppendsNewID() throws {
        let fixture = try makeCloneFixture(name: "clone-tdbid.bin")
        let outDir = tempDir.appendingPathComponent("clone-tdbid-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .tweakDBID(property: "icon", value: "UIIcon.cybermac_probe_icon")
            ]
        ))

        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "icon" })
        XCTAssertEqual(override.typeName, "TweakDBID")
        XCTAssertTrue(override.valueAppended)
        XCTAssertEqual(override.newValueIndex, fixture.initialTweakDBIDValueCount)
        XCTAssertEqual(override.overrideKind, "tweakDBID")

        let expectedID = tweakDBID("UIIcon.cybermac_probe_icon")
        let iconFlat = try XCTUnwrap(report.verification?.knownFlats.first { $0.property == "icon" })
        XCTAssertEqual(iconFlat.typeName, "TweakDBID")
        XCTAssertTrue(iconFlat.valueSummary?.contains(String(format: "0x%016llx", expectedID)) ?? false)
    }

    func testLocKeyOverrideUpdatesClonedFlat() throws {
        let fixture = try makeCloneFixture(name: "clone-lockey.bin")
        let outDir = tempDir.appendingPathComponent("clone-lockey-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .locKey(property: "displayName", value: 42)
            ]
        ))

        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "displayName" })
        XCTAssertEqual(override.typeName, "gamedataLocKeyWrapper")
        XCTAssertTrue(override.valueAppended)
        XCTAssertEqual(override.valueSummary, "LocKey 42")

        let clonedDisplay = try XCTUnwrap(report.clonedFlats.first { $0.property == "displayName" })
        XCTAssertEqual(clonedDisplay.newValueIndex, fixture.initialLocKeyValueCount)
        XCTAssertTrue(clonedDisplay.valueAppended)

        let displayFlat = try XCTUnwrap(report.verification?.knownFlats.first { $0.property == "displayName" })
        XCTAssertEqual(displayFlat.valueSummary, "LocKey 42")
    }

    func testStagedOutputReparsesWithStructureInspector() throws {
        let fixture = try makeCloneFixture(name: "clone-reparse.bin")
        let outDir = tempDir.appendingPathComponent("clone-reparse-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))

        let inspectorReport = try makeManager().inspectTweakDBStructure(request: AddonProbeTweakDBStructureInspectRequest(
            fileURL: URL(fileURLWithPath: report.stagedFilePath),
            outputDirectoryURL: tempDir.appendingPathComponent("clone-reparse-inspect", isDirectory: true),
            records: ["Items.Source", "Items.Clone"]
        ))

        XCTAssertEqual(inspectorReport.recordCount, 2)
        XCTAssertTrue(inspectorReport.resolvedRecords.contains { $0.recordName == "Items.Clone" && $0.recordTableEntry != nil })
        XCTAssertTrue(inspectorReport.conclusions.contains(.wolvenKitHeaderMatched))
    }

    func testRefusesOutputInsideAppBundle() throws {
        let fixture = try makeCloneFixture(name: "clone-refuse.bin")
        let outsideApp = tempDir
            .appendingPathComponent("Cyberpunk 2077.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Probe", isDirectory: true)

        XCTAssertThrowsError(try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outsideApp,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))) { error in
            XCTAssertTrue("\(error)".contains(".app bundle"), "Expected .app bundle refusal, got: \(error)")
        }
    }

    func testReportJSONRoundTrips() throws {
        let fixture = try makeCloneFixture(name: "clone-json.bin")
        let outDir = tempDir.appendingPathComponent("clone-json-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .cName(property: "appearanceName", value: "cybermac_probe_appearance")
            ]
        ))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBCloneRecordReport.self, from: data)
        XCTAssertEqual(decoded.sourceRecord, report.sourceRecord)
        XCTAssertEqual(decoded.newRecord, report.newRecord)
        XCTAssertEqual(decoded.clonedFlats.count, report.clonedFlats.count)
        XCTAssertEqual(decoded.appliedOverrides.count, report.appliedOverrides.count)
        XCTAssertEqual(decoded.conclusions, report.conclusions)

        let formatted = AddonProbeTweakDBCloneRecordFormatter.format(report)
        XCTAssertTrue(formatted.contains("Items.Source"))
        XCTAssertTrue(formatted.contains("Items.Clone"))
    }

    func testRefusesUnknownSourceRecord() throws {
        let fixture = try makeCloneFixture(name: "clone-missing-source.bin")
        let outDir = tempDir.appendingPathComponent("clone-missing-source-out", isDirectory: true)

        XCTAssertThrowsError(try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.DoesNotExist",
            newRecord: "Items.Clone"
        ))) { error in
            XCTAssertTrue("\(error)".contains("Items.DoesNotExist"), "Expected missing source error, got: \(error)")
        }
    }

    func testRefusesClonedRecordAlreadyExists() throws {
        let fixture = try makeCloneFixture(name: "clone-existing-target.bin")
        let outDir = tempDir.appendingPathComponent("clone-existing-target-out", isDirectory: true)

        XCTAssertThrowsError(try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Source"
        ))) { error in
            XCTAssertTrue("\(error)".contains("already exists"), "Expected already-exists error, got: \(error)")
        }
    }

    func testDoesNotFatalOnDescriptorBlockMismatchAndClonesKeys() throws {
        let fixture = try makeMismatchedCloneFixture(name: "clone-mismatch-clones.bin")
        let outDir = tempDir.appendingPathComponent("clone-mismatch-clones-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))

        XCTAssertTrue(report.conclusions.contains(.stagedCloneProduced))
        XCTAssertTrue(report.conclusions.contains(.stagedCloneParsed))
        XCTAssertTrue(report.conclusions.contains(.newRecordResolved))
        XCTAssertFalse(report.conclusions.contains(.failed))

        let tagsFlat = try XCTUnwrap(report.clonedFlats.first { $0.property == "tags" })
        XCTAssertEqual(tagsFlat.typeName, "array:TweakDBID")
        XCTAssertEqual(tagsFlat.sourceValueIndex, 1)
        XCTAssertEqual(tagsFlat.newValueIndex, 1)
        XCTAssertFalse(tagsFlat.valueAppended)
        XCTAssertNil(tagsFlat.overrideKind)

        // Reparsed staged file lists Items.Clone in record table
        let inspectorReport = try makeManager().inspectTweakDBStructure(request: AddonProbeTweakDBStructureInspectRequest(
            fileURL: URL(fileURLWithPath: report.stagedFilePath),
            outputDirectoryURL: tempDir.appendingPathComponent("clone-mismatch-inspect", isDirectory: true),
            records: ["Items.Clone"]
        ))
        XCTAssertEqual(inspectorReport.recordCount, 2)
        XCTAssertTrue(inspectorReport.resolvedRecords.contains { $0.recordName == "Items.Clone" && $0.recordTableEntry != nil })
    }

    func testMismatchedArraySectionPreservesValueBlockBytes() throws {
        let fixture = try makeMismatchedCloneFixture(name: "clone-mismatch-preserve.bin")
        let outDir = tempDir.appendingPathComponent("clone-mismatch-preserve-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))

        let inspectorReport = try makeManager().inspectTweakDBStructure(request: AddonProbeTweakDBStructureInspectRequest(
            fileURL: URL(fileURLWithPath: report.stagedFilePath),
            outputDirectoryURL: tempDir.appendingPathComponent("clone-mismatch-preserve-inspect", isDirectory: true)
        ))
        let arraySection = try XCTUnwrap(inspectorReport.flatTypeSections.first { $0.typeName == "array:TweakDBID" })
        XCTAssertEqual(arraySection.valueCount, fixture.arrayTweakDBIDDescriptorValueCount)
        let valueBlockEnd = try XCTUnwrap(arraySection.keyBlockOffset)

        let stagedData = try Data(contentsOf: URL(fileURLWithPath: report.stagedFilePath))
        let stagedArrayBytes = stagedData.subdata(in: arraySection.valueBlockOffset..<valueBlockEnd)
        XCTAssertEqual(stagedArrayBytes, fixture.originalArrayTweakDBIDBlockBytes)
    }

    func testCNameOverrideStillAppendsOnHighConfidenceSectionWhenMismatchExistsElsewhere() throws {
        let fixture = try makeMismatchedCloneFixture(name: "clone-mismatch-cname.bin")
        let outDir = tempDir.appendingPathComponent("clone-mismatch-cname-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .cName(property: "appearanceName", value: "cybermac_probe_appearance")
            ]
        ))

        let override = try XCTUnwrap(report.appliedOverrides.first { $0.property == "appearanceName" })
        XCTAssertTrue(override.valueAppended)
        XCTAssertEqual(override.newValueIndex, 2)
        XCTAssertEqual(override.valueSummary, "\"cybermac_probe_appearance\"")
    }

    func testRefusesOverrideTargetingLowConfidenceCNameSection() throws {
        let fixture = try makeMismatchedCloneFixture(name: "clone-bad-cname.bin", mismatchCName: true)
        let outDir = tempDir.appendingPathComponent("clone-bad-cname-out", isDirectory: true)

        XCTAssertThrowsError(try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone",
            overrides: [
                .cName(property: "appearanceName", value: "new_value")
            ]
        ))) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("low-confidence"), "Expected low-confidence error, got: \(message)")
            XCTAssertTrue(message.contains("appearanceName"), "Expected property name in error, got: \(message)")
        }
    }

    func testCloneWithoutOverridesStillSucceedsWhenCNameSectionIsMismatched() throws {
        let fixture = try makeMismatchedCloneFixture(name: "clone-bad-cname-noop.bin", mismatchCName: true)
        let outDir = tempDir.appendingPathComponent("clone-bad-cname-noop-out", isDirectory: true)

        let report = try makeManager().stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: fixture.url,
            outputDirectoryURL: outDir,
            sourceRecord: "Items.Source",
            newRecord: "Items.Clone"
        ))

        XCTAssertTrue(report.conclusions.contains(.newRecordResolved))
        let appearance = try XCTUnwrap(report.clonedFlats.first { $0.property == "appearanceName" })
        XCTAssertFalse(appearance.valueAppended)
        XCTAssertEqual(appearance.sourceValueIndex, appearance.newValueIndex)
    }

    // MARK: - Helpers

    private func makeManager() -> AddonProbeManager {
        AddonProbeManager(
            home: home,
            tooling: NoopAddonProbeTooling(),
            dateProvider: { Date(timeIntervalSince1970: 0) },
            idProvider: { "testid" }
        )
    }

    private struct CloneFixture {
        let url: URL
        let initialCNameValueCount: Int
        let initialStringValueCount: Int
        let initialTweakDBIDValueCount: Int
        let initialLocKeyValueCount: Int
        let initialInt32ValueCount: Int
    }

    private func makeCloneFixture(name: String) throws -> CloneFixture {
        var data = Data()
        // Header placeholder
        appendUInt32(0x0BB1DB47, to: &data)
        appendUInt32(8, to: &data)
        appendUInt32(4, to: &data)
        appendUInt32(0xDEADBEEF, to: &data)
        appendUInt32(0x20, to: &data)
        appendUInt32(0, to: &data) // recordsOffset patched later
        appendUInt32(0, to: &data) // queriesOffset patched later
        appendUInt32(0, to: &data) // groupTagsOffset patched later
        XCTAssertEqual(data.count, 0x20)

        // Flat type descriptor table: 5 types (CName, String, TweakDBID, gamedataLocKeyWrapper, Int32)
        appendUInt32(5, to: &data)
        let descriptorTableStart = data.count
        for _ in 0..<5 {
            data.append(Data(count: 20))
        }

        // CName pool
        let cNameHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("CName".utf8))
        let cNameValues = ["appearance_source", "extra_cname"]
        let cNameBlockOffset = data.count
        appendUInt32(UInt32(cNameValues.count), to: &data)
        for value in cNameValues {
            data.append(encodeLengthPrefixedString(value))
        }
        let cNameKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.appearanceName"), 0)
        ]
        appendUInt32(UInt32(cNameKeys.count), to: &data)
        for key in cNameKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // String pool (no source keys, but has one pre-existing value)
        let stringHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("String".utf8))
        let stringValues = ["preexisting_string"]
        let stringBlockOffset = data.count
        appendUInt32(UInt32(stringValues.count), to: &data)
        for value in stringValues {
            data.append(encodeLengthPrefixedString(value))
        }
        appendUInt32(0, to: &data) // 0 keys

        // TweakDBID pool
        let tweakDBIDHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("TweakDBID".utf8))
        let tweakDBIDValues: [UInt64] = [tweakDBID("UIIcon.source_icon")]
        let tweakDBIDBlockOffset = data.count
        appendUInt32(UInt32(tweakDBIDValues.count), to: &data)
        for value in tweakDBIDValues {
            appendUInt64(value, to: &data)
        }
        let tweakDBIDKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.icon"), 0)
        ]
        appendUInt32(UInt32(tweakDBIDKeys.count), to: &data)
        for key in tweakDBIDKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // gamedataLocKeyWrapper pool
        let locKeyHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("gamedataLocKeyWrapper".utf8))
        let locKeyValues: [UInt64] = [12345]
        let locKeyBlockOffset = data.count
        appendUInt32(UInt32(locKeyValues.count), to: &data)
        for value in locKeyValues {
            appendUInt64(value, to: &data)
        }
        let locKeyKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.displayName"), 0)
        ]
        appendUInt32(UInt32(locKeyKeys.count), to: &data)
        for key in locKeyKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // Int32 pool
        let int32Hash = TweakDBPackedStringAnalyzer.fnv1a64(Array("Int32".utf8))
        let int32Values: [Int32] = [10]
        let int32BlockOffset = data.count
        appendUInt32(UInt32(int32Values.count), to: &data)
        for value in int32Values {
            appendInt32(value, to: &data)
        }
        let int32Keys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.quality"), 0)
        ]
        appendUInt32(UInt32(int32Keys.count), to: &data)
        for key in int32Keys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // Patch descriptor table
        let descriptors: [(UInt64, UInt32, UInt32, UInt32)] = [
            (cNameHash, UInt32(cNameValues.count), UInt32(cNameKeys.count), UInt32(cNameBlockOffset)),
            (stringHash, UInt32(stringValues.count), 0, UInt32(stringBlockOffset)),
            (tweakDBIDHash, UInt32(tweakDBIDValues.count), UInt32(tweakDBIDKeys.count), UInt32(tweakDBIDBlockOffset)),
            (locKeyHash, UInt32(locKeyValues.count), UInt32(locKeyKeys.count), UInt32(locKeyBlockOffset)),
            (int32Hash, UInt32(int32Values.count), UInt32(int32Keys.count), UInt32(int32BlockOffset))
        ]
        var descOffset = descriptorTableStart
        for descriptor in descriptors {
            writeUInt64(descriptor.0, into: &data, at: descOffset)
            writeUInt32(descriptor.1, into: &data, at: descOffset + 8)
            writeUInt32(descriptor.2, into: &data, at: descOffset + 12)
            writeUInt32(descriptor.3, into: &data, at: descOffset + 16)
            descOffset += 20
        }

        // Records
        let recordsOffset = data.count
        appendUInt32(1, to: &data)
        appendUInt64(tweakDBID("Items.Source"), to: &data)
        appendUInt32(murmur3_32("Item", seed: 0x5EEDBA5E), to: &data)

        let queriesOffset = data.count
        appendUInt32(0, to: &data)

        let groupTagsOffset = data.count
        appendUInt32(0, to: &data)

        writeUInt32(UInt32(recordsOffset), into: &data, at: 20)
        writeUInt32(UInt32(queriesOffset), into: &data, at: 24)
        writeUInt32(UInt32(groupTagsOffset), into: &data, at: 28)

        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return CloneFixture(
            url: url,
            initialCNameValueCount: cNameValues.count,
            initialStringValueCount: stringValues.count,
            initialTweakDBIDValueCount: tweakDBIDValues.count,
            initialLocKeyValueCount: locKeyValues.count,
            initialInt32ValueCount: int32Values.count
        )
    }

    private struct MismatchedCloneFixture {
        let url: URL
        let arrayTweakDBIDDescriptorValueCount: Int
        let arrayTweakDBIDBlockValueCount: Int
        let originalArrayTweakDBIDBlockBytes: Data
        let cNameDescriptorValueCount: Int
        let cNameBlockValueCount: Int
        let cNameIsMismatched: Bool
    }

    private func makeMismatchedCloneFixture(name: String, mismatchCName: Bool = false) throws -> MismatchedCloneFixture {
        var data = Data()
        appendUInt32(0x0BB1DB47, to: &data)
        appendUInt32(8, to: &data)
        appendUInt32(4, to: &data)
        appendUInt32(0xDEADBEEF, to: &data)
        appendUInt32(0x20, to: &data)
        appendUInt32(0, to: &data) // recordsOffset patched later
        appendUInt32(0, to: &data) // queriesOffset patched later
        appendUInt32(0, to: &data) // groupTagsOffset patched later
        XCTAssertEqual(data.count, 0x20)

        // 6 type pools: CName, String, TweakDBID, gamedataLocKeyWrapper, Int32, array:TweakDBID
        let typeCount = 6
        appendUInt32(UInt32(typeCount), to: &data)
        let descriptorTableStart = data.count
        for _ in 0..<typeCount {
            data.append(Data(count: 20))
        }

        // CName pool (optionally mismatched)
        let cNameHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("CName".utf8))
        let cNameValues = ["appearance_source", "extra_cname"]
        let cNameBlockOffset = data.count
        appendUInt32(UInt32(cNameValues.count), to: &data)
        for value in cNameValues {
            data.append(encodeLengthPrefixedString(value))
        }
        let cNameKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.appearanceName"), 0)
        ]
        appendUInt32(UInt32(cNameKeys.count), to: &data)
        for key in cNameKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }
        // If mismatchCName, the descriptor will lie about valueCount
        let cNameDescriptorValueCount = mismatchCName ? cNameValues.count + 3 : cNameValues.count

        // String pool
        let stringHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("String".utf8))
        let stringValues = ["preexisting_string"]
        let stringBlockOffset = data.count
        appendUInt32(UInt32(stringValues.count), to: &data)
        for value in stringValues {
            data.append(encodeLengthPrefixedString(value))
        }
        appendUInt32(0, to: &data)

        // TweakDBID pool
        let tweakDBIDHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("TweakDBID".utf8))
        let tweakDBIDValues: [UInt64] = [tweakDBID("UIIcon.source_icon")]
        let tweakDBIDBlockOffset = data.count
        appendUInt32(UInt32(tweakDBIDValues.count), to: &data)
        for value in tweakDBIDValues {
            appendUInt64(value, to: &data)
        }
        let tweakDBIDKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.icon"), 0)
        ]
        appendUInt32(UInt32(tweakDBIDKeys.count), to: &data)
        for key in tweakDBIDKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // gamedataLocKeyWrapper pool
        let locKeyHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("gamedataLocKeyWrapper".utf8))
        let locKeyValues: [UInt64] = [12345]
        let locKeyBlockOffset = data.count
        appendUInt32(UInt32(locKeyValues.count), to: &data)
        for value in locKeyValues {
            appendUInt64(value, to: &data)
        }
        let locKeyKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.displayName"), 0)
        ]
        appendUInt32(UInt32(locKeyKeys.count), to: &data)
        for key in locKeyKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // Int32 pool
        let int32Hash = TweakDBPackedStringAnalyzer.fnv1a64(Array("Int32".utf8))
        let int32Values: [Int32] = [10]
        let int32BlockOffset = data.count
        appendUInt32(UInt32(int32Values.count), to: &data)
        for value in int32Values {
            appendInt32(value, to: &data)
        }
        let int32Keys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.quality"), 0)
        ]
        appendUInt32(UInt32(int32Keys.count), to: &data)
        for key in int32Keys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // array:TweakDBID pool — MISMATCHED on purpose (descriptor says 5, block has 2)
        let arrayTweakDBIDHash = TweakDBPackedStringAnalyzer.fnv1a64(Array("array:TweakDBID".utf8))
        let arrayTweakDBIDBlockValueCount = 2
        let arrayTweakDBIDDescriptorValueCount = 5
        let arrayTweakDBIDBlockOffset = data.count
        let arrayValueBlockStart = data.count
        appendUInt32(UInt32(arrayTweakDBIDBlockValueCount), to: &data)
        // Array value 0: VLQ count=2, then two TweakDBIDs (positive VLQ 2 = 0x02)
        data.append(0x02)
        appendUInt64(tweakDBID("Tags.Tag1"), to: &data)
        appendUInt64(tweakDBID("Tags.Tag2"), to: &data)
        // Array value 1: VLQ count=1, then one TweakDBID
        data.append(0x01)
        appendUInt64(tweakDBID("Tags.Tag3"), to: &data)
        let arrayKeyBlockStart = data.count
        let originalArrayTweakDBIDBlockBytes = data.subdata(in: arrayValueBlockStart..<arrayKeyBlockStart)
        let arrayTweakDBIDKeys: [(UInt64, Int32)] = [
            (tweakDBID("Items.Source.tags"), 1)
        ]
        appendUInt32(UInt32(arrayTweakDBIDKeys.count), to: &data)
        for key in arrayTweakDBIDKeys {
            appendUInt64(key.0, to: &data)
            appendInt32(key.1, to: &data)
        }

        // Patch descriptor table
        let descriptors: [(UInt64, UInt32, UInt32, UInt32)] = [
            (cNameHash, UInt32(cNameDescriptorValueCount), UInt32(cNameKeys.count), UInt32(cNameBlockOffset)),
            (stringHash, UInt32(stringValues.count), 0, UInt32(stringBlockOffset)),
            (tweakDBIDHash, UInt32(tweakDBIDValues.count), UInt32(tweakDBIDKeys.count), UInt32(tweakDBIDBlockOffset)),
            (locKeyHash, UInt32(locKeyValues.count), UInt32(locKeyKeys.count), UInt32(locKeyBlockOffset)),
            (int32Hash, UInt32(int32Values.count), UInt32(int32Keys.count), UInt32(int32BlockOffset)),
            (arrayTweakDBIDHash, UInt32(arrayTweakDBIDDescriptorValueCount), UInt32(arrayTweakDBIDKeys.count), UInt32(arrayTweakDBIDBlockOffset))
        ]
        var descOffset = descriptorTableStart
        for descriptor in descriptors {
            writeUInt64(descriptor.0, into: &data, at: descOffset)
            writeUInt32(descriptor.1, into: &data, at: descOffset + 8)
            writeUInt32(descriptor.2, into: &data, at: descOffset + 12)
            writeUInt32(descriptor.3, into: &data, at: descOffset + 16)
            descOffset += 20
        }

        let recordsOffset = data.count
        appendUInt32(1, to: &data)
        appendUInt64(tweakDBID("Items.Source"), to: &data)
        appendUInt32(murmur3_32("Item", seed: 0x5EEDBA5E), to: &data)

        let queriesOffset = data.count
        appendUInt32(0, to: &data)

        let groupTagsOffset = data.count
        appendUInt32(0, to: &data)

        writeUInt32(UInt32(recordsOffset), into: &data, at: 20)
        writeUInt32(UInt32(queriesOffset), into: &data, at: 24)
        writeUInt32(UInt32(groupTagsOffset), into: &data, at: 28)

        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return MismatchedCloneFixture(
            url: url,
            arrayTweakDBIDDescriptorValueCount: arrayTweakDBIDDescriptorValueCount,
            arrayTweakDBIDBlockValueCount: arrayTweakDBIDBlockValueCount,
            originalArrayTweakDBIDBlockBytes: originalArrayTweakDBIDBlockBytes,
            cNameDescriptorValueCount: cNameDescriptorValueCount,
            cNameBlockValueCount: cNameValues.count,
            cNameIsMismatched: mismatchCName
        )
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }

    private func appendInt32(_ value: Int32, to data: inout Data) {
        appendUInt32(UInt32(bitPattern: value), to: &data)
    }

    private func appendUInt64(_ value: UInt64, to data: inout Data) {
        data.append(contentsOf: (0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xff) })
    }

    private func writeUInt32(_ value: UInt32, into data: inout Data, at offset: Int) {
        let bytes: [UInt8] = [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ]
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }

    private func writeUInt64(_ value: UInt64, into data: inout Data, at offset: Int) {
        let bytes = (0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xff) }
        data.replaceSubrange(offset..<(offset + 8), with: bytes)
    }

    private func encodeLengthPrefixedString(_ value: String) -> Data {
        if value.isEmpty {
            return Data([0])
        }
        let utf8 = Array(value.utf8)
        XCTAssert(utf8.count < 64, "Test helper encodes short ASCII only; got length \(utf8.count)")
        var data = Data([0x80 | UInt8(utf8.count)])
        data.append(contentsOf: utf8)
        return data
    }

    private func tweakDBID(_ name: String) -> UInt64 {
        let bytes = Array(name.utf8)
        return (UInt64(bytes.count) << 32) | UInt64(TweakDBPackedStringAnalyzer.crc32(bytes))
    }

    private func murmur3_32(_ string: String, seed: UInt32) -> UInt32 {
        let data = Array(string.utf8)
        let c1: UInt32 = 0xcc9e2d51
        let c2: UInt32 = 0x1b873593
        var hash = seed
        let roundedEnd = data.count & ~3
        var index = 0
        while index < roundedEnd {
            var k = UInt32(data[index]) |
                (UInt32(data[index + 1]) << 8) |
                (UInt32(data[index + 2]) << 16) |
                (UInt32(data[index + 3]) << 24)
            k = k &* c1
            k = (k << 15) | (k >> 17)
            k = k &* c2
            hash ^= k
            hash = (hash << 13) | (hash >> 19)
            hash = hash &* 5 &+ 0xe6546b64
            index += 4
        }
        var k1: UInt32 = 0
        let remaining = data.count & 3
        if remaining == 3 { k1 ^= UInt32(data[roundedEnd + 2]) << 16 }
        if remaining >= 2 { k1 ^= UInt32(data[roundedEnd + 1]) << 8 }
        if remaining >= 1 {
            k1 ^= UInt32(data[roundedEnd])
            k1 = k1 &* c1
            k1 = (k1 << 15) | (k1 >> 17)
            k1 = k1 &* c2
            hash ^= k1
        }
        hash ^= UInt32(data.count)
        hash ^= hash >> 16
        hash = hash &* 0x85ebca6b
        hash ^= hash >> 13
        hash = hash &* 0xc2b2ae35
        hash ^= hash >> 16
        return hash
    }
}

private struct NoopAddonProbeTooling: OfficialArchiveSwapTooling {
    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {}
    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {}
}
