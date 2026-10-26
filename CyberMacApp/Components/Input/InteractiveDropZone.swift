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
        .shadow(
            color: CyberAccent.cyan.color.opacity(isTargeted ? 0.34 : 0.0),
            radius: isTargeted ? 28 : 0,
            y: isTargeted ? 10 : 0
        )
        .animation(.easeOut(duration: 0.18), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            onFiles(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .help("Drop a mod archive")
    }

}
