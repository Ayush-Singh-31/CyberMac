import Foundation

public struct ClothingImportCatalog: Codable, Sendable {
    public struct Item: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let category: String
        public let archivePath: String
        public let record: String?
        public let previewURL: URL?
        public let unavailableReason: String?
        public let previewError: String?
        public var canSelect: Bool { record != nil && unavailableReason == nil }
    }
    public let items: [Item]
    public let notice: String?
    public var availableItems: [Item] { items.filter(\.canSelect) }

    public init(contents: ModPackageContents, wardrobe: ClothingWardrobe?, notice: String? = nil) {
        self.notice = notice
        var seen = Set<String>()
        self.items = contents.archives.flatMap { archive -> [Item] in
            if archive.preparedPieces.isEmpty {
                return [Item(id: "archive:" + archive.path,
                    name: archive.name.replacingOccurrences(of: "_", with: " "), category: archive.category,
                    archivePath: archive.path, record: nil, previewURL: nil,
                    unavailableReason: archive.problem ?? "This garment needs a conversion adapter before it can be installed.", previewError: nil)]
            }
            return archive.preparedPieces.map { piece in
                let prepared = wardrobe?.items.first { $0.id == piece.id }
                return Item(id: piece.id, name: piece.name, category: archive.category, archivePath: archive.path,
                    record: piece.id, previewURL: prepared?.previewURL,
                    unavailableReason: prepared == nil && piece.requiresConversion != true ? "Open the prepared wardrobe in Clothing to use this garment." : nil, previewError: nil)
            }
        }.filter { seen.insert($0.id).inserted }
    }

    private init(items: [Item], notice: String?) { self.items = items; self.notice = notice }

    public func applying(_ snapshot: ClothingPreviewSnapshot) -> ClothingImportCatalog {
        ClothingImportCatalog(items: items.map { item in
            Item(id: item.id, name: item.name, category: item.category, archivePath: item.archivePath,
                record: item.record, previewURL: item.previewURL ?? snapshot.images[item.archivePath],
                unavailableReason: item.unavailableReason, previewError: snapshot.errors[item.archivePath])
        }, notice: notice)
    }

    public func validateSelection(_ records: [String]) throws {
        guard !records.isEmpty, Set(records).count == records.count,
              Set(records).isSubset(of: Set(availableItems.compactMap(\.record))) else {
            throw CyberMacError.invalidInput("Select one or more available garments from this package.")
        }
    }

    /// Replace this package's previous choices, preserving other packages.
    public static func replacingPackageSelection(contents: ModPackageContents, selected: [String], existing: Set<String>) throws -> [String] {
        let package = Set(contents.preparedPieces.map(\.id))
        guard !selected.isEmpty, Set(selected).count == selected.count, Set(selected).isSubset(of: package) else {
            throw CyberMacError.invalidInput("Selected clothing is empty, duplicated, or not part of this ZIP.")
        }
        return existing.subtracting(package).union(selected).sorted()
    }
}
