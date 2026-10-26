import CyberMacCore
import SwiftUI

struct ModPackageContentsView: View {
    let contents: ModPackageContents
    @State private var expanded = true
    @State private var search = ""
    @State private var category = "All"

    private var categories: [String] { Array(Set(contents.archives.map(\.category))).sorted() }
    private var visible: [ModPackageContents.Archive] {
        contents.archives.filter {
            (category == "All" || $0.category == category) &&
            (search.isEmpty || $0.path.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("\(contents.archives.count) archive variants in this ZIP")
                .font(.headline)
            if !contents.preparedPieces.isEmpty {
                Text("\(contents.preparedPieces.count) available garments · \(contents.unpreparedArchives.count) variants not supported yet")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(contents.preparedPieces) { piece in
                    Label(piece.name, systemImage: "tshirt")
                        .font(.callout).foregroundStyle(CyberAccent.cyan.color)
                }
                Text("Choose the available garments in Clothing. The other variants cannot be installed with this version of CyberMac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Browse all variants", isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Find a garment or colour…", text: $search).textFieldStyle(.roundedBorder)
                        Picker("Category", selection: $category) {
                            Text("All").tag("All")
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }.frame(maxWidth: 250)
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(visible) { archive in
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(archive.category).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        Text(archive.name.replacingOccurrences(of: "_", with: " "))
                                            .font(.callout).textSelection(.enabled)
                                    }
                                    Spacer()
                                    Text(archive.problem != nil ? "File differs" : (archive.preparedPieces.isEmpty ? "Not supported yet" : "Available"))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(archive.preparedPieces.isEmpty ? CyberAccent.amber.color : CyberAccent.green.color)
                                }
                                if let problem = archive.problem { Text(problem).font(.caption).foregroundStyle(.orange) }
                                Divider()
                            }
                            if visible.isEmpty { Text("No matching variants.").foregroundStyle(.secondary) }
                        }.padding(.trailing, 10)
                    }.frame(height: 260)
                    Text("Showing \(visible.count) of \(contents.archives.count) variants")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 10)
            }
        }
    }
}
