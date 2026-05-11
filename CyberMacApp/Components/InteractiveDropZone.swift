import SwiftUI
import UniformTypeIdentifiers

struct InteractiveDropZone: View {
    let title: String
    let subtitle: String
    let onFiles: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        CyberPanel(accent: .cyan, interactive: true) {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 34))
                    .foregroundStyle(CyberAccent.cyan.color)
                    .symbolEffect(.pulse, value: isTargeted)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            loadFileURLs(from: providers)
            return true
        }
        .help("Drop a redscript-only .zip mod archive")
    }

    private func loadFileURLs(from providers: [NSItemProvider]) {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let itemURL = item as? URL {
                    url = itemURL
                } else {
                    url = nil
                }
                guard let url, url.pathExtension.lowercased() == "zip" else { return }
                DispatchQueue.main.async {
                    onFiles([url])
                }
            }
        }
    }
}
