import Foundation

public struct ModPackageContents: Codable, Sendable {
    public struct Piece: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public init(id: String, name: String) { self.id = id; self.name = name }
    }
    public struct Archive: Codable, Identifiable, Sendable {
        public let path: String
        public let preparedPieces: [Piece]
        public let problem: String?
        public var id: String { path }
        public var name: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
        public var category: String { URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent }
        public init(path: String, preparedPieces: [Piece], problem: String? = nil) {
            self.path = path; self.preparedPieces = preparedPieces; self.problem = problem
        }
    }
    public let archives: [Archive]
    public var preparedPieces: [Piece] { archives.flatMap(\.preparedPieces) }
    public var unpreparedArchives: [Archive] { archives.filter { $0.preparedPieces.isEmpty } }
    public var isClothingCollection: Bool {
        if !preparedPieces.isEmpty { return true }
        let pattern = #"(?i)(?:^|[/_\s-])(jinguji|clothing|clothes|outfits?|corset|shirts?|dresses|dress|pants|boots|jacket|heels|bodysuit|skirt|bolero|sandals|stockings|lingerie|bra)(?:$|[/_\s.-])"#
        return archives.contains { $0.path.range(of: pattern, options: .regularExpression) != nil }
    }
    public init(archives: [Archive]) { self.archives = archives }
}
