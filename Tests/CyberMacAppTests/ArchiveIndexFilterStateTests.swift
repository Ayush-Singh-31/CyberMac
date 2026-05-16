@testable import CyberMacApp
import XCTest

final class ArchiveIndexFilterStateTests: XCTestCase {
    func testDefaultFiltersAreAnyVisualWithNoPreviewToggle() {
        let state = ArchiveIndexFilterState.default

        XCTAssertEqual(state.category, .anyVisual)
        XCTAssertEqual(state.ext, .any)
        XCTAssertEqual(state.archive, "")
        XCTAssertEqual(state.query, "")
        XCTAssertFalse(state.onlyWithPreview)
        XCTAssertTrue(state.isDefault)
    }

    func testAnyVisualCategoryResolvesToExcludeAudio() {
        let state = ArchiveIndexFilterState.default

        XCTAssertNil(state.category.resolvedCategoryFilter)
        XCTAssertEqual(state.category.resolvedExcludedCategoryFilter, "audio")
    }

    func testAnyCategoryAppliesNoFilter() {
        var state = ArchiveIndexFilterState.default
        state.category = .any

        XCTAssertNil(state.category.resolvedCategoryFilter)
        XCTAssertNil(state.category.resolvedExcludedCategoryFilter)
    }

    func testSpecificCategoryResolvesToOnlyCategoryFilter() {
        var state = ArchiveIndexFilterState.default
        state.category = .specific("garment")

        XCTAssertEqual(state.category.resolvedCategoryFilter, "garment")
        XCTAssertNil(state.category.resolvedExcludedCategoryFilter)
    }

    func testExtensionSelectionResolvesCorrectly() {
        XCTAssertNil(ArchiveIndexExtensionSelection.any.resolvedExtensionFilter)
        XCTAssertEqual(
            ArchiveIndexExtensionSelection.specific("xbm").resolvedExtensionFilter,
            "xbm"
        )
    }

    func testArchiveFilterIsTrimmedAndNilWhenEmpty() {
        var state = ArchiveIndexFilterState.default
        XCTAssertNil(state.resolvedArchiveFilter)

        state.archive = "   "
        XCTAssertNil(state.resolvedArchiveFilter)

        state.archive = "  Data/archive/Mac/content/basegame_1_engine.archive  "
        XCTAssertEqual(
            state.resolvedArchiveFilter,
            "Data/archive/Mac/content/basegame_1_engine.archive"
        )
    }

    func testMutationsMakeStateNonDefault() {
        var state = ArchiveIndexFilterState.default
        state.category = .specific("makeup")
        XCTAssertFalse(state.isDefault)

        var state2 = ArchiveIndexFilterState.default
        state2.ext = .specific("mesh")
        XCTAssertFalse(state2.isDefault)

        var state3 = ArchiveIndexFilterState.default
        state3.archive = "Data/archive/Mac/ep1/ep1_main.archive"
        XCTAssertFalse(state3.isDefault)

        var state4 = ArchiveIndexFilterState.default
        state4.onlyWithPreview = true
        XCTAssertFalse(state4.isDefault)

        var state5 = ArchiveIndexFilterState.default
        state5.query = "crosshair"
        XCTAssertFalse(state5.isDefault)
    }

    func testResetRestoresDefaults() {
        var state = ArchiveIndexFilterState.default
        state.query = "lips_makeup"
        state.category = .specific("makeup")
        state.ext = .specific("xbm")
        state.archive = "Data/archive/Mac/content/basegame_1_engine.archive"
        state.onlyWithPreview = true
        XCTAssertFalse(state.isDefault)

        state.reset()

        XCTAssertEqual(state, ArchiveIndexFilterState.default)
        XCTAssertTrue(state.isDefault)
    }

    func testCategoryAllCasesIncludeAnyAnyVisualAndAllRequestedCategories() {
        let displayNames = ArchiveIndexCategorySelection.allCases.map(\.displayName)
        XCTAssertEqual(displayNames.first, "Any")
        XCTAssertEqual(displayNames[1], "Any visual (no audio)")
        for required in ["ui", "garment", "makeup", "hair", "skin", "tattoo", "weapon", "vehicle", "world", "audio", "unknown"] {
            XCTAssertTrue(displayNames.contains(required), "Missing category option: \(required)")
        }
    }

    func testExtensionAllCasesIncludeAnyAndRequestedExtensions() {
        let displayNames = ArchiveIndexExtensionSelection.allCases.map(\.displayName)
        XCTAssertEqual(displayNames.first, "Any")
        for required in ["xbm", "mesh", "mi", "mlsetup", "ent", "app", "inkatlas", "inkwidget", "inkanim", "wem"] {
            XCTAssertTrue(displayNames.contains(required), "Missing extension option: \(required)")
        }
    }
}
