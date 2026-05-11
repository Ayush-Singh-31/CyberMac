import SwiftUI

struct WarningBanner: View {
    let message: String
    var title: String = "Known input-loader issue detected"
    var kind: WarningBannerKind = .warning
    var onDismiss: (() -> Void)?
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(kind.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    if showDetails {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button(showDetails ? "Hide details" : "Show details") {
                    showDetails.toggle()
                }
                .buttonStyle(CyberButtonStyle(.ghost, accent: kind.accent))
                if let onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(CyberButtonStyle(.ghost, accent: kind.accent))
                }
            }
        }
        .padding(14)
        .background(kind.accent.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(kind.accent.color.opacity(0.16), lineWidth: 1)
        }
    }
}

enum WarningBannerKind {
    case warning
    case blocked
    case info
    case success

    var accent: CyberAccent {
        switch self {
        case .warning:
            return .amber
        case .blocked:
            return .red
        case .info:
            return .cyan
        case .success:
            return .green
        }
    }

    var systemImage: String {
        switch self {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        }
    }
}
