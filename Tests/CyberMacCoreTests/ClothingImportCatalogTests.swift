import Foundation
import XCTest
@testable import CyberMacCore

final class ClothingImportCatalogTests: XCTestCase {
    func testRepeatedArchiveContentsProduceOneSelectableItem() {
        let piece = ModPackageContents.Piece(id: "Items.Same", name: "Same garment", requiresConversion: true)
        let contents = ModPackageContents(archives: [.init(path: "A.archive", preparedPieces: [piece]), .init(path: "Copy/A.archive", preparedPieces: [piece])])
        XCTAssertEqual(ClothingImportCatalog(contents: contents, wardrobe: nil).items.count, 1)
    }
    func testDiscoveredAdditionIsSelectableWithoutARegisteredWardrobeOrPreview() throws {
        let contents = ModPackageContents(archives: [.init(path: "My Clothes/Pink.archive", preparedPieces: [
            .init(id: "Items.CyberMac_Import_abcd", name: "Pink heels", requiresConversion: true)
        ])])
        let catalog = ClothingImportCatalog(contents: contents, wardrobe: nil)
        XCTAssertEqual(catalog.availableItems.count, 1)
        XCTAssertNil(catalog.items[0].previewURL)
        XCTAssertNoThrow(try catalog.validateSelection(["Items.CyberMac_Import_abcd"]))
    }
    private func contents() -> ModPackageContents {
        ModPackageContents(archives: [
            .init(path: "Jinguji/Tops/corset.archive", preparedPieces: [.init(id: "Items.Corset", name: "Corset")]),
            .init(path: "Jinguji/Legs/pants.archive", preparedPieces: [.init(id: "Items.Pants", name: "Pants")]),
            .init(path: "Jinguji/Feet/heels.archive", preparedPieces: [.init(id: "Items.Heels", name: "Heels")]),
            .init(path: "Jinguji/Tops/other.archive", preparedPieces: [])
        ])
    }
    private func wardrobe() -> ClothingWardrobe {
        let items = contents().preparedPieces.map {
            ClothingWardrobeItem(id: $0.id, name: $0.name, collection: "Jinguji", slot: "Fixture", previewURL: URL(fileURLWithPath: "/private/tmp/\($0.id).png"))
        }
        return ClothingWardrobe(workspace: URL(fileURLWithPath: "/private/tmp/wardrobe"), gameApp: "Fixture.app", items: items,
            selectedRecords: Set(items.map(\.id)), previewStyle: "Fixture")
    }

    func testCatalogUsesTheMatchingGarmentPreviewAndIncludesUnconvertedVariants() throws {
        let catalog = ClothingImportCatalog(contents: contents(), wardrobe: wardrobe())
        XCTAssertEqual(catalog.items.count, 4)
        XCTAssertEqual(catalog.availableItems.count, 3)
        XCTAssertEqual(catalog.availableItems.first { $0.record == "Items.Pants" }?.previewURL?.lastPathComponent, "Items.Pants.png")
        let unconverted = try XCTUnwrap(catalog.items.first { $0.archivePath.hasSuffix("other.archive") })
        XCTAssertFalse(unconverted.canSelect)
        XCTAssertNil(unconverted.previewURL)
        XCTAssertNotNil(unconverted.unavailableReason)
    }

    func testMissingWardrobeNeverMakesUnpreparedGarmentsSelectable() {
        let catalog = ClothingImportCatalog(contents: contents(), wardrobe: nil)
        XCTAssertEqual(catalog.items.count, 4)
        XCTAssertTrue(catalog.availableItems.isEmpty)
    }

    func testChoosingPantsRemovesUncheckedGarmentsFromSamePackageAndKeepsOtherPacks() throws {
        let records = try ClothingImportCatalog.replacingPackageSelection(contents: contents(), selected: ["Items.Pants"],
            existing: ["Items.Corset", "Items.Pants", "Items.Heels", "Items.LucyJacket"])
        XCTAssertEqual(records, ["Items.LucyJacket", "Items.Pants"])
    }

    func testEmptyDuplicateAndForeignSelectionsAreRejected() {
        let catalog = ClothingImportCatalog(contents: contents(), wardrobe: wardrobe())
        for records in [[], ["Items.Pants", "Items.Pants"], ["Items.Other"], ["archive:Jinguji/Tops/other.archive"]] {
            XCTAssertThrowsError(try catalog.validateSelection(records))
            XCTAssertThrowsError(try ClothingImportCatalog.replacingPackageSelection(contents: contents(), selected: records, existing: []))
        }
    }

    func testClothingDetectionDoesNotTreatOtherArchiveModsAsClothes() {
        XCTAssertTrue(contents().isClothingCollection)
        XCTAssertTrue(ModPackageContents(archives: [.init(path: "Clothing/Tops/red.archive", preparedPieces: [])]).isClothingCollection)
        XCTAssertFalse(ModPackageContents(archives: [.init(path: "UI/brackets.archive", preparedPieces: [])]).isClothingCollection)
    }

    func testLocalJingujiDropRequiresChoiceWithoutPreparingOrDetectingGame() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let zip = root.deletingLastPathComponent().appendingPathComponent("Resources/JingujiAllInOne.zip")
        guard FileManager.default.fileExists(atPath: zip.path) else { throw XCTSkip("Local clothing ZIP not bundled.") }
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        guard case .clothingSelectionRequired = try AutomaticModInstaller(home: .init(homeURL: home)).prepare(zip) else {
            return XCTFail("A clothing drop must stop before applying any selection")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.path))
    }
}
