import CyberMacCore
import SwiftUI

struct ClothingPreviewProgressView: View {
    let progress: ClothingPreviewProgress
    let retry: () -> Void
    let pause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                if progress.isActive { ProgressView().controlSize(.small) }
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                if progress.isActive { Button("Pause", action: pause).buttonStyle(CyberButtonStyle(.ghost)).controlSize(.small) }
                else if progress.failed > 0 || progress.state != "finished" { Button("Resume previews", action: retry).buttonStyle(CyberButtonStyle(.ghost)).controlSize(.small) }
            }
            if progress.isActive && progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
            }
            if progress.total > 0 {
                Text("\(progress.readyCount) images ready · \(progress.completed) of \(progress.total) variants processed\(progress.failed > 0 ? " · \(progress.failed) could not render" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if progress.isActive || progress.state == "failed" {
                Text(progress.current).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
            }
        }
        .padding(12)
        .cyberSurface(radius: CyberStyle.rowRadius)
    }

    private var title: String {
        switch progress.state {
        case "loading": "Loading lightweight clothing previews…"
        case "rendering": "Preparing previews for the clothes you’re browsing…"
        case "finished": progress.failed == 0 ? "Previews ready · more load as you browse" : "Some previews could not be generated"
        case "cancelled": "Preview rendering paused"
        default: "Preview rendering needs attention"
        }
    }
}
