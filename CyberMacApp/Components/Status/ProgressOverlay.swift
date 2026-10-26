import SwiftUI

struct ProgressOverlay: View {
    let title: String
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            GlassPanel {
                HStack(spacing: 14) {
                    ProgressView()
                    Text(title)
                        .font(.headline)
                    if let onCancel { Button("Stop checking", action: onCancel) }
                }
                .frame(minWidth: 280)
            }
        }
    }
}
