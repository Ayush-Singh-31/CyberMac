import Foundation

public enum AddonProbeTweakDBCloneOverride: Equatable, Sendable {
    case cName(property: String, value: String)
    case string(property: String, value: String)
    case tweakDBID(property: String, value: String)
    case locKey(property: String, value: UInt64)

    public var property: String {
        switch self {
        case .cName(let property, _): return property
        case .string(let property, _): return property
        case .tweakDBID(let property, _): return property
        case .locKey(let property, _): return property
        }
    }

    public var typeName: String {
        switch self {
        case .cName: return "CName"
        case .string: return "String"
        case .tweakDBID: return "TweakDBID"
        case .locKey: return "gamedataLocKeyWrapper"
        }
    }

    public var kind: String {
        switch self {
        case .cName: return "cName"
        case .string: return "string"
        case .tweakDBID: return "tweakDBID"
        case .locKey: return "locKey"
        }
    }
}

public struct AddonProbeTweakDBCloneRecordRequest: Sendable {
    public let fileURL: URL
    public let outputDirectoryURL: URL
    public let sourceRecord: String
    public let newRecord: String
    public let overrides: [AddonProbeTweakDBCloneOverride]

    public init(
        fileURL: URL,
        outputDirectoryURL: URL,
        sourceRecord: String,
        newRecord: String,
        overrides: [AddonProbeTweakDBCloneOverride] = []
    ) {
        self.fileURL = fileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.sourceRecord = sourceRecord
        self.newRecord = newRecord
        self.overrides = overrides
    }
}

public enum AddonProbeTweakDBCloneRecordConclusion: String, Codable, Equatable, Sendable {
    case stagedCloneProduced
    case stagedCloneParsed
    case newRecordResolved
    case overrideFlatsResolved
    case checksumUnverified
    case writerIncomplete
    case failed
}

public struct AddonProbeTweakDBCloneFlatPlan: Codable, Equatable, Sendable {
    public let property: String
    public let typeName: String?
    public let typeHashHex: String
    public let sourceFlatIDHex: String
    public let newFlatIDHex: String
    public let sourceValueIndex: Int
    public let newValueIndex: Int
    public let valueAppended: Bool
    public let valueSummary: String?
    public let overrideKind: String?
    public let unresolved: Bool
}

public struct AddonProbeTweakDBCloneRecordReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let outputDirectoryPath: String
    public let stagedFilePath: String
    public let sourceRecord: String
    public let sourceRecordIDHex: String
    public let sourceRecordTypeHashHex: String
    public let sourceRecordTypeName: String?
    public let newRecord: String
    public let newRecordIDHex: String
    public let originalSize: Int
    public let stagedSize: Int
    public let stagedSHA256: String
    public let knownSchemaPropertyCount: Int
    public let clonedFlats: [AddonProbeTweakDBCloneFlatPlan]
    public let appliedOverrides: [AddonProbeTweakDBCloneFlatPlan]
    public let verificationStatus: String
    public let verification: AddonProbeTweakDBRecordTrace?
    public let conclusions: [AddonProbeTweakDBCloneRecordConclusion]
    public let warnings: [String]
    public let reportPath: String
    public let summaryPath: String
    public let verificationReportPath: String?
}

public struct TweakDBCloneRecordStager: Sendable {
    public init() {}

    public func stage(request: AddonProbeTweakDBCloneRecordRequest) throws -> AddonProbeTweakDBCloneRecordReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.ensureOutputIsNotInputFile(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.validateRecordName(request.sourceRecord, label: "--source-record")
        try Self.validateRecordName(request.newRecord, label: "--new-record")
        for override in request.overrides {
            try Self.validateProperty(override.property)
        }
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let originalData = try Self.readData(fileURL)
        var parsed = try Self.parse(data: originalData)

        let sourceRecordID = Self.tweakDBID(request.sourceRecord)
        let newRecordID = Self.tweakDBID(request.newRecord)

        guard let sourceRecord = parsed.records.first(where: { $0.id == sourceRecordID }) else {
            throw CyberMacError.invalidInput("Source record \(request.sourceRecord) was not found in \(fileURL.path).")
        }
        if parsed.records.contains(where: { $0.id == newRecordID }) {
            throw CyberMacError.invalidInput("New record \(request.newRecord) already exists in \(fileURL.path). Refusing to overwrite.")
        }

        let sourceTypeHashHex = Self.hex(sourceRecord.typeHash)
        let sourceTypeName = Self.recordTypeNameForHash[sourceRecord.typeHash]

        var clonedFlats: [AddonProbeTweakDBCloneFlatPlan] = []
        for property in TweakDBStructureInspector.itemRecordProperties {
            let sourceFlatID = Self.tweakDBID("\(request.sourceRecord).\(property)")
            guard let location = parsed.flatLocationByID[sourceFlatID] else { continue }
            let newFlatID = Self.tweakDBID("\(request.newRecord).\(property)")
            let type = parsed.flatTypes[location.typeIndex]
            let key = type.keys[location.keyIndex]
            let value = key.valueIndex >= 0 && key.valueIndex < type.parsedValues.count ? type.parsedValues[key.valueIndex] : nil
            parsed.flatTypes[location.typeIndex].keys.append(StagerKey(id: newFlatID, valueIndex: key.valueIndex))
            parsed.flatLocationByID[newFlatID] = StagerFlatLocation(
                typeIndex: location.typeIndex,
                keyIndex: parsed.flatTypes[location.typeIndex].keys.count - 1
            )
            clonedFlats.append(AddonProbeTweakDBCloneFlatPlan(
                property: property,
                typeName: type.typeName,
                typeHashHex: Self.hex(type.typeHash),
                sourceFlatIDHex: Self.hex(sourceFlatID),
                newFlatIDHex: Self.hex(newFlatID),
                sourceValueIndex: key.valueIndex,
                newValueIndex: key.valueIndex,
                valueAppended: false,
                valueSummary: value?.summary,
                overrideKind: nil,
                unresolved: false
            ))
        }

        var appliedOverrides: [AddonProbeTweakDBCloneFlatPlan] = []
        var overrideWarnings: [String] = []
        for override in request.overrides {
            let typeName = override.typeName
            guard let typeIndex = parsed.typeIndexByName[typeName] else {
                overrideWarnings.append("No \(typeName) flat type pool found in source file. Skipping override for \(override.property).")
                appliedOverrides.append(AddonProbeTweakDBCloneFlatPlan(
                    property: override.property,
                    typeName: typeName,
                    typeHashHex: Self.hex(UInt64(0)),
                    sourceFlatIDHex: Self.hex(UInt64(0)),
                    newFlatIDHex: Self.hex(Self.tweakDBID("\(request.newRecord).\(override.property)")),
                    sourceValueIndex: -1,
                    newValueIndex: -1,
                    valueAppended: false,
                    valueSummary: nil,
                    overrideKind: override.kind,
                    unresolved: true
                ))
                continue
            }
            let newFlatID = Self.tweakDBID("\(request.newRecord).\(override.property)")
            let prepared = Self.prepareOverrideValue(override: override)
            let pool = parsed.flatTypes[typeIndex]

            let existingValueIndex = pool.parsedValues.firstIndex { $0.equality == prepared.equality }
            let existingAppendedIndex = pool.appendedValues.firstIndex { $0.equality == prepared.equality }
            let valueIndex: Int
            let appended: Bool
            if let existingValueIndex {
                valueIndex = existingValueIndex
                appended = false
            } else if let existingAppendedIndex {
                valueIndex = pool.blockValueCount + existingAppendedIndex
                appended = false
            } else {
                guard pool.isHighConfidence else {
                    throw CyberMacError.invalidInput("Refusing override for '\(override.property)': the \(typeName) flat type pool has descriptor/block count mismatch (descriptor=\(pool.descriptorValueCount) block=\(pool.blockValueCount)). Appending a new value to a low-confidence section could corrupt the staged TweakDB.")
                }
                parsed.flatTypes[typeIndex].appendedValues.append(StagerValue(bytes: prepared.bytes, equality: prepared.equality, summary: prepared.summary))
                valueIndex = pool.blockValueCount + parsed.flatTypes[typeIndex].appendedValues.count - 1
                appended = true
            }

            if let existingKey = parsed.flatLocationByID[newFlatID], existingKey.typeIndex == typeIndex {
                parsed.flatTypes[typeIndex].keys[existingKey.keyIndex] = StagerKey(id: newFlatID, valueIndex: valueIndex)
            } else {
                parsed.flatTypes[typeIndex].keys.append(StagerKey(id: newFlatID, valueIndex: valueIndex))
                parsed.flatLocationByID[newFlatID] = StagerFlatLocation(
                    typeIndex: typeIndex,
                    keyIndex: parsed.flatTypes[typeIndex].keys.count - 1
                )
            }

            for index in 0..<clonedFlats.count where clonedFlats[index].property == override.property {
                clonedFlats[index] = AddonProbeTweakDBCloneFlatPlan(
                    property: clonedFlats[index].property,
                    typeName: clonedFlats[index].typeName,
                    typeHashHex: clonedFlats[index].typeHashHex,
                    sourceFlatIDHex: clonedFlats[index].sourceFlatIDHex,
                    newFlatIDHex: clonedFlats[index].newFlatIDHex,
                    sourceValueIndex: clonedFlats[index].sourceValueIndex,
                    newValueIndex: valueIndex,
                    valueAppended: appended,
                    valueSummary: prepared.summary,
                    overrideKind: override.kind,
                    unresolved: false
                )
            }

            appliedOverrides.append(AddonProbeTweakDBCloneFlatPlan(
                property: override.property,
                typeName: typeName,
                typeHashHex: Self.hex(parsed.flatTypes[typeIndex].typeHash),
                sourceFlatIDHex: Self.hex(UInt64(0)),
                newFlatIDHex: Self.hex(newFlatID),
                sourceValueIndex: -1,
                newValueIndex: valueIndex,
                valueAppended: appended,
                valueSummary: prepared.summary,
                overrideKind: override.kind,
                unresolved: false
            ))
        }

        parsed.records.append(StagerRecord(id: newRecordID, typeHash: sourceRecord.typeHash))

        let stagedData = try Self.write(parsed: parsed)
        let stagedDirectory = outputDirectoryURL.appendingPathComponent("staged", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
        let stagedFileURL = stagedDirectory.appendingPathComponent("tweakdb.bin")
        try stagedData.write(to: stagedFileURL, options: [.atomic])

        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-clone-stage.json")
        let summaryURL = outputDirectoryURL.appendingPathComponent("tweakdb-clone-stage.txt")
        let verificationURL = outputDirectoryURL.appendingPathComponent("tweakdb-clone-verification.txt")

        var conclusions: [AddonProbeTweakDBCloneRecordConclusion] = [.stagedCloneProduced, .checksumUnverified, .writerIncomplete]
        var warnings: [String] = Self.commonWarnings()
        warnings.append(contentsOf: overrideWarnings)

        var verification: AddonProbeTweakDBRecordTrace?
        var verificationStatus: String
        do {
            let report = try TweakDBStructureInspector().trace(request: AddonProbeTweakDBRecordTraceRequest(
                fileURL: stagedFileURL,
                record: request.newRecord,
                outputDirectoryURL: stagedDirectory
            ))
            verification = report.trace
            conclusions.append(.stagedCloneParsed)
            if report.trace.recordTableEntry != nil {
                conclusions.append(.newRecordResolved)
                verificationStatus = "newRecordResolvedInStagedFile"
            } else {
                verificationStatus = "newRecordNotResolvedInStagedFile"
                conclusions.append(.failed)
            }
            let knownOverridesResolved = request.overrides.allSatisfy { override in
                guard TweakDBStructureInspector.itemRecordProperties.contains(override.property) else { return true }
                guard !overrideWarnings.contains(where: { $0.contains(override.property) }) else { return false }
                return report.trace.knownFlats.contains { $0.property == override.property }
            }
            if knownOverridesResolved {
                conclusions.append(.overrideFlatsResolved)
            }
        } catch {
            verificationStatus = "stagedFileReparseFailed: \(error)"
            conclusions.append(.failed)
            warnings.append("Staged file failed to re-parse: \(error)")
        }

        let report = AddonProbeTweakDBCloneRecordReport(
            filePath: fileURL.path,
            outputDirectoryPath: outputDirectoryURL.path,
            stagedFilePath: stagedFileURL.path,
            sourceRecord: request.sourceRecord,
            sourceRecordIDHex: Self.hex(sourceRecordID),
            sourceRecordTypeHashHex: sourceTypeHashHex,
            sourceRecordTypeName: sourceTypeName,
            newRecord: request.newRecord,
            newRecordIDHex: Self.hex(newRecordID),
            originalSize: originalData.count,
            stagedSize: stagedData.count,
            stagedSHA256: PathSafety.sha256(data: stagedData),
            knownSchemaPropertyCount: TweakDBStructureInspector.itemRecordProperties.count,
            clonedFlats: clonedFlats,
            appliedOverrides: appliedOverrides,
            verificationStatus: verificationStatus,
            verification: verification,
            conclusions: conclusions,
            warnings: warnings,
            reportPath: reportURL.path,
            summaryPath: summaryURL.path,
            verificationReportPath: verification != nil ? verificationURL.path : nil
        )

        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        try Self.writeSummary(report, to: summaryURL)
        if let verification {
            try Self.writeVerification(report.newRecord, trace: verification, to: verificationURL)
        }
        return report
    }

    private struct StagerFile {
        let originalData: Data
        let magic: UInt32
        let blobVersion: UInt32
        let parserVersion: UInt32
        let recordsChecksum: UInt32
        let queryBlockBytes: Data
        let groupTagBlockBytes: Data
        var flatTypes: [StagerFlatType]
        var records: [StagerRecord]
        var flatLocationByID: [UInt64: StagerFlatLocation]
        var typeIndexByName: [String: Int]
    }

    private struct StagerFlatType {
        let typeHash: UInt64
        let typeName: String?
        let descriptorOffset: Int
        let valueBlockOffset: Int
        let descriptorValueCount: Int
        let blockValueCount: Int
        let descriptorKeyCount: Int
        let blockKeyCount: Int
        let valueBytesRange: Range<Int>
        let keyTableRange: Range<Int>
        let isHighConfidence: Bool
        let preservedValueBlockBytes: Data
        var parsedValues: [StagerValue]
        var appendedValues: [StagerValue]
        var keys: [StagerKey]
    }

    private struct StagerValue: Equatable {
        let bytes: Data
        let equality: StagerValueEquality
        let summary: String
    }

    private enum StagerValueEquality: Equatable {
        case cName(String)
        case string(String)
        case tweakDBID(UInt64)
        case locKey(UInt64)
        case raw(Data)
    }

    private struct StagerKey: Equatable {
        let id: UInt64
        let valueIndex: Int
    }

    private struct StagerRecord {
        let id: UInt64
        let typeHash: UInt32
    }

    private struct StagerFlatLocation {
        let typeIndex: Int
        let keyIndex: Int
    }

    private struct PreparedOverride {
        let bytes: Data
        let equality: StagerValueEquality
        let summary: String
    }

    private static let magic: UInt32 = 0x0BB1DB47
    private static let blobVersion: UInt32 = 8
    private static let parserVersion: UInt32 = 4
    private static let fileHeaderSize = 0x20
    private static let flatTypeDescriptorSize = 20

    private static let supportedTypeNames = [
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

    private static let recordsSeed: UInt32 = 0x5EEDBA5E

    private static let recordTypeNameForHash: [UInt32: String] = {
        var map: [UInt32: String] = [:]
        for name in recordTypeNames {
            map[murmur3_32(name, seed: recordsSeed)] = name
        }
        return map
    }()

    private static func parse(data: Data) throws -> StagerFile {
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

        guard magicValue == magic, blobVersionValue == blobVersion, parserVersionValue == parserVersion else {
            throw CyberMacError.invalidInput("Unsupported TweakDB header: magic=\(hex(magicValue)) blob=\(blobVersionValue) parser=\(parserVersionValue)")
        }
        try validateOffset(flatsOffset, count: bytes.count, label: "flats offset")
        try validateOffset(recordsOffset, count: bytes.count, label: "records offset")
        try validateOffset(queriesOffset, count: bytes.count, label: "queries offset")
        try validateOffset(groupTagsOffset, count: bytes.count, label: "group tags offset")

        let typeHashNames = Dictionary(uniqueKeysWithValues: supportedTypeNames.map { (TweakDBPackedStringAnalyzer.fnv1a64(Array($0.utf8)), $0) })

        var typeCursor = Cursor(bytes: bytes, offset: flatsOffset)
        let typeCount = Int(try typeCursor.readUInt32LE())
        guard typeCount >= 0, typeCount < 256 else {
            throw CyberMacError.invalidInput("Unreasonable flat type count \(typeCount) at offset \(flatsOffset).")
        }
        var descriptors: [(typeHash: UInt64, typeName: String?, valueCount: Int, keyCount: Int, valueBlockOffset: Int, descriptorOffset: Int)] = []
        for index in 0..<typeCount {
            let descriptorOffset = flatsOffset + 4 + index * flatTypeDescriptorSize
            let typeHash = try typeCursor.readUInt64LE()
            let valueCount = Int(try typeCursor.readUInt32LE())
            let keyCount = Int(try typeCursor.readUInt32LE())
            let valueBlockOffset = Int(try typeCursor.readUInt32LE())
            descriptors.append((typeHash, typeHashNames[typeHash], valueCount, keyCount, valueBlockOffset, descriptorOffset))
        }

        var flatTypes: [StagerFlatType] = []
        var typeIndexByName: [String: Int] = [:]
        var flatLocationByID: [UInt64: StagerFlatLocation] = [:]
        for (typeIndex, descriptor) in descriptors.enumerated() {
            try validateOffset(descriptor.valueBlockOffset, count: bytes.count, label: "flat value block offset")
            var blockCursor = Cursor(bytes: bytes, offset: descriptor.valueBlockOffset)
            let valueBlockStart = blockCursor.offset
            let encodedValueCount = Int(try blockCursor.readUInt32LE())
            guard encodedValueCount >= 0, encodedValueCount < 10_000_000 else {
                throw CyberMacError.invalidInput("Unreasonable flat value count \(encodedValueCount) at offset \(valueBlockStart).")
            }
            var parsedValues: [StagerValue] = []
            for _ in 0..<encodedValueCount {
                let start = blockCursor.offset
                let parsed = try parseValueForStager(typeName: descriptor.typeName, cursor: &blockCursor)
                let end = blockCursor.offset
                let valueBytes = Data(bytes[start..<end])
                parsedValues.append(StagerValue(bytes: valueBytes, equality: parsed.equality, summary: parsed.summary))
            }
            let keyBlockStart = blockCursor.offset
            let encodedKeyCount = Int(try blockCursor.readUInt32LE())
            guard encodedKeyCount >= 0, encodedKeyCount < 10_000_000 else {
                throw CyberMacError.invalidInput("Unreasonable flat key count \(encodedKeyCount) at offset \(keyBlockStart).")
            }
            var keys: [StagerKey] = []
            for keyIndex in 0..<encodedKeyCount {
                let id = try blockCursor.readUInt64LE()
                let valueIndex = Int(try blockCursor.readInt32LE())
                keys.append(StagerKey(id: id, valueIndex: valueIndex))
                flatLocationByID[id] = StagerFlatLocation(typeIndex: typeIndex, keyIndex: keyIndex)
            }
            let keyTableEnd = blockCursor.offset
            let valueBytesRange = valueBlockStart..<keyBlockStart
            let keyTableRange = keyBlockStart..<keyTableEnd
            let isHighConfidence = encodedValueCount == descriptor.valueCount

            flatTypes.append(StagerFlatType(
                typeHash: descriptor.typeHash,
                typeName: descriptor.typeName,
                descriptorOffset: descriptor.descriptorOffset,
                valueBlockOffset: descriptor.valueBlockOffset,
                descriptorValueCount: descriptor.valueCount,
                blockValueCount: encodedValueCount,
                descriptorKeyCount: descriptor.keyCount,
                blockKeyCount: encodedKeyCount,
                valueBytesRange: valueBytesRange,
                keyTableRange: keyTableRange,
                isHighConfidence: isHighConfidence,
                preservedValueBlockBytes: Data(bytes[valueBytesRange]),
                parsedValues: parsedValues,
                appendedValues: [],
                keys: keys
            ))
            if let typeName = descriptor.typeName {
                typeIndexByName[typeName] = typeIndex
            }
        }

        var recordCursor = Cursor(bytes: bytes, offset: recordsOffset)
        let recordCount = Int(try recordCursor.readUInt32LE())
        guard recordCount >= 0, recordsOffset + 4 + recordCount * 12 <= min(queriesOffset, bytes.count) else {
            throw CyberMacError.invalidInput("Record table count \(recordCount) does not fit in section.")
        }
        var records: [StagerRecord] = []
        for _ in 0..<recordCount {
            let id = try recordCursor.readUInt64LE()
            let typeHash = try recordCursor.readUInt32LE()
            records.append(StagerRecord(id: id, typeHash: typeHash))
        }

        let queryBlockBytes = Data(bytes[queriesOffset..<groupTagsOffset])
        let groupTagBlockBytes = Data(bytes[groupTagsOffset..<bytes.count])

        return StagerFile(
            originalData: data,
            magic: magicValue,
            blobVersion: blobVersionValue,
            parserVersion: parserVersionValue,
            recordsChecksum: checksum,
            queryBlockBytes: queryBlockBytes,
            groupTagBlockBytes: groupTagBlockBytes,
            flatTypes: flatTypes,
            records: records,
            flatLocationByID: flatLocationByID,
            typeIndexByName: typeIndexByName
        )
    }

    private struct ParsedScalar {
        let equality: StagerValueEquality
        let summary: String
    }

    private static func parseValueForStager(typeName: String?, cursor: inout Cursor) throws -> ParsedScalar {
        guard let typeName else {
            throw CyberMacError.invalidInput("Cannot parse flat value with unknown type at offset \(cursor.offset).")
        }
        if typeName.hasPrefix("array:") {
            return try parseArrayForStager(elementType: String(typeName.dropFirst("array:".count)), cursor: &cursor)
        }
        return try parseScalarForStager(typeName: typeName, cursor: &cursor)
    }

    private static func parseScalarForStager(typeName: String, cursor: inout Cursor) throws -> ParsedScalar {
        switch typeName {
        case "Bool":
            let value = try cursor.readUInt8()
            return ParsedScalar(equality: .raw(Data([value])), summary: value == 0 ? "false" : "true")
        case "Uint8":
            let value = try cursor.readUInt8()
            return ParsedScalar(equality: .raw(Data([value])), summary: "\(value)")
        case "Int8":
            let raw = try cursor.readUInt8()
            return ParsedScalar(equality: .raw(Data([raw])), summary: "\(Int8(bitPattern: raw))")
        case "Uint16":
            let value = try cursor.readUInt16LE()
            return ParsedScalar(equality: .raw(littleEndianBytes16(value)), summary: "\(value)")
        case "Int16":
            let raw = try cursor.readUInt16LE()
            return ParsedScalar(equality: .raw(littleEndianBytes16(raw)), summary: "\(Int16(bitPattern: raw))")
        case "Uint32":
            let value = try cursor.readUInt32LE()
            return ParsedScalar(equality: .raw(littleEndianBytes32(value)), summary: "\(value)")
        case "Int32":
            let raw = try cursor.readInt32LE()
            return ParsedScalar(equality: .raw(littleEndianBytes32(UInt32(bitPattern: raw))), summary: "\(raw)")
        case "Uint64":
            let value = try cursor.readUInt64LE()
            return ParsedScalar(equality: .raw(littleEndianBytes64(value)), summary: "\(value)")
        case "Int64":
            let raw = try cursor.readUInt64LE()
            return ParsedScalar(equality: .raw(littleEndianBytes64(raw)), summary: "\(Int64(bitPattern: raw))")
        case "Float":
            let raw = try cursor.readUInt32LE()
            return ParsedScalar(equality: .raw(littleEndianBytes32(raw)), summary: "\(Float(bitPattern: raw))")
        case "String":
            let value = try cursor.readLengthPrefixedString()
            return ParsedScalar(equality: .string(value), summary: "\"\(value)\"")
        case "CName":
            let value = try cursor.readLengthPrefixedString()
            return ParsedScalar(equality: .cName(value), summary: "\"\(value)\"")
        case "TweakDBID":
            let value = try cursor.readUInt64LE()
            return ParsedScalar(equality: .tweakDBID(value), summary: "TweakDBID \(hex(value))")
        case "gamedataLocKeyWrapper":
            let value = try cursor.readUInt64LE()
            return ParsedScalar(equality: .locKey(value), summary: "LocKey \(value)")
        case "raRef:CResource":
            let value = try cursor.readUInt64LE()
            return ParsedScalar(equality: .raw(littleEndianBytes64(value)), summary: "ResourcePathHash \(hex(value))")
        case "Color":
            let value = try cursor.readUInt32LE()
            return ParsedScalar(equality: .raw(littleEndianBytes32(value)), summary: "Color \(hex(value))")
        case "Vector2":
            let x = try cursor.readUInt32LE()
            let y = try cursor.readUInt32LE()
            var data = Data()
            data.append(littleEndianBytes32(x))
            data.append(littleEndianBytes32(y))
            return ParsedScalar(equality: .raw(data), summary: "Vector2(\(Float(bitPattern: x)), \(Float(bitPattern: y)))")
        case "Vector3":
            let x = try cursor.readUInt32LE()
            let y = try cursor.readUInt32LE()
            let z = try cursor.readUInt32LE()
            var data = Data()
            data.append(littleEndianBytes32(x))
            data.append(littleEndianBytes32(y))
            data.append(littleEndianBytes32(z))
            return ParsedScalar(equality: .raw(data), summary: "Vector3(\(Float(bitPattern: x)), \(Float(bitPattern: y)), \(Float(bitPattern: z)))")
        case "EulerAngles":
            let p = try cursor.readUInt32LE()
            let y = try cursor.readUInt32LE()
            let r = try cursor.readUInt32LE()
            var data = Data()
            data.append(littleEndianBytes32(p))
            data.append(littleEndianBytes32(y))
            data.append(littleEndianBytes32(r))
            return ParsedScalar(equality: .raw(data), summary: "EulerAngles(\(Float(bitPattern: p)), \(Float(bitPattern: y)), \(Float(bitPattern: r)))")
        case "Quaternion":
            let i = try cursor.readUInt32LE()
            let j = try cursor.readUInt32LE()
            let k = try cursor.readUInt32LE()
            let r = try cursor.readUInt32LE()
            var data = Data()
            data.append(littleEndianBytes32(i))
            data.append(littleEndianBytes32(j))
            data.append(littleEndianBytes32(k))
            data.append(littleEndianBytes32(r))
            return ParsedScalar(equality: .raw(data), summary: "Quaternion(\(Float(bitPattern: i)), \(Float(bitPattern: j)), \(Float(bitPattern: k)), \(Float(bitPattern: r)))")
        default:
            throw CyberMacError.invalidInput("Unsupported flat scalar type \(typeName) at offset \(cursor.offset).")
        }
    }

    private static func parseArrayForStager(elementType: String, cursor: inout Cursor) throws -> ParsedScalar {
        let count = try cursor.readVLQInt32()
        guard count >= 0, count < 1_000_000 else {
            throw CyberMacError.invalidInput("Unreasonable array count \(count) at offset \(cursor.offset).")
        }
        for _ in 0..<count {
            _ = try parseScalarForStager(typeName: elementType, cursor: &cursor)
        }
        return ParsedScalar(equality: .raw(Data()), summary: "array:\(elementType) count=\(count)")
    }

    private static func prepareOverrideValue(override: AddonProbeTweakDBCloneOverride) -> PreparedOverride {
        switch override {
        case .cName(_, let value):
            return PreparedOverride(bytes: encodeLengthPrefixedString(value), equality: .cName(value), summary: "\"\(value)\"")
        case .string(_, let value):
            return PreparedOverride(bytes: encodeLengthPrefixedString(value), equality: .string(value), summary: "\"\(value)\"")
        case .tweakDBID(_, let value):
            let id = tweakDBID(value)
            return PreparedOverride(bytes: littleEndianBytes64(id), equality: .tweakDBID(id), summary: "TweakDBID \(hex(id)) (\(value))")
        case .locKey(_, let value):
            return PreparedOverride(bytes: littleEndianBytes64(value), equality: .locKey(value), summary: "LocKey \(value)")
        }
    }

    private static func write(parsed: StagerFile) throws -> Data {
        var output = Data()
        output.append(Data(count: fileHeaderSize))
        let flatsOffset = output.count
        output.append(littleEndianBytes32(UInt32(parsed.flatTypes.count)))
        let descriptorTableStart = output.count
        output.append(Data(count: parsed.flatTypes.count * flatTypeDescriptorSize))

        var descriptorRows: [(typeHash: UInt64, valueCount: Int, keyCount: Int, valueBlockOffset: Int)] = []
        for type in parsed.flatTypes {
            let valueBlockOffset = output.count
            if type.appendedValues.isEmpty {
                output.append(type.preservedValueBlockBytes)
            } else {
                let newBlockValueCount = type.blockValueCount + type.appendedValues.count
                output.append(littleEndianBytes32(UInt32(newBlockValueCount)))
                if type.preservedValueBlockBytes.count > 4 {
                    output.append(type.preservedValueBlockBytes.subdata(in: 4..<type.preservedValueBlockBytes.count))
                }
                for value in type.appendedValues {
                    output.append(value.bytes)
                }
            }
            let sortedKeys = type.keys.sorted { $0.id < $1.id }
            output.append(littleEndianBytes32(UInt32(sortedKeys.count)))
            for key in sortedKeys {
                output.append(littleEndianBytes64(key.id))
                output.append(littleEndianBytes32(UInt32(bitPattern: Int32(key.valueIndex))))
            }
            let descriptorValueCount = type.descriptorValueCount + type.appendedValues.count
            descriptorRows.append((type.typeHash, descriptorValueCount, sortedKeys.count, valueBlockOffset))
        }

        var descriptorOffset = descriptorTableStart
        for row in descriptorRows {
            output.replaceSubrange(descriptorOffset..<(descriptorOffset + 8), with: littleEndianBytes64(row.typeHash))
            output.replaceSubrange((descriptorOffset + 8)..<(descriptorOffset + 12), with: littleEndianBytes32(UInt32(row.valueCount)))
            output.replaceSubrange((descriptorOffset + 12)..<(descriptorOffset + 16), with: littleEndianBytes32(UInt32(row.keyCount)))
            output.replaceSubrange((descriptorOffset + 16)..<(descriptorOffset + 20), with: littleEndianBytes32(UInt32(row.valueBlockOffset)))
            descriptorOffset += flatTypeDescriptorSize
        }

        let recordsOffset = output.count
        output.append(littleEndianBytes32(UInt32(parsed.records.count)))
        for record in parsed.records {
            output.append(littleEndianBytes64(record.id))
            output.append(littleEndianBytes32(record.typeHash))
        }

        let queriesOffset = output.count
        output.append(parsed.queryBlockBytes)

        let groupTagsOffset = output.count
        output.append(parsed.groupTagBlockBytes)

        var header = Data()
        header.append(littleEndianBytes32(parsed.magic))
        header.append(littleEndianBytes32(parsed.blobVersion))
        header.append(littleEndianBytes32(parsed.parserVersion))
        header.append(littleEndianBytes32(parsed.recordsChecksum))
        header.append(littleEndianBytes32(UInt32(flatsOffset)))
        header.append(littleEndianBytes32(UInt32(recordsOffset)))
        header.append(littleEndianBytes32(UInt32(queriesOffset)))
        header.append(littleEndianBytes32(UInt32(groupTagsOffset)))
        output.replaceSubrange(0..<fileHeaderSize, with: header)

        return output
    }

    private static func littleEndianBytes16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff)])
    }

    private static func littleEndianBytes32(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }

    private static func littleEndianBytes64(_ value: UInt64) -> Data {
        Data((0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xff) })
    }

    private static func encodeLengthPrefixedString(_ value: String) -> Data {
        if value.isEmpty {
            return encodeVLQInt32(0)
        }
        let utf8Bytes = Array(value.utf8)
        var data = encodeVLQInt32(-utf8Bytes.count)
        data.append(contentsOf: utf8Bytes)
        return data
    }

    private static func encodeVLQInt32(_ value: Int) -> Data {
        let isNegative = value < 0
        var remaining = abs(value)
        var data = Data()
        var firstByte: UInt8 = UInt8(remaining & 0x3F)
        remaining >>= 6
        if isNegative {
            firstByte |= 0x80
        }
        if remaining > 0 {
            firstByte |= 0x40
            data.append(firstByte)
            while remaining > 0 {
                var byte: UInt8 = UInt8(remaining & 0x7F)
                remaining >>= 7
                if remaining > 0 {
                    byte |= 0x80
                }
                data.append(byte)
            }
        } else {
            data.append(firstByte)
        }
        return data
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
        if let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let appPath = NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
            let outputPath = outputDirectoryURL.standardizedFileURL.path
            if outputPath == appPath || outputPath.hasPrefix(appPath + "/") {
                throw CyberMacError.invalidInput("Refusing to write TweakDB clone output inside the game app: \(outputPath)")
            }
        }
        let outComponents = outputDirectoryURL.standardizedFileURL.pathComponents
        if outComponents.contains(where: { $0.hasSuffix(".app") }) {
            throw CyberMacError.invalidInput("Refusing to write TweakDB clone output inside a .app bundle: \(outputDirectoryURL.path)")
        }
    }

    private static func ensureOutputIsNotInputFile(inputFileURL: URL, outputDirectoryURL: URL) throws {
        let staged = outputDirectoryURL.appendingPathComponent("staged").appendingPathComponent("tweakdb.bin").standardizedFileURL.path
        if staged == inputFileURL.standardizedFileURL.path {
            throw CyberMacError.invalidInput("Refusing to overwrite input file: \(inputFileURL.path)")
        }
    }

    private static func validateRecordName(_ name: String, label: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("\(label) must not be empty")
        }
    }

    private static func validateProperty(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("Override property name must not be empty")
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
        if remaining == 3 { k1 ^= UInt32(data[roundedEnd + 2]) << 16 }
        if remaining >= 2 { k1 ^= UInt32(data[roundedEnd + 1]) << 8 }
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

    private static func commonWarnings() -> [String] {
        [
            "Staged clone is experimental. Checksum is preserved verbatim and not recomputed.",
            "Cloned flat keys reuse the source value indices; only override flats append new values.",
            "Property names are resolved via CyberMac's known item schema list, so non-schema flats remain in place but cannot be re-keyed.",
            "Staged output is for offline experimentation only. No game files were modified."
        ]
    }

    private static func writeSummary(_ report: AddonProbeTweakDBCloneRecordReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB clone stage",
            "Status: experimental offline writer; no game files were modified.",
            "Input: \(PathSafety.redactUserPath(report.filePath)) (size=\(report.originalSize))",
            "Staged: \(PathSafety.redactUserPath(report.stagedFilePath)) (size=\(report.stagedSize))",
            "Source record: \(report.sourceRecord) id=\(report.sourceRecordIDHex) type=\(report.sourceRecordTypeName ?? report.sourceRecordTypeHashHex)",
            "New record: \(report.newRecord) id=\(report.newRecordIDHex)",
            "Cloned known-schema flats: \(report.clonedFlats.count) (out of \(report.knownSchemaPropertyCount) known properties tried)",
            "Applied overrides: \(report.appliedOverrides.count)",
            "Verification: \(report.verificationStatus)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            ""
        ]
        if !report.clonedFlats.isEmpty {
            lines.append("Cloned flats:")
            for flat in report.clonedFlats {
                lines.append("  .\(flat.property) \(flat.typeName ?? flat.typeHashHex) sourceID=\(flat.sourceFlatIDHex) newID=\(flat.newFlatIDHex) valueIndex=\(flat.newValueIndex)\(flat.valueAppended ? " (appended)" : "") override=\(flat.overrideKind ?? "-") value=\(flat.valueSummary ?? "?")")
            }
            lines.append("")
        }
        if !report.appliedOverrides.isEmpty {
            lines.append("Applied overrides:")
            for flat in report.appliedOverrides {
                let appended = flat.valueAppended ? " (appended)" : ""
                let unresolved = flat.unresolved ? " UNRESOLVED" : ""
                lines.append("  .\(flat.property) [\(flat.overrideKind ?? "-")] \(flat.typeName ?? flat.typeHashHex) newID=\(flat.newFlatIDHex) valueIndex=\(flat.newValueIndex)\(appended)\(unresolved) value=\(flat.valueSummary ?? "?")")
            }
            lines.append("")
        }
        if !report.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeVerification(_ recordName: String, trace: AddonProbeTweakDBRecordTrace, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB staged clone verification",
            "Status: parsed staged output; this verifies the new record can be re-traced.",
            "Record: \(recordName)",
            "Record ID: \(trace.recordIDHex)"
        ]
        if let entry = trace.recordTableEntry {
            lines.append("Record table: index=\(entry.tableIndex) offset=\(entry.offset) type=\(entry.recordTypeName ?? entry.recordTypeHashHex)")
        } else {
            lines.append("Record table: NOT FOUND in staged output")
        }
        lines.append("Known flats: \(trace.knownFlatCount)")
        for flat in trace.knownFlats {
            lines.append("  .\(flat.property) \(flat.typeName ?? flat.typeHashHex) valueIndex=\(flat.valueIndex) value=\(flat.valueSummary ?? "?")")
        }
        lines.append("Status: \(trace.traceStatus.joined(separator: ", "))")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
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

        func require(_ count: Int) throws {
            guard count >= 0, offset >= 0, offset + count <= bytes.count else {
                throw CyberMacError.invalidInput("Unexpected end of TweakDB data at offset \(offset), need \(count) bytes.")
            }
        }
    }
}

public enum AddonProbeTweakDBCloneRecordFormatter {
    public static func format(_ report: AddonProbeTweakDBCloneRecordReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB clone stage",
            "Status: experimental offline writer; no game files were modified.",
            "Input: \(PathSafety.redactUserPath(report.filePath))",
            "Staged: \(PathSafety.redactUserPath(report.stagedFilePath))",
            "Output directory: \(PathSafety.redactUserPath(report.outputDirectoryPath))",
            "Source: \(report.sourceRecord) (\(report.sourceRecordIDHex)) type=\(report.sourceRecordTypeName ?? report.sourceRecordTypeHashHex)",
            "New: \(report.newRecord) (\(report.newRecordIDHex))",
            "Sizes: original=\(report.originalSize) staged=\(report.stagedSize)",
            "Cloned flats: \(report.clonedFlats.count)",
            "Applied overrides: \(report.appliedOverrides.count)",
            "Verification: \(report.verificationStatus)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Summary: \(PathSafety.redactUserPath(report.summaryPath))"
        ]
        if let verificationPath = report.verificationReportPath {
            lines.append("Verification trace: \(PathSafety.redactUserPath(verificationPath))")
        }
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBCloneRecordReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}
