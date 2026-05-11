import Foundation
import XCTest
@testable import CyberMacCore

final class InputMappingTests: XCTestCase {
    private var tempDir: URL!
    private var home: CyberMacHomeManager!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacInputMappingTests-\(UUID().uuidString)", isDirectory: true)
        home = CyberMacHomeManager(homeURL: tempDir.appendingPathComponent("home", isDirectory: true))
        try home.bootstrap()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testExtractsCyberdeckActionsHoldsAcceptedEventsAndMappings() throws {
        let extracted = try InputMappingExtractor().extract(from: fixture("insanecyberdeck_input.xml"), modID: "insane")

        XCTAssertEqual(extracted.actionNames, ["CyberdeckBoost_Hold", "CyberdeckInterruptTrace_Hold"])
        XCTAssertEqual(extracted.mappingNames, ["CyberdeckBoost", "CyberdeckInterruptTrace"])
        XCTAssertTrue(extracted.holdTimeoutsXML.contains("timeout=\"4.0\""))
        XCTAssertTrue(extracted.acceptedEventsXML.contains("CyberdeckInterruptTrace_Hold"))
        XCTAssertTrue(extracted.keyMappingsXML.contains("IK_L"))
    }

    func testExtractorMatchesUITogglesContextWithFlexibleAttributesAndIgnoresComments() throws {
        let xml = """
        <bindings>
            <!-- Find <context name="UIToggles"> and insert actions here.
            <context name="UIToggles"></context>
            -->
            <context append='true' name = 'UIToggles' priority="1">
                <action name='CyberdeckBoost_Hold' map='CyberdeckBoost' priority='-1' />
                <action map="CyberdeckInterruptTrace" priority="-1" name="CyberdeckInterruptTrace_Hold" />
            </context>
            <hold action='CyberdeckBoost_Hold' timeout='4.0' />
            <acceptedEvents action='CyberdeckBoost_Hold'>
                <event name='ButtonHold' />
            </acceptedEvents>
            <mapping type='Button' name='CyberdeckBoost'>
                <button id='IK_L' />
            </mapping>
            <mapping name="CyberdeckInterruptTrace" type="Button">
                <button id="IK_L" />
            </mapping>
        </bindings>
        """
        let url = tempDir.appendingPathComponent("flexible_input.xml")
        try write(xml, to: url)

        let extracted = try InputMappingExtractor().extract(from: url, modID: "insane")

        XCTAssertEqual(extracted.actionNames, ["CyberdeckBoost_Hold", "CyberdeckInterruptTrace_Hold"])
        XCTAssertEqual(extracted.mappingNames, ["CyberdeckBoost", "CyberdeckInterruptTrace"])
        XCTAssertFalse(extracted.actionMappingsXML.contains("Find <context"))
    }

    func testPatchesUITogglesContextWithMarker() throws {
        let mapping = try extractedMapping()
        let patched = try InputMappingPatcher().patchInputContexts(readFixture("inputContexts_mac.xml"), mapping: mapping)

        XCTAssertTrue(patched.contains("CyberMac BEGIN input modID=insane section=UITogglesActions"))
        XCTAssertTrue(patched.contains("<action name=\"CyberdeckBoost_Hold\" map=\"CyberdeckBoost\" priority=\"-1\" />"))
        XCTAssertLessThan(
            try XCTUnwrap(patched.range(of: "section=UITogglesActions")?.lowerBound),
            try XCTUnwrap(patched.range(of: "<hold action=\"PhotoMode_Hold\"")?.lowerBound)
        )
    }

    func testPatchesHoldTimeoutsAfterLastHold() throws {
        let mapping = try extractedMapping()
        let patched = try InputMappingPatcher().patchInputContexts(readFixture("inputContexts_mac.xml"), mapping: mapping)

        XCTAssertTrue(patched.contains("section=HoldTimeouts"))
        XCTAssertLessThan(
            try XCTUnwrap(patched.range(of: "<hold action=\"Inventory_Hold\"")?.lowerBound),
            try XCTUnwrap(patched.range(of: "section=HoldTimeouts")?.lowerBound)
        )
    }

    func testPatchesAcceptedEventsAfterLastAcceptedEvents() throws {
        let mapping = try extractedMapping()
        let patched = try InputMappingPatcher().patchInputContexts(readFixture("inputContexts_mac.xml"), mapping: mapping)

        XCTAssertTrue(patched.contains("section=AcceptedEvents"))
        XCTAssertLessThan(
            try XCTUnwrap(patched.range(of: "<acceptedEvents action=\"Inventory_Hold\"")?.lowerBound),
            try XCTUnwrap(patched.range(of: "section=AcceptedEvents")?.lowerBound)
        )
    }

    func testPatchesUserMappingsBeforeFinalBindings() throws {
        let mapping = try extractedMapping()
        let patched = try InputMappingPatcher().patchInputUserMappings(readFixture("inputUserMappings.xml"), mapping: mapping)

        XCTAssertTrue(patched.contains("CyberMac BEGIN input modID=insane section=KeyMappings"))
        XCTAssertTrue(patched.contains("<mapping name=\"CyberdeckBoost\" type=\"Button\">"))
        XCTAssertLessThan(
            try XCTUnwrap(patched.range(of: "section=KeyMappings")?.lowerBound),
            try XCTUnwrap(patched.range(of: "</bindings>", options: .backwards)?.lowerBound)
        )
    }

    func testRefusesDuplicateCyberMacMarker() throws {
        let mapping = try extractedMapping()
        let patcher = InputMappingPatcher()
        let once = try patcher.patchInputContexts(readFixture("inputContexts_mac.xml"), mapping: mapping)
        let twice = try patcher.patchInputContexts(once, mapping: mapping)

        XCTAssertEqual(countOccurrences(of: "CyberMac BEGIN input modID=insane section=UITogglesActions", in: twice), 1)
    }

    func testRefusesExistingManualMappingWithoutMarker() throws {
        let mapping = try extractedMapping()
        let manual = try readFixture("inputContexts_mac.xml")
            .replacingOccurrences(of: "</bindings>", with: "<hold action=\"CyberdeckBoost_Hold\" timeout=\"1.0\" />\n</bindings>")

        XCTAssertThrowsError(try InputMappingPatcher().patchInputContexts(manual, mapping: mapping))
    }

    func testRefusesMissingUIToggles() throws {
        let mapping = try extractedMapping()
        let missing = try readFixture("inputContexts_mac.xml")
            .replacingOccurrences(of: "UIToggles", with: "OtherContext")

        XCTAssertThrowsError(try InputMappingPatcher().patchInputContexts(missing, mapping: mapping))
    }

    func testRefusesMissingBindings() throws {
        let mapping = try extractedMapping()
        let missing = try readFixture("inputUserMappings.xml")
            .replacingOccurrences(of: "</bindings>", with: "")

        XCTAssertThrowsError(try InputMappingPatcher().patchInputUserMappings(missing, mapping: mapping))
    }

    func testInputConfigBackupCopiesBothFiles() throws {
        let game = try makeGameApp()
        let backup = try InputConfigBackupManager(home: home).backup(gameInstall: game, modIDs: ["insane"])

        XCTAssertEqual(backup.files.count, 2)
        for file in backup.files {
            XCTAssertEqual(file.priorState, .present)
            XCTAssertNotNil(file.sha256)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(file.backupPath)))
        }
    }

    func testInputConfigRestoreCommandsAreQuoted() throws {
        let game = try makeGameApp()
        let backup = try InputConfigBackupManager(home: home).backup(gameInstall: game, modIDs: ["insane"])
        let commands = try InputConfigBackupManager(home: home).restoreCommands(id: backup.id, gameInstall: game)

        XCTAssertEqual(commands.count, 2)
        XCTAssertTrue(commands.allSatisfy { $0.contains("sudo cp \"") })
        XCTAssertTrue(commands.contains { $0.contains("Cyberpunk 2077: Ultimate.app") })
    }

    func testInputPatchVerifyMatchesExpectedHashes() throws {
        let game = try makeGameApp()
        try saveInputMod(id: "insane")
        let manager = InputMappingManager(home: home)
        let prepared = try manager.preparePatch(gameInstall: game, modIDs: ["insane"])

        try replaceFile(at: manager.inputContextsTarget(gameInstall: game), with: URL(fileURLWithPath: prepared.generatedContextPath))
        try replaceFile(at: manager.inputUserMappingsTarget(gameInstall: game), with: URL(fileURLWithPath: prepared.generatedUserMappingsPath))

        let verified = try manager.verifyPatch(gameInstall: game)
        XCTAssertTrue(verified.matched)
        XCTAssertTrue(verified.mismatches.isEmpty)
        XCTAssertEqual(try ManifestStore(home: home).load(id: "insane").inputPatchState, .active)
    }

    func testInputPatchVerifyReportsMismatch() throws {
        let game = try makeGameApp()
        try saveInputMod(id: "insane")
        let manager = InputMappingManager(home: home)
        _ = try manager.preparePatch(gameInstall: game, modIDs: ["insane"])

        let verified = try manager.verifyPatch(gameInstall: game)
        XCTAssertFalse(verified.matched)
        XCTAssertFalse(verified.mismatches.isEmpty)
        XCTAssertEqual(try ManifestStore(home: home).load(id: "insane").inputPatchState, .failed)
    }

    private func extractedMapping() throws -> ExtractedInputMapping {
        try InputMappingExtractor().extract(from: fixture("insanecyberdeck_input.xml"), modID: "insane")
    }

    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent(name)
    }

    private func readFixture(_ name: String) throws -> String {
        try String(contentsOf: fixture(name), encoding: .utf8)
    }

    private func makeGameApp() throws -> GameInstall {
        let app = tempDir.appendingPathComponent("Cyberpunk 2077: Ultimate.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let data = contents.appendingPathComponent("Data", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let receiptDir = contents.appendingPathComponent("_MASReceipt", isDirectory: true)
        let config = data.appendingPathComponent("r6/config", isDirectory: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: receiptDir, withIntermediateDirectories: true)
        let executable = macOS.appendingPathComponent("Cyberpunk2077")
        try write("game-executable", to: executable)
        try write("receipt", to: receiptDir.appendingPathComponent("receipt"))
        try FileManager.default.copyItem(at: fixture("inputContexts_mac.xml"), to: config.appendingPathComponent("inputContexts_mac.xml"))
        try FileManager.default.copyItem(at: fixture("inputUserMappings.xml"), to: config.appendingPathComponent("inputUserMappings.xml"))
        let plist: [String: String] = [
            "CFBundleIdentifier": "com.cdprojektred.cyberpunk2077",
            "CFBundleShortVersionString": "2.2",
            "CFBundleVersion": "100"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        return GameInstall(
            appURL: app,
            executableURL: executable,
            dataURL: data,
            archiveMacURL: nil,
            r6URL: data.appendingPathComponent("r6", isDirectory: true),
            storefront: .macAppStore,
            displayName: "Cyberpunk 2077"
        )
    }

    private func saveInputMod(id: String) throws {
        let scriptRoot = home.overlayScriptsURL.appendingPathComponent(id, isDirectory: true)
        let inputRoot = home.overlayInputURL.appendingPathComponent(id, isDirectory: true)
        let script = scriptRoot.appendingPathComponent("InsaneCyberdeck.reds")
        let input = inputRoot.appendingPathComponent("insanecyberdeck_input.xml")
        try write("script", to: script)
        try FileManager.default.createDirectory(at: inputRoot, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture("insanecyberdeck_input.xml"), to: input)
        let manifest = InstalledModManifest(
            id: id,
            displayName: "InsaneCyberdeck",
            type: .redscriptInput,
            status: .enabled,
            sourceArchive: "/tmp/InsaneCyberdeck.zip",
            installedAt: Date(),
            gameAppPath: "/tmp/Cyberpunk.app",
            installMode: "sidecar_overlay",
            installedFiles: [
                InstalledFileRecord(sourceInArchive: "r6/scripts/InsaneCyberdeck.reds", installedPath: script.path, sizeBytes: try PathSafety.fileSize(url: script), sha256: try PathSafety.sha256(url: script))
            ],
            inputMappingFiles: [
                InstalledFileRecord(sourceInArchive: "r6/input/insanecyberdeck_input.xml", installedPath: input.path, sizeBytes: try PathSafety.fileSize(url: input), sha256: try PathSafety.sha256(url: input))
            ],
            inputPatchState: .required,
            requiresInputMappingPatch: true,
            detectedDependencies: ["redscript", "input-mapping"],
            compatibilityStatus: .supported
        )
        try ManifestStore(home: home).save(manifest)
    }

    private func replaceFile(at target: URL, with source: URL) throws {
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: source, to: target)
    }

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func write(_ string: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}
