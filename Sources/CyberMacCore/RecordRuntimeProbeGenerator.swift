import Foundation
import ZIPFoundation

public struct RedscriptRecordRuntimeProbeRequest: Equatable, Sendable {
    public let baseRecordIDs: [String]
    public let customRecordIDs: [String]
    public let outputZipURL: URL
    public let modName: String?

    public init(
        baseRecordIDs: [String],
        customRecordIDs: [String],
        outputZipURL: URL,
        modName: String? = nil
    ) {
        self.baseRecordIDs = baseRecordIDs
        self.customRecordIDs = customRecordIDs
        self.outputZipURL = outputZipURL
        self.modName = modName
    }
}

public struct RedscriptRecordRuntimeProbeResult: Equatable, Sendable {
    public static let redscriptEntryPath = "r6/scripts/CyberMacRecordProbe/CyberMacRecordProbe.reds"

    public let outputZipURL: URL
    public let redscriptEntryPath: String
    public let baseRecordIDs: [String]
    public let customRecordIDs: [String]
    public let modName: String
    public let redscriptContent: String
    public let redscriptSizeBytes: Int

    public init(
        outputZipURL: URL,
        redscriptEntryPath: String,
        baseRecordIDs: [String],
        customRecordIDs: [String],
        modName: String,
        redscriptContent: String,
        redscriptSizeBytes: Int
    ) {
        self.outputZipURL = outputZipURL
        self.redscriptEntryPath = redscriptEntryPath
        self.baseRecordIDs = baseRecordIDs
        self.customRecordIDs = customRecordIDs
        self.modName = modName
        self.redscriptContent = redscriptContent
        self.redscriptSizeBytes = redscriptSizeBytes
    }
}

public struct RedscriptRecordRuntimeProbeGenerator: Sendable {
    public static let defaultModName = "CyberMacRecordRuntimeProbe"

    private static let deterministicTimestamp = Date(timeIntervalSince1970: 1_704_067_200)

    public init() {}

    public func generate(request: RedscriptRecordRuntimeProbeRequest) throws -> RedscriptRecordRuntimeProbeResult {
        let baseRecordIDs = try RedscriptItemGrantGenerator.normalizeItemIDs(request.baseRecordIDs)
        let customRecordIDs = try RedscriptItemGrantGenerator.normalizeItemIDs(request.customRecordIDs)
        guard !customRecordIDs.isEmpty else {
            throw CyberMacError.invalidInput("record-runtime-probe requires at least one expanded custom Items.* record.")
        }
        let modName = try Self.normalizeModName(request.modName)
        let redscriptSource = Self.renderRedscript(
            baseRecordIDs: baseRecordIDs,
            customRecordIDs: customRecordIDs,
            modName: modName
        )
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
                with: RedscriptRecordRuntimeProbeResult.redscriptEntryPath,
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

        return RedscriptRecordRuntimeProbeResult(
            outputZipURL: request.outputZipURL,
            redscriptEntryPath: RedscriptRecordRuntimeProbeResult.redscriptEntryPath,
            baseRecordIDs: baseRecordIDs,
            customRecordIDs: customRecordIDs,
            modName: modName,
            redscriptContent: redscriptSource,
            redscriptSizeBytes: redscriptData.count
        )
    }

    static func renderRedscript(baseRecordIDs: [String], customRecordIDs: [String], modName: String) -> String {
        let baseCalls = baseRecordIDs
            .map {
                """
                  if CyberMacRecordProbe.CheckRecord(t"\($0)", n"\($0)", true) {
                    baseRecordsProbablyPresent += 1;
                  }
                """
            }
            .joined(separator: "\n")
        let customCalls = customRecordIDs
            .map {
                """
                  if CyberMacRecordProbe.CheckRecord(t"\($0)", n"\($0)", false) {
                    customRecordsProbablyPresent += 1;
                  } else {
                    customRecordsProbablyMissing += 1;
                  }
                """
            }
            .joined(separator: "\n")
        let total = baseRecordIDs.count + customRecordIDs.count

        return """
        module CyberMacRecordProbe

        // Generated by CyberMac. Do not edit manually.
        // Read-only runtime probe for TweakDB flat visibility. It does not grant
        // items, write records, or mutate game data.
        //
        // Mod label: \(modName)
        // Base records: \(baseRecordIDs.count)
        // Custom records: \(customRecordIDs.count)

        @addField(PlayerPuppet)
        private let cyberMacRecordProbeRan: Bool;

        @wrapMethod(PlayerPuppet)
        protected cb func OnGameAttached() -> Bool {
          let result: Bool = wrappedMethod();

          if this.cyberMacRecordProbeRan {
            return result;
          }
          this.cyberMacRecordProbeRan = true;

          let baseRecordsProbablyPresent: Int32 = 0;
          let customRecordsProbablyPresent: Int32 = 0;
          let customRecordsProbablyMissing: Int32 = 0;

          LogChannel(n"DEBUG", s"CyberMacRecordProbe: compile/run status reached runtime callback; probing \(total) TweakDB record ID(s) with read-only flat getters");
        \(baseCalls)
        \(customCalls)
          LogChannel(n"DEBUG", s"CyberMacRecordProbe: summary baseRecordsProbablyPresent=\\(IntToString(baseRecordsProbablyPresent)) customRecordsProbablyPresent=\\(IntToString(customRecordsProbablyPresent)) customRecordsProbablyMissing=\\(IntToString(customRecordsProbablyMissing))");
          return result;
        }

        public class CyberMacRecordProbe extends IScriptable {
          public static func CheckRecord(recordID: TweakDBID, label: CName, baseRecord: Bool) -> Bool {
            if !TDBID.IsValid(recordID) {
              LogChannel(n"DEBUG", s"CyberMacRecordProbe: invalid TDBID literal \\(NameToString(label))");
              return false;
            }

            let modType: CName = TweakDBInterface.GetCName(recordID + t".modType", n"__missing");
            let shardType: CName = TweakDBInterface.GetCName(recordID + t".shardType", n"__missing");
            let entityName: CName = TweakDBInterface.GetCName(recordID + t".entityName", n"__missing");
            let appearanceName: CName = TweakDBInterface.GetCName(recordID + t".appearanceName", n"__missing");
            let displayName: CName = TweakDBInterface.GetCName(recordID + t".displayName", n"__missing");
            let quality: CName = TweakDBInterface.GetCName(recordID + t".quality", n"__missing");
            let weight: Float = TweakDBInterface.GetFloat(recordID + t".weight", -9999.00);
            let price: Float = TweakDBInterface.GetFloat(recordID + t".price", -9999.00);
            let anyFlatFound: Bool = NotEquals(modType, n"__missing")
              || NotEquals(shardType, n"__missing")
              || NotEquals(entityName, n"__missing")
              || NotEquals(appearanceName, n"__missing")
              || NotEquals(displayName, n"__missing")
              || NotEquals(quality, n"__missing")
              || weight != -9999.00
              || price != -9999.00;
            let recordKind: String;
            let probeStatus: String;

            if baseRecord {
              recordKind = "base";
            } else {
              recordKind = "custom";
            }
            if anyFlatFound {
              probeStatus = "at_least_one_flat_non_default";
            } else {
              probeStatus = "all_probe_flats_default";
            }

            LogChannel(n"DEBUG", s"CyberMacRecordProbe: \\(recordKind) \\(NameToString(label)) status=\\(probeStatus) modType=\\(NameToString(modType)) shardType=\\(NameToString(shardType)) entityName=\\(NameToString(entityName)) appearanceName=\\(NameToString(appearanceName)) displayName=\\(NameToString(displayName)) quality=\\(NameToString(quality)) weight=\\(ToString(weight)) price=\\(ToString(price))");
            return anyFlatFound;
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

    private static func prepareOutputLocation(outputZipURL: URL) throws {
        let parent = outputZipURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outputZipURL.path) {
            try FileManager.default.removeItem(at: outputZipURL)
        }
    }
}
