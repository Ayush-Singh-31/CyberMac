import Foundation
import XCTest
import ZIPFoundation
@testable import CyberMacCore

final class RedscriptItemGrantGeneratorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacRedscriptItemGrantTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Validation

    func testRejectsEmptyItemList() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(itemIDs: [], outputZipURL: outputZipURL("a.zip"))
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("At least one --item"))
        }
    }

    func testRejectsEmptyStringItem() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(itemIDs: ["   "], outputZipURL: outputZipURL("a.zip"))
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("must not be empty"))
        }
    }

    func testRejectsItemMissingItemsPrefix() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(
                    itemIDs: ["NotPrefixed.Foo"],
                    outputZipURL: outputZipURL("a.zip")
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("must start with 'Items.'"))
        }
    }

    func testRejectsItemWithOnlyItemsPrefix() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(
                    itemIDs: ["Items."],
                    outputZipURL: outputZipURL("a.zip")
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("missing the part after 'Items.'"))
        }
    }

    func testRejectsItemWithUnsupportedCharacters() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(
                    itemIDs: ["Items.Foo Bar"],
                    outputZipURL: outputZipURL("a.zip")
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("unsupported characters"))
        }
    }

    func testRejectsItemWithQuoteInjectionAttempt() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(
                    itemIDs: ["Items.Foo\");evil(\"a"],
                    outputZipURL: outputZipURL("a.zip")
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("unsupported characters"))
        }
    }

    func testRejectsInvalidModName() {
        XCTAssertThrowsError(
            try RedscriptItemGrantGenerator().generate(
                request: RedscriptItemGrantRequest(
                    itemIDs: ["Items.Foo"],
                    outputZipURL: outputZipURL("a.zip"),
                    modName: "Bad/Name"
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("--mod-name"))
        }
    }

    // MARK: - Generation success path

    func testGeneratesZipWithExpectedEntryAndItems() throws {
        let outputURL = outputZipURL("grant.zip")
        let result = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(
                itemIDs: ["Items.Lucy_Jacket", "Items.Some_Pants"],
                outputZipURL: outputURL
            )
        )

        XCTAssertEqual(result.redscriptEntryPath, "r6/scripts/CyberMacItemGrant/CyberMacItemGrant.reds")
        XCTAssertEqual(result.modName, "CyberMacItemGrant")
        XCTAssertEqual(result.normalizedItemIDs, ["Items.Lucy_Jacket", "Items.Some_Pants"])

        let archive = try Archive(url: outputURL, accessMode: .read)
        let entries = Array(archive)
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.path, "r6/scripts/CyberMacItemGrant/CyberMacItemGrant.reds")

        var collected = Data()
        _ = try archive.extract(entry) { collected.append($0) }
        let contents = try XCTUnwrap(String(data: collected, encoding: .utf8))
        XCTAssertTrue(contents.contains("module CyberMacItemGrant"))
        XCTAssertTrue(contents.contains("@wrapMethod(PlayerPuppet)"))
        XCTAssertTrue(contents.contains("OnGameAttached"))
        XCTAssertTrue(contents.contains("GameInstance.GetTransactionSystem"))
        XCTAssertTrue(contents.contains("ItemID.FromTDBID"))
        XCTAssertTrue(contents.contains("transactionSystem.GiveItem(player, itemID, 1);"))
        XCTAssertFalse(contents.contains("LogChannel("), "Vanilla 2.5 does not provide this debug logging function")
        XCTAssertTrue(contents.contains("transactionSystem.HasItem(player, itemID)"))
        XCTAssertTrue(contents.contains("t\"Items.Lucy_Jacket\""))
        XCTAssertTrue(contents.contains("t\"Items.Some_Pants\""))
    }

    func testDeduplicatesAndPreservesItemIDOrder() throws {
        let outputURL = outputZipURL("dedup.zip")
        let result = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(
                itemIDs: ["Items.Zeta", "Items.Alpha", "Items.Zeta", "  Items.Alpha  "],
                outputZipURL: outputURL
            )
        )

        XCTAssertEqual(result.normalizedItemIDs, ["Items.Zeta", "Items.Alpha"])

        let archive = try Archive(url: outputURL, accessMode: .read)
        let entries = Array(archive)
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        var collected = Data()
        _ = try archive.extract(entry) { collected.append($0) }
        let contents = try XCTUnwrap(String(data: collected, encoding: .utf8))

        let alphaCount = countOccurrences(of: "t\"Items.Alpha\"", in: contents)
        let zetaCount = countOccurrences(of: "t\"Items.Zeta\"", in: contents)
        XCTAssertEqual(alphaCount, 1)
        XCTAssertEqual(zetaCount, 1)

        guard let alphaRange = contents.range(of: "GrantOne(transactionSystem, this, t\"Items.Alpha\""),
              let zetaRange = contents.range(of: "GrantOne(transactionSystem, this, t\"Items.Zeta\"") else {
            XCTFail("Expected GrantOne calls for both items")
            return
        }
        XCTAssertLessThan(zetaRange.lowerBound, alphaRange.lowerBound)
    }

    func testCustomModNameIsRecordedInResultAndEmbeddedInRedscript() throws {
        let outputURL = outputZipURL("named.zip")
        let result = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(
                itemIDs: ["Items.Foo"],
                outputZipURL: outputURL,
                modName: "Lucy_Jacket_Test"
            )
        )

        XCTAssertEqual(result.modName, "Lucy_Jacket_Test")
        XCTAssertTrue(result.redscriptContent.contains("Mod label: Lucy_Jacket_Test"))
        XCTAssertEqual(result.redscriptEntryPath, "r6/scripts/CyberMacItemGrant/CyberMacItemGrant.reds")
    }

    func testGenerationIsDeterministic() throws {
        let outputA = outputZipURL("deterministic-a.zip")
        let outputB = outputZipURL("deterministic-b.zip")

        let items = ["Items.Bravo", "Items.Alpha", "Items.Bravo"]
        _ = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(itemIDs: items, outputZipURL: outputA)
        )
        _ = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(itemIDs: items, outputZipURL: outputB)
        )

        let dataA = try Data(contentsOf: outputA)
        let dataB = try Data(contentsOf: outputB)
        XCTAssertEqual(dataA, dataB, "Identical inputs must produce byte-identical zip output")
    }

    func testGenerationOverwritesExistingOutputFile() throws {
        let outputURL = outputZipURL("overwrite.zip")
        try Data("stale".utf8).write(to: outputURL)

        let result = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(
                itemIDs: ["Items.Foo"],
                outputZipURL: outputURL
            )
        )

        let archive = try XCTUnwrap(Archive(url: result.outputZipURL, accessMode: .read))
        let entries = Array(archive)
        XCTAssertEqual(entries.count, 1)
    }

    func testGenerationDoesNotMutateGameOrBundleAndDoesNotRequireSudo() throws {
        let outputURL = outputZipURL("sandbox.zip")

        let sentinel = tempDir.appendingPathComponent("sentinel.txt")
        try "untouched".write(to: sentinel, atomically: true, encoding: .utf8)
        let sentinelBefore = try Data(contentsOf: sentinel)

        _ = try RedscriptItemGrantGenerator().generate(
            request: RedscriptItemGrantRequest(
                itemIDs: ["Items.Foo"],
                outputZipURL: outputURL
            )
        )

        let sentinelAfter = try Data(contentsOf: sentinel)
        XCTAssertEqual(sentinelBefore, sentinelAfter)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let zipParent = outputURL.deletingLastPathComponent()
        let siblings = try FileManager.default.contentsOfDirectory(atPath: zipParent.path)
        let allowed: Set<String> = [outputURL.lastPathComponent, "sentinel.txt"]
        for sibling in siblings {
            XCTAssertTrue(allowed.contains(sibling), "Unexpected file written to working directory: \(sibling)")
        }
    }

    // MARK: - Helpers

    private func outputZipURL(_ name: String) -> URL {
        tempDir.appendingPathComponent(name)
    }

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }
}
