import SwiftUI

struct ProgressOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            GlassPanel {
                HStack(spacing: 14) {
                    ProgressView()
                    Text(title)
                        .font(.headline)
                }
                .frame(width: 280)
            }
        }
    }
}
