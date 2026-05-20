import Foundation
import ZIPFoundation

public enum AddonProbeInputKind: String, Codable, Equatable, Sendable {
    case directory
    case zip
}

public enum AddonProbeClassification: String, Codable, Equatable, Sendable {
    case replacerOnly
    case archiveXLTweakXLAddonCandidate
    case mixedReplacerAddon
    case unsupportedUnknown
}

public struct AddonProbeInspectRequest: Equatable, Sendable {
    public let modURL: URL
    public let outputDirectoryURL: URL?

    public init(modURL: URL, outputDirectoryURL: URL? = nil) {
        self.modURL = modURL
        self.outputDirectoryURL = outputDirectoryURL
    }
}

public struct AddonProbeExpandedItemRecord: Codable, Equatable, Sendable {
    public let templateRecord: String
    public let recordID: String
    public let itemID: String
    public let instanceVariables: [String: String]
    public let baseRecord: String?
    public let placementSlots: [String]
    public let appearanceName: String?
    public let entityName: String?
    public let displayName: String?
    public let localizedDescription: String?
    public let iconAtlasPath: String?
    public let iconAtlasPart: String?
    public let iconAtlasResourcePath: String?
    public let iconAtlasPartName: String?
    public let quality: String?
    public let statModifiers: [String]

    public init(
        templateRecord: String,
        recordID: String? = nil,
        itemID: String,
        instanceVariables: [String: String],
        baseRecord: String?,
        placementSlots: [String],
        appearanceName: String?,
        entityName: String?,
        displayName: String?,
        localizedDescription: String? = nil,
        iconAtlasPath: String?,
        iconAtlasPart: String?,
        iconAtlasResourcePath: String? = nil,
        iconAtlasPartName: String? = nil,
        quality: String? = nil,
        statModifiers: [String] = []
    ) {
        self.templateRecord = templateRecord
        self.recordID = recordID ?? itemID
        self.itemID = itemID
        self.instanceVariables = instanceVariables
        self.baseRecord = baseRecord
        self.placementSlots = placementSlots
        self.appearanceName = appearanceName
        self.entityName = entityName
        self.displayName = displayName
        self.localizedDescription = localizedDescription
        self.iconAtlasPath = iconAtlasPath
        self.iconAtlasPart = iconAtlasPart
        self.iconAtlasResourcePath = iconAtlasResourcePath ?? iconAtlasPath
        self.iconAtlasPartName = iconAtlasPartName ?? iconAtlasPart
        self.quality = quality
        self.statModifiers = statModifiers
    }
}

public struct AddonProbeTweakXLAnalysis: Codable, Equatable, Sendable {
    public let templatedItemRecords: [String]
    public let expandedItemRecords: [AddonProbeExpandedItemRecord]
    public let expandedItemIDs: [String]
    public let baseRecords: [String]
    public let placementSlots: [String]
    public let appearanceNames: [String]
    public let entityNames: [String]
    public let displayNames: [String]
    public let iconAtlasPaths: [String]
    public let iconAtlasParts: [String]
    public let instanceCount: Int
    public let unresolvedTemplateExpressions: [String]
    public let warnings: [String]

    public init(
        templatedItemRecords: [String],
        expandedItemRecords: [AddonProbeExpandedItemRecord],
        expandedItemIDs: [String],
        baseRecords: [String],
        placementSlots: [String],
        appearanceNames: [String],
        entityNames: [String],
        displayNames: [String],
        iconAtlasPaths: [String],
        iconAtlasParts: [String],
        instanceCount: Int,
        unresolvedTemplateExpressions: [String],
        warnings: [String]
    ) {
        self.templatedItemRecords = templatedItemRecords
        self.expandedItemRecords = expandedItemRecords
        self.expandedItemIDs = expandedItemIDs
        self.baseRecords = baseRecords
        self.placementSlots = placementSlots
        self.appearanceNames = appearanceNames
        self.entityNames = entityNames
        self.displayNames = displayNames
        self.iconAtlasPaths = iconAtlasPaths
        self.iconAtlasParts = iconAtlasParts
        self.instanceCount = instanceCount
        self.unresolvedTemplateExpressions = unresolvedTemplateExpressions
        self.warnings = warnings
    }
}

public struct AddonProbeXLMetadataAnalysis: Codable, Equatable, Sendable {
    public let factoryCSVFilesFromXL: [String]
    public let localizationJSONFilesFromXL: [String]

    public init(factoryCSVFilesFromXL: [String], localizationJSONFilesFromXL: [String]) {
        self.factoryCSVFilesFromXL = factoryCSVFilesFromXL
        self.localizationJSONFilesFromXL = localizationJSONFilesFromXL
    }
}

public struct AddonProbeInspectReport: Codable, Equatable, Sendable {
    public let sourceModPath: String
    public let inspectedRootPath: String
    public let inputKind: AddonProbeInputKind
    public let archiveFiles: [String]
    public let xlFiles: [String]
    public let tweakFiles: [String]
    public let csvFiles: [String]
    public let jsonLocalizationFiles: [String]
    public let candidateItemIDs: [String]
    public let referencedItemIDs: [String]
    public let candidateBaseRecords: [String]
    public let candidateResourceReferences: [String]
    public let templatedItemRecords: [String]
    public let expandedItemRecords: [AddonProbeExpandedItemRecord]
    public let expandedItemIDs: [String]
    public let baseRecords: [String]
    public let placementSlots: [String]
    public let appearanceNames: [String]
    public let entityNames: [String]
    public let displayNames: [String]
    public let iconAtlasPaths: [String]
    public let iconAtlasParts: [String]
    public let instanceCount: Int
    public let unresolvedTemplateExpressions: [String]
    public let factoryCSVFilesFromXL: [String]
    public let localizationJSONFilesFromXL: [String]
    public let classification: AddonProbeClassification
    public let reasons: [String]
    public let warnings: [String]
    public let writtenReportPath: String?

    public init(
        sourceModPath: String,
        inspectedRootPath: String,
        inputKind: AddonProbeInputKind,
        archiveFiles: [String],
        xlFiles: [String],
        tweakFiles: [String],
        csvFiles: [String],
        jsonLocalizationFiles: [String],
        candidateItemIDs: [String],
        referencedItemIDs: [String],
        candidateBaseRecords: [String],
        candidateResourceReferences: [String],
        templatedItemRecords: [String] = [],
        expandedItemRecords: [AddonProbeExpandedItemRecord] = [],
        expandedItemIDs: [String] = [],
        baseRecords: [String] = [],
        placementSlots: [String] = [],
        appearanceNames: [String] = [],
        entityNames: [String] = [],
        displayNames: [String] = [],
        iconAtlasPaths: [String] = [],
        iconAtlasParts: [String] = [],
        instanceCount: Int = 0,
        unresolvedTemplateExpressions: [String] = [],
        factoryCSVFilesFromXL: [String] = [],
        localizationJSONFilesFromXL: [String] = [],
        classification: AddonProbeClassification,
        reasons: [String],
        warnings: [String],
        writtenReportPath: String?
    ) {
        self.sourceModPath = sourceModPath
        self.inspectedRootPath = inspectedRootPath
        self.inputKind = inputKind
        self.archiveFiles = archiveFiles
        self.xlFiles = xlFiles
        self.tweakFiles = tweakFiles
        self.csvFiles = csvFiles
        self.jsonLocalizationFiles = jsonLocalizationFiles
        self.candidateItemIDs = candidateItemIDs
        self.referencedItemIDs = referencedItemIDs
        self.candidateBaseRecords = candidateBaseRecords
        self.candidateResourceReferences = candidateResourceReferences
        self.templatedItemRecords = templatedItemRecords
        self.expandedItemRecords = expandedItemRecords
        self.expandedItemIDs = expandedItemIDs
        self.baseRecords = baseRecords
        self.placementSlots = placementSlots
        self.appearanceNames = appearanceNames
        self.entityNames = entityNames
        self.displayNames = displayNames
        self.iconAtlasPaths = iconAtlasPaths
        self.iconAtlasParts = iconAtlasParts
        self.instanceCount = instanceCount
        self.unresolvedTemplateExpressions = unresolvedTemplateExpressions
        self.factoryCSVFilesFromXL = factoryCSVFilesFromXL
        self.localizationJSONFilesFromXL = localizationJSONFilesFromXL
        self.classification = classification
        self.reasons = reasons
        self.warnings = warnings
        self.writtenReportPath = writtenReportPath
    }
}

public struct AddonProbeStageAssetsRequest: Sendable {
    public let modURL: URL
    public let targetArchiveRelativePath: String
    public let profileID: String
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall
    public let databaseURL: URL?

    public init(
        modURL: URL,
        targetArchiveRelativePath: String,
        profileID: String,
        outputDirectoryURL: URL,
        cp77toolsURL: URL,
        gameInstall: GameInstall,
        databaseURL: URL? = nil
    ) {
        self.modURL = modURL
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.profileID = profileID
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
        self.databaseURL = databaseURL
    }
}

public struct AddonProbeGrantManyRequest: Sendable {
    public let inputURL: URL
    public let outputZipURL: URL
    public let modName: String?

    public init(inputURL: URL, outputZipURL: URL, modName: String? = nil) {
        self.inputURL = inputURL
        self.outputZipURL = outputZipURL
        self.modName = modName
    }
}

public struct AddonProbeGrantManyResult: Codable, Equatable, Sendable {
    public let inputPath: String
    public let outputZipPath: String
    public let modName: String
    public let redscriptEntryPath: String
    public let itemIDs: [String]
    public let warnings: [String]

    public init(
        inputPath: String,
        outputZipPath: String,
        modName: String,
        redscriptEntryPath: String,
        itemIDs: [String],
        warnings: [String]
    ) {
        self.inputPath = inputPath
        self.outputZipPath = outputZipPath
        self.modName = modName
        self.redscriptEntryPath = redscriptEntryPath
        self.itemIDs = itemIDs
        self.warnings = warnings
    }
}

public struct AddonProbeAtomiicSummaryReport: Codable, Equatable, Sendable {
    public let modPath: String
    public let totalExpandedItems: Int
    public let shirtsCount: Int
    public let skirtsCount: Int
    public let factoryCSVFilesFromXL: [String]
    public let localizationJSONFilesFromXL: [String]
    public let iconAtlasPaths: [String]
    public let archiveFiles: [String]
    public let expectedUnresolvedLayers: [String]
    public let warnings: [String]

    public init(
        modPath: String,
        totalExpandedItems: Int,
        shirtsCount: Int,
        skirtsCount: Int,
        factoryCSVFilesFromXL: [String],
        localizationJSONFilesFromXL: [String],
        iconAtlasPaths: [String],
        archiveFiles: [String],
        expectedUnresolvedLayers: [String],
        warnings: [String]
    ) {
        self.modPath = modPath
        self.totalExpandedItems = totalExpandedItems
        self.shirtsCount = shirtsCount
        self.skirtsCount = skirtsCount
        self.factoryCSVFilesFromXL = factoryCSVFilesFromXL
        self.localizationJSONFilesFromXL = localizationJSONFilesFromXL
        self.iconAtlasPaths = iconAtlasPaths
        self.archiveFiles = archiveFiles
        self.expectedUnresolvedLayers = expectedUnresolvedLayers
        self.warnings = warnings
    }
}

public enum AddonProbeXLFactoryAnalysisConclusion: String, Codable, Equatable, Sendable {
    case xlFactoryDecoded
    case xlFactoryMissing
    case xlFactoryFoundButDecodeFailed
    case localizationFound
    case localizationMissing
    case unresolved
}

public struct AddonProbeXLFactoryAnalysisRequest: Sendable {
    public let modURL: URL
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall

    public init(modURL: URL, outputDirectoryURL: URL, cp77toolsURL: URL, gameInstall: GameInstall) {
        self.modURL = modURL
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
    }
}

public struct AddonProbeXLResourceDiagnostic: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let archivePath: String?
    public let extractedPath: String?
    public let exists: Bool
    public let size: Int?
    public let first32BytesHex: String
    public let detectedMagic: AddonProbeFactoryResourceMagic
    public let warnings: [String]
}

public struct AddonProbeXLJSONStringValue: Codable, Equatable, Sendable {
    public let jsonPath: String
    public let value: String
}

public struct AddonProbeXLDecodedFactoryJSONSummary: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let decodedJSONPath: String
    public let topLevelType: String
    public let topLevelKeys: [String]
    public let compiledDataRowCount: Int?
    public let dataRowCount: Int?
    public let stringValues: [AddonProbeXLJSONStringValue]
    public let entReferences: [String]
    public let appReferences: [String]
    public let appearanceNames: [String]
    public let entityKeys: [String]
    public let atomiicStrings: [String]
    public let shirtStrings: [String]
    public let skirtStrings: [String]
    public let slotStrings: [String]
    public let warnings: [String]
}

public struct AddonProbeXLLocalizationSummary: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let decodedPath: String?
    public let localizationKeys: [String]
    public let stringValues: [AddonProbeXLJSONStringValue]
    public let warnings: [String]
}

public struct AddonProbeXLYAMLComparison: Codable, Equatable, Sendable {
    public let expectedEntityNames: [String]
    public let matchedEntityNames: [String]
    public let missingEntityNames: [String]
    public let expectedAppearanceNames: [String]
    public let matchedAppearanceNames: [String]
    public let missingAppearanceNames: [String]
    public let expectedDisplayNames: [String]
    public let matchedDisplayNames: [String]
    public let missingDisplayNames: [String]
    public let expectedIconAtlasPaths: [String]
    public let matchedIconAtlasPaths: [String]
    public let missingIconAtlasPaths: [String]
    public let expectedIconAtlasParts: [String]
    public let matchedIconAtlasParts: [String]
    public let missingIconAtlasParts: [String]
}

public struct AddonProbeXLFactoryAnalysisReport: Codable, Equatable, Sendable {
    public let modPath: String
    public let archiveFiles: [String]
    public let xlFiles: [String]
    public let declaredFactoryCSVs: [String]
    public let declaredLocalizationJSONs: [String]
    public let extractedResourceDiagnostics: [AddonProbeXLResourceDiagnostic]
    public let decodedFactoryJSONPaths: [String]
    public let decodedLocalizationPaths: [String]
    public let factoryJSONSummaries: [AddonProbeXLDecodedFactoryJSONSummary]
    public let localizationSummaries: [AddonProbeXLLocalizationSummary]
    public let yamlComparison: AddonProbeXLYAMLComparison
    public let cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt]
    public let warnings: [String]
    public let conclusion: AddonProbeXLFactoryAnalysisConclusion
    public let reportPath: String
}

public enum AddonProbeXLFactoryRegistryStageConclusion: String, Codable, Equatable, CaseIterable, Sendable {
    case stagedFactoryRegistryArchiveProduced
    case stagedRegistryArchiveProduced
    case factoryPathAlreadyPresent
    case factoryRegistryDecodeFailed
    case factoryRegistryEditFailed
    case baselineDeserializeFailed
    case deserializeFailed
    case packFailed
    case unresolved
}

public struct AddonProbeFactoryRegistryRawInsertion: Codable, Equatable, Sendable {
    public let arrayPath: String
    public let insertionOffset: Int
    public let insertionLine: Int
    public let context: String

    public init(arrayPath: String, insertionOffset: Int, insertionLine: Int, context: String) {
        self.arrayPath = arrayPath
        self.insertionOffset = insertionOffset
        self.insertionLine = insertionLine
        self.context = context
    }
}

public struct AddonProbeFactoryRegistryRawEditResult: Equatable, Sendable {
    public let declaredFactoryPaths: [String]
    public let alreadyPresentFactoryPaths: [String]
    public let addedFactoryPaths: [String]
    public let rowsAddedCompiledData: Int
    public let rowsAddedData: Int
    public let clonedSourceRowPath: String?
    public let clonedSourceRowText: String?
    public let addedRowText: String?
    public let compiledDataRowsBefore: Int?
    public let compiledDataRowsAfter: Int?
    public let dataRowsBefore: Int?
    public let dataRowsAfter: Int?
    public let compiledDataInsertion: AddonProbeFactoryRegistryRawInsertion?
    public let dataInsertion: AddonProbeFactoryRegistryRawInsertion?
    public let editedJSONText: String?
    public let conclusion: AddonProbeXLFactoryRegistryStageConclusion
    public let warnings: [String]
}

public struct AddonProbeXLFactoryRegistryStageRequest: Sendable {
    public let modURL: URL
    public let archivePath: String
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall

    public init(modURL: URL, archivePath: String, outputDirectoryURL: URL, cp77toolsURL: URL, gameInstall: GameInstall) {
        self.modURL = modURL
        self.archivePath = archivePath
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
    }
}

public struct AddonProbeXLFactoryRegistryEditResult: Equatable, Sendable {
    public let declaredFactoryPaths: [String]
    public let alreadyPresentFactoryPaths: [String]
    public let addedFactoryPaths: [String]
    public let rowsAddedCompiledData: Int
    public let rowsAddedData: Int
    public let clonedSourceRowPath: String?
    public let clonedSourceRowPreview: String?
    public let addedRowPreview: String?
    public let compiledDataRowsBefore: Int?
    public let compiledDataRowsAfter: Int?
    public let dataRowsBefore: Int?
    public let dataRowsAfter: Int?
    public let editedJSONData: Data?
    public let conclusion: AddonProbeXLFactoryRegistryStageConclusion
    public let warnings: [String]
}

public struct AddonProbeXLFactoryRegistryStageManifest: Codable, Equatable, Sendable {
    public let modPath: String
    public let archive: String
    public let resource: String
    public let declaredFactoryCSVs: [String]
    public let alreadyPresentFactoryCSVs: [String]
    public let addedFactoryCSVs: [String]
    public let rowsAddedCompiledData: Int
    public let rowsAddedData: Int
    public let clonedSourceRowPath: String?
    public let clonedSourceRowPreview: String?
    public let addedRowPreview: String?
    public let compiledDataRowsBefore: Int?
    public let compiledDataRowsAfter: Int?
    public let dataRowsBefore: Int?
    public let dataRowsAfter: Int?
    public let compiledDataInsertion: AddonProbeFactoryRegistryRawInsertion?
    public let dataInsertion: AddonProbeFactoryRegistryRawInsertion?
    public let decodedOriginalJson: String?
    public let decodedEditedJson: String?
    public let editedJsonPath: String?
    public let rebuiltResource: String?
    public let stagedArchive: String?
    public let originalResourceSHA256: String?
    public let editedResourceSHA256: String?
    public let stagedArchiveSHA256: String?
    public let originalResourceSize: UInt64?
    public let editedResourceSize: UInt64?
    public let cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt]
    public let baselineDeserializeStdout: String?
    public let baselineDeserializeStderr: String?
    public let deserializeStdout: String?
    public let deserializeStderr: String?
    public let conclusion: AddonProbeXLFactoryRegistryStageConclusion
    public let warnings: [String]
    public let manifestPath: String
    public let manualInstallCommand: String?
}

public struct AddonProbeOfficialIndexMatch: Codable, Equatable, Sendable {
    public let assetPath: String
    public let officialArchives: [String]

    public init(assetPath: String, officialArchives: [String]) {
        self.assetPath = assetPath
        self.officialArchives = officialArchives
    }
}

public struct AddonProbeStageManifest: Codable, Equatable, Sendable {
    public let modPath: String
    public let targetArchiveRelativePath: String
    public let profileID: String
    public let discoveredArchives: [String]
    public let discoveredXLFiles: [String]
    public let discoveredYAMLFiles: [String]
    public let discoveredCSVFiles: [String]
    public let discoveredJSONFiles: [String]
    public let extractedAssetPaths: [String]
    public let exactMatchAssets: [String]
    public let addedCustomAssets: [String]
    public let candidateItemIDs: [String]
    public let candidateResourceReferences: [String]
    public let officialIndexMatches: [AddonProbeOfficialIndexMatch]
    public let stagedArchivePath: String
    public let stagedSHA256: String
    public let manifestPath: String
    public let manualInstallCommand: String
    public let warnings: [String]

    public init(
        modPath: String,
        targetArchiveRelativePath: String,
        profileID: String,
        discoveredArchives: [String],
        discoveredXLFiles: [String],
        discoveredYAMLFiles: [String],
        discoveredCSVFiles: [String],
        discoveredJSONFiles: [String],
        extractedAssetPaths: [String],
        exactMatchAssets: [String],
        addedCustomAssets: [String],
        candidateItemIDs: [String],
        candidateResourceReferences: [String],
        officialIndexMatches: [AddonProbeOfficialIndexMatch],
        stagedArchivePath: String,
        stagedSHA256: String,
        manifestPath: String,
        manualInstallCommand: String,
        warnings: [String]
    ) {
        self.modPath = modPath
        self.targetArchiveRelativePath = targetArchiveRelativePath
        self.profileID = profileID
        self.discoveredArchives = discoveredArchives
        self.discoveredXLFiles = discoveredXLFiles
        self.discoveredYAMLFiles = discoveredYAMLFiles
        self.discoveredCSVFiles = discoveredCSVFiles
        self.discoveredJSONFiles = discoveredJSONFiles
        self.extractedAssetPaths = extractedAssetPaths
        self.exactMatchAssets = exactMatchAssets
        self.addedCustomAssets = addedCustomAssets
        self.candidateItemIDs = candidateItemIDs
        self.candidateResourceReferences = candidateResourceReferences
        self.officialIndexMatches = officialIndexMatches
        self.stagedArchivePath = stagedArchivePath
        self.stagedSHA256 = stagedSHA256
        self.manifestPath = manifestPath
        self.manualInstallCommand = manualInstallCommand
        self.warnings = warnings
    }
}

public struct AddonProbeRecordLayerQueryReport: Codable, Equatable, Sendable {
    public let query: String
    public let command: String
    public let totalMatchCount: Int
    public let shownMatchCount: Int
    public let matches: [ArchiveCatalogIndexSearchMatch]

    public init(
        query: String,
        command: String,
        totalMatchCount: Int,
        shownMatchCount: Int,
        matches: [ArchiveCatalogIndexSearchMatch]
    ) {
        self.query = query
        self.command = command
        self.totalMatchCount = totalMatchCount
        self.shownMatchCount = shownMatchCount
        self.matches = matches
    }
}

public struct AddonProbeRecordLayerSearchReport: Codable, Equatable, Sendable {
    public static let queries = ["tweakdb", "gamedata", "Items.", "TweakDB", ".tweak", ".tdb"]

    public let databasePath: String
    public let databaseExists: Bool
    public let limit: Int
    public let queryReports: [AddonProbeRecordLayerQueryReport]
    public let commands: [String]
    public let likelyPatchableRecordLayerFound: Bool
    public let status: String
    public let warnings: [String]

    public init(
        databasePath: String,
        databaseExists: Bool,
        limit: Int,
        queryReports: [AddonProbeRecordLayerQueryReport],
        commands: [String],
        likelyPatchableRecordLayerFound: Bool,
        status: String,
        warnings: [String]
    ) {
        self.databasePath = databasePath
        self.databaseExists = databaseExists
        self.limit = limit
        self.queryReports = queryReports
        self.commands = commands
        self.likelyPatchableRecordLayerFound = likelyPatchableRecordLayerFound
        self.status = status
        self.warnings = warnings
    }
}

public struct AddonProbeTweakXLExpandedRecordsReport: Codable, Equatable, Sendable {
    public let modPath: String
    public let recordCount: Int
    public let baseRecordCounts: [String: Int]
    public let records: [AddonProbeExpandedItemRecord]
    public let warnings: [String]

    public init(
        modPath: String,
        recordCount: Int,
        baseRecordCounts: [String: Int],
        records: [AddonProbeExpandedItemRecord],
        warnings: [String]
    ) {
        self.modPath = modPath
        self.recordCount = recordCount
        self.baseRecordCounts = baseRecordCounts
        self.records = records
        self.warnings = warnings
    }
}

public struct AddonProbeRecordLayerProbeRequest: Sendable {
    public let modURL: URL
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall
    public let databaseURL: URL

    public init(
        modURL: URL,
        outputDirectoryURL: URL,
        cp77toolsURL: URL,
        gameInstall: GameInstall,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) {
        self.modURL = modURL
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
        self.databaseURL = databaseURL
    }
}

public struct AddonProbeRecordLayerCandidateResource: Codable, Equatable, Sendable {
    public let archivePath: String
    public let assetPath: String
    public let assetExtension: String
    public let category: String
    public let matchedTerms: [String]

    public init(
        archivePath: String,
        assetPath: String,
        assetExtension: String,
        category: String,
        matchedTerms: [String]
    ) {
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.assetExtension = assetExtension
        self.category = category
        self.matchedTerms = matchedTerms
    }
}

public struct AddonProbeRecordLayerResourceDiagnostic: Codable, Equatable, Sendable {
    public let archivePath: String
    public let resourcePath: String
    public let extractedPath: String?
    public let exists: Bool
    public let size: Int?
    public let first32BytesHex: String
    public let detectedMagic: AddonProbeFactoryResourceMagic
    public let parseStatus: AddonProbeFactoryParseStatus
    public let warnings: [String]

    public init(
        archivePath: String,
        resourcePath: String,
        extractedPath: String?,
        exists: Bool,
        size: Int?,
        first32BytesHex: String,
        detectedMagic: AddonProbeFactoryResourceMagic,
        parseStatus: AddonProbeFactoryParseStatus,
        warnings: [String]
    ) {
        self.archivePath = archivePath
        self.resourcePath = resourcePath
        self.extractedPath = extractedPath
        self.exists = exists
        self.size = size
        self.first32BytesHex = first32BytesHex
        self.detectedMagic = detectedMagic
        self.parseStatus = parseStatus
        self.warnings = warnings
    }
}

public struct AddonProbeRecordLayerTextMatch: Codable, Equatable, Sendable {
    public let term: String
    public let archivePath: String?
    public let resourcePath: String
    public let sourcePath: String
    public let lineNumber: Int?
    public let jsonPath: String?
    public let matchedString: String

    public init(
        term: String,
        archivePath: String?,
        resourcePath: String,
        sourcePath: String,
        lineNumber: Int?,
        jsonPath: String?,
        matchedString: String
    ) {
        self.term = term
        self.archivePath = archivePath
        self.resourcePath = resourcePath
        self.sourcePath = sourcePath
        self.lineNumber = lineNumber
        self.jsonPath = jsonPath
        self.matchedString = matchedString
    }
}

public enum AddonProbeRecordLayerProbeConclusion: String, Codable, Equatable, Sendable {
    case patchableRecordLayerCandidateFound
    case candidateResourcesFoundNoRecordDefinitions
    case noCandidateResources
    case archiveIndexMissing
    case unresolved
}

public struct AddonProbeRecordLayerProbeReport: Codable, Equatable, Sendable {
    public let modPath: String
    public let outputDirectoryPath: String
    public let expandedRecordsPath: String
    public let expandedRecords: [AddonProbeExpandedItemRecord]
    public let baseRecordCounts: [String: Int]
    public let searchTerms: [String]
    public let indexDatabasePath: String
    public let indexDatabaseExists: Bool
    public let indexSearches: [AddonProbeFactoryIndexSearchReport]
    public let candidateResources: [AddonProbeRecordLayerCandidateResource]
    public let extractionArchivePaths: [String]
    public let resourceDiagnostics: [AddonProbeRecordLayerResourceDiagnostic]
    public let cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt]
    public let decodedTextMatches: [AddonProbeRecordLayerTextMatch]
    public let likelyPatchableRecordLayerFound: Bool
    public let conclusion: AddonProbeRecordLayerProbeConclusion
    public let warnings: [String]
    public let reportPath: String

    public init(
        modPath: String,
        outputDirectoryPath: String,
        expandedRecordsPath: String,
        expandedRecords: [AddonProbeExpandedItemRecord],
        baseRecordCounts: [String: Int],
        searchTerms: [String],
        indexDatabasePath: String,
        indexDatabaseExists: Bool,
        indexSearches: [AddonProbeFactoryIndexSearchReport],
        candidateResources: [AddonProbeRecordLayerCandidateResource],
        extractionArchivePaths: [String],
        resourceDiagnostics: [AddonProbeRecordLayerResourceDiagnostic],
        cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt],
        decodedTextMatches: [AddonProbeRecordLayerTextMatch],
        likelyPatchableRecordLayerFound: Bool,
        conclusion: AddonProbeRecordLayerProbeConclusion,
        warnings: [String],
        reportPath: String
    ) {
        self.modPath = modPath
        self.outputDirectoryPath = outputDirectoryPath
        self.expandedRecordsPath = expandedRecordsPath
        self.expandedRecords = expandedRecords
        self.baseRecordCounts = baseRecordCounts
        self.searchTerms = searchTerms
        self.indexDatabasePath = indexDatabasePath
        self.indexDatabaseExists = indexDatabaseExists
        self.indexSearches = indexSearches
        self.candidateResources = candidateResources
        self.extractionArchivePaths = extractionArchivePaths
        self.resourceDiagnostics = resourceDiagnostics
        self.cp77toolsCommandsAttempted = cp77toolsCommandsAttempted
        self.decodedTextMatches = decodedTextMatches
        self.likelyPatchableRecordLayerFound = likelyPatchableRecordLayerFound
        self.conclusion = conclusion
        self.warnings = warnings
        self.reportPath = reportPath
    }
}

public struct AddonProbeRecordRuntimeProbeRequest: Sendable {
    public let modURL: URL
    public let outputZipURL: URL
    public let modName: String?

    public init(modURL: URL, outputZipURL: URL, modName: String? = nil) {
        self.modURL = modURL
        self.outputZipURL = outputZipURL
        self.modName = modName
    }
}

public struct AddonProbeRecordRuntimeProbeResult: Codable, Equatable, Sendable {
    public let inputPath: String
    public let outputZipPath: String
    public let modName: String
    public let redscriptEntryPath: String
    public let baseRecordIDs: [String]
    public let customRecordIDs: [String]
    public let warnings: [String]

    public init(
        inputPath: String,
        outputZipPath: String,
        modName: String,
        redscriptEntryPath: String,
        baseRecordIDs: [String],
        customRecordIDs: [String],
        warnings: [String]
    ) {
        self.inputPath = inputPath
        self.outputZipPath = outputZipPath
        self.modName = modName
        self.redscriptEntryPath = redscriptEntryPath
        self.baseRecordIDs = baseRecordIDs
        self.customRecordIDs = customRecordIDs
        self.warnings = warnings
    }
}

public struct AddonProbeCompareBaseRecordsRequest: Sendable {
    public let modURL: URL
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall
    public let databaseURL: URL

    public init(
        modURL: URL,
        outputDirectoryURL: URL,
        cp77toolsURL: URL,
        gameInstall: GameInstall,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) {
        self.modURL = modURL
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
        self.databaseURL = databaseURL
    }
}

public enum AddonProbeCompareBaseRecordsConclusion: String, Codable, Equatable, Sendable {
    case decodedBaseRecordReferencesFound
    case unresolved
}

public struct AddonProbeCompareBaseRecordsReport: Codable, Equatable, Sendable {
    public let modPath: String
    public let baseRecordIDs: [String]
    public let recordLayerReportPath: String
    public let matchesByBaseRecord: [String: [AddonProbeRecordLayerTextMatch]]
    public let conclusion: AddonProbeCompareBaseRecordsConclusion
    public let summary: String
    public let warnings: [String]
    public let reportPath: String

    public init(
        modPath: String,
        baseRecordIDs: [String],
        recordLayerReportPath: String,
        matchesByBaseRecord: [String: [AddonProbeRecordLayerTextMatch]],
        conclusion: AddonProbeCompareBaseRecordsConclusion,
        summary: String,
        warnings: [String],
        reportPath: String
    ) {
        self.modPath = modPath
        self.baseRecordIDs = baseRecordIDs
        self.recordLayerReportPath = recordLayerReportPath
        self.matchesByBaseRecord = matchesByBaseRecord
        self.conclusion = conclusion
        self.summary = summary
        self.warnings = warnings
        self.reportPath = reportPath
    }
}

public struct AddonProbePlanReport: Codable, Equatable, Sendable {
    public let inspect: AddonProbeInspectReport
    public let steps: [String]
    public let expectedFailureModes: [String]
    public let warnings: [String]

    public init(
        inspect: AddonProbeInspectReport,
        steps: [String],
        expectedFailureModes: [String],
        warnings: [String]
    ) {
        self.inspect = inspect
        self.steps = steps
        self.expectedFailureModes = expectedFailureModes
        self.warnings = warnings
    }
}

public enum AddonProbeFactoryLayerConclusion: String, Codable, Equatable, Sendable {
    case relevantToItemResourceRegistration = "factory CSVs appear relevant to item/resource registration"
    case spawningLookupButInsufficient = "factory CSVs appear relevant to spawning/factory lookup but insufficient for TweakDB item registration"
    case cr2wDecodeRequired = "factory resources found, but CR2W decoding is required before CSV analysis"
    case unrelated = "factory CSVs appear unrelated to clothing item registration"
    case unableToDetermine = "unable to determine"
}

public struct AddonProbeFactoryLayerRequest: Sendable {
    public let outputDirectoryURL: URL?
    public let cp77toolsURL: URL?
    public let gameInstall: GameInstall?
    public let databaseURL: URL
    public let tryCR2WDecode: Bool

    public init(
        outputDirectoryURL: URL? = nil,
        cp77toolsURL: URL? = nil,
        gameInstall: GameInstall? = nil,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        tryCR2WDecode: Bool = false
    ) {
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
        self.databaseURL = databaseURL
        self.tryCR2WDecode = tryCR2WDecode
    }
}

public struct AddonProbeFactoryIndexSearchReport: Codable, Equatable, Sendable {
    public let term: String
    public let exactResource: Bool
    public let totalMatchCount: Int
    public let shownMatchCount: Int
    public let matches: [ArchiveCatalogIndexSearchMatch]

    public init(
        term: String,
        exactResource: Bool,
        totalMatchCount: Int,
        shownMatchCount: Int,
        matches: [ArchiveCatalogIndexSearchMatch]
    ) {
        self.term = term
        self.exactResource = exactResource
        self.totalMatchCount = totalMatchCount
        self.shownMatchCount = shownMatchCount
        self.matches = matches
    }
}

public struct AddonProbeFactoryExtractedFile: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let extractedPath: String
    public let required: Bool
    public let parsed: Bool

    public init(resourcePath: String, extractedPath: String, required: Bool, parsed: Bool) {
        self.resourcePath = resourcePath
        self.extractedPath = extractedPath
        self.required = required
        self.parsed = parsed
    }
}

public enum AddonProbeFactoryResourceMagic: String, Codable, Equatable, Sendable {
    case cr2w = "CR2W"
    case kark = "KARK"
    case jsonText = "jsonText"
    case utf8Text = "utf8Text"
    case empty = "empty"
    case unknownBinary = "unknownBinary"
}

public enum AddonProbeFactoryParseStatus: String, Codable, Equatable, Sendable {
    case parsedTextCSV
    case parsedJSONText
    case extractedCR2W
    case extractedKARK
    case extractedUnknownBinary
    case empty
    case missing
    case extractionFailed
}

public struct AddonProbeFactoryDecodeAttempt: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let command: String
    public let exitCode: Int32?
    public let stdout: String
    public let stderr: String
    public let producedFiles: [String]
    public let parsedOutputPath: String?
    public let warnings: [String]

    public init(
        resourcePath: String,
        command: String,
        exitCode: Int32?,
        stdout: String,
        stderr: String,
        producedFiles: [String],
        parsedOutputPath: String?,
        warnings: [String]
    ) {
        self.resourcePath = resourcePath
        self.command = command
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.producedFiles = producedFiles
        self.parsedOutputPath = parsedOutputPath
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryResourceDiagnostic: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let archivePath: String?
    public let extractedFilePath: String?
    public let exists: Bool
    public let size: Int?
    public let first32BytesHex: String
    public let detectedMagic: AddonProbeFactoryResourceMagic
    public let parseStatus: AddonProbeFactoryParseStatus
    public let warnings: [String]

    public init(
        resourcePath: String,
        archivePath: String?,
        extractedFilePath: String?,
        exists: Bool,
        size: Int?,
        first32BytesHex: String,
        detectedMagic: AddonProbeFactoryResourceMagic,
        parseStatus: AddonProbeFactoryParseStatus,
        warnings: [String]
    ) {
        self.resourcePath = resourcePath
        self.archivePath = archivePath
        self.extractedFilePath = extractedFilePath
        self.exists = exists
        self.size = size
        self.first32BytesHex = first32BytesHex
        self.detectedMagic = detectedMagic
        self.parseStatus = parseStatus
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryCellDetection: Codable, Equatable, Sendable {
    public let rowIndex: Int
    public let column: String
    public let value: String
    public let matches: [String]

    public init(rowIndex: Int, column: String, value: String, matches: [String]) {
        self.rowIndex = rowIndex
        self.column = column
        self.value = value
        self.matches = matches
    }
}

public struct AddonProbeFactorySemanticDetection: Codable, Equatable, Sendable {
    public let rowIndex: Int
    public let column: String
    public let value: String
    public let kinds: [String]

    public init(rowIndex: Int, column: String, value: String, kinds: [String]) {
        self.rowIndex = rowIndex
        self.column = column
        self.value = value
        self.kinds = kinds
    }
}

public struct AddonProbeFactoryKnownItemRow: Codable, Equatable, Sendable {
    public let itemID: String
    public let rowIndex: Int
    public let row: [String: String]

    public init(itemID: String, rowIndex: Int, row: [String: String]) {
        self.itemID = itemID
        self.rowIndex = rowIndex
        self.row = row
    }
}

public struct AddonProbeFactoryDecodedTextSummary: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let decodedPath: String
    public let itemIDs: [String]
    public let resourceReferences: [String]
    public let semanticTerms: [String]
    public let knownVanillaItemIDs: [String]
    public let warnings: [String]

    public init(
        resourcePath: String,
        decodedPath: String,
        itemIDs: [String],
        resourceReferences: [String],
        semanticTerms: [String],
        knownVanillaItemIDs: [String],
        warnings: [String]
    ) {
        self.resourcePath = resourcePath
        self.decodedPath = decodedPath
        self.itemIDs = itemIDs
        self.resourceReferences = resourceReferences
        self.semanticTerms = semanticTerms
        self.knownVanillaItemIDs = knownVanillaItemIDs
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryCSVSummary: Codable, Equatable, Sendable {
    public let resourcePath: String
    public let extractedPath: String?
    public let headers: [String]
    public let rowCount: Int
    public let itemIDDetections: [AddonProbeFactoryCellDetection]
    public let tweakDBDetections: [AddonProbeFactoryCellDetection]
    public let resourcePathDetections: [AddonProbeFactoryCellDetection]
    public let semanticDetections: [AddonProbeFactorySemanticDetection]
    public let knownVanillaItemRows: [AddonProbeFactoryKnownItemRow]
    public let representativeRows: [[String: String]]
    public let warnings: [String]

    public init(
        resourcePath: String,
        extractedPath: String?,
        headers: [String],
        rowCount: Int,
        itemIDDetections: [AddonProbeFactoryCellDetection],
        tweakDBDetections: [AddonProbeFactoryCellDetection],
        resourcePathDetections: [AddonProbeFactoryCellDetection],
        semanticDetections: [AddonProbeFactorySemanticDetection],
        knownVanillaItemRows: [AddonProbeFactoryKnownItemRow],
        representativeRows: [[String: String]],
        warnings: [String]
    ) {
        self.resourcePath = resourcePath
        self.extractedPath = extractedPath
        self.headers = headers
        self.rowCount = rowCount
        self.itemIDDetections = itemIDDetections
        self.tweakDBDetections = tweakDBDetections
        self.resourcePathDetections = resourcePathDetections
        self.semanticDetections = semanticDetections
        self.knownVanillaItemRows = knownVanillaItemRows
        self.representativeRows = representativeRows
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryCrossReference: Codable, Equatable, Sendable {
    public let relationship: String
    public let fromCSV: String
    public let toCSV: String
    public let token: String
    public let fromRows: [Int]

    public init(relationship: String, fromCSV: String, toCSV: String, token: String, fromRows: [Int]) {
        self.relationship = relationship
        self.fromCSV = fromCSV
        self.toCSV = toCSV
        self.token = token
        self.fromRows = fromRows
    }
}

public struct AddonProbeFactoryLayerReport: Codable, Equatable, Sendable {
    public let searchedTerms: [String]
    public let exactResourceTerms: [String]
    public let broadSearchTerms: [String]
    public let indexDatabasePath: String
    public let indexDatabaseExists: Bool
    public let indexSearches: [AddonProbeFactoryIndexSearchReport]
    public let matchingArchiveResources: [ArchiveCatalogIndexSearchMatch]
    public let extractionArchivePath: String?
    public let extractedFiles: [AddonProbeFactoryExtractedFile]
    public let resourceDiagnostics: [AddonProbeFactoryResourceDiagnostic]
    public let decodeAttempts: [AddonProbeFactoryDecodeAttempt]
    public let decodedTextSummaries: [AddonProbeFactoryDecodedTextSummary]
    public let csvSummaries: [AddonProbeFactoryCSVSummary]
    public let crossCSVReferences: [AddonProbeFactoryCrossReference]
    public let warnings: [String]
    public let conclusion: AddonProbeFactoryLayerConclusion
    public let writtenReportPath: String?

    public init(
        searchedTerms: [String],
        exactResourceTerms: [String],
        broadSearchTerms: [String],
        indexDatabasePath: String,
        indexDatabaseExists: Bool,
        indexSearches: [AddonProbeFactoryIndexSearchReport],
        matchingArchiveResources: [ArchiveCatalogIndexSearchMatch],
        extractionArchivePath: String?,
        extractedFiles: [AddonProbeFactoryExtractedFile],
        resourceDiagnostics: [AddonProbeFactoryResourceDiagnostic] = [],
        decodeAttempts: [AddonProbeFactoryDecodeAttempt] = [],
        decodedTextSummaries: [AddonProbeFactoryDecodedTextSummary] = [],
        csvSummaries: [AddonProbeFactoryCSVSummary],
        crossCSVReferences: [AddonProbeFactoryCrossReference],
        warnings: [String],
        conclusion: AddonProbeFactoryLayerConclusion,
        writtenReportPath: String?
    ) {
        self.searchedTerms = searchedTerms
        self.exactResourceTerms = exactResourceTerms
        self.broadSearchTerms = broadSearchTerms
        self.indexDatabasePath = indexDatabasePath
        self.indexDatabaseExists = indexDatabaseExists
        self.indexSearches = indexSearches
        self.matchingArchiveResources = matchingArchiveResources
        self.extractionArchivePath = extractionArchivePath
        self.extractedFiles = extractedFiles
        self.resourceDiagnostics = resourceDiagnostics
        self.decodeAttempts = decodeAttempts
        self.decodedTextSummaries = decodedTextSummaries
        self.csvSummaries = csvSummaries
        self.crossCSVReferences = crossCSVReferences
        self.warnings = warnings
        self.conclusion = conclusion
        self.writtenReportPath = writtenReportPath
    }
}

public enum AddonProbeFactoryJSONRole: String, Codable, Equatable, Sendable {
    case topLevelFactoryRegistry
    case clothingEquipmentEntityTemplateFactoryMapping
    case clothingAppearanceResourceMapping
    case genericItemFactoryMapping
    case unknown
}

public struct AddonProbeFactoryJSONAnalysisRequest: Sendable {
    public let decodedJSONRootURL: URL

    public init(decodedJSONRootURL: URL) {
        self.decodedJSONRootURL = decodedJSONRootURL
    }
}

public struct AddonProbeFactoryJSONMatch: Codable, Equatable, Sendable {
    public let term: String
    public let jsonPath: String
    public let value: String
    public let normalizedValue: String?
    public let matchedIn: [String]

    public init(term: String, jsonPath: String, value: String, normalizedValue: String?, matchedIn: [String]) {
        self.term = term
        self.jsonPath = jsonPath
        self.value = value
        self.normalizedValue = normalizedValue
        self.matchedIn = matchedIn
    }
}

public struct AddonProbeFactoryJSONFileReport: Codable, Equatable, Sendable {
    public let fileName: String
    public let decodedJSONPath: String
    public let relativePath: String
    public let topLevelType: String
    public let topLevelKeys: [String]
    public let stringValueCount: Int
    public let counts: [String: Int]
    public let representativeMatches: [String: [AddonProbeFactoryJSONMatch]]
    public let inferredRole: AddonProbeFactoryJSONRole
    public let warnings: [String]

    public init(
        fileName: String,
        decodedJSONPath: String,
        relativePath: String,
        topLevelType: String,
        topLevelKeys: [String],
        stringValueCount: Int,
        counts: [String: Int],
        representativeMatches: [String: [AddonProbeFactoryJSONMatch]],
        inferredRole: AddonProbeFactoryJSONRole,
        warnings: [String]
    ) {
        self.fileName = fileName
        self.decodedJSONPath = decodedJSONPath
        self.relativePath = relativePath
        self.topLevelType = topLevelType
        self.topLevelKeys = topLevelKeys
        self.stringValueCount = stringValueCount
        self.counts = counts
        self.representativeMatches = representativeMatches
        self.inferredRole = inferredRole
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryJSONAnalysisReport: Codable, Equatable, Sendable {
    public let inputRoot: String
    public let discoveredFiles: [String]
    public let files: [AddonProbeFactoryJSONFileReport]
    public let warnings: [String]

    public init(
        inputRoot: String,
        discoveredFiles: [String],
        files: [AddonProbeFactoryJSONFileReport],
        warnings: [String]
    ) {
        self.inputRoot = inputRoot
        self.discoveredFiles = discoveredFiles
        self.files = files
        self.warnings = warnings
    }
}

public enum AddonProbeFactoryRoundtripConclusion: String, Codable, Equatable, Sendable {
    case decodedOnly_reserializeUnsupported
    case roundtripExact
    case roundtripDifferentButCR2W
    case roundtripFailed
    case stagedNoopArchiveProduced
    case unresolved
}

public struct AddonProbeFactoryRoundtripRequest: Sendable {
    public let resourcePath: String
    public let archivePath: String
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall

    public init(
        resourcePath: String,
        archivePath: String,
        outputDirectoryURL: URL,
        cp77toolsURL: URL,
        gameInstall: GameInstall
    ) {
        self.resourcePath = resourcePath
        self.archivePath = archivePath
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
    }
}

public struct AddonProbeFactoryRoundtripCommandAttempt: Codable, Equatable, Sendable {
    public let command: String
    public let arguments: [String]
    public let exitCode: Int32?
    public let stdout: String
    public let stderr: String
    public let warnings: [String]

    public init(command: String, arguments: [String], exitCode: Int32?, stdout: String, stderr: String, warnings: [String]) {
        self.command = command
        self.arguments = arguments
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryRoundtripManifest: Codable, Equatable, Sendable {
    public let inputArchive: String
    public let resourcePath: String
    public let extractedResourcePath: String?
    public let decodedJSONPath: String?
    public let reserializedCR2WPath: String?
    public let originalSHA256: String?
    public let rebuiltSHA256: String?
    public let originalSize: UInt64?
    public let rebuiltSize: UInt64?
    public let originalFirst32: String?
    public let rebuiltFirst32: String?
    public let originalMagic: String?
    public let rebuiltMagic: String?
    public let cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt]
    public let stagedArchivePath: String?
    public let stagedArchiveSHA256: String?
    public let manifestPath: String
    public let manualInstallCommand: String?
    public let conclusion: AddonProbeFactoryRoundtripConclusion
    public let warnings: [String]

    public init(
        inputArchive: String,
        resourcePath: String,
        extractedResourcePath: String?,
        decodedJSONPath: String?,
        reserializedCR2WPath: String?,
        originalSHA256: String?,
        rebuiltSHA256: String?,
        originalSize: UInt64?,
        rebuiltSize: UInt64?,
        originalFirst32: String?,
        rebuiltFirst32: String?,
        originalMagic: String?,
        rebuiltMagic: String?,
        cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt],
        stagedArchivePath: String?,
        stagedArchiveSHA256: String?,
        manifestPath: String,
        manualInstallCommand: String?,
        conclusion: AddonProbeFactoryRoundtripConclusion,
        warnings: [String]
    ) {
        self.inputArchive = inputArchive
        self.resourcePath = resourcePath
        self.extractedResourcePath = extractedResourcePath
        self.decodedJSONPath = decodedJSONPath
        self.reserializedCR2WPath = reserializedCR2WPath
        self.originalSHA256 = originalSHA256
        self.rebuiltSHA256 = rebuiltSHA256
        self.originalSize = originalSize
        self.rebuiltSize = rebuiltSize
        self.originalFirst32 = originalFirst32
        self.rebuiltFirst32 = rebuiltFirst32
        self.originalMagic = originalMagic
        self.rebuiltMagic = rebuiltMagic
        self.cp77toolsCommandsAttempted = cp77toolsCommandsAttempted
        self.stagedArchivePath = stagedArchivePath
        self.stagedArchiveSHA256 = stagedArchiveSHA256
        self.manifestPath = manifestPath
        self.manualInstallCommand = manualInstallCommand
        self.conclusion = conclusion
        self.warnings = warnings
    }
}

public enum AddonProbeFactoryRowCloneConclusion: String, Codable, Equatable, CaseIterable, Sendable {
    case stagedCloneArchiveProduced
    case sourceKeyNotFound
    case newKeyAlreadyPresent
    case deserializeFailed
    case packFailed
    case unresolved
}

public struct AddonProbeFactoryRowCloneRequest: Sendable {
    public let resourcePath: String
    public let sourceKey: String
    public let newKey: String
    public let archivePath: String
    public let outputDirectoryURL: URL
    public let cp77toolsURL: URL
    public let gameInstall: GameInstall

    public init(
        resourcePath: String,
        sourceKey: String,
        newKey: String,
        archivePath: String,
        outputDirectoryURL: URL,
        cp77toolsURL: URL,
        gameInstall: GameInstall
    ) {
        self.resourcePath = resourcePath
        self.sourceKey = sourceKey
        self.newKey = newKey
        self.archivePath = archivePath
        self.outputDirectoryURL = outputDirectoryURL
        self.cp77toolsURL = cp77toolsURL
        self.gameInstall = gameInstall
    }
}

public struct AddonProbeFactoryRowCloneEditResult: Equatable, Sendable {
    public let sourceRowsFound: Int
    public let sourceRowPath: String?
    public let rowsAddedCompiledData: Int
    public let rowsAddedData: Int
    public let editedJSONData: Data?
    public let conclusion: AddonProbeFactoryRowCloneConclusion
    public let warnings: [String]

    public init(
        sourceRowsFound: Int,
        sourceRowPath: String?,
        rowsAddedCompiledData: Int,
        rowsAddedData: Int,
        editedJSONData: Data?,
        conclusion: AddonProbeFactoryRowCloneConclusion,
        warnings: [String]
    ) {
        self.sourceRowsFound = sourceRowsFound
        self.sourceRowPath = sourceRowPath
        self.rowsAddedCompiledData = rowsAddedCompiledData
        self.rowsAddedData = rowsAddedData
        self.editedJSONData = editedJSONData
        self.conclusion = conclusion
        self.warnings = warnings
    }
}

public struct AddonProbeFactoryRowCloneManifest: Codable, Equatable, Sendable {
    public let archive: String
    public let resource: String
    public let sourceKey: String
    public let newKey: String
    public let sourceRowsFound: Int
    public let sourceRowPath: String?
    public let rowsAddedCompiledData: Int
    public let rowsAddedData: Int
    public let decodedOriginalJson: String?
    public let decodedEditedJson: String?
    public let rebuiltResource: String?
    public let stagedArchive: String?
    public let originalResourceSHA256: String?
    public let editedResourceSHA256: String?
    public let stagedArchiveSHA256: String?
    public let originalResourceSize: UInt64?
    public let editedResourceSize: UInt64?
    public let cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt]
    public let conclusion: AddonProbeFactoryRowCloneConclusion
    public let warnings: [String]
    public let manifestPath: String
    public let manualInstallCommand: String?

    public init(
        archive: String,
        resource: String,
        sourceKey: String,
        newKey: String,
        sourceRowsFound: Int,
        sourceRowPath: String?,
        rowsAddedCompiledData: Int,
        rowsAddedData: Int,
        decodedOriginalJson: String?,
        decodedEditedJson: String?,
        rebuiltResource: String?,
        stagedArchive: String?,
        originalResourceSHA256: String?,
        editedResourceSHA256: String?,
        stagedArchiveSHA256: String?,
        originalResourceSize: UInt64?,
        editedResourceSize: UInt64?,
        cp77toolsCommandsAttempted: [AddonProbeFactoryRoundtripCommandAttempt],
        conclusion: AddonProbeFactoryRowCloneConclusion,
        warnings: [String],
        manifestPath: String,
        manualInstallCommand: String?
    ) {
        self.archive = archive
        self.resource = resource
        self.sourceKey = sourceKey
        self.newKey = newKey
        self.sourceRowsFound = sourceRowsFound
        self.sourceRowPath = sourceRowPath
        self.rowsAddedCompiledData = rowsAddedCompiledData
        self.rowsAddedData = rowsAddedData
        self.decodedOriginalJson = decodedOriginalJson
        self.decodedEditedJson = decodedEditedJson
        self.rebuiltResource = rebuiltResource
        self.stagedArchive = stagedArchive
        self.originalResourceSHA256 = originalResourceSHA256
        self.editedResourceSHA256 = editedResourceSHA256
        self.stagedArchiveSHA256 = stagedArchiveSHA256
        self.originalResourceSize = originalResourceSize
        self.editedResourceSize = editedResourceSize
        self.cp77toolsCommandsAttempted = cp77toolsCommandsAttempted
        self.conclusion = conclusion
        self.warnings = warnings
        self.manifestPath = manifestPath
        self.manualInstallCommand = manualInstallCommand
    }
}

public struct AddonProbeManager: Sendable {
    public static let defaultGrantModName = "CyberMacAddonProbeGrant"
    public static let factoryLayerArchiveRelativePath = "Data/archive/Mac/content/basegame_4_gamedata.archive"
    public static let requiredFactoryCSVResources = [
        "base/gameplay/factories.csv",
        "base/gameplay/factories/items/items.csv",
        "base/gameplay/factories/items/clothing.csv",
        "base/gameplay/factories/items/clothing_appearances.csv"
    ]
    public static let optionalFactoryCSVResources = [
        "base/gameplay/factories/items/accessories.csv",
        "base/gameplay/factories/items/quest_drops.csv",
        "base/gameplay/factories/items/weapons/weapons.csv",
        "base/gameplay/factories/items/weapons/weapons_appearances.csv"
    ]
    public static let factoryLayerBroadSearchTerms = [
        "base/gameplay/factories/items",
        "clothing.csv",
        "clothing_appearances.csv",
        "factories.csv",
        "Items.",
        ".ent",
        ".app",
        ".mesh"
    ]
    public static let knownVanillaClothingItemIDs = [
        "Items.Vest_08_basic_01",
        "Items.Shirt_01_basic_01",
        "Items.TShirt_04_old_01",
        "Items.FormalSkirt_01_basic_02",
        "Items.Pants_10_rich_01"
    ]
    public static let decodedFactoryJSONFileNames = [
        "factories.csv.json",
        "items.csv.json",
        "clothing.csv.json",
        "clothing_appearances.csv.json",
        "accessories.csv.json",
        "quest_drops.csv.json",
        "weapons.csv.json",
        "weapons_appearances.csv.json"
    ]
    public static let factoryJSONAnalysisTerms = [
        "Items.",
        ".ent",
        ".app",
        ".mesh",
        ".mlsetup",
        ".mlmask",
        ".xbm",
        "player_outer_torso_item",
        "player_inner_torso_item",
        "player_legs_item",
        "player_feet_item",
        "player_torso_item_appearances",
        "appearance",
        "factory",
        "clothing",
        "equipment",
        "garment"
    ]
    public static let recordLayerProbeSearchTerms = [
        "Items.GenericInnerChestClothing",
        "Items.Skirt",
        "GenericInnerChestClothing",
        "OutfitSlots.TorsoInner",
        "OutfitSlots.LegsOuter",
        "Quality.Legendary",
        "IconicItem",
        "ScaleToPlayerLevel",
        "TweakDB",
        "tweakdb",
        "gamedata",
        "static_data",
        "database",
        "records",
        "itemRecords",
        ".tweak",
        ".tdb",
        ".json",
        ".csv"
    ]
    public static let baseRecordProbeIDs = [
        "Items.GenericInnerChestClothing",
        "Items.Skirt"
    ]

    private struct ResolvedModRoot {
        let sourceURL: URL
        let rootURL: URL
        let inputKind: AddonProbeInputKind
        let warnings: [String]
    }

    private struct ExtractedAsset {
        let assetPath: String
        let url: URL
        let sha256: String
    }

    private struct FactoryJSONStringValue {
        let path: String
        let value: String
    }

    private struct FactoryFileFacts {
        let sha256: String
        let size: UInt64
        let first32: String
        let magic: String
    }

    private struct FactoryReverseSerializationPlan {
        let arguments: [String]
    }

    private struct TweakXLRecordTemplate {
        let key: String
        var baseRecord: String?
        var placementSlots: [String] = []
        var appearanceName: String?
        var entityName: String?
        var displayName: String?
        var localizedDescription: String?
        var iconAtlasPath: String?
        var iconAtlasPart: String?
        var quality: String?
        var statModifiers: [String] = []
        var instances: [[String: String]] = []
        var unresolvedTemplateExpressions: [String] = []
    }

    private struct Discovery {
        let root: ResolvedModRoot
        let archiveFiles: [String]
        let xlFiles: [String]
        let tweakFiles: [String]
        let csvFiles: [String]
        let jsonFiles: [String]
        let candidateItemIDs: [String]
        let referencedItemIDs: [String]
        let candidateBaseRecords: [String]
        let candidateResourceReferences: [String]
        let tweakXLAnalysis: AddonProbeTweakXLAnalysis
        let xlMetadataAnalysis: AddonProbeXLMetadataAnalysis
        let classification: AddonProbeClassification
        let reasons: [String]
        let warnings: [String]
    }

    private let home: CyberMacHomeManager
    private let tooling: any OfficialArchiveSwapTooling
    private let dateProvider: @Sendable () -> Date
    private let idProvider: @Sendable () -> String

    public init(
        home: CyberMacHomeManager,
        tooling: any OfficialArchiveSwapTooling = CP77ToolsArchiveSwapTooling(),
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        idProvider: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.home = home
        self.tooling = tooling
        self.dateProvider = dateProvider
        self.idProvider = idProvider
    }

    public func inspect(request: AddonProbeInspectRequest) throws -> AddonProbeInspectReport {
        try home.bootstrap()
        let root = try resolveModRoot(request.modURL)
        let discovery = try discover(root: root)
        let provisional = makeInspectReport(discovery: discovery, writtenReportPath: nil)

        guard let outputDirectoryURL = request.outputDirectoryURL?.standardizedFileURL else {
            return provisional
        }
        try validateOutputDirectory(outputDirectoryURL, description: "Inspect output directory")
        let reportURL = outputDirectoryURL.appendingPathComponent("addon-probe-inspect.json")
        try JSONEncoder.cybermac.encode(provisional).write(to: reportURL, options: [.atomic])
        return makeInspectReport(discovery: discovery, writtenReportPath: reportURL.path)
    }

    public func stageAssets(request: AddonProbeStageAssetsRequest) throws -> AddonProbeStageManifest {
        try home.bootstrap()
        let targetArchive = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(request.targetArchiveRelativePath)
        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "Stage output directory")
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")

        let profile = try OutfitRegistryManager(home: home).loadProfile(id: request.profileID)
        guard profile.targetArchiveRelativePath == targetArchive else {
            throw CyberMacError.invalidInput("Outfit profile \(profile.id) targets \(profile.targetArchiveRelativePath), not \(targetArchive). Use the matching profile or create one with `cybermac outfit profile create --id \(profile.id) --name <name> --target-archive \(targetArchive) --backup-id <official-backup-id>`.")
        }

        let backupManager = OfficialArchiveBackupManager(home: home)
        let backup = try backupManager.load(backupID: profile.pristineBackupId)
        guard backup.relativeArchivePath == targetArchive else {
            throw CyberMacError.invalidInput("Outfit profile \(profile.id) backup \(backup.backupID) belongs to \(backup.relativeArchivePath), not \(targetArchive).")
        }
        let pristineArchiveURL = try backupManager.backupFileURL(backupID: backup.backupID)

        let root = try resolveModRoot(request.modURL)
        let discovery = try discover(root: root)
        guard !discovery.archiveFiles.isEmpty else {
            throw CyberMacError.invalidInput("addon-probe stage-assets requires at least one discovered .archive file in the mod.")
        }

        let stageRootURL = outputRootURL.appendingPathComponent("addon-probe-\(stageID())", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageRootURL.path) else {
            throw CyberMacError.invalidInput("Stage output already exists: \(stageRootURL.path)")
        }
        let officialDirectory = stageRootURL.appendingPathComponent("official", isDirectory: true)
        let sourceDirectory = stageRootURL.appendingPathComponent("sources", isDirectory: true)
        let packedDirectory = stageRootURL.appendingPathComponent("packed", isDirectory: true)
        let patchedDirectory = stageRootURL.appendingPathComponent("patched", isDirectory: true)
        for directory in [officialDirectory, sourceDirectory, packedDirectory, patchedDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try tooling.extractArchive(
            cp77toolsURL: cp77toolsURL,
            sourceArchiveURL: pristineArchiveURL,
            outputDirectoryURL: officialDirectory
        )
        let officialAssets = try collectExtractedAssets(under: officialDirectory, description: "Pristine target archive extraction")

        var warnings = discovery.warnings
        var assetsByPath: [String: ExtractedAsset] = [:]
        for (index, relativeArchivePath) in discovery.archiveFiles.enumerated() {
            let archiveURL = try resolvedFileURL(relativePath: relativeArchivePath, rootURL: discovery.root.rootURL, description: "Discovered mod archive")
            let extractionURL = sourceDirectory.appendingPathComponent("archive-\(index)", isDirectory: true)
            try tooling.extractArchive(
                cp77toolsURL: cp77toolsURL,
                sourceArchiveURL: archiveURL,
                outputDirectoryURL: extractionURL
            )
            let extracted = try collectExtractedAssets(under: extractionURL, description: "Mod archive extraction")
            for asset in extracted.values {
                if let existing = assetsByPath[asset.assetPath] {
                    if existing.sha256 == asset.sha256 {
                        warnings.append("Duplicate mod asset path with identical bytes was deduped: \(asset.assetPath)")
                        continue
                    }
                    throw CyberMacError.invalidInput("Multiple mod archives contain different bytes for the same asset path: \(asset.assetPath)")
                }
                assetsByPath[asset.assetPath] = asset
            }
        }

        let extractedAssetPaths = assetsByPath.keys.sorted()
        guard !extractedAssetPaths.isEmpty else {
            throw CyberMacError.invalidInput("Discovered .archive files extracted no regular asset files.")
        }
        let exactMatchAssets = extractedAssetPaths.filter { officialAssets[$0] != nil }
        let addedCustomAssets = extractedAssetPaths.filter { officialAssets[$0] == nil }

        for assetPath in extractedAssetPaths {
            guard let asset = assetsByPath[assetPath] else { continue }
            let destinationURL = try assetURL(assetPath: assetPath, rootURL: officialDirectory, label: "Addon probe staged asset")
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: asset.url, to: destinationURL)
        }

        let targetFileName = URL(fileURLWithPath: targetArchive).lastPathComponent
        let requestedPackedURL = packedDirectory.appendingPathComponent(targetFileName)
        try tooling.packArchive(
            cp77toolsURL: cp77toolsURL,
            extractedDirectoryURL: officialDirectory,
            outputArchiveURL: requestedPackedURL
        )
        let generatedArchiveURL = try singleGeneratedArchive(in: packedDirectory)
        let stagedArchiveURL = patchedDirectory.appendingPathComponent(targetFileName)
        guard !FileManager.default.fileExists(atPath: stagedArchiveURL.path) else {
            throw CyberMacError.invalidInput("Staged archive already exists: \(stagedArchiveURL.path)")
        }
        try FileManager.default.copyItem(at: generatedArchiveURL, to: stagedArchiveURL)
        let stagedSHA = try PathSafety.sha256(url: stagedArchiveURL)

        let destinationArchiveURL = try gameArchiveURL(relativeArchivePath: targetArchive, gameInstall: request.gameInstall)
        let manualInstallCommand = "sudo cp \(PathSafety.shellQuoted(stagedArchiveURL.path)) \(PathSafety.shellQuoted(destinationArchiveURL.path))"

        var officialIndexMatches: [AddonProbeOfficialIndexMatch] = []
        if let databaseURL = request.databaseURL?.standardizedFileURL ?? existingDefaultDatabaseURL() {
            do {
                let matches = try ArchiveCatalogIndexStore().findExactAssetPathMatches(
                    databaseURL: databaseURL,
                    assetPaths: extractedAssetPaths
                )
                officialIndexMatches = matches
                    .map { AddonProbeOfficialIndexMatch(assetPath: $0.key, officialArchives: $0.value) }
                    .sorted { $0.assetPath < $1.assetPath }
            } catch {
                warnings.append("Archive catalog advisory lookup failed: \(error)")
            }
        } else {
            warnings.append("Archive catalog index database was not found; official-index advisory matches were skipped.")
        }

        warnings.append("Path B probe only stages asset files into an official Mac archive. It does not register TweakDB records, factories, localization, or ArchiveXL/TweakXL runtime behavior.")
        warnings.append("Do not install automatically. Review the manifest and run the printed sudo cp command manually only for an intentional game test.")

        let manifestURL = stageRootURL.appendingPathComponent("addon-probe-manifest.json")
        let manifest = AddonProbeStageManifest(
            modPath: discovery.root.sourceURL.path,
            targetArchiveRelativePath: targetArchive,
            profileID: profile.id,
            discoveredArchives: discovery.archiveFiles,
            discoveredXLFiles: discovery.xlFiles,
            discoveredYAMLFiles: discovery.tweakFiles,
            discoveredCSVFiles: discovery.csvFiles,
            discoveredJSONFiles: discovery.jsonFiles,
            extractedAssetPaths: extractedAssetPaths,
            exactMatchAssets: exactMatchAssets,
            addedCustomAssets: addedCustomAssets,
            candidateItemIDs: discovery.candidateItemIDs,
            candidateResourceReferences: discovery.candidateResourceReferences,
            officialIndexMatches: officialIndexMatches,
            stagedArchivePath: stagedArchiveURL.path,
            stagedSHA256: stagedSHA,
            manifestPath: manifestURL.path,
            manualInstallCommand: manualInstallCommand,
            warnings: warnings.sorted()
        )
        try JSONEncoder.cybermac.encode(manifest).write(to: manifestURL, options: [.atomic])
        return manifest
    }

    public func grantTestMany(request: AddonProbeGrantManyRequest) throws -> AddonProbeGrantManyResult {
        try home.bootstrap()
        let inputURL = request.inputURL.standardizedFileURL
        try validateLocalURL(inputURL, description: "grant-test-many input")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("grant-test-many input does not exist: \(inputURL.path)")
        }

        var warnings = [
            "Generated grant helper is experimental. If TweakDB records are not registered, grants may do nothing."
        ]
        let itemIDs: [String]
        if isDirectory.boolValue || inputURL.pathExtension.lowercased() == "zip" {
            let root = try resolveModRoot(inputURL)
            let discovery = try discover(root: root)
            warnings.append(contentsOf: discovery.warnings)
            var values = discovery.candidateItemIDs
            let files = try regularFiles(under: discovery.root.rootURL, description: "grant-test-many mod input")
            for file in files where file.relativePath.lowercased().hasSuffix(".txt") {
                guard let text = try readSmallTextFile(file.url) else { continue }
                values.append(contentsOf: Self.parseGrantManyItemIDs(text))
            }
            itemIDs = Self.orderedUnique(values)
        } else {
            try validateRegularFile(inputURL, description: "grant-test-many input file")
            guard let text = try readSmallTextFile(inputURL) else {
                throw CyberMacError.invalidInput("grant-test-many input file is too large or not UTF-8 text: \(inputURL.path)")
            }
            itemIDs = Self.parseGrantManyItemIDs(text)
        }

        guard !itemIDs.isEmpty else {
            throw CyberMacError.invalidInput("No item IDs were found for grant-test-many input: \(inputURL.path)")
        }

        let result = try RedscriptItemGrantGenerator().generate(request: RedscriptItemGrantRequest(
            itemIDs: itemIDs,
            outputZipURL: request.outputZipURL,
            modName: request.modName
        ))
        return AddonProbeGrantManyResult(
            inputPath: inputURL.path,
            outputZipPath: result.outputZipURL.path,
            modName: result.modName,
            redscriptEntryPath: result.redscriptEntryPath,
            itemIDs: result.normalizedItemIDs,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public func atomiicSummary(modURL: URL) throws -> AddonProbeAtomiicSummaryReport {
        let inspect = try inspect(request: AddonProbeInspectRequest(modURL: modURL))
        let lowerIDs = inspect.expandedItemIDs.map { $0.lowercased() }
        let shirtsCount = lowerIDs.filter { $0.contains("_shirt_") }.count
        let skirtsCount = lowerIDs.filter { $0.contains("_skirt_") }.count
        var warnings = inspect.warnings
        warnings.append("Atomiic summary is a Path B probe summary. It does not prove true add-on clothing support.")
        return AddonProbeAtomiicSummaryReport(
            modPath: inspect.sourceModPath,
            totalExpandedItems: inspect.expandedItemIDs.count,
            shirtsCount: shirtsCount,
            skirtsCount: skirtsCount,
            factoryCSVFilesFromXL: inspect.factoryCSVFilesFromXL,
            localizationJSONFilesFromXL: inspect.localizationJSONFilesFromXL,
            iconAtlasPaths: inspect.iconAtlasPaths,
            archiveFiles: inspect.archiveFiles,
            expectedUnresolvedLayers: [
                "TweakDB item records",
                "factory registration",
                "localization registration",
                "appearance/entity resource wiring"
            ],
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public func analyzeXLFactory(request: AddonProbeXLFactoryAnalysisRequest) throws -> AddonProbeXLFactoryAnalysisReport {
        try home.bootstrap()
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "XL factory analysis output directory")
        try validateOutsideGameBundle(outputRootURL, gameInstall: request.gameInstall, description: "XL factory analysis output directory")

        let resolvedRoot = try resolveModRoot(request.modURL)
        let discovery = try discover(root: resolvedRoot)
        let declaredFactories = Self.normalizedXLResourcePaths(discovery.xlMetadataAnalysis.factoryCSVFilesFromXL)
        let declaredLocalizations = Self.normalizedXLResourcePaths(discovery.xlMetadataAnalysis.localizationJSONFilesFromXL)
        let analysisRoot = outputRootURL.appendingPathComponent("xl-factory-analysis-\(stageID())", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: analysisRoot.path) else {
            throw CyberMacError.invalidInput("XL factory analysis work directory already exists: \(analysisRoot.path)")
        }
        let extractedRoot = analysisRoot.appendingPathComponent("extracted-mod-archives", isDirectory: true)
        let decodedRoot = analysisRoot.appendingPathComponent("decoded", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: decodedRoot, withIntermediateDirectories: true)
        let reportURL = analysisRoot.appendingPathComponent("addon-probe-xl-factory-analysis.json")

        var warnings = discovery.warnings
        warnings.append("XL factory analysis is a Path B probe. It does not register TweakDB records or prove true add-on clothing support.")
        if declaredFactories.isEmpty {
            warnings.append("No factory CSV paths were declared by discovered .xl files.")
        }
        if declaredLocalizations.isEmpty {
            warnings.append("No localization JSON paths were declared by discovered .xl files.")
        }

        var attempts: [AddonProbeFactoryRoundtripCommandAttempt] = []
        var extractedAssets: [String: ExtractedAsset] = [:]
        var assetArchivePaths: [String: String] = [:]
        for archivePath in discovery.archiveFiles {
            let archiveURL = try resolvedFileURL(relativePath: archivePath, rootURL: discovery.root.rootURL, description: "XL mod archive")
            let archiveExtractRoot = extractedRoot.appendingPathComponent(Self.safeFilename(archivePath), isDirectory: true)
            do {
                try recordRoundtripArchiveToolingCommand(
                    cp77toolsURL: cp77toolsURL,
                    arguments: CP77ToolsArchiveSwapTooling.extractArguments(
                        sourceArchiveURL: archiveURL,
                        outputDirectoryURL: archiveExtractRoot
                    ),
                    attempts: &attempts,
                    operation: "XL mod archive extraction"
                ) {
                    try tooling.extractArchive(
                        cp77toolsURL: cp77toolsURL,
                        sourceArchiveURL: archiveURL,
                        outputDirectoryURL: archiveExtractRoot
                    )
                }
                let assets = try collectExtractedAssets(under: archiveExtractRoot, description: "XL mod archive extraction")
                for (assetPath, asset) in assets {
                    if extractedAssets[assetPath] != nil {
                        warnings.append("Duplicate extracted XL asset path after normalization was skipped: \(assetPath)")
                        continue
                    }
                    extractedAssets[assetPath] = asset
                    assetArchivePaths[assetPath] = archivePath
                }
            } catch {
                warnings.append("Could not extract XL mod archive \(archivePath): \(error.localizedDescription)")
            }
        }

        var diagnostics: [AddonProbeXLResourceDiagnostic] = []
        var factorySummaries: [AddonProbeXLDecodedFactoryJSONSummary] = []
        var localizationSummaries: [AddonProbeXLLocalizationSummary] = []
        var decodedFactoryPaths: [String] = []
        var decodedLocalizationPaths: [String] = []
        var foundFactory = false
        var decodedFactory = false
        var factoryDecodeFailed = false
        var foundLocalization = false

        for resourcePath in declaredFactories {
            guard let asset = extractedAssets[resourcePath] else {
                diagnostics.append(Self.missingXLResourceDiagnostic(resourcePath: resourcePath, warning: "Declared XL factory CSV was not found in extracted mod archives."))
                continue
            }
            foundFactory = true
            let diagnostic = try Self.xlResourceDiagnostic(
                resourcePath: resourcePath,
                archivePath: assetArchivePaths[resourcePath],
                url: asset.url
            )
            diagnostics.append(diagnostic)
            guard diagnostic.detectedMagic == .cr2w else {
                warnings.append("Declared XL factory CSV is \(diagnostic.detectedMagic.rawValue), not CR2W; decode was skipped: \(resourcePath)")
                continue
            }
            let resourceDecodedRoot = decodedRoot
                .appendingPathComponent("factory-\(Self.safeFilename(resourcePath))", isDirectory: true)
            try FileManager.default.createDirectory(at: resourceDecodedRoot, withIntermediateDirectories: true)
            let decodeResult = runRoundtripCP77ToolsCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: ["convert", "serialize", asset.url.path, "--outpath", resourceDecodedRoot.path],
                timeout: 120,
                attempts: &attempts
            )
            guard decodeResult?.exitCode == 0 else {
                factoryDecodeFailed = true
                warnings.append("cp77tools convert serialize failed for declared XL factory CSV: \(resourcePath)")
                continue
            }
            var decodeWarnings: [String] = []
            guard let decodedJSONURL = try findDecodedFactoryJSON(for: resourcePath, under: resourceDecodedRoot, warnings: &decodeWarnings) else {
                factoryDecodeFailed = true
                warnings.append("cp77tools serialize produced no decoded JSON for declared XL factory CSV: \(resourcePath)")
                warnings.append(contentsOf: decodeWarnings)
                continue
            }
            decodedFactory = true
            decodedFactoryPaths.append(decodedJSONURL.path)
            var summary = try Self.summarizeXLDecodedFactoryJSON(resourcePath: resourcePath, decodedJSONURL: decodedJSONURL)
            summary = Self.addWarnings(decodeWarnings, to: summary)
            factorySummaries.append(summary)
        }

        for resourcePath in declaredLocalizations {
            guard let asset = extractedAssets[resourcePath] else {
                diagnostics.append(Self.missingXLResourceDiagnostic(resourcePath: resourcePath, warning: "Declared XL localization JSON was not found in extracted mod archives."))
                continue
            }
            foundLocalization = true
            let diagnostic = try Self.xlResourceDiagnostic(
                resourcePath: resourcePath,
                archivePath: assetArchivePaths[resourcePath],
                url: asset.url
            )
            diagnostics.append(diagnostic)
            switch diagnostic.detectedMagic {
            case .jsonText:
                localizationSummaries.append(try Self.summarizeXLLocalizationJSON(resourcePath: resourcePath, decodedPath: asset.url.path, data: Data(contentsOf: asset.url)))
                decodedLocalizationPaths.append(asset.url.path)
            case .cr2w:
                let resourceDecodedRoot = decodedRoot
                    .appendingPathComponent("localization-\(Self.safeFilename(resourcePath))", isDirectory: true)
                try FileManager.default.createDirectory(at: resourceDecodedRoot, withIntermediateDirectories: true)
                let decodeResult = runRoundtripCP77ToolsCommand(
                    cp77toolsURL: cp77toolsURL,
                    arguments: ["convert", "serialize", asset.url.path, "--outpath", resourceDecodedRoot.path],
                    timeout: 120,
                    attempts: &attempts
                )
                guard decodeResult?.exitCode == 0,
                      let decodedJSONURL = try findDecodedFactoryJSON(for: resourcePath, under: resourceDecodedRoot, warnings: &warnings)
                else {
                    warnings.append("Declared XL localization resource is CR2W, but decode did not produce JSON: \(resourcePath)")
                    continue
                }
                localizationSummaries.append(try Self.summarizeXLLocalizationJSON(resourcePath: resourcePath, decodedPath: decodedJSONURL.path, data: Data(contentsOf: decodedJSONURL)))
                decodedLocalizationPaths.append(decodedJSONURL.path)
            default:
                localizationSummaries.append(AddonProbeXLLocalizationSummary(
                    resourcePath: resourcePath,
                    decodedPath: asset.url.path,
                    localizationKeys: [],
                    stringValues: [],
                    warnings: ["Localization resource was not plain JSON or decoded CR2W JSON: \(diagnostic.detectedMagic.rawValue)"]
                ))
            }
        }

        let comparison = Self.compareXLDecodedStringsToYAML(
            discovery: discovery,
            factorySummaries: factorySummaries,
            localizationSummaries: localizationSummaries
        )
        let conclusion: AddonProbeXLFactoryAnalysisConclusion
        if decodedFactory {
            conclusion = .xlFactoryDecoded
        } else if foundFactory && factoryDecodeFailed {
            conclusion = .xlFactoryFoundButDecodeFailed
        } else if !declaredFactories.isEmpty && !foundFactory {
            conclusion = .xlFactoryMissing
        } else if foundLocalization {
            conclusion = .localizationFound
        } else if !declaredLocalizations.isEmpty {
            conclusion = .localizationMissing
        } else {
            conclusion = .unresolved
        }

        let report = AddonProbeXLFactoryAnalysisReport(
            modPath: discovery.root.sourceURL.path,
            archiveFiles: discovery.archiveFiles,
            xlFiles: discovery.xlFiles,
            declaredFactoryCSVs: declaredFactories,
            declaredLocalizationJSONs: declaredLocalizations,
            extractedResourceDiagnostics: diagnostics,
            decodedFactoryJSONPaths: decodedFactoryPaths,
            decodedLocalizationPaths: decodedLocalizationPaths,
            factoryJSONSummaries: factorySummaries,
            localizationSummaries: localizationSummaries,
            yamlComparison: comparison,
            cp77toolsCommandsAttempted: attempts,
            warnings: Array(Set(warnings)).sorted(),
            conclusion: conclusion,
            reportPath: reportURL.path
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func stageXLFactoryRegistry(request: AddonProbeXLFactoryRegistryStageRequest) throws -> AddonProbeXLFactoryRegistryStageManifest {
        try home.bootstrap()
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
        let sourceArchiveURL = try resolveFactoryRoundtripArchiveURL(
            archivePath: request.archivePath,
            gameInstall: request.gameInstall
        )
        try validateRegularFile(sourceArchiveURL, description: "XL factory registry source archive")
        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "XL factory registry output directory")
        try validateOutsideGameBundle(outputRootURL, gameInstall: request.gameInstall, description: "XL factory registry output directory")

        let resolvedRoot = try resolveModRoot(request.modURL)
        let discovery = try discover(root: resolvedRoot)
        let declaredFactories = Self.normalizedXLResourcePaths(discovery.xlMetadataAnalysis.factoryCSVFilesFromXL)
        let resourcePath = "base/gameplay/factories.csv"

        let stageRoot = outputRootURL.appendingPathComponent("xl-factory-registry-\(stageID())", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("XL factory registry work directory already exists: \(stageRoot.path)")
        }
        let extractedRoot = stageRoot.appendingPathComponent("extracted", isDirectory: true)
        let decodedRoot = stageRoot.appendingPathComponent("decoded", isDirectory: true)
        let baselineRoot = stageRoot.appendingPathComponent("baseline-reserialized", isDirectory: true)
        let reserializedRoot = stageRoot.appendingPathComponent("reserialized", isDirectory: true)
        let packedRoot = stageRoot.appendingPathComponent("packed", isDirectory: true)
        let stagedRoot = stageRoot.appendingPathComponent("staged", isDirectory: true)
        for directory in [extractedRoot, decodedRoot, baselineRoot, reserializedRoot, packedRoot, stagedRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let manifestURL = stageRoot.appendingPathComponent("addon-probe-xl-factory-registry.json")

        var attempts: [AddonProbeFactoryRoundtripCommandAttempt] = []
        var warnings = discovery.warnings
        warnings.append("XL factory registry staging simulates ArchiveXL factory registration only. It does not register TweakDB records or prove true add-on clothing support.")
        warnings.append("The game app is not mutated; any staged archive is written only under --out.")

        var inputs = XLFactoryRegistryManifestInputs(
            modPath: discovery.root.sourceURL.path,
            archive: sourceArchiveURL.path,
            resource: resourcePath,
            editResult: nil,
            rawEditResult: nil,
            decodedOriginalJson: nil,
            decodedEditedJson: nil,
            rebuiltResource: nil,
            stagedArchive: nil,
            originalFacts: nil,
            editedFacts: nil,
            stagedArchiveSHA256: nil,
            attempts: attempts,
            conclusion: .unresolved,
            warnings: warnings,
            manifestURL: manifestURL,
            manualInstallCommand: nil,
            baselineDeserializeStdout: nil,
            baselineDeserializeStderr: nil,
            deserializeStdout: nil,
            deserializeStderr: nil
        )

        guard !declaredFactories.isEmpty else {
            warnings.append("No XL factory CSV paths were declared by discovered .xl files.")
            inputs.warnings = warnings
            inputs.conclusion = .unresolved
            inputs.attempts = attempts
            return try writeXLFactoryRegistryManifest(inputs)
        }

        do {
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.extractArguments(
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                ),
                attempts: &attempts,
                operation: "XL factory registry archive extraction"
            ) {
                try tooling.extractArchive(
                    cp77toolsURL: cp77toolsURL,
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                )
            }
        } catch {
            warnings.append("Factory registry source archive extraction failed: \(error.localizedDescription)")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryDecodeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let extractedResourceURL: URL
        do {
            extractedResourceURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Extracted factories.csv")
            try validateRegularFile(extractedResourceURL, description: "Extracted factories.csv")
        } catch {
            warnings.append("Official factories.csv was not found after extraction: \(error.localizedDescription)")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryDecodeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }
        let originalFacts = try Self.factoryFileFacts(url: extractedResourceURL)
        inputs.originalFacts = originalFacts

        let decodeResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "serialize", extractedResourceURL.path, "--outpath", decodedRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        guard decodeResult?.exitCode == 0,
              let decodedJSONURL = try findDecodedFactoryJSON(for: resourcePath, under: decodedRoot, warnings: &warnings)
        else {
            warnings.append("cp77tools convert serialize failed or produced no decoded factories.csv JSON.")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryDecodeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }
        inputs.decodedOriginalJson = decodedJSONURL.path

        let baselineResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "deserialize", decodedJSONURL.path, "--outpath", baselineRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        inputs.baselineDeserializeStdout = baselineResult?.stdout
        inputs.baselineDeserializeStderr = baselineResult?.stderr
        guard baselineResult?.exitCode == 0 else {
            warnings.append("cp77tools convert deserialize on the unedited decoded JSON failed; raw-text patching is unsafe.")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .baselineDeserializeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let originalText: String
        do {
            originalText = try String(contentsOf: decodedJSONURL, encoding: .utf8)
        } catch {
            warnings.append("Decoded factories.csv JSON could not be read as UTF-8: \(error.localizedDescription)")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryEditFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let rawEditResult: AddonProbeFactoryRegistryRawEditResult
        do {
            rawEditResult = try Self.rawPatchFactoriesJSON(originalText: originalText, factoryPaths: declaredFactories)
        } catch {
            warnings.append("Could not raw-patch decoded factories.csv JSON: \(error.localizedDescription)")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryEditFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }
        warnings.append(contentsOf: rawEditResult.warnings)
        inputs.rawEditResult = rawEditResult

        if rawEditResult.conclusion == .factoryPathAlreadyPresent {
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryPathAlreadyPresent
            return try writeXLFactoryRegistryManifest(inputs)
        }
        guard rawEditResult.conclusion == .unresolved,
              let editedText = rawEditResult.editedJSONText
        else {
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .factoryRegistryEditFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let editedJSONURL = decodedJSONURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(decodedJSONURL.deletingPathExtension().lastPathComponent).cybermac-xl-registry.json")
        try Data(editedText.utf8).write(to: editedJSONURL, options: [.atomic])
        inputs.decodedEditedJson = editedJSONURL.path

        let deserializeResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "deserialize", editedJSONURL.path, "--outpath", reserializedRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        inputs.deserializeStdout = deserializeResult?.stdout
        inputs.deserializeStderr = deserializeResult?.stderr
        guard deserializeResult?.exitCode == 0,
              let rebuiltURL = try findReserializedCR2W(for: resourcePath, under: reserializedRoot, warnings: &warnings)
        else {
            warnings.append("cp77tools convert deserialize failed or produced no valid-looking CR2W factories.csv.")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .deserializeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }
        let editedFacts = try Self.factoryFileFacts(url: rebuiltURL)
        inputs.editedFacts = editedFacts
        inputs.rebuiltResource = rebuiltURL.path
        guard editedFacts.magic == AddonProbeFactoryResourceMagic.cr2w.rawValue else {
            warnings.append("Rebuilt factories.csv does not have a CR2W magic header: \(editedFacts.magic).")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .deserializeFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let stagedArchiveURL: URL
        let stagedArchiveSHA256: String
        do {
            let extractedTargetURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Edited staged factories.csv")
            try FileManager.default.removeItem(at: extractedTargetURL)
            try FileManager.default.copyItem(at: rebuiltURL, to: extractedTargetURL)
            let requestedPackedURL = packedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.packArguments(
                    extractedDirectoryURL: extractedRoot,
                    outputDirectoryURL: packedRoot
                ),
                attempts: &attempts,
                operation: "XL factory registry archive packing"
            ) {
                try tooling.packArchive(
                    cp77toolsURL: cp77toolsURL,
                    extractedDirectoryURL: extractedRoot,
                    outputArchiveURL: requestedPackedURL
                )
            }
            let generatedArchiveURL = try singleGeneratedArchive(in: packedRoot)
            stagedArchiveURL = stagedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            try FileManager.default.copyItem(at: generatedArchiveURL, to: stagedArchiveURL)
            stagedArchiveSHA256 = try PathSafety.sha256(url: stagedArchiveURL)
        } catch {
            warnings.append("Rebuilt factories.csv exists, but staging the archive failed: \(error.localizedDescription)")
            inputs.warnings = warnings
            inputs.attempts = attempts
            inputs.conclusion = .packFailed
            return try writeXLFactoryRegistryManifest(inputs)
        }

        let manualInstallCommand = "cp \(PathSafety.shellQuoted(stagedArchiveURL.path)) \(PathSafety.shellQuoted(sourceArchiveURL.path))"
        warnings.append("Manual install command is printed for review only and intentionally does not include sudo.")
        inputs.stagedArchive = stagedArchiveURL.path
        inputs.stagedArchiveSHA256 = stagedArchiveSHA256
        inputs.manualInstallCommand = manualInstallCommand
        inputs.warnings = warnings
        inputs.attempts = attempts
        inputs.conclusion = .stagedFactoryRegistryArchiveProduced
        return try writeXLFactoryRegistryManifest(inputs)
    }

    public func searchRecordLayer(databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL, limit: Int = 50) throws -> AddonProbeRecordLayerSearchReport {
        guard limit > 0 else {
            throw CyberMacError.invalidInput("addon-probe search-record-layer --limit must be greater than zero.")
        }
        let databaseURL = databaseURL.standardizedFileURL
        let commands = Self.recordLayerSearchCommands(databaseURL: databaseURL, limit: limit)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return AddonProbeRecordLayerSearchReport(
                databasePath: databaseURL.path,
                databaseExists: false,
                limit: limit,
                queryReports: [],
                commands: commands,
                likelyPatchableRecordLayerFound: false,
                status: "unresolved",
                warnings: ["Archive catalog index database was not found. Commands are printed for a future indexed catalog search."]
            )
        }

        let store = ArchiveCatalogIndexStore()
        var reports: [AddonProbeRecordLayerQueryReport] = []
        for query in AddonProbeRecordLayerSearchReport.queries {
            let report = try store.search(options: ArchiveCatalogIndexSearchOptions(
                query: query,
                databaseURL: databaseURL,
                limit: limit
            ))
            reports.append(AddonProbeRecordLayerQueryReport(
                query: query,
                command: Self.recordLayerSearchCommand(query: query, databaseURL: databaseURL, limit: limit),
                totalMatchCount: report.totalMatchCount,
                shownMatchCount: report.matches.count,
                matches: report.matches
            ))
        }

        let likelyPatchable = reports.flatMap(\.matches).contains { match in
            let ext = match.assetExtension.lowercased()
            let assetPath = match.assetPath.lowercased()
            return ext == "tweak" || ext == "tdb" || assetPath.hasSuffix(".tweak") || assetPath.hasSuffix(".tdb")
        }
        return AddonProbeRecordLayerSearchReport(
            databasePath: databaseURL.path,
            databaseExists: true,
            limit: limit,
            queryReports: reports,
            commands: commands,
            likelyPatchableRecordLayerFound: likelyPatchable,
            status: likelyPatchable ? "candidate-found" : "unresolved",
            warnings: likelyPatchable ? [
                "Candidate record-layer resources were found in the archive catalog, but CyberMac does not yet support patching them."
            ] : [
                "No likely patchable TweakDB/gamedata resource layer was confirmed. True add-on item registration remains unresolved."
            ]
        )
    }

    public func recordLayerProbe(request: AddonProbeRecordLayerProbeRequest) throws -> AddonProbeRecordLayerProbeReport {
        try runRecordLayerProbe(
            modURL: request.modURL,
            outputDirectoryURL: request.outputDirectoryURL,
            cp77toolsURL: request.cp77toolsURL,
            gameInstall: request.gameInstall,
            databaseURL: request.databaseURL,
            searchTerms: Self.recordLayerProbeSearchTerms,
            reportFileName: "addon-probe-record-layer-probe.json"
        )
    }

    public func recordRuntimeProbe(request: AddonProbeRecordRuntimeProbeRequest) throws -> AddonProbeRecordRuntimeProbeResult {
        try home.bootstrap()
        let root = try resolveModRoot(request.modURL)
        let discovery = try discover(root: root)
        let customRecordIDs = discovery.tweakXLAnalysis.expandedItemIDs
        guard !customRecordIDs.isEmpty else {
            throw CyberMacError.invalidInput("record-runtime-probe found no expanded custom Items.* records in TweakXL YAML.")
        }
        let generatorResult = try RedscriptRecordRuntimeProbeGenerator().generate(request: RedscriptRecordRuntimeProbeRequest(
            baseRecordIDs: Self.baseRecordProbeIDs,
            customRecordIDs: customRecordIDs,
            outputZipURL: request.outputZipURL,
            modName: request.modName
        ))
        var warnings = discovery.warnings
        warnings.append("Generated runtime probe is read-only: it queries TweakDB flats with default values and does not grant items.")
        warnings.append("The script uses CyberMac's existing LogChannel DEBUG pattern; inspect the same redscript/game log location used for other CyberMac redscript helpers after activation.")
        warnings.append("Compile smoke command: swift run cybermac activate --dry-run")
        warnings.append("This does not register custom records and does not prove true add-on clothing support.")
        return AddonProbeRecordRuntimeProbeResult(
            inputPath: root.sourceURL.path,
            outputZipPath: generatorResult.outputZipURL.path,
            modName: generatorResult.modName,
            redscriptEntryPath: generatorResult.redscriptEntryPath,
            baseRecordIDs: generatorResult.baseRecordIDs,
            customRecordIDs: generatorResult.customRecordIDs,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public func compareBaseRecords(request: AddonProbeCompareBaseRecordsRequest) throws -> AddonProbeCompareBaseRecordsReport {
        let terms = Self.baseRecordProbeIDs + ["GenericInnerChestClothing", "Skirt"]
        let layerReport = try runRecordLayerProbe(
            modURL: request.modURL,
            outputDirectoryURL: request.outputDirectoryURL,
            cp77toolsURL: request.cp77toolsURL,
            gameInstall: request.gameInstall,
            databaseURL: request.databaseURL,
            searchTerms: Self.orderedUnique(terms),
            reportFileName: "addon-probe-compare-base-records-layer.json"
        )

        var matchesByBaseRecord: [String: [AddonProbeRecordLayerTextMatch]] = [:]
        for baseRecord in Self.baseRecordProbeIDs {
            let suffix = baseRecord.replacingOccurrences(of: "Items.", with: "")
            matchesByBaseRecord[baseRecord] = layerReport.decodedTextMatches.filter { match in
                match.matchedString.localizedCaseInsensitiveContains(baseRecord) ||
                    match.matchedString.localizedCaseInsensitiveContains(suffix)
            }
        }
        let found = matchesByBaseRecord.values.contains { !$0.isEmpty }
        let conclusion: AddonProbeCompareBaseRecordsConclusion = found ? .decodedBaseRecordReferencesFound : .unresolved
        let summary = found
            ? "Decoded candidate resources contain base-record references. Review matches to determine whether they are definitions or incidental references."
            : "Base item records are likely not stored in currently indexed patchable archive resources."
        var warnings = layerReport.warnings
        if !found {
            warnings.append("No decoded resource exposed definitions or references for Items.GenericInnerChestClothing or Items.Skirt.")
        }
        warnings.append("compare-base-records is read-only and does not mutate the game app.")

        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        let reportURL = outputRootURL.appendingPathComponent("addon-probe-compare-base-records.json")
        let report = AddonProbeCompareBaseRecordsReport(
            modPath: layerReport.modPath,
            baseRecordIDs: Self.baseRecordProbeIDs,
            recordLayerReportPath: layerReport.reportPath,
            matchesByBaseRecord: matchesByBaseRecord,
            conclusion: conclusion,
            summary: summary,
            warnings: Array(Set(warnings)).sorted(),
            reportPath: reportURL.path
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    public func locateTweakDBStorage(request: AddonProbeTweakDBStorageLocatorRequest) throws -> AddonProbeTweakDBStorageLocatorReport {
        try TweakDBStorageLocator(home: home).locate(request: request)
    }

    public func redscriptTweakDBAPIScan(request: AddonProbeRedscriptTweakDBAPIScanRequest) throws -> AddonProbeRedscriptTweakDBAPIScanReport {
        try TweakDBStorageLocator(home: home).redscriptAPIScan(request: request)
    }

    public func inspectTweakDBBinary(request: AddonProbeTweakDBBinaryInspectRequest) throws -> AddonProbeTweakDBBinaryInspectReport {
        try TweakDBBinaryInspector().inspect(request: request)
    }

    public func compareTweakDBBinaries(request: AddonProbeTweakDBBinaryCompareRequest) throws -> AddonProbeTweakDBBinaryCompareReport {
        try TweakDBBinaryInspector().compare(request: request)
    }

    public func analyzeTweakDBPackedStrings(request: AddonProbeTweakDBPackedStringAnalysisRequest) throws -> AddonProbeTweakDBPackedStringAnalysisReport {
        try TweakDBPackedStringAnalyzer().analyze(request: request)
    }

    public func analyzeTweakDBReferenceTables(request: AddonProbeTweakDBReferenceTableAnalysisRequest) throws -> AddonProbeTweakDBReferenceTableAnalysisReport {
        try TweakDBReferenceTableAnalyzer().analyze(request: request)
    }

    public func analyzeTweakDBItemIndexes(request: AddonProbeTweakDBItemIndexAnalysisRequest) throws -> AddonProbeTweakDBItemIndexAnalysisReport {
        try TweakDBItemIndexAnalyzer().analyze(request: request)
    }

    public func inspectTweakDBStructure(request: AddonProbeTweakDBStructureInspectRequest) throws -> AddonProbeTweakDBStructureReport {
        try TweakDBStructureInspector().inspect(request: request)
    }

    public func traceTweakDBRecord(request: AddonProbeTweakDBRecordTraceRequest) throws -> AddonProbeTweakDBRecordTraceReport {
        try TweakDBStructureInspector().trace(request: request)
    }

    public func stageTweakDBCloneRecord(request: AddonProbeTweakDBCloneRecordRequest) throws -> AddonProbeTweakDBCloneRecordReport {
        try TweakDBCloneRecordStager().stage(request: request)
    }

    public func compareTweakDBPackedStringAnalyses(request: AddonProbeTweakDBPackedStringComparisonRequest) throws -> AddonProbeTweakDBPackedStringComparisonReport {
        try TweakDBPackedStringAnalyzer().compare(request: request)
    }

    public func inspectFactoryLayer(request: AddonProbeFactoryLayerRequest) throws -> AddonProbeFactoryLayerReport {
        try home.bootstrap()
        let databaseURL = request.databaseURL.standardizedFileURL
        let exactTerms = Self.requiredFactoryCSVResources + Self.optionalFactoryCSVResources
        let searchedTerms = exactTerms + Self.factoryLayerBroadSearchTerms
        var warnings: [String] = [
            "Factory-layer inspection is a conservative Path B probe. It does not prove true add-on clothing support."
        ]
        var indexSearches: [AddonProbeFactoryIndexSearchReport] = []
        var matchingArchiveResources: [ArchiveCatalogIndexSearchMatch] = []

        if FileManager.default.fileExists(atPath: databaseURL.path) {
            let store = ArchiveCatalogIndexStore()
            for term in exactTerms {
                let report = try store.search(options: ArchiveCatalogIndexSearchOptions(
                    query: term,
                    databaseURL: databaseURL,
                    archiveFilter: Self.factoryLayerArchiveRelativePath,
                    limit: 50
                ))
                let exactMatches = report.matches.filter { Self.normalizedFactoryPath($0.assetPath) == Self.normalizedFactoryPath(term) }
                indexSearches.append(AddonProbeFactoryIndexSearchReport(
                    term: term,
                    exactResource: true,
                    totalMatchCount: exactMatches.count,
                    shownMatchCount: exactMatches.count,
                    matches: exactMatches
                ))
                matchingArchiveResources.append(contentsOf: exactMatches)
            }
            for term in Self.factoryLayerBroadSearchTerms {
                let report = try store.search(options: ArchiveCatalogIndexSearchOptions(
                    query: term,
                    databaseURL: databaseURL,
                    limit: 50
                ))
                indexSearches.append(AddonProbeFactoryIndexSearchReport(
                    term: term,
                    exactResource: false,
                    totalMatchCount: report.totalMatchCount,
                    shownMatchCount: report.matches.count,
                    matches: report.matches
                ))
                matchingArchiveResources.append(contentsOf: report.matches)
            }
            matchingArchiveResources = uniqueIndexMatches(matchingArchiveResources)
        } else {
            warnings.append("Archive catalog index database was not found; factory-layer index searches were skipped.")
        }

        var extractedFiles: [AddonProbeFactoryExtractedFile] = []
        var resourceDiagnostics: [AddonProbeFactoryResourceDiagnostic] = []
        var decodeAttempts: [AddonProbeFactoryDecodeAttempt] = []
        var decodedTextSummaries: [AddonProbeFactoryDecodedTextSummary] = []
        var csvSummaries: [AddonProbeFactoryCSVSummary] = []
        var extractionArchivePath: String?

        if let cp77toolsURL = request.cp77toolsURL?.standardizedFileURL,
           let gameInstall = request.gameInstall {
            try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
            let sourceArchiveURL = try gameArchiveURL(
                relativeArchivePath: Self.factoryLayerArchiveRelativePath,
                gameInstall: gameInstall
            )
            try validateRegularFile(sourceArchiveURL, description: "Factory-layer source archive")
            extractionArchivePath = sourceArchiveURL.path

            let workRoot = try factoryLayerWorkRoot(outputDirectoryURL: request.outputDirectoryURL)
            let extractedRoot = workRoot.appendingPathComponent("extracted", isDirectory: true)
            do {
                try tooling.extractArchive(
                    cp77toolsURL: cp77toolsURL,
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                )

                for resourcePath in exactTerms {
                    let required = Self.requiredFactoryCSVResources.contains(resourcePath)
                    let localURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Factory-layer extracted CSV")
                    let archivePath = Self.archivePath(for: resourcePath, in: matchingArchiveResources) ?? extractionArchivePath
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        let data = try Data(contentsOf: localURL)
                        let diagnostic = Self.diagnoseFactoryResource(
                            resourcePath: resourcePath,
                            archivePath: archivePath,
                            extractedPath: localURL.path,
                            data: data
                        )
                        resourceDiagnostics.append(diagnostic)
                        if diagnostic.parseStatus == .parsedTextCSV,
                           let text = String(data: data, encoding: .utf8) {
                            csvSummaries.append(Self.analyzeFactoryCSV(
                                resourcePath: resourcePath,
                                extractedPath: localURL.path,
                                contents: text
                            ))
                        } else {
                            warnings.append(contentsOf: diagnostic.warnings)
                        }
                        extractedFiles.append(AddonProbeFactoryExtractedFile(
                            resourcePath: resourcePath,
                            extractedPath: localURL.path,
                            required: required,
                            parsed: diagnostic.parseStatus == .parsedTextCSV
                        ))

                        if request.tryCR2WDecode,
                           diagnostic.parseStatus == .extractedCR2W || diagnostic.parseStatus == .extractedKARK {
                            let decode = try attemptFactoryCR2WDecode(
                                cp77toolsURL: cp77toolsURL,
                                resourcePath: resourcePath,
                                sourceURL: localURL,
                                workRoot: workRoot
                            )
                            decodeAttempts.append(contentsOf: decode.attempts)
                            decodedTextSummaries.append(contentsOf: decode.textSummaries)
                            if decode.textSummaries.isEmpty {
                                warnings.append("CR2W factory resource extracted but no supported conversion path was found: \(resourcePath)")
                            }
                        }
                    } else if required {
                        let diagnostic = AddonProbeFactoryResourceDiagnostic(
                            resourcePath: resourcePath,
                            archivePath: archivePath,
                            extractedFilePath: localURL.path,
                            exists: false,
                            size: nil,
                            first32BytesHex: "",
                            detectedMagic: .empty,
                            parseStatus: .missing,
                            warnings: ["Required factory resource was not found after extraction: \(resourcePath)"]
                        )
                        resourceDiagnostics.append(diagnostic)
                        warnings.append(contentsOf: diagnostic.warnings)
                        extractedFiles.append(AddonProbeFactoryExtractedFile(
                            resourcePath: resourcePath,
                            extractedPath: localURL.path,
                            required: true,
                            parsed: false
                        ))
                    }
                }
            } catch {
                let message = "Factory archive extraction failed; resource diagnostics are marked extractionFailed: \(error.localizedDescription)"
                warnings.append(message)
                for resourcePath in exactTerms {
                    let required = Self.requiredFactoryCSVResources.contains(resourcePath)
                    resourceDiagnostics.append(AddonProbeFactoryResourceDiagnostic(
                        resourcePath: resourcePath,
                        archivePath: Self.archivePath(for: resourcePath, in: matchingArchiveResources) ?? extractionArchivePath,
                        extractedFilePath: nil,
                        exists: false,
                        size: nil,
                        first32BytesHex: "",
                        detectedMagic: .empty,
                        parseStatus: .extractionFailed,
                        warnings: [message]
                    ))
                    if required {
                        extractedFiles.append(AddonProbeFactoryExtractedFile(
                            resourcePath: resourcePath,
                            extractedPath: "",
                            required: true,
                            parsed: false
                        ))
                    }
                }
            }
        } else if request.tryCR2WDecode {
            warnings.append("--try-cr2w-decode requires both --cp77tools and --game-app because factory resources must be extracted before conversion.")
        } else {
            if request.cp77toolsURL != nil || request.gameInstall != nil {
                warnings.append("Factory CSV extraction requires both --cp77tools and --game-app; extraction was skipped.")
            } else {
                warnings.append("No cp77tools/game app pair was supplied; report is limited to archive-index search results.")
            }
        }

        csvSummaries.sort { $0.resourcePath < $1.resourcePath }
        let crossReferences = Self.analyzeFactoryCrossCSVReferences(csvSummaries)
        let conclusion = Self.concludeFactoryLayer(
            indexSearches: indexSearches,
            resourceDiagnostics: resourceDiagnostics,
            csvSummaries: csvSummaries,
            crossReferences: crossReferences
        )
        warnings.append("Factory CSVs may describe factory lookup or resource wiring, but TweakDB item registration remains unresolved unless a patchable record layer is proven.")
        warnings = Array(Set(warnings)).sorted()

        let provisional = AddonProbeFactoryLayerReport(
            searchedTerms: searchedTerms,
            exactResourceTerms: exactTerms,
            broadSearchTerms: Self.factoryLayerBroadSearchTerms,
            indexDatabasePath: databaseURL.path,
            indexDatabaseExists: FileManager.default.fileExists(atPath: databaseURL.path),
            indexSearches: indexSearches,
            matchingArchiveResources: matchingArchiveResources,
            extractionArchivePath: extractionArchivePath,
            extractedFiles: extractedFiles,
            resourceDiagnostics: resourceDiagnostics.sorted { $0.resourcePath < $1.resourcePath },
            decodeAttempts: decodeAttempts,
            decodedTextSummaries: decodedTextSummaries.sorted { $0.decodedPath < $1.decodedPath },
            csvSummaries: csvSummaries,
            crossCSVReferences: crossReferences,
            warnings: warnings,
            conclusion: conclusion,
            writtenReportPath: nil
        )

        guard let outputDirectoryURL = request.outputDirectoryURL?.standardizedFileURL else {
            return provisional
        }
        try validateOutputDirectory(outputDirectoryURL, description: "Factory probe output directory")
        let reportURL = outputDirectoryURL.appendingPathComponent("addon-probe-factory-layer.json")
        let finalReport = AddonProbeFactoryLayerReport(
            searchedTerms: provisional.searchedTerms,
            exactResourceTerms: provisional.exactResourceTerms,
            broadSearchTerms: provisional.broadSearchTerms,
            indexDatabasePath: provisional.indexDatabasePath,
            indexDatabaseExists: provisional.indexDatabaseExists,
            indexSearches: provisional.indexSearches,
            matchingArchiveResources: provisional.matchingArchiveResources,
            extractionArchivePath: provisional.extractionArchivePath,
            extractedFiles: provisional.extractedFiles,
            resourceDiagnostics: provisional.resourceDiagnostics,
            decodeAttempts: provisional.decodeAttempts,
            decodedTextSummaries: provisional.decodedTextSummaries,
            csvSummaries: provisional.csvSummaries,
            crossCSVReferences: provisional.crossCSVReferences,
            warnings: provisional.warnings,
            conclusion: provisional.conclusion,
            writtenReportPath: reportURL.path
        )
        try JSONEncoder.cybermac.encode(finalReport).write(to: reportURL, options: [.atomic])
        return finalReport
    }

    public func analyzeFactoryJSON(request: AddonProbeFactoryJSONAnalysisRequest) throws -> AddonProbeFactoryJSONAnalysisReport {
        let rootURL = request.decodedJSONRootURL.standardizedFileURL
        try validateReadableDirectory(rootURL, description: "Decoded factory JSON root")
        let targetNames = Set(Self.decodedFactoryJSONFileNames)
        let files = try regularFiles(under: rootURL, description: "Decoded factory JSON root")
            .filter { targetNames.contains($0.url.lastPathComponent) }
            .sorted { $0.relativePath < $1.relativePath }

        var warnings: [String] = []
        if files.isEmpty {
            warnings.append("No supported decoded factory JSON files were found under the input root.")
        }

        var fileReports: [AddonProbeFactoryJSONFileReport] = []
        for file in files {
            fileReports.append(try analyzeFactoryJSONFile(file, rootURL: rootURL))
        }

        return AddonProbeFactoryJSONAnalysisReport(
            inputRoot: rootURL.path,
            discoveredFiles: files.map(\.url.path),
            files: fileReports,
            warnings: warnings
        )
    }

    public func roundtripFactoryResource(request: AddonProbeFactoryRoundtripRequest) throws -> AddonProbeFactoryRoundtripManifest {
        try home.bootstrap()
        let resourcePath = try validatedAssetPath(request.resourcePath, label: "Factory resource")
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
        let sourceArchiveURL = try resolveFactoryRoundtripArchiveURL(
            archivePath: request.archivePath,
            gameInstall: request.gameInstall
        )
        try validateRegularFile(sourceArchiveURL, description: "Factory roundtrip source archive")

        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "Factory roundtrip output directory")
        try validateOutsideGameBundle(outputRootURL, gameInstall: request.gameInstall, description: "Factory roundtrip output directory")

        let stageRoot = outputRootURL.appendingPathComponent(
            "factory-roundtrip-\(Self.safeFilename(resourcePath))-\(stageID())",
            isDirectory: true
        )
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("Factory roundtrip work directory already exists: \(stageRoot.path)")
        }
        try FileManager.default.createDirectory(at: stageRoot, withIntermediateDirectories: true)
        let manifestURL = stageRoot.appendingPathComponent("addon-probe-factory-roundtrip.json")
        let extractedRoot = stageRoot.appendingPathComponent("extracted", isDirectory: true)
        let decodedRoot = stageRoot.appendingPathComponent("decoded", isDirectory: true)
        let reserializedRoot = stageRoot.appendingPathComponent("reserialized", isDirectory: true)
        let packedRoot = stageRoot.appendingPathComponent("packed", isDirectory: true)
        let stagedRoot = stageRoot.appendingPathComponent("staged", isDirectory: true)
        for directory in [extractedRoot, decodedRoot, reserializedRoot, packedRoot, stagedRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var attempts: [AddonProbeFactoryRoundtripCommandAttempt] = []
        var warnings: [String] = [
            "Factory resource roundtrip is a no-op Path B probe. It does not prove true add-on clothing support.",
            "The game app is not mutated; any staged archive is written only under --out."
        ]

        do {
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.extractArguments(
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                ),
                attempts: &attempts,
                operation: "Archive extraction"
            ) {
                try tooling.extractArchive(
                    cp77toolsURL: cp77toolsURL,
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                )
            }
        } catch {
            warnings.append("Factory archive extraction failed: \(error.localizedDescription)")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: nil,
                decodedJSONPath: nil,
                reserializedCR2WPath: nil,
                originalFacts: nil,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }
        let extractedResourceURL: URL
        do {
            extractedResourceURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Extracted factory resource")
            try validateRegularFile(extractedResourceURL, description: "Extracted factory resource")
        } catch {
            warnings.append("Requested factory resource was not found after extraction: \(error.localizedDescription)")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: nil,
                decodedJSONPath: nil,
                reserializedCR2WPath: nil,
                originalFacts: nil,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }
        let originalFacts = try Self.factoryFileFacts(url: extractedResourceURL)
        if originalFacts.magic != AddonProbeFactoryResourceMagic.cr2w.rawValue {
            warnings.append("Extracted factory resource is not CR2W by magic header: \(originalFacts.magic). Decode is still attempted because cp77tools may handle wrapped input.")
        }

        let decodeResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "serialize", extractedResourceURL.path, "--outpath", decodedRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        if decodeResult?.exitCode != 0 {
            warnings.append("cp77tools convert serialize exited non-zero; reverse probing is skipped.")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: nil,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        let decodedJSONURL: URL?
        do {
            decodedJSONURL = try findDecodedFactoryJSON(for: resourcePath, under: decodedRoot, warnings: &warnings)
        } catch {
            warnings.append("Decoded JSON discovery failed: \(error.localizedDescription)")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: nil,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        guard let decodedJSONURL else {
            warnings.append("cp77tools serialize produced no decoded JSON file for the requested resource.")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: nil,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        guard let reversePlan = probeFactoryReverseSerialization(
            cp77toolsURL: cp77toolsURL,
            decodedJSONURL: decodedJSONURL,
            outputDirectoryURL: reserializedRoot,
            attempts: &attempts
        ) else {
            warnings.append("No supported JSON-to-CR2W reserialization path was discovered from cp77tools help output.")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: decodedJSONURL.path,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .decodedOnly_reserializeUnsupported,
                warnings: warnings
            )
        }

        let reverseResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: reversePlan.arguments,
            timeout: 120,
            attempts: &attempts
        )
        guard reverseResult?.exitCode == 0 else {
            warnings.append("JSON-to-CR2W reserialization command exited non-zero.")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: decodedJSONURL.path,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        guard let rebuiltURL = try findReserializedCR2W(for: resourcePath, under: reserializedRoot, warnings: &warnings) else {
            warnings.append("JSON-to-CR2W command completed but produced no valid-looking CR2W output.")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: decodedJSONURL.path,
                reserializedCR2WPath: nil,
                originalFacts: originalFacts,
                rebuiltFacts: nil,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        let rebuiltFacts = try Self.factoryFileFacts(url: rebuiltURL)
        let roundtripConclusion: AddonProbeFactoryRoundtripConclusion = originalFacts.sha256 == rebuiltFacts.sha256
            ? .roundtripExact
            : .roundtripDifferentButCR2W
        if rebuiltFacts.magic != AddonProbeFactoryResourceMagic.cr2w.rawValue {
            warnings.append("Rebuilt file does not have a CR2W magic header: \(rebuiltFacts.magic).")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: decodedJSONURL.path,
                reserializedCR2WPath: rebuiltURL.path,
                originalFacts: originalFacts,
                rebuiltFacts: rebuiltFacts,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: .roundtripFailed,
                warnings: warnings
            )
        }

        let stagedArchiveURL: URL
        let stagedArchiveSHA256: String
        do {
            let extractedTargetURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "No-op staged factory resource")
            try FileManager.default.removeItem(at: extractedTargetURL)
            try FileManager.default.copyItem(at: rebuiltURL, to: extractedTargetURL)
            let requestedPackedURL = packedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.packArguments(
                    extractedDirectoryURL: extractedRoot,
                    outputDirectoryURL: packedRoot
                ),
                attempts: &attempts,
                operation: "Archive packing"
            ) {
                try tooling.packArchive(
                    cp77toolsURL: cp77toolsURL,
                    extractedDirectoryURL: extractedRoot,
                    outputArchiveURL: requestedPackedURL
                )
            }
            let generatedArchiveURL = try singleGeneratedArchive(in: packedRoot)
            stagedArchiveURL = stagedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: stagedArchiveURL.path) else {
                throw CyberMacError.invalidInput("Staged roundtrip archive already exists: \(stagedArchiveURL.path)")
            }
            try FileManager.default.copyItem(at: generatedArchiveURL, to: stagedArchiveURL)
            stagedArchiveSHA256 = try PathSafety.sha256(url: stagedArchiveURL)
        } catch {
            warnings.append("Rebuilt CR2W exists, but staging the no-op archive failed: \(error.localizedDescription)")
            return try writeRoundtripManifest(
                inputArchive: sourceArchiveURL.path,
                resourcePath: resourcePath,
                extractedResourcePath: extractedResourceURL.path,
                decodedJSONPath: decodedJSONURL.path,
                reserializedCR2WPath: rebuiltURL.path,
                originalFacts: originalFacts,
                rebuiltFacts: rebuiltFacts,
                attempts: attempts,
                stagedArchivePath: nil,
                stagedArchiveSHA256: nil,
                manifestURL: manifestURL,
                manualInstallCommand: nil,
                conclusion: roundtripConclusion,
                warnings: warnings
            )
        }

        let manualInstallCommand = "cp \(PathSafety.shellQuoted(stagedArchiveURL.path)) \(PathSafety.shellQuoted(sourceArchiveURL.path))"
        warnings.append("Manual install command is printed for review only and intentionally does not include sudo.")
        return try writeRoundtripManifest(
            inputArchive: sourceArchiveURL.path,
            resourcePath: resourcePath,
            extractedResourcePath: extractedResourceURL.path,
            decodedJSONPath: decodedJSONURL.path,
            reserializedCR2WPath: rebuiltURL.path,
            originalFacts: originalFacts,
            rebuiltFacts: rebuiltFacts,
            attempts: attempts,
            stagedArchivePath: stagedArchiveURL.path,
            stagedArchiveSHA256: stagedArchiveSHA256,
            manifestURL: manifestURL,
            manualInstallCommand: manualInstallCommand,
            conclusion: .stagedNoopArchiveProduced,
            warnings: warnings
        )
    }

    public func cloneFactoryRow(request: AddonProbeFactoryRowCloneRequest) throws -> AddonProbeFactoryRowCloneManifest {
        try home.bootstrap()
        let resourcePath = try validatedAssetPath(request.resourcePath, label: "Factory resource")
        let sourceKey = try Self.validatedFactoryRowKey(request.sourceKey, label: "Source key")
        let newKey = try Self.validatedFactoryRowKey(request.newKey, label: "New key")
        let cp77toolsURL = request.cp77toolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
        let sourceArchiveURL = try resolveFactoryRoundtripArchiveURL(
            archivePath: request.archivePath,
            gameInstall: request.gameInstall
        )
        try validateRegularFile(sourceArchiveURL, description: "Factory row clone source archive")

        let outputRootURL = request.outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "Factory row clone output directory")
        try validateOutsideGameBundle(outputRootURL, gameInstall: request.gameInstall, description: "Factory row clone output directory")

        let stageRoot = outputRootURL.appendingPathComponent(
            "factory-row-clone-\(Self.safeFilename(resourcePath))-\(Self.safeFilename(newKey))-\(stageID())",
            isDirectory: true
        )
        guard !FileManager.default.fileExists(atPath: stageRoot.path) else {
            throw CyberMacError.invalidInput("Factory row clone work directory already exists: \(stageRoot.path)")
        }
        try FileManager.default.createDirectory(at: stageRoot, withIntermediateDirectories: true)
        let manifestURL = stageRoot.appendingPathComponent("addon-probe-factory-row-clone.json")
        let extractedRoot = stageRoot.appendingPathComponent("extracted", isDirectory: true)
        let decodedRoot = stageRoot.appendingPathComponent("decoded", isDirectory: true)
        let reserializedRoot = stageRoot.appendingPathComponent("reserialized", isDirectory: true)
        let packedRoot = stageRoot.appendingPathComponent("packed", isDirectory: true)
        let stagedRoot = stageRoot.appendingPathComponent("staged", isDirectory: true)
        for directory in [extractedRoot, decodedRoot, reserializedRoot, packedRoot, stagedRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var attempts: [AddonProbeFactoryRoundtripCommandAttempt] = []
        var warnings: [String] = [
            "Factory row clone is a Path B acceptance probe. It does not prove true add-on clothing support.",
            "The game app is not mutated; any staged archive is written only under --out."
        ]

        do {
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.extractArguments(
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                ),
                attempts: &attempts,
                operation: "Archive extraction"
            ) {
                try tooling.extractArchive(
                    cp77toolsURL: cp77toolsURL,
                    sourceArchiveURL: sourceArchiveURL,
                    outputDirectoryURL: extractedRoot
                )
            }
        } catch {
            warnings.append("Factory archive extraction failed: \(error.localizedDescription)")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: nil,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: nil,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let extractedResourceURL: URL
        do {
            extractedResourceURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Extracted factory resource")
            try validateRegularFile(extractedResourceURL, description: "Extracted factory resource")
        } catch {
            warnings.append("Requested factory resource was not found after extraction: \(error.localizedDescription)")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: nil,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: nil,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }
        let originalFacts = try Self.factoryFileFacts(url: extractedResourceURL)

        let decodeResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "serialize", extractedResourceURL.path, "--outpath", decodedRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        if decodeResult?.exitCode != 0 {
            warnings.append("cp77tools convert serialize exited non-zero; factory row clone cannot proceed.")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: nil,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let decodedJSONURL: URL?
        do {
            decodedJSONURL = try findDecodedFactoryJSON(for: resourcePath, under: decodedRoot, warnings: &warnings)
        } catch {
            warnings.append("Decoded JSON discovery failed: \(error.localizedDescription)")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: nil,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        guard let decodedJSONURL else {
            warnings.append("cp77tools serialize produced no decoded JSON file for the requested resource.")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: nil,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let editResult: AddonProbeFactoryRowCloneEditResult
        do {
            let decodedJSONData = try Data(contentsOf: decodedJSONURL)
            editResult = try Self.cloneFactoryRowInDecodedJSON(
                decodedJSONData,
                sourceKey: sourceKey,
                newKey: newKey
            )
        } catch {
            warnings.append("Factory JSON row clone failed: \(error.localizedDescription)")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: nil,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }
        warnings.append(contentsOf: editResult.warnings)

        if editResult.conclusion == .newKeyAlreadyPresent || editResult.conclusion == .sourceKeyNotFound {
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: editResult.conclusion,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        guard let editedJSONData = editResult.editedJSONData else {
            warnings.append("Factory row clone produced no edited JSON data.")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: nil,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .unresolved,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let editedJSONURL = decodedJSONURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(decodedJSONURL.deletingPathExtension().lastPathComponent).cybermac-clone.json")
        try editedJSONData.write(to: editedJSONURL, options: [.atomic])

        let deserializeResult = runRoundtripCP77ToolsCommand(
            cp77toolsURL: cp77toolsURL,
            arguments: ["convert", "deserialize", editedJSONURL.path, "--outpath", reserializedRoot.path],
            timeout: 120,
            attempts: &attempts
        )
        guard deserializeResult?.exitCode == 0 else {
            warnings.append("cp77tools convert deserialize exited non-zero.")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: editedJSONURL.path,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .deserializeFailed,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        guard let rebuiltURL = try findReserializedCR2W(for: resourcePath, under: reserializedRoot, warnings: &warnings) else {
            warnings.append("cp77tools convert deserialize completed but produced no valid-looking CR2W output.")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: editedJSONURL.path,
                rebuiltResource: nil,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: nil,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .deserializeFailed,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }
        let editedFacts = try Self.factoryFileFacts(url: rebuiltURL)
        if editedFacts.magic != AddonProbeFactoryResourceMagic.cr2w.rawValue {
            warnings.append("Rebuilt edited resource does not have a CR2W magic header: \(editedFacts.magic).")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: editedJSONURL.path,
                rebuiltResource: rebuiltURL.path,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: editedFacts,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .deserializeFailed,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let stagedArchiveURL: URL
        let stagedArchiveSHA256: String
        do {
            let extractedTargetURL = try assetURL(assetPath: resourcePath, rootURL: extractedRoot, label: "Edited staged factory resource")
            try FileManager.default.removeItem(at: extractedTargetURL)
            try FileManager.default.copyItem(at: rebuiltURL, to: extractedTargetURL)
            let requestedPackedURL = packedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            try recordRoundtripArchiveToolingCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: CP77ToolsArchiveSwapTooling.packArguments(
                    extractedDirectoryURL: extractedRoot,
                    outputDirectoryURL: packedRoot
                ),
                attempts: &attempts,
                operation: "Archive packing"
            ) {
                try tooling.packArchive(
                    cp77toolsURL: cp77toolsURL,
                    extractedDirectoryURL: extractedRoot,
                    outputArchiveURL: requestedPackedURL
                )
            }
            let generatedArchiveURL = try singleGeneratedArchive(in: packedRoot)
            stagedArchiveURL = stagedRoot.appendingPathComponent(sourceArchiveURL.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: stagedArchiveURL.path) else {
                throw CyberMacError.invalidInput("Staged clone archive already exists: \(stagedArchiveURL.path)")
            }
            try FileManager.default.copyItem(at: generatedArchiveURL, to: stagedArchiveURL)
            stagedArchiveSHA256 = try PathSafety.sha256(url: stagedArchiveURL)
        } catch {
            warnings.append("Rebuilt edited CR2W exists, but staging the archive failed: \(error.localizedDescription)")
            return try writeFactoryRowCloneManifest(
                archive: sourceArchiveURL.path,
                resource: resourcePath,
                sourceKey: sourceKey,
                newKey: newKey,
                editResult: editResult,
                decodedOriginalJson: decodedJSONURL.path,
                decodedEditedJson: editedJSONURL.path,
                rebuiltResource: rebuiltURL.path,
                stagedArchive: nil,
                originalFacts: originalFacts,
                editedFacts: editedFacts,
                stagedArchiveSHA256: nil,
                attempts: attempts,
                conclusion: .packFailed,
                warnings: warnings,
                manifestURL: manifestURL,
                manualInstallCommand: nil
            )
        }

        let manualInstallCommand = "cp \(PathSafety.shellQuoted(stagedArchiveURL.path)) \(PathSafety.shellQuoted(sourceArchiveURL.path))"
        warnings.append("Manual install command is printed for review only and intentionally does not include sudo.")
        return try writeFactoryRowCloneManifest(
            archive: sourceArchiveURL.path,
            resource: resourcePath,
            sourceKey: sourceKey,
            newKey: newKey,
            editResult: editResult,
            decodedOriginalJson: decodedJSONURL.path,
            decodedEditedJson: editedJSONURL.path,
            rebuiltResource: rebuiltURL.path,
            stagedArchive: stagedArchiveURL.path,
            originalFacts: originalFacts,
            editedFacts: editedFacts,
            stagedArchiveSHA256: stagedArchiveSHA256,
            attempts: attempts,
            conclusion: .stagedCloneArchiveProduced,
            warnings: warnings,
            manifestURL: manifestURL,
            manualInstallCommand: manualInstallCommand
        )
    }

    public func plan(modURL: URL) throws -> AddonProbePlanReport {
        let inspect = try inspect(request: AddonProbeInspectRequest(modURL: modURL))
        let steps = [
            "Step A: Stage custom and replacement assets into the official Mac appearance archive with `cybermac addon-probe stage-assets ...`; do not install automatically.",
            "Step B: Generate a temporary custom-item grant helper with `cybermac addon-probe grant-test <Items.ID> --out <zip-path>`.",
            "Step C: Run a manual game test by installing the grant helper, activating bundle mode, copying final.redscripts as instructed, and launching once.",
            "Step D: If the grant fails or grants nothing, treat the missing TweakDB item record or missing registration layer as confirmed for this mod.",
            "Step E: Run `cybermac addon-probe search-record-layer --limit 50` and inspect any indexed gamedata/TweakDB candidates before adding more support."
        ]
        let failures = [
            "missing TweakDB item record",
            "missing factory/appearance registration",
            "unresolved localization",
            "unsupported ArchiveXL resource patching",
            "unsupported runtime framework requirement"
        ]
        var warnings = inspect.warnings
        warnings.append("This is a Path B probe. It does not prove true add-on clothing support on Mac.")
        return AddonProbePlanReport(
            inspect: inspect,
            steps: steps,
            expectedFailureModes: failures,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public static func analyzeFactoryCSV(resourcePath: String, extractedPath: String? = nil, contents: String) -> AddonProbeFactoryCSVSummary {
        let parsed = parseCSV(contents)
        let headers = parsed.headers
        let rows = parsed.rows
        var itemDetections: [AddonProbeFactoryCellDetection] = []
        var tweakDetections: [AddonProbeFactoryCellDetection] = []
        var resourceDetections: [AddonProbeFactoryCellDetection] = []
        var semanticDetections: [AddonProbeFactorySemanticDetection] = []
        var knownRows: [AddonProbeFactoryKnownItemRow] = []

        for (index, row) in rows.enumerated() {
            let rowIndex = index + 1
            var knownIDsSeen = Set<String>()
            for column in headers {
                let value = row[column] ?? ""
                let itemMatches = sortedMatches(pattern: #"Items\.[A-Za-z0-9_.-]+"#, text: value)
                if !itemMatches.isEmpty {
                    itemDetections.append(AddonProbeFactoryCellDetection(
                        rowIndex: rowIndex,
                        column: column,
                        value: value,
                        matches: itemMatches
                    ))
                }

                let tweakMatches = sortedMatches(
                    pattern: #"(?:Items|TweakDB|EquipmentArea|AttachmentSlots|gamedata[A-Za-z0-9_]+)\.[A-Za-z0-9_.-]+"#,
                    text: value
                )
                if !tweakMatches.isEmpty {
                    tweakDetections.append(AddonProbeFactoryCellDetection(
                        rowIndex: rowIndex,
                        column: column,
                        value: value,
                        matches: tweakMatches
                    ))
                }

                let resourceMatches = sortedMatches(
                    pattern: #"[A-Za-z0-9_.$:/\\-]+\.(?:ent|app|mesh|mlsetup|mlmask|xbm|inkatlas|csv)"#,
                    text: value
                ).map { $0.replacingOccurrences(of: "\\", with: "/") }
                if !resourceMatches.isEmpty {
                    resourceDetections.append(AddonProbeFactoryCellDetection(
                        rowIndex: rowIndex,
                        column: column,
                        value: value,
                        matches: Array(Set(resourceMatches)).sorted()
                    ))
                }

                let semanticKinds = factorySemanticKinds(column: column, value: value)
                if !semanticKinds.isEmpty {
                    semanticDetections.append(AddonProbeFactorySemanticDetection(
                        rowIndex: rowIndex,
                        column: column,
                        value: value,
                        kinds: semanticKinds
                    ))
                }

                for itemID in knownVanillaClothingItemIDs where value.contains(itemID) {
                    knownIDsSeen.insert(itemID)
                }
            }
            for itemID in knownIDsSeen.sorted() {
                knownRows.append(AddonProbeFactoryKnownItemRow(itemID: itemID, rowIndex: rowIndex, row: row))
            }
        }

        var warnings = parsed.warnings
        if contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("CSV is empty.")
        } else if headers.isEmpty {
            warnings.append("CSV has no header row.")
        }

        return AddonProbeFactoryCSVSummary(
            resourcePath: resourcePath,
            extractedPath: extractedPath,
            headers: headers,
            rowCount: rows.count,
            itemIDDetections: itemDetections,
            tweakDBDetections: tweakDetections,
            resourcePathDetections: resourceDetections,
            semanticDetections: semanticDetections,
            knownVanillaItemRows: knownRows,
            representativeRows: Array(rows.prefix(25)),
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public static func diagnoseFactoryResource(
        resourcePath: String,
        archivePath: String?,
        extractedPath: String?,
        data: Data
    ) -> AddonProbeFactoryResourceDiagnostic {
        let magic = factoryResourceMagic(data)
        let parseStatus: AddonProbeFactoryParseStatus
        var warnings: [String] = []
        switch magic {
        case .cr2w:
            parseStatus = .extractedCR2W
            warnings.append("Factory resource is CR2W binary data; CSV analysis requires a successful CR2W decode/export step.")
        case .kark:
            parseStatus = .extractedKARK
            warnings.append("Factory resource is KARK-compressed binary data; decompression/CR2W decoding is required before CSV analysis.")
        case .jsonText:
            parseStatus = .parsedJSONText
        case .utf8Text:
            parseStatus = .parsedTextCSV
        case .empty:
            parseStatus = .empty
            warnings.append("Factory resource is empty; no CSV rows can be parsed.")
        case .unknownBinary:
            parseStatus = .extractedUnknownBinary
            warnings.append("Factory resource is not valid UTF-8 text and does not use a recognized CR2W/KARK magic header.")
        }

        return AddonProbeFactoryResourceDiagnostic(
            resourcePath: resourcePath,
            archivePath: archivePath,
            extractedFilePath: extractedPath,
            exists: true,
            size: data.count,
            first32BytesHex: hexPrefix(data, count: 32),
            detectedMagic: magic,
            parseStatus: parseStatus,
            warnings: warnings
        )
    }

    public static func analyzeFactoryDecodedText(resourcePath: String, decodedPath: String, contents: String) -> AddonProbeFactoryDecodedTextSummary {
        let itemIDs = parseReferencedItemIDs(contents)
        let resourceReferences = parseResourceReferences(contents)
        let lower = contents.lowercased()
        let semanticTerms = [
            "appearance",
            "factory",
            "factories",
            "clothing",
            "slot",
            "equipment",
            "equipmentarea",
            "outerchest",
            "innerchest",
            "legs",
            "feet",
            "garment"
        ].filter { lower.contains($0) }
        let knownIDs = knownVanillaClothingItemIDs.filter { contents.contains($0) }
        var warnings: [String] = []
        if contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Decoded text is empty.")
        }
        return AddonProbeFactoryDecodedTextSummary(
            resourcePath: resourcePath,
            decodedPath: decodedPath,
            itemIDs: itemIDs,
            resourceReferences: resourceReferences,
            semanticTerms: Array(Set(semanticTerms)).sorted(),
            knownVanillaItemIDs: knownIDs,
            warnings: warnings
        )
    }

    public static func analyzeFactoryCrossCSVReferences(_ summaries: [AddonProbeFactoryCSVSummary]) -> [AddonProbeFactoryCrossReference] {
        let byPath = Dictionary(uniqueKeysWithValues: summaries.map { ($0.resourcePath, $0) })
        var references: [AddonProbeFactoryCrossReference] = []

        if let clothing = byPath["base/gameplay/factories/items/clothing.csv"],
           let appearances = byPath["base/gameplay/factories/items/clothing_appearances.csv"] {
            references.append(contentsOf: crossReferences(
                relationship: "clothing.csv references clothing_appearances.csv rows or IDs",
                from: clothing,
                to: appearances,
                tokens: referenceTokens(from: appearances),
                limit: 100
            ))
        }

        if let items = byPath["base/gameplay/factories/items/items.csv"],
           let clothing = byPath["base/gameplay/factories/items/clothing.csv"] {
            var tokens = referenceTokens(from: clothing)
            tokens.insert("clothing.csv")
            tokens.insert("base/gameplay/factories/items/clothing.csv")
            references.append(contentsOf: crossReferences(
                relationship: "items.csv references clothing.csv or clothing entries",
                from: items,
                to: clothing,
                tokens: tokens,
                limit: 100
            ))
        }

        if let factories = byPath["base/gameplay/factories.csv"] {
            let itemFactoryTargets = Set(requiredFactoryCSVResources.dropFirst() + optionalFactoryCSVResources)
            for target in itemFactoryTargets.sorted() {
                let rows = matchingRowIndices(in: factories, token: target)
                if !rows.isEmpty {
                    references.append(AddonProbeFactoryCrossReference(
                        relationship: "factories.csv references item factory CSVs",
                        fromCSV: factories.resourcePath,
                        toCSV: target,
                        token: target,
                        fromRows: rows
                    ))
                }
            }
        }

        return references.sorted {
            if $0.relationship != $1.relationship { return $0.relationship < $1.relationship }
            if $0.fromCSV != $1.fromCSV { return $0.fromCSV < $1.fromCSV }
            if $0.toCSV != $1.toCSV { return $0.toCSV < $1.toCSV }
            return $0.token < $1.token
        }
    }

    public static func concludeFactoryLayer(
        indexSearches: [AddonProbeFactoryIndexSearchReport],
        resourceDiagnostics: [AddonProbeFactoryResourceDiagnostic] = [],
        csvSummaries: [AddonProbeFactoryCSVSummary],
        crossReferences: [AddonProbeFactoryCrossReference]
    ) -> AddonProbeFactoryLayerConclusion {
        if csvSummaries.isEmpty,
           resourceDiagnostics.contains(where: { $0.parseStatus == .extractedCR2W }) {
            return .cr2wDecodeRequired
        }

        guard !csvSummaries.isEmpty else {
            return .unableToDetermine
        }

        let hasClothing = csvSummaries.contains { $0.resourcePath == "base/gameplay/factories/items/clothing.csv" }
        let hasAppearances = csvSummaries.contains { $0.resourcePath == "base/gameplay/factories/items/clothing_appearances.csv" }
        let hasItems = csvSummaries.contains { $0.resourcePath == "base/gameplay/factories/items/items.csv" }
        let hasFactories = csvSummaries.contains { $0.resourcePath == "base/gameplay/factories.csv" }
        let hasItemsSignals = csvSummaries.contains { !$0.itemIDDetections.isEmpty || !$0.tweakDBDetections.isEmpty }
        let hasResourceSignals = csvSummaries.contains { !$0.resourcePathDetections.isEmpty }
        let hasRegistrationShape = hasClothing && hasAppearances && hasItems && hasFactories && hasItemsSignals && hasResourceSignals && !crossReferences.isEmpty

        if hasRegistrationShape {
            return .relevantToItemResourceRegistration
        }
        if hasFactories || !crossReferences.isEmpty || csvSummaries.contains(where: { !$0.semanticDetections.isEmpty }) {
            return .spawningLookupButInsufficient
        }
        return .unrelated
    }

    public static func cloneFactoryRowInDecodedJSON(
        _ data: Data,
        sourceKey: String,
        newKey: String
    ) throws -> AddonProbeFactoryRowCloneEditResult {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw CyberMacError.invalidInput("Decoded factory JSON could not be parsed: \(error.localizedDescription)")
        }

        guard var root = parsed as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factory JSON top-level value is not an object.")
        }
        guard var dataObject = root["Data"] as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factory JSON does not contain object at $.Data.")
        }
        guard var rootChunk = dataObject["RootChunk"] as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factory JSON does not contain object at $.Data.RootChunk.")
        }

        var warnings: [String] = []
        let compiledDataRows = factoryRowArray(named: "compiledData", in: rootChunk, warnings: &warnings)
        let dataRows = factoryRowArray(named: "data", in: rootChunk, warnings: &warnings)

        if compiledDataRows == nil {
            warnings.append("$.Data.RootChunk.compiledData is absent; only $.Data.RootChunk.data can be modified if present.")
        }
        if dataRows == nil {
            warnings.append("$.Data.RootChunk.data is absent; only $.Data.RootChunk.compiledData can be modified if present.")
        }

        let sourceCompiledRows = factoryRows(matchingKey: sourceKey, in: compiledDataRows)
        let sourceDataRows = factoryRows(matchingKey: sourceKey, in: dataRows)
        let sourceRowsFound = sourceCompiledRows.count + sourceDataRows.count
        let sourceRowPath = (sourceCompiledRows + sourceDataRows)
            .compactMap { firstEntityPath(inFactoryRow: $0) }
            .first

        let newKeyAlreadyPresent = factoryContainsRow(key: newKey, in: compiledDataRows) ||
            factoryContainsRow(key: newKey, in: dataRows)
        if newKeyAlreadyPresent {
            return AddonProbeFactoryRowCloneEditResult(
                sourceRowsFound: sourceRowsFound,
                sourceRowPath: sourceRowPath,
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                editedJSONData: nil,
                conclusion: .newKeyAlreadyPresent,
                warnings: Array(Set(warnings)).sorted()
            )
        }

        guard sourceRowsFound > 0 else {
            return AddonProbeFactoryRowCloneEditResult(
                sourceRowsFound: 0,
                sourceRowPath: nil,
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                editedJSONData: nil,
                conclusion: .sourceKeyNotFound,
                warnings: Array(Set(warnings)).sorted()
            )
        }

        var rowsAddedCompiledData = 0
        var rowsAddedData = 0
        if var compiledDataRows {
            let clones = sourceCompiledRows.map { clonedFactoryRow($0, newKey: newKey) }
            compiledDataRows.append(contentsOf: clones)
            rootChunk["compiledData"] = compiledDataRows
            rowsAddedCompiledData = clones.count
        }
        if var dataRows {
            let clones = sourceDataRows.map { clonedFactoryRow($0, newKey: newKey) }
            dataRows.append(contentsOf: clones)
            rootChunk["data"] = dataRows
            rowsAddedData = clones.count
        }
        if sourceRowPath == nil {
            warnings.append("Source row was cloned, but no direct .ent string was found after column 0.")
        }

        dataObject["RootChunk"] = rootChunk
        root["Data"] = dataObject
        let editedJSONData = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )
        return AddonProbeFactoryRowCloneEditResult(
            sourceRowsFound: sourceRowsFound,
            sourceRowPath: sourceRowPath,
            rowsAddedCompiledData: rowsAddedCompiledData,
            rowsAddedData: rowsAddedData,
            editedJSONData: editedJSONData,
            conclusion: .unresolved,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public static func addFactoryRegistryPathsToDecodedJSON(
        _ data: Data,
        factoryPaths: [String]
    ) throws -> AddonProbeXLFactoryRegistryEditResult {
        let declaredPaths = orderedUnique(factoryPaths.map(normalizedFactoryResourceDisplayPath))
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw CyberMacError.invalidInput("Decoded factories.csv JSON could not be parsed: \(error.localizedDescription)")
        }

        guard var root = parsed as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factories.csv JSON top-level value is not an object.")
        }
        guard var dataObject = root["Data"] as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factories.csv JSON does not contain object at $.Data.")
        }
        guard var rootChunk = dataObject["RootChunk"] as? [String: Any] else {
            throw CyberMacError.invalidInput("Decoded factories.csv JSON does not contain object at $.Data.RootChunk.")
        }

        var warnings: [String] = []
        let originalCompiledDataRows = factoryRowArray(named: "compiledData", in: rootChunk, warnings: &warnings)
        let originalDataRows = factoryRowArray(named: "data", in: rootChunk, warnings: &warnings)
        if originalCompiledDataRows == nil {
            warnings.append("$.Data.RootChunk.compiledData is absent; only $.Data.RootChunk.data can be modified if present.")
        }
        if originalDataRows == nil {
            warnings.append("$.Data.RootChunk.data is absent; only $.Data.RootChunk.compiledData can be modified if present.")
        }
        let compiledDataRowsBefore = originalCompiledDataRows?.count
        let dataRowsBefore = originalDataRows?.count

        guard var compiledDataRows = originalCompiledDataRows else {
            return AddonProbeXLFactoryRegistryEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: [],
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: nil,
                clonedSourceRowPreview: nil,
                addedRowPreview: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsBefore,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                editedJSONData: nil,
                conclusion: .factoryRegistryEditFailed,
                warnings: Array(Set(warnings)).sorted()
            )
        }

        let alreadyPresent = declaredPaths.filter { path in
            factoryRowsContainPath(path, in: originalCompiledDataRows) ||
                factoryRowsContainPath(path, in: originalDataRows)
        }
        var addedPaths: [String] = []
        var rowsAddedCompiledData = 0
        var rowsAddedData = 0
        var firstSourcePath: String?
        var firstSourcePreview: String?
        var firstAddedPreview: String?

        guard let compiledSource = factoryRegistrySourceRow(in: compiledDataRows, arrayPath: "$.Data.RootChunk.compiledData") else {
            warnings.append("No compatible .csv-shaped source row was found in $.Data.RootChunk.compiledData; factories.csv was not edited.")
            return AddonProbeXLFactoryRegistryEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: alreadyPresent,
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: nil,
                clonedSourceRowPreview: nil,
                addedRowPreview: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsBefore,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                editedJSONData: nil,
                conclusion: declaredPaths.allSatisfy { alreadyPresent.contains($0) } ? .factoryPathAlreadyPresent : .factoryRegistryEditFailed,
                warnings: Array(Set(warnings)).sorted()
            )
        }
        firstSourcePath = compiledSource.jsonPath
        firstSourcePreview = jsonPreview(compiledSource.row)

        for path in declaredPaths where !factoryRowsContainPath(path, in: compiledDataRows) && !alreadyPresent.contains(path) {
            let addedRow = clonedFactoryRegistryRow(compiledSource, factoryPath: path)
            guard factoryRegistryRowMatchesClone(source: compiledSource.row, clone: addedRow, oldPath: compiledSource.pathValue, newPath: factoryRegistryPathForStyle(path, like: compiledSource.pathValue)) else {
                warnings.append("CompiledData clone validation failed for \(path); row was not added.")
                continue
            }
            compiledDataRows.append(addedRow)
            rowsAddedCompiledData += 1
            addedPaths.append(path)
            if firstAddedPreview == nil {
                firstAddedPreview = jsonPreview(addedRow)
            }
        }
        rootChunk["compiledData"] = compiledDataRows

        var dataRowsAfter = dataRowsBefore
        if var dataRows = originalDataRows {
            if dataRows.isEmpty {
                warnings.append("$.Data.RootChunk.data exists but has no rows; data was not edited.")
            } else if let dataSource = factoryRegistrySourceRow(in: dataRows, arrayPath: "$.Data.RootChunk.data"),
                      factoryRegistryRowsAreCompatible(compiledSource.row, dataSource.row) {
                for path in declaredPaths where !factoryRowsContainPath(path, in: dataRows) && !alreadyPresent.contains(path) {
                    let addedRow = clonedFactoryRegistryRow(dataSource, factoryPath: path)
                    guard factoryRegistryRowMatchesClone(source: dataSource.row, clone: addedRow, oldPath: dataSource.pathValue, newPath: factoryRegistryPathForStyle(path, like: dataSource.pathValue)) else {
                        warnings.append("Data clone validation failed for \(path); row was not added to data.")
                        continue
                    }
                    dataRows.append(addedRow)
                    rowsAddedData += 1
                    addedPaths.append(path)
                }
                dataRowsAfter = dataRows.count
                rootChunk["data"] = dataRows
            } else {
                warnings.append("$.Data.RootChunk.data exists but does not have the same compatible factory row structure; data was not edited.")
            }
        }
        let compiledDataRowsAfter = compiledDataRows.count

        let uniqueAddedPaths = orderedUnique(addedPaths)
        guard !uniqueAddedPaths.isEmpty else {
            let conclusion: AddonProbeXLFactoryRegistryStageConclusion = declaredPaths.allSatisfy { alreadyPresent.contains($0) }
                ? .factoryPathAlreadyPresent
                : .factoryRegistryEditFailed
            return AddonProbeXLFactoryRegistryEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: alreadyPresent,
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: firstSourcePath,
                clonedSourceRowPreview: firstSourcePreview,
                addedRowPreview: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsAfter,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsAfter,
                editedJSONData: nil,
                conclusion: conclusion,
                warnings: Array(Set(warnings)).sorted()
            )
        }

        dataObject["RootChunk"] = rootChunk
        root["Data"] = dataObject
        let editedJSONData = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )
        do {
            _ = try JSONSerialization.jsonObject(with: editedJSONData, options: [])
        } catch {
            throw CyberMacError.invalidInput("Edited factories.csv JSON could not be re-read: \(error.localizedDescription)")
        }
        let expectedCompiledRowsAfter = (compiledDataRowsBefore ?? 0) + rowsAddedCompiledData
        if compiledDataRowsAfter != expectedCompiledRowsAfter {
            warnings.append("compiledData row count changed unexpectedly: before \(compiledDataRowsBefore ?? -1), after \(compiledDataRowsAfter), expected \(expectedCompiledRowsAfter).")
        }
        if let dataRowsBefore {
            let expectedDataRowsAfter = dataRowsBefore + rowsAddedData
            if dataRowsAfter != expectedDataRowsAfter {
                warnings.append("data row count changed unexpectedly: before \(dataRowsBefore), after \(dataRowsAfter ?? -1), expected \(expectedDataRowsAfter).")
            }
        }
        return AddonProbeXLFactoryRegistryEditResult(
            declaredFactoryPaths: declaredPaths,
            alreadyPresentFactoryPaths: alreadyPresent,
            addedFactoryPaths: uniqueAddedPaths,
            rowsAddedCompiledData: rowsAddedCompiledData,
            rowsAddedData: rowsAddedData,
            clonedSourceRowPath: firstSourcePath,
            clonedSourceRowPreview: firstSourcePreview,
            addedRowPreview: firstAddedPreview,
            compiledDataRowsBefore: compiledDataRowsBefore,
            compiledDataRowsAfter: compiledDataRowsAfter,
            dataRowsBefore: dataRowsBefore,
            dataRowsAfter: dataRowsAfter,
            editedJSONData: editedJSONData,
            conclusion: .unresolved,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public static func rawPatchFactoriesJSON(
        originalText: String,
        factoryPaths: [String]
    ) throws -> AddonProbeFactoryRegistryRawEditResult {
        let declaredPaths = orderedUnique(factoryPaths.map(normalizedFactoryResourceDisplayPath))
        var warnings: [String] = []

        let scanner = try JSONRawTextScanner(text: originalText)
        let compiledLocation = scanner.locateArrayByKeyPath(["Data", "RootChunk", "compiledData"])
        let dataLocation = scanner.locateArrayByKeyPath(["Data", "RootChunk", "data"])

        let compiledRowRanges = compiledLocation.map { scanner.splitArrayRows(openOffset: $0.openOffset, closeOffset: $0.closeOffset) } ?? []
        let dataRowRanges = dataLocation.map { scanner.splitArrayRows(openOffset: $0.openOffset, closeOffset: $0.closeOffset) } ?? []

        let compiledDataRowsBefore = compiledLocation == nil ? nil : compiledRowRanges.count
        let dataRowsBefore = dataLocation == nil ? nil : dataRowRanges.count

        if compiledLocation == nil {
            warnings.append("$.Data.RootChunk.compiledData is absent; factories.csv was not edited.")
            return AddonProbeFactoryRegistryRawEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: [],
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: nil,
                clonedSourceRowText: nil,
                addedRowText: nil,
                compiledDataRowsBefore: nil,
                compiledDataRowsAfter: nil,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                compiledDataInsertion: nil,
                dataInsertion: nil,
                editedJSONText: nil,
                conclusion: .factoryRegistryEditFailed,
                warnings: orderedUnique(warnings)
            )
        }
        if dataLocation == nil {
            warnings.append("$.Data.RootChunk.data is absent; only $.Data.RootChunk.compiledData was considered.")
        }

        let compiledRows = compiledRowRanges.map { range -> RawArrayRow in
            RawArrayRow(byteRange: range, text: scanner.substring(byteRange: range))
        }
        let dataRows = dataRowRanges.map { range -> RawArrayRow in
            RawArrayRow(byteRange: range, text: scanner.substring(byteRange: range))
        }

        let alreadyPresent = declaredPaths.filter { path in
            rawRowsContainPath(path, in: compiledRows) || rawRowsContainPath(path, in: dataRows)
        }
        if !alreadyPresent.isEmpty && alreadyPresent.count == declaredPaths.count {
            return AddonProbeFactoryRegistryRawEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: alreadyPresent,
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: nil,
                clonedSourceRowText: nil,
                addedRowText: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsBefore,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                compiledDataInsertion: nil,
                dataInsertion: nil,
                editedJSONText: nil,
                conclusion: .factoryPathAlreadyPresent,
                warnings: orderedUnique(warnings)
            )
        }

        guard let compiledSource = pickFactorySourceRow(in: compiledRows, arrayPath: "$.Data.RootChunk.compiledData") else {
            warnings.append("No compatible .csv-shaped source row was found in $.Data.RootChunk.compiledData; factories.csv was not edited.")
            return AddonProbeFactoryRegistryRawEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: alreadyPresent,
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: nil,
                clonedSourceRowText: nil,
                addedRowText: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsBefore,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                compiledDataInsertion: nil,
                dataInsertion: nil,
                editedJSONText: nil,
                conclusion: .factoryRegistryEditFailed,
                warnings: orderedUnique(warnings)
            )
        }
        let dataSource = pickFactorySourceRow(in: dataRows, arrayPath: "$.Data.RootChunk.data")
        if !dataRows.isEmpty && dataSource == nil {
            warnings.append("$.Data.RootChunk.data exists but does not contain a compatible .csv-shaped source row; data was not edited.")
        }

        var insertions: [TextInsertion] = []
        var compiledInsertionInfo: AddonProbeFactoryRegistryRawInsertion?
        var dataInsertionInfo: AddonProbeFactoryRegistryRawInsertion?
        var addedPaths: [String] = []
        var rowsAddedCompiledData = 0
        var rowsAddedData = 0
        var firstAddedRowText: String?

        let pathsToInsert = declaredPaths.filter { !alreadyPresent.contains($0) }
        for path in pathsToInsert {
            let pathStyled = styledFactoryPath(path, like: compiledSource.sourcePathStringDecoded)
            guard let cloned = clonedRowText(sourceRow: compiledSource, withNewPath: pathStyled) else {
                warnings.append("Could not splice path \(path) into compiledData source row; row was not added.")
                continue
            }
            let insertion = buildRowInsertion(
                sourceRow: compiledSource,
                clonedRowText: cloned,
                originalText: originalText
            )
            insertions.append(insertion)
            rowsAddedCompiledData += 1
            addedPaths.append(path)
            if firstAddedRowText == nil {
                firstAddedRowText = cloned
            }
        }
        if let firstCompiledInsertion = insertions.first {
            let (line, _) = lineAndColumn(for: firstCompiledInsertion.byteOffset, in: originalText)
            compiledInsertionInfo = AddonProbeFactoryRegistryRawInsertion(
                arrayPath: "$.Data.RootChunk.compiledData",
                insertionOffset: firstCompiledInsertion.byteOffset,
                insertionLine: line,
                context: contextAround(byteOffset: firstCompiledInsertion.byteOffset, in: originalText)
            )
        }

        if let dataSource {
            let preInsertCount = insertions.count
            for path in pathsToInsert {
                let pathStyled = styledFactoryPath(path, like: dataSource.sourcePathStringDecoded)
                guard let cloned = clonedRowText(sourceRow: dataSource, withNewPath: pathStyled) else {
                    warnings.append("Could not splice path \(path) into data source row; row was not added to data.")
                    continue
                }
                let insertion = buildRowInsertion(
                    sourceRow: dataSource,
                    clonedRowText: cloned,
                    originalText: originalText
                )
                insertions.append(insertion)
                rowsAddedData += 1
            }
            if insertions.count > preInsertCount {
                let firstDataInsertion = insertions[preInsertCount]
                let (line, _) = lineAndColumn(for: firstDataInsertion.byteOffset, in: originalText)
                dataInsertionInfo = AddonProbeFactoryRegistryRawInsertion(
                    arrayPath: "$.Data.RootChunk.data",
                    insertionOffset: firstDataInsertion.byteOffset,
                    insertionLine: line,
                    context: contextAround(byteOffset: firstDataInsertion.byteOffset, in: originalText)
                )
            }
        }

        let uniqueAddedPaths = orderedUnique(addedPaths)
        guard !insertions.isEmpty else {
            let conclusion: AddonProbeXLFactoryRegistryStageConclusion =
                alreadyPresent.count == declaredPaths.count && !alreadyPresent.isEmpty
                ? .factoryPathAlreadyPresent
                : .factoryRegistryEditFailed
            return AddonProbeFactoryRegistryRawEditResult(
                declaredFactoryPaths: declaredPaths,
                alreadyPresentFactoryPaths: alreadyPresent,
                addedFactoryPaths: [],
                rowsAddedCompiledData: 0,
                rowsAddedData: 0,
                clonedSourceRowPath: compiledSource.jsonPath,
                clonedSourceRowText: compiledSource.text,
                addedRowText: nil,
                compiledDataRowsBefore: compiledDataRowsBefore,
                compiledDataRowsAfter: compiledDataRowsBefore,
                dataRowsBefore: dataRowsBefore,
                dataRowsAfter: dataRowsBefore,
                compiledDataInsertion: nil,
                dataInsertion: nil,
                editedJSONText: nil,
                conclusion: conclusion,
                warnings: orderedUnique(warnings)
            )
        }

        let editedText = applyTextInsertions(originalText: originalText, insertions: insertions)
        do {
            _ = try JSONSerialization.jsonObject(with: Data(editedText.utf8), options: [])
        } catch {
            throw CyberMacError.invalidInput("Edited factories.csv JSON could not be re-parsed: \(error.localizedDescription)")
        }

        let editedCompiledRowsAfter = (compiledDataRowsBefore ?? 0) + rowsAddedCompiledData
        let editedDataRowsAfter = dataRowsBefore.map { $0 + rowsAddedData }

        return AddonProbeFactoryRegistryRawEditResult(
            declaredFactoryPaths: declaredPaths,
            alreadyPresentFactoryPaths: alreadyPresent,
            addedFactoryPaths: uniqueAddedPaths,
            rowsAddedCompiledData: rowsAddedCompiledData,
            rowsAddedData: rowsAddedData,
            clonedSourceRowPath: compiledSource.jsonPath,
            clonedSourceRowText: compiledSource.text,
            addedRowText: firstAddedRowText,
            compiledDataRowsBefore: compiledDataRowsBefore,
            compiledDataRowsAfter: editedCompiledRowsAfter,
            dataRowsBefore: dataRowsBefore,
            dataRowsAfter: editedDataRowsAfter,
            compiledDataInsertion: compiledInsertionInfo,
            dataInsertion: dataInsertionInfo,
            editedJSONText: editedText,
            conclusion: .unresolved,
            warnings: orderedUnique(warnings)
        )
    }

    private struct RawArrayRow: Equatable {
        let byteRange: Range<Int>
        let text: String
    }

    private struct RawFactoryRegistrySourceRow {
        let arrayPath: String
        let rowIndex: Int
        let byteRange: Range<Int>
        let text: String
        let sourcePathStringDecoded: String
        let sourcePathStringByteRange: Range<Int>

        var jsonPath: String { "\(arrayPath)[\(rowIndex)]" }
    }

    private struct TextInsertion {
        let byteOffset: Int
        let insertedText: String
    }

    private static func pickFactorySourceRow(in rows: [RawArrayRow], arrayPath: String) -> RawFactoryRegistrySourceRow? {
        let preferredPath = "base/gameplay/factories/items/clothing.csv"
        var fallback: RawFactoryRegistrySourceRow?
        for (rowIndex, row) in rows.enumerated() {
            let strings = extractRawJSONStrings(in: row.text, baseOffset: row.byteRange.lowerBound)
            let csvStrings = strings.filter { entry in
                normalizedFactoryResourceDisplayPath(entry.decoded).lowercased().contains(".csv")
            }
            guard let firstCSV = csvStrings.first else { continue }
            if csvStrings.contains(where: { normalizedFactoryResourceDisplayPath($0.decoded).lowercased() == preferredPath }) {
                let preferred = csvStrings.first { normalizedFactoryResourceDisplayPath($0.decoded).lowercased() == preferredPath }!
                return RawFactoryRegistrySourceRow(
                    arrayPath: arrayPath,
                    rowIndex: rowIndex,
                    byteRange: row.byteRange,
                    text: row.text,
                    sourcePathStringDecoded: preferred.decoded,
                    sourcePathStringByteRange: preferred.byteRange
                )
            }
            if fallback == nil {
                fallback = RawFactoryRegistrySourceRow(
                    arrayPath: arrayPath,
                    rowIndex: rowIndex,
                    byteRange: row.byteRange,
                    text: row.text,
                    sourcePathStringDecoded: firstCSV.decoded,
                    sourcePathStringByteRange: firstCSV.byteRange
                )
            }
        }
        return fallback
    }

    private static func rawRowsContainPath(_ path: String, in rows: [RawArrayRow]) -> Bool {
        let normalized = normalizedFactoryResourceDisplayPath(path).lowercased()
        guard !rows.isEmpty else { return false }
        for row in rows {
            for entry in extractRawJSONStrings(in: row.text, baseOffset: row.byteRange.lowerBound) {
                if normalizedFactoryResourceDisplayPath(entry.decoded).lowercased() == normalized {
                    return true
                }
            }
        }
        return false
    }

    private static func styledFactoryPath(_ path: String, like sourcePath: String) -> String {
        let normalized = normalizedFactoryResourceDisplayPath(path)
        return sourcePath.contains("\\") ? normalized.replacingOccurrences(of: "/", with: "\\") : normalized
    }

    private static func clonedRowText(sourceRow: RawFactoryRegistrySourceRow, withNewPath newPath: String) -> String? {
        let rowText = sourceRow.text
        let rowStart = sourceRow.byteRange.lowerBound
        let stringStartLocal = sourceRow.sourcePathStringByteRange.lowerBound - rowStart
        let stringEndLocal = sourceRow.sourcePathStringByteRange.upperBound - rowStart
        let utf8 = Array(rowText.utf8)
        guard stringStartLocal >= 0, stringEndLocal <= utf8.count, stringStartLocal < stringEndLocal else {
            return nil
        }
        let newLiteral = encodeJSONStringLiteral(newPath)
        let prefixBytes = Array(utf8[0..<stringStartLocal])
        let suffixBytes = Array(utf8[stringEndLocal..<utf8.count])
        let prefix = String(bytes: prefixBytes, encoding: .utf8) ?? ""
        let suffix = String(bytes: suffixBytes, encoding: .utf8) ?? ""
        return prefix + newLiteral + suffix
    }

    private static func buildRowInsertion(
        sourceRow: RawFactoryRegistrySourceRow,
        clonedRowText: String,
        originalText: String
    ) -> TextInsertion {
        let utf8 = Array(originalText.utf8)
        let insertionOffset = sourceRow.byteRange.upperBound
        let indent = leadingIndentationBeforeRow(rowStart: sourceRow.byteRange.lowerBound, in: utf8)
        let inserted = ",\n" + indent + clonedRowText
        return TextInsertion(byteOffset: insertionOffset, insertedText: inserted)
    }

    private static func leadingIndentationBeforeRow(rowStart: Int, in utf8: [UInt8]) -> String {
        var i = rowStart - 1
        var spaces = 0
        while i >= 0 {
            let c = utf8[i]
            if c == 0x20 || c == 0x09 {
                spaces += 1
                i -= 1
                continue
            }
            break
        }
        if i >= 0 && utf8[i] == 0x0A {
            return String(repeating: " ", count: spaces)
        }
        return ""
    }

    private static func applyTextInsertions(originalText: String, insertions: [TextInsertion]) -> String {
        let sorted = insertions.sorted { $0.byteOffset > $1.byteOffset }
        var utf8 = Array(originalText.utf8)
        for insertion in sorted {
            let bytes = Array(insertion.insertedText.utf8)
            utf8.insert(contentsOf: bytes, at: insertion.byteOffset)
        }
        return String(bytes: utf8, encoding: .utf8) ?? originalText
    }

    private static func lineAndColumn(for byteOffset: Int, in text: String) -> (line: Int, column: Int) {
        let utf8 = Array(text.utf8)
        let clamped = min(max(byteOffset, 0), utf8.count)
        var line = 1
        var col = 1
        for i in 0..<clamped {
            if utf8[i] == 0x0A {
                line += 1
                col = 1
            } else {
                col += 1
            }
        }
        return (line, col)
    }

    private static func contextAround(byteOffset: Int, in text: String, lineRadius: Int = 2) -> String {
        let utf8 = Array(text.utf8)
        let clamped = min(max(byteOffset, 0), utf8.count)
        var start = clamped
        var newlinesBack = 0
        while start > 0 {
            start -= 1
            if utf8[start] == 0x0A {
                newlinesBack += 1
                if newlinesBack > lineRadius {
                    start += 1
                    break
                }
            }
        }
        var end = clamped
        var newlinesForward = 0
        while end < utf8.count {
            if utf8[end] == 0x0A {
                newlinesForward += 1
                if newlinesForward > lineRadius {
                    break
                }
            }
            end += 1
        }
        let slice = Array(utf8[start..<end])
        return String(bytes: slice, encoding: .utf8) ?? ""
    }

    private static func encodeJSONStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: [.withoutEscapingSlashes]),
              let encoded = String(data: data, encoding: .utf8),
              encoded.hasPrefix("[") else {
            var escaped = "\""
            for char in value {
                switch char {
                case "\\": escaped += "\\\\"
                case "\"": escaped += "\\\""
                case "\n": escaped += "\\n"
                case "\r": escaped += "\\r"
                case "\t": escaped += "\\t"
                default: escaped.append(char)
                }
            }
            escaped += "\""
            return escaped
        }
        let trimmed = encoded.dropFirst().dropLast()
        return String(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeJSONStringLiteral(_ literal: String) -> String? {
        let wrapper = "[\(literal)]"
        guard let array = try? JSONSerialization.jsonObject(with: Data(wrapper.utf8), options: []) as? [Any],
              let first = array.first as? String else {
            return nil
        }
        return first
    }

    private struct RawJSONStringEntry: Equatable {
        let decoded: String
        let byteRange: Range<Int>
    }

    private static func extractRawJSONStrings(in text: String, baseOffset: Int) -> [RawJSONStringEntry] {
        let utf8 = Array(text.utf8)
        var result: [RawJSONStringEntry] = []
        var i = 0
        while i < utf8.count {
            let c = utf8[i]
            if c == 0x22 {
                let start = i
                let end = skipJSONString(in: utf8, from: i)
                let literalBytes = Array(utf8[start..<end])
                if let literal = String(bytes: literalBytes, encoding: .utf8),
                   let decoded = decodeJSONStringLiteral(literal) {
                    result.append(RawJSONStringEntry(
                        decoded: decoded,
                        byteRange: (baseOffset + start)..<(baseOffset + end)
                    ))
                }
                i = end
                continue
            }
            i += 1
        }
        return result
    }

    private static func skipJSONString(in utf8: [UInt8], from start: Int) -> Int {
        var i = start + 1
        while i < utf8.count {
            let c = utf8[i]
            if c == 0x5C {
                i += 2
                continue
            }
            if c == 0x22 {
                return i + 1
            }
            i += 1
        }
        return i
    }

    struct JSONRawTextScanner {
        let utf8: [UInt8]

        init(text: String) throws {
            self.utf8 = Array(text.utf8)
            do {
                _ = try JSONSerialization.jsonObject(with: Data(utf8), options: [])
            } catch {
                throw CyberMacError.invalidInput("Original decoded factories.csv JSON could not be parsed: \(error.localizedDescription)")
            }
        }

        func substring(byteRange: Range<Int>) -> String {
            guard byteRange.lowerBound >= 0,
                  byteRange.upperBound <= utf8.count,
                  byteRange.lowerBound <= byteRange.upperBound else {
                return ""
            }
            let slice = Array(utf8[byteRange])
            return String(bytes: slice, encoding: .utf8) ?? ""
        }

        func locateArrayByKeyPath(_ keyPath: [String]) -> (openOffset: Int, closeOffset: Int)? {
            var i = 0
            var pathSoFar: [String] = []
            var stack: [Frame] = []

            while i < utf8.count {
                let c = utf8[i]
                if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                    i += 1
                    continue
                }
                if c == 0x22 {
                    let stringEnd = AddonProbeManager.skipJSONString(in: utf8, from: i)
                    let literalBytes = Array(utf8[i..<stringEnd])
                    if let literal = String(bytes: literalBytes, encoding: .utf8),
                       let last = stack.last,
                       last.kind == .object,
                       last.pendingKey == nil,
                       AddonProbeManager.decodeJSONStringLiteral(literal) != nil {
                        var j = stringEnd
                        while j < utf8.count {
                            let nc = utf8[j]
                            if nc == 0x20 || nc == 0x09 || nc == 0x0A || nc == 0x0D {
                                j += 1
                                continue
                            }
                            break
                        }
                        if j < utf8.count && utf8[j] == 0x3A {
                            j += 1
                            stack[stack.count - 1].pendingKey = AddonProbeManager.decodeJSONStringLiteral(literal)
                            i = j
                            continue
                        }
                    }
                    if let last = stack.last, last.kind == .object {
                        stack[stack.count - 1].pendingKey = nil
                    }
                    i = stringEnd
                    continue
                }
                if c == 0x7B {
                    var pushedKey = false
                    if let last = stack.last,
                       last.kind == .object,
                       let key = last.pendingKey {
                        pathSoFar.append(key)
                        pushedKey = true
                    }
                    stack.append(Frame(kind: .object, pendingKey: nil, pushedKey: pushedKey))
                    i += 1
                    continue
                }
                if c == 0x5B {
                    if let last = stack.last,
                       last.kind == .object,
                       let key = last.pendingKey {
                        if pathSoFar + [key] == keyPath {
                            let closeOffset = findMatchingClose(openOffset: i)
                            return (i, closeOffset)
                        }
                        pathSoFar.append(key)
                        stack.append(Frame(kind: .array, pendingKey: nil, pushedKey: true))
                    } else {
                        stack.append(Frame(kind: .array, pendingKey: nil, pushedKey: false))
                    }
                    i += 1
                    continue
                }
                if c == 0x7D || c == 0x5D {
                    if let popped = stack.popLast(), popped.pushedKey, !pathSoFar.isEmpty {
                        pathSoFar.removeLast()
                    }
                    if let last = stack.last, last.kind == .object {
                        stack[stack.count - 1].pendingKey = nil
                    }
                    i += 1
                    continue
                }
                if c == 0x2C {
                    if let last = stack.last, last.kind == .object {
                        stack[stack.count - 1].pendingKey = nil
                    }
                    i += 1
                    continue
                }
                if c == 0x3A {
                    i += 1
                    continue
                }
                i = skipPrimitiveValue(from: i)
                if let last = stack.last, last.kind == .object {
                    stack[stack.count - 1].pendingKey = nil
                }
            }
            return nil
        }

        func splitArrayRows(openOffset: Int, closeOffset: Int) -> [Range<Int>] {
            var rows: [Range<Int>] = []
            var i = openOffset + 1
            while i < closeOffset {
                let c = utf8[i]
                if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x2C {
                    i += 1
                    continue
                }
                let rowStart = i
                let rowEnd: Int
                if c == 0x7B || c == 0x5B {
                    rowEnd = findMatchingClose(openOffset: i) + 1
                } else if c == 0x22 {
                    rowEnd = AddonProbeManager.skipJSONString(in: utf8, from: i)
                } else {
                    rowEnd = skipPrimitiveValue(from: i)
                }
                rows.append(rowStart..<rowEnd)
                i = rowEnd
            }
            return rows
        }

        private func findMatchingClose(openOffset: Int) -> Int {
            let openByte = utf8[openOffset]
            let closeByte: UInt8 = openByte == 0x5B ? 0x5D : 0x7D
            var i = openOffset + 1
            while i < utf8.count {
                let c = utf8[i]
                if c == 0x22 {
                    i = AddonProbeManager.skipJSONString(in: utf8, from: i)
                    continue
                }
                if c == 0x7B || c == 0x5B {
                    i = findMatchingClose(openOffset: i) + 1
                    continue
                }
                if c == closeByte {
                    return i
                }
                i += 1
            }
            return i
        }

        private func skipPrimitiveValue(from start: Int) -> Int {
            var i = start
            while i < utf8.count {
                let c = utf8[i]
                if c == 0x2C || c == 0x7D || c == 0x5D || c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                    return i
                }
                i += 1
            }
            return i
        }

        struct Frame {
            var kind: Kind
            var pendingKey: String?
            var pushedKey: Bool
            enum Kind { case object, array }
        }
    }

    public static func parseYAMLishItemIDs(_ text: String) -> [String] {
        sortedMatches(pattern: #"(?m)^\s*['"]?(Items\.[A-Za-z0-9_.-]+)['"]?\s*:"#, text: text)
    }

    public static func parseReferencedItemIDs(_ text: String) -> [String] {
        sortedMatches(pattern: #"Items\.[A-Za-z0-9_.-]+"#, text: text)
    }

    public static func parseTweakDBRecordReferences(from text: String) -> [String] {
        sortedMatches(
            pattern: #"(?:Items|OutfitSlots|Quality|BaseStats|Stats|RPGActionRewards|AttachmentSlots|EquipmentArea|TweakDB)\.[A-Za-z0-9_.-]+"#,
            text: text
        )
    }

    public static func parseCandidateBaseRecords(_ text: String) -> [String] {
        var values = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            let rawLine = String(line)
            guard let colonIndex = rawLine.firstIndex(of: ":") else { continue }
            let key = rawLine[..<colonIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                .lowercased()
            guard key == "$base" ||
                key == "base" ||
                key == "parent" ||
                key.contains("itemtype") ||
                key.contains("appearance")
            else { continue }
            let valueStart = rawLine.index(after: colonIndex)
            let rawValue = String(rawLine[valueStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\",;[]{}"))
            guard !rawValue.isEmpty else { continue }
            values.insert(rawValue)
        }
        return values.sorted()
    }

    public static func parseResourceReferences(_ text: String) -> [String] {
        let pattern = #"[A-Za-z0-9_.$:/\\-]+[./\\][A-Za-z0-9_.$:/\\-]+\.(?:ent|app|mesh|mlsetup|mlmask|xbm|inkatlas)"#
        let normalized = sortedMatches(pattern: pattern, text: text).map {
            $0.replacingOccurrences(of: "\\", with: "/")
        }
        return Array(Set(normalized)).sorted()
    }

    public static func analyzeTweakXL(_ text: String) -> AddonProbeTweakXLAnalysis {
        let templates = parseTweakXLRecordTemplates(text)
        var templatedItemRecords: [String] = []
        var expandedRecords: [AddonProbeExpandedItemRecord] = []
        var baseRecords: [String] = []
        var placementSlots: [String] = []
        var appearanceNames: [String] = []
        var entityNames: [String] = []
        var displayNames: [String] = []
        var iconAtlasPaths: [String] = []
        var iconAtlasParts: [String] = []
        var unresolvedExpressions: [String] = []
        var warnings: [String] = []
        var instanceCount = 0

        for template in templates {
            if template.key.contains("${") {
                templatedItemRecords.append(template.key)
            }
            if let baseRecord = template.baseRecord {
                baseRecords.append(baseRecord)
            }
            placementSlots.append(contentsOf: template.placementSlots)
            if template.key.contains("${"), template.instances.isEmpty {
                warnings.append("Templated item record has no parsed $instances block: \(template.key)")
            }
            unresolvedExpressions.append(contentsOf: template.unresolvedTemplateExpressions)

            for instance in template.instances {
                instanceCount += 1
                let itemExpansion = expandTweakXLTemplate(template.key, variables: instance)
                unresolvedExpressions.append(contentsOf: itemExpansion.unresolvedExpressions)
                guard itemExpansion.unresolvedExpressions.isEmpty,
                      itemExpansion.value.hasPrefix("Items."),
                      !itemExpansion.value.contains("${")
                else {
                    warnings.append("Could not fully expand item record key: \(template.key)")
                    continue
                }

                let appearance = expandedOptionalTemplate(template.appearanceName, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let entity = expandedOptionalTemplate(template.entityName, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let display = expandedOptionalTemplate(template.displayName, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let localizedDescription = expandedOptionalTemplate(template.localizedDescription, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let atlasPart = expandedOptionalTemplate(template.iconAtlasPart, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let quality = expandedOptionalTemplate(template.quality, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                let statModifiers = template.statModifiers.map {
                    expandedTemplate($0, variables: instance, unresolved: &unresolvedExpressions, allowBangExpressions: true)
                }
                let atlasPath = template.iconAtlasPath

                if let appearance { appearanceNames.append(appearance) }
                if let entity { entityNames.append(entity) }
                if let display { displayNames.append(display) }
                if let atlasPath { iconAtlasPaths.append(atlasPath) }
                if let atlasPart { iconAtlasParts.append(atlasPart) }

                expandedRecords.append(AddonProbeExpandedItemRecord(
                    templateRecord: template.key,
                    itemID: itemExpansion.value,
                    instanceVariables: instance,
                    baseRecord: template.baseRecord,
                    placementSlots: template.placementSlots,
                    appearanceName: appearance,
                    entityName: entity,
                    displayName: display,
                    localizedDescription: localizedDescription,
                    iconAtlasPath: atlasPath,
                    iconAtlasPart: atlasPart,
                    quality: quality,
                    statModifiers: orderedUnique(statModifiers)
                ))
            }
        }

        let uniqueUnresolved = orderedUnique(unresolvedExpressions)
        if !uniqueUnresolved.isEmpty {
            warnings.append("Some template expressions could not be expanded conservatively: \(uniqueUnresolved.joined(separator: ", "))")
        }

        return AddonProbeTweakXLAnalysis(
            templatedItemRecords: orderedUnique(templatedItemRecords),
            expandedItemRecords: expandedRecords,
            expandedItemIDs: orderedUnique(expandedRecords.map(\.itemID)),
            baseRecords: orderedUnique(baseRecords),
            placementSlots: orderedUnique(placementSlots),
            appearanceNames: orderedUnique(appearanceNames),
            entityNames: orderedUnique(entityNames),
            displayNames: orderedUnique(displayNames),
            iconAtlasPaths: orderedUnique(iconAtlasPaths),
            iconAtlasParts: orderedUnique(iconAtlasParts),
            instanceCount: instanceCount,
            unresolvedTemplateExpressions: uniqueUnresolved,
            warnings: orderedUnique(warnings)
        )
    }

    public static func analyzeXLMetadata(_ text: String) -> AddonProbeXLMetadataAnalysis {
        let resourcePattern = #"[A-Za-z0-9_.$:/\\-]+\.(?:csv|json)"#
        var factories: [String] = []
        var localizations: [String] = []
        for match in regexMatches(pattern: resourcePattern, text: text) {
            guard let range = Range(match.range, in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\"',;[]{}"))
            if value.lowercased().hasSuffix(".csv") {
                factories.append(value)
            } else if value.lowercased().hasSuffix(".json") {
                localizations.append(value)
            }
        }
        return AddonProbeXLMetadataAnalysis(
            factoryCSVFilesFromXL: orderedUnique(factories),
            localizationJSONFilesFromXL: orderedUnique(localizations)
        )
    }

    public static func parseGrantManyItemIDs(_ text: String) -> [String] {
        orderedItemIDMatches(text)
    }

    public static func parseDirectTweakXLItemIDs(_ text: String) -> [String] {
        parseTweakXLRecordTemplates(text)
            .map(\.key)
            .filter { !$0.contains("${") }
    }

    public static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private static func emptyTweakXLAnalysis() -> AddonProbeTweakXLAnalysis {
        AddonProbeTweakXLAnalysis(
            templatedItemRecords: [],
            expandedItemRecords: [],
            expandedItemIDs: [],
            baseRecords: [],
            placementSlots: [],
            appearanceNames: [],
            entityNames: [],
            displayNames: [],
            iconAtlasPaths: [],
            iconAtlasParts: [],
            instanceCount: 0,
            unresolvedTemplateExpressions: [],
            warnings: []
        )
    }

    private static func mergeTweakXLAnalyses(_ analyses: [AddonProbeTweakXLAnalysis]) -> AddonProbeTweakXLAnalysis {
        guard !analyses.isEmpty else { return emptyTweakXLAnalysis() }
        return AddonProbeTweakXLAnalysis(
            templatedItemRecords: orderedUnique(analyses.flatMap(\.templatedItemRecords)),
            expandedItemRecords: analyses.flatMap(\.expandedItemRecords),
            expandedItemIDs: orderedUnique(analyses.flatMap(\.expandedItemIDs)),
            baseRecords: orderedUnique(analyses.flatMap(\.baseRecords)),
            placementSlots: orderedUnique(analyses.flatMap(\.placementSlots)),
            appearanceNames: orderedUnique(analyses.flatMap(\.appearanceNames)),
            entityNames: orderedUnique(analyses.flatMap(\.entityNames)),
            displayNames: orderedUnique(analyses.flatMap(\.displayNames)),
            iconAtlasPaths: orderedUnique(analyses.flatMap(\.iconAtlasPaths)),
            iconAtlasParts: orderedUnique(analyses.flatMap(\.iconAtlasParts)),
            instanceCount: analyses.reduce(0) { $0 + $1.instanceCount },
            unresolvedTemplateExpressions: orderedUnique(analyses.flatMap(\.unresolvedTemplateExpressions)),
            warnings: orderedUnique(analyses.flatMap(\.warnings))
        )
    }

    private static func mergeXLMetadataAnalyses(_ analyses: [AddonProbeXLMetadataAnalysis]) -> AddonProbeXLMetadataAnalysis {
        AddonProbeXLMetadataAnalysis(
            factoryCSVFilesFromXL: orderedUnique(analyses.flatMap(\.factoryCSVFilesFromXL)),
            localizationJSONFilesFromXL: orderedUnique(analyses.flatMap(\.localizationJSONFilesFromXL))
        )
    }

    private static func parseTweakXLRecordTemplates(_ text: String) -> [TweakXLRecordTemplate] {
        var templates: [TweakXLRecordTemplate] = []
        var current: TweakXLRecordTemplate?
        var inInstances = false
        var currentListKey: String?

        func finishCurrent() {
            guard let current else { return }
            templates.append(current)
        }

        for line in text.components(separatedBy: .newlines) {
            if let key = tweakXLRecordKey(in: line) {
                finishCurrent()
                current = TweakXLRecordTemplate(key: key)
                inInstances = false
                currentListKey = nil
                continue
            }
            guard current != nil else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("$instances:") {
                inInstances = true
                currentListKey = "$instances"
                continue
            }
            if inInstances, trimmed.hasPrefix("-") {
                if let instance = parseInlineYAMLMap(trimmed), !instance.isEmpty {
                    current?.instances.append(instance)
                }
                continue
            }
            if trimmed.hasPrefix("-") {
                let value = normalizedYAMLScalar(String(trimmed.dropFirst()))
                if currentListKey?.lowercased().contains("statmodifier") == true {
                    current?.statModifiers.append(contentsOf: parseTweakDBRecordReferences(from: value))
                    if parseTweakDBRecordReferences(from: value).isEmpty, !value.isEmpty {
                        current?.statModifiers.append(value)
                    }
                }
                if currentListKey?.lowercased().contains("placement") == true,
                   let slot = firstMatch(pattern: #"OutfitSlots\.[A-Za-z0-9_.-]+"#, text: value) {
                    current?.placementSlots.append(slot)
                }
                continue
            }

            if let slot = firstMatch(pattern: #"OutfitSlots\.[A-Za-z0-9_.-]+"#, text: trimmed) {
                current?.placementSlots.append(slot)
            }

            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }
            let rawKey = String(trimmed[..<colonIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let key = rawKey.lowercased()
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...])
            let value = normalizedYAMLScalar(rawValue)
            inInstances = false
            if key.contains("placement") {
                currentListKey = rawKey
            } else if key.contains("statmodifier") {
                currentListKey = rawKey
            } else {
                currentListKey = nil
            }
            guard !value.isEmpty else { continue }

            var knownExpandableScalar = false
            if key == "$base" || key == "base" {
                current?.baseRecord = value
            } else if key.contains("appearancename") {
                current?.appearanceName = value
                knownExpandableScalar = true
            } else if key.contains("entityname") {
                current?.entityName = value
                knownExpandableScalar = true
            } else if key.contains("displayname") {
                current?.displayName = value
                knownExpandableScalar = true
            } else if key.contains("localizeddescription") || (key.contains("description") && !key.contains("display")) {
                current?.localizedDescription = value
                knownExpandableScalar = true
            } else if key.contains("atlasresourcepath") || key.contains("atlaspath") || (key.contains("atlas") && value.lowercased().hasSuffix(".inkatlas")) {
                current?.iconAtlasPath = value
            } else if key.contains("atlaspartname") || key.contains("atlaspart") {
                current?.iconAtlasPart = value
                knownExpandableScalar = true
            } else if key == "quality" || key.hasSuffix(".quality") || key.contains("quality") {
                current?.quality = value
                knownExpandableScalar = true
            } else if key.contains("statmodifier") {
                let modifiers = parseTweakDBRecordReferences(from: value)
                current?.statModifiers.append(contentsOf: modifiers.isEmpty ? [value] : modifiers)
                knownExpandableScalar = true
            }

            if !knownExpandableScalar {
                current?.unresolvedTemplateExpressions.append(contentsOf: unsupportedTemplateExpressions(in: value))
            }
        }
        finishCurrent()
        return templates
    }

    private static func tweakXLRecordKey(in line: String) -> String? {
        let pattern = #"^\s*['"]?(Items\.[A-Za-z0-9_.${}-]+)['"]?\s*:\s*(?:#.*)?$"#
        guard let match = regexMatches(pattern: pattern, text: line).first,
              let range = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseInlineYAMLMap(_ line: String) -> [String: String]? {
        guard let open = line.firstIndex(of: "{"),
              let close = line.lastIndex(of: "}"),
              open < close
        else {
            return nil
        }
        let body = line[line.index(after: open)..<close]
        var result: [String: String] = [:]
        for pair in body.split(separator: ",") {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            let key = String(pair[..<colon])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let value = normalizedYAMLScalar(String(pair[pair.index(after: colon)...]))
            guard !key.isEmpty, !value.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    private static func normalizedYAMLScalar(_ rawValue: String) -> String {
        var value = rawValue
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
        if value.hasPrefix("!append ") {
            value = String(value.dropFirst("!append ".count))
        }
        if value.hasPrefix("l\""), value.hasSuffix("\"") {
            value = String(value.dropFirst(2).dropLast())
        } else {
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'[]"))
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func expandedOptionalTemplate(
        _ template: String?,
        variables: [String: String],
        unresolved: inout [String],
        allowBangExpressions: Bool = false
    ) -> String? {
        guard let template, !template.isEmpty else { return nil }
        return expandedTemplate(template, variables: variables, unresolved: &unresolved, allowBangExpressions: allowBangExpressions)
    }

    private static func expandedTemplate(
        _ template: String,
        variables: [String: String],
        unresolved: inout [String],
        allowBangExpressions: Bool = false
    ) -> String {
        let expansion = expandTweakXLTemplate(template, variables: variables, allowBangExpressions: allowBangExpressions)
        unresolved.append(contentsOf: expansion.unresolvedExpressions)
        return expansion.value
    }

    private static func expandTweakXLTemplate(
        _ template: String,
        variables: [String: String],
        allowBangExpressions: Bool = false
    ) -> (value: String, unresolvedExpressions: [String]) {
        var output = ""
        var unresolved: [String] = []
        var index = template.startIndex

        while index < template.endIndex {
            if template[index] == "!",
               let next = template.index(index, offsetBy: 1, limitedBy: template.endIndex),
               next < template.endIndex,
               template[next] == "$",
               let brace = template.index(next, offsetBy: 1, limitedBy: template.endIndex),
               brace < template.endIndex,
               template[brace] == "{",
               let close = template[brace...].firstIndex(of: "}") {
                let expression = String(template[index...close])
                let variableStart = template.index(after: brace)
                let variable = String(template[variableStart..<close])
                if allowBangExpressions, let value = variables[variable] {
                    output.append(contentsOf: value)
                } else {
                    unresolved.append(expression)
                    output.append(contentsOf: expression)
                }
                index = template.index(after: close)
                continue
            }

            if template[index] == "$",
               let brace = template.index(index, offsetBy: 1, limitedBy: template.endIndex),
               brace < template.endIndex,
               template[brace] == "{",
               let close = template[brace...].firstIndex(of: "}") {
                let variableStart = template.index(after: brace)
                let variable = String(template[variableStart..<close])
                let expression = String(template[index...close])
                if let value = variables[variable] {
                    output.append(contentsOf: value)
                } else {
                    unresolved.append(expression)
                    output.append(contentsOf: expression)
                }
                index = template.index(after: close)
                continue
            }

            output.append(template[index])
            index = template.index(after: index)
        }

        return (output, orderedUnique(unresolved))
    }

    private static func unsupportedTemplateExpressions(in value: String) -> [String] {
        var expressions: [String] = []
        for match in regexMatches(pattern: #"!\$\{[A-Za-z0-9_]+\}"#, text: value) {
            guard let range = Range(match.range, in: value) else { continue }
            expressions.append(String(value[range]))
        }
        return orderedUnique(expressions)
    }

    private static func orderedItemIDMatches(_ text: String) -> [String] {
        var values: [String] = []
        for match in regexMatches(pattern: #"Items\.[A-Za-z0-9_.-]+"#, text: text) {
            guard let range = Range(match.range, in: text) else { continue }
            values.append(String(text[range]))
        }
        return orderedUnique(values)
    }

    private static func firstMatch(pattern: String, text: String) -> String? {
        guard let match = regexMatches(pattern: pattern, text: text).first else { return nil }
        let rangeIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let range = Range(match.range(at: rangeIndex), in: text) else { return nil }
        return String(text[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"',;[]{}"))
    }

    private static func factoryResourceMagic(_ data: Data) -> AddonProbeFactoryResourceMagic {
        guard !data.isEmpty else { return .empty }
        if data.starts(with: Data([0x43, 0x52, 0x32, 0x57])) {
            return .cr2w
        }
        if data.starts(with: Data([0x4B, 0x41, 0x52, 0x4B])) {
            return .kark
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return .unknownBinary
        }
        let allowedControls = CharacterSet(charactersIn: "\n\r\t")
        for scalar in text.unicodeScalars {
            if scalar.value < 0x20 && !allowedControls.contains(scalar) {
                return .unknownBinary
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            let jsonData = Data(trimmed.utf8)
            if (try? JSONSerialization.jsonObject(with: jsonData, options: [])) != nil {
                return .jsonText
            }
        }
        return .utf8Text
    }

    private static func hexPrefix(_ data: Data, count: Int) -> String {
        data.prefix(count).map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func parseCSV(_ text: String) -> (headers: [String], rows: [[String: String]], warnings: [String]) {
        guard !text.isEmpty else {
            return ([], [], ["CSV is empty."])
        }

        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var warnings: [String] = []
        let characters = Array(text)
        var index = 0

        func finishField() {
            fields.append(field)
            field = ""
        }

        func finishRecord() {
            finishField()
            if fields.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                records.append(fields)
            }
            fields = []
        }

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if inQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 2
                    continue
                }
                inQuotes.toggle()
                index += 1
                continue
            }

            if character == "," && !inQuotes {
                finishField()
                index += 1
                continue
            }

            if (character == "\n" || character == "\r") && !inQuotes {
                finishRecord()
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 2
                } else {
                    index += 1
                }
                continue
            }

            field.append(character)
            index += 1
        }

        if inQuotes {
            warnings.append("CSV has an unterminated quoted field; parsed best-effort.")
        }
        if !field.isEmpty || !fields.isEmpty {
            finishRecord()
        }

        guard let rawHeaders = records.first else {
            return ([], [], warnings.isEmpty ? ["CSV has no rows."] : warnings)
        }
        let headers = normalizedCSVHeaders(rawHeaders)
        let dataRecords = Array(records.dropFirst())
        var rows: [[String: String]] = []
        for (recordIndex, record) in dataRecords.enumerated() {
            if record.count > headers.count {
                warnings.append("Row \(recordIndex + 1) has \(record.count) cells but only \(headers.count) headers; extra cells were named column_N.")
            }
            var row: [String: String] = [:]
            let maxCount = max(headers.count, record.count)
            for columnIndex in 0..<maxCount {
                let header = columnIndex < headers.count ? headers[columnIndex] : "column_\(columnIndex + 1)"
                row[header] = columnIndex < record.count ? record[columnIndex] : ""
            }
            rows.append(row)
        }

        return (headers, rows, warnings)
    }

    private static func normalizedCSVHeaders(_ rawHeaders: [String]) -> [String] {
        var counts: [String: Int] = [:]
        return rawHeaders.enumerated().map { index, rawHeader in
            let trimmed = rawHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = trimmed.isEmpty ? "column_\(index + 1)" : trimmed
            let count = counts[base, default: 0] + 1
            counts[base] = count
            return count == 1 ? base : "\(base)_\(count)"
        }
    }

    private static func factorySemanticKinds(column: String, value: String) -> [String] {
        let haystack = "\(column) \(value)".lowercased()
        var kinds = Set<String>()
        if haystack.contains("appearance") {
            kinds.insert("appearance names")
        }
        if haystack.contains("factories/") || haystack.contains("factory") || value.lowercased().hasSuffix(".csv") {
            kinds.insert("factory paths")
        }
        if haystack.contains("entity") || haystack.contains(".ent") {
            kinds.insert("entity template paths")
        }
        if haystack.contains("category") || haystack.contains("itemtype") || haystack.contains("item_type") || haystack.contains("type") {
            kinds.insert("item categories")
        }
        if haystack.contains("equipment") || haystack.contains("equipmentarea") {
            kinds.insert("equipment areas")
        }
        for area in ["outerchest", "innerchest", "legs", "feet", "head", "face", "outfit"] where haystack.contains(area) {
            kinds.insert("equipment areas")
        }
        if haystack.contains("garment") || haystack.contains("body") || haystack.contains("slot") {
            kinds.insert("garment/body slots")
        }
        return kinds.sorted()
    }

    private static func referenceTokens(from summary: AddonProbeFactoryCSVSummary) -> Set<String> {
        var tokens = Set<String>()
        for detection in summary.itemIDDetections {
            tokens.formUnion(detection.matches)
        }
        for detection in summary.resourcePathDetections {
            tokens.formUnion(detection.matches)
        }
        for detection in summary.semanticDetections {
            let value = detection.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 3 {
                tokens.insert(value)
            }
        }
        let preferredHeaders = summary.headers.filter { header in
            let lower = header.lowercased()
            return lower == "id" ||
                lower == "name" ||
                lower.contains("item") ||
                lower.contains("appearance") ||
                lower.contains("factory") ||
                lower.contains("entity")
        }
        for row in summary.representativeRows {
            for header in preferredHeaders {
                let value = row[header]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if value.count >= 3 {
                    tokens.insert(value)
                }
            }
        }
        return tokens
    }

    private static func crossReferences(
        relationship: String,
        from: AddonProbeFactoryCSVSummary,
        to: AddonProbeFactoryCSVSummary,
        tokens: Set<String>,
        limit: Int
    ) -> [AddonProbeFactoryCrossReference] {
        var references: [AddonProbeFactoryCrossReference] = []
        for token in tokens.sorted() where references.count < limit {
            let rows = matchingRowIndices(in: from, token: token)
            guard !rows.isEmpty else { continue }
            references.append(AddonProbeFactoryCrossReference(
                relationship: relationship,
                fromCSV: from.resourcePath,
                toCSV: to.resourcePath,
                token: token,
                fromRows: rows
            ))
        }
        return references
    }

    private static func matchingRowIndices(in summary: AddonProbeFactoryCSVSummary, token: String) -> [Int] {
        let normalizedToken = token.lowercased()
        guard !normalizedToken.isEmpty else { return [] }
        var matches = Set<Int>()
        for detection in summary.itemIDDetections where detection.value.lowercased().contains(normalizedToken) {
            matches.insert(detection.rowIndex)
        }
        for detection in summary.tweakDBDetections where detection.value.lowercased().contains(normalizedToken) {
            matches.insert(detection.rowIndex)
        }
        for detection in summary.resourcePathDetections where detection.value.lowercased().contains(normalizedToken) {
            matches.insert(detection.rowIndex)
        }
        for detection in summary.semanticDetections where detection.value.lowercased().contains(normalizedToken) {
            matches.insert(detection.rowIndex)
        }
        for known in summary.knownVanillaItemRows where known.itemID.lowercased().contains(normalizedToken) {
            matches.insert(known.rowIndex)
        }
        for (index, row) in summary.representativeRows.enumerated() {
            if row.values.contains(where: { $0.lowercased().contains(normalizedToken) }) {
                matches.insert(index + 1)
            }
        }
        return matches.sorted()
    }

    public static func recordLayerSearchCommands(databaseURL: URL, limit: Int) -> [String] {
        AddonProbeRecordLayerSearchReport.queries.map {
            recordLayerSearchCommand(query: $0, databaseURL: databaseURL, limit: limit)
        }
    }

    private static func recordLayerSearchCommand(query: String, databaseURL: URL, limit: Int) -> String {
        "swift run cybermac archive-catalog index search \(PathSafety.shellQuoted(query)) --db \(PathSafety.shellQuoted(databaseURL.path)) --limit \(limit)"
    }

    private func makeInspectReport(discovery: Discovery, writtenReportPath: String?) -> AddonProbeInspectReport {
        AddonProbeInspectReport(
            sourceModPath: discovery.root.sourceURL.path,
            inspectedRootPath: discovery.root.rootURL.path,
            inputKind: discovery.root.inputKind,
            archiveFiles: discovery.archiveFiles,
            xlFiles: discovery.xlFiles,
            tweakFiles: discovery.tweakFiles,
            csvFiles: discovery.csvFiles,
            jsonLocalizationFiles: discovery.jsonFiles,
            candidateItemIDs: discovery.candidateItemIDs,
            referencedItemIDs: discovery.referencedItemIDs,
            candidateBaseRecords: discovery.candidateBaseRecords,
            candidateResourceReferences: discovery.candidateResourceReferences,
            templatedItemRecords: discovery.tweakXLAnalysis.templatedItemRecords,
            expandedItemRecords: discovery.tweakXLAnalysis.expandedItemRecords,
            expandedItemIDs: discovery.tweakXLAnalysis.expandedItemIDs,
            baseRecords: discovery.tweakXLAnalysis.baseRecords,
            placementSlots: discovery.tweakXLAnalysis.placementSlots,
            appearanceNames: discovery.tweakXLAnalysis.appearanceNames,
            entityNames: discovery.tweakXLAnalysis.entityNames,
            displayNames: discovery.tweakXLAnalysis.displayNames,
            iconAtlasPaths: discovery.tweakXLAnalysis.iconAtlasPaths,
            iconAtlasParts: discovery.tweakXLAnalysis.iconAtlasParts,
            instanceCount: discovery.tweakXLAnalysis.instanceCount,
            unresolvedTemplateExpressions: discovery.tweakXLAnalysis.unresolvedTemplateExpressions,
            factoryCSVFilesFromXL: discovery.xlMetadataAnalysis.factoryCSVFilesFromXL,
            localizationJSONFilesFromXL: discovery.xlMetadataAnalysis.localizationJSONFilesFromXL,
            classification: discovery.classification,
            reasons: discovery.reasons,
            warnings: discovery.warnings,
            writtenReportPath: writtenReportPath
        )
    }

    private func resolveModRoot(_ rawURL: URL) throws -> ResolvedModRoot {
        let url = rawURL.standardizedFileURL
        try validateLocalURL(url, description: "Mod path")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("Mod path does not exist: \(url.path)")
        }

        if isDirectory.boolValue {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("Mod folder must not be a symlink: \(url.path)")
            }
            return ResolvedModRoot(sourceURL: url, rootURL: url, inputKind: .directory, warnings: [])
        }

        guard url.pathExtension.lowercased() == "zip" else {
            throw CyberMacError.invalidInput("addon-probe accepts an unpacked mod folder or a .zip file: \(url.path)")
        }
        try PathSafety.validateArchiveSize(url)
        let extractionRoot = home.archiveProbeTmpURL
            .appendingPathComponent("addon-probe-\(stageID())", isDirectory: true)
            .appendingPathComponent("unzipped", isDirectory: true)
        try unzip(url, to: extractionRoot)
        return ResolvedModRoot(
            sourceURL: url,
            rootURL: extractionRoot,
            inputKind: .zip,
            warnings: ["Zip input was extracted to CyberMac probe temp storage: \(extractionRoot.path)"]
        )
    }

    private func unzip(_ zipURL: URL, to destinationURL: URL) throws {
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw CyberMacError.invalidInput("Could not open zip archive: \(zipURL.path): \(error.localizedDescription)")
        }
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        var entryCount = 0
        for entry in archive {
            entryCount += 1
            guard entryCount <= PathSafety.maxArchiveEntries else {
                throw CyberMacError.invalidInput("Zip has too many entries: limit is \(PathSafety.maxArchiveEntries)")
            }
            try PathSafety.validateArchivePath(entry.path)
            let targetURL = destinationURL.appendingPathComponent(entry.path)
            try PathSafety.validateContainedPath(targetURL, in: destinationURL)
            switch entry.type {
            case .directory:
                try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            case .file:
                try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: targetURL)
            case .symlink:
                throw CyberMacError.unsafePath("Zip contains symlink: \(entry.path)")
            }
        }
    }

    private func discover(root: ResolvedModRoot) throws -> Discovery {
        let allFiles = try regularFiles(under: root.rootURL, description: "Mod folder")
        var archiveFiles: [String] = []
        var xlFiles: [String] = []
        var tweakFiles: [String] = []
        var csvFiles: [String] = []
        var jsonFiles: [String] = []
        var textFilesForParsing: [URL] = []
        var tweakTextFiles: [URL] = []
        var xlTextFiles: [URL] = []

        for file in allFiles {
            let lower = file.relativePath.lowercased()
            if lower.hasSuffix(".archive") {
                archiveFiles.append(file.relativePath)
            }
            if lower.hasSuffix(".archive.xl") || lower.hasSuffix(".xl") {
                xlFiles.append(file.relativePath)
                textFilesForParsing.append(file.url)
                xlTextFiles.append(file.url)
            }
            if (lower.hasSuffix(".yaml") || lower.hasSuffix(".yml")) && containsPathComponents(lower, ["r6", "tweaks"]) {
                tweakFiles.append(file.relativePath)
                textFilesForParsing.append(file.url)
                tweakTextFiles.append(file.url)
            }
            if lower.hasSuffix(".csv") {
                csvFiles.append(file.relativePath)
                textFilesForParsing.append(file.url)
            }
            if lower.hasSuffix(".json") {
                if isLikelyLocalizationJSON(lower) {
                    jsonFiles.append(file.relativePath)
                }
                textFilesForParsing.append(file.url)
            }
        }

        var candidateItemIDs = Set<String>()
        var referencedItemIDs = Set<String>()
        var candidateBaseRecords = Set<String>()
        var candidateResourceReferences = Set<String>()
        var directItemIDs: [String] = []
        var tweakAnalyses: [AddonProbeTweakXLAnalysis] = []
        var xlAnalyses: [AddonProbeXLMetadataAnalysis] = []
        for url in textFilesForParsing {
            guard let text = try readSmallTextFile(url) else { continue }
            candidateItemIDs.formUnion(Self.parseYAMLishItemIDs(text))
            referencedItemIDs.formUnion(Self.parseReferencedItemIDs(text))
            candidateBaseRecords.formUnion(Self.parseCandidateBaseRecords(text))
            candidateResourceReferences.formUnion(Self.parseResourceReferences(text))
        }
        for url in tweakTextFiles {
            guard let text = try readSmallTextFile(url) else { continue }
            directItemIDs.append(contentsOf: Self.parseDirectTweakXLItemIDs(text))
            tweakAnalyses.append(Self.analyzeTweakXL(text))
        }
        for url in xlTextFiles {
            guard let text = try readSmallTextFile(url) else { continue }
            xlAnalyses.append(Self.analyzeXLMetadata(text))
        }
        let tweakXLAnalysis = Self.mergeTweakXLAnalyses(tweakAnalyses)
        let xlMetadataAnalysis = Self.mergeXLMetadataAnalyses(xlAnalyses)
        let orderedCandidateItemIDs = Self.orderedUnique(directItemIDs + tweakXLAnalysis.expandedItemIDs)
        candidateItemIDs.formUnion(orderedCandidateItemIDs)
        candidateBaseRecords.formUnion(tweakXLAnalysis.baseRecords)

        let classification = classify(
            archiveFiles: archiveFiles,
            xlFiles: xlFiles,
            tweakFiles: tweakFiles,
            candidateItemIDs: orderedCandidateItemIDs.isEmpty ? Array(candidateItemIDs) : orderedCandidateItemIDs,
            resourceReferences: Array(candidateResourceReferences)
        )
        let reasons = classificationReasons(
            classification: classification,
            archiveFiles: archiveFiles,
            xlFiles: xlFiles,
            tweakFiles: tweakFiles,
            candidateItemIDs: orderedCandidateItemIDs.isEmpty ? Array(candidateItemIDs) : orderedCandidateItemIDs,
            resourceReferences: Array(candidateResourceReferences)
        )
        var warnings = root.warnings
        warnings.append(contentsOf: tweakXLAnalysis.warnings)
        warnings.append("Path B addon-probe is experimental. It does not mean true add-on clothing works on Mac.")
        if !candidateItemIDs.isEmpty || !xlFiles.isEmpty || !tweakFiles.isEmpty {
            warnings.append("Files alone are insufficient for a custom item; TweakDB/item records and resource registration are still required.")
        }
        if archiveFiles.isEmpty {
            warnings.append("No .archive files were discovered; asset staging cannot proceed for this mod.")
        }

        return Discovery(
            root: root,
            archiveFiles: archiveFiles.sorted(),
            xlFiles: xlFiles.sorted(),
            tweakFiles: tweakFiles.sorted(),
            csvFiles: csvFiles.sorted(),
            jsonFiles: jsonFiles.sorted(),
            candidateItemIDs: orderedCandidateItemIDs.isEmpty ? candidateItemIDs.sorted() : orderedCandidateItemIDs,
            referencedItemIDs: referencedItemIDs.sorted(),
            candidateBaseRecords: candidateBaseRecords.sorted(),
            candidateResourceReferences: candidateResourceReferences.sorted(),
            tweakXLAnalysis: tweakXLAnalysis,
            xlMetadataAnalysis: xlMetadataAnalysis,
            classification: classification,
            reasons: reasons,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    private struct RegularFile {
        let relativePath: String
        let url: URL
    }

    private func regularFiles(under rootURL: URL, description: String) throws -> [RegularFile] {
        let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) root is a symlink: \(rootURL.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("\(description) root does not exist: \(rootURL.path)")
        }
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [RegularFile] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard resource.isSymbolicLink != true else {
                throw CyberMacError.unsafePath("\(description) contains a symlink: \(url.path)")
            }
            guard resource.isRegularFile == true else { continue }
            try validateContainedPath(url, in: rootURL, description: description)
            let relative = try PathSafety.relativePath(of: url.standardizedFileURL, in: rootURL.standardizedFileURL)
                .replacingOccurrences(of: "\\", with: "/")
            try PathSafety.validateArchivePath(relative)
            files.append(RegularFile(relativePath: relative, url: url.standardizedFileURL))
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func readSmallTextFile(_ url: URL) throws -> String? {
        let size = try PathSafety.fileSize(url: url)
        guard size <= 5 * 1024 * 1024 else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func classify(
        archiveFiles: [String],
        xlFiles: [String],
        tweakFiles: [String],
        candidateItemIDs: [String],
        resourceReferences: [String]
    ) -> AddonProbeClassification {
        let hasArchives = !archiveFiles.isEmpty
        let hasAddonMarkers = !xlFiles.isEmpty || !tweakFiles.isEmpty || !candidateItemIDs.isEmpty

        if hasAddonMarkers && hasArchives && hasLikelyReplacerArchivePath(archiveFiles) {
            return .mixedReplacerAddon
        }
        if hasAddonMarkers {
            return .archiveXLTweakXLAddonCandidate
        }
        if hasArchives {
            return .replacerOnly
        }
        return .unsupportedUnknown
    }

    private func classificationReasons(
        classification: AddonProbeClassification,
        archiveFiles: [String],
        xlFiles: [String],
        tweakFiles: [String],
        candidateItemIDs: [String],
        resourceReferences: [String]
    ) -> [String] {
        var reasons: [String] = []
        if !archiveFiles.isEmpty {
            reasons.append("Discovered \(archiveFiles.count) .archive asset file(s).")
        }
        if !xlFiles.isEmpty {
            reasons.append("Discovered ArchiveXL-style .xl metadata.")
        }
        if !tweakFiles.isEmpty {
            reasons.append("Discovered TweakXL-style r6/tweaks YAML.")
        }
        if !candidateItemIDs.isEmpty {
            reasons.append("Discovered candidate custom item IDs under Items.*.")
        }
        if !resourceReferences.isEmpty {
            reasons.append("Discovered resource references that may need registration.")
        }
        switch classification {
        case .replacerOnly:
            reasons.append("No ArchiveXL/TweakXL metadata or candidate custom item IDs were found.")
        case .archiveXLTweakXLAddonCandidate:
            reasons.append("ArchiveXL/TweakXL markers indicate an add-on candidate, but Mac runtime framework support is not assumed.")
        case .mixedReplacerAddon:
            reasons.append("Both add-on metadata and likely replacer asset archives were found.")
        case .unsupportedUnknown:
            reasons.append("No supported Path B probe inputs were discovered.")
        }
        return reasons
    }

    private func hasLikelyReplacerArchivePath(_ archiveFiles: [String]) -> Bool {
        archiveFiles.contains { path in
            let lower = path.lowercased()
            return lower.contains("archive/pc/content/")
        }
    }

    private func isLikelyLocalizationJSON(_ lowerPath: String) -> Bool {
        lowerPath.hasSuffix(".json") && (
            lowerPath.contains("localization") ||
                lowerPath.contains("/l10n/") ||
                lowerPath.contains("/loc/") ||
                lowerPath.contains("onscreens/") ||
                lowerPath.contains("local")
        )
    }

    private func containsPathComponents(_ lowerPath: String, _ components: [String]) -> Bool {
        let pathComponents = lowerPath
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .map(String.init)
        guard pathComponents.count >= components.count else { return false }
        for index in 0...(pathComponents.count - components.count) {
            if Array(pathComponents[index..<(index + components.count)]) == components {
                return true
            }
        }
        return false
    }

    private func collectExtractedAssets(under rootURL: URL, description: String) throws -> [String: ExtractedAsset] {
        let files = try regularFiles(under: rootURL, description: description)
        var assets: [String: ExtractedAsset] = [:]
        for file in files {
            let assetPath = try validatedAssetPath(file.relativePath, label: description)
            guard assets[assetPath] == nil else {
                throw CyberMacError.invalidInput("\(description) contains duplicate asset path after normalization: \(assetPath)")
            }
            assets[assetPath] = ExtractedAsset(
                assetPath: assetPath,
                url: file.url,
                sha256: try PathSafety.sha256(url: file.url)
            )
        }
        return assets
    }

    private func resolvedFileURL(relativePath: String, rootURL: URL, description: String) throws -> URL {
        try PathSafety.validateArchivePath(relativePath)
        let url = relativePath
            .split(separator: "/")
            .reduce(rootURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            .standardizedFileURL
        try validateContainedPath(url, in: rootURL, description: description)
        try validateRegularFile(url, description: description)
        return url
    }

    private func assetURL(assetPath: String, rootURL: URL, label: String) throws -> URL {
        let validated = try validatedAssetPath(assetPath, label: label)
        let url = validated
            .split(separator: "/")
            .reduce(rootURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            .standardizedFileURL
        try validateContainedPath(url, in: rootURL, description: label)
        return url
    }

    private func validatedAssetPath(_ rawPath: String, label: String) throws -> String {
        let normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty else {
            throw CyberMacError.unsafePath("\(label) asset path is empty.")
        }
        guard !normalized.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(label) asset path must be relative: \(rawPath)")
        }
        guard !normalized.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(label) asset path contains control characters: \(rawPath)")
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains(where: { $0.isEmpty }) else {
            throw CyberMacError.unsafePath("\(label) asset path contains an empty component: \(rawPath)")
        }
        guard !components.contains("."), !components.contains("..") else {
            throw CyberMacError.unsafePath("\(label) asset path contains traversal: \(rawPath)")
        }
        return components.joined(separator: "/")
    }

    private func singleGeneratedArchive(in packedDirectory: URL) throws -> URL {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: packedDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "archive" }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        guard !candidates.isEmpty else {
            throw CyberMacError.notFound("No generated .archive files were found in packed output directory: \(packedDirectory.path)")
        }
        guard candidates.count == 1 else {
            let candidateList = candidates.map { "- \($0.path)" }.joined(separator: "\n")
            throw CyberMacError.invalidInput("cp77tools generated more than one .archive in packed output directory \(packedDirectory.path):\n\(candidateList)")
        }
        let archive = candidates[0].standardizedFileURL
        try validateRegularFile(archive, description: "Generated packed archive")
        return archive
    }

    private func gameArchiveURL(relativeArchivePath: String, gameInstall: GameInstall) throws -> URL {
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        let url = relativeArchivePath
            .split(separator: "/")
            .reduce(contentsURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            .standardizedFileURL
        try validateContainedPath(url, in: contentsURL, description: "Game archive destination")
        return url
    }

    private func existingDefaultDatabaseURL() -> URL? {
        let url = ArchiveCatalogIndexDefaults.databaseURL.standardizedFileURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func attemptFactoryCR2WDecode(
        cp77toolsURL: URL,
        resourcePath: String,
        sourceURL: URL,
        workRoot: URL
    ) throws -> (attempts: [AddonProbeFactoryDecodeAttempt], textSummaries: [AddonProbeFactoryDecodedTextSummary]) {
        let runner = ProcessRunner()
        let decodeRoot = workRoot
            .appendingPathComponent("decoded", isDirectory: true)
            .appendingPathComponent(Self.safeFilename(resourcePath), isDirectory: true)
        try validateOutputDirectory(decodeRoot, description: "Factory CR2W decode output directory")

        var attempts: [AddonProbeFactoryDecodeAttempt] = []
        var textSummaries: [AddonProbeFactoryDecodedTextSummary] = []

        func runAttempt(arguments: [String], timeout: TimeInterval = 30) {
            let command = CP77ToolsErrorFormatter.displayCommand(executable: cp77toolsURL, arguments: arguments)
            do {
                let result = try runner.run(
                    executableURL: cp77toolsURL,
                    arguments: arguments,
                    timeoutSeconds: timeout,
                    allowFailure: true
                )
                attempts.append(AddonProbeFactoryDecodeAttempt(
                    resourcePath: resourcePath,
                    command: command,
                    exitCode: result.exitCode,
                    stdout: Self.clippedProcessOutput(result.stdout),
                    stderr: Self.clippedProcessOutput(result.stderr),
                    producedFiles: [],
                    parsedOutputPath: nil,
                    warnings: result.exitCode == 0 ? [] : ["Command exited non-zero while probing cp77tools support."]
                ))
            } catch {
                attempts.append(AddonProbeFactoryDecodeAttempt(
                    resourcePath: resourcePath,
                    command: command,
                    exitCode: nil,
                    stdout: "",
                    stderr: "",
                    producedFiles: [],
                    parsedOutputPath: nil,
                    warnings: ["Command could not run: \(error.localizedDescription)"]
                ))
            }
        }

        for arguments in [
            ["--help"],
            ["-h"],
            ["help"],
            ["convert", "--help"],
            ["convert", "serialize", "--help"],
            ["cr2w", "--help"],
            ["cr2w2json", "--help"],
            ["export", "--help"],
            ["uncook", "--help"]
        ] {
            runAttempt(arguments: arguments)
        }

        let helpText = attempts
            .map { "\($0.command)\n\($0.stdout)\n\($0.stderr)" }
            .joined(separator: "\n")
            .lowercased()
        let cr2wHelp = attempts
            .filter { $0.command.contains("cr2w2json") }
            .map { "\($0.stdout)\n\($0.stderr)" }
            .joined(separator: "\n")
            .lowercased()
        let convertSerializeHelp = attempts
            .filter { $0.command.contains("convert") && $0.command.contains("serialize") }
            .map { "\($0.stdout)\n\($0.stderr)" }
            .joined(separator: "\n")
            .lowercased()
        let legacyCR2WHelp = attempts
            .filter { $0.command.contains("cr2w") && !$0.command.contains("cr2w2json") }
            .map { "\($0.stdout)\n\($0.stderr)" }
            .joined(separator: "\n")
            .lowercased()

        let outputURL = decodeRoot.appendingPathComponent("cr2w-json-output", isDirectory: true)
        try validateOutputDirectory(outputURL, description: "Factory CR2W JSON output directory")
        let conversionArguments: [String]?
        if helpText.contains("convert"),
           convertSerializeHelp.contains("serialize the cr2w"),
           let outputFlag = Self.supportedOutputFlag(in: convertSerializeHelp) {
            conversionArguments = ["convert", "serialize", sourceURL.path, outputFlag, outputURL.path]
        } else if legacyCR2WHelp.contains("--serialize"),
                  let outputFlag = Self.supportedOutputFlag(in: legacyCR2WHelp) {
            conversionArguments = ["cr2w", sourceURL.path, "--serialize", outputFlag, outputURL.path]
        } else if helpText.contains("cr2w2json"),
                  let outputFlag = Self.supportedOutputFlag(in: cr2wHelp),
                  cr2wHelp.contains("--path") || cr2wHelp.contains("<path") || cr2wHelp.contains(" path") {
            if cr2wHelp.contains("--path") {
                conversionArguments = ["cr2w2json", "--path", sourceURL.path, outputFlag, outputURL.path]
            } else {
                conversionArguments = ["cr2w2json", sourceURL.path, outputFlag, outputURL.path]
            }
        } else {
            conversionArguments = nil
        }

        guard let conversionArguments else {
            attempts.append(AddonProbeFactoryDecodeAttempt(
                resourcePath: resourcePath,
                command: "not-run: no supported cp77tools CR2W conversion command discovered from help output",
                exitCode: nil,
                stdout: "",
                stderr: "",
                producedFiles: [],
                parsedOutputPath: nil,
                warnings: ["CR2W factory resource extracted but no supported conversion path was found."]
            ))
            return (attempts, textSummaries)
        }

        let command = CP77ToolsErrorFormatter.displayCommand(executable: cp77toolsURL, arguments: conversionArguments)
        do {
            let result = try runner.run(
                executableURL: cp77toolsURL,
                arguments: conversionArguments,
                timeoutSeconds: 120,
                allowFailure: true
            )
            let producedFiles = try regularFiles(under: outputURL, description: "Factory CR2W decode output")
            for file in producedFiles {
                guard let text = try readSmallTextFile(file.url) else { continue }
                textSummaries.append(Self.analyzeFactoryDecodedText(
                    resourcePath: resourcePath,
                    decodedPath: file.url.path,
                    contents: text
                ))
            }
            attempts.append(AddonProbeFactoryDecodeAttempt(
                resourcePath: resourcePath,
                command: command,
                exitCode: result.exitCode,
                stdout: Self.clippedProcessOutput(result.stdout),
                stderr: Self.clippedProcessOutput(result.stderr),
                producedFiles: producedFiles.map(\.relativePath),
                parsedOutputPath: textSummaries.first?.decodedPath,
                warnings: Self.decodeWarnings(exitCode: result.exitCode, textSummaryCount: textSummaries.count)
            ))
        } catch {
            attempts.append(AddonProbeFactoryDecodeAttempt(
                resourcePath: resourcePath,
                command: command,
                exitCode: nil,
                stdout: "",
                stderr: "",
                producedFiles: [],
                parsedOutputPath: nil,
                warnings: ["CR2W conversion attempt failed to run cleanly: \(error.localizedDescription)"]
            ))
        }

        return (attempts, textSummaries)
    }

    private func analyzeFactoryJSONFile(_ file: RegularFile, rootURL: URL) throws -> AddonProbeFactoryJSONFileReport {
        var warnings: [String] = []
        let data = try Data(contentsOf: file.url)
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            warnings.append("JSON parse failed: \(error.localizedDescription)")
            return AddonProbeFactoryJSONFileReport(
                fileName: file.url.lastPathComponent,
                decodedJSONPath: file.url.path,
                relativePath: file.relativePath,
                topLevelType: "invalid",
                topLevelKeys: [],
                stringValueCount: 0,
                counts: Self.zeroFactoryJSONCounts(),
                representativeMatches: [:],
                inferredRole: .unknown,
                warnings: warnings
            )
        }

        var stringValues: [FactoryJSONStringValue] = []
        Self.collectFactoryJSONStringValues(parsed, path: "$", into: &stringValues)
        let matchSummary = Self.matchFactoryJSONStringValues(stringValues)
        let role = Self.inferFactoryJSONRole(
            fileName: file.url.lastPathComponent,
            counts: matchSummary.counts,
            stringValues: stringValues
        )
        if let object = parsed as? [String: Any],
           object["Header"] == nil || object["Data"] == nil {
            warnings.append("Top-level object does not expose both Header and Data keys.")
        }

        return AddonProbeFactoryJSONFileReport(
            fileName: file.url.lastPathComponent,
            decodedJSONPath: file.url.path,
            relativePath: file.relativePath,
            topLevelType: Self.factoryJSONTopLevelType(parsed),
            topLevelKeys: Self.factoryJSONTopLevelKeys(parsed),
            stringValueCount: stringValues.count,
            counts: matchSummary.counts,
            representativeMatches: matchSummary.representatives,
            inferredRole: role,
            warnings: warnings
        )
    }

    private static func collectFactoryJSONStringValues(_ node: Any, path: String, into values: inout [FactoryJSONStringValue]) {
        if let object = node as? [String: Any] {
            for key in object.keys.sorted() {
                collectFactoryJSONStringValues(object[key] as Any, path: jsonPathAppendingKey(key, to: path), into: &values)
            }
        } else if let array = node as? [Any] {
            for (index, item) in array.enumerated() {
                collectFactoryJSONStringValues(item, path: "\(path)[\(index)]", into: &values)
            }
        } else if let string = node as? String {
            values.append(FactoryJSONStringValue(path: path, value: string))
        }
    }

    private static func matchFactoryJSONStringValues(
        _ stringValues: [FactoryJSONStringValue],
        representativeLimit: Int = 5
    ) -> (counts: [String: Int], representatives: [String: [AddonProbeFactoryJSONMatch]]) {
        var counts = zeroFactoryJSONCounts()
        var representatives: [String: [AddonProbeFactoryJSONMatch]] = [:]
        let resourceTerms = Set([".ent", ".app", ".mesh", ".mlsetup", ".mlmask", ".xbm"])

        for stringValue in stringValues {
            let lowerValue = stringValue.value.lowercased()
            let lowerPath = stringValue.path.lowercased()
            for term in factoryJSONAnalysisTerms {
                let lowerTerm = term.lowercased()
                var matchedIn: [String] = []
                if lowerValue.contains(lowerTerm) {
                    matchedIn.append("value")
                }
                if lowerPath.contains(lowerTerm) {
                    matchedIn.append("path")
                }
                guard !matchedIn.isEmpty else { continue }
                counts[term, default: 0] += 1
                if representatives[term, default: []].count < representativeLimit {
                    let normalizedValue = resourceTerms.contains(term) && matchedIn.contains("value")
                        ? normalizedFactoryResourceDisplayPath(stringValue.value)
                        : nil
                    representatives[term, default: []].append(AddonProbeFactoryJSONMatch(
                        term: term,
                        jsonPath: stringValue.path,
                        value: stringValue.value,
                        normalizedValue: normalizedValue,
                        matchedIn: matchedIn
                    ))
                }
            }
        }
        return (counts, representatives)
    }

    private static func inferFactoryJSONRole(
        fileName: String,
        counts: [String: Int],
        stringValues: [FactoryJSONStringValue]
    ) -> AddonProbeFactoryJSONRole {
        let lowerValues = stringValues.map { $0.value.lowercased() }
        switch fileName {
        case "factories.csv.json":
            if lowerValues.contains(where: { $0.contains(".csv") }) || (counts["factory"] ?? 0) > 0 {
                return .topLevelFactoryRegistry
            }
        case "clothing.csv.json":
            let slotTokens = [
                "player_outer_torso_item",
                "player_inner_torso_item",
                "player_legs_item",
                "player_feet_item"
            ]
            if lowerValues.contains(where: { value in
                value.contains(".ent") && slotTokens.contains(where: value.contains)
            }) {
                return .clothingEquipmentEntityTemplateFactoryMapping
            }
        case "clothing_appearances.csv.json":
            if lowerValues.contains(where: { $0.contains(".app") && $0.contains("player_torso_item_appearances") }) ||
                ((counts[".app"] ?? 0) > 0 && (counts["appearance"] ?? 0) > 0) {
                return .clothingAppearanceResourceMapping
            }
        case "items.csv.json":
            if (counts[".ent"] ?? 0) > 0 {
                return .genericItemFactoryMapping
            }
        default:
            break
        }
        return .unknown
    }

    private static func factoryJSONTopLevelType(_ value: Any) -> String {
        if value is [String: Any] { return "object" }
        if value is [Any] { return "array" }
        if value is String { return "string" }
        if value is NSNull { return "null" }
        if let number = value as? NSNumber {
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? "bool" : "number"
        }
        return "unknown"
    }

    private static func factoryJSONTopLevelKeys(_ value: Any) -> [String] {
        guard let object = value as? [String: Any] else { return [] }
        return object.keys.sorted()
    }

    private static func zeroFactoryJSONCounts() -> [String: Int] {
        Dictionary(uniqueKeysWithValues: factoryJSONAnalysisTerms.map { ($0, 0) })
    }

    private static func jsonPathAppendingKey(_ key: String, to path: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if !key.isEmpty,
           key.unicodeScalars.allSatisfy({ allowed.contains($0) }),
           key.unicodeScalars.first.map({ CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains($0) }) == true {
            return "\(path).\(key)"
        }
        return "\(path)[\(jsonStringLiteral(key))]"
    }

    private static func jsonStringLiteral(_ value: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
           let encoded = String(data: data, encoding: .utf8),
           encoded.hasPrefix("["),
           encoded.hasSuffix("]") {
            return String(encoded.dropFirst().dropLast())
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func normalizedFactoryResourceDisplayPath(_ value: String) -> String {
        var normalized = value.replacingOccurrences(of: "\\", with: "/")
        while normalized.contains("//") {
            normalized = normalized.replacingOccurrences(of: "//", with: "/")
        }
        return normalized
    }

    private static func factoryRowArray(
        named name: String,
        in rootChunk: [String: Any],
        warnings: inout [String]
    ) -> [Any]? {
        guard let value = rootChunk[name] else {
            return nil
        }
        guard let rows = value as? [Any] else {
            warnings.append("$.Data.RootChunk.\(name) exists but is not an array; it was skipped.")
            return nil
        }
        return rows
    }

    private static func factoryRows(matchingKey key: String, in rows: [Any]?) -> [[Any]] {
        guard let rows else { return [] }
        return rows.compactMap { row in
            guard let values = row as? [Any],
                  values.first as? String == key
            else {
                return nil
            }
            return values
        }
    }

    private static func factoryContainsRow(key: String, in rows: [Any]?) -> Bool {
        guard let rows else { return false }
        return rows.contains { row in
            guard let values = row as? [Any] else { return false }
            return values.first as? String == key
        }
    }

    private static func clonedFactoryRow(_ row: [Any], newKey: String) -> [Any] {
        var clone = row
        if !clone.isEmpty {
            clone[0] = newKey
        }
        return clone
    }

    private static func firstEntityPath(inFactoryRow row: [Any]) -> String? {
        for value in row.dropFirst() {
            guard let string = value as? String else { continue }
            if string.lowercased().hasSuffix(".ent") {
                return string
            }
        }
        return nil
    }

    private static func normalizedXLResourcePaths(_ values: [String]) -> [String] {
        orderedUnique(values.map(normalizedFactoryResourceDisplayPath))
    }

    private enum FactoryRegistryPathComponent: Equatable {
        case index(Int)
        case key(String)
    }

    private struct FactoryRegistrySourceRow {
        let row: Any
        let jsonPath: String
        let pathValue: String
        let pathComponents: [FactoryRegistryPathComponent]
    }

    private static func factoryRowsContainPath(_ path: String, in rows: [Any]?) -> Bool {
        let normalizedPath = normalizedFactoryResourceDisplayPath(path)
        guard let rows else { return false }
        return rows.contains { row in
            factoryRegistryCSVStrings(in: row).contains { string in
                normalizedFactoryResourceDisplayPath(string.value) == normalizedPath
            }
        }
    }

    private static func factoryRegistrySourceRow(in rows: [Any], arrayPath: String) -> FactoryRegistrySourceRow? {
        let preferredPath = "base/gameplay/factories/items/clothing.csv"
        var fallback: FactoryRegistrySourceRow?
        for (rowIndex, row) in rows.enumerated() {
            let rowPath = "\(arrayPath)[\(rowIndex)]"
            let strings = factoryRegistryCSVStrings(in: row)
            if let preferred = strings.first(where: { normalizedFactoryResourceDisplayPath($0.value).lowercased() == preferredPath }) {
                return FactoryRegistrySourceRow(
                    row: row,
                    jsonPath: rowPath,
                    pathValue: preferred.value,
                    pathComponents: preferred.components
                )
            }
            if fallback == nil, let firstCSV = strings.first {
                fallback = FactoryRegistrySourceRow(
                    row: row,
                    jsonPath: rowPath,
                    pathValue: firstCSV.value,
                    pathComponents: firstCSV.components
                )
            }
        }
        return fallback
    }

    private static func factoryRegistryRowsAreCompatible(_ left: Any, _ right: Any) -> Bool {
        switch (left, right) {
        case (let left as [Any], let right as [Any]):
            return left.count == right.count
        case (let left as [String: Any], let right as [String: Any]):
            return Set(left.keys) == Set(right.keys)
        default:
            return false
        }
    }

    private static func factoryRegistryPathForStyle(_ path: String, like sourcePath: String) -> String {
        let normalized = normalizedFactoryResourceDisplayPath(path)
        return sourcePath.contains("\\") ? normalized.replacingOccurrences(of: "/", with: "\\") : normalized
    }

    private static func clonedFactoryRegistryRow(_ source: FactoryRegistrySourceRow, factoryPath: String) -> Any {
        replacingJSONValue(
            in: source.row,
            at: source.pathComponents,
            with: factoryRegistryPathForStyle(factoryPath, like: source.pathValue)
        )
    }

    private static func factoryRegistryRowMatchesClone(source: Any, clone: Any, oldPath: String, newPath: String) -> Bool {
        let expected = replacingFirstStringValue(in: source, oldValue: oldPath, newValue: newPath)
        return jsonPreview(expected) == jsonPreview(clone)
    }

    private static func factoryRegistryCSVStrings(
        in node: Any,
        components: [FactoryRegistryPathComponent] = []
    ) -> [(value: String, components: [FactoryRegistryPathComponent])] {
        if let object = node as? [String: Any] {
            return object.keys.sorted().flatMap { key in
                factoryRegistryCSVStrings(in: object[key] as Any, components: components + [.key(key)])
            }
        }
        if let array = node as? [Any] {
            return array.indices.flatMap { index in
                factoryRegistryCSVStrings(in: array[index], components: components + [.index(index)])
            }
        }
        if let string = node as? String,
           normalizedFactoryResourceDisplayPath(string).lowercased().contains(".csv") {
            return [(string, components)]
        }
        return []
    }

    private static func replacingJSONValue(
        in node: Any,
        at components: [FactoryRegistryPathComponent],
        with newValue: String
    ) -> Any {
        guard let first = components.first else { return newValue }
        let rest = Array(components.dropFirst())
        switch first {
        case .index(let index):
            guard var array = node as? [Any], array.indices.contains(index) else { return node }
            array[index] = replacingJSONValue(in: array[index], at: rest, with: newValue)
            return array
        case .key(let key):
            guard var object = node as? [String: Any], object.keys.contains(key) else { return node }
            object[key] = replacingJSONValue(in: object[key] as Any, at: rest, with: newValue)
            return object
        }
    }

    private static func replacingFirstStringValue(in node: Any, oldValue: String, newValue: String) -> Any {
        var replaced = false
        func replace(_ node: Any) -> Any {
            if let string = node as? String {
                if !replaced, string == oldValue {
                    replaced = true
                    return newValue
                }
                return string
            }
            if let array = node as? [Any] {
                return array.map(replace)
            }
            if let object = node as? [String: Any] {
                var result: [String: Any] = [:]
                for key in object.keys {
                    result[key] = replace(object[key] as Any)
                }
                return result
            }
            return node
        }
        return replace(node)
    }

    private static func jsonPreview(_ value: Any, limit: Int = 500) -> String {
        let data: Data?
        if JSONSerialization.isValidJSONObject(value) {
            data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
        } else {
            data = nil
        }
        let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: value)
        let oneLine = raw.replacingOccurrences(of: "\n", with: " ")
        if oneLine.count <= limit {
            return oneLine
        }
        return String(oneLine.prefix(limit)) + "...truncated"
    }

    private static func missingXLResourceDiagnostic(resourcePath: String, warning: String) -> AddonProbeXLResourceDiagnostic {
        AddonProbeXLResourceDiagnostic(
            resourcePath: resourcePath,
            archivePath: nil,
            extractedPath: nil,
            exists: false,
            size: nil,
            first32BytesHex: "",
            detectedMagic: .unknownBinary,
            warnings: [warning]
        )
    }

    private static func xlResourceDiagnostic(resourcePath: String, archivePath: String?, url: URL) throws -> AddonProbeXLResourceDiagnostic {
        let data = try Data(contentsOf: url)
        return AddonProbeXLResourceDiagnostic(
            resourcePath: resourcePath,
            archivePath: archivePath,
            extractedPath: url.path,
            exists: true,
            size: data.count,
            first32BytesHex: hexPrefix(data, count: 32),
            detectedMagic: factoryResourceMagic(data),
            warnings: []
        )
    }

    private static func summarizeXLDecodedFactoryJSON(
        resourcePath: String,
        decodedJSONURL: URL
    ) throws -> AddonProbeXLDecodedFactoryJSONSummary {
        var warnings: [String] = []
        let data = try Data(contentsOf: decodedJSONURL)
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            warnings.append("Decoded factory JSON parse failed: \(error.localizedDescription)")
            return AddonProbeXLDecodedFactoryJSONSummary(
                resourcePath: resourcePath,
                decodedJSONPath: decodedJSONURL.path,
                topLevelType: "invalid",
                topLevelKeys: [],
                compiledDataRowCount: nil,
                dataRowCount: nil,
                stringValues: [],
                entReferences: [],
                appReferences: [],
                appearanceNames: [],
                entityKeys: [],
                atomiicStrings: [],
                shirtStrings: [],
                skirtStrings: [],
                slotStrings: [],
                warnings: warnings
            )
        }

        var stringValues: [FactoryJSONStringValue] = []
        collectFactoryJSONStringValues(parsed, path: "$", into: &stringValues)
        let publicValues = stringValues.map { AddonProbeXLJSONStringValue(jsonPath: $0.path, value: $0.value) }
        let compiledCount = factoryJSONRootChunkArrayCount(parsed, key: "compiledData")
        let dataCount = factoryJSONRootChunkArrayCount(parsed, key: "data")
        let pairs = stringValues.map { ($0.path, $0.value) }
        return AddonProbeXLDecodedFactoryJSONSummary(
            resourcePath: resourcePath,
            decodedJSONPath: decodedJSONURL.path,
            topLevelType: factoryJSONTopLevelType(parsed),
            topLevelKeys: factoryJSONTopLevelKeys(parsed),
            compiledDataRowCount: compiledCount,
            dataRowCount: dataCount,
            stringValues: publicValues,
            entReferences: strings(containing: ".ent", in: pairs, normalizePaths: true),
            appReferences: strings(containing: ".app", in: pairs, normalizePaths: true),
            appearanceNames: strings(containing: "appearance", in: pairs, includePath: true),
            entityKeys: strings(containing: "entity", in: pairs, includePath: true),
            atomiicStrings: strings(containing: "atomiic_sexyofficedress", in: pairs),
            shirtStrings: strings(containing: "shirt", in: pairs),
            skirtStrings: strings(containing: "skirt", in: pairs),
            slotStrings: strings(containing: "slot", in: pairs),
            warnings: warnings
        )
    }

    private static func addWarnings(
        _ warnings: [String],
        to summary: AddonProbeXLDecodedFactoryJSONSummary
    ) -> AddonProbeXLDecodedFactoryJSONSummary {
        AddonProbeXLDecodedFactoryJSONSummary(
            resourcePath: summary.resourcePath,
            decodedJSONPath: summary.decodedJSONPath,
            topLevelType: summary.topLevelType,
            topLevelKeys: summary.topLevelKeys,
            compiledDataRowCount: summary.compiledDataRowCount,
            dataRowCount: summary.dataRowCount,
            stringValues: summary.stringValues,
            entReferences: summary.entReferences,
            appReferences: summary.appReferences,
            appearanceNames: summary.appearanceNames,
            entityKeys: summary.entityKeys,
            atomiicStrings: summary.atomiicStrings,
            shirtStrings: summary.shirtStrings,
            skirtStrings: summary.skirtStrings,
            slotStrings: summary.slotStrings,
            warnings: orderedUnique(summary.warnings + warnings)
        )
    }

    private static func summarizeXLLocalizationJSON(
        resourcePath: String,
        decodedPath: String,
        data: Data
    ) throws -> AddonProbeXLLocalizationSummary {
        var warnings: [String] = []
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return AddonProbeXLLocalizationSummary(
                resourcePath: resourcePath,
                decodedPath: decodedPath,
                localizationKeys: [],
                stringValues: [],
                warnings: ["Localization JSON parse failed: \(error.localizedDescription)"]
            )
        }
        var keys: [String] = []
        collectJSONKeys(parsed, path: "$", into: &keys)
        var values: [FactoryJSONStringValue] = []
        collectFactoryJSONStringValues(parsed, path: "$", into: &values)
        if keys.isEmpty {
            warnings.append("Localization JSON did not contain object keys.")
        }
        return AddonProbeXLLocalizationSummary(
            resourcePath: resourcePath,
            decodedPath: decodedPath,
            localizationKeys: orderedUnique(keys),
            stringValues: values.map { AddonProbeXLJSONStringValue(jsonPath: $0.path, value: $0.value) },
            warnings: warnings
        )
    }

    private static func compareXLDecodedStringsToYAML(
        discovery: Discovery,
        factorySummaries: [AddonProbeXLDecodedFactoryJSONSummary],
        localizationSummaries: [AddonProbeXLLocalizationSummary]
    ) -> AddonProbeXLYAMLComparison {
        let decodedStrings = orderedUnique(
            factorySummaries.flatMap { $0.stringValues.map(\.value) } +
                localizationSummaries.flatMap { $0.stringValues.map(\.value) + $0.localizationKeys }
        )
        let normalizedDecodedStrings = Set(decodedStrings.map { normalizedFactoryResourceDisplayPath($0).lowercased() })

        func match(_ expected: [String]) -> (matched: [String], missing: [String]) {
            var matched: [String] = []
            var missing: [String] = []
            for value in orderedUnique(expected) {
                let normalized = normalizedFactoryResourceDisplayPath(value).lowercased()
                let found = normalizedDecodedStrings.contains(normalized) ||
                    decodedStrings.contains { $0.localizedCaseInsensitiveContains(value) || value.localizedCaseInsensitiveContains($0) }
                if found {
                    matched.append(value)
                } else {
                    missing.append(value)
                }
            }
            return (matched, missing)
        }

        let entity = match(discovery.tweakXLAnalysis.entityNames)
        let appearance = match(discovery.tweakXLAnalysis.appearanceNames)
        let display = match(discovery.tweakXLAnalysis.displayNames)
        let atlasPaths = match(discovery.tweakXLAnalysis.iconAtlasPaths)
        let atlasParts = match(discovery.tweakXLAnalysis.iconAtlasParts)
        return AddonProbeXLYAMLComparison(
            expectedEntityNames: discovery.tweakXLAnalysis.entityNames,
            matchedEntityNames: entity.matched,
            missingEntityNames: entity.missing,
            expectedAppearanceNames: discovery.tweakXLAnalysis.appearanceNames,
            matchedAppearanceNames: appearance.matched,
            missingAppearanceNames: appearance.missing,
            expectedDisplayNames: discovery.tweakXLAnalysis.displayNames,
            matchedDisplayNames: display.matched,
            missingDisplayNames: display.missing,
            expectedIconAtlasPaths: discovery.tweakXLAnalysis.iconAtlasPaths,
            matchedIconAtlasPaths: atlasPaths.matched,
            missingIconAtlasPaths: atlasPaths.missing,
            expectedIconAtlasParts: discovery.tweakXLAnalysis.iconAtlasParts,
            matchedIconAtlasParts: atlasParts.matched,
            missingIconAtlasParts: atlasParts.missing
        )
    }

    private static func factoryJSONRootChunkArrayCount(_ parsed: Any, key: String) -> Int? {
        guard let root = parsed as? [String: Any],
              let data = root["Data"] as? [String: Any],
              let rootChunk = data["RootChunk"] as? [String: Any],
              let array = rootChunk[key] as? [Any]
        else {
            return nil
        }
        return array.count
    }

    private static func collectJSONKeys(_ node: Any, path: String, into keys: inout [String]) {
        if let object = node as? [String: Any] {
            for key in object.keys.sorted() {
                keys.append(key)
                collectJSONKeys(object[key] as Any, path: jsonPathAppendingKey(key, to: path), into: &keys)
            }
        } else if let array = node as? [Any] {
            for (index, item) in array.enumerated() {
                collectJSONKeys(item, path: "\(path)[\(index)]", into: &keys)
            }
        }
    }

    private static func strings(
        containing term: String,
        in pairs: [(path: String, value: String)],
        includePath: Bool = false,
        normalizePaths: Bool = false
    ) -> [String] {
        let lowerTerm = term.lowercased()
        let values = pairs.compactMap { pair -> String? in
            let valueMatches = pair.value.lowercased().contains(lowerTerm)
            let pathMatches = includePath && pair.path.lowercased().contains(lowerTerm)
            guard valueMatches || pathMatches else { return nil }
            return normalizePaths ? normalizedFactoryResourceDisplayPath(pair.value) : pair.value
        }
        return orderedUnique(values)
    }

    private static func validatedFactoryRowKey(_ rawKey: String, label: String) throws -> String {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw CyberMacError.invalidInput("\(label) must not be empty.")
        }
        guard !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(label) contains control characters.")
        }
        return key
    }

    private func resolveFactoryRoundtripArchiveURL(archivePath: String, gameInstall: GameInstall) throws -> URL {
        let trimmed = archivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CyberMacError.unsafePath("Factory roundtrip archive path is empty.")
        }
        if trimmed.hasPrefix("/") {
            let url = URL(fileURLWithPath: trimmed).standardizedFileURL
            try validateLocalURL(url, description: "Factory roundtrip archive")
            guard url.pathExtension.lowercased() == "archive" else {
                throw CyberMacError.invalidInput("Factory roundtrip archive path must end in .archive: \(url.path)")
            }
            return url
        }

        let relativeArchivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(trimmed)
        let contentsURL = gameInstall.appURL.appendingPathComponent("Contents", isDirectory: true)
        let url = relativeArchivePath
            .split(separator: "/")
            .reduce(contentsURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            .standardizedFileURL
        try validateContainedPath(url, in: contentsURL, description: "Factory roundtrip archive")
        return url
    }

    private func runRoundtripCP77ToolsCommand(
        cp77toolsURL: URL,
        arguments: [String],
        timeout: TimeInterval,
        attempts: inout [AddonProbeFactoryRoundtripCommandAttempt]
    ) -> ProcessResult? {
        let command = CP77ToolsErrorFormatter.displayCommand(executable: cp77toolsURL, arguments: arguments)
        do {
            let result = try ProcessRunner().run(
                executableURL: cp77toolsURL,
                arguments: arguments,
                timeoutSeconds: timeout,
                allowFailure: true
            )
            attempts.append(AddonProbeFactoryRoundtripCommandAttempt(
                command: command,
                arguments: arguments,
                exitCode: result.exitCode,
                stdout: Self.clippedProcessOutput(result.stdout),
                stderr: Self.clippedProcessOutput(result.stderr),
                warnings: result.exitCode == 0 ? [] : ["Command exited non-zero while probing factory roundtrip support."]
            ))
            return result
        } catch {
            attempts.append(AddonProbeFactoryRoundtripCommandAttempt(
                command: command,
                arguments: arguments,
                exitCode: nil,
                stdout: "",
                stderr: "",
                warnings: ["Command could not run: \(error.localizedDescription)"]
            ))
            return nil
        }
    }

    private func recordRoundtripArchiveToolingCommand(
        cp77toolsURL: URL,
        arguments: [String],
        attempts: inout [AddonProbeFactoryRoundtripCommandAttempt],
        operation: String,
        body: () throws -> Void
    ) throws {
        let command = CP77ToolsErrorFormatter.displayCommand(executable: cp77toolsURL, arguments: arguments)
        do {
            try body()
            attempts.append(AddonProbeFactoryRoundtripCommandAttempt(
                command: command,
                arguments: arguments,
                exitCode: 0,
                stdout: "",
                stderr: "",
                warnings: ["\(operation) ran through archive tooling; process stdout/stderr are not exposed by that abstraction."]
            ))
        } catch {
            attempts.append(AddonProbeFactoryRoundtripCommandAttempt(
                command: command,
                arguments: arguments,
                exitCode: nil,
                stdout: "",
                stderr: "\(error)",
                warnings: ["\(operation) failed while running through archive tooling."]
            ))
            throw error
        }
    }

    private func probeFactoryReverseSerialization(
        cp77toolsURL: URL,
        decodedJSONURL: URL,
        outputDirectoryURL: URL,
        attempts: inout [AddonProbeFactoryRoundtripCommandAttempt]
    ) -> FactoryReverseSerializationPlan? {
        let startIndex = attempts.count
        let helpCommands = [
            ["--help"],
            ["convert", "--help"],
            ["convert", "serialize", "--help"],
            ["convert", "deserialize", "--help"],
            ["json2cr2w", "--help"],
            ["cr2w", "--help"]
        ]
        for arguments in helpCommands {
            _ = runRoundtripCP77ToolsCommand(
                cp77toolsURL: cp77toolsURL,
                arguments: arguments,
                timeout: 30,
                attempts: &attempts
            )
        }

        let helpAttempts = Array(attempts.dropFirst(startIndex))
        if let deserializeHelp = helpAttempts.first(where: { $0.arguments == ["convert", "deserialize", "--help"] }) {
            let helpText = Self.roundtripAttemptText(deserializeHelp)
            if deserializeHelp.exitCode == 0,
               helpText.contains("deserialize"),
               let outputFlag = Self.supportedOutputFlag(in: helpText) {
                return FactoryReverseSerializationPlan(arguments: [
                    "convert",
                    "deserialize",
                    decodedJSONURL.path,
                    outputFlag,
                    outputDirectoryURL.path
                ])
            }
        }

        if let json2CR2WHelp = helpAttempts.first(where: { $0.arguments == ["json2cr2w", "--help"] }) {
            let helpText = Self.roundtripAttemptText(json2CR2WHelp)
            if json2CR2WHelp.exitCode == 0,
               helpText.contains("json2cr2w"),
               let outputFlag = Self.supportedOutputFlag(in: helpText) {
                return FactoryReverseSerializationPlan(arguments: [
                    "json2cr2w",
                    decodedJSONURL.path,
                    outputFlag,
                    outputDirectoryURL.path
                ])
            }
        }

        return nil
    }

    private static func roundtripAttemptText(_ attempt: AddonProbeFactoryRoundtripCommandAttempt) -> String {
        "\(attempt.command)\n\(attempt.stdout)\n\(attempt.stderr)".lowercased()
    }

    private func findDecodedFactoryJSON(for resourcePath: String, under rootURL: URL, warnings: inout [String]) throws -> URL? {
        let files = try regularFiles(under: rootURL, description: "Factory roundtrip decoded JSON")
            .filter { $0.url.pathExtension.lowercased() == "json" }
        guard !files.isEmpty else { return nil }
        let expectedName = URL(fileURLWithPath: resourcePath).lastPathComponent + ".json"
        let exact = files.filter { $0.url.lastPathComponent == expectedName }
        if let match = exact.sorted(by: { $0.relativePath < $1.relativePath }).first {
            return match.url
        }
        if files.count > 1 {
            warnings.append("Multiple decoded JSON files were produced; using the first because no \(expectedName) file was found.")
        }
        return files.sorted { $0.relativePath < $1.relativePath }.first?.url
    }

    private func findReserializedCR2W(for resourcePath: String, under rootURL: URL, warnings: inout [String]) throws -> URL? {
        let files = try regularFiles(under: rootURL, description: "Factory roundtrip reserialized CR2W")
        var cr2wFiles: [(relativePath: String, url: URL)] = []
        for file in files {
            let data = try Data(contentsOf: file.url)
            if Self.factoryResourceMagic(data) == .cr2w {
                cr2wFiles.append((relativePath: file.relativePath, url: file.url))
            }
        }
        guard !cr2wFiles.isEmpty else { return nil }
        let expectedName = URL(fileURLWithPath: resourcePath).lastPathComponent
        if let match = cr2wFiles.sorted(by: { $0.relativePath < $1.relativePath }).first(where: { $0.url.lastPathComponent == expectedName }) {
            return match.url
        }
        if cr2wFiles.count > 1 {
            warnings.append("Multiple valid-looking CR2W files were produced; using the first because no \(expectedName) file was found.")
        }
        return cr2wFiles.sorted { $0.relativePath < $1.relativePath }.first?.url
    }

    private static func factoryFileFacts(url: URL) throws -> FactoryFileFacts {
        let data = try Data(contentsOf: url)
        return FactoryFileFacts(
            sha256: PathSafety.sha256(data: data),
            size: UInt64(data.count),
            first32: hexPrefix(data, count: 32),
            magic: factoryResourceMagic(data).rawValue
        )
    }

    private func writeRoundtripManifest(
        inputArchive: String,
        resourcePath: String,
        extractedResourcePath: String?,
        decodedJSONPath: String?,
        reserializedCR2WPath: String?,
        originalFacts: FactoryFileFacts?,
        rebuiltFacts: FactoryFileFacts?,
        attempts: [AddonProbeFactoryRoundtripCommandAttempt],
        stagedArchivePath: String?,
        stagedArchiveSHA256: String?,
        manifestURL: URL,
        manualInstallCommand: String?,
        conclusion: AddonProbeFactoryRoundtripConclusion,
        warnings: [String]
    ) throws -> AddonProbeFactoryRoundtripManifest {
        let manifest = AddonProbeFactoryRoundtripManifest(
            inputArchive: inputArchive,
            resourcePath: resourcePath,
            extractedResourcePath: extractedResourcePath,
            decodedJSONPath: decodedJSONPath,
            reserializedCR2WPath: reserializedCR2WPath,
            originalSHA256: originalFacts?.sha256,
            rebuiltSHA256: rebuiltFacts?.sha256,
            originalSize: originalFacts?.size,
            rebuiltSize: rebuiltFacts?.size,
            originalFirst32: originalFacts?.first32,
            rebuiltFirst32: rebuiltFacts?.first32,
            originalMagic: originalFacts?.magic,
            rebuiltMagic: rebuiltFacts?.magic,
            cp77toolsCommandsAttempted: attempts,
            stagedArchivePath: stagedArchivePath,
            stagedArchiveSHA256: stagedArchiveSHA256,
            manifestPath: manifestURL.path,
            manualInstallCommand: manualInstallCommand,
            conclusion: conclusion,
            warnings: Array(Set(warnings)).sorted()
        )
        try JSONEncoder.cybermac.encode(manifest).write(to: manifestURL, options: [.atomic])
        return manifest
    }

    private func writeFactoryRowCloneManifest(
        archive: String,
        resource: String,
        sourceKey: String,
        newKey: String,
        editResult: AddonProbeFactoryRowCloneEditResult?,
        decodedOriginalJson: String?,
        decodedEditedJson: String?,
        rebuiltResource: String?,
        stagedArchive: String?,
        originalFacts: FactoryFileFacts?,
        editedFacts: FactoryFileFacts?,
        stagedArchiveSHA256: String?,
        attempts: [AddonProbeFactoryRoundtripCommandAttempt],
        conclusion: AddonProbeFactoryRowCloneConclusion,
        warnings: [String],
        manifestURL: URL,
        manualInstallCommand: String?
    ) throws -> AddonProbeFactoryRowCloneManifest {
        let manifest = AddonProbeFactoryRowCloneManifest(
            archive: archive,
            resource: resource,
            sourceKey: sourceKey,
            newKey: newKey,
            sourceRowsFound: editResult?.sourceRowsFound ?? 0,
            sourceRowPath: editResult?.sourceRowPath,
            rowsAddedCompiledData: editResult?.rowsAddedCompiledData ?? 0,
            rowsAddedData: editResult?.rowsAddedData ?? 0,
            decodedOriginalJson: decodedOriginalJson,
            decodedEditedJson: decodedEditedJson,
            rebuiltResource: rebuiltResource,
            stagedArchive: stagedArchive,
            originalResourceSHA256: originalFacts?.sha256,
            editedResourceSHA256: editedFacts?.sha256,
            stagedArchiveSHA256: stagedArchiveSHA256,
            originalResourceSize: originalFacts?.size,
            editedResourceSize: editedFacts?.size,
            cp77toolsCommandsAttempted: attempts,
            conclusion: conclusion,
            warnings: Array(Set(warnings)).sorted(),
            manifestPath: manifestURL.path,
            manualInstallCommand: manualInstallCommand
        )
        try JSONEncoder.cybermac.encode(manifest).write(to: manifestURL, options: [.atomic])
        return manifest
    }

    private struct XLFactoryRegistryManifestInputs {
        var modPath: String
        var archive: String
        var resource: String
        var editResult: AddonProbeXLFactoryRegistryEditResult?
        var rawEditResult: AddonProbeFactoryRegistryRawEditResult?
        var decodedOriginalJson: String?
        var decodedEditedJson: String?
        var rebuiltResource: String?
        var stagedArchive: String?
        var originalFacts: FactoryFileFacts?
        var editedFacts: FactoryFileFacts?
        var stagedArchiveSHA256: String?
        var attempts: [AddonProbeFactoryRoundtripCommandAttempt]
        var conclusion: AddonProbeXLFactoryRegistryStageConclusion
        var warnings: [String]
        var manifestURL: URL
        var manualInstallCommand: String?
        var baselineDeserializeStdout: String?
        var baselineDeserializeStderr: String?
        var deserializeStdout: String?
        var deserializeStderr: String?
    }

    private func writeXLFactoryRegistryManifest(
        _ inputs: XLFactoryRegistryManifestInputs
    ) throws -> AddonProbeXLFactoryRegistryStageManifest {
        let declaredCSVs = inputs.rawEditResult?.declaredFactoryPaths ?? inputs.editResult?.declaredFactoryPaths ?? []
        let alreadyPresentCSVs = inputs.rawEditResult?.alreadyPresentFactoryPaths ?? inputs.editResult?.alreadyPresentFactoryPaths ?? []
        let addedCSVs = inputs.rawEditResult?.addedFactoryPaths ?? inputs.editResult?.addedFactoryPaths ?? []
        let rowsAddedCompiled = inputs.rawEditResult?.rowsAddedCompiledData ?? inputs.editResult?.rowsAddedCompiledData ?? 0
        let rowsAddedData = inputs.rawEditResult?.rowsAddedData ?? inputs.editResult?.rowsAddedData ?? 0
        let clonedSourceRowPath = inputs.rawEditResult?.clonedSourceRowPath ?? inputs.editResult?.clonedSourceRowPath
        let clonedSourceRowPreview = inputs.rawEditResult?.clonedSourceRowText ?? inputs.editResult?.clonedSourceRowPreview
        let addedRowPreview = inputs.rawEditResult?.addedRowText ?? inputs.editResult?.addedRowPreview
        let compiledDataRowsBefore = inputs.rawEditResult?.compiledDataRowsBefore ?? inputs.editResult?.compiledDataRowsBefore
        let compiledDataRowsAfter = inputs.rawEditResult?.compiledDataRowsAfter ?? inputs.editResult?.compiledDataRowsAfter
        let dataRowsBefore = inputs.rawEditResult?.dataRowsBefore ?? inputs.editResult?.dataRowsBefore
        let dataRowsAfter = inputs.rawEditResult?.dataRowsAfter ?? inputs.editResult?.dataRowsAfter
        let compiledInsertion = inputs.rawEditResult?.compiledDataInsertion
        let dataInsertion = inputs.rawEditResult?.dataInsertion
        let manifest = AddonProbeXLFactoryRegistryStageManifest(
            modPath: inputs.modPath,
            archive: inputs.archive,
            resource: inputs.resource,
            declaredFactoryCSVs: declaredCSVs,
            alreadyPresentFactoryCSVs: alreadyPresentCSVs,
            addedFactoryCSVs: addedCSVs,
            rowsAddedCompiledData: rowsAddedCompiled,
            rowsAddedData: rowsAddedData,
            clonedSourceRowPath: clonedSourceRowPath,
            clonedSourceRowPreview: clonedSourceRowPreview,
            addedRowPreview: addedRowPreview,
            compiledDataRowsBefore: compiledDataRowsBefore,
            compiledDataRowsAfter: compiledDataRowsAfter,
            dataRowsBefore: dataRowsBefore,
            dataRowsAfter: dataRowsAfter,
            compiledDataInsertion: compiledInsertion,
            dataInsertion: dataInsertion,
            decodedOriginalJson: inputs.decodedOriginalJson,
            decodedEditedJson: inputs.decodedEditedJson,
            editedJsonPath: inputs.decodedEditedJson,
            rebuiltResource: inputs.rebuiltResource,
            stagedArchive: inputs.stagedArchive,
            originalResourceSHA256: inputs.originalFacts?.sha256,
            editedResourceSHA256: inputs.editedFacts?.sha256,
            stagedArchiveSHA256: inputs.stagedArchiveSHA256,
            originalResourceSize: inputs.originalFacts?.size,
            editedResourceSize: inputs.editedFacts?.size,
            cp77toolsCommandsAttempted: inputs.attempts,
            baselineDeserializeStdout: inputs.baselineDeserializeStdout,
            baselineDeserializeStderr: inputs.baselineDeserializeStderr,
            deserializeStdout: inputs.deserializeStdout,
            deserializeStderr: inputs.deserializeStderr,
            conclusion: inputs.conclusion,
            warnings: Array(Set(inputs.warnings)).sorted(),
            manifestPath: inputs.manifestURL.path,
            manualInstallCommand: inputs.manualInstallCommand
        )
        try JSONEncoder.cybermac.encode(manifest).write(to: inputs.manifestURL, options: [.atomic])
        return manifest
    }

    private func runRecordLayerProbe(
        modURL: URL,
        outputDirectoryURL: URL,
        cp77toolsURL rawCP77ToolsURL: URL,
        gameInstall: GameInstall,
        databaseURL rawDatabaseURL: URL,
        searchTerms: [String],
        reportFileName: String
    ) throws -> AddonProbeRecordLayerProbeReport {
        try home.bootstrap()
        let cp77toolsURL = rawCP77ToolsURL.standardizedFileURL
        try validateExecutableFile(cp77toolsURL, description: "cp77tools path")
        let outputRootURL = outputDirectoryURL.standardizedFileURL
        try validateOutputDirectory(outputRootURL, description: "Record-layer probe output directory")
        try validateOutsideGameBundle(outputRootURL, gameInstall: gameInstall, description: "Record-layer probe output directory")

        let root = try resolveModRoot(modURL)
        let discovery = try discover(root: root)
        let expandedRecords = discovery.tweakXLAnalysis.expandedItemRecords
        let baseCounts = Self.baseRecordCounts(expandedRecords)
        let expandedReportURL = outputRootURL.appendingPathComponent("tweakxl-expanded-records.json")
        let expandedReport = AddonProbeTweakXLExpandedRecordsReport(
            modPath: root.sourceURL.path,
            recordCount: expandedRecords.count,
            baseRecordCounts: baseCounts,
            records: expandedRecords,
            warnings: discovery.warnings
        )
        try JSONEncoder.cybermac.encode(expandedReport).write(to: expandedReportURL, options: [.atomic])

        let databaseURL = rawDatabaseURL.standardizedFileURL
        let databaseExists = FileManager.default.fileExists(atPath: databaseURL.path)
        let terms = Self.orderedUnique(searchTerms)
        let reportURL = outputRootURL.appendingPathComponent(reportFileName)
        let workRoot = outputRootURL.appendingPathComponent("record-layer-probe-\(stageID())", isDirectory: true)
        var warnings = discovery.warnings
        warnings.append("Record-layer probe is read-only. It does not mutate the game app, pack archives, or register TweakDB records.")
        if expandedRecords.isEmpty {
            warnings.append("No expanded TweakXL item records were found; tweakxl-expanded-records.json was still written.")
        }

        var indexSearches: [AddonProbeFactoryIndexSearchReport] = []
        var candidateResources: [AddonProbeRecordLayerCandidateResource] = []
        if databaseExists {
            let store = ArchiveCatalogIndexStore()
            var candidatesByKey: [String: (match: ArchiveCatalogIndexSearchMatch, terms: Set<String>)] = [:]
            for term in terms {
                let search = try store.search(options: ArchiveCatalogIndexSearchOptions(
                    query: term,
                    databaseURL: databaseURL,
                    limit: 50
                ))
                indexSearches.append(AddonProbeFactoryIndexSearchReport(
                    term: term,
                    exactResource: false,
                    totalMatchCount: search.totalMatchCount,
                    shownMatchCount: search.matches.count,
                    matches: search.matches
                ))
                for match in search.matches {
                    let key = "\(match.archivePath)\u{0}\(match.assetPath)"
                    var entry = candidatesByKey[key] ?? (match, [])
                    entry.terms.insert(term)
                    candidatesByKey[key] = entry
                }
            }
            candidateResources = candidatesByKey.values
                .map { entry in
                    AddonProbeRecordLayerCandidateResource(
                        archivePath: entry.match.archivePath,
                        assetPath: entry.match.assetPath,
                        assetExtension: entry.match.assetExtension,
                        category: entry.match.category,
                        matchedTerms: entry.terms.sorted()
                    )
                }
                .sorted {
                    if $0.archivePath != $1.archivePath { return $0.archivePath < $1.archivePath }
                    return $0.assetPath < $1.assetPath
                }
        } else {
            warnings.append("Archive catalog index database was not found; resource extraction was skipped.")
        }

        var diagnostics: [AddonProbeRecordLayerResourceDiagnostic] = []
        var attempts: [AddonProbeFactoryRoundtripCommandAttempt] = []
        var decodedTextMatches: [AddonProbeRecordLayerTextMatch] = []
        var extractionArchivePaths: [String] = []

        if databaseExists, !candidateResources.isEmpty {
            try FileManager.default.createDirectory(at: workRoot, withIntermediateDirectories: true)
            let extractedRoot = workRoot.appendingPathComponent("extracted", isDirectory: true)
            let decodedRoot = workRoot.appendingPathComponent("decoded", isDirectory: true)
            try FileManager.default.createDirectory(at: extractedRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: decodedRoot, withIntermediateDirectories: true)

            let candidatesByArchive = Dictionary(grouping: candidateResources, by: \.archivePath)
            for archivePath in candidatesByArchive.keys.sorted() {
                let sourceArchiveURL: URL
                do {
                    sourceArchiveURL = try resolveFactoryRoundtripArchiveURL(archivePath: archivePath, gameInstall: gameInstall)
                    try validateRegularFile(sourceArchiveURL, description: "Record-layer source archive")
                } catch {
                    warnings.append("Candidate archive could not be resolved for extraction: \(archivePath): \(error.localizedDescription)")
                    continue
                }
                extractionArchivePaths.append(sourceArchiveURL.path)
                let archiveExtractRoot = extractedRoot.appendingPathComponent(Self.safeFilename(archivePath), isDirectory: true)
                do {
                    try recordRoundtripArchiveToolingCommand(
                        cp77toolsURL: cp77toolsURL,
                        arguments: CP77ToolsArchiveSwapTooling.extractArguments(
                            sourceArchiveURL: sourceArchiveURL,
                            outputDirectoryURL: archiveExtractRoot
                        ),
                        attempts: &attempts,
                        operation: "Record-layer candidate archive extraction"
                    ) {
                        try tooling.extractArchive(
                            cp77toolsURL: cp77toolsURL,
                            sourceArchiveURL: sourceArchiveURL,
                            outputDirectoryURL: archiveExtractRoot
                        )
                    }
                } catch {
                    warnings.append("Record-layer candidate archive extraction failed for \(archivePath): \(error.localizedDescription)")
                    continue
                }

                for candidate in candidatesByArchive[archivePath, default: []].sorted(by: { $0.assetPath < $1.assetPath }) {
                    let localURL: URL
                    do {
                        localURL = try assetURL(assetPath: candidate.assetPath, rootURL: archiveExtractRoot, label: "Record-layer candidate resource")
                    } catch {
                        warnings.append("Candidate resource path could not be resolved after extraction: \(candidate.assetPath): \(error.localizedDescription)")
                        continue
                    }

                    guard FileManager.default.fileExists(atPath: localURL.path) else {
                        let message = "Candidate resource was not found after extraction: \(candidate.assetPath)"
                        diagnostics.append(AddonProbeRecordLayerResourceDiagnostic(
                            archivePath: archivePath,
                            resourcePath: candidate.assetPath,
                            extractedPath: localURL.path,
                            exists: false,
                            size: nil,
                            first32BytesHex: "",
                            detectedMagic: .empty,
                            parseStatus: .missing,
                            warnings: [message]
                        ))
                        warnings.append(message)
                        continue
                    }

                    let data = try Data(contentsOf: localURL)
                    let factoryDiagnostic = Self.diagnoseFactoryResource(
                        resourcePath: candidate.assetPath,
                        archivePath: archivePath,
                        extractedPath: localURL.path,
                        data: data
                    )
                    diagnostics.append(AddonProbeRecordLayerResourceDiagnostic(
                        archivePath: archivePath,
                        resourcePath: candidate.assetPath,
                        extractedPath: localURL.path,
                        exists: true,
                        size: factoryDiagnostic.size,
                        first32BytesHex: factoryDiagnostic.first32BytesHex,
                        detectedMagic: factoryDiagnostic.detectedMagic,
                        parseStatus: factoryDiagnostic.parseStatus,
                        warnings: factoryDiagnostic.warnings
                    ))

                    if let text = String(data: data, encoding: .utf8) {
                        decodedTextMatches.append(contentsOf: Self.recordLayerMatches(
                            text: text,
                            sourcePath: localURL.path,
                            resourcePath: candidate.assetPath,
                            archivePath: archivePath,
                            terms: terms
                        ))
                    }

                    if factoryDiagnostic.detectedMagic == .cr2w {
                        let resourceDecodedRoot = decodedRoot.appendingPathComponent(
                            "\(Self.safeFilename(archivePath))-\(Self.safeFilename(candidate.assetPath))",
                            isDirectory: true
                        )
                        try FileManager.default.createDirectory(at: resourceDecodedRoot, withIntermediateDirectories: true)
                        let result = runRoundtripCP77ToolsCommand(
                            cp77toolsURL: cp77toolsURL,
                            arguments: ["convert", "serialize", localURL.path, "--outpath", resourceDecodedRoot.path],
                            timeout: 120,
                            attempts: &attempts
                        )
                        guard result?.exitCode == 0 else {
                            warnings.append("cp77tools convert serialize failed for candidate record-layer resource: \(candidate.assetPath)")
                            continue
                        }
                        let decodedFiles = try regularFiles(under: resourceDecodedRoot, description: "Record-layer decoded CR2W output")
                        if decodedFiles.isEmpty {
                            warnings.append("cp77tools convert serialize produced no decoded files for candidate record-layer resource: \(candidate.assetPath)")
                        }
                        for file in decodedFiles {
                            guard let text = try readSmallTextFile(file.url) else { continue }
                            decodedTextMatches.append(contentsOf: Self.recordLayerMatches(
                                text: text,
                                sourcePath: file.url.path,
                                resourcePath: candidate.assetPath,
                                archivePath: archivePath,
                                terms: terms
                            ))
                        }
                    }
                }
            }
        }

        let likelyPatchable = candidateResources.contains(where: Self.isLikelyPatchableRecordLayerCandidate)
        if !databaseExists {
            warnings.append("No archive index was available, so CyberMac could not determine whether a patchable item-record layer exists.")
        } else if candidateResources.isEmpty {
            warnings.append("No candidate record/static-data resources were found in the archive index for the requested terms.")
        } else if !likelyPatchable {
            warnings.append("Candidate resources were found, but none look like a patchable .tweak/.tdb item-record layer. True add-on item registration remains unresolved.")
        } else {
            warnings.append("Candidate .tweak/.tdb record-layer resources were found, but CyberMac does not support patching them yet.")
        }

        let conclusion: AddonProbeRecordLayerProbeConclusion
        if !databaseExists {
            conclusion = .archiveIndexMissing
        } else if candidateResources.isEmpty {
            conclusion = .noCandidateResources
        } else if likelyPatchable {
            conclusion = .patchableRecordLayerCandidateFound
        } else {
            conclusion = .candidateResourcesFoundNoRecordDefinitions
        }

        let report = AddonProbeRecordLayerProbeReport(
            modPath: root.sourceURL.path,
            outputDirectoryPath: outputRootURL.path,
            expandedRecordsPath: expandedReportURL.path,
            expandedRecords: expandedRecords,
            baseRecordCounts: baseCounts,
            searchTerms: terms,
            indexDatabasePath: databaseURL.path,
            indexDatabaseExists: databaseExists,
            indexSearches: indexSearches,
            candidateResources: candidateResources,
            extractionArchivePaths: extractionArchivePaths,
            resourceDiagnostics: diagnostics.sorted {
                if $0.archivePath != $1.archivePath { return $0.archivePath < $1.archivePath }
                return $0.resourcePath < $1.resourcePath
            },
            cp77toolsCommandsAttempted: attempts,
            decodedTextMatches: decodedTextMatches.sorted {
                if $0.sourcePath != $1.sourcePath { return $0.sourcePath < $1.sourcePath }
                if ($0.lineNumber ?? -1) != ($1.lineNumber ?? -1) { return ($0.lineNumber ?? -1) < ($1.lineNumber ?? -1) }
                if ($0.jsonPath ?? "") != ($1.jsonPath ?? "") { return ($0.jsonPath ?? "") < ($1.jsonPath ?? "") }
                return $0.term < $1.term
            },
            likelyPatchableRecordLayerFound: likelyPatchable,
            conclusion: conclusion,
            warnings: Array(Set(warnings)).sorted(),
            reportPath: reportURL.path
        )
        try JSONEncoder.cybermac.encode(report).write(to: reportURL, options: [.atomic])
        return report
    }

    private static func baseRecordCounts(_ records: [AddonProbeExpandedItemRecord]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for record in records {
            guard let baseRecord = record.baseRecord else { continue }
            counts[baseRecord, default: 0] += 1
        }
        return counts
    }

    private static func isLikelyPatchableRecordLayerCandidate(_ candidate: AddonProbeRecordLayerCandidateResource) -> Bool {
        let ext = candidate.assetExtension.lowercased()
        let path = candidate.assetPath.lowercased()
        return ext == "tweak" ||
            ext == "tdb" ||
            path.hasSuffix(".tweak") ||
            path.hasSuffix(".tdb")
    }

    private static func recordLayerMatches(
        text: String,
        sourcePath: String,
        resourcePath: String,
        archivePath: String?,
        terms: [String]
    ) -> [AddonProbeRecordLayerTextMatch] {
        var matches: [AddonProbeRecordLayerTextMatch] = []
        let loweredTerms = terms.map { ($0, $0.lowercased()) }
        if let jsonMatches = recordLayerJSONMatches(
            text: text,
            sourcePath: sourcePath,
            resourcePath: resourcePath,
            archivePath: archivePath,
            terms: loweredTerms
        ) {
            matches.append(contentsOf: jsonMatches)
        }

        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            for (term, lowerTerm) in loweredTerms where lowerLine.contains(lowerTerm) {
                matches.append(AddonProbeRecordLayerTextMatch(
                    term: term,
                    archivePath: archivePath,
                    resourcePath: resourcePath,
                    sourcePath: sourcePath,
                    lineNumber: index + 1,
                    jsonPath: nil,
                    matchedString: clippedMatchString(line)
                ))
            }
        }
        return dedupeRecordLayerMatches(matches)
    }

    private static func recordLayerJSONMatches(
        text: String,
        sourcePath: String,
        resourcePath: String,
        archivePath: String?,
        terms: [(term: String, lowerTerm: String)]
    ) -> [AddonProbeRecordLayerTextMatch]? {
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data, options: [])
        else {
            return nil
        }
        var values: [FactoryJSONStringValue] = []
        collectFactoryJSONStringValues(parsed, path: "$", into: &values)
        var keys: [FactoryJSONStringValue] = []
        collectFactoryJSONKeyValues(parsed, path: "$", into: &keys)
        var matches: [AddonProbeRecordLayerTextMatch] = []
        for entry in values + keys {
            let lowerValue = entry.value.lowercased()
            let lowerPath = entry.path.lowercased()
            for (term, lowerTerm) in terms where lowerValue.contains(lowerTerm) || lowerPath.contains(lowerTerm) {
                matches.append(AddonProbeRecordLayerTextMatch(
                    term: term,
                    archivePath: archivePath,
                    resourcePath: resourcePath,
                    sourcePath: sourcePath,
                    lineNumber: nil,
                    jsonPath: entry.path,
                    matchedString: clippedMatchString(entry.value)
                ))
            }
        }
        return matches
    }

    private static func collectFactoryJSONKeyValues(_ node: Any, path: String, into values: inout [FactoryJSONStringValue]) {
        if let object = node as? [String: Any] {
            for key in object.keys.sorted() {
                let keyPath = jsonPathAppendingKey(key, to: path)
                values.append(FactoryJSONStringValue(path: keyPath, value: key))
                collectFactoryJSONKeyValues(object[key] as Any, path: keyPath, into: &values)
            }
        } else if let array = node as? [Any] {
            for (index, item) in array.enumerated() {
                collectFactoryJSONKeyValues(item, path: "\(path)[\(index)]", into: &values)
            }
        }
    }

    private static func dedupeRecordLayerMatches(_ matches: [AddonProbeRecordLayerTextMatch]) -> [AddonProbeRecordLayerTextMatch] {
        var seen = Set<String>()
        var result: [AddonProbeRecordLayerTextMatch] = []
        for match in matches {
            let key = [
                match.term,
                match.archivePath ?? "",
                match.resourcePath,
                match.sourcePath,
                match.lineNumber.map(String.init) ?? "",
                match.jsonPath ?? "",
                match.matchedString
            ].joined(separator: "\u{0}")
            guard seen.insert(key).inserted else { continue }
            result.append(match)
        }
        return result
    }

    private static func clippedMatchString(_ value: String, limit: Int = 500) -> String {
        let oneLine = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard oneLine.count > limit else { return oneLine }
        return String(oneLine.prefix(limit - 13)) + "... truncated"
    }

    private func factoryLayerWorkRoot(outputDirectoryURL: URL?) throws -> URL {
        let root = (outputDirectoryURL?.standardizedFileURL ?? home.archiveProbeTmpURL)
            .appendingPathComponent("factory-layer-\(stageID())", isDirectory: true)
        try validateOutputDirectory(root, description: "Factory-layer work directory")
        return root
    }

    private func uniqueIndexMatches(_ matches: [ArchiveCatalogIndexSearchMatch]) -> [ArchiveCatalogIndexSearchMatch] {
        var seen = Set<String>()
        var result: [ArchiveCatalogIndexSearchMatch] = []
        for match in matches.sorted(by: {
            if $0.archivePath != $1.archivePath { return $0.archivePath < $1.archivePath }
            return $0.assetPath < $1.assetPath
        }) {
            let key = "\(match.archivePath)\u{0}\(match.assetPath)\u{0}\(match.sourceCatalogFile)"
            guard seen.insert(key).inserted else { continue }
            result.append(match)
        }
        return result
    }

    private static func normalizedFactoryPath(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/").lowercased()
    }

    private static func archivePath(for resourcePath: String, in matches: [ArchiveCatalogIndexSearchMatch]) -> String? {
        matches.first { normalizedFactoryPath($0.assetPath) == normalizedFactoryPath(resourcePath) }?.archivePath
    }

    private static func safeFilename(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber || character == "." || character == "-" ? character : "_"
        }
        .map(String.init)
        .joined()
    }

    private static func supportedOutputFlag(in helpText: String) -> String? {
        if helpText.contains("--outpath") { return "--outpath" }
        if helpText.contains("--outdir") { return "--outdir" }
        if helpText.contains("--output") { return "--output" }
        if helpText.contains("--out") { return "--out" }
        return nil
    }

    private static func clippedProcessOutput(_ output: String, limit: Int = 4_000) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "\n... truncated ..."
    }

    private static func decodeWarnings(exitCode: Int32, textSummaryCount: Int) -> [String] {
        var warnings: [String] = []
        if exitCode != 0 {
            warnings.append("CR2W conversion command exited non-zero.")
        }
        if textSummaryCount == 0 {
            warnings.append("CR2W factory resource extracted but no readable decoded text output was produced.")
        }
        return warnings
    }

    private func stageID() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return "\(formatter.string(from: dateProvider()))-\(idProvider().prefix(8))"
    }

    private func validateOutputDirectory(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.invalidInput("\(description) is not a directory: \(url.path)")
        }
    }

    private func validateReadableDirectory(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("\(description) is not a directory: \(url.path)")
        }
    }

    private func validateRegularFile(_ url: URL, description: String) throws {
        try validateLocalURL(url, description: description)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("\(description) is a symlink: \(url.path)")
        }
        guard values.isRegularFile == true else {
            throw CyberMacError.invalidInput("\(description) is not a regular file: \(url.path)")
        }
    }

    private func validateExecutableFile(_ url: URL, description: String) throws {
        try validateRegularFile(url, description: description)
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CyberMacError.invalidInput("\(description) is not executable: \(url.path)")
        }
    }

    private func validateOutsideGameBundle(_ url: URL, gameInstall: GameInstall, description: String) throws {
        let gameRoot = gameInstall.appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = gameRoot.hasSuffix("/") ? gameRoot : gameRoot + "/"
        guard targetPath != gameRoot, !targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) must not be inside the game bundle: \(targetPath)")
        }
    }

    private func validateLocalURL(_ url: URL, description: String) throws {
        guard url.isFileURL else {
            throw CyberMacError.unsafePath("\(description) must be a file URL: \(url.absoluteString)")
        }
        let path = url.path
        guard path.hasPrefix("/") else {
            throw CyberMacError.unsafePath("\(description) path must be absolute: \(path)")
        }
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.unsafePath("\(description) path is empty.")
        }
        guard !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("\(description) path contains control characters.")
        }
        guard !path.split(separator: "/", omittingEmptySubsequences: true).contains("..") else {
            throw CyberMacError.unsafePath("\(description) path contains traversal: \(path)")
        }
    }

    private func validateContainedPath(_ targetURL: URL, in rootURL: URL, description: String) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath == rootPath || targetPath.hasPrefix(prefix) else {
            throw CyberMacError.unsafePath("\(description) escapes expected root: \(targetPath)")
        }
    }

    private static func sortedMatches(pattern: String, text: String) -> [String] {
        var values = Set<String>()
        for match in regexMatches(pattern: pattern, text: text) {
            let rangeIndex = match.numberOfRanges > 1 ? 1 : 0
            guard let range = Range(match.range(at: rangeIndex), in: text) else { continue }
            let value = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\",;:()[]{}"))
            guard !value.isEmpty else { continue }
            values.insert(value)
        }
        return values.sorted()
    }

    private static func regexMatches(pattern: String, text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        return regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }
}

public enum AddonProbeInspectFormatter {
    public static func format(_ report: AddonProbeInspectReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe inspect",
            "Status: experimental Path B probe; true add-on clothing is not solved.",
            "Source: \(PathSafety.redactUserPath(report.sourceModPath))",
            "Input kind: \(report.inputKind.rawValue)",
            "Classification: \(report.classification.rawValue)",
            "Archives: \(report.archiveFiles.count)",
            "XL metadata files: \(report.xlFiles.count)",
            "Tweak YAML files: \(report.tweakFiles.count)",
            "CSV files: \(report.csvFiles.count)",
            "JSON localization candidates: \(report.jsonLocalizationFiles.count)",
            "Candidate item IDs: \(report.candidateItemIDs.count)",
            "Expanded item IDs: \(report.expandedItemIDs.count)",
            "TweakXL instances: \(report.instanceCount)",
            "Resource references: \(report.candidateResourceReferences.count)"
        ]
        appendList("Archive files", report.archiveFiles, to: &lines)
        appendList("XL files", report.xlFiles, to: &lines)
        appendList("Tweak YAML files", report.tweakFiles, to: &lines)
        appendList("Candidate item IDs", report.candidateItemIDs, to: &lines)
        appendList("Templated item records", report.templatedItemRecords, to: &lines)
        appendList("Expanded item IDs", report.expandedItemIDs, to: &lines)
        appendList("Base records", report.baseRecords, to: &lines)
        appendList("Placement slots", report.placementSlots, to: &lines)
        appendList("Appearance names", report.appearanceNames, to: &lines)
        appendList("Entity names", report.entityNames, to: &lines)
        appendList("Display names", report.displayNames, to: &lines)
        appendList("Icon atlas paths", report.iconAtlasPaths, to: &lines)
        appendList("Icon atlas parts", report.iconAtlasParts, to: &lines)
        appendList("XL factory CSV files", report.factoryCSVFilesFromXL, to: &lines)
        appendList("XL localization JSON files", report.localizationJSONFilesFromXL, to: &lines)
        appendList("Unresolved template expressions", report.unresolvedTemplateExpressions, to: &lines)
        appendList("Candidate base/parent/appearance records", report.candidateBaseRecords, to: &lines)
        appendList("Candidate resource references", report.candidateResourceReferences, to: &lines)
        appendList("Reasons", report.reasons, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        if let writtenReportPath = report.writtenReportPath {
            lines.append("")
            lines.append("Wrote JSON report: \(PathSafety.redactUserPath(writtenReportPath))")
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeInspectReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 50) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeStageFormatter {
    public static func format(_ manifest: AddonProbeStageManifest) -> String {
        var lines: [String] = [
            "CyberMac add-on probe staged assets",
            "Status: experimental Path B probe; assets alone do not register custom items.",
            "Target archive: \(manifest.targetArchiveRelativePath)",
            "Profile: \(manifest.profileID)",
            "Extracted mod assets: \(manifest.extractedAssetPaths.count)",
            "Exact-match replacement assets: \(manifest.exactMatchAssets.count)",
            "Added/custom assets: \(manifest.addedCustomAssets.count)",
            "Staged archive: \(PathSafety.redactUserPath(manifest.stagedArchivePath))",
            "SHA-256: \(manifest.stagedSHA256)",
            "Manifest: \(PathSafety.redactUserPath(manifest.manifestPath))",
            "",
            "Manual install command:",
            manifest.manualInstallCommand,
            "",
            "Warning: if the item ID is not registered in TweakDB, this archive can load assets and still grant nothing."
        ]
        if !manifest.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in manifest.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum AddonProbeGrantManyFormatter {
    public static func format(_ result: AddonProbeGrantManyResult) -> String {
        var lines: [String] = [
            "CyberMac add-on probe grant helper",
            "Status: experimental Path B probe; this does not register TweakDB records.",
            "Input: \(PathSafety.redactUserPath(result.inputPath))",
            "Output zip: \(PathSafety.redactUserPath(result.outputZipPath))",
            "Mod name: \(result.modName)",
            "Entry path: \(result.redscriptEntryPath)",
            "Item IDs (\(result.itemIDs.count)):"
        ]
        for itemID in result.itemIDs {
            lines.append("  - \(itemID)")
        }
        if !result.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in result.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum AddonProbeAtomiicSummaryFormatter {
    public static func format(_ report: AddonProbeAtomiicSummaryReport) -> String {
        var lines: [String] = [
            "CyberMac Atomiic add-on probe summary",
            "Status: experimental Path B summary; true add-on clothing is not solved.",
            "Mod: \(PathSafety.redactUserPath(report.modPath))",
            "Total expanded items: \(report.totalExpandedItems)",
            "Shirts: \(report.shirtsCount)",
            "Skirts: \(report.skirtsCount)"
        ]
        appendList("Archive files", report.archiveFiles, to: &lines)
        appendList("Factory CSV from XL", report.factoryCSVFilesFromXL, to: &lines)
        appendList("Localization JSON from XL", report.localizationJSONFilesFromXL, to: &lines)
        appendList("Icon atlas", report.iconAtlasPaths, to: &lines)
        appendList("Expected unresolved layers", report.expectedUnresolvedLayers, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeAtomiicSummaryReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values {
            lines.append("- \(value)")
        }
    }
}

public enum AddonProbeXLFactoryAnalysisFormatter {
    public static func format(_ report: AddonProbeXLFactoryAnalysisReport) -> String {
        var lines: [String] = [
            "CyberMac XL factory analysis",
            "Status: experimental Path B probe; true add-on clothing is not solved.",
            "Mod: \(PathSafety.redactUserPath(report.modPath))",
            "Conclusion: \(report.conclusion.rawValue)",
            "Archives: \(report.archiveFiles.count)",
            "XL files: \(report.xlFiles.count)",
            "Declared factory CSVs: \(report.declaredFactoryCSVs.count)",
            "Declared localization JSONs: \(report.declaredLocalizationJSONs.count)"
        ]
        appendList("Factory CSVs from XL", report.declaredFactoryCSVs, to: &lines)
        appendList("Localization JSONs from XL", report.declaredLocalizationJSONs, to: &lines)
        if !report.extractedResourceDiagnostics.isEmpty {
            lines.append("")
            lines.append("Declared resource diagnostics:")
            for diagnostic in report.extractedResourceDiagnostics {
                lines.append("- \(diagnostic.resourcePath): exists=\(diagnostic.exists), magic=\(diagnostic.detectedMagic.rawValue), size=\(diagnostic.size.map(String.init) ?? "n/a")")
                if let path = diagnostic.extractedPath {
                    lines.append("  path: \(PathSafety.redactUserPath(path))")
                }
            }
        }
        appendList("Decoded factory JSON", report.decodedFactoryJSONPaths.map(PathSafety.redactUserPath), to: &lines)
        appendList("Decoded localization", report.decodedLocalizationPaths.map(PathSafety.redactUserPath), to: &lines)
        for summary in report.factoryJSONSummaries {
            lines.append("")
            lines.append("Factory JSON summary: \(summary.resourcePath)")
            lines.append("- top-level keys: \(summary.topLevelKeys.joined(separator: ", "))")
            lines.append("- compiledData rows: \(summary.compiledDataRowCount.map(String.init) ?? "n/a")")
            lines.append("- data rows: \(summary.dataRowCount.map(String.init) ?? "n/a")")
            appendList("  .ent references", summary.entReferences, to: &lines, limit: 10)
            appendList("  .app references", summary.appReferences, to: &lines, limit: 10)
            appendList("  Atomiic strings", summary.atomiicStrings, to: &lines, limit: 20)
            appendList("  Shirt strings", summary.shirtStrings, to: &lines, limit: 10)
            appendList("  Skirt strings", summary.skirtStrings, to: &lines, limit: 10)
            appendList("  Slot strings", summary.slotStrings, to: &lines, limit: 10)
        }
        appendList("Matched entity names", report.yamlComparison.matchedEntityNames, to: &lines)
        appendList("Missing entity names", report.yamlComparison.missingEntityNames, to: &lines)
        appendList("Matched appearance names", report.yamlComparison.matchedAppearanceNames, to: &lines)
        appendList("Missing appearance names", report.yamlComparison.missingAppearanceNames, to: &lines)
        appendList("Matched display names", report.yamlComparison.matchedDisplayNames, to: &lines)
        appendList("Missing display names", report.yamlComparison.missingDisplayNames, to: &lines)
        appendList("Matched icon atlas paths", report.yamlComparison.matchedIconAtlasPaths, to: &lines)
        appendList("Missing icon atlas paths", report.yamlComparison.missingIconAtlasPaths, to: &lines)
        appendList("Warnings", report.warnings, to: &lines)
        lines.append("")
        lines.append("Report: \(PathSafety.redactUserPath(report.reportPath))")
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeXLFactoryAnalysisReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 50) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeXLFactoryRegistryStageFormatter {
    public static func format(_ manifest: AddonProbeXLFactoryRegistryStageManifest) -> String {
        var lines: [String] = [
            "CyberMac XL factory registry staged archive",
            "Status: experimental Path B probe; this only simulates ArchiveXL factory registration.",
            "Conclusion: \(manifest.conclusion.rawValue)",
            "Archive: \(PathSafety.redactUserPath(manifest.archive))",
            "Resource: \(manifest.resource)",
            "Rows added in compiledData: \(manifest.rowsAddedCompiledData)",
            "Rows added in data: \(manifest.rowsAddedData)"
        ]
        if let clonedSourceRowPath = manifest.clonedSourceRowPath {
            lines.append("Cloned source row path: \(clonedSourceRowPath)")
        }
        if let clonedSourceRowPreview = manifest.clonedSourceRowPreview {
            lines.append("Cloned source row preview: \(clonedSourceRowPreview)")
        }
        if let addedRowPreview = manifest.addedRowPreview {
            lines.append("Added row preview: \(addedRowPreview)")
        }
        lines.append("compiledData rows before/after: \(manifest.compiledDataRowsBefore.map(String.init) ?? "n/a") / \(manifest.compiledDataRowsAfter.map(String.init) ?? "n/a")")
        lines.append("data rows before/after: \(manifest.dataRowsBefore.map(String.init) ?? "n/a") / \(manifest.dataRowsAfter.map(String.init) ?? "n/a")")
        if let editedJsonPath = manifest.editedJsonPath {
            lines.append("Edited JSON: \(PathSafety.redactUserPath(editedJsonPath))")
        }
        if let compiledInsertion = manifest.compiledDataInsertion {
            lines.append("compiledData insertion: \(compiledInsertion.arrayPath) @ offset \(compiledInsertion.insertionOffset) (line \(compiledInsertion.insertionLine))")
            lines.append("compiledData insertion context:")
            lines.append(compiledInsertion.context)
        }
        if let dataInsertion = manifest.dataInsertion {
            lines.append("data insertion: \(dataInsertion.arrayPath) @ offset \(dataInsertion.insertionOffset) (line \(dataInsertion.insertionLine))")
            lines.append("data insertion context:")
            lines.append(dataInsertion.context)
        }
        if let baselineStdout = manifest.baselineDeserializeStdout, !baselineStdout.isEmpty {
            lines.append("Baseline deserialize stdout: \(baselineStdout)")
        }
        if let baselineStderr = manifest.baselineDeserializeStderr, !baselineStderr.isEmpty {
            lines.append("Baseline deserialize stderr: \(baselineStderr)")
        }
        if let deserializeStdout = manifest.deserializeStdout, !deserializeStdout.isEmpty {
            lines.append("Deserialize stdout: \(deserializeStdout)")
        }
        if let deserializeStderr = manifest.deserializeStderr, !deserializeStderr.isEmpty {
            lines.append("Deserialize stderr: \(deserializeStderr)")
        }
        appendList("Declared factory CSVs", manifest.declaredFactoryCSVs, to: &lines)
        appendList("Already present factory CSVs", manifest.alreadyPresentFactoryCSVs, to: &lines)
        appendList("Added factory CSVs", manifest.addedFactoryCSVs, to: &lines)
        if let originalSHA = manifest.originalResourceSHA256 {
            lines.append("Original factories.csv SHA-256: \(originalSHA)")
        }
        if let editedSHA = manifest.editedResourceSHA256 {
            lines.append("Edited factories.csv SHA-256: \(editedSHA)")
        }
        if let stagedArchive = manifest.stagedArchive {
            lines.append("Staged archive: \(PathSafety.redactUserPath(stagedArchive))")
        }
        if let stagedSHA = manifest.stagedArchiveSHA256 {
            lines.append("Staged archive SHA-256: \(stagedSHA)")
        }
        lines.append("Manifest: \(PathSafety.redactUserPath(manifest.manifestPath))")
        if let manualInstallCommand = manifest.manualInstallCommand {
            lines.append("")
            lines.append("Manual install command:")
            lines.append(manualInstallCommand)
        }
        appendList("Warnings", manifest.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ manifest: AddonProbeXLFactoryRegistryStageManifest) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(manifest), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 50) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeRecordLayerFormatter {
    public static func format(_ report: AddonProbeRecordLayerSearchReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe record-layer search",
            "Status: \(report.status)",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Limit per query: \(report.limit)"
        ]
        if !report.databaseExists {
            lines.append("Database exists: no")
            lines.append("")
            lines.append("Equivalent commands:")
            lines.append(contentsOf: report.commands)
        } else {
            lines.append("Database exists: yes")
            lines.append("Likely patchable record layer found: \(report.likelyPatchableRecordLayerFound ? "yes" : "no")")
            for queryReport in report.queryReports {
                lines.append("")
                lines.append("Query: \(queryReport.query)")
                lines.append("Command: \(queryReport.command)")
                lines.append("Matches: \(queryReport.shownMatchCount) of \(queryReport.totalMatchCount)")
                for match in queryReport.matches.prefix(10) {
                    lines.append("- \(match.archivePath) | \(match.assetPath) | \(match.assetExtension)")
                }
            }
        }
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in report.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum AddonProbeRecordLayerProbeFormatter {
    public static func format(_ report: AddonProbeRecordLayerProbeReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe record-layer probe",
            "Status: read-only Path B probe; true add-on clothing is not solved.",
            "Conclusion: \(report.conclusion.rawValue)",
            "Expanded TweakXL records: \(report.expandedRecords.count)",
            "Expanded records JSON: \(PathSafety.redactUserPath(report.expandedRecordsPath))",
            "Archive index DB: \(PathSafety.redactUserPath(report.indexDatabasePath))",
            "Index DB exists: \(report.indexDatabaseExists ? "yes" : "no")",
            "Candidate resources: \(report.candidateResources.count)",
            "Likely patchable record layer found: \(report.likelyPatchableRecordLayerFound ? "yes" : "no")",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]
        if !report.baseRecordCounts.isEmpty {
            lines.append("")
            lines.append("Base record counts:")
            for key in report.baseRecordCounts.keys.sorted() {
                lines.append("- \(key): \(report.baseRecordCounts[key] ?? 0)")
            }
        }
        appendList("Search terms", report.searchTerms, to: &lines)
        if !report.candidateResources.isEmpty {
            lines.append("")
            lines.append("Candidate resources:")
            for candidate in report.candidateResources.prefix(100) {
                lines.append("- \(candidate.archivePath) | \(candidate.assetPath) | terms: \(candidate.matchedTerms.joined(separator: ", "))")
            }
            if report.candidateResources.count > 100 {
                lines.append("- ... \(report.candidateResources.count - 100) more")
            }
        }
        if !report.resourceDiagnostics.isEmpty {
            lines.append("")
            lines.append("Resource diagnostics:")
            for diagnostic in report.resourceDiagnostics.prefix(100) {
                lines.append("- \(diagnostic.archivePath) | \(diagnostic.resourcePath)")
                if let extractedPath = diagnostic.extractedPath {
                    lines.append("  path: \(PathSafety.redactUserPath(extractedPath))")
                }
                lines.append("  exists: \(diagnostic.exists ? "yes" : "no"), magic: \(diagnostic.detectedMagic.rawValue), parse: \(diagnostic.parseStatus.rawValue), size: \(diagnostic.size.map(String.init) ?? "n/a")")
                for warning in diagnostic.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }
        if !report.decodedTextMatches.isEmpty {
            lines.append("")
            lines.append("Decoded/text matches:")
            for match in report.decodedTextMatches.prefix(100) {
                let location = match.jsonPath ?? match.lineNumber.map { "line \($0)" } ?? "unknown location"
                lines.append("- \(match.term) in \(PathSafety.redactUserPath(match.sourcePath)) @ \(location): \(match.matchedString)")
            }
            if report.decodedTextMatches.count > 100 {
                lines.append("- ... \(report.decodedTextMatches.count - 100) more")
            }
        }
        if !report.cp77toolsCommandsAttempted.isEmpty {
            lines.append("")
            lines.append("cp77tools commands attempted: \(report.cp77toolsCommandsAttempted.count)")
            for attempt in report.cp77toolsCommandsAttempted.prefix(50) {
                lines.append("- exit \(attempt.exitCode.map(String.init) ?? "(not run)"): \(attempt.command)")
                for warning in attempt.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeRecordLayerProbeReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 100) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeRecordRuntimeProbeFormatter {
    public static func format(_ result: AddonProbeRecordRuntimeProbeResult) -> String {
        var lines: [String] = [
            "CyberMac add-on probe record-runtime probe",
            "Status: read-only redscript probe; it does not grant items or register records.",
            "Input: \(PathSafety.redactUserPath(result.inputPath))",
            "Output zip: \(PathSafety.redactUserPath(result.outputZipPath))",
            "Mod name: \(result.modName)",
            "Entry path: \(result.redscriptEntryPath)",
            "Base records: \(result.baseRecordIDs.count)",
            "Custom records: \(result.customRecordIDs.count)"
        ]
        appendList("Base record IDs", result.baseRecordIDs, to: &lines)
        appendList("Custom record IDs", result.customRecordIDs, to: &lines)
        appendList("Warnings", result.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 100) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeCompareBaseRecordsFormatter {
    public static func format(_ report: AddonProbeCompareBaseRecordsReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe compare base records",
            "Status: read-only Path B probe; true add-on clothing is not solved.",
            "Conclusion: \(report.conclusion.rawValue)",
            "Summary: \(report.summary)",
            "Layer report: \(PathSafety.redactUserPath(report.recordLayerReportPath))",
            "Report: \(PathSafety.redactUserPath(report.reportPath))"
        ]
        for baseRecord in report.baseRecordIDs {
            let matches = report.matchesByBaseRecord[baseRecord] ?? []
            lines.append("")
            lines.append("\(baseRecord): \(matches.count) match(es)")
            for match in matches.prefix(25) {
                let location = match.jsonPath ?? match.lineNumber.map { "line \($0)" } ?? "unknown location"
                lines.append("- \(PathSafety.redactUserPath(match.sourcePath)) @ \(location): \(match.matchedString)")
            }
        }
        appendList("Warnings", report.warnings, to: &lines)
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeCompareBaseRecordsReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func appendList(_ title: String, _ values: [String], to lines: inout [String], limit: Int = 100) {
        guard !values.isEmpty else { return }
        lines.append("")
        lines.append("\(title):")
        for value in values.prefix(limit) {
            lines.append("- \(value)")
        }
        if values.count > limit {
            lines.append("- ... \(values.count - limit) more")
        }
    }
}

public enum AddonProbeFactoryLayerFormatter {
    public static func format(_ report: AddonProbeFactoryLayerReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe factory-layer inspect",
            "Status: experimental Path B probe; true add-on clothing is not solved.",
            "Conclusion: \(report.conclusion.rawValue)",
            "Archive index DB: \(PathSafety.redactUserPath(report.indexDatabasePath))",
            "Index DB exists: \(report.indexDatabaseExists ? "yes" : "no")"
        ]
        if let extractionArchivePath = report.extractionArchivePath {
            lines.append("Extraction archive: \(PathSafety.redactUserPath(extractionArchivePath))")
        } else {
            lines.append("Extraction archive: (not extracted)")
        }
        if let writtenReportPath = report.writtenReportPath {
            lines.append("JSON report: \(PathSafety.redactUserPath(writtenReportPath))")
        }

        lines.append("")
        lines.append("Exact resource search:")
        for search in report.indexSearches.filter(\.exactResource) {
            lines.append("- \(search.term): \(search.shownMatchCount) match(es)")
            for match in search.matches.prefix(5) {
                lines.append("  \(match.archivePath) | \(match.assetPath)")
            }
        }

        lines.append("")
        lines.append("Broad search terms:")
        for search in report.indexSearches.filter({ !$0.exactResource }) {
            lines.append("- \(search.term): \(search.shownMatchCount) of \(search.totalMatchCount)")
        }

        if !report.extractedFiles.isEmpty {
            lines.append("")
            lines.append("Extracted files:")
            for file in report.extractedFiles {
                let required = file.required ? "required" : "optional"
                let diagnostic = report.resourceDiagnostics.first { $0.resourcePath == file.resourcePath }
                let state = file.parsed ? "parsed" : (diagnostic?.exists == true ? "diagnosed" : "missing")
                lines.append("- \(file.resourcePath) (\(required), \(state)): \(PathSafety.redactUserPath(file.extractedPath))")
            }
        }

        if !report.resourceDiagnostics.isEmpty {
            lines.append("")
            lines.append("Resource diagnostics:")
            for diagnostic in report.resourceDiagnostics {
                lines.append("- \(diagnostic.resourcePath)")
                if let archivePath = diagnostic.archivePath {
                    lines.append("  archive: \(archivePath)")
                }
                if let extractedPath = diagnostic.extractedFilePath {
                    lines.append("  path: \(PathSafety.redactUserPath(extractedPath))")
                }
                lines.append("  exists: \(diagnostic.exists ? "yes" : "no")")
                lines.append("  size: \(diagnostic.size.map(String.init) ?? "(unknown)")")
                lines.append("  first32: \(diagnostic.first32BytesHex.isEmpty ? "(none)" : diagnostic.first32BytesHex)")
                lines.append("  magic: \(diagnostic.detectedMagic.rawValue)")
                lines.append("  parse: \(diagnostic.parseStatus.rawValue)")
                for warning in diagnostic.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }

        if !report.decodeAttempts.isEmpty {
            lines.append("")
            lines.append("CR2W decode attempts:")
            for attempt in report.decodeAttempts {
                lines.append("- \(attempt.resourcePath): \(attempt.command)")
                if let exitCode = attempt.exitCode {
                    lines.append("  exit: \(exitCode)")
                }
                if !attempt.producedFiles.isEmpty {
                    lines.append("  produced: \(attempt.producedFiles.joined(separator: ", "))")
                }
                if let parsedOutputPath = attempt.parsedOutputPath {
                    lines.append("  parsed: \(PathSafety.redactUserPath(parsedOutputPath))")
                }
                for warning in attempt.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }

        if !report.decodedTextSummaries.isEmpty {
            lines.append("")
            lines.append("Decoded text summaries:")
            for summary in report.decodedTextSummaries {
                lines.append("- \(summary.resourcePath): \(PathSafety.redactUserPath(summary.decodedPath))")
                lines.append("  Items.*: \(summary.itemIDs.prefix(25).joined(separator: ", "))")
                lines.append("  resources: \(summary.resourceReferences.prefix(25).joined(separator: ", "))")
                lines.append("  semantic terms: \(summary.semanticTerms.joined(separator: ", "))")
                if !summary.knownVanillaItemIDs.isEmpty {
                    lines.append("  known vanilla IDs: \(summary.knownVanillaItemIDs.joined(separator: ", "))")
                }
                for warning in summary.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }

        for summary in report.csvSummaries {
            lines.append("")
            lines.append("CSV: \(summary.resourcePath)")
            if let extractedPath = summary.extractedPath {
                lines.append("Path: \(PathSafety.redactUserPath(extractedPath))")
            }
            lines.append("Headers: \(summary.headers.isEmpty ? "(none)" : summary.headers.joined(separator: ", "))")
            lines.append("Rows: \(summary.rowCount)")
            lines.append("Items.* cells: \(summary.itemIDDetections.count)")
            lines.append("TweakDB-style cells: \(summary.tweakDBDetections.count)")
            lines.append("Resource path cells: \(summary.resourcePathDetections.count)")
            lines.append("Semantic cells: \(summary.semanticDetections.count)")
            if !summary.knownVanillaItemRows.isEmpty {
                lines.append("Known vanilla item rows:")
                for known in summary.knownVanillaItemRows.prefix(25) {
                    lines.append("  row \(known.rowIndex) \(known.itemID): \(formatRow(known.row))")
                }
            }
            if !summary.representativeRows.isEmpty {
                lines.append("Representative rows:")
                for (index, row) in summary.representativeRows.prefix(25).enumerated() {
                    lines.append("  row \(index + 1): \(formatRow(row))")
                }
            }
            if !summary.warnings.isEmpty {
                lines.append("CSV warnings:")
                for warning in summary.warnings {
                    lines.append("  - \(warning)")
                }
            }
        }

        if !report.crossCSVReferences.isEmpty {
            lines.append("")
            lines.append("Cross-CSV references:")
            for reference in report.crossCSVReferences.prefix(100) {
                lines.append("- \(reference.relationship): \(reference.fromCSV) -> \(reference.toCSV) via \(reference.token) rows \(reference.fromRows.map(String.init).joined(separator: ","))")
            }
        }

        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in report.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeFactoryLayerReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func formatRow(_ row: [String: String]) -> String {
        row.keys.sorted().map { key in
            let value = row[key] ?? ""
            let clipped = value.count > 80 ? String(value.prefix(77)) + "..." : value
            return "\(key)=\(clipped)"
        }
        .joined(separator: " | ")
    }
}

public enum AddonProbeFactoryJSONAnalysisFormatter {
    public static func format(_ report: AddonProbeFactoryJSONAnalysisReport) -> String {
        var lines: [String] = [
            "CyberMac add-on probe factory JSON analysis",
            "Status: structure/resource wiring analysis only; true add-on clothing is not proven.",
            "Input root: \(PathSafety.redactUserPath(report.inputRoot))",
            "Discovered decoded JSON files: \(report.discoveredFiles.count)"
        ]

        for file in report.files {
            lines.append("")
            lines.append("File: \(file.fileName)")
            lines.append("Path: \(PathSafety.redactUserPath(file.decodedJSONPath))")
            lines.append("Top-level: \(file.topLevelType)")
            lines.append("Keys: \(file.topLevelKeys.isEmpty ? "(none)" : file.topLevelKeys.joined(separator: ", "))")
            lines.append("String values: \(file.stringValueCount)")
            lines.append("Inferred role: \(roleDescription(file.inferredRole))")

            let nonzeroCounts = AddonProbeManager.factoryJSONAnalysisTerms
                .compactMap { term -> String? in
                    let count = file.counts[term] ?? 0
                    return count > 0 ? "\(term)=\(count)" : nil
                }
            lines.append("Matches: \(nonzeroCounts.isEmpty ? "(none)" : nonzeroCounts.joined(separator: ", "))")

            let exampleTerms = AddonProbeManager.factoryJSONAnalysisTerms
                .filter { !(file.representativeMatches[$0] ?? []).isEmpty }
            if !exampleTerms.isEmpty {
                lines.append("Representative matches:")
                for term in exampleTerms {
                    guard let matches = file.representativeMatches[term], !matches.isEmpty else { continue }
                    for match in matches.prefix(3) {
                        let value = match.normalizedValue ?? match.value
                        lines.append("  - \(term) at \(match.jsonPath): \(clipped(value))")
                    }
                }
            }

            for warning in file.warnings {
                lines.append("Warning: \(warning)")
            }
        }

        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in report.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbeFactoryJSONAnalysisReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }

    private static func roleDescription(_ role: AddonProbeFactoryJSONRole) -> String {
        switch role {
        case .topLevelFactoryRegistry:
            return "likely top-level factory registry"
        case .clothingEquipmentEntityTemplateFactoryMapping:
            return "likely clothing equipment entity-template factory mapping"
        case .clothingAppearanceResourceMapping:
            return "likely clothing appearance-resource mapping"
        case .genericItemFactoryMapping:
            return "likely generic item factory mapping"
        case .unknown:
            return "unknown"
        }
    }

    private static func clipped(_ value: String, limit: Int = 180) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 3)) + "..."
    }
}

public enum AddonProbeFactoryRoundtripFormatter {
    public static func format(_ manifest: AddonProbeFactoryRoundtripManifest) -> String {
        var lines: [String] = [
            "CyberMac add-on probe factory-resource roundtrip",
            "Status: no-op factory resource probe; true add-on support is not claimed.",
            "Conclusion: \(manifest.conclusion.rawValue)",
            "Archive: \(PathSafety.redactUserPath(manifest.inputArchive))",
            "Resource: \(manifest.resourcePath)",
            "Manifest: \(PathSafety.redactUserPath(manifest.manifestPath))"
        ]
        if let extracted = manifest.extractedResourcePath {
            lines.append("Extracted resource: \(PathSafety.redactUserPath(extracted))")
        }
        if let decoded = manifest.decodedJSONPath {
            lines.append("Decoded JSON: \(PathSafety.redactUserPath(decoded))")
        }
        if let rebuilt = manifest.reserializedCR2WPath {
            lines.append("Rebuilt CR2W: \(PathSafety.redactUserPath(rebuilt))")
        }

        lines.append("")
        lines.append("Original: size=\(manifest.originalSize.map(String.init) ?? "(unknown)") sha256=\(manifest.originalSHA256 ?? "(unknown)") magic=\(manifest.originalMagic ?? "(unknown)")")
        lines.append("Original first32: \(manifest.originalFirst32 ?? "(unknown)")")
        if manifest.rebuiltSHA256 != nil || manifest.rebuiltSize != nil || manifest.rebuiltMagic != nil {
            lines.append("Rebuilt: size=\(manifest.rebuiltSize.map(String.init) ?? "(unknown)") sha256=\(manifest.rebuiltSHA256 ?? "(unknown)") magic=\(manifest.rebuiltMagic ?? "(unknown)")")
            lines.append("Rebuilt first32: \(manifest.rebuiltFirst32 ?? "(unknown)")")
        }

        lines.append("")
        lines.append("cp77tools commands attempted: \(manifest.cp77toolsCommandsAttempted.count)")
        for attempt in manifest.cp77toolsCommandsAttempted {
            let exit = attempt.exitCode.map(String.init) ?? "(not run)"
            lines.append("- exit \(exit): \(attempt.command)")
            for warning in attempt.warnings {
                lines.append("  warning: \(warning)")
            }
        }

        if let stagedArchivePath = manifest.stagedArchivePath {
            lines.append("")
            lines.append("Staged no-op archive: \(PathSafety.redactUserPath(stagedArchivePath))")
            lines.append("Staged SHA-256: \(manifest.stagedArchiveSHA256 ?? "(unknown)")")
        }
        if let manualInstallCommand = manifest.manualInstallCommand {
            lines.append("")
            lines.append("Manual install command:")
            lines.append(manualInstallCommand)
        }

        if !manifest.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in manifest.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ manifest: AddonProbeFactoryRoundtripManifest) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(manifest), encoding: .utf8) ?? "{}"
    }
}

public enum AddonProbeFactoryRowCloneFormatter {
    public static func format(_ manifest: AddonProbeFactoryRowCloneManifest) -> String {
        var lines: [String] = [
            "CyberMac add-on probe factory-row clone",
            "Status: staged factory-row acceptance probe; true add-on support is not claimed.",
            "Conclusion: \(manifest.conclusion.rawValue)",
            "Archive: \(PathSafety.redactUserPath(manifest.archive))",
            "Resource: \(manifest.resource)",
            "Source key: \(manifest.sourceKey)",
            "New key: \(manifest.newKey)",
            "Source row path: \(manifest.sourceRowPath ?? "(not found)")",
            "Source rows found: \(manifest.sourceRowsFound)",
            "Rows added in compiledData: \(manifest.rowsAddedCompiledData)",
            "Rows added in data: \(manifest.rowsAddedData)",
            "Manifest: \(PathSafety.redactUserPath(manifest.manifestPath))"
        ]
        if let decodedOriginalJson = manifest.decodedOriginalJson {
            lines.append("Decoded original JSON: \(PathSafety.redactUserPath(decodedOriginalJson))")
        }
        if let decodedEditedJson = manifest.decodedEditedJson {
            lines.append("Decoded edited JSON: \(PathSafety.redactUserPath(decodedEditedJson))")
        }
        if let rebuiltResource = manifest.rebuiltResource {
            lines.append("Rebuilt edited resource: \(PathSafety.redactUserPath(rebuiltResource))")
        }

        lines.append("")
        lines.append("Original resource: size=\(manifest.originalResourceSize.map(String.init) ?? "(unknown)") sha256=\(manifest.originalResourceSHA256 ?? "(unknown)")")
        if manifest.editedResourceSHA256 != nil || manifest.editedResourceSize != nil {
            lines.append("Edited resource: size=\(manifest.editedResourceSize.map(String.init) ?? "(unknown)") sha256=\(manifest.editedResourceSHA256 ?? "(unknown)")")
        }

        if let stagedArchive = manifest.stagedArchive {
            lines.append("")
            lines.append("Staged archive: \(PathSafety.redactUserPath(stagedArchive))")
            lines.append("Staged SHA-256: \(manifest.stagedArchiveSHA256 ?? "(unknown)")")
        }
        if let manualInstallCommand = manifest.manualInstallCommand {
            lines.append("")
            lines.append("Manual install command:")
            lines.append(manualInstallCommand)
        }

        if !manifest.cp77toolsCommandsAttempted.isEmpty {
            lines.append("")
            lines.append("cp77tools commands attempted: \(manifest.cp77toolsCommandsAttempted.count)")
            for attempt in manifest.cp77toolsCommandsAttempted {
                let exit = attempt.exitCode.map(String.init) ?? "(not run)"
                lines.append("- exit \(exit): \(attempt.command)")
                for warning in attempt.warnings {
                    lines.append("  warning: \(warning)")
                }
            }
        }

        if !manifest.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            for warning in manifest.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ manifest: AddonProbeFactoryRowCloneManifest) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(manifest), encoding: .utf8) ?? "{}"
    }
}

public enum AddonProbePlanFormatter {
    public static func format(_ report: AddonProbePlanReport) -> String {
        var lines: [String] = [
            "CyberMac Path B add-on probe plan",
            "Status: experimental; true add-on clothing is not solved.",
            "Mod classification: \(report.inspect.classification.rawValue)"
        ]
        if !report.inspect.candidateItemIDs.isEmpty {
            lines.append("Candidate item IDs: \(report.inspect.candidateItemIDs.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("Next steps:")
        lines.append(contentsOf: report.steps.map { "- \($0)" })
        lines.append("")
        lines.append("Expected failure modes:")
        lines.append(contentsOf: report.expectedFailureModes.map { "- \($0)" })
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: report.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func formatJSON(_ report: AddonProbePlanReport) throws -> String {
        String(data: try JSONEncoder.cybermac.encode(report), encoding: .utf8) ?? "{}"
    }
}
