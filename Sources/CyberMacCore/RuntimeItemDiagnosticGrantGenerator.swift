import Foundation
import ZIPFoundation

public struct RedscriptRuntimeCNameCheck: Codable, Equatable, Sendable {
    public let record: String
    public let property: String
    public let expectedValue: String

    public init(record: String, property: String, expectedValue: String) {
        self.record = record
        self.property = property
        self.expectedValue = expectedValue
    }
}

public struct RedscriptRuntimeItemDiagnosticGrantRequest: Equatable, Sendable {
    public let itemIDs: [String]
    public let outputZipURL: URL
    public let modName: String?
    public let moneyMarkers: Bool
    public let cNameChecks: [RedscriptRuntimeCNameCheck]

    public init(
        itemIDs: [String],
        outputZipURL: URL,
        modName: String? = nil,
        moneyMarkers: Bool = false,
        cNameChecks: [RedscriptRuntimeCNameCheck] = []
    ) {
        self.itemIDs = itemIDs
        self.outputZipURL = outputZipURL
        self.modName = modName
        self.moneyMarkers = moneyMarkers
        self.cNameChecks = cNameChecks
    }
}

public struct RedscriptRuntimeItemDiagnosticGrantResult: Equatable, Sendable {
    public static let redscriptEntryPath = "r6/scripts/CyberMacItemDiag/CyberMacItemDiag.reds"

    public let outputZipURL: URL
    public let summaryURL: URL
    public let redscriptEntryPath: String
    public let normalizedItemIDs: [String]
    public let expectedTweakDBIDHexByItemID: [String: String]
    public let modName: String
    public let moneyMarkers: Bool
    public let cNameChecks: [RedscriptRuntimeCNameCheck]
    public let moneyMarkerLegend: [String]
    public let moneyMarkerInterpretationExamples: [String]
    public let redscriptContent: String
    public let redscriptSizeBytes: Int
    public let summaryContent: String

    public init(
        outputZipURL: URL,
        summaryURL: URL,
        redscriptEntryPath: String,
        normalizedItemIDs: [String],
        expectedTweakDBIDHexByItemID: [String: String],
        modName: String,
        moneyMarkers: Bool,
        cNameChecks: [RedscriptRuntimeCNameCheck],
        moneyMarkerLegend: [String],
        moneyMarkerInterpretationExamples: [String],
        redscriptContent: String,
        redscriptSizeBytes: Int,
        summaryContent: String
    ) {
        self.outputZipURL = outputZipURL
        self.summaryURL = summaryURL
        self.redscriptEntryPath = redscriptEntryPath
        self.normalizedItemIDs = normalizedItemIDs
        self.expectedTweakDBIDHexByItemID = expectedTweakDBIDHexByItemID
        self.modName = modName
        self.moneyMarkers = moneyMarkers
        self.cNameChecks = cNameChecks
        self.moneyMarkerLegend = moneyMarkerLegend
        self.moneyMarkerInterpretationExamples = moneyMarkerInterpretationExamples
        self.redscriptContent = redscriptContent
        self.redscriptSizeBytes = redscriptSizeBytes
        self.summaryContent = summaryContent
    }
}

public struct RedscriptRuntimeItemDiagnosticGrantGenerator: Sendable {
    public static let defaultModName = "CyberMacItemDiag"

    private static let deterministicTimestamp = Date(timeIntervalSince1970: 1_704_067_200)
    private static let moneyMarkerLegend: [String] = [
        "+700000 trigger entered",
        "+11000 clone appearanceName is visible",
        "+12000 clone appearanceName is __missing",
        "+2100 clone entityName is visible",
        "+2200 clone entityName is __missing",
        "+310 clone inventory count increased after GiveItem",
        "+320 clone inventory count did not increase after GiveItem",
        "+41 clone isGarment is true",
        "+42 clone isGarment is false",
        "+51 clone canDrop is true",
        "+52 clone canDrop is false",
        "+5000 checked existing CName equals expected value",
        "+6000 checked existing CName does not equal expected value"
    ]
    private static let moneyMarkerInterpretationExamples: [String] = [
        "+713514 = trigger entered, appearance visible, entity visible, clone inventory did not increase, isGarment false, canDrop false",
        "+714612 = trigger entered, appearance missing, entity missing, clone inventory did not increase, isGarment true, canDrop true",
        "+719612 = same as +714612 plus existing CName check matched",
        "+720612 = same as +714612 plus existing CName check did not match"
    ]

    public init() {}

    public func generate(request: RedscriptRuntimeItemDiagnosticGrantRequest) throws -> RedscriptRuntimeItemDiagnosticGrantResult {
        let normalizedItemIDs = try RedscriptItemGrantGenerator.normalizeItemIDs(request.itemIDs)
        if request.moneyMarkers, !(normalizedItemIDs.count == 1 || normalizedItemIDs.count == 2) {
            throw CyberMacError.invalidInput("--money-markers requires one --item value for the item under test, or two --item values with the vanilla proof item first and clone item second")
        }
        if !request.moneyMarkers, !request.cNameChecks.isEmpty {
            throw CyberMacError.invalidInput("--check-cname is only supported with --money-markers")
        }
        try request.cNameChecks.forEach(Self.validateCNameCheck)
        let modName = try Self.normalizeModName(request.modName)
        let expectedHashes = Dictionary(uniqueKeysWithValues: normalizedItemIDs.map { ($0, Self.tweakDBIDHex($0)) })

        let redscriptSource = Self.renderRedscript(
            itemIDs: normalizedItemIDs,
            expectedTweakDBIDHexByItemID: expectedHashes,
            modName: modName,
            moneyMarkers: request.moneyMarkers,
            cNameChecks: request.cNameChecks
        )
        let redscriptData = Data(redscriptSource.utf8)
        let summaryURL = Self.summaryURL(for: request.outputZipURL)
        let summaryContent = Self.renderSummary(
            outputZipURL: request.outputZipURL,
            summaryURL: summaryURL,
            itemIDs: normalizedItemIDs,
            expectedTweakDBIDHexByItemID: expectedHashes,
            modName: modName,
            redscriptSizeBytes: redscriptData.count,
            moneyMarkers: request.moneyMarkers,
            cNameChecks: request.cNameChecks
        )

        try Self.prepareOutputLocation(outputZipURL: request.outputZipURL)

        let archive: Archive
        do {
            archive = try Archive(url: request.outputZipURL, accessMode: .create)
        } catch {
            throw CyberMacError.fileSystem("Could not create zip at \(request.outputZipURL.path): \(error.localizedDescription)")
        }

        do {
            try archive.addEntry(
                with: RedscriptRuntimeItemDiagnosticGrantResult.redscriptEntryPath,
                type: .file,
                uncompressedSize: Int64(redscriptData.count),
                modificationDate: Self.deterministicTimestamp,
                permissions: 0o644,
                compressionMethod: .none
            ) { position, size in
                let start = Int(position)
                let end = min(start + size, redscriptData.count)
                return redscriptData.subdata(in: start..<end)
            }
            try Data(summaryContent.utf8).write(to: summaryURL, options: [.atomic])
        } catch {
            try? FileManager.default.removeItem(at: request.outputZipURL)
            throw CyberMacError.fileSystem("Failed to write runtime item diagnostic output: \(error.localizedDescription)")
        }

        return RedscriptRuntimeItemDiagnosticGrantResult(
            outputZipURL: request.outputZipURL,
            summaryURL: summaryURL,
            redscriptEntryPath: RedscriptRuntimeItemDiagnosticGrantResult.redscriptEntryPath,
            normalizedItemIDs: normalizedItemIDs,
            expectedTweakDBIDHexByItemID: expectedHashes,
            modName: modName,
            moneyMarkers: request.moneyMarkers,
            cNameChecks: request.cNameChecks,
            moneyMarkerLegend: request.moneyMarkers ? Self.moneyMarkerLegend : [],
            moneyMarkerInterpretationExamples: request.moneyMarkers ? Self.moneyMarkerInterpretationExamples : [],
            redscriptContent: redscriptSource,
            redscriptSizeBytes: redscriptData.count,
            summaryContent: summaryContent
        )
    }

    static func renderRedscript(
        itemIDs: [String],
        expectedTweakDBIDHexByItemID: [String: String],
        modName: String,
        moneyMarkers: Bool,
        cNameChecks: [RedscriptRuntimeCNameCheck]
    ) -> String {
        let modeLabel: String
        let diagnosticCalls: String
        if moneyMarkers {
            let proofItemID = itemIDs.count == 2 ? itemIDs[0] : nil
            let cloneItemID = itemIDs.count == 2 ? itemIDs[1] : itemIDs[0]
            let cloneExpectedHash = expectedTweakDBIDHexByItemID[cloneItemID] ?? Self.tweakDBIDHex(cloneItemID)
            let proofCall = proofItemID.map {
                "  CyberMacItemDiagHelper.GrantProofItem(transactionSystem, this, t\"\($0)\", n\"\($0)\");"
            } ?? "  LogChannel(n\"DEBUG\", s\"[CyberMacItemDiag] one-item money marker mode; skipping vanilla proof grant\");"
            let cNameCheckCalls = cNameChecks
                .map { check in
                    "  CyberMacItemDiagHelper.CheckCNameMarker(transactionSystem, this, t\"\(check.record)\", t\".\(check.property)\", n\"\(check.expectedValue)\", n\"\(check.record).\(check.property)\");"
                }
                .joined(separator: "\n")
            modeLabel = "money markers enabled"
            diagnosticCalls = """
            \(proofCall)
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, this, 700000);
            \(cNameCheckCalls)
              CyberMacItemDiagHelper.ProbeCloneWithMoneyMarkers(transactionSystem, this, t"\(cloneItemID)", n"\(cloneItemID)", "\(cloneExpectedHash)");
            """
        } else {
            modeLabel = "log-only"
            diagnosticCalls = itemIDs
                .map { itemID in
                    let expectedHash = expectedTweakDBIDHexByItemID[itemID] ?? Self.tweakDBIDHex(itemID)
                    return "  CyberMacItemDiagHelper.ProbeOne(transactionSystem, this, t\"\(itemID)\", n\"\(itemID)\", \"\(expectedHash)\");"
                }
                .joined(separator: "\n")
        }

        return """
        module CyberMacItemDiag

        // Generated by CyberMac. Do not edit manually.
        // Runtime diagnostic for TweakDB item flat visibility and GiveItem behavior.
        // Uses vanilla redscript APIs only - no CET, RED4ext, Codeware, ArchiveXL, or TweakXL.
        //
        // Mod label: \(modName)
        // Item count: \(itemIDs.count)
        // Mode: \(modeLabel)

        @addField(PlayerPuppet)
        private let cyberMacItemDiagRan: Bool;

        @wrapMethod(PlayerPuppet)
        protected cb func OnGameAttached() -> Bool {
          let result: Bool = wrappedMethod();

          if this.cyberMacItemDiagRan {
            return result;
          }
          this.cyberMacItemDiagRan = true;

          let gameInstance: GameInstance = this.GetGame();
          let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
          if !IsDefined(transactionSystem) {
            LogChannel(n"DEBUG", s"[CyberMacItemDiag] TransactionSystem missing; skipping diagnostics");
            return result;
          }

          LogChannel(n"DEBUG", s"[CyberMacItemDiag] runtime diagnostic starting itemCount=\(itemIDs.count)");
        \(diagnosticCalls)
          LogChannel(n"DEBUG", s"[CyberMacItemDiag] runtime diagnostic finished");
          return result;
        }

        public class CyberMacItemDiagHelper extends IScriptable {
          public static func GrantProofItem(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, tdbid: TweakDBID, label: CName) -> Void {
            let itemName: String = NameToString(label);
            let itemID: ItemID = ItemID.FromTDBID(tdbid);
            CyberMacItemDiagHelper.Log(s"proof_grant item=\\(itemName) action=GiveItem quantity=1");
            transactionSystem.GiveItem(player, itemID, 1);
          }

          public static func GrantMoneyMarker(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, amount: Int32) -> Void {
            let moneyID: ItemID = ItemID.FromTDBID(t"Items.money");
            transactionSystem.GiveItem(player, moneyID, amount);
            CyberMacItemDiagHelper.Log(s"money_marker amount=\\(IntToString(amount))");
          }

          public static func CheckCNameMarker(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, recordID: TweakDBID, flatSuffix: TweakDBID, expectedValue: CName, label: CName) -> Void {
            let actualValue: CName = TweakDBInterface.GetCName(recordID + flatSuffix, n"__missing");
            CyberMacItemDiagHelper.Log(s"check_cname label=\\(NameToString(label)) actual=\\(NameToString(actualValue)) expected=\\(NameToString(expectedValue))");
            if Equals(actualValue, expectedValue) {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 5000);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 6000);
            }
          }

          public static func ProbeCloneWithMoneyMarkers(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, tdbid: TweakDBID, label: CName, expectedTDBIDHex: String) -> Void {
            let itemName: String = NameToString(label);
            CyberMacItemDiagHelper.Log(s"clone_item=\\(itemName)");
            CyberMacItemDiagHelper.Log(s"clone_tdbid_literal=\\(itemName) expected_tdbid_hash=\\(expectedTDBIDHex)");

            let appearanceName: CName = TweakDBInterface.GetCName(tdbid + t".appearanceName", n"__missing");
            let entityName: CName = TweakDBInterface.GetCName(tdbid + t".entityName", n"__missing");
            let isGarment: Bool = TweakDBInterface.GetBool(tdbid + t".isGarment", false);
            let canDrop: Bool = TweakDBInterface.GetBool(tdbid + t".canDrop", false);

            CyberMacItemDiagHelper.Log(s"clone_flats item=\\(itemName) appearanceName=\\(NameToString(appearanceName)) entityName=\\(NameToString(entityName)) isGarment=\\(CyberMacItemDiagHelper.BoolString(isGarment)) canDrop=\\(CyberMacItemDiagHelper.BoolString(canDrop))");

            let beforeCount: Int32 = CyberMacItemDiagHelper.CountInventory(transactionSystem, player, tdbid);
            CyberMacItemDiagHelper.Log(s"clone_inventory_before item=\\(itemName) count=\\(IntToString(beforeCount))");

            let itemID: ItemID = ItemID.FromTDBID(tdbid);
            CyberMacItemDiagHelper.Log(s"clone_give_attempt item=\\(itemName) action=GiveItem quantity=1");
            transactionSystem.GiveItem(player, itemID, 1);

            let afterCount: Int32 = CyberMacItemDiagHelper.CountInventory(transactionSystem, player, tdbid);
            let countIncreased: Bool = afterCount > beforeCount;
            CyberMacItemDiagHelper.Log(s"clone_inventory_after item=\\(itemName) count=\\(IntToString(afterCount))");
            CyberMacItemDiagHelper.Log(s"clone_inventory_increased item=\\(itemName) increased=\\(CyberMacItemDiagHelper.BoolString(countIncreased)) delta=\\(IntToString(afterCount - beforeCount))");

            if NotEquals(appearanceName, n"__missing") {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 11000);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 12000);
            }
            if NotEquals(entityName, n"__missing") {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 2100);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 2200);
            }
            if countIncreased {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 310);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 320);
            }
            if isGarment {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 41);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 42);
            }
            if canDrop {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 51);
            } else {
              CyberMacItemDiagHelper.GrantMoneyMarker(transactionSystem, player, 52);
            }
          }

          public static func ProbeOne(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, tdbid: TweakDBID, label: CName, expectedTDBIDHex: String) -> Void {
            let itemName: String = NameToString(label);
            CyberMacItemDiagHelper.Log(s"item=\\(itemName)");
            CyberMacItemDiagHelper.Log(s"tdbid_literal=\\(itemName) expected_tdbid_hash=\\(expectedTDBIDHex)");

            let appearanceName: CName = TweakDBInterface.GetCName(tdbid + t".appearanceName", n"__missing");
            let entityName: CName = TweakDBInterface.GetCName(tdbid + t".entityName", n"__missing");
            let isGarment: Bool = TweakDBInterface.GetBool(tdbid + t".isGarment", false);
            let canDrop: Bool = TweakDBInterface.GetBool(tdbid + t".canDrop", false);

            CyberMacItemDiagHelper.Log(s"flats item=\\(itemName) appearanceName=\\(NameToString(appearanceName)) entityName=\\(NameToString(entityName)) isGarment=\\(CyberMacItemDiagHelper.BoolString(isGarment)) canDrop=\\(CyberMacItemDiagHelper.BoolString(canDrop))");

            let beforeCount: Int32 = CyberMacItemDiagHelper.CountInventory(transactionSystem, player, tdbid);
            CyberMacItemDiagHelper.Log(s"inventory_before item=\\(itemName) count=\\(IntToString(beforeCount))");

            let itemID: ItemID = ItemID.FromTDBID(tdbid);
            CyberMacItemDiagHelper.Log(s"give_attempt item=\\(itemName) action=GiveItem quantity=1");
            transactionSystem.GiveItem(player, itemID, 1);

            let afterCount: Int32 = CyberMacItemDiagHelper.CountInventory(transactionSystem, player, tdbid);
            let changed: Bool = afterCount > beforeCount;
            CyberMacItemDiagHelper.Log(s"inventory_after item=\\(itemName) count=\\(IntToString(afterCount))");
            CyberMacItemDiagHelper.Log(s"inventory_increased item=\\(itemName) increased=\\(CyberMacItemDiagHelper.BoolString(changed)) delta=\\(IntToString(afterCount - beforeCount))");
          }

          public static func CountInventory(transactionSystem: ref<TransactionSystem>, holder: ref<PlayerPuppet>, tdbid: TweakDBID) -> Int32 {
            if !IsDefined(transactionSystem) || !IsDefined(holder) {
              return 0;
            }

            let items: array<wref<gameItemData>>;
            transactionSystem.GetItemList(holder, items);

            let count: Int32 = 0;
            let i: Int32 = 0;
            let n: Int32 = ArraySize(items);
            while i < n {
              if Equals(ItemID.GetTDBID(items[i].GetID()), tdbid) {
                count += 1;
              }
              i += 1;
            }

            return count;
          }

          private static func BoolString(value: Bool) -> String {
            if value {
              return "true";
            }
            return "false";
          }

          private static func Log(message: String) -> Void {
            LogChannel(n"DEBUG", s"[CyberMacItemDiag] \\(message)");
          }
        }
        """
    }

    private static func normalizeModName(_ raw: String?) throws -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultModName
        }
        return try RedscriptItemGrantGenerator.normalizeModName(raw)
    }

    private static func validateCNameCheck(_ check: RedscriptRuntimeCNameCheck) throws {
        _ = try RedscriptItemGrantGenerator.normalizeItemIDs([check.record])
        guard !check.property.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("--check-cname property must not be empty")
        }
        guard check.property.allSatisfy(isAllowedIdentifierCharacter) else {
            throw CyberMacError.invalidInput("--check-cname property contains unsupported characters: \(check.property). Allowed: A-Z, a-z, 0-9, '_'.")
        }
        guard !check.expectedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("--check-cname expected value must not be empty")
        }
        guard check.expectedValue.allSatisfy(isAllowedCNameValueCharacter) else {
            throw CyberMacError.invalidInput("--check-cname expected value contains unsupported characters: \(check.expectedValue). Allowed: A-Z, a-z, 0-9, '_', '-', '.', ':', '/'.")
        }
    }

    private static func isAllowedIdentifierCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            if !(isUpper || isLower || isDigit || scalar == "_") {
                return false
            }
        }
        return true
    }

    private static func isAllowedCNameValueCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            let isPunct = scalar == "_" || scalar == "-" || scalar == "." || scalar == ":" || scalar == "/"
            if !(isUpper || isLower || isDigit || isPunct) {
                return false
            }
        }
        return true
    }

    private static func prepareOutputLocation(outputZipURL: URL) throws {
        let parent = outputZipURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outputZipURL.path) {
            try FileManager.default.removeItem(at: outputZipURL)
        }
    }

    private static func summaryURL(for outputZipURL: URL) -> URL {
        outputZipURL.deletingPathExtension().appendingPathExtension("summary.txt")
    }

    private static func renderSummary(
        outputZipURL: URL,
        summaryURL: URL,
        itemIDs: [String],
        expectedTweakDBIDHexByItemID: [String: String],
        modName: String,
        redscriptSizeBytes: Int,
        moneyMarkers: Bool,
        cNameChecks: [RedscriptRuntimeCNameCheck]
    ) -> String {
        var lines: [String] = [
            "CyberMac TweakDB runtime item diagnostic",
            "Output zip: \(outputZipURL.path)",
            "Summary: \(summaryURL.path)",
            "Mod name: \(modName)",
            "Entry path: \(RedscriptRuntimeItemDiagnosticGrantResult.redscriptEntryPath)",
            "Log prefix: [CyberMacItemDiag]",
            "Money markers: \(moneyMarkers ? "enabled" : "disabled")",
            "Redscript size: \(redscriptSizeBytes) bytes",
            "",
            "Items:"
        ]
        for itemID in itemIDs {
            lines.append("- \(itemID) expected_tdbid_hash=\(expectedTweakDBIDHexByItemID[itemID] ?? tweakDBIDHex(itemID))")
        }
        if !cNameChecks.isEmpty {
            lines.append("")
            lines.append("CName checks:")
            for check in cNameChecks {
                lines.append("- \(check.record).\(check.property)=\(check.expectedValue)")
            }
        }
        lines.append("")
        if moneyMarkers {
            lines.append("Money marker legend:")
            for marker in moneyMarkerLegend {
                lines.append("- \(marker)")
            }
            lines.append("")
            lines.append("Interpretation examples:")
            for example in moneyMarkerInterpretationExamples {
                lines.append("- \(example)")
            }
            lines.append("")
            if itemIDs.count == 1 {
                lines.append("The helper probes the listed item directly and reports diagnostic results through the total Items.money delta.")
            } else {
                lines.append("The helper grants the first item as the trigger proof, probes the second item, and reports diagnostic results through the total Items.money delta.")
            }
        } else {
            lines.append("The helper logs flat getter results, inventory count before GiveItem, the GiveItem attempt, inventory count after GiveItem, and whether the count increased.")
        }
        return lines.joined(separator: "\n")
    }

    private static func tweakDBIDHex(_ name: String) -> String {
        let bytes = Array(name.utf8)
        let value = (UInt64(bytes.count) << 32) | UInt64(TweakDBPackedStringAnalyzer.crc32(bytes))
        let raw = String(value, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: max(0, 16 - raw.count)) + raw
    }
}
