import Foundation

public struct AddonProbeTweakDBStructureInspectRequest: Sendable {
    public let fileURL: URL
    public let outputDirectoryURL: URL
    public let records: [String]

    public init(fileURL: URL, outputDirectoryURL: URL, records: [String] = []) {
        self.fileURL = fileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.records = records
    }
}

public struct AddonProbeTweakDBRecordTraceRequest: Sendable {
    public let fileURL: URL
    public let record: String
    public let outputDirectoryURL: URL

    public init(fileURL: URL, record: String, outputDirectoryURL: URL) {
        self.fileURL = fileURL
        self.record = record
        self.outputDirectoryURL = outputDirectoryURL
    }
}

public enum AddonProbeTweakDBStructureConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
    case unknown
}

public enum AddonProbeTweakDBStructureConclusion: String, Codable, Equatable, Sendable {
    case wolvenKitHeaderMatched
    case sectionsMapped
    case recordTableParsed
    case flatTableParsed
    case queryRecordsResolved
    case queryRecordsUnresolved
    case unresolved
}

public struct AddonProbeTweakDBParsedHeader: Codable, Equatable, Sendable {
    public let magic: UInt32
    public let magicHex: String
    public let blobVersion: UInt32
    public let parserVersion: UInt32
    public let recordsChecksum: UInt32
    public let recordsChecksumHex: String
    public let flatsOffset: Int
    public let recordsOffset: Int
    public let queriesOffset: Int
    public let groupTagsOffset: Int
    public let validWolvenKitHeader: Bool
}

public struct AddonProbeTweakDBStructureSection: Codable, Equatable, Sendable {
    public let name: String
    public let role: String
    public let offset: Int
    public let size: Int
    public let count: Int?
    public let confidence: AddonProbeTweakDBStructureConfidence
    public let firstEntries: [String]
    public let lastEntries: [String]
    public let notes: [String]
}

public struct AddonProbeTweakDBFlatTypeSection: Codable, Equatable, Sendable {
    public let typeHashHex: String
    public let typeName: String?
    public let descriptorOffset: Int
    public let valueBlockOffset: Int
    public let valueCount: Int
    public let keyCount: Int
    public let parsedValueCount: Int
    public let parsedKeyCount: Int
    public let keyBlockOffset: Int?
    public let endOffset: Int?
    public let confidence: AddonProbeTweakDBStructureConfidence
    public let sampleValues: [String]
    public let sampleKeys: [String]
    public let warnings: [String]
}

public struct AddonProbeTweakDBRecordTableEntry: Codable, Equatable, Sendable {
    public let tableIndex: Int
    public let offset: Int
    public let recordID: UInt64
    public let recordIDHex: String
    public let recordTypeHash: UInt32
    public let recordTypeHashHex: String
    public let recordTypeName: String?
}

public struct AddonProbeTweakDBFlatTrace: Codable, Equatable, Sendable {
    public let property: String
    public let flatID: UInt64
    public let flatIDHex: String
    public let keyOffset: Int
    public let typeName: String?
    public let typeHashHex: String
    public let valueIndex: Int
    public let valueSummary: String?
    public let referencedTweakDBIDs: [String]
}

public struct AddonProbeTweakDBRecordTrace: Codable, Equatable, Sendable {
    public let recordName: String
    public let recordID: UInt64
    public let recordIDHex: String
    public let recordTableEntry: AddonProbeTweakDBRecordTableEntry?
    public let parentBaseRecord: String?
    public let parentBaseRecordStatus: String
    public let knownFlatCount: Int
    public let knownFlatCountConfidence: AddonProbeTweakDBStructureConfidence
    public let knownFlats: [AddonProbeTweakDBFlatTrace]
    public let nearbyRecords: [AddonProbeTweakDBRecordTableEntry]
    public let traceStatus: [String]
}

public struct AddonProbeTweakDBStructureReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let size: Int
    public let sha256: String
    public let header: AddonProbeTweakDBParsedHeader
    public let sections: [AddonProbeTweakDBStructureSection]
    public let flatTypeSections: [AddonProbeTweakDBFlatTypeSection]
    public let recordCount: Int
    public let queryCount: Int
    public let groupTagCount: Int
    public let resolvedRecords: [AddonProbeTweakDBRecordTrace]
    public let sectionsPath: String
    public let recordTracesPath: String
    public let reportPath: String
    public let conclusions: [AddonProbeTweakDBStructureConclusion]
    public let warnings: [String]
}

public struct AddonProbeTweakDBRecordTraceReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let size: Int
    public let sha256: String
    public let header: AddonProbeTweakDBParsedHeader
    public let trace: AddonProbeTweakDBRecordTrace
    public let tracePath: String
    public let reportPath: String
    public let warnings: [String]
}

public struct TweakDBStructureInspector: Sendable {
    public static let defaultRecords = [
        "Items.TShirt_04_old_01",
        "Items.Pants_10_rich_01",
        "Items.FormalSkirt_01_basic_02",
        "Items.Skirt"
    ]

    private static let magic: UInt32 = 0x0BB1DB47
    private static let blobVersion: UInt32 = 8
    private static let parserVersion: UInt32 = 4
    private static let recordsSeed: UInt32 = 0x5EEDBA5E
    private static let fileHeaderSize = 0x20
    private static let flatTypeDescriptorSize = 20
    private static let maxSampleCount = 6

    private static let flatTypeNames = [
        "CName", "String", "TweakDBID", "raRef:CResource", "Float", "Bool",
        "Uint8", "Uint16", "Uint32", "Uint64", "Int8", "Int16", "Int32", "Int64",
        "Color", "EulerAngles", "Quaternion", "Vector2", "Vector3", "gamedataLocKeyWrapper",
        "array:CName", "array:String", "array:TweakDBID", "array:raRef:CResource", "array:Float", "array:Bool",
        "array:Uint8", "array:Uint16", "array:Uint32", "array:Uint64", "array:Int8", "array:Int16", "array:Int32", "array:Int64",
        "array:Color", "array:EulerAngles", "array:Quaternion", "array:Vector2", "array:Vector3", "array:gamedataLocKeyWrapper"
    ]

    private static let recordTypeNames = [
        "Item", "Clothing", "ClothingItem", "OutfitItem", "WeaponItem", "ConsumableItem", "InventoryItem", "ItemList", "ItemQuery",
        "ItemArrayQuery", "ItemCategory", "ItemType", "ItemStructure", "ItemPartConnection",
        "ItemPartListElement", "ItemRequiredSlot", "SlotItemPartPreset", "SlotItemPartElement",
        "SlotItemPartListElement", "EquipmentArea", "InventoryItemGroup", "InventoryItemSet",
        "RecipeItem", "LootItem", "VendorItem", "VendorWare", "Quality", "RPGDataPackage",
        "StatModifier", "StatModifierGroup", "AttachmentSlot", "UIIcon", "UIIconPool"
    ]

    internal static let itemRecordProperties = [
        "animationParameters", "animFeatureName", "animName", "animSetResource", "appearanceName",
        "appearanceResourceName", "appearanceSuffixes", "appearanceSuffixesOwnerOverride", "attachmentSlots",
        "audioName", "audioSwitchName", "audioSwitchValue", "blueprint", "buyPrice", "cameraForward",
        "cameraUp", "canDrop", "connections", "counterpart", "cpoItemCategory", "CraftingData",
        "crosshair", "deprecated", "displayName", "dropObject", "dropSettings", "enableNpcRPGData",
        "entityName", "equipArea", "equipAreas", "equipPrereqs", "equipSoundMetadata", "equivalent",
        "friendlyName", "gameplayRestrictions", "garmentOffset", "hairSkinnedMeshComponents", "icon",
        "iconPath", "isCached", "isCoreCW", "isCustomizable", "isGarment", "isPart", "isSingleInstance",
        "itemCategory", "itemSecondaryAction", "itemStructure", "itemType", "localizedDescription",
        "localizedName", "mass", "minigameInstance", "movementPattern", "movementSound", "nextUpgradeItem",
        "npcRPGData", "OnAttach", "OnEquip", "onEquipStats", "OnLooted", "parentAttachmentType",
        "parts", "placementSlots", "powerLevelDeterminedByParent", "previewBBoxOverride", "quality",
        "qualityRestrictedByParent", "replicateWhenNotActive", "requiredSlots", "sellPrice",
        "sideUpgradeItem", "slotPartList", "slotPartListPreset", "stateMachineName", "tags",
        "upgradeCostMult", "useHeadgearGarmentAggregator", "useNewSpawnMethod", "usesVariants",
        "variants", "visualTags"
    ]

    public init() {}

    public func inspect(request: AddonProbeTweakDBStructureInspectRequest) throws -> AddonProbeTweakDBStructureReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let parsed = try Self.parse(data: data)
        let records = Self.normalizedRecords(request.records)
        let traces = records.map { Self.trace(recordName: $0, parsed: parsed) }

        let sectionsURL = outputDirectoryURL.appendingPathComponent("tweakdb-structure-sections.txt")
        let tracesURL = outputDirectoryURL.appendingPathComponent("tweakdb-structure-record-traces.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-structure-analysis.json")

        let report = AddonProbeTweakDBStructureReport(
            filePath: fileURL.path,
            size: data.count,
            sha256: try PathSafety.sha256(url: fileURL),
            header: parsed.header,
            sections: parsed.sections,
            flatTypeSections: parsed.flatTypeReports,
            recordCount: parsed.records.count,
            queryCount: parsed.queryCount,
            groupTagCount: parsed.groupTagCount,
            resolvedRecords: traces,
            sectionsPath: sectionsURL.path,
            recordTracesPath: tracesURL.path,
            reportPath: reportURL.path,
            conclusions: Self.conclusions(parsed: parsed, traces: traces),
            warnings: Self.commonWarnings()
        )

        try Self.writeSections(report, to: sectionsURL)
        try Self.writeRecordTraces(traces, to: tracesURL)
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func trace(request: AddonProbeTweakDBRecordTraceRequest) throws -> AddonProbeTweakDBRecordTraceReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let data = try Self.readData(fileURL)
        let parsed = try Self.parse(data: data)
        let record = request.record.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !record.isEmpty else {
            throw CyberMacError.invalidInput("--record must not be empty")
        }
        let trace = Self.trace(recordName: record, parsed: parsed)

        let traceURL = outputDirectoryURL.appendingPathComponent("tweakdb-record-trace.txt")
        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-record-trace.json")
        let report = AddonProbeTweakDBRecordTraceReport(
            filePath: fileURL.path,
            size: data.count,
            sha256: try PathSafety.sha256(url: fileURL),
            header: parsed.header,
            trace: trace,
            tracePath: traceURL.path,
            reportPath: reportURL.path,
            warnings: Self.commonWarnings()
        )
        try Self.writeRecordTraces([trace], to: traceURL)
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    private struct ParsedFile {
        let header: AddonProbeTweakDBParsedHeader
        let sections: [AddonProbeTweakDBStructureSection]
        let flatTypeReports: [AddonProbeTweakDBFlatTypeSection]
        let records: [AddonProbeTweakDBRecordTableEntry]
        let recordsByID: [UInt64: AddonProbeTweakDBRecordTableEntry]
        let flatEntriesByID: [UInt64: ParsedFlatEntry]
        let queryCount: Int
        let groupTagCount: Int
    }

    private struct ParsedFlatEntry {
        let id: UInt64
        let keyOffset: Int
        let valueIndex: Int
        let typeHash: UInt64
        let typeName: String?
        let value: ParsedFlatValue?
    }

    private struct ParsedFlatValue {
        let summary: String
        let referencedIDs: [UInt64]
    }

    private struct FlatTypeDescriptor {
        let typeHash: UInt64
        let typeName: String?
        let valueCount: Int
        let keyCount: Int
        let valueBlockOffset: Int
        let descriptorOffset: Int
    }

    private struct ParsedFlatType {
        let report: AddonProbeTweakDBFlatTypeSection
        let entries: [ParsedFlatEntry]
    }

    private struct Cursor {
        let bytes: [UInt8]
        var offset: Int

        mutating func readUInt8() throws -> UInt8 {
            try require(1)
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func readUInt16LE() throws -> UInt16 {
            try require(2)
            defer { offset += 2 }
            return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        }

        mutating func readUInt32LE() throws -> UInt32 {
            try require(4)
            defer { offset += 4 }
            return UInt32(bytes[offset]) |
                (UInt32(bytes[offset + 1]) << 8) |
                (UInt32(bytes[offset + 2]) << 16) |
                (UInt32(bytes[offset + 3]) << 24)
        }

        mutating func readInt32LE() throws -> Int32 {
            Int32(bitPattern: try readUInt32LE())
        }

        mutating func readUInt64LE() throws -> UInt64 {
            try require(8)
            defer { offset += 8 }
            var value: UInt64 = 0
            for index in 0..<8 {
                value |= UInt64(bytes[offset + index]) << UInt64(index * 8)
            }
            return value
        }

        mutating func readFloat32LE() throws -> Float {
            Float(bitPattern: try readUInt32LE())
        }

        mutating func readVLQInt32() throws -> Int {
            let first = try readUInt8()
            let isNegative = (first & 0b1000_0000) != 0
            var value = Int(first & 0b0011_1111)
            if (first & 0b0100_0000) != 0 {
                let second = try readUInt8()
                value |= Int(second & 0b0111_1111) << 6
                if (second & 0b1000_0000) != 0 {
                    let third = try readUInt8()
                    value |= Int(third & 0b0111_1111) << 13
                    if (third & 0b1000_0000) != 0 {
                        let fourth = try readUInt8()
                        value |= Int(fourth & 0b0111_1111) << 20
                        if (fourth & 0b1000_0000) != 0 {
                            let fifth = try readUInt8()
                            value |= Int(fifth & 0b0111_1111) << 27
                            if (fifth & 0b1000_0000) != 0 {
                                throw CyberMacError.invalidInput("Invalid VLQ int32 at offset \(offset - 1)")
                            }
                        }
                    }
                }
            }
            return isNegative ? -value : value
        }

        mutating func readLengthPrefixedString() throws -> String {
            let prefix = try readVLQInt32()
            let characterLength = abs(prefix)
            guard characterLength > 0 else { return "" }
            if prefix > 0 {
                let byteCount = characterLength * 2
                try require(byteCount)
                let raw = Array(bytes[offset..<(offset + byteCount)])
                offset += byteCount
                let codeUnits = stride(from: 0, to: raw.count, by: 2).map { index in
                    UInt16(raw[index]) | (UInt16(raw[index + 1]) << 8)
                }
                return String(decoding: codeUnits, as: UTF16.self)
            } else {
                try require(characterLength)
                let raw = Array(bytes[offset..<(offset + characterLength)])
                offset += characterLength
                return String(decoding: raw, as: UTF8.self)
            }
        }

        mutating func skip(_ count: Int) throws {
            try require(count)
            offset += count
        }

        func require(_ count: Int) throws {
            guard count >= 0, offset >= 0, offset + count <= bytes.count else {
                throw CyberMacError.invalidInput("Unexpected end of TweakDB data at offset \(offset), need \(count) bytes.")
            }
        }
    }

    private static func parse(data: Data) throws -> ParsedFile {
        let bytes = [UInt8](data)
        guard bytes.count >= fileHeaderSize else {
            throw CyberMacError.invalidInput("TweakDB file is too small to contain a WolvenKit-style header.")
        }

        var cursor = Cursor(bytes: bytes, offset: 0)
        let magicValue = try cursor.readUInt32LE()
        let blobVersionValue = try cursor.readUInt32LE()
        let parserVersionValue = try cursor.readUInt32LE()
        let checksum = try cursor.readUInt32LE()
        let flatsOffset = Int(try cursor.readUInt32LE())
        let recordsOffset = Int(try cursor.readUInt32LE())
        let queriesOffset = Int(try cursor.readUInt32LE())
        let groupTagsOffset = Int(try cursor.readUInt32LE())

        let header = AddonProbeTweakDBParsedHeader(
            magic: magicValue,
            magicHex: hex(magicValue),
            blobVersion: blobVersionValue,
            parserVersion: parserVersionValue,
            recordsChecksum: checksum,
            recordsChecksumHex: hex(checksum),
            flatsOffset: flatsOffset,
            recordsOffset: recordsOffset,
            queriesOffset: queriesOffset,
            groupTagsOffset: groupTagsOffset,
            validWolvenKitHeader: magicValue == magic && blobVersionValue == blobVersion && parserVersionValue == parserVersion
        )

        guard header.validWolvenKitHeader else {
            throw CyberMacError.invalidInput("Unsupported TweakDB header: magic=\(hex(magicValue)) blob=\(blobVersionValue) parser=\(parserVersionValue)")
        }
        try validateOffset(flatsOffset, count: bytes.count, label: "flats offset")
        try validateOffset(recordsOffset, count: bytes.count, label: "records offset")
        try validateOffset(queriesOffset, count: bytes.count, label: "queries offset")
        try validateOffset(groupTagsOffset, count: bytes.count, label: "group tags offset")

        let typeHashNames = Dictionary(uniqueKeysWithValues: flatTypeNames.map { (TweakDBPackedStringAnalyzer.fnv1a64(Array($0.utf8)), $0) })
        let recordHashNames = Dictionary(uniqueKeysWithValues: recordTypeNames.map { (murmur3_32($0, seed: recordsSeed), $0) })
        let flatTypes = try parseFlatTypes(bytes: bytes, offset: flatsOffset, typeHashNames: typeHashNames)
        var flatEntriesByID: [UInt64: ParsedFlatEntry] = [:]
        for flatType in flatTypes {
            for entry in flatType.entries {
                flatEntriesByID[entry.id] = entry
            }
        }

        let records = try parseRecords(bytes: bytes, offset: recordsOffset, endOffset: queriesOffset, recordHashNames: recordHashNames)
        let queries = try parseQueries(bytes: bytes, offset: queriesOffset, endOffset: groupTagsOffset)
        let groupTags = try parseGroupTags(bytes: bytes, offset: groupTagsOffset)
        let sections = try makeSections(
            bytes: bytes,
            header: header,
            flatTypes: flatTypes.map(\.report),
            records: records,
            queries: queries.samples,
            queryCount: queries.count,
            groupTags: groupTags.samples,
            groupTagCount: groupTags.count
        )

        return ParsedFile(
            header: header,
            sections: sections,
            flatTypeReports: flatTypes.map(\.report),
            records: records,
            recordsByID: Dictionary(uniqueKeysWithValues: records.map { ($0.recordID, $0) }),
            flatEntriesByID: flatEntriesByID,
            queryCount: queries.count,
            groupTagCount: groupTags.count
        )
    }

    private static func parseFlatTypes(
        bytes: [UInt8],
        offset: Int,
        typeHashNames: [UInt64: String]
    ) throws -> [ParsedFlatType] {
        var cursor = Cursor(bytes: bytes, offset: offset)
        let typeCount = Int(try cursor.readUInt32LE())
        guard typeCount >= 0, typeCount < 256 else {
            throw CyberMacError.invalidInput("Unreasonable flat type count \(typeCount) at offset \(offset).")
        }
        var descriptors: [FlatTypeDescriptor] = []
        for index in 0..<typeCount {
            let descriptorOffset = offset + 4 + index * flatTypeDescriptorSize
            let typeHash = try cursor.readUInt64LE()
            let valueCount = Int(try cursor.readUInt32LE())
            let keyCount = Int(try cursor.readUInt32LE())
            let valueBlockOffset = Int(try cursor.readUInt32LE())
            descriptors.append(FlatTypeDescriptor(
                typeHash: typeHash,
                typeName: typeHashNames[typeHash],
                valueCount: valueCount,
                keyCount: keyCount,
                valueBlockOffset: valueBlockOffset,
                descriptorOffset: descriptorOffset
            ))
        }

        return descriptors.map { descriptor in
            parseFlatType(descriptor: descriptor, bytes: bytes)
        }
    }

    private static func parseFlatType(descriptor: FlatTypeDescriptor, bytes: [UInt8]) -> ParsedFlatType {
        var warnings: [String] = []
        var values: [ParsedFlatValue] = []
        var entries: [ParsedFlatEntry] = []
        var keyBlockOffset: Int?
        var endOffset: Int?
        do {
            try validateOffset(descriptor.valueBlockOffset, count: bytes.count, label: "flat value block offset")
            var cursor = Cursor(bytes: bytes, offset: descriptor.valueBlockOffset)
            let encodedValueCount = Int(try cursor.readUInt32LE())
            if encodedValueCount != descriptor.valueCount {
                warnings.append("Descriptor valueCount=\(descriptor.valueCount) but block starts with \(encodedValueCount).")
            }
            let parseCount = min(max(0, descriptor.valueCount), max(0, encodedValueCount))
            for _ in 0..<parseCount {
                values.append(try parseFlatValue(typeName: descriptor.typeName, cursor: &cursor))
            }
            keyBlockOffset = cursor.offset
            let encodedKeyCount = Int(try cursor.readUInt32LE())
            if encodedKeyCount != descriptor.keyCount {
                warnings.append("Descriptor keyCount=\(descriptor.keyCount) but key block starts with \(encodedKeyCount).")
            }
            let keyCount = min(max(0, descriptor.keyCount), max(0, encodedKeyCount))
            for _ in 0..<keyCount {
                let keyOffset = cursor.offset
                let id = try cursor.readUInt64LE()
                let valueIndex = Int(try cursor.readInt32LE())
                let value = valueIndex >= 0 && valueIndex < values.count ? values[valueIndex] : nil
                entries.append(ParsedFlatEntry(
                    id: id,
                    keyOffset: keyOffset,
                    valueIndex: valueIndex,
                    typeHash: descriptor.typeHash,
                    typeName: descriptor.typeName,
                    value: value
                ))
            }
            endOffset = cursor.offset
        } catch {
            warnings.append(String(describing: error))
        }

        let report = AddonProbeTweakDBFlatTypeSection(
            typeHashHex: hex(descriptor.typeHash),
            typeName: descriptor.typeName,
            descriptorOffset: descriptor.descriptorOffset,
            valueBlockOffset: descriptor.valueBlockOffset,
            valueCount: descriptor.valueCount,
            keyCount: descriptor.keyCount,
            parsedValueCount: values.count,
            parsedKeyCount: entries.count,
            keyBlockOffset: keyBlockOffset,
            endOffset: endOffset,
            confidence: warnings.isEmpty && descriptor.typeName != nil ? .high : (descriptor.typeName == nil ? .low : .medium),
            sampleValues: values.prefix(maxSampleCount).map(\.summary),
            sampleKeys: entries.prefix(maxSampleCount).map { "\(hex($0.id)) -> value[\($0.valueIndex)] \($0.value?.summary ?? "?")" },
            warnings: warnings
        )
        return ParsedFlatType(report: report, entries: entries)
    }

    private static func parseFlatValue(typeName: String?, cursor: inout Cursor) throws -> ParsedFlatValue {
        guard let typeName else {
            throw CyberMacError.invalidInput("Cannot parse flat value with unknown type at offset \(cursor.offset).")
        }
        if typeName.hasPrefix("array:") {
            return try parseArrayFlatValue(elementType: String(typeName.dropFirst("array:".count)), cursor: &cursor)
        }
        return try parseScalarFlatValue(typeName: typeName, cursor: &cursor)
    }

    private static func parseScalarFlatValue(typeName: String, cursor: inout Cursor) throws -> ParsedFlatValue {
        switch typeName {
        case "Bool":
            return ParsedFlatValue(summary: try cursor.readUInt8() == 0 ? "false" : "true", referencedIDs: [])
        case "Uint8":
            return ParsedFlatValue(summary: "\(try cursor.readUInt8())", referencedIDs: [])
        case "Int8":
            return ParsedFlatValue(summary: "\(Int8(bitPattern: try cursor.readUInt8()))", referencedIDs: [])
        case "Uint16":
            return ParsedFlatValue(summary: "\(try cursor.readUInt16LE())", referencedIDs: [])
        case "Int16":
            return ParsedFlatValue(summary: "\(Int16(bitPattern: try cursor.readUInt16LE()))", referencedIDs: [])
        case "Uint32":
            return ParsedFlatValue(summary: "\(try cursor.readUInt32LE())", referencedIDs: [])
        case "Int32":
            return ParsedFlatValue(summary: "\(try cursor.readInt32LE())", referencedIDs: [])
        case "Uint64":
            return ParsedFlatValue(summary: "\(try cursor.readUInt64LE())", referencedIDs: [])
        case "Int64":
            return ParsedFlatValue(summary: "\(Int64(bitPattern: try cursor.readUInt64LE()))", referencedIDs: [])
        case "Float":
            return ParsedFlatValue(summary: "\(try cursor.readFloat32LE())", referencedIDs: [])
        case "String", "CName":
            return ParsedFlatValue(summary: "\"\(truncate(try cursor.readLengthPrefixedString(), limit: 120))\"", referencedIDs: [])
        case "TweakDBID":
            let value = try cursor.readUInt64LE()
            return ParsedFlatValue(summary: "TweakDBID \(hex(value))", referencedIDs: [value])
        case "gamedataLocKeyWrapper":
            return ParsedFlatValue(summary: "LocKey \(try cursor.readUInt64LE())", referencedIDs: [])
        case "raRef:CResource":
            return ParsedFlatValue(summary: "ResourcePathHash \(hex(try cursor.readUInt64LE()))", referencedIDs: [])
        case "Color":
            return ParsedFlatValue(summary: "Color \(hex(try cursor.readUInt32LE()))", referencedIDs: [])
        case "Vector2":
            let x = try cursor.readFloat32LE()
            let y = try cursor.readFloat32LE()
            return ParsedFlatValue(summary: "Vector2(\(x), \(y))", referencedIDs: [])
        case "Vector3":
            let x = try cursor.readFloat32LE()
            let y = try cursor.readFloat32LE()
            let z = try cursor.readFloat32LE()
            return ParsedFlatValue(summary: "Vector3(\(x), \(y), \(z))", referencedIDs: [])
        case "EulerAngles":
            let pitch = try cursor.readFloat32LE()
            let yaw = try cursor.readFloat32LE()
            let roll = try cursor.readFloat32LE()
            return ParsedFlatValue(summary: "EulerAngles(\(pitch), \(yaw), \(roll))", referencedIDs: [])
        case "Quaternion":
            let i = try cursor.readFloat32LE()
            let j = try cursor.readFloat32LE()
            let k = try cursor.readFloat32LE()
            let r = try cursor.readFloat32LE()
            return ParsedFlatValue(summary: "Quaternion(\(i), \(j), \(k), \(r))", referencedIDs: [])
        default:
            throw CyberMacError.invalidInput("Unsupported flat scalar type \(typeName) at offset \(cursor.offset).")
        }
    }

    private static func parseArrayFlatValue(elementType: String, cursor: inout Cursor) throws -> ParsedFlatValue {
        let count = try cursor.readVLQInt32()
        guard count >= 0, count < 1_000_000 else {
            throw CyberMacError.invalidInput("Unreasonable array count \(count) at offset \(cursor.offset).")
        }
        var summaries: [String] = []
        var references: [UInt64] = []
        for index in 0..<count {
            let value = try parseScalarFlatValue(typeName: elementType, cursor: &cursor)
            references.append(contentsOf: value.referencedIDs)
            if index < maxSampleCount {
                summaries.append(value.summary)
            }
        }
        let suffix = count > maxSampleCount ? ", ..." : ""
        return ParsedFlatValue(summary: "[\(summaries.joined(separator: ", "))\(suffix)] count=\(count)", referencedIDs: references)
    }

    private static func parseRecords(
        bytes: [UInt8],
        offset: Int,
        endOffset: Int,
        recordHashNames: [UInt32: String]
    ) throws -> [AddonProbeTweakDBRecordTableEntry] {
        var cursor = Cursor(bytes: bytes, offset: offset)
        let count = Int(try cursor.readUInt32LE())
        guard count >= 0, offset + 4 + count * 12 <= min(endOffset, bytes.count) else {
            throw CyberMacError.invalidInput("Record table count \(count) does not fit in section.")
        }
        return try (0..<count).map { index in
            let entryOffset = cursor.offset
            let id = try cursor.readUInt64LE()
            let typeHash = try cursor.readUInt32LE()
            return AddonProbeTweakDBRecordTableEntry(
                tableIndex: index,
                offset: entryOffset,
                recordID: id,
                recordIDHex: hex(id),
                recordTypeHash: typeHash,
                recordTypeHashHex: hex(typeHash),
                recordTypeName: recordHashNames[typeHash]
            )
        }
    }

    private static func parseQueries(bytes: [UInt8], offset: Int, endOffset: Int) throws -> (count: Int, samples: [String]) {
        var cursor = Cursor(bytes: bytes, offset: offset)
        let count = Int(try cursor.readUInt32LE())
        guard count >= 0 else {
            throw CyberMacError.invalidInput("Invalid query count \(count).")
        }
        var samples: [String] = []
        for index in 0..<count {
            guard cursor.offset + 12 <= min(endOffset, bytes.count) else { break }
            let queryID = try cursor.readUInt64LE()
            let resultCount = Int(try cursor.readUInt32LE())
            if index < maxSampleCount || index >= max(0, count - maxSampleCount) {
                samples.append("\(index): \(hex(queryID)) results=\(resultCount)")
            }
            guard resultCount >= 0, cursor.offset + resultCount * 8 <= min(endOffset, bytes.count) else { break }
            try cursor.skip(resultCount * 8)
        }
        return (count, samples)
    }

    private static func parseGroupTags(bytes: [UInt8], offset: Int) throws -> (count: Int, samples: [String]) {
        var cursor = Cursor(bytes: bytes, offset: offset)
        let count = Int(try cursor.readUInt32LE())
        guard count >= 0 else {
            throw CyberMacError.invalidInput("Invalid group tag count \(count).")
        }
        var samples: [String] = []
        for index in 0..<count {
            guard cursor.offset + 9 <= bytes.count else { break }
            let id = try cursor.readUInt64LE()
            let tag = try cursor.readUInt8()
            if index < maxSampleCount || index >= max(0, count - maxSampleCount) {
                samples.append("\(index): \(hex(id)) tag=\(tag)")
            }
        }
        return (count, samples)
    }

    private static func makeSections(
        bytes: [UInt8],
        header: AddonProbeTweakDBParsedHeader,
        flatTypes: [AddonProbeTweakDBFlatTypeSection],
        records: [AddonProbeTweakDBRecordTableEntry],
        queries: [String],
        queryCount: Int,
        groupTags: [String],
        groupTagCount: Int
    ) throws -> [AddonProbeTweakDBStructureSection] {
        var sections: [AddonProbeTweakDBStructureSection] = [
            AddonProbeTweakDBStructureSection(
                name: "fileHeader",
                role: "WolvenKit/FileHeader: magic, versions, checksum, section offsets",
                offset: 0,
                size: min(fileHeaderSize, bytes.count),
                count: nil,
                confidence: header.validWolvenKitHeader ? .high : .low,
                firstEntries: [
                    "magic=\(header.magicHex)",
                    "blobVersion=\(header.blobVersion)",
                    "parserVersion=\(header.parserVersion)",
                    "recordsChecksum=\(header.recordsChecksumHex)"
                ],
                lastEntries: [
                    "flatsOffset=\(header.flatsOffset)",
                    "recordsOffset=\(header.recordsOffset)",
                    "queriesOffset=\(header.queriesOffset)",
                    "groupTagsOffset=\(header.groupTagsOffset)"
                ],
                notes: []
            ),
            AddonProbeTweakDBStructureSection(
                name: "flatsPool",
                role: "Flat/value table: typed value pools followed by TweakDBID key -> value index tables",
                offset: header.flatsOffset,
                size: max(0, header.recordsOffset - header.flatsOffset),
                count: flatTypes.count,
                confidence: flatTypes.allSatisfy { $0.confidence == .high } ? .high : .medium,
                firstEntries: flatTypes.prefix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) values=\($0.valueCount) keys=\($0.keyCount) offset=\($0.valueBlockOffset)" },
                lastEntries: flatTypes.suffix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) values=\($0.valueCount) keys=\($0.keyCount) offset=\($0.valueBlockOffset)" },
                notes: [
                    "String and CName values are not a separate global name table; they are typed flat values inside this pool.",
                    "Keys are 64-bit TweakDBIDs: low32 CRC32(name), high32 name length."
                ]
            ),
            AddonProbeTweakDBStructureSection(
                name: "recordTable",
                role: "Record table: TweakDBID -> Murmur3 record type hash",
                offset: header.recordsOffset,
                size: max(0, header.queriesOffset - header.recordsOffset),
                count: records.count,
                confidence: .high,
                firstEntries: records.prefix(maxSampleCount).map { "\($0.recordIDHex) type=\($0.recordTypeName ?? $0.recordTypeHashHex) offset=\($0.offset)" },
                lastEntries: records.suffix(maxSampleCount).map { "\($0.recordIDHex) type=\($0.recordTypeName ?? $0.recordTypeHashHex) offset=\($0.offset)" },
                notes: [
                    "Record names are not stored as plaintext here; resolving names requires computing TweakDBID from candidate names."
                ]
            ),
            AddonProbeTweakDBStructureSection(
                name: "queryTable",
                role: "Query table: query TweakDBID -> result record IDs",
                offset: header.queriesOffset,
                size: max(0, header.groupTagsOffset - header.queriesOffset),
                count: queryCount,
                confidence: .high,
                firstEntries: Array(queries.prefix(maxSampleCount)),
                lastEntries: Array(queries.suffix(maxSampleCount)),
                notes: []
            ),
            AddonProbeTweakDBStructureSection(
                name: "groupTagTable",
                role: "Group tag table: TweakDBID -> byte tag",
                offset: header.groupTagsOffset,
                size: max(0, bytes.count - header.groupTagsOffset),
                count: groupTagCount,
                confidence: .high,
                firstEntries: Array(groupTags.prefix(maxSampleCount)),
                lastEntries: Array(groupTags.suffix(maxSampleCount)),
                notes: []
            )
        ]

        if !flatTypes.isEmpty {
            sections.insert(AddonProbeTweakDBStructureSection(
                name: "flatTypeDescriptorTable",
                role: "Type table inside flatsPool: FNV1a64 flat type hash, value count, key count, value block offset",
                offset: header.flatsOffset + 4,
                size: flatTypes.count * flatTypeDescriptorSize,
                count: flatTypes.count,
                confidence: flatTypes.allSatisfy { $0.typeName != nil } ? .high : .medium,
                firstEntries: flatTypes.prefix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) descriptor=\($0.descriptorOffset) valueBlock=\($0.valueBlockOffset)" },
                lastEntries: flatTypes.suffix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) descriptor=\($0.descriptorOffset) valueBlock=\($0.valueBlockOffset)" },
                notes: [
                    "This is a derived sub-section. The file header points to flatsPool, whose first bytes contain these descriptors."
                ]
            ), at: 2)

            let keyTables = flatTypes.filter { $0.keyBlockOffset != nil }
            if !keyTables.isEmpty {
                let minKeyOffset = keyTables.compactMap(\.keyBlockOffset).min() ?? header.flatsOffset
                let totalKnownKeyBytes = keyTables.reduce(0) { partial, flatType in
                    guard let keyBlockOffset = flatType.keyBlockOffset, let endOffset = flatType.endOffset else { return partial }
                    return partial + max(0, endOffset - keyBlockOffset)
                }
                sections.insert(AddonProbeTweakDBStructureSection(
                    name: "flatKeyIndexTables",
                    role: "Hash/index tables inside flatsPool: TweakDBID flat key -> typed value index",
                    offset: minKeyOffset,
                    size: totalKnownKeyBytes,
                    count: keyTables.reduce(0) { $0 + $1.parsedKeyCount },
                    confidence: .medium,
                    firstEntries: keyTables.prefix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) keys=\($0.parsedKeyCount) keyBlock=\($0.keyBlockOffset.map(String.init) ?? "?")" },
                    lastEntries: keyTables.suffix(maxSampleCount).map { "\($0.typeName ?? $0.typeHashHex) keys=\($0.parsedKeyCount) keyBlock=\($0.keyBlockOffset.map(String.init) ?? "?")" },
                    notes: [
                        "Entries are keyed by TweakDBID hashes, so names resolve only when CyberMac can derive candidate names."
                    ]
                ), at: 3)
            }
        }

        let stringFlatTypes = flatTypes.filter { $0.typeName == "String" || $0.typeName == "CName" || $0.typeName == "array:String" || $0.typeName == "array:CName" }
        if !stringFlatTypes.isEmpty {
            sections.append(AddonProbeTweakDBStructureSection(
                name: "stringNameValues",
                role: "Derived view of string-bearing flat value blocks",
                offset: stringFlatTypes.map(\.valueBlockOffset).min() ?? header.flatsOffset,
                size: stringFlatTypes.compactMap { section in
                    guard let endOffset = section.endOffset else { return nil }
                    return endOffset - section.valueBlockOffset
                }.reduce(0, +),
                count: stringFlatTypes.reduce(0) { $0 + $1.valueCount },
                confidence: .medium,
                firstEntries: stringFlatTypes.prefix(maxSampleCount).map { "\($0.typeName ?? "?") values=\($0.valueCount) block=\($0.valueBlockOffset)" },
                lastEntries: stringFlatTypes.suffix(maxSampleCount).map { "\($0.typeName ?? "?") values=\($0.valueCount) block=\($0.valueBlockOffset)" },
                notes: [
                    "This is not an independent header section. It is a format-informed derived section inside flatsPool."
                ]
            ))
        }
        return sections
    }

    private static func trace(recordName: String, parsed: ParsedFile) -> AddonProbeTweakDBRecordTrace {
        let recordID = tweakDBID(recordName)
        let recordEntry = parsed.recordsByID[recordID]
        let knownFlats = itemRecordProperties.compactMap { property -> AddonProbeTweakDBFlatTrace? in
            let flatName = "\(recordName).\(property)"
            let flatID = tweakDBID(flatName)
            guard let entry = parsed.flatEntriesByID[flatID] else { return nil }
            return AddonProbeTweakDBFlatTrace(
                property: property,
                flatID: flatID,
                flatIDHex: hex(flatID),
                keyOffset: entry.keyOffset,
                typeName: entry.typeName,
                typeHashHex: hex(entry.typeHash),
                valueIndex: entry.valueIndex,
                valueSummary: entry.value?.summary,
                referencedTweakDBIDs: entry.value?.referencedIDs.map(hex) ?? []
            )
        }.sorted { $0.property < $1.property }

        let nearbyRecords: [AddonProbeTweakDBRecordTableEntry]
        if let recordEntry {
            let lower = max(0, recordEntry.tableIndex - 3)
            let upper = min(parsed.records.count, recordEntry.tableIndex + 4)
            nearbyRecords = Array(parsed.records[lower..<upper])
        } else {
            nearbyRecords = []
        }

        var status: [String] = []
        if recordEntry != nil {
            status.append("recordTableEntryResolved")
        } else {
            status.append("recordTableEntryNotFound")
        }
        if knownFlats.isEmpty {
            status.append("knownSchemaFlatsNotResolved")
        } else {
            status.append("knownSchemaFlatsResolved")
        }
        return AddonProbeTweakDBRecordTrace(
            recordName: recordName,
            recordID: recordID,
            recordIDHex: hex(recordID),
            recordTableEntry: recordEntry,
            parentBaseRecord: nil,
            parentBaseRecordStatus: "Not directly encoded in the parsed record table. WolvenKit/TweakXL clone/inherit behavior creates or copies record flats; this pass only resolves flats with known property names.",
            knownFlatCount: knownFlats.count,
            knownFlatCountConfidence: knownFlats.isEmpty ? .unknown : .medium,
            knownFlats: knownFlats,
            nearbyRecords: nearbyRecords,
            traceStatus: status
        )
    }

    private static func conclusions(parsed: ParsedFile, traces: [AddonProbeTweakDBRecordTrace]) -> [AddonProbeTweakDBStructureConclusion] {
        var result: [AddonProbeTweakDBStructureConclusion] = []
        if parsed.header.validWolvenKitHeader { result.append(.wolvenKitHeaderMatched) }
        if !parsed.sections.isEmpty { result.append(.sectionsMapped) }
        if !parsed.records.isEmpty { result.append(.recordTableParsed) }
        if !parsed.flatTypeReports.isEmpty { result.append(.flatTableParsed) }
        if traces.contains(where: { $0.recordTableEntry != nil }) { result.append(.queryRecordsResolved) }
        if traces.contains(where: { $0.recordTableEntry == nil }) { result.append(.queryRecordsUnresolved) }
        if result.isEmpty { result.append(.unresolved) }
        return result
    }

    private static func normalizedRecords(_ records: [String]) -> [String] {
        let cleaned = records
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? defaultRecords : AddonProbeManager.orderedUnique(cleaned)
    }

    private static func commonWarnings() -> [String] {
        [
            "Read-only analysis only. No game files were modified.",
            "Parser is grounded in WolvenKit's TweakDB Header/TweakDBReader/TweakDBWriter layout, but record property resolution is limited to known item schema fields.",
            "This command does not prove that offline extension is safe; it maps the static blob structure needed for a future patch design."
        ]
    }

    private static func readData(_ url: URL) throws -> Data {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("TweakDB binary file not found: \(url.path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("Expected a file, got directory: \(url.path)")
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private static func ensureOutputIsNotInsideInspectedApp(inputFileURL: URL, outputDirectoryURL: URL) throws {
        let components = inputFileURL.standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return
        }
        let appPath = NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
        let outputPath = outputDirectoryURL.standardizedFileURL.path
        if outputPath == appPath || outputPath.hasPrefix(appPath + "/") {
            throw CyberMacError.invalidInput("Refusing to write TweakDB structure output inside the game app: \(outputPath)")
        }
    }

    private static func validateOffset(_ offset: Int, count: Int, label: String) throws {
        guard offset >= 0, offset <= count else {
            throw CyberMacError.invalidInput("Invalid \(label): \(offset) outside file size \(count).")
        }
    }

    private static func tweakDBID(_ name: String) -> UInt64 {
        let bytes = Array(name.utf8)
        let crc = TweakDBPackedStringAnalyzer.crc32(bytes)
        return (UInt64(bytes.count) << 32) | UInt64(crc)
    }

    private static func murmur3_32(_ string: String, seed: UInt32) -> UInt32 {
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
        if remaining == 3 {
            k1 ^= UInt32(data[roundedEnd + 2]) << 16
        }
        if remaining >= 2 {
            k1 ^= UInt32(data[roundedEnd + 1]) << 8
        }
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

    private static func hex(_ value: UInt32) -> String {
        String(format: "0x%08x", value)
    }

    private static func hex(_ value: UInt64) -> String {
        String(format: "0x%016llx", value)
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "..."
    }

    private static func writeSections(_ report: AddonProbeTweakDBStructureReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB structure inspection",
            "Status: read-only; no game files were modified.",
            "Header: magic=\(report.header.magicHex) blob=\(report.header.blobVersion) parser=\(report.header.parserVersion) checksum=\(report.header.recordsChecksumHex)",
            ""
        ]
        for section in report.sections {
            lines.append("[\(section.name)] \(section.role)")
            lines.append("  offset=\(section.offset) size=\(section.size) count=\(section.count.map(String.init) ?? "?") confidence=\(section.confidence.rawValue)")
            if !section.firstEntries.isEmpty {
                lines.append("  first:")
                lines.append(contentsOf: section.firstEntries.map { "    \($0)" })
            }
            if !section.lastEntries.isEmpty {
                lines.append("  last:")
                lines.append(contentsOf: section.lastEntries.map { "    \($0)" })
            }
            if !section.notes.isEmpty {
                lines.append("  notes:")
                lines.append(contentsOf: section.notes.map { "    \($0)" })
            }
            lines.append("")
        }
        lines.append("Flat type sections:")
        for flatType in report.flatTypeSections {
            lines.append("- \(flatType.typeName ?? flatType.typeHashHex): values=\(flatType.valueCount) keys=\(flatType.keyCount) block=\(flatType.valueBlockOffset) parsedValues=\(flatType.parsedValueCount) parsedKeys=\(flatType.parsedKeyCount) confidence=\(flatType.confidence.rawValue)")
            for warning in flatType.warnings {
                lines.append("  warning: \(warning)")
            }
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeRecordTraces(_ traces: [AddonProbeTweakDBRecordTrace], to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB record traces",
            "Status: read-only; no game files were modified.",
            ""
        ]
        for trace in traces {
            lines.append("[record] \(trace.recordName) id=\(trace.recordIDHex)")
            if let entry = trace.recordTableEntry {
                lines.append("  record table: index=\(entry.tableIndex) offset=\(entry.offset) type=\(entry.recordTypeName ?? entry.recordTypeHashHex)")
            } else {
                lines.append("  record table: not found")
            }
            lines.append("  known flats: \(trace.knownFlatCount) confidence=\(trace.knownFlatCountConfidence.rawValue)")
            if !trace.knownFlats.isEmpty {
                for flat in trace.knownFlats {
                    lines.append("    .\(flat.property) \(flat.typeName ?? flat.typeHashHex) keyOffset=\(flat.keyOffset) valueIndex=\(flat.valueIndex) value=\(flat.valueSummary ?? "?")")
                }
            }
            lines.append("  parent/base: \(trace.parentBaseRecordStatus)")
            lines.append("  status: \(trace.traceStatus.joined(separator: ", "))")
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

public enum AddonProbeTweakDBStructureFormatter {
    public static func format(_ report: AddonProbeTweakDBStructureReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB structure inspection",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Size: \(report.size)",
            "Header: magic=\(report.header.magicHex) blob=\(report.header.blobVersion) parser=\(report.header.parserVersion)",
            "Offsets: flats=\(report.header.flatsOffset) records=\(report.header.recordsOffset) queries=\(report.header.queriesOffset) groupTags=\(report.header.groupTagsOffset)",
            "Sections: \(report.sections.count)",
            "Flat type sections: \(report.flatTypeSections.count)",
            "Records: \(report.recordCount)",
            "Queries: \(report.queryCount)",
            "Group tags: \(report.groupTagCount)",
            "Resolved record reports: \(report.resolvedRecords.count)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Sections: \(PathSafety.redactUserPath(report.sectionsPath))",
            "Record traces: \(PathSafety.redactUserPath(report.recordTracesPath))"
        ]
        appendWarnings(report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBStructureReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendWarnings(_ warnings: [String], to lines: inout [String]) {
        guard !warnings.isEmpty else { return }
        lines.append("")
        lines.append("Warnings:")
        lines.append(contentsOf: warnings.map { "- \($0)" })
    }
}

public enum AddonProbeTweakDBRecordTraceFormatter {
    public static func format(_ report: AddonProbeTweakDBRecordTraceReport) -> String {
        let trace = report.trace
        var lines: [String] = [
            "CyberMac TweakDB record trace",
            "Status: read-only; no game files were modified.",
            "File: \(PathSafety.redactUserPath(report.filePath))",
            "Record: \(trace.recordName)",
            "Record ID: \(trace.recordIDHex)"
        ]
        if let entry = trace.recordTableEntry {
            lines.append("Record table: index=\(entry.tableIndex) offset=\(entry.offset) type=\(entry.recordTypeName ?? entry.recordTypeHashHex)")
        } else {
            lines.append("Record table: not found")
        }
        lines.append("Known flats: \(trace.knownFlatCount) confidence=\(trace.knownFlatCountConfidence.rawValue)")
        lines.append("Trace: \(PathSafety.redactUserPath(report.tracePath))")
        lines.append("Report: \(PathSafety.redactUserPath(report.reportPath))")
        if !trace.traceStatus.isEmpty {
            lines.append("Status: \(trace.traceStatus.joined(separator: ", "))")
        }
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBRecordTraceReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}
