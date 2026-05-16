@testable import CyberMacApp
import XCTest

final class ArchiveLabContentTests: XCTestCase {
    func testCommandSnippetsIncludeArchiveResearchWorkflows() {
        let commands = ArchiveLabCommandSnippet.all.map(\.command).joined(separator: "\n")

        XCTAssertTrue(commands.contains("archive-patch status Data/archive/Mac/content/basegame_1_engine.archive"))
        XCTAssertTrue(commands.contains("archive-patch backup-official Data/archive/Mac/content/basegame_1_engine.archive"))
        XCTAssertTrue(commands.contains("archive-catalog search crosshair"))
        XCTAssertTrue(commands.contains("--catalog-dir \"$PROBE/catalog/archiveinfo\""))
        XCTAssertTrue(commands.contains("archive-patch stage-merge Data/archive/Mac/content/basegame_1_engine.archive"))
        XCTAssertTrue(commands.contains("--mod-archive \"/path/to/mod.archive\""))
        XCTAssertTrue(commands.contains("--cp77tools \"$HOME/.dotnet-x64/tools/cp77tools\""))
    }

    func testBlockedFrameworkContentIncludesKnownBlockedRuntimes() {
        let blockedClassificationText = ArchiveLabClassificationItem.all
            .filter { $0.badge == .blocked }
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
        let scopeText = ArchiveLabContent.scopeLines.joined(separator: " ")
        let blockedText = "\(blockedClassificationText) \(scopeText)"

        for term in ["ArchiveXL", "TweakXL", "Codeware", "RED4ext", "Equipment-EX", "CET"] {
            XCTAssertTrue(blockedText.contains(term), "Expected blocked content to mention \(term)")
        }
    }

    func testProofItemsIncludeTextureAndMeleeHUDProofs() {
        let proofText = ArchiveLabProofItem.all
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")

        XCTAssertTrue(proofText.contains("UI texture proof"))
        XCTAssertTrue(proofText.contains("basegame_1_engine.archive menu .xbm swap changed the main menu"))
        XCTAssertTrue(proofText.contains("Melee HUD Replacer"))
        XCTAssertTrue(proofText.contains("exact-path merged into basegame_1_engine.archive and worked in-game"))
    }
}
