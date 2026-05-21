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

public struct AddonProbeTweakDBCloneRecordNeighbor: Codable, Equatable, Sendable {
    public let tableIndex: Int
    public let recordIDHex: String
    public let recordName: String?
}

public struct AddonProbeTweakDBCloneTouchedFlatKeyTable: Codable, Equatable, Sendable {
    public let typeHashHex: String
    public let typeName: String?
    public let keyCount: Int
    public let keyTableSortedByID: Bool
    public let firstUnsortedKeyPair: AddonProbeTweakDBIDOrderIssue?
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
    public let newRecordSortedIndex: Int
    public let previousRecord: AddonProbeTweakDBCloneRecordNeighbor?
    public let nextRecord: AddonProbeTweakDBCloneRecordNeighbor?
    public let stagedRecordsSortedByID: Bool
    public let touchedFlatKeyTables: [AddonProbeTweakDBCloneTouchedFlatKeyTable]
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

public struct AddonProbeTweakDBOverrideFlatRequest: Sendable {
    public let fileURL: URL
    public let outputDirectoryURL: URL
    public let record: String
    public let property: String
    public let cNameValue: String

    public init(
        fileURL: URL,
        outputDirectoryURL: URL,
        record: String,
        property: String,
        cNameValue: String
    ) {
        self.fileURL = fileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.record = record
        self.property = property
        self.cNameValue = cNameValue
    }
}

public enum AddonProbeTweakDBOverrideFlatConclusion: String, Codable, Equatable, Sendable {
    case stagedOverrideProduced
    case stagedOverrideParsed
    case existingRecordResolved
    case existingFlatResolved
    case offlineValueVerified
    case checksumUnverified
    case writerIncomplete
    case failed
}

public struct AddonProbeTweakDBOverrideFlatReport: Codable, Equatable, Sendable {
    public let filePath: String
    public let outputDirectoryPath: String
    public let stagedFilePath: String
    public let record: String
    public let recordIDHex: String
    public let property: String
    public let flatIDHex: String
    public let typeName: String
    public let typeHashHex: String
    public let originalValue: String?
    public let newValue: String
    public let originalValueIndex: Int
    public let newValueIndex: Int
    public let cNameValueCountBefore: Int
    public let cNameValueCountAfter: Int
    public let cNameValueReused: Bool
    public let cNameValueAppended: Bool
    public let keyTableCountBefore: Int
    public let keyTableCountAfter: Int
    public let keyTableCountChanged: Bool
    public let keyValueIndexChanged: Bool
    public let valueBlockChanged: Bool
    public let cNamePoolChanged: Bool
    public let touchedFlatKeyTable: AddonProbeTweakDBCloneTouchedFlatKeyTable
    public let originalSize: Int
    public let stagedSize: Int
    public let stagedSHA256: String
    public let verificationSucceeded: Bool
    public let verificationStatus: String
    public let verification: AddonProbeTweakDBRecordTrace?
    public let conclusions: [AddonProbeTweakDBOverrideFlatConclusion]
    public let warnings: [String]
    public let reportPath: String
    public let summaryPath: String
    public let verificationReportPath: String?
}

public struct AddonProbeTweakDBDualOverrideFlatRequest: Sendable {
    public let baseFileURL: URL
    public let ep1FileURL: URL
    public let outputDirectoryURL: URL
    public let record: String
    public let property: String
    public let cNameValue: String

    public init(
        baseFileURL: URL,
        ep1FileURL: URL,
        outputDirectoryURL: URL,
        record: String,
        property: String,
        cNameValue: String
    ) {
        self.baseFileURL = baseFileURL
        self.ep1FileURL = ep1FileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.record = record
        self.property = property
        self.cNameValue = cNameValue
    }
}

public enum AddonProbeTweakDBDualOverrideFlatConclusion: String, Codable, Equatable, Sendable {
    case stagedBaseOverrideProduced
    case stagedEP1OverrideProduced
    case baseOfflineValueVerified
    case ep1OfflineValueVerified
    case checksumUnverified
    case writerIncomplete
    case failed
}

public struct AddonProbeTweakDBDualOverrideFlatReport: Codable, Equatable, Sendable {
    public let baseFilePath: String
    public let ep1FilePath: String
    public let outputDirectoryPath: String
    public let stagedBaseFilePath: String
    public let stagedEP1FilePath: String
    public let record: String
    public let property: String
    public let newValue: String
    public let baseReport: AddonProbeTweakDBOverrideFlatReport
    public let ep1Report: AddonProbeTweakDBOverrideFlatReport
    public let baseVerificationSucceeded: Bool
    public let ep1VerificationSucceeded: Bool
    public let verificationSucceeded: Bool
    public let baseVerificationStatus: String
    public let ep1VerificationStatus: String
    public let conclusions: [AddonProbeTweakDBDualOverrideFlatConclusion]
    public let warnings: [String]
    public let reportPath: String
    public let summaryPath: String
}

public struct AddonProbeTweakDBDualCloneRecordRequest: Sendable {
    public let baseFileURL: URL
    public let ep1FileURL: URL
    public let outputDirectoryURL: URL
    public let sourceRecord: String
    public let newRecord: String
    public let overrides: [AddonProbeTweakDBCloneOverride]

    public init(
        baseFileURL: URL,
        ep1FileURL: URL,
        outputDirectoryURL: URL,
        sourceRecord: String,
        newRecord: String,
        overrides: [AddonProbeTweakDBCloneOverride] = []
    ) {
        self.baseFileURL = baseFileURL
        self.ep1FileURL = ep1FileURL
        self.outputDirectoryURL = outputDirectoryURL
        self.sourceRecord = sourceRecord
        self.newRecord = newRecord
        self.overrides = overrides
    }
}

public enum AddonProbeTweakDBDualCloneRecordConclusion: String, Codable, Equatable, Sendable {
    case stagedBaseCloneProduced
    case stagedEP1CloneProduced
    case baseNewRecordResolved
    case ep1NewRecordResolved
    case baseRecordsSortedByID
    case ep1RecordsSortedByID
    case baseTouchedFlatKeyTablesSorted
    case ep1TouchedFlatKeyTablesSorted
    case baseKnownClothingFlatsResolved
    case ep1KnownClothingFlatsResolved
    case checksumUnverified
    case writerIncomplete
    case failed
}

public struct AddonProbeTweakDBDualCloneRecordReport: Codable, Equatable, Sendable {
    public let baseFilePath: String
    public let ep1FilePath: String
    public let outputDirectoryPath: String
    public let stagedBaseFilePath: String
    public let stagedEP1FilePath: String
    public let sourceRecord: String
    public let newRecord: String
    public let expectedKnownClothingFlatCount: Int
    public let baseKnownClothingFlatCount: Int
    public let ep1KnownClothingFlatCount: Int
    public let baseNewRecordSortedIndex: Int
    public let ep1NewRecordSortedIndex: Int
    public let baseReport: AddonProbeTweakDBCloneRecordReport
    public let ep1Report: AddonProbeTweakDBCloneRecordReport
    public let baseRuntimeLookupValidation: AddonProbeTweakDBRuntimeLookupValidationReport
    public let ep1RuntimeLookupValidation: AddonProbeTweakDBRuntimeLookupValidationReport
    public let baseNewRecordResolved: Bool
    public let ep1NewRecordResolved: Bool
    public let baseRecordsSortedByID: Bool
    public let ep1RecordsSortedByID: Bool
    public let baseTouchedFlatKeyTablesSorted: Bool
    public let ep1TouchedFlatKeyTablesSorted: Bool
    public let baseKnownClothingFlatsResolved: Bool
    public let ep1KnownClothingFlatsResolved: Bool
    public let verificationSucceeded: Bool
    public let baseVerificationStatus: String
    public let ep1VerificationStatus: String
    public let conclusions: [AddonProbeTweakDBDualCloneRecordConclusion]
    public let warnings: [String]
    public let reportPath: String
    public let summaryPath: String
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
        var touchedFlatTypeIndices = Set<Int>()
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
            touchedFlatTypeIndices.insert(location.typeIndex)
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
            touchedFlatTypeIndices.insert(typeIndex)

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
        parsed.records.sort { $0.id < $1.id }
        for typeIndex in touchedFlatTypeIndices {
            parsed.flatTypes[typeIndex].keys.sort { $0.id < $1.id }
        }
        Self.rebuildFlatLocations(parsed: &parsed)
        let newRecordSortedIndex = parsed.records.firstIndex { $0.id == newRecordID } ?? -1
        let stagedRecordsOrderIssue = Self.firstUnsortedPair(ids: parsed.records.map(\.id))
        let knownRecordNames = Self.knownRecordNamesByID(sourceRecord: request.sourceRecord, newRecord: request.newRecord)
        let previousRecord = Self.neighborRecord(
            in: parsed.records,
            at: newRecordSortedIndex - 1,
            knownRecordNames: knownRecordNames
        )
        let nextRecord = Self.neighborRecord(
            in: parsed.records,
            at: newRecordSortedIndex + 1,
            knownRecordNames: knownRecordNames
        )
        let touchedFlatKeyTables = touchedFlatTypeIndices.sorted().map { typeIndex in
            Self.touchedFlatKeyTableReport(parsed.flatTypes[typeIndex])
        }

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
            newRecordSortedIndex: newRecordSortedIndex,
            previousRecord: previousRecord,
            nextRecord: nextRecord,
            stagedRecordsSortedByID: stagedRecordsOrderIssue == nil,
            touchedFlatKeyTables: touchedFlatKeyTables,
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

    public func stageOverrideFlat(
        request: AddonProbeTweakDBOverrideFlatRequest
    ) throws -> AddonProbeTweakDBOverrideFlatReport {
        let fileURL = request.fileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.ensureOutputIsNotInputFile(inputFileURL: fileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.validateRecordName(request.record, label: "--record")
        try Self.validateProperty(request.property)
        try Self.validateFlatPropertyIdentifier(request.property)
        try Self.validateCNameValue(request.cNameValue)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let originalData = try Self.readData(fileURL)
        var parsed = try Self.parse(data: originalData)

        let recordID = Self.tweakDBID(request.record)
        guard parsed.records.contains(where: { $0.id == recordID }) else {
            throw CyberMacError.invalidInput("Record \(request.record) was not found in \(fileURL.path).")
        }

        guard let typeIndex = parsed.typeIndexByName["CName"] else {
            throw CyberMacError.invalidInput("No CName flat type pool found in \(fileURL.path).")
        }

        let flatID = Self.tweakDBID("\(request.record).\(request.property)")
        guard let location = parsed.flatLocationByID[flatID] else {
            throw CyberMacError.invalidInput("Existing flat \(request.record).\(request.property) was not found in \(fileURL.path). Refusing to append a new flat key.")
        }
        guard location.typeIndex == typeIndex else {
            let actualType = parsed.flatTypes[location.typeIndex].typeName ?? Self.hex(parsed.flatTypes[location.typeIndex].typeHash)
            throw CyberMacError.invalidInput("Existing flat \(request.record).\(request.property) is \(actualType), not CName.")
        }

        let poolBefore = parsed.flatTypes[typeIndex]
        let keyBefore = poolBefore.keys[location.keyIndex]
        let originalValueIndex = keyBefore.valueIndex
        let originalValue = Self.cNameValue(in: poolBefore, at: originalValueIndex)
        let keyTableCountBefore = poolBefore.keys.count
        let cNameValueCountBefore = poolBefore.blockValueCount + poolBefore.appendedValues.count

        let prepared = Self.prepareOverrideValue(override: .cName(property: request.property, value: request.cNameValue))
        let existingValueIndex = poolBefore.parsedValues.firstIndex { $0.equality == prepared.equality }
        let existingAppendedIndex = poolBefore.appendedValues.firstIndex { $0.equality == prepared.equality }
        let newValueIndex: Int
        let valueAppended: Bool
        if let existingValueIndex {
            newValueIndex = existingValueIndex
            valueAppended = false
        } else if let existingAppendedIndex {
            newValueIndex = poolBefore.blockValueCount + existingAppendedIndex
            valueAppended = false
        } else {
            guard poolBefore.isHighConfidence else {
                throw CyberMacError.invalidInput("Refusing override for '\(request.property)': the CName flat type pool has descriptor/block count mismatch (descriptor=\(poolBefore.descriptorValueCount) block=\(poolBefore.blockValueCount)). Appending a new CName value to a low-confidence section could corrupt the staged TweakDB.")
            }
            parsed.flatTypes[typeIndex].appendedValues.append(StagerValue(bytes: prepared.bytes, equality: prepared.equality, summary: prepared.summary))
            newValueIndex = poolBefore.blockValueCount + parsed.flatTypes[typeIndex].appendedValues.count - 1
            valueAppended = true
        }

        parsed.flatTypes[typeIndex].keys[location.keyIndex] = StagerKey(id: flatID, valueIndex: newValueIndex)
        parsed.flatTypes[typeIndex].keys.sort { $0.id < $1.id }
        Self.rebuildFlatLocations(parsed: &parsed)

        let touchedFlatKeyTable = Self.touchedFlatKeyTableReport(parsed.flatTypes[typeIndex])
        let keyTableCountAfter = parsed.flatTypes[typeIndex].keys.count
        let cNameValueCountAfter = parsed.flatTypes[typeIndex].blockValueCount + parsed.flatTypes[typeIndex].appendedValues.count

        let stagedData = try Self.write(parsed: parsed)
        let stagedDirectory = outputDirectoryURL.appendingPathComponent("staged", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
        let stagedFileURL = stagedDirectory.appendingPathComponent("tweakdb.bin")
        try stagedData.write(to: stagedFileURL, options: [.atomic])

        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-override-flat-stage.json")
        let summaryURL = outputDirectoryURL.appendingPathComponent("tweakdb-override-flat-stage.txt")
        let verificationURL = outputDirectoryURL.appendingPathComponent("tweakdb-override-flat-verification.txt")

        var verification: AddonProbeTweakDBRecordTrace?
        var verificationSucceeded = false
        var verificationStatus: String
        var conclusions: [AddonProbeTweakDBOverrideFlatConclusion] = [
            .stagedOverrideProduced,
            .existingRecordResolved,
            .existingFlatResolved,
            .checksumUnverified,
            .writerIncomplete
        ]
        var warnings = Self.overrideFlatWarnings()

        do {
            let reparsed = try Self.parse(data: stagedData)
            let verifiedValue = Self.cNameFlatValue(parsed: reparsed, record: request.record, property: request.property)
            verificationSucceeded = verifiedValue == request.cNameValue
            let traceReport = try TweakDBStructureInspector().trace(request: AddonProbeTweakDBRecordTraceRequest(
                fileURL: stagedFileURL,
                record: request.record,
                outputDirectoryURL: stagedDirectory
            ))
            verification = traceReport.trace
            conclusions.append(.stagedOverrideParsed)
            if verificationSucceeded {
                verificationStatus = "\(request.record).\(request.property) == \(request.cNameValue)"
                conclusions.append(.offlineValueVerified)
            } else {
                verificationStatus = "\(request.record).\(request.property) verification failed; parsed value=\(verifiedValue ?? "<missing>")"
                conclusions.append(.failed)
            }
        } catch {
            verificationStatus = "stagedFileReparseFailed: \(error)"
            conclusions.append(.failed)
            warnings.append("Staged file failed to re-parse: \(error)")
        }

        let report = AddonProbeTweakDBOverrideFlatReport(
            filePath: fileURL.path,
            outputDirectoryPath: outputDirectoryURL.path,
            stagedFilePath: stagedFileURL.path,
            record: request.record,
            recordIDHex: Self.hex(recordID),
            property: request.property,
            flatIDHex: Self.hex(flatID),
            typeName: "CName",
            typeHashHex: Self.hex(parsed.flatTypes[typeIndex].typeHash),
            originalValue: originalValue,
            newValue: request.cNameValue,
            originalValueIndex: originalValueIndex,
            newValueIndex: newValueIndex,
            cNameValueCountBefore: cNameValueCountBefore,
            cNameValueCountAfter: cNameValueCountAfter,
            cNameValueReused: !valueAppended,
            cNameValueAppended: valueAppended,
            keyTableCountBefore: keyTableCountBefore,
            keyTableCountAfter: keyTableCountAfter,
            keyTableCountChanged: keyTableCountAfter != keyTableCountBefore,
            keyValueIndexChanged: newValueIndex != originalValueIndex,
            valueBlockChanged: valueAppended,
            cNamePoolChanged: valueAppended,
            touchedFlatKeyTable: touchedFlatKeyTable,
            originalSize: originalData.count,
            stagedSize: stagedData.count,
            stagedSHA256: PathSafety.sha256(data: stagedData),
            verificationSucceeded: verificationSucceeded,
            verificationStatus: verificationStatus,
            verification: verification,
            conclusions: conclusions,
            warnings: warnings,
            reportPath: reportURL.path,
            summaryPath: summaryURL.path,
            verificationReportPath: verification != nil ? verificationURL.path : nil
        )

        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        try Self.writeOverrideFlatSummary(report, to: summaryURL)
        if let verification {
            try Self.writeVerification(report.record, trace: verification, to: verificationURL)
        }
        return report
    }

    public func stageDualOverrideFlat(
        request: AddonProbeTweakDBDualOverrideFlatRequest
    ) throws -> AddonProbeTweakDBDualOverrideFlatReport {
        let baseFileURL = request.baseFileURL.standardizedFileURL
        let ep1FileURL = request.ep1FileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: baseFileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: ep1FileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.validateRecordName(request.record, label: "--record")
        try Self.validateProperty(request.property)
        try Self.validateFlatPropertyIdentifier(request.property)
        try Self.validateCNameValue(request.cNameValue)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let finalStagedDirectory = outputDirectoryURL.appendingPathComponent("staged", isDirectory: true)
        let finalBaseURL = finalStagedDirectory.appendingPathComponent("tweakdb.bin")
        let finalEP1URL = finalStagedDirectory.appendingPathComponent("tweakdb_ep1.bin")
        for stagedURL in [finalBaseURL, finalEP1URL] {
            if stagedURL.standardizedFileURL.path == baseFileURL.path || stagedURL.standardizedFileURL.path == ep1FileURL.path {
                throw CyberMacError.invalidInput("Refusing to overwrite input file: \(stagedURL.path)")
            }
        }

        let baseWorkDirectory = outputDirectoryURL.appendingPathComponent("base", isDirectory: true)
        let ep1WorkDirectory = outputDirectoryURL.appendingPathComponent("ep1", isDirectory: true)
        let baseReport = try stageOverrideFlat(request: AddonProbeTweakDBOverrideFlatRequest(
            fileURL: baseFileURL,
            outputDirectoryURL: baseWorkDirectory,
            record: request.record,
            property: request.property,
            cNameValue: request.cNameValue
        ))
        let ep1Report = try stageOverrideFlat(request: AddonProbeTweakDBOverrideFlatRequest(
            fileURL: ep1FileURL,
            outputDirectoryURL: ep1WorkDirectory,
            record: request.record,
            property: request.property,
            cNameValue: request.cNameValue
        ))

        try FileManager.default.createDirectory(at: finalStagedDirectory, withIntermediateDirectories: true)
        for stagedURL in [finalBaseURL, finalEP1URL] where FileManager.default.fileExists(atPath: stagedURL.path) {
            try FileManager.default.removeItem(at: stagedURL)
        }
        try FileManager.default.copyItem(at: URL(fileURLWithPath: baseReport.stagedFilePath), to: finalBaseURL)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: ep1Report.stagedFilePath), to: finalEP1URL)

        let baseFinalValue = try Self.cNameFlatValue(fileURL: finalBaseURL, record: request.record, property: request.property)
        let ep1FinalValue = try Self.cNameFlatValue(fileURL: finalEP1URL, record: request.record, property: request.property)
        let baseVerificationSucceeded = baseFinalValue == request.cNameValue
        let ep1VerificationSucceeded = ep1FinalValue == request.cNameValue
        let baseVerificationStatus = baseVerificationSucceeded
            ? "\(request.record).\(request.property) == \(request.cNameValue)"
            : "\(request.record).\(request.property) verification failed; parsed value=\(baseFinalValue ?? "<missing>")"
        let ep1VerificationStatus = ep1VerificationSucceeded
            ? "\(request.record).\(request.property) == \(request.cNameValue)"
            : "\(request.record).\(request.property) verification failed; parsed value=\(ep1FinalValue ?? "<missing>")"

        var conclusions: [AddonProbeTweakDBDualOverrideFlatConclusion] = [
            .stagedBaseOverrideProduced,
            .stagedEP1OverrideProduced,
            .checksumUnverified,
            .writerIncomplete
        ]
        if baseVerificationSucceeded {
            conclusions.append(.baseOfflineValueVerified)
        }
        if ep1VerificationSucceeded {
            conclusions.append(.ep1OfflineValueVerified)
        }
        if !baseVerificationSucceeded || !ep1VerificationSucceeded {
            conclusions.append(.failed)
        }

        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-dual-override-flat-stage.json")
        let summaryURL = outputDirectoryURL.appendingPathComponent("tweakdb-dual-override-flat-stage.txt")
        let warnings = Self.dualOverrideFlatWarnings()
        let report = AddonProbeTweakDBDualOverrideFlatReport(
            baseFilePath: baseFileURL.path,
            ep1FilePath: ep1FileURL.path,
            outputDirectoryPath: outputDirectoryURL.path,
            stagedBaseFilePath: finalBaseURL.path,
            stagedEP1FilePath: finalEP1URL.path,
            record: request.record,
            property: request.property,
            newValue: request.cNameValue,
            baseReport: baseReport,
            ep1Report: ep1Report,
            baseVerificationSucceeded: baseVerificationSucceeded,
            ep1VerificationSucceeded: ep1VerificationSucceeded,
            verificationSucceeded: baseVerificationSucceeded && ep1VerificationSucceeded,
            baseVerificationStatus: baseVerificationStatus,
            ep1VerificationStatus: ep1VerificationStatus,
            conclusions: conclusions,
            warnings: warnings,
            reportPath: reportURL.path,
            summaryPath: summaryURL.path
        )

        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        try Self.writeDualOverrideFlatSummary(report, to: summaryURL)
        return report
    }

    public func stageDualCloneRecord(
        request: AddonProbeTweakDBDualCloneRecordRequest
    ) throws -> AddonProbeTweakDBDualCloneRecordReport {
        let baseFileURL = request.baseFileURL.standardizedFileURL
        let ep1FileURL = request.ep1FileURL.standardizedFileURL
        let outputDirectoryURL = request.outputDirectoryURL.standardizedFileURL
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: baseFileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.ensureOutputIsNotInsideInspectedApp(inputFileURL: ep1FileURL, outputDirectoryURL: outputDirectoryURL)
        try Self.validateRecordName(request.sourceRecord, label: "--source-record")
        try Self.validateRecordName(request.newRecord, label: "--new-record")
        for override in request.overrides {
            try Self.validateProperty(override.property)
        }
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let finalStagedDirectory = outputDirectoryURL.appendingPathComponent("staged", isDirectory: true)
        let finalBaseURL = finalStagedDirectory.appendingPathComponent("tweakdb.bin")
        let finalEP1URL = finalStagedDirectory.appendingPathComponent("tweakdb_ep1.bin")
        for stagedURL in [finalBaseURL, finalEP1URL] {
            let stagedPath = stagedURL.standardizedFileURL.path
            if stagedPath == baseFileURL.path || stagedPath == ep1FileURL.path {
                throw CyberMacError.invalidInput("Refusing to overwrite input file: \(stagedURL.path)")
            }
        }

        let baseWorkDirectory = outputDirectoryURL.appendingPathComponent("base-clone", isDirectory: true)
        let ep1WorkDirectory = outputDirectoryURL.appendingPathComponent("ep1-clone", isDirectory: true)
        let baseReport = try stage(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: baseFileURL,
            outputDirectoryURL: baseWorkDirectory,
            sourceRecord: request.sourceRecord,
            newRecord: request.newRecord,
            overrides: request.overrides
        ))
        let ep1Report = try stage(request: AddonProbeTweakDBCloneRecordRequest(
            fileURL: ep1FileURL,
            outputDirectoryURL: ep1WorkDirectory,
            sourceRecord: request.sourceRecord,
            newRecord: request.newRecord,
            overrides: request.overrides
        ))

        try FileManager.default.createDirectory(at: finalStagedDirectory, withIntermediateDirectories: true)
        for stagedURL in [finalBaseURL, finalEP1URL] where FileManager.default.fileExists(atPath: stagedURL.path) {
            try FileManager.default.removeItem(at: stagedURL)
        }
        try FileManager.default.copyItem(at: URL(fileURLWithPath: baseReport.stagedFilePath), to: finalBaseURL)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: ep1Report.stagedFilePath), to: finalEP1URL)

        let baseLookup = try TweakDBStructureInspector().validateRuntimeLookup(request: AddonProbeTweakDBRuntimeLookupValidationRequest(
            fileURL: finalBaseURL,
            record: request.newRecord,
            outputDirectoryURL: outputDirectoryURL.appendingPathComponent("base-runtime-lookup", isDirectory: true)
        ))
        let ep1Lookup = try TweakDBStructureInspector().validateRuntimeLookup(request: AddonProbeTweakDBRuntimeLookupValidationRequest(
            fileURL: finalEP1URL,
            record: request.newRecord,
            outputDirectoryURL: outputDirectoryURL.appendingPathComponent("ep1-runtime-lookup", isDirectory: true)
        ))

        let expectedKnownFlatCount = TweakDBStructureInspector.itemRecordProperties.count
        let baseKnownFlatCount = baseReport.verification?.knownFlatCount ?? 0
        let ep1KnownFlatCount = ep1Report.verification?.knownFlatCount ?? 0
        let baseNewRecordResolved = baseReport.verification?.recordTableEntry != nil && baseLookup.recordBinaryFound
        let ep1NewRecordResolved = ep1Report.verification?.recordTableEntry != nil && ep1Lookup.recordBinaryFound
        let baseRecordsSortedByID = baseReport.stagedRecordsSortedByID && baseLookup.recordsSortedByID
        let ep1RecordsSortedByID = ep1Report.stagedRecordsSortedByID && ep1Lookup.recordsSortedByID
        let baseTouchedFlatKeyTablesSorted = baseReport.touchedFlatKeyTables.allSatisfy(\.keyTableSortedByID)
        let ep1TouchedFlatKeyTablesSorted = ep1Report.touchedFlatKeyTables.allSatisfy(\.keyTableSortedByID)
        let baseKnownClothingFlatsResolved = baseKnownFlatCount == expectedKnownFlatCount &&
            baseLookup.flatValidations.count == expectedKnownFlatCount &&
            baseLookup.flatValidations.allSatisfy { $0.binaryFound && $0.keyTableSortedByID }
        let ep1KnownClothingFlatsResolved = ep1KnownFlatCount == expectedKnownFlatCount &&
            ep1Lookup.flatValidations.count == expectedKnownFlatCount &&
            ep1Lookup.flatValidations.allSatisfy { $0.binaryFound && $0.keyTableSortedByID }

        let baseVerificationStatus = [
            "newRecordBinaryLookup=\(baseLookup.recordBinaryFound)",
            "recordsSortedByID=\(baseRecordsSortedByID)",
            "touchedFlatKeyTablesSorted=\(baseTouchedFlatKeyTablesSorted)",
            "knownClothingFlats=\(baseKnownFlatCount)/\(expectedKnownFlatCount)"
        ].joined(separator: "; ")
        let ep1VerificationStatus = [
            "newRecordBinaryLookup=\(ep1Lookup.recordBinaryFound)",
            "recordsSortedByID=\(ep1RecordsSortedByID)",
            "touchedFlatKeyTablesSorted=\(ep1TouchedFlatKeyTablesSorted)",
            "knownClothingFlats=\(ep1KnownFlatCount)/\(expectedKnownFlatCount)"
        ].joined(separator: "; ")

        var conclusions: [AddonProbeTweakDBDualCloneRecordConclusion] = [
            .stagedBaseCloneProduced,
            .stagedEP1CloneProduced,
            .checksumUnverified,
            .writerIncomplete
        ]
        if baseNewRecordResolved { conclusions.append(.baseNewRecordResolved) }
        if ep1NewRecordResolved { conclusions.append(.ep1NewRecordResolved) }
        if baseRecordsSortedByID { conclusions.append(.baseRecordsSortedByID) }
        if ep1RecordsSortedByID { conclusions.append(.ep1RecordsSortedByID) }
        if baseTouchedFlatKeyTablesSorted { conclusions.append(.baseTouchedFlatKeyTablesSorted) }
        if ep1TouchedFlatKeyTablesSorted { conclusions.append(.ep1TouchedFlatKeyTablesSorted) }
        if baseKnownClothingFlatsResolved { conclusions.append(.baseKnownClothingFlatsResolved) }
        if ep1KnownClothingFlatsResolved { conclusions.append(.ep1KnownClothingFlatsResolved) }

        let verificationSucceeded = baseNewRecordResolved &&
            ep1NewRecordResolved &&
            baseRecordsSortedByID &&
            ep1RecordsSortedByID &&
            baseTouchedFlatKeyTablesSorted &&
            ep1TouchedFlatKeyTablesSorted &&
            baseKnownClothingFlatsResolved &&
            ep1KnownClothingFlatsResolved
        if !verificationSucceeded {
            conclusions.append(.failed)
        }

        let reportURL = outputDirectoryURL.appendingPathComponent("tweakdb-dual-clone-record-stage.json")
        let summaryURL = outputDirectoryURL.appendingPathComponent("tweakdb-dual-clone-record-stage.txt")
        let report = AddonProbeTweakDBDualCloneRecordReport(
            baseFilePath: baseFileURL.path,
            ep1FilePath: ep1FileURL.path,
            outputDirectoryPath: outputDirectoryURL.path,
            stagedBaseFilePath: finalBaseURL.path,
            stagedEP1FilePath: finalEP1URL.path,
            sourceRecord: request.sourceRecord,
            newRecord: request.newRecord,
            expectedKnownClothingFlatCount: expectedKnownFlatCount,
            baseKnownClothingFlatCount: baseKnownFlatCount,
            ep1KnownClothingFlatCount: ep1KnownFlatCount,
            baseNewRecordSortedIndex: baseReport.newRecordSortedIndex,
            ep1NewRecordSortedIndex: ep1Report.newRecordSortedIndex,
            baseReport: baseReport,
            ep1Report: ep1Report,
            baseRuntimeLookupValidation: baseLookup,
            ep1RuntimeLookupValidation: ep1Lookup,
            baseNewRecordResolved: baseNewRecordResolved,
            ep1NewRecordResolved: ep1NewRecordResolved,
            baseRecordsSortedByID: baseRecordsSortedByID,
            ep1RecordsSortedByID: ep1RecordsSortedByID,
            baseTouchedFlatKeyTablesSorted: baseTouchedFlatKeyTablesSorted,
            ep1TouchedFlatKeyTablesSorted: ep1TouchedFlatKeyTablesSorted,
            baseKnownClothingFlatsResolved: baseKnownClothingFlatsResolved,
            ep1KnownClothingFlatsResolved: ep1KnownClothingFlatsResolved,
            verificationSucceeded: verificationSucceeded,
            baseVerificationStatus: baseVerificationStatus,
            ep1VerificationStatus: ep1VerificationStatus,
            conclusions: conclusions,
            warnings: Self.dualCloneRecordWarnings(expectedKnownFlatCount: expectedKnownFlatCount),
            reportPath: reportURL.path,
            summaryPath: summaryURL.path
        )

        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        try Self.writeDualCloneRecordSummary(report, to: summaryURL)
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
            output.append(littleEndianBytes32(UInt32(type.keys.count)))
            for key in type.keys {
                output.append(littleEndianBytes64(key.id))
                output.append(littleEndianBytes32(UInt32(bitPattern: Int32(key.valueIndex))))
            }
            let descriptorValueCount = type.descriptorValueCount + type.appendedValues.count
            descriptorRows.append((type.typeHash, descriptorValueCount, type.keys.count, valueBlockOffset))
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

    private static func rebuildFlatLocations(parsed: inout StagerFile) {
        var locations: [UInt64: StagerFlatLocation] = [:]
        for typeIndex in parsed.flatTypes.indices {
            for keyIndex in parsed.flatTypes[typeIndex].keys.indices {
                locations[parsed.flatTypes[typeIndex].keys[keyIndex].id] = StagerFlatLocation(
                    typeIndex: typeIndex,
                    keyIndex: keyIndex
                )
            }
        }
        parsed.flatLocationByID = locations
    }

    private static func firstUnsortedPair(ids: [UInt64]) -> AddonProbeTweakDBIDOrderIssue? {
        guard ids.count > 1 else { return nil }
        for index in 1..<ids.count where ids[index - 1] > ids[index] {
            return AddonProbeTweakDBIDOrderIssue(
                previousIndex: index - 1,
                previousIDHex: hex(ids[index - 1]),
                currentIndex: index,
                currentIDHex: hex(ids[index])
            )
        }
        return nil
    }

    private static func touchedFlatKeyTableReport(_ type: StagerFlatType) -> AddonProbeTweakDBCloneTouchedFlatKeyTable {
        let issue = firstUnsortedPair(ids: type.keys.map(\.id))
        return AddonProbeTweakDBCloneTouchedFlatKeyTable(
            typeHashHex: hex(type.typeHash),
            typeName: type.typeName,
            keyCount: type.keys.count,
            keyTableSortedByID: issue == nil,
            firstUnsortedKeyPair: issue
        )
    }

    private static func knownRecordNamesByID(sourceRecord: String, newRecord: String) -> [UInt64: String] {
        var namesByID: [UInt64: String] = [:]
        for recordName in AddonProbeManager.orderedUnique([sourceRecord, newRecord] + TweakDBStructureInspector.defaultRecords) {
            namesByID[tweakDBID(recordName)] = recordName
        }
        return namesByID
    }

    private static func neighborRecord(
        in records: [StagerRecord],
        at index: Int,
        knownRecordNames: [UInt64: String]
    ) -> AddonProbeTweakDBCloneRecordNeighbor? {
        guard records.indices.contains(index) else { return nil }
        let record = records[index]
        return AddonProbeTweakDBCloneRecordNeighbor(
            tableIndex: index,
            recordIDHex: hex(record.id),
            recordName: knownRecordNames[record.id]
        )
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

    private static func validateFlatPropertyIdentifier(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.allSatisfy(isAllowedRedscriptIdentifierCharacter) else {
            throw CyberMacError.invalidInput("Override property contains unsupported characters: \(name). Allowed: A-Z, a-z, 0-9, '_'.")
        }
    }

    private static func validateCNameValue(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.invalidInput("CName override value must not be empty")
        }
        guard trimmed == value else {
            throw CyberMacError.invalidInput("CName override value must not have leading or trailing whitespace: \(value)")
        }
        guard value.allSatisfy(isAllowedCNameValueCharacter) else {
            throw CyberMacError.invalidInput("CName override value contains unsupported characters: \(value). Allowed: A-Z, a-z, 0-9, '_', '-', '.', ':', '/'.")
        }
    }

    private static func isAllowedRedscriptIdentifierCharacter(_ character: Character) -> Bool {
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

    private static func cNameValue(in type: StagerFlatType, at valueIndex: Int) -> String? {
        guard valueIndex >= 0 else { return nil }
        if valueIndex < type.parsedValues.count,
           case .cName(let value) = type.parsedValues[valueIndex].equality {
            return value
        }
        let appendedIndex = valueIndex - type.blockValueCount
        if appendedIndex >= 0,
           appendedIndex < type.appendedValues.count,
           case .cName(let value) = type.appendedValues[appendedIndex].equality {
            return value
        }
        return nil
    }

    private static func cNameFlatValue(parsed: StagerFile, record: String, property: String) -> String? {
        let flatID = tweakDBID("\(record).\(property)")
        guard let location = parsed.flatLocationByID[flatID],
              parsed.flatTypes.indices.contains(location.typeIndex),
              parsed.flatTypes[location.typeIndex].keys.indices.contains(location.keyIndex)
        else {
            return nil
        }
        let type = parsed.flatTypes[location.typeIndex]
        guard type.typeName == "CName" else { return nil }
        let valueIndex = type.keys[location.keyIndex].valueIndex
        return cNameValue(in: type, at: valueIndex)
    }

    private static func cNameFlatValue(fileURL: URL, record: String, property: String) throws -> String? {
        let data = try readData(fileURL)
        let parsed = try parse(data: data)
        return cNameFlatValue(parsed: parsed, record: record, property: property)
    }

    private static func commonWarnings() -> [String] {
        [
            "Staged clone is experimental. Checksum is preserved verbatim and not recomputed.",
            "Cloned flat keys reuse the source value indices; only override flats append new values.",
            "Property names are resolved via CyberMac's known item schema list, so non-schema flats remain in place but cannot be re-keyed.",
            "Staged output is for offline experimentation only. No game files were modified."
        ]
    }

    private static func overrideFlatWarnings() -> [String] {
        [
            "Existing-flat override is experimental. Checksum is preserved verbatim and not recomputed.",
            "This stages a new tweakdb.bin only; no game files were modified.",
            "The command refuses to append cloned records or new flat keys. It only updates an existing flat key's value index.",
            "If the requested CName value is absent, it is appended to the CName typed value pool."
        ]
    }

    private static func dualOverrideFlatWarnings() -> [String] {
        [
            "Dual existing-flat override stages patched base and EP1 TweakDB blobs only; no game files were modified.",
            "Both staged blobs preserve their original checksums verbatim and do not recompute them.",
            "Final files to install are staged/tweakdb.bin and staged/tweakdb_ep1.bin.",
            "Use runtime-item-diagnostic-grant --money-markers --check-cname to determine whether runtime sees the patched CName."
        ]
    }

    private static func dualCloneRecordWarnings(expectedKnownFlatCount: Int) -> [String] {
        [
            "Dual clone stage writes install-ready staged/tweakdb.bin and staged/tweakdb_ep1.bin; no game files were modified.",
            "Both staged blobs preserve their original checksums verbatim and do not recompute them.",
            "Final files must be installed together into Data/r6/cache/tweakdb.bin and Data/r6/cache/tweakdb_ep1.bin.",
            "Offline verification expects \(expectedKnownFlatCount) known Clothing flats to resolve in each staged blob."
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
            "New record sorted index: \(report.newRecordSortedIndex)",
            "Previous record: \(formatNeighbor(report.previousRecord))",
            "Next record: \(formatNeighbor(report.nextRecord))",
            "Staged records sorted by ID: \(report.stagedRecordsSortedByID)",
            "Touched flat key tables sorted: \(report.touchedFlatKeyTables.allSatisfy(\.keyTableSortedByID))",
            "Cloned known-schema flats: \(report.clonedFlats.count) (out of \(report.knownSchemaPropertyCount) known properties tried)",
            "Applied overrides: \(report.appliedOverrides.count)",
            "Verification: \(report.verificationStatus)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            ""
        ]
        if !report.touchedFlatKeyTables.isEmpty {
            lines.append("Touched flat key tables:")
            for table in report.touchedFlatKeyTables {
                lines.append("  \(table.typeName ?? table.typeHashHex) keys=\(table.keyCount) sorted=\(table.keyTableSortedByID)")
                if let issue = table.firstUnsortedKeyPair {
                    lines.append("    first unsorted key: [\(issue.previousIndex)] \(issue.previousIDHex) > [\(issue.currentIndex)] \(issue.currentIDHex)")
                }
            }
            lines.append("")
        }
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

    private static func writeOverrideFlatSummary(_ report: AddonProbeTweakDBOverrideFlatReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB existing flat override stage",
            "Status: experimental offline writer; no game files were modified.",
            "Input: \(PathSafety.redactUserPath(report.filePath)) (size=\(report.originalSize))",
            "Staged: \(PathSafety.redactUserPath(report.stagedFilePath)) (size=\(report.stagedSize))",
            "Record: \(report.record) id=\(report.recordIDHex)",
            "Flat: .\(report.property) id=\(report.flatIDHex) type=\(report.typeName)",
            "Original value: \(report.originalValue ?? "<missing>")",
            "New value: \(report.newValue)",
            "Value index: \(report.originalValueIndex) -> \(report.newValueIndex)",
            "CName value count: \(report.cNameValueCountBefore) -> \(report.cNameValueCountAfter)",
            "CName value reused: \(report.cNameValueReused)",
            "CName value appended: \(report.cNameValueAppended)",
            "Key table count: \(report.keyTableCountBefore) -> \(report.keyTableCountAfter)",
            "Key table count changed: \(report.keyTableCountChanged)",
            "Key value index changed: \(report.keyValueIndexChanged)",
            "Value block changed: \(report.valueBlockChanged)",
            "CName pool changed: \(report.cNamePoolChanged)",
            "Touched flat key table sorted: \(report.touchedFlatKeyTable.keyTableSortedByID)",
            "Verification: \(report.verificationStatus)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            ""
        ]
        if let issue = report.touchedFlatKeyTable.firstUnsortedKeyPair {
            lines.append("First unsorted key: [\(issue.previousIndex)] \(issue.previousIDHex) > [\(issue.currentIndex)] \(issue.currentIDHex)")
            lines.append("")
        }
        if !report.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeDualOverrideFlatSummary(_ report: AddonProbeTweakDBDualOverrideFlatReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB dual existing flat override stage",
            "Status: experimental offline writer; no game files were modified.",
            "Base input: \(PathSafety.redactUserPath(report.baseFilePath))",
            "EP1 input: \(PathSafety.redactUserPath(report.ep1FilePath))",
            "Base staged: \(PathSafety.redactUserPath(report.stagedBaseFilePath))",
            "EP1 staged: \(PathSafety.redactUserPath(report.stagedEP1FilePath))",
            "Record: \(report.record)",
            "Flat: .\(report.property)",
            "New value: \(report.newValue)",
            "Base verification: \(report.baseVerificationStatus)",
            "EP1 verification: \(report.ep1VerificationStatus)",
            "Verification succeeded: \(report.verificationSucceeded)",
            "Base original value: \(report.baseReport.originalValue ?? "<missing>")",
            "Base value index: \(report.baseReport.originalValueIndex) -> \(report.baseReport.newValueIndex)",
            "Base CName values: \(report.baseReport.cNameValueCountBefore) -> \(report.baseReport.cNameValueCountAfter)",
            "Base key table count changed: \(report.baseReport.keyTableCountChanged)",
            "EP1 original value: \(report.ep1Report.originalValue ?? "<missing>")",
            "EP1 value index: \(report.ep1Report.originalValueIndex) -> \(report.ep1Report.newValueIndex)",
            "EP1 CName values: \(report.ep1Report.cNameValueCountBefore) -> \(report.ep1Report.cNameValueCountAfter)",
            "EP1 key table count changed: \(report.ep1Report.keyTableCountChanged)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            ""
        ]
        if !report.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeDualCloneRecordSummary(_ report: AddonProbeTweakDBDualCloneRecordReport, to url: URL) throws {
        var lines: [String] = [
            "CyberMac TweakDB dual clone record stage",
            "Status: experimental offline writer; no game files were modified.",
            "Base input: \(PathSafety.redactUserPath(report.baseFilePath))",
            "EP1 input: \(PathSafety.redactUserPath(report.ep1FilePath))",
            "Base staged: \(PathSafety.redactUserPath(report.stagedBaseFilePath))",
            "EP1 staged: \(PathSafety.redactUserPath(report.stagedEP1FilePath))",
            "Source record: \(report.sourceRecord)",
            "New record: \(report.newRecord)",
            "Base new record sorted index: \(report.baseNewRecordSortedIndex)",
            "EP1 new record sorted index: \(report.ep1NewRecordSortedIndex)",
            "Base new record resolved: \(report.baseNewRecordResolved)",
            "EP1 new record resolved: \(report.ep1NewRecordResolved)",
            "Base records sorted by ID: \(report.baseRecordsSortedByID)",
            "EP1 records sorted by ID: \(report.ep1RecordsSortedByID)",
            "Base touched flat key tables sorted: \(report.baseTouchedFlatKeyTablesSorted)",
            "EP1 touched flat key tables sorted: \(report.ep1TouchedFlatKeyTablesSorted)",
            "Base known Clothing flats: \(report.baseKnownClothingFlatCount)/\(report.expectedKnownClothingFlatCount)",
            "EP1 known Clothing flats: \(report.ep1KnownClothingFlatCount)/\(report.expectedKnownClothingFlatCount)",
            "Base runtime binary index: \(report.baseRuntimeLookupValidation.recordBinaryIndex.map(String.init) ?? "missing")",
            "EP1 runtime binary index: \(report.ep1RuntimeLookupValidation.recordBinaryIndex.map(String.init) ?? "missing")",
            "Base verification: \(report.baseVerificationStatus)",
            "EP1 verification: \(report.ep1VerificationStatus)",
            "Verification succeeded: \(report.verificationSucceeded)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            ""
        ]
        if !report.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func formatNeighbor(_ neighbor: AddonProbeTweakDBCloneRecordNeighbor?) -> String {
        guard let neighbor else { return "none" }
        return neighbor.recordIDHex + (neighbor.recordName.map { " \($0)" } ?? "")
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
            "New record sorted index: \(report.newRecordSortedIndex)",
            "Previous record: \(formatNeighbor(report.previousRecord))",
            "Next record: \(formatNeighbor(report.nextRecord))",
            "Staged records sorted by ID: \(report.stagedRecordsSortedByID)",
            "Touched flat key tables sorted: \(report.touchedFlatKeyTables.allSatisfy(\.keyTableSortedByID))",
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

    private static func formatNeighbor(_ neighbor: AddonProbeTweakDBCloneRecordNeighbor?) -> String {
        guard let neighbor else { return "none" }
        return neighbor.recordIDHex + (neighbor.recordName.map { " \($0)" } ?? "")
    }
}

public enum AddonProbeTweakDBOverrideFlatFormatter {
    public static func format(_ report: AddonProbeTweakDBOverrideFlatReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB existing flat override stage",
            "Status: experimental offline writer; no game files were modified.",
            "Input: \(PathSafety.redactUserPath(report.filePath))",
            "Staged: \(PathSafety.redactUserPath(report.stagedFilePath))",
            "Output directory: \(PathSafety.redactUserPath(report.outputDirectoryPath))",
            "Record: \(report.record) (\(report.recordIDHex))",
            "Flat: .\(report.property) (\(report.flatIDHex)) type=\(report.typeName)",
            "Original value: \(report.originalValue ?? "<missing>")",
            "New value: \(report.newValue)",
            "Value index: \(report.originalValueIndex) -> \(report.newValueIndex)",
            "CName values: \(report.cNameValueCountBefore) -> \(report.cNameValueCountAfter)",
            "CName value reused: \(report.cNameValueReused)",
            "CName value appended: \(report.cNameValueAppended)",
            "Key table count changed: \(report.keyTableCountChanged) (\(report.keyTableCountBefore) -> \(report.keyTableCountAfter))",
            "Key value index changed: \(report.keyValueIndexChanged)",
            "Value block changed: \(report.valueBlockChanged)",
            "CName pool changed: \(report.cNamePoolChanged)",
            "Touched flat key table sorted: \(report.touchedFlatKeyTable.keyTableSortedByID)",
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

    public static func formatJSON(_ report: AddonProbeTweakDBOverrideFlatReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}

public enum AddonProbeTweakDBDualOverrideFlatFormatter {
    public static func format(_ report: AddonProbeTweakDBDualOverrideFlatReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB dual existing flat override stage",
            "Status: experimental offline writer; no game files were modified.",
            "Base input: \(PathSafety.redactUserPath(report.baseFilePath))",
            "EP1 input: \(PathSafety.redactUserPath(report.ep1FilePath))",
            "Base staged: \(PathSafety.redactUserPath(report.stagedBaseFilePath))",
            "EP1 staged: \(PathSafety.redactUserPath(report.stagedEP1FilePath))",
            "Output directory: \(PathSafety.redactUserPath(report.outputDirectoryPath))",
            "Record: \(report.record)",
            "Flat: .\(report.property)",
            "New value: \(report.newValue)",
            "Base verification: \(report.baseVerificationStatus)",
            "EP1 verification: \(report.ep1VerificationStatus)",
            "Verification succeeded: \(report.verificationSucceeded)",
            "Base value index: \(report.baseReport.originalValueIndex) -> \(report.baseReport.newValueIndex)",
            "EP1 value index: \(report.ep1Report.originalValueIndex) -> \(report.ep1Report.newValueIndex)",
            "Base key table count changed: \(report.baseReport.keyTableCountChanged)",
            "EP1 key table count changed: \(report.ep1Report.keyTableCountChanged)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Summary: \(PathSafety.redactUserPath(report.summaryPath))"
        ]
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBDualOverrideFlatReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}

public enum AddonProbeTweakDBDualCloneRecordFormatter {
    public static func format(_ report: AddonProbeTweakDBDualCloneRecordReport) -> String {
        var lines: [String] = [
            "CyberMac TweakDB dual clone record stage",
            "Status: experimental offline writer; no game files were modified.",
            "Base input: \(PathSafety.redactUserPath(report.baseFilePath))",
            "EP1 input: \(PathSafety.redactUserPath(report.ep1FilePath))",
            "Base staged: \(PathSafety.redactUserPath(report.stagedBaseFilePath))",
            "EP1 staged: \(PathSafety.redactUserPath(report.stagedEP1FilePath))",
            "Output directory: \(PathSafety.redactUserPath(report.outputDirectoryPath))",
            "Source: \(report.sourceRecord)",
            "New: \(report.newRecord)",
            "Base new record sorted index: \(report.baseNewRecordSortedIndex)",
            "EP1 new record sorted index: \(report.ep1NewRecordSortedIndex)",
            "Base binary lookup: \(report.baseRuntimeLookupValidation.recordBinaryFound ? "found" : "missing")\(report.baseRuntimeLookupValidation.recordBinaryIndex.map { " index=\($0)" } ?? "")",
            "EP1 binary lookup: \(report.ep1RuntimeLookupValidation.recordBinaryFound ? "found" : "missing")\(report.ep1RuntimeLookupValidation.recordBinaryIndex.map { " index=\($0)" } ?? "")",
            "Base records sorted by ID: \(report.baseRecordsSortedByID)",
            "EP1 records sorted by ID: \(report.ep1RecordsSortedByID)",
            "Base touched flat key tables sorted: \(report.baseTouchedFlatKeyTablesSorted)",
            "EP1 touched flat key tables sorted: \(report.ep1TouchedFlatKeyTablesSorted)",
            "Base known Clothing flats: \(report.baseKnownClothingFlatCount)/\(report.expectedKnownClothingFlatCount)",
            "EP1 known Clothing flats: \(report.ep1KnownClothingFlatCount)/\(report.expectedKnownClothingFlatCount)",
            "Verification succeeded: \(report.verificationSucceeded)",
            "Conclusions: \(report.conclusions.map(\.rawValue).joined(separator: ", "))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))",
            "Summary: \(PathSafety.redactUserPath(report.summaryPath))"
        ]
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeTweakDBDualCloneRecordReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}
