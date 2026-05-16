import Foundation
import SQLite3

public enum AssetPreviewKind {
    public static let textureThumbnail = "texture_thumbnail"
    public static let atlasSheet = "atlas_sheet"
    public static let meshRender = "mesh_render"
    public static let materialReference = "material_reference"
    public static let mannequinRender = "mannequin_render"
    public static let externalReference = "external_reference"

    public static let allValues: [String] = [
        textureThumbnail,
        atlasSheet,
        meshRender,
        materialReference,
        mannequinRender,
        externalReference
    ]

    public static var acceptedValuesDescription: String {
        allValues.joined(separator: ", ")
    }

    static func normalized(_ rawValue: String?) throws -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            throw CyberMacError.invalidInput("Asset preview kind cannot be empty.")
        }
        guard allValues.contains(value) else {
            throw CyberMacError.invalidInput("Unknown asset preview kind: \(rawValue). Expected one of: \(acceptedValuesDescription)")
        }
        return value
    }
}

public enum AssetPreviewStatus {
    public static let available = "available"
    public static let missing = "missing"
    public static let failed = "failed"
}

enum AssetPreviewSchema {
    static let createTableSQL = """
    CREATE TABLE IF NOT EXISTS asset_previews (
        id INTEGER PRIMARY KEY,
        asset_id INTEGER NOT NULL,
        preview_kind TEXT NOT NULL,
        preview_path TEXT NOT NULL,
        source_tool TEXT,
        width INTEGER,
        height INTEGER,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
    );
    """

    static let createIndexesSQL = """
    CREATE INDEX IF NOT EXISTS asset_previews_asset_id_idx ON asset_previews(asset_id);
    CREATE INDEX IF NOT EXISTS asset_previews_preview_kind_idx ON asset_previews(preview_kind);
    CREATE UNIQUE INDEX IF NOT EXISTS asset_previews_unique_idx ON asset_previews(asset_id, preview_kind, preview_path);
    """
}

public struct AssetPreviewRegisterOptions: Equatable, Sendable {
    public let databaseURL: URL
    public let archivePath: String
    public let assetPath: String
    public let previewURL: URL
    public let kind: String?
    public let sourceTool: String?

    public init(
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        archivePath: String,
        assetPath: String,
        previewURL: URL,
        kind: String? = nil,
        sourceTool: String? = nil
    ) {
        self.databaseURL = databaseURL
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.previewURL = previewURL
        self.kind = kind
        self.sourceTool = sourceTool
    }
}

public struct AssetPreviewRegisterReport: Equatable, Sendable {
    public let databasePath: String
    public let archivePath: String
    public let assetPath: String
    public let previewPath: String
    public let previewKind: String
    public let sourceTool: String?
    public let status: String
    public let inserted: Bool
    public let updated: Bool
    public let createdAt: String

    public init(
        databasePath: String,
        archivePath: String,
        assetPath: String,
        previewPath: String,
        previewKind: String,
        sourceTool: String?,
        status: String,
        inserted: Bool,
        updated: Bool,
        createdAt: String
    ) {
        self.databasePath = databasePath
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.previewPath = previewPath
        self.previewKind = previewKind
        self.sourceTool = sourceTool
        self.status = status
        self.inserted = inserted
        self.updated = updated
        self.createdAt = createdAt
    }
}

public struct AssetPreviewManifestImportFailure: Equatable, Sendable {
    public let index: Int
    public let archive: String?
    public let assetPath: String?
    public let previewPath: String?
    public let reason: String

    public init(index: Int, archive: String?, assetPath: String?, previewPath: String?, reason: String) {
        self.index = index
        self.archive = archive
        self.assetPath = assetPath
        self.previewPath = previewPath
        self.reason = reason
    }
}

public struct AssetPreviewManifestImportReport: Equatable, Sendable {
    public let databasePath: String
    public let manifestPath: String
    public let totalEntries: Int
    public let importedCount: Int
    public let skippedCount: Int
    public let failedCount: Int
    public let failures: [AssetPreviewManifestImportFailure]

    public init(
        databasePath: String,
        manifestPath: String,
        totalEntries: Int,
        importedCount: Int,
        skippedCount: Int,
        failedCount: Int,
        failures: [AssetPreviewManifestImportFailure]
    ) {
        self.databasePath = databasePath
        self.manifestPath = manifestPath
        self.totalEntries = totalEntries
        self.importedCount = importedCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.failures = failures
    }
}

public struct AssetPreviewSearchOptions: Equatable, Sendable {
    public let query: String
    public let databaseURL: URL
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let categoryFilter: String?
    public let excludedCategoryFilter: String?
    public let onlyWithPreview: Bool
    public let limit: Int

    public init(
        query: String,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        extensionFilter: String? = nil,
        archiveFilter: String? = nil,
        categoryFilter: String? = nil,
        excludedCategoryFilter: String? = nil,
        onlyWithPreview: Bool = false,
        limit: Int = 50
    ) {
        self.query = query
        self.databaseURL = databaseURL
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.categoryFilter = categoryFilter
        self.excludedCategoryFilter = excludedCategoryFilter
        self.onlyWithPreview = onlyWithPreview
        self.limit = limit
    }
}

public struct AssetPreviewSearchMatch: Equatable, Sendable {
    public let archivePath: String
    public let assetPath: String
    public let assetExtension: String
    public let category: String
    public let previewCount: Int
    public let firstPreviewPath: String?
    public let firstPreviewKind: String?

    public init(
        archivePath: String,
        assetPath: String,
        assetExtension: String,
        category: String,
        previewCount: Int,
        firstPreviewPath: String?,
        firstPreviewKind: String?
    ) {
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.assetExtension = assetExtension
        self.category = category
        self.previewCount = previewCount
        self.firstPreviewPath = firstPreviewPath
        self.firstPreviewKind = firstPreviewKind
    }
}

public struct AssetPreviewSearchReport: Equatable, Sendable {
    public let query: String
    public let databasePath: String
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let categoryFilter: String?
    public let excludedCategoryFilter: String?
    public let onlyWithPreview: Bool
    public let limit: Int
    public let matches: [AssetPreviewSearchMatch]

    public init(
        query: String,
        databasePath: String,
        extensionFilter: String?,
        archiveFilter: String?,
        categoryFilter: String?,
        excludedCategoryFilter: String? = nil,
        onlyWithPreview: Bool,
        limit: Int,
        matches: [AssetPreviewSearchMatch]
    ) {
        self.query = query
        self.databasePath = databasePath
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.categoryFilter = categoryFilter
        self.excludedCategoryFilter = excludedCategoryFilter
        self.onlyWithPreview = onlyWithPreview
        self.limit = limit
        self.matches = matches
    }
}

public struct AssetPreviewStatsReport: Equatable, Sendable {
    public let databasePath: String
    public let totalPreviewRows: Int
    public let distinctAssetsWithPreviews: Int
    public let countsByKind: [ArchiveCatalogIndexCount]
    public let countsByStatus: [ArchiveCatalogIndexCount]
    public let topArchives: [ArchiveCatalogIndexCount]

    public init(
        databasePath: String,
        totalPreviewRows: Int,
        distinctAssetsWithPreviews: Int,
        countsByKind: [ArchiveCatalogIndexCount],
        countsByStatus: [ArchiveCatalogIndexCount],
        topArchives: [ArchiveCatalogIndexCount]
    ) {
        self.databasePath = databasePath
        self.totalPreviewRows = totalPreviewRows
        self.distinctAssetsWithPreviews = distinctAssetsWithPreviews
        self.countsByKind = countsByKind
        self.countsByStatus = countsByStatus
        self.topArchives = topArchives
    }
}

public struct AssetPreviewRegistry {
    public static let topArchivesLimit = 20

    public init() {}

    public func register(options: AssetPreviewRegisterOptions) throws -> AssetPreviewRegisterReport {
        let archivePath = try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(options.archivePath)
        let assetPath = try Self.normalizedAssetPath(options.assetPath)
        let kind = try AssetPreviewKind.normalized(options.kind) ?? AssetPreviewKind.externalReference
        let sourceTool = options.sourceTool?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previewURL = options.previewURL.standardizedFileURL
        let databaseURL = options.databaseURL.standardizedFileURL

        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw CyberMacError.notFound("Archive catalog index database does not exist: \(databaseURL.path)")
        }
        try Self.validatePreviewFile(previewURL)

        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READWRITE)
        defer { database.close() }
        try Self.ensureSchema(database: database)

        let assetID = try Self.lookupAssetID(
            database: database,
            archivePath: archivePath,
            assetPath: assetPath
        )

        let now = Self.timestamp()
        let upsert = try Self.upsertPreview(
            database: database,
            assetID: assetID,
            kind: kind,
            previewPath: previewURL.path,
            sourceTool: sourceTool,
            status: AssetPreviewStatus.available,
            createdAt: now
        )

        return AssetPreviewRegisterReport(
            databasePath: databaseURL.path,
            archivePath: archivePath,
            assetPath: assetPath,
            previewPath: previewURL.path,
            previewKind: kind,
            sourceTool: (sourceTool?.isEmpty == false) ? sourceTool : nil,
            status: AssetPreviewStatus.available,
            inserted: upsert.inserted,
            updated: upsert.updated,
            createdAt: now
        )
    }

    public func importManifest(
        manifestURL: URL,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL
    ) throws -> AssetPreviewManifestImportReport {
        let manifestURL = manifestURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw CyberMacError.notFound("Asset preview manifest does not exist: \(manifestURL.path)")
        }
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw CyberMacError.fileSystem("Unable to read asset preview manifest: \(manifestURL.path): \(error)")
        }
        let entries: [ManifestEntry]
        do {
            entries = try JSONDecoder().decode([ManifestEntry].self, from: data)
        } catch {
            throw CyberMacError.invalidInput("Asset preview manifest is not a valid JSON array of preview entries: \(error)")
        }

        let manifestDirectory = manifestURL.deletingLastPathComponent()
        var imported = 0
        var skipped = 0
        var failures: [AssetPreviewManifestImportFailure] = []

        for (index, entry) in entries.enumerated() {
            do {
                let archive = try Self.requiredField(entry.archive, name: "archive", index: index)
                let assetPath = try Self.requiredField(entry.assetPath, name: "assetPath", index: index)
                let previewPathRaw = try Self.requiredField(entry.previewPath, name: "previewPath", index: index)
                let previewURL = Self.resolvedPreviewURL(rawPath: previewPathRaw, manifestDirectory: manifestDirectory)
                let options = AssetPreviewRegisterOptions(
                    databaseURL: databaseURL,
                    archivePath: archive,
                    assetPath: assetPath,
                    previewURL: previewURL,
                    kind: entry.kind,
                    sourceTool: entry.sourceTool
                )
                let report = try register(options: options)
                if report.inserted {
                    imported += 1
                } else {
                    skipped += 1
                }
            } catch {
                failures.append(AssetPreviewManifestImportFailure(
                    index: index,
                    archive: entry.archive,
                    assetPath: entry.assetPath,
                    previewPath: entry.previewPath,
                    reason: String(describing: error)
                ))
            }
        }

        return AssetPreviewManifestImportReport(
            databasePath: databaseURL.standardizedFileURL.path,
            manifestPath: manifestURL.path,
            totalEntries: entries.count,
            importedCount: imported,
            skippedCount: skipped,
            failedCount: failures.count,
            failures: failures
        )
    }

    public func search(options: AssetPreviewSearchOptions) throws -> AssetPreviewSearchReport {
        let query = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw CyberMacError.invalidInput("Asset preview search query cannot be empty.")
        }
        guard options.limit > 0 else {
            throw CyberMacError.invalidInput("Asset preview search limit must be greater than zero.")
        }

        let databaseURL = options.databaseURL.standardizedFileURL
        let extensionFilter = try ArchiveCatalogParser.normalizedExtensionFilter(options.extensionFilter)
        let archiveFilter = try options.archiveFilter.map {
            try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath($0)
        }
        let categoryFilter = try ArchiveCatalogIndexCategory.normalized(options.categoryFilter)
        let excludedCategoryFilter = try ArchiveCatalogIndexCategory.normalized(options.excludedCategoryFilter)
        if let categoryFilter, let excludedCategoryFilter, categoryFilter == excludedCategoryFilter {
            throw CyberMacError.invalidInput("Category filter and excluded category filter must differ when both are set: \(categoryFilter)")
        }

        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw CyberMacError.notFound("Archive catalog index database does not exist: \(databaseURL.path)")
        }

        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READWRITE)
        defer { database.close() }
        try Self.ensureSchema(database: database)

        var clauses = ["instr(lower(assets.asset_path), lower(?)) > 0"]
        var bindings: [ArchiveCatalogSQLiteValue] = [.text(query)]
        if let extensionFilter {
            clauses.append("assets.ext = ?")
            bindings.append(.text(extensionFilter))
        }
        if let archiveFilter {
            clauses.append("archives.relative_archive_path = ?")
            bindings.append(.text(archiveFilter))
        }
        if let categoryFilter {
            clauses.append("assets.category = ?")
            bindings.append(.text(categoryFilter))
        }
        if let excludedCategoryFilter {
            clauses.append("assets.category != ?")
            bindings.append(.text(excludedCategoryFilter))
        }
        if options.onlyWithPreview {
            clauses.append("EXISTS (SELECT 1 FROM asset_previews WHERE asset_previews.asset_id = assets.id AND asset_previews.status = '\(AssetPreviewStatus.available)')")
        }

        let whereClause = "WHERE " + clauses.joined(separator: " AND ")
        let sql = """
            SELECT
                archives.relative_archive_path,
                assets.id,
                assets.asset_path,
                assets.ext,
                assets.category,
                (SELECT COUNT(*) FROM asset_previews
                    WHERE asset_previews.asset_id = assets.id
                      AND asset_previews.status = '\(AssetPreviewStatus.available)') AS preview_count,
                (SELECT preview_path FROM asset_previews
                    WHERE asset_previews.asset_id = assets.id
                      AND asset_previews.status = '\(AssetPreviewStatus.available)'
                    ORDER BY preview_kind ASC, preview_path ASC LIMIT 1) AS first_preview_path,
                (SELECT preview_kind FROM asset_previews
                    WHERE asset_previews.asset_id = assets.id
                      AND asset_previews.status = '\(AssetPreviewStatus.available)'
                    ORDER BY preview_kind ASC, preview_path ASC LIMIT 1) AS first_preview_kind
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            \(whereClause)
            ORDER BY archives.relative_archive_path ASC, assets.asset_path ASC, assets.id ASC
            LIMIT ?;
            """
        let statement = try database.prepare(sql)
        bindings.append(.int(options.limit))
        try statement.bind(bindings)

        var matches: [AssetPreviewSearchMatch] = []
        while true {
            let result = try statement.step()
            if result == SQLITE_DONE { break }
            matches.append(AssetPreviewSearchMatch(
                archivePath: statement.columnString(0) ?? "",
                assetPath: statement.columnString(2) ?? "",
                assetExtension: statement.columnString(3) ?? "",
                category: statement.columnString(4) ?? "",
                previewCount: statement.columnInt(5),
                firstPreviewPath: statement.columnString(6),
                firstPreviewKind: statement.columnString(7)
            ))
        }

        return AssetPreviewSearchReport(
            query: query,
            databasePath: databaseURL.path,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            categoryFilter: categoryFilter,
            excludedCategoryFilter: excludedCategoryFilter,
            onlyWithPreview: options.onlyWithPreview,
            limit: options.limit,
            matches: matches
        )
    }

    public func stats(databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL) throws -> AssetPreviewStatsReport {
        let databaseURL = databaseURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw CyberMacError.notFound("Archive catalog index database does not exist: \(databaseURL.path)")
        }

        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READWRITE)
        defer { database.close() }
        try Self.ensureSchema(database: database)

        let totalRows = try database.prepare("SELECT COUNT(*) FROM asset_previews;").firstInt([])
        let distinctAssets = try database.prepare("SELECT COUNT(DISTINCT asset_id) FROM asset_previews;").firstInt([])
        let countsByKind = try Self.groupedCounts(
            database: database,
            sql: "SELECT preview_kind, COUNT(*) FROM asset_previews GROUP BY preview_kind ORDER BY COUNT(*) DESC, preview_kind ASC;"
        )
        let countsByStatus = try Self.groupedCounts(
            database: database,
            sql: "SELECT status, COUNT(*) FROM asset_previews GROUP BY status ORDER BY COUNT(*) DESC, status ASC;"
        )
        let topArchivesStatement = try database.prepare("""
            SELECT archives.relative_archive_path, COUNT(*)
            FROM asset_previews
            JOIN assets ON assets.id = asset_previews.asset_id
            JOIN archives ON archives.id = assets.archive_id
            GROUP BY archives.relative_archive_path
            ORDER BY COUNT(*) DESC, archives.relative_archive_path ASC
            LIMIT ?;
            """)
        try topArchivesStatement.bind([.int(Self.topArchivesLimit)])
        var topArchives: [ArchiveCatalogIndexCount] = []
        while try topArchivesStatement.step() == SQLITE_ROW {
            topArchives.append(ArchiveCatalogIndexCount(
                value: topArchivesStatement.columnString(0) ?? "",
                count: topArchivesStatement.columnInt(1)
            ))
        }

        return AssetPreviewStatsReport(
            databasePath: databaseURL.path,
            totalPreviewRows: totalRows,
            distinctAssetsWithPreviews: distinctAssets,
            countsByKind: countsByKind,
            countsByStatus: countsByStatus,
            topArchives: topArchives
        )
    }

    static func ensureSchema(database: ArchiveCatalogSQLiteDatabase) throws {
        try database.exec(AssetPreviewSchema.createTableSQL)
        try database.exec(AssetPreviewSchema.createIndexesSQL)
    }

    // MARK: - Private helpers

    private struct ManifestEntry: Decodable {
        let archive: String?
        let assetPath: String?
        let previewPath: String?
        let kind: String?
        let sourceTool: String?
    }

    private struct UpsertResult {
        let inserted: Bool
        let updated: Bool
    }

    private static func upsertPreview(
        database: ArchiveCatalogSQLiteDatabase,
        assetID: Int,
        kind: String,
        previewPath: String,
        sourceTool: String?,
        status: String,
        createdAt: String
    ) throws -> UpsertResult {
        let existingStatement = try database.prepare("""
            SELECT id FROM asset_previews
            WHERE asset_id = ? AND preview_kind = ? AND preview_path = ?;
            """)
        try existingStatement.bind([
            .int(assetID),
            .text(kind),
            .text(previewPath)
        ])
        var existingID: Int?
        if try existingStatement.step() == SQLITE_ROW {
            existingID = existingStatement.columnInt(0)
        }

        let sourceToolValue: ArchiveCatalogSQLiteValue = (sourceTool?.isEmpty == false)
            ? .text(sourceTool!)
            : .null

        if let existingID {
            let updateStatement = try database.prepare("""
                UPDATE asset_previews
                SET source_tool = ?, status = ?, created_at = ?
                WHERE id = ?;
                """)
            try updateStatement.run([
                sourceToolValue,
                .text(status),
                .text(createdAt),
                .int(existingID)
            ])
            return UpsertResult(inserted: false, updated: true)
        } else {
            let insertStatement = try database.prepare("""
                INSERT INTO asset_previews (
                    asset_id, preview_kind, preview_path, source_tool,
                    width, height, status, created_at
                ) VALUES (?, ?, ?, ?, NULL, NULL, ?, ?);
                """)
            try insertStatement.run([
                .int(assetID),
                .text(kind),
                .text(previewPath),
                sourceToolValue,
                .text(status),
                .text(createdAt)
            ])
            return UpsertResult(inserted: true, updated: false)
        }
    }

    private static func lookupAssetID(
        database: ArchiveCatalogSQLiteDatabase,
        archivePath: String,
        assetPath: String
    ) throws -> Int {
        let statement = try database.prepare("""
            SELECT assets.id
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            WHERE archives.relative_archive_path = ?
              AND assets.asset_path = ?
            LIMIT 1;
            """)
        try statement.bind([.text(archivePath), .text(assetPath)])
        if try statement.step() == SQLITE_ROW {
            return statement.columnInt(0)
        }
        throw CyberMacError.notFound("Asset is not indexed for archive \(archivePath): \(assetPath)")
    }

    private static func validatePreviewFile(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CyberMacError.notFound("Preview file does not exist: \(url.path)")
        }
        guard !isDirectory.boolValue else {
            throw CyberMacError.invalidInput("Preview path is a directory, not a file: \(url.path)")
        }
    }

    private static func normalizedAssetPath(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw CyberMacError.invalidInput("Asset path cannot be empty.")
        }
        guard !value.hasPrefix("/") else {
            throw CyberMacError.unsafePath("Asset path must be relative, not absolute: \(raw)")
        }
        guard !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CyberMacError.unsafePath("Asset path contains control characters.")
        }
        return value
    }

    private static func resolvedPreviewURL(rawPath: String, manifestDirectory: URL) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return manifestDirectory.appendingPathComponent(expanded).standardizedFileURL
    }

    private static func requiredField(_ value: String?, name: String, index: Int) throws -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("Manifest entry at index \(index) is missing required field: \(name)")
        }
        return value
    }

    private static func groupedCounts(database: ArchiveCatalogSQLiteDatabase, sql: String) throws -> [ArchiveCatalogIndexCount] {
        let statement = try database.prepare(sql)
        var counts: [ArchiveCatalogIndexCount] = []
        while try statement.step() == SQLITE_ROW {
            counts.append(ArchiveCatalogIndexCount(
                value: statement.columnString(0) ?? "",
                count: statement.columnInt(1)
            ))
        }
        return counts
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}

public enum AssetPreviewRegisterFormatter {
    public static func format(_ report: AssetPreviewRegisterReport) -> String {
        var lines = [
            report.inserted ? "Asset preview registered." : "Asset preview updated.",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Archive: \(report.archivePath)",
            "Asset: \(report.assetPath)",
            "Kind: \(report.previewKind)",
            "Status: \(report.status)",
            "Preview: \(PathSafety.redactUserPath(report.previewPath))",
            "Created at: \(report.createdAt)"
        ]
        if let sourceTool = report.sourceTool {
            lines.append("Source tool: \(sourceTool)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum AssetPreviewManifestImportFormatter {
    public static func format(_ report: AssetPreviewManifestImportReport) -> String {
        var lines = [
            "Asset preview manifest import",
            "Manifest: \(PathSafety.redactUserPath(report.manifestPath))",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Total entries: \(report.totalEntries)",
            "Imported: \(report.importedCount)",
            "Skipped: \(report.skippedCount)",
            "Failed: \(report.failedCount)"
        ]
        if !report.failures.isEmpty {
            lines.append("")
            lines.append("Failures:")
            for failure in report.failures {
                lines.append("- [\(failure.index)] \(failure.archive ?? "<no archive>") | \(failure.assetPath ?? "<no asset>"): \(failure.reason)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum AssetPreviewSearchFormatter {
    public static func format(_ report: AssetPreviewSearchReport) -> String {
        var lines = [
            "Asset preview search",
            "Query: \(report.query)",
            "DB: \(PathSafety.redactUserPath(report.databasePath))"
        ]
        if let extensionFilter = report.extensionFilter {
            lines.append("Extension: \(extensionFilter)")
        }
        if let archiveFilter = report.archiveFilter {
            lines.append("Archive: \(archiveFilter)")
        }
        if let categoryFilter = report.categoryFilter {
            lines.append("Category: \(categoryFilter)")
        }
        if let excludedCategoryFilter = report.excludedCategoryFilter {
            lines.append("Excluded category: \(excludedCategoryFilter)")
        }
        if report.onlyWithPreview {
            lines.append("Filter: only assets with available previews")
        }

        guard !report.matches.isEmpty else {
            lines.append("No matches found for query: \(report.query)")
            return lines.joined(separator: "\n")
        }

        lines.append("Matches: \(report.matches.count)")
        for match in report.matches {
            let firstPreview = match.firstPreviewPath.map(PathSafety.redactUserPath) ?? "-"
            lines.append([
                match.archivePath,
                match.assetPath,
                match.assetExtension,
                match.category,
                "previews=\(match.previewCount)",
                "first=\(firstPreview)"
            ].joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }
}

public enum AssetPreviewStatsFormatter {
    public static func format(_ report: AssetPreviewStatsReport) -> String {
        var lines = [
            "Asset preview stats",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Total preview rows: \(report.totalPreviewRows)",
            "Distinct assets with previews: \(report.distinctAssetsWithPreviews)"
        ]
        appendCounts(report.countsByKind, title: "Counts by kind", to: &lines)
        appendCounts(report.countsByStatus, title: "Counts by status", to: &lines)
        appendCounts(report.topArchives, title: "Top archives with previews", to: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendCounts(_ counts: [ArchiveCatalogIndexCount], title: String, to lines: inout [String]) {
        lines.append("")
        lines.append(title)
        if counts.isEmpty {
            lines.append("(none)")
            return
        }
        for item in counts {
            lines.append("\(item.value) | \(item.count)")
        }
    }
}
