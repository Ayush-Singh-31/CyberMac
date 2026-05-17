import Foundation
import SQLite3

public enum ArchiveCatalogIndexCategory: String, CaseIterable, Sendable {
    case ui
    case audio
    case garment
    case makeup
    case skin
    case hair
    case tattoo
    case weapon
    case vehicle
    case world
    case unknown

    public static var acceptedValuesDescription: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }

    static func normalized(_ rawCategory: String?) throws -> String? {
        guard let rawCategory else { return nil }
        let value = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            throw CyberMacError.invalidInput("Archive catalog category filter cannot be empty.")
        }
        guard Self(rawValue: value) != nil else {
            throw CyberMacError.invalidInput("Unknown archive catalog category: \(rawCategory). Expected one of: \(acceptedValuesDescription)")
        }
        return value
    }

    static func guess(assetPath: String, extension assetExtension: String) -> String {
        let normalizedPath = assetPath
            .replacingOccurrences(of: "\\", with: "/")
            .lowercased()

        if normalizedPath.contains("/gui/")
            || normalizedPath.contains("/widgets/")
            || normalizedPath.contains("/ink") {
            return Self.ui.rawValue
        }
        if assetExtension == "wem"
            || normalizedPath.contains("/sound/")
            || normalizedPath.contains("/soundbanks/") {
            return Self.audio.rawValue
        }
        if normalizedPath.contains("/garment/") {
            return Self.garment.rawValue
        }
        if normalizedPath.contains("/makeup/") {
            return Self.makeup.rawValue
        }
        if normalizedPath.contains("/skin/") {
            return Self.skin.rawValue
        }
        if normalizedPath.contains("/hair/") {
            return Self.hair.rawValue
        }
        if normalizedPath.contains("/tattoo/") || normalizedPath.contains("/tattoos/") {
            return Self.tattoo.rawValue
        }
        if normalizedPath.contains("/weapons/")
            || normalizedPath.contains("/weapon/") {
            return Self.weapon.rawValue
        }
        if normalizedPath.contains("/vehicles/")
            || normalizedPath.contains("/vehicle/") {
            return Self.vehicle.rawValue
        }
        if normalizedPath.contains("/worlds/")
            || normalizedPath.contains("/environment/") {
            return Self.world.rawValue
        }
        return Self.unknown.rawValue
    }
}

public enum ArchiveCatalogIndexDefaults {
    public static var databaseURL: URL {
        CyberMacHomeManager().archiveIndexDatabaseURL
    }
}

public struct ArchiveCatalogIndexBuildOptions: Equatable, Sendable {
    public let catalogDirectory: URL
    public let outputDatabase: URL

    public init(catalogDirectory: URL, outputDatabase: URL = ArchiveCatalogIndexDefaults.databaseURL) {
        self.catalogDirectory = catalogDirectory
        self.outputDatabase = outputDatabase
    }
}

public struct ArchiveCatalogIndexBuildReport: Equatable, Sendable {
    public let catalogDirectoryPath: String
    public let databasePath: String
    public let archiveCount: Int
    public let assetRowCount: Int
    public let duplicateAssetRowCount: Int

    public init(
        catalogDirectoryPath: String,
        databasePath: String,
        archiveCount: Int,
        assetRowCount: Int,
        duplicateAssetRowCount: Int
    ) {
        self.catalogDirectoryPath = catalogDirectoryPath
        self.databasePath = databasePath
        self.archiveCount = archiveCount
        self.assetRowCount = assetRowCount
        self.duplicateAssetRowCount = duplicateAssetRowCount
    }
}

public struct ArchiveCatalogIndexSearchOptions: Equatable, Sendable {
    public let query: String
    public let databaseURL: URL
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let categoryFilter: String?
    public let limit: Int

    public init(
        query: String,
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        extensionFilter: String? = nil,
        archiveFilter: String? = nil,
        categoryFilter: String? = nil,
        limit: Int = 50
    ) {
        self.query = query
        self.databaseURL = databaseURL
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.categoryFilter = categoryFilter
        self.limit = limit
    }
}

public struct ArchiveCatalogIndexSearchMatch: Equatable, Sendable {
    public let archivePath: String
    public let assetPath: String
    public let assetExtension: String
    public let category: String
    public let sourceCatalogFile: String

    public init(
        archivePath: String,
        assetPath: String,
        assetExtension: String,
        category: String,
        sourceCatalogFile: String
    ) {
        self.archivePath = archivePath
        self.assetPath = assetPath
        self.assetExtension = assetExtension
        self.category = category
        self.sourceCatalogFile = sourceCatalogFile
    }
}

public struct ArchiveCatalogIndexSearchReport: Equatable, Sendable {
    public let query: String
    public let databasePath: String
    public let extensionFilter: String?
    public let archiveFilter: String?
    public let categoryFilter: String?
    public let limit: Int
    public let totalMatchCount: Int
    public let matches: [ArchiveCatalogIndexSearchMatch]

    public init(
        query: String,
        databasePath: String,
        extensionFilter: String?,
        archiveFilter: String?,
        categoryFilter: String?,
        limit: Int,
        totalMatchCount: Int,
        matches: [ArchiveCatalogIndexSearchMatch]
    ) {
        self.query = query
        self.databasePath = databasePath
        self.extensionFilter = extensionFilter
        self.archiveFilter = archiveFilter
        self.categoryFilter = categoryFilter
        self.limit = limit
        self.totalMatchCount = totalMatchCount
        self.matches = matches
    }
}

public struct ArchiveCatalogIndexCount: Equatable, Sendable {
    public let value: String
    public let count: Int

    public init(value: String, count: Int) {
        self.value = value
        self.count = count
    }
}

public struct ArchiveCatalogIndexStatsReport: Equatable, Sendable {
    public let databasePath: String
    public let archiveCount: Int
    public let assetRowCount: Int
    public let countsByExtension: [ArchiveCatalogIndexCount]
    public let countsByArchive: [ArchiveCatalogIndexCount]
    public let countsByCategory: [ArchiveCatalogIndexCount]

    public init(
        databasePath: String,
        archiveCount: Int,
        assetRowCount: Int,
        countsByExtension: [ArchiveCatalogIndexCount],
        countsByArchive: [ArchiveCatalogIndexCount],
        countsByCategory: [ArchiveCatalogIndexCount]
    ) {
        self.databasePath = databasePath
        self.archiveCount = archiveCount
        self.assetRowCount = assetRowCount
        self.countsByExtension = countsByExtension
        self.countsByArchive = countsByArchive
        self.countsByCategory = countsByCategory
    }
}

public struct ArchiveCatalogIndexBuilder {
    public init() {}

    public func build(options: ArchiveCatalogIndexBuildOptions) throws -> ArchiveCatalogIndexBuildReport {
        let catalogDirectory = options.catalogDirectory.resolvingSymlinksInPath().standardizedFileURL
        try ArchiveCatalogParser.validateCatalogDirectory(catalogDirectory)

        let outputDatabase = options.outputDatabase.standardizedFileURL
        let outputDirectory = outputDatabase.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try validateReplaceableDatabaseTarget(outputDatabase)

        let tempDatabase = outputDirectory.appendingPathComponent(".\(outputDatabase.lastPathComponent).\(UUID().uuidString).tmp")
        try? FileManager.default.removeItem(at: tempDatabase)
        defer { try? FileManager.default.removeItem(at: tempDatabase) }

        var archiveCount = 0
        var assetRowCount = 0
        var duplicateAssetRowCount = 0

        do {
            let database = try ArchiveCatalogSQLiteDatabase(url: tempDatabase, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            try database.exec(ArchiveCatalogIndexStore.schemaSQL)
            try database.exec("BEGIN IMMEDIATE TRANSACTION;")

            let insertArchive = try database.prepare("""
                INSERT OR IGNORE INTO archives (relative_archive_path, catalog_file, archive_group, created_at)
                VALUES (?, ?, ?, NULL);
                """)
            let selectArchiveID = try database.prepare("""
                SELECT id FROM archives WHERE relative_archive_path = ?;
                """)
            let insertAsset = try database.prepare("""
                INSERT OR IGNORE INTO assets (
                    archive_id,
                    asset_path,
                    asset_dir,
                    basename,
                    ext,
                    category,
                    source_catalog_file
                )
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """)

            for catalogFile in try ArchiveCatalogParser.catalogFiles(under: catalogDirectory) {
                let sourceCatalogFile = try PathSafety.relativePath(of: catalogFile, in: catalogDirectory)
                let text = try ArchiveCatalogParser.readCatalogText(catalogFile)
                let inferredArchivePath = ArchiveCatalogParser.inferArchivePath(
                    sourceCatalogFile: sourceCatalogFile,
                    text: text
                )
                let archivePath = inferredArchivePath ?? "unknown:\(sourceCatalogFile)"
                let archiveGroup = Self.archiveGroup(for: archivePath)

                try insertArchive.run([
                    .text(archivePath),
                    .text(sourceCatalogFile),
                    .text(archiveGroup)
                ])
                if database.lastChangeCount > 0 {
                    archiveCount += 1
                }

                let archiveID = try selectArchiveID.firstInt([.text(archivePath)])
                for line in text.split(whereSeparator: \.isNewline) {
                    for assetPath in ArchiveCatalogParser.assetPathCandidates(in: String(line)) {
                        guard let assetExtension = ArchiveCatalogParser.assetExtension(assetPath) else { continue }
                        let components = Self.assetComponents(assetPath: assetPath)
                        try insertAsset.run([
                            .int(archiveID),
                            .text(assetPath),
                            .text(components.assetDirectory),
                            .text(components.basename),
                            .text(assetExtension),
                            .text(ArchiveCatalogIndexCategory.guess(assetPath: assetPath, extension: assetExtension)),
                            .text(sourceCatalogFile)
                        ])
                        if database.lastChangeCount > 0 {
                            assetRowCount += 1
                        } else {
                            duplicateAssetRowCount += 1
                        }
                    }
                }
            }
            try database.exec("COMMIT;")
            database.close()
        }

        if FileManager.default.fileExists(atPath: outputDatabase.path) {
            try FileManager.default.removeItem(at: outputDatabase)
        }
        try FileManager.default.moveItem(at: tempDatabase, to: outputDatabase)

        return ArchiveCatalogIndexBuildReport(
            catalogDirectoryPath: catalogDirectory.path,
            databasePath: outputDatabase.path,
            archiveCount: archiveCount,
            assetRowCount: assetRowCount,
            duplicateAssetRowCount: duplicateAssetRowCount
        )
    }

    private static func archiveGroup(for archivePath: String) -> String {
        if archivePath.hasPrefix("Data/archive/Mac/content/") {
            return "content"
        }
        if archivePath.hasPrefix("Data/archive/Mac/ep1/") {
            return "ep1"
        }
        return "unknown"
    }

    private static func assetComponents(assetPath: String) -> (assetDirectory: String, basename: String) {
        let normalized = assetPath.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let basename = parts.last else {
            return ("", assetPath)
        }
        let directory = parts.dropLast().joined(separator: "/")
        return (directory, basename)
    }

    private func validateReplaceableDatabaseTarget(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory != true else {
            throw CyberMacError.invalidInput("Archive index output path is a directory: \(url.path)")
        }
    }
}

public struct ArchiveCatalogIndexStore {
    static let schemaSQL = """
    PRAGMA foreign_keys = ON;

    CREATE TABLE archives (
        id INTEGER PRIMARY KEY,
        relative_archive_path TEXT UNIQUE NOT NULL,
        catalog_file TEXT,
        archive_group TEXT,
        created_at TEXT
    );

    CREATE TABLE assets (
        id INTEGER PRIMARY KEY,
        archive_id INTEGER NOT NULL,
        asset_path TEXT NOT NULL,
        asset_dir TEXT NOT NULL,
        basename TEXT NOT NULL,
        ext TEXT NOT NULL,
        category TEXT NOT NULL,
        source_catalog_file TEXT NOT NULL,
        FOREIGN KEY (archive_id) REFERENCES archives(id) ON DELETE CASCADE,
        UNIQUE(archive_id, asset_path)
    );

    CREATE INDEX assets_asset_path_idx ON assets(asset_path);
    CREATE INDEX assets_ext_idx ON assets(ext);
    CREATE INDEX assets_basename_idx ON assets(basename);
    CREATE INDEX assets_category_idx ON assets(category);
    CREATE INDEX assets_archive_id_idx ON assets(archive_id);

    \(AssetPreviewSchema.createTableSQL)
    \(AssetPreviewSchema.createIndexesSQL)
    """

    public init() {}

    public func search(options: ArchiveCatalogIndexSearchOptions) throws -> ArchiveCatalogIndexSearchReport {
        let query = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw CyberMacError.invalidInput("Archive catalog index query cannot be empty.")
        }
        guard options.limit > 0 else {
            throw CyberMacError.invalidInput("Archive catalog index limit must be greater than zero.")
        }

        let databaseURL = options.databaseURL.standardizedFileURL
        let extensionFilter = try ArchiveCatalogParser.normalizedExtensionFilter(options.extensionFilter)
        let archiveFilter = try options.archiveFilter.map {
            try OfficialArchiveBackupManager.validateOfficialRelativeArchivePath($0)
        }
        let categoryFilter = try ArchiveCatalogIndexCategory.normalized(options.categoryFilter)

        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READONLY)
        let filter = SearchFilter(
            query: query,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            categoryFilter: categoryFilter
        )

        let totalMatchCount = try countMatches(database: database, filter: filter)
        let matches = try searchMatches(database: database, filter: filter, limit: options.limit)
        database.close()

        return ArchiveCatalogIndexSearchReport(
            query: query,
            databasePath: databaseURL.path,
            extensionFilter: extensionFilter,
            archiveFilter: archiveFilter,
            categoryFilter: categoryFilter,
            limit: options.limit,
            totalMatchCount: totalMatchCount,
            matches: matches
        )
    }

    public func findExactAssetPathMatches(
        databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL,
        assetPaths: [String]
    ) throws -> [String: [String]] {
        let databaseURL = databaseURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw CyberMacError.notFound("Archive catalog index database does not exist: \(databaseURL.path)")
        }

        var normalizedByLookup: [String: [String]] = [:]
        for path in assetPaths {
            let lookup = Self.normalizedLookupAssetPath(path)
            guard !lookup.isEmpty else { continue }
            normalizedByLookup[lookup, default: []].append(path)
        }
        guard !normalizedByLookup.isEmpty else { return [:] }

        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READONLY)
        defer { database.close() }

        let statement = try database.prepare("""
            SELECT archives.relative_archive_path
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            WHERE REPLACE(LOWER(assets.asset_path), '\\', '/') = ?
            ORDER BY archives.relative_archive_path ASC;
            """)

        var matches: [String: [String]] = [:]
        for (lookupKey, originalPaths) in normalizedByLookup {
            try statement.bind([.text(lookupKey)])
            var archives: [String] = []
            var seen = Set<String>()
            while true {
                let stepResult = try statement.step()
                if stepResult == SQLITE_DONE { break }
                if let archivePath = statement.columnString(0), seen.insert(archivePath).inserted {
                    archives.append(archivePath)
                }
            }
            guard !archives.isEmpty else { continue }
            for originalPath in originalPaths {
                matches[originalPath] = archives
            }
        }
        return matches
    }

    static func normalizedLookupAssetPath(_ assetPath: String) -> String {
        assetPath
            .replacingOccurrences(of: "\\", with: "/")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func stats(databaseURL: URL = ArchiveCatalogIndexDefaults.databaseURL) throws -> ArchiveCatalogIndexStatsReport {
        let databaseURL = databaseURL.standardizedFileURL
        let database = try ArchiveCatalogSQLiteDatabase(url: databaseURL, flags: SQLITE_OPEN_READONLY)
        let archiveCount = try database.prepare("SELECT COUNT(*) FROM archives;").firstInt([])
        let assetRowCount = try database.prepare("SELECT COUNT(*) FROM assets;").firstInt([])
        let countsByExtension = try groupedCounts(
            database: database,
            sql: "SELECT ext, COUNT(*) FROM assets GROUP BY ext ORDER BY COUNT(*) DESC, ext ASC;"
        )
        let countsByArchive = try groupedCounts(
            database: database,
            sql: """
            SELECT archives.relative_archive_path, COUNT(*)
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            GROUP BY archives.relative_archive_path
            ORDER BY COUNT(*) DESC, archives.relative_archive_path ASC;
            """
        )
        let countsByCategory = try groupedCounts(
            database: database,
            sql: "SELECT category, COUNT(*) FROM assets GROUP BY category ORDER BY COUNT(*) DESC, category ASC;"
        )
        database.close()

        return ArchiveCatalogIndexStatsReport(
            databasePath: databaseURL.path,
            archiveCount: archiveCount,
            assetRowCount: assetRowCount,
            countsByExtension: countsByExtension,
            countsByArchive: countsByArchive,
            countsByCategory: countsByCategory
        )
    }

    private struct SearchFilter {
        let query: String
        let extensionFilter: String?
        let archiveFilter: String?
        let categoryFilter: String?
    }

    private func countMatches(database: ArchiveCatalogSQLiteDatabase, filter: SearchFilter) throws -> Int {
        let statement = try database.prepare("""
            SELECT COUNT(*)
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            \(whereClause(filter: filter));
            """)
        return try statement.firstInt(bindings(filter: filter))
    }

    private func searchMatches(
        database: ArchiveCatalogSQLiteDatabase,
        filter: SearchFilter,
        limit: Int
    ) throws -> [ArchiveCatalogIndexSearchMatch] {
        let statement = try database.prepare("""
            SELECT
                archives.relative_archive_path,
                assets.asset_path,
                assets.ext,
                assets.category,
                assets.source_catalog_file
            FROM assets
            JOIN archives ON archives.id = assets.archive_id
            \(whereClause(filter: filter))
            ORDER BY archives.relative_archive_path ASC, assets.asset_path ASC, assets.source_catalog_file ASC
            LIMIT ?;
            """)
        var values = bindings(filter: filter)
        values.append(.int(limit))
        try statement.bind(values)

        var matches: [ArchiveCatalogIndexSearchMatch] = []
        while true {
            let result = try statement.step()
            if result == SQLITE_DONE {
                break
            }
            matches.append(ArchiveCatalogIndexSearchMatch(
                archivePath: statement.columnString(0) ?? "",
                assetPath: statement.columnString(1) ?? "",
                assetExtension: statement.columnString(2) ?? "",
                category: statement.columnString(3) ?? "",
                sourceCatalogFile: statement.columnString(4) ?? ""
            ))
        }
        return matches
    }

    private func whereClause(filter: SearchFilter) -> String {
        var clauses = ["instr(lower(assets.asset_path), lower(?)) > 0"]
        if filter.extensionFilter != nil {
            clauses.append("assets.ext = ?")
        }
        if filter.archiveFilter != nil {
            clauses.append("archives.relative_archive_path = ?")
        }
        if filter.categoryFilter != nil {
            clauses.append("assets.category = ?")
        }
        return "WHERE " + clauses.joined(separator: " AND ")
    }

    private func bindings(filter: SearchFilter) -> [ArchiveCatalogSQLiteValue] {
        var values: [ArchiveCatalogSQLiteValue] = [.text(filter.query)]
        if let extensionFilter = filter.extensionFilter {
            values.append(.text(extensionFilter))
        }
        if let archiveFilter = filter.archiveFilter {
            values.append(.text(archiveFilter))
        }
        if let categoryFilter = filter.categoryFilter {
            values.append(.text(categoryFilter))
        }
        return values
    }

    private func groupedCounts(database: ArchiveCatalogSQLiteDatabase, sql: String) throws -> [ArchiveCatalogIndexCount] {
        let statement = try database.prepare(sql)
        var counts: [ArchiveCatalogIndexCount] = []
        while true {
            let result = try statement.step()
            if result == SQLITE_DONE {
                break
            }
            counts.append(ArchiveCatalogIndexCount(
                value: statement.columnString(0) ?? "",
                count: statement.columnInt(1)
            ))
        }
        return counts
    }
}

public enum ArchiveCatalogIndexBuildFormatter {
    public static func format(_ report: ArchiveCatalogIndexBuildReport) -> String {
        [
            "Archive catalog index built",
            "Catalog dir: \(PathSafety.redactUserPath(report.catalogDirectoryPath))",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Archives: \(report.archiveCount)",
            "Asset rows: \(report.assetRowCount)",
            "Duplicate asset rows ignored: \(report.duplicateAssetRowCount)"
        ].joined(separator: "\n")
    }
}

public enum ArchiveCatalogIndexSearchFormatter {
    public static func format(_ report: ArchiveCatalogIndexSearchReport) -> String {
        var lines = [
            "Archive catalog index search",
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

        guard !report.matches.isEmpty else {
            lines.append("No archive catalog index matches found for query: \(report.query)")
            return lines.joined(separator: "\n")
        }

        lines.append("Matches: \(report.matches.count)")
        if report.totalMatchCount > report.matches.count {
            lines.append("Showing: \(report.matches.count) of \(report.totalMatchCount)")
        }
        for match in report.matches {
            lines.append([
                match.archivePath,
                match.assetPath,
                match.assetExtension,
                match.category,
                match.sourceCatalogFile
            ].joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }
}

public enum ArchiveCatalogIndexStatsFormatter {
    public static func format(_ report: ArchiveCatalogIndexStatsReport) -> String {
        var lines = [
            "Archive catalog index stats",
            "DB: \(PathSafety.redactUserPath(report.databasePath))",
            "Archives: \(report.archiveCount)",
            "Asset rows: \(report.assetRowCount)"
        ]
        appendCounts(report.countsByExtension, title: "Counts by extension", to: &lines)
        appendCounts(report.countsByArchive, title: "Counts by archive", to: &lines)
        appendCounts(report.countsByCategory, title: "Counts by category", to: &lines)
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

enum ArchiveCatalogSQLiteValue {
    case int(Int)
    case text(String)
    case null
}

final class ArchiveCatalogSQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL, flags: Int32) throws {
        var openedHandle: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &openedHandle, flags, nil)
        guard result == SQLITE_OK, let openedHandle else {
            let message = openedHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open SQLite database"
            if let openedHandle {
                sqlite3_close(openedHandle)
            }
            throw CyberMacError.fileSystem("SQLite open failed for \(url.path): \(message)")
        }
        self.handle = openedHandle
    }

    deinit {
        close()
    }

    var lastChangeCount: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_changes(handle))
    }

    func close() {
        guard let handle else { return }
        sqlite3_close(handle)
        self.handle = nil
    }

    func exec(_ sql: String) throws {
        guard let handle else {
            throw CyberMacError.fileSystem("SQLite database is closed.")
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message: String
            if let errorMessage {
                message = String(cString: errorMessage)
                sqlite3_free(errorMessage)
            } else {
                message = String(cString: sqlite3_errmsg(handle))
            }
            throw CyberMacError.fileSystem("SQLite exec failed: \(message)")
        }
    }

    func prepare(_ sql: String) throws -> ArchiveCatalogSQLiteStatement {
        guard let handle else {
            throw CyberMacError.fileSystem("SQLite database is closed.")
        }
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw CyberMacError.fileSystem("SQLite prepare failed: \(String(cString: sqlite3_errmsg(handle)))")
        }
        return ArchiveCatalogSQLiteStatement(database: self, statement: statement)
    }

    fileprivate func errorMessage() -> String {
        guard let handle else { return "SQLite database is closed." }
        return String(cString: sqlite3_errmsg(handle))
    }
}

final class ArchiveCatalogSQLiteStatement {
    private let database: ArchiveCatalogSQLiteDatabase
    private let statement: OpaquePointer

    init(database: ArchiveCatalogSQLiteDatabase, statement: OpaquePointer) {
        self.database = database
        self.statement = statement
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func run(_ values: [ArchiveCatalogSQLiteValue]) throws {
        try bind(values)
        let result = try step()
        guard result == SQLITE_DONE else {
            throw CyberMacError.fileSystem("SQLite statement did not finish: \(database.errorMessage())")
        }
        reset()
    }

    func firstInt(_ values: [ArchiveCatalogSQLiteValue]) throws -> Int {
        try bind(values)
        let result = try step()
        guard result == SQLITE_ROW else {
            reset()
            throw CyberMacError.notFound("SQLite query returned no rows.")
        }
        let value = columnInt(0)
        reset()
        return value
    }

    func bind(_ values: [ArchiveCatalogSQLiteValue]) throws {
        reset()
        sqlite3_clear_bindings(statement)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .int(let intValue):
                result = sqlite3_bind_int64(statement, index, sqlite3_int64(intValue))
            case .text(let stringValue):
                result = stringValue.withCString {
                    sqlite3_bind_text(statement, index, $0, -1, sqliteTransient)
                }
            case .null:
                result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else {
                throw CyberMacError.fileSystem("SQLite bind failed: \(database.errorMessage())")
            }
        }
    }

    func step() throws -> Int32 {
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW || result == SQLITE_DONE else {
            throw CyberMacError.fileSystem("SQLite step failed: \(database.errorMessage())")
        }
        return result
    }

    func columnInt(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func columnString(_ index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: UnsafeRawPointer(text).assumingMemoryBound(to: CChar.self))
    }

    private func reset() {
        sqlite3_reset(statement)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
