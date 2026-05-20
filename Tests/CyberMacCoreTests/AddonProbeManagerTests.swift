import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class AddonProbeManagerTests: XCTestCase {
    private let relativeArchivePath = "Data/archive/Mac/content/basegame_4_appearance.archive"
    private var tempDir: URL!
    private var home: CyberMacHomeManager!
    private var cp77toolsURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacAddonProbeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        cp77toolsURL = tempDir.appendingPathComponent("cp77tools")
        try "#!/bin/sh\nexit 0\n".write(to: cp77toolsURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cp77toolsURL.path)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testParsesYAMLishItemIDsAndBaseRecords() throws {
        let text = """
        Items.Unquoted_Item:
          $base: Items.GenericOuterChest
          parent: Items.ParentRecord
          itemType: Clothing
          appearanceName: cool_variant
        "Items.Quoted-Item":
          base: Items.OtherBase
        """

        XCTAssertEqual(AddonProbeManager.parseYAMLishItemIDs(text), [
            "Items.Quoted-Item",
            "Items.Unquoted_Item"
        ])
        XCTAssertEqual(AddonProbeManager.parseReferencedItemIDs(text), [
            "Items.GenericOuterChest",
            "Items.OtherBase",
            "Items.ParentRecord",
            "Items.Quoted-Item",
            "Items.Unquoted_Item"
        ])
        XCTAssertEqual(AddonProbeManager.parseCandidateBaseRecords(text), [
            "Clothing",
            "Items.GenericOuterChest",
            "Items.OtherBase",
            "Items.ParentRecord",
            "cool_variant"
        ])
    }

    func testParsesResourceReferencesFromXLAndCSVLikeText() throws {
        let text = """
        resource: base\\characters\\garment\\custom\\jacket.ent
        appearance = base/characters/garment/custom/jacket.app
        mesh,base/characters/garment/custom/jacket.mesh
        mlsetup: "base/characters/garment/custom/jacket.mlsetup"
        mlmask: "base/characters/garment/custom/jacket.mlmask"
        icon: "base/gameplay/gui/icons/custom_jacket.xbm"
        atlas: base/gameplay/gui/icons/custom_jacket.inkatlas
        """

        XCTAssertEqual(AddonProbeManager.parseResourceReferences(text), [
            "base/characters/garment/custom/jacket.app",
            "base/characters/garment/custom/jacket.ent",
            "base/characters/garment/custom/jacket.mesh",
            "base/characters/garment/custom/jacket.mlmask",
            "base/characters/garment/custom/jacket.mlsetup",
            "base/gameplay/gui/icons/custom_jacket.inkatlas",
            "base/gameplay/gui/icons/custom_jacket.xbm"
        ])
    }

    func testInspectDiscoversModFolderLayoutAndAddonMarkers() throws {
        let modRoot = tempDir.appendingPathComponent("UnpackedMod", isDirectory: true)
        try write("archive/pc/mod/addon.archive", under: modRoot, contents: "archive")
        try write("archive/pc/content/replacer.archive", under: modRoot, contents: "archive")
        try write("archive/nested/other.archive", under: modRoot, contents: "archive")
        try write("floating.archive", under: modRoot, contents: "archive")
        try write("metadata/custom.archive.xl", under: modRoot, contents: "localization: localization/en-us.json\nfactory: resources/factory.csv\n")
        try write("resources/factory.csv", under: modRoot, contents: "base/characters/garment/custom/jacket.mesh\n")
        try write("localization/en-us.json", under: modRoot, contents: #"{"Items.Custom_Jacket":"Custom Jacket"}"#)
        try write(
            "r6/tweaks/items.yaml",
            under: modRoot,
            contents: """
            Items.Custom_Jacket:
              $base: Items.GenericOuterChest
              appearanceName: custom_jacket
              entityName: base/characters/garment/custom/jacket.ent
            """
        )

        let report = try makeManager().inspect(request: AddonProbeInspectRequest(modURL: modRoot))

        XCTAssertEqual(report.archiveFiles, [
            "archive/nested/other.archive",
            "archive/pc/content/replacer.archive",
            "archive/pc/mod/addon.archive",
            "floating.archive"
        ])
        XCTAssertEqual(report.xlFiles, ["metadata/custom.archive.xl"])
        XCTAssertEqual(report.tweakFiles, ["r6/tweaks/items.yaml"])
        XCTAssertEqual(report.csvFiles, ["resources/factory.csv"])
        XCTAssertEqual(report.jsonLocalizationFiles, ["localization/en-us.json"])
        XCTAssertEqual(report.candidateItemIDs, ["Items.Custom_Jacket"])
        XCTAssertTrue(report.candidateBaseRecords.contains("Items.GenericOuterChest"))
        XCTAssertTrue(report.candidateResourceReferences.contains("base/characters/garment/custom/jacket.ent"))
        XCTAssertEqual(report.classification, .mixedReplacerAddon)
    }

    func testInspectAcceptsZipInputSafely() throws {
        let zipURL = tempDir.appendingPathComponent("Addon.zip")
        try createZip(zipURL, entries: [
            "archive/pc/mod/addon.archive": "archive",
            "r6/tweaks/items.yaml": "Items.Zip_Item:\n  $base: Items.GenericInnerChest\n"
        ])

        let report = try makeManager().inspect(request: AddonProbeInspectRequest(modURL: zipURL))

        XCTAssertEqual(report.inputKind, .zip)
        XCTAssertEqual(report.archiveFiles, ["archive/pc/mod/addon.archive"])
        XCTAssertEqual(report.candidateItemIDs, ["Items.Zip_Item"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.inspectedRootPath))
        XCTAssertTrue(report.warnings.contains { $0.contains("Zip input was extracted") })
    }

    func testTweakXLInstancesExpandTemplatedItemIDsAndFields() throws {
        let analysis = AddonProbeManager.analyzeTweakXL(
            """
            Items.test_dress_${base_color}:
              $base: Items.GenericInnerChestClothing
              placementSlots:
                - !append OutfitSlots.TorsoInner
              appearanceName: dress_${base_color}
              entityName: test_dress_${base_color}_w
              displayName: Test Dress ${base_color}
              icon:
                atlasResourcePath: base\\test\\icons\\dress.inkatlas
                atlasPartName: ${icon}
              unsupportedField: !${base_color}
              $instances:
                - { base_color: black, icon: slot_01 }
                - { base_color: white, icon: slot_02 }
            """
        )

        XCTAssertEqual(analysis.templatedItemRecords, ["Items.test_dress_${base_color}"])
        XCTAssertEqual(analysis.expandedItemIDs, ["Items.test_dress_black", "Items.test_dress_white"])
        XCTAssertEqual(analysis.baseRecords, ["Items.GenericInnerChestClothing"])
        XCTAssertEqual(analysis.placementSlots, ["OutfitSlots.TorsoInner"])
        XCTAssertEqual(analysis.appearanceNames, ["dress_black", "dress_white"])
        XCTAssertEqual(analysis.entityNames, ["test_dress_black_w", "test_dress_white_w"])
        XCTAssertEqual(analysis.displayNames, ["Test Dress black", "Test Dress white"])
        XCTAssertEqual(analysis.iconAtlasPaths, ["base\\test\\icons\\dress.inkatlas"])
        XCTAssertEqual(analysis.iconAtlasParts, ["slot_01", "slot_02"])
        XCTAssertEqual(analysis.instanceCount, 2)
        XCTAssertTrue(analysis.unresolvedTemplateExpressions.contains("!${base_color}"))
    }

    func testAtomiicStyleShirtTemplateExpandsNineRecords() throws {
        let analysis = AddonProbeManager.analyzeTweakXL(atomiicShirtTemplate())

        XCTAssertEqual(analysis.expandedItemIDs.count, 9)
        XCTAssertEqual(analysis.expandedItemIDs.first, "Items.atomiic_sexyofficedress_shirt_black")
        XCTAssertEqual(analysis.expandedItemIDs.last, "Items.atomiic_sexyofficedress_shirt_brown")
        XCTAssertEqual(analysis.baseRecords, ["Items.GenericInnerChestClothing"])
        XCTAssertEqual(analysis.placementSlots, ["OutfitSlots.TorsoInner"])
        XCTAssertEqual(analysis.entityNames, ["atomiic_sexyofficedress_shirt_w"])
        XCTAssertEqual(analysis.iconAtlasPaths, ["base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas"])
        XCTAssertEqual(analysis.iconAtlasParts, [
            "slot_01",
            "slot_02",
            "slot_03",
            "slot_04",
            "slot_05",
            "slot_06",
            "slot_07",
            "slot_08",
            "slot_09"
        ])
    }

    func testAtomiicStyleSkirtTemplateExpandsEighteenRecords() throws {
        let analysis = AddonProbeManager.analyzeTweakXL(atomiicSkirtTemplate())

        XCTAssertEqual(analysis.expandedItemIDs.count, 18)
        XCTAssertEqual(analysis.expandedItemIDs.first, "Items.atomiic_sexyofficedress_skirt_black")
        XCTAssertEqual(analysis.expandedItemIDs.last, "Items.atomiic_sexyofficedress_skirt_brownv2")
        XCTAssertEqual(analysis.baseRecords, ["Items.Skirt"])
        XCTAssertEqual(analysis.placementSlots, ["OutfitSlots.LegsOuter"])
        XCTAssertEqual(analysis.entityNames, ["atomiic_sexyofficedress_skirt_w"])
        XCTAssertEqual(analysis.iconAtlasPaths, ["base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas"])
    }

    func testXLMetadataParserExtractsFactoriesAndLocalizationOnscreens() throws {
        let metadata = AddonProbeManager.analyzeXLMetadata(
            """
            factories:
              - base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv
            localization:
              onscreens:
                en-us: base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.json
            """
        )

        XCTAssertEqual(metadata.factoryCSVFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv"])
        XCTAssertEqual(metadata.localizationJSONFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.json"])
    }

    func testInspectJSONIncludesExpandedItemIDsForTweakXLTemplates() throws {
        let modRoot = try makeAtomiicMod()

        let report = try makeManager().inspect(request: AddonProbeInspectRequest(modURL: modRoot))
        XCTAssertEqual(report.expandedItemIDs.count, 27)
        XCTAssertEqual(report.candidateItemIDs.count, 27)
        XCTAssertEqual(report.baseRecords, ["Items.GenericInnerChestClothing", "Items.Skirt"])
        XCTAssertEqual(report.placementSlots, ["OutfitSlots.TorsoInner", "OutfitSlots.LegsOuter"])
        XCTAssertEqual(report.factoryCSVFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv"])
        XCTAssertEqual(report.localizationJSONFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.json"])

        let json = try AddonProbeInspectFormatter.formatJSON(report)
        XCTAssertTrue(json.contains("\"expandedItemIDs\""))
        XCTAssertTrue(json.contains("Items.atomiic_sexyofficedress_shirt_black"))
        XCTAssertTrue(json.contains("Items.atomiic_sexyofficedress_skirt_brownv2"))
    }

    func testAtomiicTweakXLExpandsIntoFullRecordSummaries() throws {
        let analysis = AddonProbeManager.analyzeTweakXL("\(atomiicShirtTemplate())\n\(atomiicSkirtTemplate())")

        XCTAssertEqual(analysis.expandedItemRecords.count, 27)
        XCTAssertEqual(analysis.expandedItemRecords.filter { $0.baseRecord == "Items.GenericInnerChestClothing" }.count, 9)
        XCTAssertEqual(analysis.expandedItemRecords.filter { $0.baseRecord == "Items.Skirt" }.count, 18)

        let firstShirt = try XCTUnwrap(analysis.expandedItemRecords.first { $0.recordID == "Items.atomiic_sexyofficedress_shirt_black" })
        XCTAssertEqual(firstShirt.itemID, firstShirt.recordID)
        XCTAssertEqual(firstShirt.placementSlots, ["OutfitSlots.TorsoInner"])
        XCTAssertEqual(firstShirt.appearanceName, "atomiic_sexyofficedress_shirt_w_black")
        XCTAssertEqual(firstShirt.entityName, "atomiic_sexyofficedress_shirt_w")
        XCTAssertEqual(firstShirt.displayName, "Atomiic Sexy Office Dress Shirt black")
        XCTAssertEqual(firstShirt.localizedDescription, "Atomiic Sexy Office Dress localized description black")
        XCTAssertEqual(firstShirt.iconAtlasResourcePath, "base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas")
        XCTAssertEqual(firstShirt.iconAtlasPartName, "slot_01")
        XCTAssertEqual(firstShirt.quality, "Quality.Legendary")
        XCTAssertEqual(firstShirt.statModifiers, ["Items.IconicItem", "Items.ScaleToPlayerLevel"])
    }

    func testRecordLayerProbeWritesExpandedRecordsAndHandlesNoCandidateResources() throws {
        let modRoot = try makeAtomiicMod()
        let dbURL = try makeArchiveIndex(catalogs: [
            "Data_archive_Mac_content_basegame_1_engine.archive.txt": "base\\ui\\unrelated_asset.xbm\n"
        ])
        let game = try makeGameInstall()

        let report = try makeManager().recordLayerProbe(request: AddonProbeRecordLayerProbeRequest(
            modURL: modRoot,
            outputDirectoryURL: tempDir.appendingPathComponent("record-layer-no-candidates", isDirectory: true),
            cp77toolsURL: cp77toolsURL,
            gameInstall: game,
            databaseURL: dbURL
        ))

        XCTAssertEqual(report.searchTerms, AddonProbeManager.recordLayerProbeSearchTerms)
        XCTAssertEqual(report.expandedRecords.count, 27)
        XCTAssertEqual(report.baseRecordCounts["Items.GenericInnerChestClothing"], 9)
        XCTAssertEqual(report.baseRecordCounts["Items.Skirt"], 18)
        XCTAssertEqual(report.conclusion, .noCandidateResources)
        XCTAssertTrue(report.candidateResources.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.expandedRecordsPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.reportPath))

        let expandedData = try Data(contentsOf: URL(fileURLWithPath: report.expandedRecordsPath))
        let expanded = try JSONDecoder.cybermac.decode(AddonProbeTweakXLExpandedRecordsReport.self, from: expandedData)
        XCTAssertEqual(expanded.recordCount, 27)
        XCTAssertEqual(expanded.records.first?.recordID, "Items.atomiic_sexyofficedress_shirt_black")
    }

    func testRecordLayerProbeDecodesCR2WAndFindsNestedJSONStrings() throws {
        let modRoot = try makeAtomiicMod()
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let resourcePath = "base/gamedata/static_data/itemRecords.tdb"
        let dbURL = try makeArchiveIndex(catalogs: [
            "Data_archive_Mac_content_basegame_4_gamedata.archive.txt": "\(resourcePath)\n"
        ])
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                resourcePath: Data([0x43, 0x52, 0x32, 0x57, 0x00])
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForRecordLayerDecode()

        let report = try makeManager(tooling: tooling).recordLayerProbe(request: AddonProbeRecordLayerProbeRequest(
            modURL: modRoot,
            outputDirectoryURL: tempDir.appendingPathComponent("record-layer-cr2w", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game,
            databaseURL: dbURL
        ))

        XCTAssertEqual(report.conclusion, .patchableRecordLayerCandidateFound)
        XCTAssertTrue(report.likelyPatchableRecordLayerFound)
        XCTAssertEqual(report.candidateResources.first?.assetPath, resourcePath)
        XCTAssertEqual(report.resourceDiagnostics.first?.detectedMagic, .cr2w)
        XCTAssertTrue(report.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "serialize"] })
        XCTAssertTrue(report.decodedTextMatches.contains { $0.term == "Items.GenericInnerChestClothing" && $0.jsonPath == "$.Data.records[0].id" })
        XCTAssertTrue(report.decodedTextMatches.contains { $0.term == "Items.Skirt" && $0.matchedString == "Items.Skirt" })
        XCTAssertTrue(report.decodedTextMatches.contains { $0.term == "ScaleToPlayerLevel" && $0.matchedString == "Items.ScaleToPlayerLevel" })

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeRecordLayerProbeReport.self, from: data)
        XCTAssertEqual(decoded.conclusion, .patchableRecordLayerCandidateFound)
    }

    func testRecordRuntimeProbeIncludesAllBaseAndCustomRecordIDs() throws {
        let modRoot = try makeAtomiicMod()
        let outputZip = tempDir.appendingPathComponent("record-runtime-probe.zip")

        let result = try makeManager().recordRuntimeProbe(request: AddonProbeRecordRuntimeProbeRequest(
            modURL: modRoot,
            outputZipURL: outputZip,
            modName: "CyberMac Atomiic Record Probe"
        ))

        XCTAssertEqual(result.baseRecordIDs, ["Items.GenericInnerChestClothing", "Items.Skirt"])
        XCTAssertEqual(result.customRecordIDs.count, 27)
        XCTAssertEqual(result.customRecordIDs.first, "Items.atomiic_sexyofficedress_shirt_black")
        XCTAssertEqual(result.customRecordIDs.last, "Items.atomiic_sexyofficedress_skirt_brownv2")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputZipPath))

        let source = try redscriptEntry(in: outputZip, path: result.redscriptEntryPath)
        XCTAssertFalse(source.isEmpty)
        for recordID in result.baseRecordIDs + result.customRecordIDs {
            XCTAssertTrue(source.contains(recordID), "Missing \(recordID)")
        }
        XCTAssertFalse(source.contains("gamedataItem_Record"))
        XCTAssertFalse(source.contains("gamedataClothing_Record"))
        XCTAssertFalse(source.contains("gamedataItem_Record_inline"))
        XCTAssertFalse(source.contains("TweakDBInterface.GetItemRecord"))
        XCTAssertFalse(source.contains("TweakDBInterface.GetRecord"))
        XCTAssertTrue(source.contains("TweakDBInterface.GetCName"))
        XCTAssertTrue(source.contains("TweakDBInterface.GetFloat"))
        XCTAssertTrue(source.contains("baseRecordsProbablyPresent"))
        XCTAssertTrue(source.contains("customRecordsProbablyPresent"))
        XCTAssertTrue(source.contains("customRecordsProbablyMissing"))
        XCTAssertFalse(source.contains("GiveItem"))
    }

    func testCompareBaseRecordsReportsUnresolvedWhenNoDefinitionsFound() throws {
        let modRoot = try makeAtomiicMod()
        let dbURL = try makeArchiveIndex(catalogs: [
            "Data_archive_Mac_content_basegame_1_engine.archive.txt": "base\\ui\\unrelated_asset.xbm\n"
        ])
        let game = try makeGameInstall()

        let report = try makeManager().compareBaseRecords(request: AddonProbeCompareBaseRecordsRequest(
            modURL: modRoot,
            outputDirectoryURL: tempDir.appendingPathComponent("compare-base-unresolved", isDirectory: true),
            cp77toolsURL: cp77toolsURL,
            gameInstall: game,
            databaseURL: dbURL
        ))

        XCTAssertEqual(report.conclusion, .unresolved)
        XCTAssertTrue(report.matchesByBaseRecord["Items.GenericInnerChestClothing"]?.isEmpty == true)
        XCTAssertTrue(report.matchesByBaseRecord["Items.Skirt"]?.isEmpty == true)
        XCTAssertTrue(report.summary.contains("likely not stored"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.reportPath))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeCompareBaseRecordsReport.self, from: data)
        XCTAssertEqual(decoded.conclusion, .unresolved)
    }

    func testTweakDBStorageLocatorDetectsPathMatchesInFakeGameBundle() throws {
        let game = try makeGameInstall()
        try write("Contents/Data/r6/cache/tweakdb/item_records.tdb", under: game.appURL, contents: "placeholder")

        let report = try makeManager().locateTweakDBStorage(request: AddonProbeTweakDBStorageLocatorRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-locator-paths", isDirectory: true),
            gameInstall: game,
            archiveIndexDatabaseURL: tempDir.appendingPathComponent("missing-index.sqlite")
        ))

        XCTAssertTrue(report.pathMatches.contains { $0.relativePath == "cache/tweakdb/item_records.tdb" })
        XCTAssertEqual(report.conclusion, .noStorageFound)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.reportPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.pathMatchesPath))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBStorageLocatorReport.self, from: data)
        XCTAssertEqual(decoded.pathMatches.count, report.pathMatches.count)
    }

    func testTweakDBStorageLocatorDetectsStringsInFakeBinaryAndTextFiles() throws {
        let game = try makeGameInstall()
        try write(
            "Contents/Data/r6/cache/item-records.txt",
            under: game.appURL,
            contents: "Items.Skirt uses OutfitSlots.LegsOuter"
        )
        let binaryURL = game.appURL.appendingPathComponent("Contents/MacOS/Cyberpunk2077")
        var binary = Data([0xFE, 0xED, 0xFA, 0xCF])
        binary.append(contentsOf: Array("TweakDBInterface GetRecord".utf8))
        try binary.write(to: binaryURL, options: [.atomic])

        let report = try makeManager().locateTweakDBStorage(request: AddonProbeTweakDBStorageLocatorRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-locator-strings", isDirectory: true),
            gameInstall: game,
            archiveIndexDatabaseURL: tempDir.appendingPathComponent("missing-index.sqlite")
        ))

        XCTAssertTrue(report.stringMatches.contains { $0.term == "Items.Skirt" && $0.fileKind == "text" })
        XCTAssertTrue(report.stringMatches.contains { $0.term == "GetRecord" && $0.fileKind == "mach-o" })
        XCTAssertTrue(report.stringMatches.contains { $0.term == "GetRecord" && $0.offsets.contains(21) })
    }

    func testTweakDBStorageLocatorClassifiesRandomTweakDBIDReferencesAsNotStorage() throws {
        let game = try makeGameInstall()
        try write(
            "Contents/Data/archive/pc/content/random_streaming_sector.ent",
            under: game.appURL,
            contents: "entity reference TweakDBID only"
        )

        let report = try makeManager().locateTweakDBStorage(request: AddonProbeTweakDBStorageLocatorRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-locator-incidental", isDirectory: true),
            gameInstall: game,
            archiveIndexDatabaseURL: tempDir.appendingPathComponent("missing-index.sqlite")
        ))

        XCTAssertTrue(report.candidateStorageFiles.isEmpty)
        XCTAssertEqual(report.conclusion, .noStorageFound)
        XCTAssertTrue(report.stringMatches.contains { $0.term == "TweakDBID" && $0.priority == .incidental && !$0.storageLike })
    }

    func testTweakDBStorageLocatorClassifiesExactBaseRecordAsHighPriorityStorageCandidate() throws {
        let game = try makeGameInstall()
        try write(
            "Contents/Data/r6/cache/item-record-store.bin",
            under: game.appURL,
            contents: "record Items.GenericInnerChestClothing placement OutfitSlots.TorsoInner"
        )

        let report = try makeManager().locateTweakDBStorage(request: AddonProbeTweakDBStorageLocatorRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-locator-base-record", isDirectory: true),
            gameInstall: game,
            archiveIndexDatabaseURL: tempDir.appendingPathComponent("missing-index.sqlite")
        ))

        let candidate = try XCTUnwrap(report.candidateStorageFiles.first)
        XCTAssertEqual(candidate.priority, .high)
        XCTAssertTrue(candidate.matchedTerms.contains("Items.GenericInnerChestClothing"))
        XCTAssertEqual(report.conclusion, .patchableArchiveRecordStoreFound)
    }

    func testRedscriptTweakDBAPIScanReportsAvailableAndMissingSymbols() throws {
        try write(
            "defs/tweakdb.reds",
            under: home.redscriptRuntimeURL,
            contents: """
            public native class TweakDBInterface {
              public static native func GetRecord(recordID: TDBID) -> ref<IScriptable>;
            }
            public native class TDBID {
              public static native func Create(value: String) -> TDBID;
            }
            public native class ItemID {
              public static native func FromTDBID(id: TDBID) -> ItemID;
            }
            public native class gamedataClothing_Record {}
            """
        )

        let report = try makeManager().redscriptTweakDBAPIScan(request: AddonProbeRedscriptTweakDBAPIScanRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("redscript-tweakdb-api-scan", isDirectory: true)
        ))

        XCTAssertTrue(report.availableSymbols.contains("TweakDBInterface.GetRecord"))
        XCTAssertTrue(report.availableSymbols.contains("TweakDBInterface.Get*"))
        XCTAssertTrue(report.availableSymbols.contains("TDBID.Create"))
        XCTAssertTrue(report.availableSymbols.contains("ItemID.FromTDBID"))
        XCTAssertTrue(report.availableSymbols.contains("gamedataClothing_Record"))
        XCTAssertTrue(report.missingSymbols.contains("gamedataItem_Record"))
        XCTAssertTrue(report.missingSymbols.contains("TweakDBInterface.GetItemRecord"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.reportPath))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeRedscriptTweakDBAPIScanReport.self, from: data)
        XCTAssertEqual(decoded.availableSymbols, report.availableSymbols)
    }

    func testTweakDBBinaryInspectExtractsStringsOffsetsAndQueryMatches() throws {
        let fake = try makeFakeTweakDBBinary(name: "tweakdb.bin", strings: [
            "Items.Skirt",
            "Items.FormalSkirt_01_basic_02",
            "BaseClothing"
        ])
        let out = tempDir.appendingPathComponent("tweakdb-bin-inspect", isDirectory: true)

        let report = try makeManager().inspectTweakDBBinary(request: AddonProbeTweakDBBinaryInspectRequest(
            fileURL: fake.url,
            outputDirectoryURL: out,
            queries: ["Items.Skirt", "Skirt"]
        ))

        XCTAssertEqual(report.magicHeaderValue, "47 db b1 0b")
        XCTAssertEqual(report.headerWords.first?.u32LE, 196205383)
        XCTAssertEqual(report.stringCount, 3)
        XCTAssertTrue(report.conclusions.contains(.plaintextRecordNamesFound))
        XCTAssertTrue(report.conclusions.contains(.queryRecordsFound))
        XCTAssertTrue(report.queryMatches.contains {
            $0.query == "Items.Skirt" &&
                $0.kind == .exactString &&
                $0.stringOffset == fake.offsets["Items.Skirt"]
        })
        XCTAssertTrue(report.queryMatches.contains {
            $0.query == "Skirt" &&
                $0.kind == .substringString &&
                $0.string == "Items.Skirt"
        })
        XCTAssertTrue(report.queryMatches.contains {
            $0.query == "Items.Skirt" &&
                $0.kind == .rawBytes &&
                $0.rawByteOffset == fake.offsets["Items.Skirt"]
        })

        let stringsTSV = try String(contentsOfFile: report.stringsTablePath, encoding: .utf8)
        XCTAssertTrue(stringsTSV.contains("\(fake.offsets["Items.Skirt"]!)\t11\tItems.Skirt"))
        let contextDump = try String(contentsOfFile: report.contextDumpsPath, encoding: .utf8)
        XCTAssertTrue(contextDump.contains("de ad be ef"))
        XCTAssertTrue(contextDump.contains("fa ce"))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBBinaryInspectReport.self, from: data)
        XCTAssertEqual(decoded.sha256, report.sha256)
    }

    func testTweakDBBinaryInspectReportsNoQueryMatches() throws {
        let fake = try makeFakeTweakDBBinary(name: "tweakdb-no-query.bin", strings: [
            "Items.TShirt_04_old_01",
            "FeetClothing"
        ])
        let report = try makeManager().inspectTweakDBBinary(request: AddonProbeTweakDBBinaryInspectRequest(
            fileURL: fake.url,
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-bin-no-query", isDirectory: true),
            queries: ["Items.DoesNotExist"]
        ))

        XCTAssertTrue(report.conclusions.contains(.noQueryRecordsFound))
        XCTAssertTrue(report.queryMatches.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.queryMatchesPath))
    }

    func testTweakDBBinaryCompareReportsSharedAndUniqueStrings() throws {
        let base = try makeFakeTweakDBBinary(name: "tweakdb-base.bin", strings: [
            "Items.Skirt",
            "Items.BaseOnly",
            "Clothing"
        ])
        let ep1 = try makeFakeTweakDBBinary(name: "tweakdb-ep1.bin", strings: [
            "Items.Skirt",
            "Items.EP1Only",
            "Clothing"
        ])

        let report = try makeManager().compareTweakDBBinaries(request: AddonProbeTweakDBBinaryCompareRequest(
            baseURL: base.url,
            ep1URL: ep1.url,
            outputDirectoryURL: tempDir.appendingPathComponent("tweakdb-bin-compare", isDirectory: true)
        ))

        XCTAssertTrue(report.headersMatch)
        XCTAssertTrue(report.sharedStrings.contains("Items.Skirt"))
        XCTAssertTrue(report.sharedStrings.contains("Clothing"))
        XCTAssertTrue(report.uniqueToBase.contains("Items.BaseOnly"))
        XCTAssertTrue(report.uniqueToEP1.contains("Items.EP1Only"))
        XCTAssertTrue(report.sharedRecordContexts.contains { $0.string == "Items.Skirt" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.stringsComparisonPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.contextComparisonPath))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBBinaryCompareReport.self, from: data)
        XCTAssertEqual(decoded.sharedStrings, report.sharedStrings)
    }

    func testTweakDBPackedStringAnalysisDetectsFixstrAndShortNames() throws {
        let build = buildPackedTweakDBBinary(packed: [
            (encoding: .fixstr, value: "Items.Skirt"),
            (encoding: .fixstr, value: "Items.TShirt_04_old_01"),
            (encoding: .fixstr, value: "Items.FormalSkirt_01_basic_02"),
            (encoding: .fixstr, value: "BaseClothing")
        ])
        try build.data.write(to: build.url, options: [.atomic])

        let report = try makeManager().analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: build.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-fixstr", isDirectory: true),
            queries: ["Items.Skirt", "Items.TShirt_04_old_01", "Items.FormalSkirt_01_basic_02"]
        ))

        XCTAssertTrue(report.conclusions.contains(.packedStringsConfirmed))
        XCTAssertTrue(report.conclusions.contains(.queryPackedStringsFound))

        let skirt = try XCTUnwrap(report.packedStrings.first { $0.string == "Items.Skirt" })
        XCTAssertEqual(skirt.encoding, .fixstr)
        XCTAssertEqual(skirt.length, 11)
        XCTAssertEqual(skirt.stringOffset, skirt.tagOffset + 1)
        XCTAssertEqual(build.data[skirt.tagOffset], 0x8b)

        let shirt = try XCTUnwrap(report.packedStrings.first { $0.string == "Items.TShirt_04_old_01" })
        XCTAssertEqual(shirt.length, 22)
        XCTAssertEqual(build.data[shirt.tagOffset], 0x96)

        let formal = try XCTUnwrap(report.packedStrings.first { $0.string == "Items.FormalSkirt_01_basic_02" })
        XCTAssertEqual(formal.length, 29)
        XCTAssertEqual(build.data[formal.tagOffset], 0x9d)

        let tsv = try String(contentsOfFile: report.packedStringsTablePath, encoding: .utf8)
        XCTAssertTrue(tsv.contains("Items.Skirt"))
        XCTAssertTrue(tsv.contains("fixstr"))
    }

    func testTweakDBPackedStringAnalysisDetectsStr8AndStr16Encodings() throws {
        let long40 = String(repeating: "A", count: 40)
        let long300 = String(repeating: "B", count: 300)
        let build = buildPackedTweakDBBinary(packed: [
            (encoding: .str8, value: long40),
            (encoding: .str16, value: long300)
        ])
        try build.data.write(to: build.url, options: [.atomic])

        let report = try makeManager().analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: build.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-str816", isDirectory: true),
            queries: [long40, long300]
        ))

        let str8 = try XCTUnwrap(report.packedStrings.first { $0.string == long40 })
        XCTAssertEqual(str8.encoding, .str8)
        XCTAssertEqual(str8.length, 40)
        XCTAssertEqual(build.data[str8.tagOffset], 0xd9)

        let str16 = try XCTUnwrap(report.packedStrings.first { $0.string == long300 })
        XCTAssertEqual(str16.encoding, .str16)
        XCTAssertEqual(str16.length, 300)
        XCTAssertEqual(build.data[str16.tagOffset], 0xda)
    }

    func testTweakDBPackedStringAnalysisFindsAbsoluteReferences() throws {
        let build = buildPackedTweakDBBinary(packed: [
            (encoding: .fixstr, value: "Items.Skirt"),
            (encoding: .fixstr, value: "Items.Other_Item_01")
        ], appendReferencesToFirstPackedString: true)
        try build.data.write(to: build.url, options: [.atomic])

        let report = try makeManager().analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: build.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-refs", isDirectory: true),
            queries: ["Items.Skirt"]
        ))

        let queryReport = try XCTUnwrap(report.queryReports.first { $0.query == "Items.Skirt" })
        XCTAssertFalse(queryReport.previousStrings.isEmpty && queryReport.nextStrings.isEmpty)
        XCTAssertEqual(queryReport.nextStrings.first?.string, "Items.Other_Item_01")
        XCTAssertTrue(queryReport.references.contains { $0.kind == .absoluteToString })
        XCTAssertTrue(queryReport.references.contains { $0.kind == .absoluteToTag })
        XCTAssertTrue(report.conclusions.contains(.queryReferencesFound))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBPackedStringAnalysisReport.self, from: data)
        XCTAssertEqual(decoded.packedStringCount, report.packedStringCount)
    }

    func testTweakDBPackedStringAnalysisRecordsNoQueryReferencesWhenAbsent() throws {
        let build = buildPackedTweakDBBinary(packed: [
            (encoding: .fixstr, value: "Items.Skirt")
        ])
        try build.data.write(to: build.url, options: [.atomic])

        let report = try makeManager().analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: build.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-no-refs", isDirectory: true),
            queries: ["Items.DoesNotExist"]
        ))

        XCTAssertTrue(report.conclusions.contains(.noQueryReferencesFound))
        XCTAssertTrue(report.queryReports.first?.packedMatches.isEmpty ?? false)
    }

    func testTweakDBPackedStringComparisonReportsBaseAndEP1Differences() throws {
        let base = buildPackedTweakDBBinary(packed: [
            (encoding: .fixstr, value: "Items.Skirt"),
            (encoding: .fixstr, value: "Items.BaseOnly")
        ])
        try base.data.write(to: base.url, options: [.atomic])
        let ep1 = buildPackedTweakDBBinary(packed: [
            (encoding: .fixstr, value: "Items.Skirt"),
            (encoding: .fixstr, value: "Items.EP1Only")
        ], name: "packed-ep1.bin")
        try ep1.data.write(to: ep1.url, options: [.atomic])

        let manager = makeManager()
        let baseReport = try manager.analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: base.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-base-out", isDirectory: true),
            queries: ["Items.Skirt"]
        ))
        let ep1Report = try manager.analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest(
            fileURL: ep1.url,
            outputDirectoryURL: tempDir.appendingPathComponent("packed-ep1-out", isDirectory: true),
            queries: ["Items.Skirt"]
        ))

        let comparison = try manager.compareTweakDBPackedStringAnalyses(request: AddonProbeTweakDBPackedStringComparisonRequest(
            baseAnalysisURL: URL(fileURLWithPath: baseReport.reportPath),
            ep1AnalysisURL: URL(fileURLWithPath: ep1Report.reportPath),
            outputDirectoryURL: tempDir.appendingPathComponent("packed-compare", isDirectory: true)
        ))

        XCTAssertTrue(comparison.sharedItemNames.contains("Items.Skirt"))
        XCTAssertTrue(comparison.baseOnlyItemNames.contains("Items.BaseOnly"))
        XCTAssertTrue(comparison.ep1OnlyItemNames.contains("Items.EP1Only"))
        XCTAssertTrue(comparison.queryDiffs.contains { $0.query == "Items.Skirt" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: comparison.comparisonTSVPath))

        let data = try JSONEncoder.cybermac.encode(comparison)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeTweakDBPackedStringComparisonReport.self, from: data)
        XCTAssertEqual(decoded.sharedItemNames, comparison.sharedItemNames)
    }

    func testAtomiicSummaryReportsShirtAndSkirtCounts() throws {
        let modRoot = try makeAtomiicMod()

        let summary = try makeManager().atomiicSummary(modURL: modRoot)

        XCTAssertEqual(summary.totalExpandedItems, 27)
        XCTAssertEqual(summary.shirtsCount, 9)
        XCTAssertEqual(summary.skirtsCount, 18)
        XCTAssertEqual(summary.factoryCSVFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv"])
        XCTAssertEqual(summary.localizationJSONFilesFromXL, ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.json"])
        XCTAssertEqual(summary.iconAtlasPaths, ["base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas"])
        XCTAssertEqual(summary.archiveFiles, ["archive/pc/mod/Atomiic_Sexy_Office_Dress_XL.archive"])
        XCTAssertTrue(summary.expectedUnresolvedLayers.contains("TweakDB item records"))
    }

    func testGrantTestManyParsesAddToInventoryAndRawItemsLines() throws {
        let parsed = AddonProbeManager.parseGrantManyItemIDs(
            """
            Game.AddToInventory("Items.Second_Item",1)
            Items.First_Item
            Game.AddToInventory('Items.Second_Item', 1)
            """
        )

        XCTAssertEqual(parsed, ["Items.Second_Item", "Items.First_Item"])
    }

    func testGrantTestManyDeduplicatesWhilePreservingOrder() throws {
        let itemsFile = tempDir.appendingPathComponent("Items Codes.txt")
        try """
        Items.Zeta
        Game.AddToInventory("Items.Alpha",1)
        Items.Zeta
        Items.Bravo
        """.write(to: itemsFile, atomically: true, encoding: .utf8)

        let result = try makeManager().grantTestMany(request: AddonProbeGrantManyRequest(
            inputURL: itemsFile,
            outputZipURL: tempDir.appendingPathComponent("grant-many.zip"),
            modName: "CyberMac Atomiic Grant All"
        ))

        XCTAssertEqual(result.itemIDs, ["Items.Zeta", "Items.Alpha", "Items.Bravo"])
        XCTAssertEqual(result.modName, "CyberMac Atomiic Grant All")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputZipPath))
    }

    func testGrantTestManyModPathCombinesExpandedYAMLAndItemsCodes() throws {
        let modRoot = try makeAtomiicMod(itemsCodes: """
        Game.AddToInventory("Items.atomiic_sexyofficedress_shirt_black",1)
        Game.AddToInventory("Items.Manual_Extra",1)
        """)

        let result = try makeManager().grantTestMany(request: AddonProbeGrantManyRequest(
            inputURL: modRoot,
            outputZipURL: tempDir.appendingPathComponent("atomiic-grant-all.zip"),
            modName: "CyberMac Atomiic Grant All"
        ))

        XCTAssertEqual(result.itemIDs.count, 28)
        XCTAssertEqual(Array(result.itemIDs.prefix(3)), [
            "Items.atomiic_sexyofficedress_shirt_black",
            "Items.atomiic_sexyofficedress_shirt_white",
            "Items.atomiic_sexyofficedress_shirt_green"
        ])
        XCTAssertEqual(result.itemIDs.last, "Items.Manual_Extra")
    }

    func testAnalyzeXLFactoryParsesXLPathsDetectsCR2WAndSummarizesDecodedAtomiicStrings() throws {
        let modRoot = try makeAtomiicMod()
        let modArchive = modRoot.appendingPathComponent("archive/pc/mod/Atomiic_Sexy_Office_Dress_XL.archive")
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            modArchive.path: [
                "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv": Data([0x43, 0x52, 0x32, 0x57, 0x01]),
                "base/atomiic/xl_stuff/atomiic_sexyofficedress.json": Data(#"{"Items.atomiic_sexyofficedress_shirt_black":"Black shirt"}"#.utf8)
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForXLAnalysis()
        let game = try makeGameInstall()

        let report = try makeManager(tooling: tooling).analyzeXLFactory(request: AddonProbeXLFactoryAnalysisRequest(
            modURL: modRoot,
            outputDirectoryURL: tempDir.appendingPathComponent("xl-analysis", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(report.conclusion, .xlFactoryDecoded)
        XCTAssertEqual(report.declaredFactoryCSVs, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(report.declaredLocalizationJSONs, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.json"])
        XCTAssertEqual(report.extractedResourceDiagnostics.first { $0.resourcePath.hasSuffix(".csv") }?.detectedMagic, .cr2w)
        XCTAssertEqual(report.extractedResourceDiagnostics.first { $0.resourcePath.hasSuffix(".json") }?.detectedMagic, .jsonText)
        let summary = try XCTUnwrap(report.factoryJSONSummaries.first)
        XCTAssertEqual(summary.compiledDataRowCount, 2)
        XCTAssertEqual(summary.dataRowCount, 1)
        XCTAssertTrue(summary.entReferences.contains("base/atomiic/entities/atomiic_sexyofficedress_shirt.ent"))
        XCTAssertTrue(summary.appReferences.contains("base/atomiic/apps/atomiic_sexyofficedress_skirt.app"))
        XCTAssertTrue(summary.atomiicStrings.contains("atomiic_sexyofficedress_shirt_w"))
        XCTAssertTrue(summary.shirtStrings.contains("atomiic_sexyofficedress_shirt_w"))
        XCTAssertTrue(summary.skirtStrings.contains("atomiic_sexyofficedress_skirt_w"))
        XCTAssertTrue(summary.slotStrings.contains("slot_01"))
        XCTAssertTrue(report.localizationSummaries.first?.localizationKeys.contains("Items.atomiic_sexyofficedress_shirt_black") == true)
        XCTAssertTrue(report.yamlComparison.matchedEntityNames.contains("atomiic_sexyofficedress_shirt_w"))
        XCTAssertTrue(report.yamlComparison.matchedIconAtlasPaths.contains("base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas"))

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeXLFactoryAnalysisReport.self, from: data)
        XCTAssertEqual(decoded.conclusion, .xlFactoryDecoded)
    }

    func testRawPatchFactoriesJSONClonesSingleStringRowPreservingSurroundingText() throws {
        let original = """
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base\\\\gameplay\\\\factories\\\\items\\\\clothing.csv"]
              ]
            }
          }
        }
        """
        let result = try AddonProbeManager.rawPatchFactoriesJSON(
            originalText: original,
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 0)
        let edited = try XCTUnwrap(result.editedJSONText)
        XCTAssertTrue(edited.hasPrefix("{\n  \"Header\": {},\n  \"Data\": {"))
        XCTAssertTrue(edited.hasSuffix("}"))
        XCTAssertTrue(edited.contains("[\"clothing\", \"base\\\\gameplay\\\\factories\\\\items\\\\clothing.csv\"]"))
        XCTAssertTrue(edited.contains("[\"clothing\", \"base\\\\atomiic\\\\xl_stuff\\\\atomiic_sexyofficedress.csv\"]"))
        XCTAssertEqual(result.clonedSourceRowText, "[\"clothing\", \"base\\\\gameplay\\\\factories\\\\items\\\\clothing.csv\"]")
        XCTAssertEqual(result.addedRowText, "[\"clothing\", \"base\\\\atomiic\\\\xl_stuff\\\\atomiic_sexyofficedress.csv\"]")
        XCTAssertNotNil(result.compiledDataInsertion)
        XCTAssertEqual(result.compiledDataInsertion?.arrayPath, "$.Data.RootChunk.compiledData")
        XCTAssertGreaterThan(result.compiledDataInsertion?.insertionLine ?? 0, 0)
        XCTAssertTrue(result.compiledDataInsertion?.context.isEmpty == false)
    }

    func testRawPatchFactoriesJSONInsertsIntoBothCompiledDataAndDataWhenBothContainSourceRow() throws {
        let original = """
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ],
              "data": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ]
            }
          }
        }
        """
        let result = try AddonProbeManager.rawPatchFactoriesJSON(
            originalText: original,
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 1)
        let edited = try XCTUnwrap(result.editedJSONText)
        let count = edited.components(separatedBy: "atomiic_sexyofficedress.csv").count - 1
        XCTAssertEqual(count, 2)
        XCTAssertNotNil(result.compiledDataInsertion)
        XCTAssertNotNil(result.dataInsertion)
        XCTAssertNotEqual(result.compiledDataInsertion?.insertionOffset, result.dataInsertion?.insertionOffset)
    }

    func testRawPatchFactoriesJSONDoesNotDuplicateExistingPath() throws {
        let original = """
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"],
                ["atomiic", "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
              ],
              "data": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ]
            }
          }
        }
        """
        let result = try AddonProbeManager.rawPatchFactoriesJSON(
            originalText: original,
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .factoryPathAlreadyPresent)
        XCTAssertEqual(result.alreadyPresentFactoryPaths, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(result.rowsAddedCompiledData, 0)
        XCTAssertEqual(result.rowsAddedData, 0)
        XCTAssertNil(result.editedJSONText)
    }

    func testRawPatchFactoriesJSONPreservesUnrelatedPrefixAndSuffixExactly() throws {
        let original = """
        {
          "Header": {"version": 42, "tag": "Cyberpunk2077"},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ],
              "data": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ]
            }
          },
          "TrailingMetadata": {"unused": true}
        }
        """
        let result = try AddonProbeManager.rawPatchFactoriesJSON(
            originalText: original,
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        let edited = try XCTUnwrap(result.editedJSONText)
        XCTAssertTrue(edited.contains("\"version\": 42, \"tag\": \"Cyberpunk2077\""))
        XCTAssertTrue(edited.contains("\"TrailingMetadata\": {\"unused\": true}"))
        XCTAssertTrue(edited.hasSuffix("}"))
        XCTAssertTrue(edited.hasPrefix("{\n  \"Header\""))
    }

    func testAddFactoryRegistryPathsToDecodedJSONAddsMissingPathToCompiledDataAndData() throws {
        let result = try AddonProbeManager.addFactoryRegistryPathsToDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["clothing", "base/gameplay/factories/items/clothing.csv"]],
                data: [["items", "base/gameplay/factories/items/items.csv"]]
            ).utf8),
            factoryPaths: ["base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.addedFactoryPaths, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 1)

        let edited = try XCTUnwrap(result.editedJSONData)
        let compiledData = try factoryRows(in: edited, key: "compiledData")
        let data = try factoryRows(in: edited, key: "data")
        XCTAssertEqual(compiledData.last?[0] as? String, "clothing")
        XCTAssertEqual(compiledData.last?[1] as? String, "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv")
        XCTAssertEqual(data.last?[0] as? String, "items")
        XCTAssertEqual(data.last?[1] as? String, "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv")
        XCTAssertEqual(result.clonedSourceRowPath, "$.Data.RootChunk.compiledData[0]")
        XCTAssertTrue(result.clonedSourceRowPreview?.contains("clothing.csv") == true)
        XCTAssertTrue(result.addedRowPreview?.contains("atomiic_sexyofficedress.csv") == true)
        XCTAssertEqual(result.compiledDataRowsBefore, 1)
        XCTAssertEqual(result.compiledDataRowsAfter, 2)
        XCTAssertEqual(result.dataRowsBefore, 1)
        XCTAssertEqual(result.dataRowsAfter, 2)
    }

    func testAddFactoryRegistryPathsToDecodedJSONClonesObjectRowsAndPreservesShape() throws {
        let json = """
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                {"factory": "clothing", "path": "base\\\\gameplay\\\\factories\\\\items\\\\clothing.csv", "enabled": true}
              ],
              "data": [
                {"factory": "items", "path": "base\\\\gameplay\\\\factories\\\\items\\\\items.csv", "enabled": true}
              ]
            }
          }
        }
        """
        let result = try AddonProbeManager.addFactoryRegistryPathsToDecodedJSON(
            Data(json.utf8),
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 1)
        let edited = try XCTUnwrap(result.editedJSONData)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: edited) as? [String: Any])
        let dataObject = try XCTUnwrap(object["Data"] as? [String: Any])
        let rootChunk = try XCTUnwrap(dataObject["RootChunk"] as? [String: Any])
        let compiledData = try XCTUnwrap(rootChunk["compiledData"] as? [[String: Any]])
        let added = try XCTUnwrap(compiledData.last)
        XCTAssertEqual(added["factory"] as? String, "clothing")
        XCTAssertEqual(added["path"] as? String, "base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv")
        XCTAssertEqual(added["enabled"] as? Bool, true)
    }

    func testAddFactoryRegistryPathsToDecodedJSONEditsCompiledDataWhenDataMissing() throws {
        let result = try AddonProbeManager.addFactoryRegistryPathsToDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["clothing", "base/gameplay/factories/items/clothing.csv"]],
                data: nil
            ).utf8),
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("$.Data.RootChunk.data is absent") })
        XCTAssertEqual(result.compiledDataRowsBefore, 1)
        XCTAssertEqual(result.compiledDataRowsAfter, 2)
        XCTAssertNil(result.dataRowsBefore)
        XCTAssertNil(result.dataRowsAfter)
    }

    func testAddFactoryRegistryPathsToDecodedJSONSkipsIncompatibleDataRows() throws {
        let result = try AddonProbeManager.addFactoryRegistryPathsToDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["clothing", "base/gameplay/factories/items/clothing.csv"]],
                data: [["base/gameplay/factories/items/items.csv"]]
            ).utf8),
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("does not have the same compatible factory row structure") })
        XCTAssertEqual(result.dataRowsBefore, 1)
        XCTAssertEqual(result.dataRowsAfter, 1)
    }

    func testAddFactoryRegistryPathsToDecodedJSONDoesNotDuplicateExistingPath() throws {
        let result = try AddonProbeManager.addFactoryRegistryPathsToDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["atomiic_sexyofficedress", "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]],
                data: [["atomiic_sexyofficedress", "base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]]
            ).utf8),
            factoryPaths: ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"]
        )

        XCTAssertEqual(result.conclusion, .factoryPathAlreadyPresent)
        XCTAssertEqual(result.alreadyPresentFactoryPaths, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(result.rowsAddedCompiledData, 0)
        XCTAssertEqual(result.rowsAddedData, 0)
        XCTAssertNil(result.editedJSONData)
    }

    func testStageXLFactoryRegistryStagesArchiveWithoutGameMutation() throws {
        let modRoot = try makeAtomiicMod()
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                "base/gameplay/factories.csv": Data("CR2W original".utf8)
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForXLRegistry()
        let originalGameArchiveSHA = try PathSafety.sha256(url: factoryArchive)

        let manifest = try makeManager(tooling: tooling).stageXLFactoryRegistry(request: AddonProbeXLFactoryRegistryStageRequest(
            modURL: modRoot,
            archivePath: AddonProbeManager.factoryLayerArchiveRelativePath,
            outputDirectoryURL: tempDir.appendingPathComponent("xl-registry-stage", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.conclusion, .stagedFactoryRegistryArchiveProduced)
        XCTAssertEqual(manifest.declaredFactoryCSVs, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(manifest.addedFactoryCSVs, ["base/atomiic/xl_stuff/atomiic_sexyofficedress.csv"])
        XCTAssertEqual(manifest.rowsAddedCompiledData, 1)
        XCTAssertEqual(manifest.rowsAddedData, 1)
        XCTAssertNotNil(manifest.decodedOriginalJson)
        XCTAssertNotNil(manifest.decodedEditedJson)
        XCTAssertNotNil(manifest.rebuiltResource)
        XCTAssertNotNil(manifest.stagedArchive)
        XCTAssertTrue(manifest.manualInstallCommand?.hasPrefix("cp ") == true)
        XCTAssertTrue(manifest.manualInstallCommand?.contains("sudo") == false)
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "serialize"] })
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "deserialize"] })
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(1)) == ["pack"] })
        XCTAssertEqual(try PathSafety.sha256(url: factoryArchive), originalGameArchiveSHA)

        let data = try JSONEncoder.cybermac.encode(manifest)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeXLFactoryRegistryStageManifest.self, from: data)
        XCTAssertEqual(decoded.conclusion, .stagedFactoryRegistryArchiveProduced)
    }

    func testStageXLFactoryRegistryReportsBaselineDeserializeFailedWhenOriginalCannotDeserialize() throws {
        let modRoot = try makeAtomiicMod()
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                "base/gameplay/factories.csv": Data("CR2W original".utf8)
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForXLRegistryBaselineFailure()

        let manifest = try makeManager(tooling: tooling).stageXLFactoryRegistry(request: AddonProbeXLFactoryRegistryStageRequest(
            modURL: modRoot,
            archivePath: AddonProbeManager.factoryLayerArchiveRelativePath,
            outputDirectoryURL: tempDir.appendingPathComponent("xl-registry-baseline-fail", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.conclusion, .baselineDeserializeFailed)
        XCTAssertNil(manifest.decodedEditedJson)
        XCTAssertNil(manifest.editedJsonPath)
        XCTAssertNil(manifest.stagedArchive)
        XCTAssertEqual(manifest.baselineDeserializeStdout, "baseline deserialize stdout\n")
        XCTAssertEqual(manifest.baselineDeserializeStderr, "baseline deserialize stderr\n")
    }

    func testStageXLFactoryRegistryDeserializeFailureManifestIncludesEditedJSONAndProcessOutput() throws {
        let modRoot = try makeAtomiicMod()
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                "base/gameplay/factories.csv": Data("CR2W original".utf8)
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForXLRegistryDeserializeFailure()

        let manifest = try makeManager(tooling: tooling).stageXLFactoryRegistry(request: AddonProbeXLFactoryRegistryStageRequest(
            modURL: modRoot,
            archivePath: AddonProbeManager.factoryLayerArchiveRelativePath,
            outputDirectoryURL: tempDir.appendingPathComponent("xl-registry-deserialize-fail", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.conclusion, .deserializeFailed)
        XCTAssertNotNil(manifest.decodedEditedJson)
        XCTAssertEqual(manifest.editedJsonPath, manifest.decodedEditedJson)
        XCTAssertEqual(manifest.deserializeStdout, "deserialize stdout\n")
        XCTAssertEqual(manifest.deserializeStderr, "deserialize stderr\n")
        XCTAssertNil(manifest.stagedArchive)
        XCTAssertNotNil(manifest.compiledDataInsertion)
        XCTAssertEqual(manifest.compiledDataInsertion?.arrayPath, "$.Data.RootChunk.compiledData")
        XCTAssertTrue(manifest.compiledDataInsertion?.context.isEmpty == false)
        XCTAssertTrue(manifest.clonedSourceRowPreview?.contains("clothing.csv") == true)
        XCTAssertTrue(manifest.addedRowPreview?.contains("atomiic_sexyofficedress.csv") == true)
    }

    func testStageAssetsIncludesCustomAndExactMatchAssetsWithoutGameMutation() throws {
        let game = try makeGameInstall()
        let backupManager = OfficialArchiveBackupManager(home: home)
        let backup = try backupManager.backup(relativeArchivePath: relativeArchivePath, gameInstall: game)
        _ = try OutfitRegistryManager(home: home).createProfile(request: OutfitProfileCreateRequest(
            id: "appearance-main",
            displayName: "Appearance Main",
            targetArchiveRelativePath: relativeArchivePath,
            backupID: backup.backupID
        ))

        let modRoot = tempDir.appendingPathComponent("AddonStageMod", isDirectory: true)
        let modArchive = try write("archive/pc/mod/addon.archive", under: modRoot, contents: "archive")
        try write(
            "r6/tweaks/items.yaml",
            under: modRoot,
            contents: """
            Items.Custom_Jacket:
              $base: Items.GenericOuterChest
              entityName: base/characters/garment/custom/jacket.ent
            """
        )
        let originalGameArchiveSHA = try PathSafety.sha256(url: archiveURL(gameInstall: game))
        let tooling = FakeAddonProbeTooling(filesByArchivePath: [
            backup.backupFilePath: [
                "base/garment/replaced.mesh": "pristine",
                "base/garment/vanilla.mesh": "vanilla"
            ],
            modArchive.path: [
                "base/garment/replaced.mesh": "replacement",
                "base/garment/custom.mesh": "custom"
            ]
        ])

        let manifest = try makeManager(tooling: tooling).stageAssets(request: AddonProbeStageAssetsRequest(
            modURL: modRoot,
            targetArchiveRelativePath: relativeArchivePath,
            profileID: "appearance-main",
            outputDirectoryURL: tempDir.appendingPathComponent("stage-out", isDirectory: true),
            cp77toolsURL: cp77toolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.extractedAssetPaths, [
            "base/garment/custom.mesh",
            "base/garment/replaced.mesh"
        ])
        XCTAssertEqual(manifest.exactMatchAssets, ["base/garment/replaced.mesh"])
        XCTAssertEqual(manifest.addedCustomAssets, ["base/garment/custom.mesh"])
        XCTAssertEqual(tooling.packedFiles["base/garment/replaced.mesh"], "replacement")
        XCTAssertEqual(tooling.packedFiles["base/garment/custom.mesh"], "custom")
        XCTAssertEqual(tooling.packedFiles["base/garment/vanilla.mesh"], "vanilla")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.stagedArchivePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.manifestPath))
        XCTAssertTrue(manifest.manualInstallCommand.contains("sudo cp"))
        XCTAssertEqual(try PathSafety.sha256(url: archiveURL(gameInstall: game)), originalGameArchiveSHA)
    }

    func testFactoryCSVDetectsItemIDsResourcePathsAndKnownVanillaItems() throws {
        let summary = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/clothing.csv",
            contents: """
            item_id,entity,appearance,slot,category
            Items.Vest_08_basic_01,base/characters/garment/vest.ent,base/characters/garment/vest.app,OuterChest,Clothing
            Items.Custom_Shirt,base/characters/garment/shirt.mesh,shirt_app,InnerChest,Clothing
            Items.Custom_Setup,base/characters/garment/setup.mlsetup,shirt_mask.xbm,Body,Garment
            """
        )

        XCTAssertEqual(summary.rowCount, 3)
        XCTAssertEqual(summary.headers, ["item_id", "entity", "appearance", "slot", "category"])
        XCTAssertTrue(summary.itemIDDetections.contains { $0.matches.contains("Items.Vest_08_basic_01") })
        XCTAssertTrue(summary.resourcePathDetections.contains { $0.matches.contains("base/characters/garment/vest.ent") })
        XCTAssertTrue(summary.resourcePathDetections.contains { $0.matches.contains("base/characters/garment/vest.app") })
        XCTAssertTrue(summary.resourcePathDetections.contains { $0.matches.contains("base/characters/garment/shirt.mesh") })
        XCTAssertTrue(summary.resourcePathDetections.contains { $0.matches.contains("base/characters/garment/setup.mlsetup") })
        XCTAssertTrue(summary.resourcePathDetections.contains { $0.matches.contains("shirt_mask.xbm") })
        XCTAssertTrue(summary.semanticDetections.contains { $0.kinds.contains("equipment areas") })
        XCTAssertEqual(summary.knownVanillaItemRows.map(\.itemID), ["Items.Vest_08_basic_01"])
    }

    func testFactoryCrossCSVReferenceAnalysisFindsExpectedLinks() throws {
        let factories = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories.csv",
            contents: """
            factory,path
            clothing,base/gameplay/factories/items/clothing.csv
            appearances,base/gameplay/factories/items/clothing_appearances.csv
            """
        )
        let items = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/items.csv",
            contents: """
            item_id,factory
            Items.Vest_08_basic_01,base/gameplay/factories/items/clothing.csv
            """
        )
        let fillerClothingRows = (1...26)
            .map { "Items.Filler_\($0),filler_app_\($0),base/characters/garment/filler_\($0).ent" }
            .joined(separator: "\n")
        let clothing = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/clothing.csv",
            contents: """
            item_id,appearance,entity
            \(fillerClothingRows)
            Items.Vest_08_basic_01,vest_app,base/characters/garment/vest.ent
            """
        )
        let appearances = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/clothing_appearances.csv",
            contents: """
            appearance,mesh
            vest_app,base/characters/garment/vest.mesh
            """
        )

        let references = AddonProbeManager.analyzeFactoryCrossCSVReferences([
            factories,
            items,
            clothing,
            appearances
        ])
        XCTAssertTrue(references.contains { $0.relationship.contains("clothing.csv references") && $0.token == "vest_app" })
        XCTAssertTrue(references.contains { $0.relationship.contains("clothing.csv references") && $0.token == "vest_app" && $0.fromRows == [27] })
        XCTAssertTrue(references.contains { $0.relationship.contains("items.csv references") && $0.token == "Items.Vest_08_basic_01" })
        XCTAssertTrue(references.contains { $0.relationship.contains("factories.csv references") && $0.token == "base/gameplay/factories/items/clothing.csv" })

        let conclusion = AddonProbeManager.concludeFactoryLayer(indexSearches: [], csvSummaries: [
            factories,
            items,
            clothing,
            appearances
        ], crossReferences: references)
        XCTAssertEqual(conclusion, .relevantToItemResourceRegistration)
    }

    func testFactoryCSVHandlesEmptyAndMalformedCSVGracefully() throws {
        let empty = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/clothing.csv",
            contents: ""
        )
        XCTAssertEqual(empty.headers, [])
        XCTAssertEqual(empty.rowCount, 0)
        XCTAssertTrue(empty.warnings.contains("CSV is empty."))

        let malformed = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/clothing.csv",
            contents: "item_id,entity\nItems.Bad,\"base/characters/garment/bad.ent"
        )
        XCTAssertEqual(malformed.headers, ["item_id", "entity"])
        XCTAssertEqual(malformed.rowCount, 1)
        XCTAssertTrue(malformed.warnings.contains { $0.contains("unterminated quoted field") })
        XCTAssertTrue(malformed.itemIDDetections.contains { $0.matches.contains("Items.Bad") })
        XCTAssertTrue(malformed.resourcePathDetections.contains { $0.matches.contains("base/characters/garment/bad.ent") })
    }

    func testFactoryLayerReportJSONEncodingWorks() throws {
        let summary = AddonProbeManager.analyzeFactoryCSV(
            resourcePath: "base/gameplay/factories/items/items.csv",
            contents: "item_id\nItems.Shirt_01_basic_01\n"
        )
        let report = AddonProbeFactoryLayerReport(
            searchedTerms: AddonProbeManager.requiredFactoryCSVResources,
            exactResourceTerms: AddonProbeManager.requiredFactoryCSVResources,
            broadSearchTerms: AddonProbeManager.factoryLayerBroadSearchTerms,
            indexDatabasePath: tempDir.appendingPathComponent("archive-index.sqlite").path,
            indexDatabaseExists: false,
            indexSearches: [],
            matchingArchiveResources: [],
            extractionArchivePath: nil,
            extractedFiles: [],
            csvSummaries: [summary],
            crossCSVReferences: [],
            warnings: ["probe only"],
            conclusion: .spawningLookupButInsufficient,
            writtenReportPath: nil
        )

        let data = try JSONEncoder.cybermac.encode(report)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeFactoryLayerReport.self, from: data)
        XCTAssertEqual(decoded.csvSummaries.first?.knownVanillaItemRows.first?.itemID, "Items.Shirt_01_basic_01")
        XCTAssertEqual(decoded.conclusion, .spawningLookupButInsufficient)
    }

    func testFactoryResourceDiagnosticsHandleBinaryMagicAndText() throws {
        let cr2w = AddonProbeManager.diagnoseFactoryResource(
            resourcePath: "base/gameplay/factories/items/clothing.csv",
            archivePath: "Data/archive/Mac/content/basegame_4_gamedata.archive",
            extractedPath: "/tmp/clothing.csv",
            data: Data([0x43, 0x52, 0x32, 0x57, 0x00])
        )
        XCTAssertEqual(cr2w.detectedMagic, .cr2w)
        XCTAssertEqual(cr2w.parseStatus, .extractedCR2W)
        XCTAssertTrue(cr2w.first32BytesHex.hasPrefix("43 52 32 57"))

        let kark = AddonProbeManager.diagnoseFactoryResource(
            resourcePath: "base/gameplay/factories/items/items.csv",
            archivePath: nil,
            extractedPath: nil,
            data: Data([0x4B, 0x41, 0x52, 0x4B, 0x00])
        )
        XCTAssertEqual(kark.detectedMagic, .kark)
        XCTAssertEqual(kark.parseStatus, .extractedKARK)

        let binary = AddonProbeManager.diagnoseFactoryResource(
            resourcePath: "base/gameplay/factories.csv",
            archivePath: nil,
            extractedPath: nil,
            data: Data([0xff, 0xfe, 0xfd])
        )
        XCTAssertEqual(binary.detectedMagic, .unknownBinary)
        XCTAssertEqual(binary.parseStatus, .extractedUnknownBinary)

        let text = AddonProbeManager.diagnoseFactoryResource(
            resourcePath: "base/gameplay/factories/items/clothing_appearances.csv",
            archivePath: nil,
            extractedPath: nil,
            data: Data("appearance,mesh\nvest,base/vest.mesh\n".utf8)
        )
        XCTAssertEqual(text.detectedMagic, .utf8Text)
        XCTAssertEqual(text.parseStatus, .parsedTextCSV)
    }

    func testInspectFactoryLayerDiagnosesCR2WWithoutCrashing() throws {
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                "base/gameplay/factories.csv": Data("factory,path\nclothing,base/gameplay/factories/items/clothing.csv\n".utf8),
                "base/gameplay/factories/items/items.csv": Data([0x4B, 0x41, 0x52, 0x4B, 0x00]),
                "base/gameplay/factories/items/clothing.csv": Data([0x43, 0x52, 0x32, 0x57, 0x01, 0x02]),
                "base/gameplay/factories/items/clothing_appearances.csv": Data([0xff, 0xfe, 0xfd])
            ]
        ])

        let report = try makeManager(tooling: tooling).inspectFactoryLayer(request: AddonProbeFactoryLayerRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("factory-report", isDirectory: true),
            cp77toolsURL: cp77toolsURL,
            gameInstall: game,
            databaseURL: tempDir.appendingPathComponent("missing.sqlite")
        ))

        XCTAssertEqual(report.resourceDiagnostics.first { $0.resourcePath.hasSuffix("clothing.csv") }?.parseStatus, .extractedCR2W)
        XCTAssertEqual(report.resourceDiagnostics.first { $0.resourcePath.hasSuffix("items.csv") }?.parseStatus, .extractedKARK)
        XCTAssertEqual(report.resourceDiagnostics.first { $0.resourcePath.hasSuffix("clothing_appearances.csv") }?.parseStatus, .extractedUnknownBinary)
        XCTAssertEqual(report.csvSummaries.first?.resourcePath, "base/gameplay/factories.csv")
        XCTAssertEqual(report.conclusion, .spawningLookupButInsufficient)

        let json = try AddonProbeFactoryLayerFormatter.formatJSON(report)
        XCTAssertTrue(json.contains("resourceDiagnostics"))
        XCTAssertTrue(json.contains("CR2W"))

        let human = AddonProbeFactoryLayerFormatter.format(report)
        XCTAssertTrue(human.contains("Resource diagnostics:"))
        XCTAssertTrue(human.contains("Factory resource is CR2W binary data"))
    }

    func testInspectFactoryLayerTryCR2WDecodeRecordsAttemptsWithoutSupportedConverter() throws {
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                "base/gameplay/factories.csv": Data([0x43, 0x52, 0x32, 0x57]),
                "base/gameplay/factories/items/items.csv": Data([0x43, 0x52, 0x32, 0x57]),
                "base/gameplay/factories/items/clothing.csv": Data([0x43, 0x52, 0x32, 0x57]),
                "base/gameplay/factories/items/clothing_appearances.csv": Data([0x43, 0x52, 0x32, 0x57])
            ]
        ])

        let report = try makeManager(tooling: tooling).inspectFactoryLayer(request: AddonProbeFactoryLayerRequest(
            outputDirectoryURL: tempDir.appendingPathComponent("factory-decode-report", isDirectory: true),
            cp77toolsURL: cp77toolsURL,
            gameInstall: game,
            databaseURL: tempDir.appendingPathComponent("missing.sqlite"),
            tryCR2WDecode: true
        ))

        XCTAssertFalse(report.decodeAttempts.isEmpty)
        XCTAssertTrue(report.decodeAttempts.contains { $0.command.contains("not-run") })
        XCTAssertTrue(report.warnings.contains { $0.contains("no supported conversion path") })
        XCTAssertEqual(report.conclusion, .cr2wDecodeRequired)
    }

    func testAnalyzeFactoryJSONDetectsNestedENTStringsAndNormalizesExamples() throws {
        let root = tempDir.appendingPathComponent("decoded-json-ent", isDirectory: true)
        try write(
            "run/decoded/base/gameplay/factories/items/clothing.csv.json",
            under: root,
            contents: """
            {
              "Header": {"name": "clothing"},
              "Data": [
                {
                  "entity": "base//characters//garment//player_outer_torso_item.ent",
                  "slot": "equipment"
                }
              ]
            }
            """
        )

        let report = try makeManager().analyzeFactoryJSON(request: AddonProbeFactoryJSONAnalysisRequest(decodedJSONRootURL: root))
        let file = try XCTUnwrap(report.files.first)

        XCTAssertEqual(file.fileName, "clothing.csv.json")
        XCTAssertEqual(file.topLevelType, "object")
        XCTAssertEqual(file.topLevelKeys, ["Data", "Header"])
        XCTAssertEqual(file.counts[".ent"], 1)
        XCTAssertEqual(file.counts["player_outer_torso_item"], 1)
        XCTAssertEqual(file.inferredRole, .clothingEquipmentEntityTemplateFactoryMapping)
        XCTAssertEqual(file.representativeMatches[".ent"]?.first?.jsonPath, "$.Data[0].entity")
        XCTAssertEqual(file.representativeMatches[".ent"]?.first?.normalizedValue, "base/characters/garment/player_outer_torso_item.ent")
    }

    func testAnalyzeFactoryJSONDetectsNestedAPPStrings() throws {
        let root = tempDir.appendingPathComponent("decoded-json-app", isDirectory: true)
        try write(
            "decoded/base/gameplay/factories/items/clothing_appearances.csv.json",
            under: root,
            contents: """
            {
              "Header": {},
              "Data": [
                {
                  "appearance": {
                    "resource": "base//characters//appearances//player_torso_item_appearances.app"
                  }
                }
              ]
            }
            """
        )

        let report = try makeManager().analyzeFactoryJSON(request: AddonProbeFactoryJSONAnalysisRequest(decodedJSONRootURL: root))
        let file = try XCTUnwrap(report.files.first)

        XCTAssertEqual(file.counts[".app"], 1)
        XCTAssertEqual(file.counts["player_torso_item_appearances"], 1)
        XCTAssertEqual(file.counts["appearance"], 1)
        XCTAssertEqual(file.inferredRole, .clothingAppearanceResourceMapping)
        XCTAssertEqual(file.representativeMatches[".app"]?.first?.normalizedValue, "base/characters/appearances/player_torso_item_appearances.app")
    }

    func testAnalyzeFactoryJSONDetectsItemsStringsAndConservativeRoles() throws {
        let root = tempDir.appendingPathComponent("decoded-json-roles", isDirectory: true)
        try write(
            "decoded/factories.csv.json",
            under: root,
            contents: #"{"Header":{},"Data":[{"factory":"base/gameplay/factories/items/clothing.csv"}]}"#
        )
        try write(
            "decoded/items.csv.json",
            under: root,
            contents: #"{"Header":{},"Data":[{"item":"Items.Custom_Jacket","entity":"base/items/misc/custom_jacket.ent"}]}"#
        )
        try write(
            "decoded/accessories.csv.json",
            under: root,
            contents: #"{"Header":{},"Data":[{"name":"plain accessory row"}]}"#
        )

        let report = try makeManager().analyzeFactoryJSON(request: AddonProbeFactoryJSONAnalysisRequest(decodedJSONRootURL: root))
        let byName = Dictionary(uniqueKeysWithValues: report.files.map { ($0.fileName, $0) })

        XCTAssertEqual(byName["factories.csv.json"]?.inferredRole, .topLevelFactoryRegistry)
        XCTAssertEqual(byName["items.csv.json"]?.counts["Items."], 1)
        XCTAssertEqual(byName["items.csv.json"]?.counts[".ent"], 1)
        XCTAssertEqual(byName["items.csv.json"]?.inferredRole, .genericItemFactoryMapping)
        XCTAssertEqual(byName["accessories.csv.json"]?.inferredRole, .unknown)
    }

    func testCloneFactoryRowInDecodedJSONClonesCompiledDataAndDataRows() throws {
        let result = try AddonProbeManager.cloneFactoryRowInDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [
                    ["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"],
                    ["player_feet_item", "base/gameplay/items/equipment/feet/player_feet_item.ent"]
                ],
                data: [
                    ["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]
                ]
            ).utf8),
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test"
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.sourceRowsFound, 2)
        XCTAssertEqual(result.sourceRowPath, "user/andrzej_zawadzki/garment_system_test_entity.ent")
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 1)

        let edited = try XCTUnwrap(result.editedJSONData)
        let compiledData = try factoryRows(in: edited, key: "compiledData")
        let data = try factoryRows(in: edited, key: "data")
        XCTAssertEqual(compiledData.count, 3)
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(compiledData.last?[0] as? String, "cybermac_probe_garment_test")
        XCTAssertEqual(compiledData.last?[1] as? String, "user/andrzej_zawadzki/garment_system_test_entity.ent")
        XCTAssertEqual(data.last?[0] as? String, "cybermac_probe_garment_test")
        XCTAssertEqual(data.last?[1] as? String, "user/andrzej_zawadzki/garment_system_test_entity.ent")
    }

    func testCloneFactoryRowInDecodedJSONReportsSourceKeyNotFound() throws {
        let result = try AddonProbeManager.cloneFactoryRowInDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["player_feet_item", "base/gameplay/items/equipment/feet/player_feet_item.ent"]],
                data: [["player_legs_item", "base/gameplay/items/equipment/legs/player_legs_item.ent"]]
            ).utf8),
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test"
        )

        XCTAssertEqual(result.conclusion, .sourceKeyNotFound)
        XCTAssertEqual(result.sourceRowsFound, 0)
        XCTAssertNil(result.editedJSONData)
        XCTAssertEqual(result.rowsAddedCompiledData, 0)
        XCTAssertEqual(result.rowsAddedData, 0)
    }

    func testCloneFactoryRowInDecodedJSONReportsNewKeyAlreadyPresent() throws {
        let result = try AddonProbeManager.cloneFactoryRowInDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [
                    ["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]
                ],
                data: [
                    ["cybermac_probe_garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]
                ]
            ).utf8),
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test"
        )

        XCTAssertEqual(result.conclusion, .newKeyAlreadyPresent)
        XCTAssertEqual(result.sourceRowsFound, 1)
        XCTAssertNil(result.editedJSONData)
        XCTAssertEqual(result.rowsAddedCompiledData, 0)
        XCTAssertEqual(result.rowsAddedData, 0)
    }

    func testCloneFactoryRowInDecodedJSONHandlesOnlyCompiledDataWithWarning() throws {
        let result = try AddonProbeManager.cloneFactoryRowInDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: [["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]],
                data: nil
            ).utf8),
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test"
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 1)
        XCTAssertEqual(result.rowsAddedData, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("$.Data.RootChunk.data is absent") })
        let edited = try XCTUnwrap(result.editedJSONData)
        XCTAssertEqual(try factoryRows(in: edited, key: "compiledData").count, 2)
    }

    func testCloneFactoryRowInDecodedJSONHandlesOnlyDataWithWarning() throws {
        let result = try AddonProbeManager.cloneFactoryRowInDecodedJSON(
            Data(factoryCloneJSON(
                compiledData: nil,
                data: [["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]]
            ).utf8),
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test"
        )

        XCTAssertEqual(result.conclusion, .unresolved)
        XCTAssertEqual(result.rowsAddedCompiledData, 0)
        XCTAssertEqual(result.rowsAddedData, 1)
        XCTAssertTrue(result.warnings.contains { $0.contains("$.Data.RootChunk.compiledData is absent") })
        let edited = try XCTUnwrap(result.editedJSONData)
        XCTAssertEqual(try factoryRows(in: edited, key: "data").count, 2)
    }

    func testFactoryRowCloneManifestJSONEncodingWorksForConclusions() throws {
        for conclusion in AddonProbeFactoryRowCloneConclusion.allCases {
            let manifest = AddonProbeFactoryRowCloneManifest(
                archive: "/tmp/basegame_4_gamedata.archive",
                resource: "base/gameplay/factories/items/clothing.csv",
                sourceKey: "garment_test",
                newKey: "cybermac_probe_garment_test",
                sourceRowsFound: 2,
                sourceRowPath: "user/andrzej_zawadzki/garment_system_test_entity.ent",
                rowsAddedCompiledData: 1,
                rowsAddedData: 1,
                decodedOriginalJson: "/tmp/clothing.csv.json",
                decodedEditedJson: "/tmp/clothing.csv.cybermac-clone.json",
                rebuiltResource: "/tmp/clothing.csv",
                stagedArchive: "/tmp/staged/basegame_4_gamedata.archive",
                originalResourceSHA256: "original",
                editedResourceSHA256: "edited",
                stagedArchiveSHA256: "staged",
                originalResourceSize: 10,
                editedResourceSize: 11,
                cp77toolsCommandsAttempted: [
                    AddonProbeFactoryRoundtripCommandAttempt(
                        command: "cp77tools convert deserialize",
                        arguments: ["convert", "deserialize"],
                        exitCode: 0,
                        stdout: "",
                        stderr: "",
                        warnings: []
                    )
                ],
                conclusion: conclusion,
                warnings: ["probe"],
                manifestPath: "/tmp/manifest.json",
                manualInstallCommand: "cp staged archive"
            )
            let data = try JSONEncoder.cybermac.encode(manifest)
            let decoded = try JSONDecoder.cybermac.decode(AddonProbeFactoryRowCloneManifest.self, from: data)
            XCTAssertEqual(decoded.conclusion, conclusion)
            XCTAssertEqual(decoded.sourceKey, "garment_test")
            XCTAssertEqual(decoded.rowsAddedCompiledData, 1)
            XCTAssertEqual(decoded.rowsAddedData, 1)
        }
    }

    func testCloneFactoryRowCommandStagesArchiveWithoutGameMutation() throws {
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let resourcePath = "base/gameplay/factories/items/clothing.csv"
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                resourcePath: Data("CR2W original".utf8)
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForCloneSuccess()
        let originalGameArchiveSHA = try PathSafety.sha256(url: factoryArchive)

        let manifest = try makeManager(tooling: tooling).cloneFactoryRow(request: AddonProbeFactoryRowCloneRequest(
            resourcePath: resourcePath,
            sourceKey: "garment_test",
            newKey: "cybermac_probe_garment_test",
            archivePath: AddonProbeManager.factoryLayerArchiveRelativePath,
            outputDirectoryURL: tempDir.appendingPathComponent("factory-clone", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.conclusion, .stagedCloneArchiveProduced)
        XCTAssertEqual(manifest.sourceRowsFound, 2)
        XCTAssertEqual(manifest.rowsAddedCompiledData, 1)
        XCTAssertEqual(manifest.rowsAddedData, 1)
        XCTAssertEqual(manifest.sourceRowPath, "user/andrzej_zawadzki/garment_system_test_entity.ent")
        XCTAssertNotNil(manifest.decodedOriginalJson)
        XCTAssertNotNil(manifest.decodedEditedJson)
        XCTAssertNotNil(manifest.rebuiltResource)
        XCTAssertNotNil(manifest.stagedArchive)
        XCTAssertNotNil(manifest.stagedArchiveSHA256)
        XCTAssertTrue(manifest.manualInstallCommand?.hasPrefix("cp ") == true)
        XCTAssertTrue(manifest.manualInstallCommand?.contains("sudo") == false)
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "serialize"] })
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "deserialize"] })
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(1)) == ["pack"] })
        XCTAssertEqual(try PathSafety.sha256(url: factoryArchive), originalGameArchiveSHA)
    }

    func testRoundtripFactoryResourceRecordsUnsupportedReverseSerializationCleanly() throws {
        let game = try makeGameInstall()
        let factoryArchive = try makeFactoryArchive(gameInstall: game)
        let resourcePath = "base/gameplay/factories/items/clothing.csv"
        let tooling = FakeAddonProbeTooling(dataByArchivePath: [
            factoryArchive.path: [
                resourcePath: Data([0x43, 0x52, 0x32, 0x57, 0x01, 0x02, 0x03, 0x04])
            ]
        ])
        let fakeCP77ToolsURL = try makeFakeCP77ToolsForDecodeOnly()
        let originalGameArchiveSHA = try PathSafety.sha256(url: factoryArchive)

        let manifest = try makeManager(tooling: tooling).roundtripFactoryResource(request: AddonProbeFactoryRoundtripRequest(
            resourcePath: resourcePath,
            archivePath: AddonProbeManager.factoryLayerArchiveRelativePath,
            outputDirectoryURL: tempDir.appendingPathComponent("factory-roundtrip", isDirectory: true),
            cp77toolsURL: fakeCP77ToolsURL,
            gameInstall: game
        ))

        XCTAssertEqual(manifest.conclusion, .decodedOnly_reserializeUnsupported)
        XCTAssertNotNil(manifest.extractedResourcePath)
        XCTAssertNotNil(manifest.decodedJSONPath)
        XCTAssertNil(manifest.reserializedCR2WPath)
        XCTAssertNil(manifest.stagedArchivePath)
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { Array($0.arguments.prefix(2)) == ["convert", "serialize"] })
        XCTAssertTrue(manifest.cp77toolsCommandsAttempted.contains { $0.arguments == ["convert", "deserialize", "--help"] })
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.manifestPath))
        XCTAssertEqual(try PathSafety.sha256(url: factoryArchive), originalGameArchiveSHA)

        let data = try JSONEncoder.cybermac.encode(manifest)
        let decoded = try JSONDecoder.cybermac.decode(AddonProbeFactoryRoundtripManifest.self, from: data)
        XCTAssertEqual(decoded.conclusion, .decodedOnly_reserializeUnsupported)
    }

    private func makeManager(tooling: any OfficialArchiveSwapTooling = FakeAddonProbeTooling()) -> AddonProbeManager {
        AddonProbeManager(
            home: home,
            tooling: tooling,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            idProvider: { "testid" }
        )
    }

    @discardableResult
    private func write(_ relativePath: String, under rootURL: URL, contents: String) throws -> URL {
        let url = relativePath
            .split(separator: "/")
            .reduce(rootURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeFakeTweakDBBinary(name: String, strings: [String]) throws -> (url: URL, offsets: [String: Int]) {
        var data = Data([0x47, 0xdb, 0xb1, 0x0b, 0x08, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        while data.count < 64 {
            data.append(0x00)
        }

        var offsets: [String: Int] = [:]
        for string in strings {
            data.append(contentsOf: [0xde, 0xad, 0xbe, 0xef])
            let offset = data.count
            data.append(contentsOf: Array(string.utf8))
            data.append(0x00)
            data.append(contentsOf: [0xfa, 0xce])
            offsets[string] = offset
        }
        if let first = strings.first, let firstOffset = offsets[first] {
            data.replaceSubrange(12..<16, with: littleEndianUInt32Bytes(UInt32(firstOffset)))
        }

        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return (url, offsets)
    }

    private struct PackedTweakDBBuild {
        let url: URL
        let data: Data
        let entries: [(encoding: AddonProbeTweakDBPackedStringEncoding, value: String, tagOffset: Int, stringOffset: Int)]
    }

    private func buildPackedTweakDBBinary(
        packed: [(encoding: AddonProbeTweakDBPackedStringEncoding, value: String)],
        appendReferencesToFirstPackedString: Bool = false,
        name: String = "packed-tweakdb.bin"
    ) -> PackedTweakDBBuild {
        var data = Data([0x47, 0xdb, 0xb1, 0x0b])
        for _ in 0..<60 { data.append(0x00) }

        var entries: [(encoding: AddonProbeTweakDBPackedStringEncoding, value: String, tagOffset: Int, stringOffset: Int)] = []
        for entry in packed {
            data.append(contentsOf: [0xde, 0xad, 0xbe, 0xef])
            let tagOffset = data.count
            let bytes = Array(entry.value.utf8)
            switch entry.encoding {
            case .fixstr:
                data.append(0x80 | UInt8(bytes.count & 0x1f))
            case .str8:
                data.append(0xd9)
                data.append(UInt8(bytes.count))
            case .str16:
                let length = bytes.count
                data.append(0xda)
                data.append(UInt8(length & 0xff))
                data.append(UInt8((length >> 8) & 0xff))
            case .str32:
                let length = bytes.count
                data.append(0xdb)
                data.append(UInt8(length & 0xff))
                data.append(UInt8((length >> 8) & 0xff))
                data.append(UInt8((length >> 16) & 0xff))
                data.append(UInt8((length >> 24) & 0xff))
            }
            let stringOffset = data.count
            data.append(contentsOf: bytes)
            entries.append((entry.encoding, entry.value, tagOffset, stringOffset))
        }

        if appendReferencesToFirstPackedString, let first = entries.first {
            for _ in 0..<8 { data.append(0x00) }
            data.append(contentsOf: littleEndianUInt32Bytes(UInt32(first.stringOffset)))
            data.append(contentsOf: littleEndianUInt32Bytes(UInt32(first.tagOffset)))
            for _ in 0..<8 { data.append(0x00) }
        }

        let url = tempDir.appendingPathComponent(name)
        return PackedTweakDBBuild(url: url, data: data, entries: entries)
    }

    private func littleEndianUInt32Bytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ]
    }

    private func factoryCloneJSON(compiledData: [[String]]?, data: [[String]]?) -> String {
        var rootChunk: [String: Any] = [:]
        if let compiledData {
            rootChunk["compiledData"] = compiledData
        }
        if let data {
            rootChunk["data"] = data
        }
        let object: [String: Any] = [
            "Header": [:],
            "Data": [
                "RootChunk": rootChunk
            ]
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: jsonData, encoding: .utf8)!
    }

    private func factoryRows(in jsonData: Data, key: String) throws -> [[Any]] {
        let object = try JSONSerialization.jsonObject(with: jsonData, options: [])
        let root = try XCTUnwrap(object as? [String: Any])
        let data = try XCTUnwrap(root["Data"] as? [String: Any])
        let rootChunk = try XCTUnwrap(data["RootChunk"] as? [String: Any])
        return try XCTUnwrap(rootChunk[key] as? [[Any]])
    }

    private func makeAtomiicMod(itemsCodes: String? = nil) throws -> URL {
        let modRoot = tempDir.appendingPathComponent("AtomiicMod-\(UUID().uuidString)", isDirectory: true)
        try write("archive/pc/mod/Atomiic_Sexy_Office_Dress_XL.archive", under: modRoot, contents: "archive")
        try write(
            "archive/pc/mod/atomiic_sexyofficedress_xl.xl",
            under: modRoot,
            contents: """
            factories:
              - base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.csv
            localization:
              onscreens:
                en-us: base\\atomiic\\xl_stuff\\atomiic_sexyofficedress.json
            """
        )
        try write(
            "r6/tweaks/atomiic/atomiic_sexyofficedress.yaml",
            under: modRoot,
            contents: "\(atomiicShirtTemplate())\n\(atomiicSkirtTemplate())"
        )
        if let itemsCodes {
            try write("Items Codes.txt", under: modRoot, contents: itemsCodes)
        }
        return modRoot
    }

    private func atomiicShirtTemplate() -> String {
        """
        Items.atomiic_sexyofficedress_shirt_${base_color}:
          $base: Items.GenericInnerChestClothing
          placementSlots:
            - !append OutfitSlots.TorsoInner
          appearanceName: atomiic_sexyofficedress_shirt_w_!${base_color}
          entityName: atomiic_sexyofficedress_shirt_w
          displayName: Atomiic Sexy Office Dress Shirt ${base_color}
          localizedDescription: Atomiic Sexy Office Dress localized description ${base_color}
          quality: Quality.Legendary
          statModifiers:
            - !append Items.IconicItem
            - !append Items.ScaleToPlayerLevel
          icon:
            atlasResourcePath: base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas
            atlasPartName: ${icon}
          $instances:
            - { base_color: black, icon: slot_01 }
            - { base_color: white, icon: slot_02 }
            - { base_color: green, icon: slot_03 }
            - { base_color: purple, icon: slot_04 }
            - { base_color: red, icon: slot_05 }
            - { base_color: blue, icon: slot_06 }
            - { base_color: blue02, icon: slot_07 }
            - { base_color: pink, icon: slot_08 }
            - { base_color: brown, icon: slot_09 }
        """
    }

    private func atomiicSkirtTemplate() -> String {
        """
        Items.atomiic_sexyofficedress_skirt_${base_color}:
          $base: Items.Skirt
          placementSlots:
            - !append OutfitSlots.LegsOuter
          appearanceName: atomiic_sexyofficedress_skirt_w_!${base_color}
          entityName: atomiic_sexyofficedress_skirt_w
          displayName: Atomiic Sexy Office Dress Skirt ${base_color}
          localizedDescription: Atomiic Sexy Office Dress localized description ${base_color}
          quality: Quality.Legendary
          statModifiers:
            - !append Items.IconicItem
            - !append Items.ScaleToPlayerLevel
          icon:
            atlasResourcePath: base\\atomiic\\icons\\atomiic_sexyofficedress.inkatlas
            atlasPartName: ${icon}
          $instances:
            - { base_color: black, icon: slot_10 }
            - { base_color: white, icon: slot_11 }
            - { base_color: green, icon: slot_12 }
            - { base_color: purple, icon: slot_13 }
            - { base_color: red, icon: slot_14 }
            - { base_color: blue, icon: slot_15 }
            - { base_color: blue02, icon: slot_16 }
            - { base_color: pink, icon: slot_17 }
            - { base_color: brown, icon: slot_18 }
            - { base_color: blackv2, icon: slot_19 }
            - { base_color: whitev2, icon: slot_20 }
            - { base_color: greenv2, icon: slot_21 }
            - { base_color: purplev2, icon: slot_22 }
            - { base_color: redv2, icon: slot_23 }
            - { base_color: bluev2, icon: slot_24 }
            - { base_color: blue02v2, icon: slot_25 }
            - { base_color: pinkv2, icon: slot_26 }
            - { base_color: brownv2, icon: slot_27 }
        """
    }

    private func makeFakeCP77ToolsForXLAnalysis() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-xl-analysis")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/atomiic_sexyofficedress.csv.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["atomiic_sexyofficedress_shirt_w", "base/atomiic/entities/atomiic_sexyofficedress_shirt.ent", "atomiic_sexyofficedress_shirt_w_!${base_color}", "slot_01", "base\\\\atomiic\\\\icons\\\\atomiic_sexyofficedress.inkatlas"],
                ["atomiic_sexyofficedress_skirt_w", "base/atomiic/apps/atomiic_sexyofficedress_skirt.app", "slot_10"]
              ],
              "data": [
                ["atomiic_sexyofficedress_shirt_w", "base/atomiic/entities/atomiic_sexyofficedress_shirt.ent", "slot_01"]
              ]
            }
          }
        }
        JSON
          exit 0
        fi
        echo "cp77tools fake xl analysis"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForXLRegistry() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-xl-registry")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/factories.csv.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ],
              "data": [
                ["items", "base/gameplay/factories/items/items.csv"]
              ]
            }
          }
        }
        JSON
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "deserialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          printf 'CR2W registry' > "$5/factories.csv"
          exit 0
        fi
        echo "cp77tools fake xl registry"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForXLRegistryDeserializeFailure() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-xl-registry-fail")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/factories.csv.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ],
              "data": [
                ["items", "base/gameplay/factories/items/items.csv"]
              ]
            }
          }
        }
        JSON
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "deserialize" ]; then
          case "$3" in
            *cybermac-xl-registry.json)
              echo "deserialize stdout"
              echo "deserialize stderr" 1>&2
              exit 2
              ;;
            *)
              mkdir -p "$5"
              printf 'CR2W baseline' > "$5/factories.csv"
              exit 0
              ;;
          esac
        fi
        echo "cp77tools fake xl registry failure"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForXLRegistryBaselineFailure() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-xl-registry-baseline-fail")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/factories.csv.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["clothing", "base/gameplay/factories/items/clothing.csv"]
              ],
              "data": [
                ["items", "base/gameplay/factories/items/items.csv"]
              ]
            }
          }
        }
        JSON
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "deserialize" ]; then
          echo "baseline deserialize stdout"
          echo "baseline deserialize stderr" 1>&2
          exit 3
        fi
        echo "cp77tools fake xl registry baseline failure"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForCloneSuccess() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-clone-success")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/clothing.csv.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "RootChunk": {
              "compiledData": [
                ["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"],
                ["player_feet_item", "base/gameplay/items/equipment/feet/player_feet_item.ent"]
              ],
              "data": [
                ["garment_test", "user/andrzej_zawadzki/garment_system_test_entity.ent"]
              ]
            }
          }
        }
        JSON
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "deserialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          printf 'CR2W edited' > "$5/clothing.csv"
          exit 0
        fi
        echo "cp77tools fake clone help"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForDecodeOnly() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-decode-only")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          printf '{"Header":{},"Data":[{"entity":"base//characters//garment//player_outer_torso_item.ent"}]}' > "$5/clothing.csv.json"
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$3" = "--help" ]; then
          echo "serialize the CR2W --outpath"
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "--help" ]; then
          echo "convert commands: serialize"
          exit 0
        fi
        if [ "$1" = "convert" ] && [ "$2" = "deserialize" ]; then
          echo "unknown subcommand deserialize"
          exit 2
        fi
        echo "cp77tools fake help"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeFakeCP77ToolsForRecordLayerDecode() throws -> URL {
        let url = tempDir.appendingPathComponent("cp77tools-record-layer-decode")
        let script = """
        #!/bin/sh
        if [ "$1" = "convert" ] && [ "$2" = "serialize" ] && [ "$4" = "--outpath" ]; then
          mkdir -p "$5"
          cat > "$5/itemRecords.tdb.json" <<'JSON'
        {
          "Header": {},
          "Data": {
            "records": [
              {
                "id": "Items.GenericInnerChestClothing",
                "placementSlots": ["OutfitSlots.TorsoInner"],
                "quality": "Quality.Legendary"
              },
              {
                "id": "Items.Skirt",
                "placementSlots": ["OutfitSlots.LegsOuter"],
                "statModifiers": ["Items.IconicItem", "Items.ScaleToPlayerLevel"]
              }
            ]
          }
        }
        JSON
          exit 0
        fi
        echo "cp77tools fake record layer decode"
        exit 0
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func createZip(_ url: URL, entries: [String: String]) throws {
        let archive = try Archive(url: url, accessMode: .create)
        for (path, contents) in entries.sorted(by: { $0.key < $1.key }) {
            let data = Data(contents.utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .none
            ) { position, size in
                let start = Int(position)
                return data.subdata(in: start..<min(start + size, data.count))
            }
        }
    }

    private func makeArchiveIndex(catalogs: [String: String]) throws -> URL {
        let catalogDir = tempDir.appendingPathComponent("record-layer-catalogs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        for (relativePath, contents) in catalogs {
            let url = catalogDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        let dbURL = tempDir.appendingPathComponent("record-layer-\(UUID().uuidString).sqlite")
        _ = try ArchiveCatalogIndexBuilder().build(options: ArchiveCatalogIndexBuildOptions(
            catalogDirectory: catalogDir,
            outputDatabase: dbURL
        ))
        return dbURL
    }

    private func redscriptEntry(in zipURL: URL, path: String) throws -> String {
        let archive = try Archive(url: zipURL, accessMode: .read)
        let entry = try XCTUnwrap(archive.first { $0.path == path })
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func makeGameInstall() throws -> GameInstall {
        let appURL = tempDir.appendingPathComponent("Cyberpunk 2077 Test.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let dataURL = contentsURL.appendingPathComponent("Data", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/Cyberpunk2077")
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        let archiveURL = archiveURL(contentsURL: contentsURL)
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "official archive".write(to: archiveURL, atomically: true, encoding: .utf8)
        try writeCodeResources(contentsURL: contentsURL)

        return GameInstall(
            appURL: appURL,
            executableURL: executableURL,
            dataURL: dataURL,
            archiveMacURL: dataURL.appendingPathComponent("archive/Mac", isDirectory: true),
            r6URL: nil,
            storefront: .macAppStore,
            displayName: "Cyberpunk 2077"
        )
    }

    @discardableResult
    private func makeFactoryArchive(gameInstall: GameInstall) throws -> URL {
        let archiveURL = gameInstall.appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent(AddonProbeManager.factoryLayerArchiveRelativePath)
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "factory archive".write(to: archiveURL, atomically: true, encoding: .utf8)
        return archiveURL
    }

    private func writeCodeResources(contentsURL: URL) throws {
        let codeSignatureURL = contentsURL.appendingPathComponent("_CodeSignature", isDirectory: true)
        try FileManager.default.createDirectory(at: codeSignatureURL, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "files2": [
                relativeArchivePath: ["hash": "fixture"]
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: codeSignatureURL.appendingPathComponent("CodeResources"), options: [.atomic])
    }

    private func archiveURL(gameInstall: GameInstall) -> URL {
        archiveURL(contentsURL: gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true))
    }

    private func archiveURL(contentsURL: URL) -> URL {
        relativeArchivePath.split(separator: "/").reduce(contentsURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}

private final class FakeAddonProbeTooling: @unchecked Sendable, OfficialArchiveSwapTooling {
    var filesByArchivePath: [String: [String: String]]
    var dataByArchivePath: [String: [String: Data]]
    private(set) var packedFiles: [String: String] = [:]

    init(filesByArchivePath: [String: [String: String]] = [:], dataByArchivePath: [String: [String: Data]] = [:]) {
        self.filesByArchivePath = filesByArchivePath
        self.dataByArchivePath = dataByArchivePath
    }

    func extractArchive(cp77toolsURL: URL, sourceArchiveURL: URL, outputDirectoryURL: URL) throws {
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        for (assetPath, contents) in filesByArchivePath[sourceArchiveURL.path, default: [:]] {
            let url = assetPath
                .split(separator: "/")
                .reduce(outputDirectoryURL) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        for (assetPath, data) in dataByArchivePath[sourceArchiveURL.path, default: [:]] {
            let url = assetPath
                .split(separator: "/")
                .reduce(outputDirectoryURL) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        }
    }

    func packArchive(cp77toolsURL: URL, extractedDirectoryURL: URL, outputArchiveURL: URL) throws {
        packedFiles = try files(under: extractedDirectoryURL)
        try FileManager.default.createDirectory(at: outputArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let summary = packedFiles.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n")
        try summary.write(to: outputArchiveURL, atomically: true, encoding: .utf8)
    }

    private func files(under rootURL: URL) throws -> [String: String] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return [:]
        }
        var result: [String: String] = [:]
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
            result[relativePath] = try String(contentsOf: url, encoding: .utf8)
        }
        return result
    }
}
