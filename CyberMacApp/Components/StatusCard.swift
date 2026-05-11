import SwiftUI

struct StatusCard: View {
    let title: String
    let status: String
    let systemImage: String
    let tint: Color

    var body: some View {
        GlassPanel {
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
