import Foundation
import ZIPFoundation

public struct RedscriptItemGrantRequest: Equatable, Sendable {
    public let itemIDs: [String]
    public let outputZipURL: URL
    public let modName: String?

    public init(itemIDs: [String], outputZipURL: URL, modName: String? = nil) {
        self.itemIDs = itemIDs
        self.outputZipURL = outputZipURL
        self.modName = modName
    }
}

public struct RedscriptItemGrantResult: Equatable, Sendable {
    public static let redscriptEntryPath = "r6/scripts/CyberMacItemGrant/CyberMacItemGrant.reds"

    public let outputZipURL: URL
    public let redscriptEntryPath: String
    public let normalizedItemIDs: [String]
    public let modName: String
    public let redscriptContent: String
    public let redscriptSizeBytes: Int

    public init(
        outputZipURL: URL,
        redscriptEntryPath: String,
        normalizedItemIDs: [String],
        modName: String,
        redscriptContent: String,
        redscriptSizeBytes: Int
    ) {
        self.outputZipURL = outputZipURL
        self.redscriptEntryPath = redscriptEntryPath
        self.normalizedItemIDs = normalizedItemIDs
        self.modName = modName
        self.redscriptContent = redscriptContent
        self.redscriptSizeBytes = redscriptSizeBytes
    }
}

public struct RedscriptItemGrantGenerator: Sendable {
    public static let defaultModName = "CyberMacItemGrant"

    private static let deterministicTimestamp = Date(timeIntervalSince1970: 1_704_067_200)

    public init() {}

    public func generate(request: RedscriptItemGrantRequest) throws -> RedscriptItemGrantResult {
        let normalizedItemIDs = try Self.normalizeItemIDs(request.itemIDs)
        let modName = try Self.normalizeModName(request.modName)

        let redscriptSource = Self.renderRedscript(itemIDs: normalizedItemIDs, modName: modName)
        let redscriptData = Data(redscriptSource.utf8)

        try Self.prepareOutputLocation(outputZipURL: request.outputZipURL)

        let archive: Archive
        do {
            archive = try Archive(url: request.outputZipURL, accessMode: .create)
        } catch {
            throw CyberMacError.fileSystem("Could not create zip at \(request.outputZipURL.path): \(error.localizedDescription)")
        }

        do {
            try archive.addEntry(
                with: RedscriptItemGrantResult.redscriptEntryPath,
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
        } catch {
            try? FileManager.default.removeItem(at: request.outputZipURL)
            throw CyberMacError.fileSystem("Failed to write redscript entry to zip: \(error.localizedDescription)")
        }

        return RedscriptItemGrantResult(
            outputZipURL: request.outputZipURL,
            redscriptEntryPath: RedscriptItemGrantResult.redscriptEntryPath,
            normalizedItemIDs: normalizedItemIDs,
            modName: modName,
            redscriptContent: redscriptSource,
            redscriptSizeBytes: redscriptData.count
        )
    }

    static func normalizeItemIDs(_ raw: [String]) throws -> [String] {
        guard !raw.isEmpty else {
            throw CyberMacError.invalidInput("At least one --item <Items.Some_Item_ID> is required")
        }

        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CyberMacError.invalidInput("Item ID must not be empty")
            }
            guard trimmed.hasPrefix("Items.") else {
                throw CyberMacError.invalidInput("Item ID must start with 'Items.': \(value)")
            }
            let suffix = trimmed.dropFirst("Items.".count)
            guard !suffix.isEmpty else {
                throw CyberMacError.invalidInput("Item ID is missing the part after 'Items.': \(value)")
            }
            guard suffix.allSatisfy(Self.isAllowedItemIDCharacter) else {
                throw CyberMacError.invalidInput("Item ID contains unsupported characters: \(value). Allowed after 'Items.': A-Z, a-z, 0-9, '_', '-', '.'")
            }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    static func normalizeModName(_ raw: String?) throws -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultModName
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.allSatisfy(Self.isAllowedModNameCharacter) else {
            throw CyberMacError.invalidInput("--mod-name may only contain A-Z, a-z, 0-9, spaces, '_', '-'. Got: \(raw)")
        }
        return trimmed
    }

    private static func isAllowedItemIDCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            let isPunct = scalar == "_" || scalar == "-" || scalar == "."
            if !(isUpper || isLower || isDigit || isPunct) {
                return false
            }
        }
        return true
    }

    private static func isAllowedModNameCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isUpper = (0x41...0x5A).contains(value)
            let isLower = (0x61...0x7A).contains(value)
            let isDigit = (0x30...0x39).contains(value)
            let isPunct = scalar == "_" || scalar == "-" || scalar == " "
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

    static func renderRedscript(itemIDs: [String], modName: String) -> String {
        let grantCalls = itemIDs
            .map { "  CyberMacItemGrantHelper.GrantOne(transactionSystem, this, t\"\($0)\", n\"\($0)\");" }
            .joined(separator: "\n")

        return """
        module CyberMacItemGrant

        // Generated by CyberMac. Do not edit manually.
        // Test helper for clothing replacement workflows: grants the listed items to the
        // player puppet once per game session. Uses vanilla redscript APIs only — no CET,
        // RED4ext, Codeware, ArchiveXL, or TweakXL.
        // Does not depend on LogChannel, which is absent from the vanilla 2.5 cache.
        //
        // Mod label: \(modName)
        // Item count: \(itemIDs.count)

        @addField(PlayerPuppet)
        private let cyberMacItemGrantGranted: Bool;

        @wrapMethod(PlayerPuppet)
        protected cb func OnGameAttached() -> Bool {
          let result: Bool = wrappedMethod();

          if this.cyberMacItemGrantGranted {
            return result;
          }
          this.cyberMacItemGrantGranted = true;

          let gameInstance: GameInstance = this.GetGame();
          let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
          if !IsDefined(transactionSystem) {
            return result;
          }

        \(grantCalls)
          return result;
        }

        public class CyberMacItemGrantHelper extends IScriptable {
          public static func GrantOne(transactionSystem: ref<TransactionSystem>, player: ref<PlayerPuppet>, tdbid: TweakDBID, label: CName) -> Void {
            if !TDBID.IsValid(tdbid) {
              return;
            }
            let itemID: ItemID = ItemID.FromTDBID(tdbid);
            if transactionSystem.HasItem(player, itemID) {
              return;
            }
            transactionSystem.GiveItem(player, itemID, 1);
          }
        }
        """
    }
}
