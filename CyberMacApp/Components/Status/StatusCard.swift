import SwiftUI

struct StatusCard: View {
    let title: String
    let status: String
    let systemImage: String
    let tint: Color
    var accent: CyberAccent = .neutral
    var highlighted: Bool = false

    var body: some View {
        CyberPanel(accent: highlighted ? accent : nil, interactive: false) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(status)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
