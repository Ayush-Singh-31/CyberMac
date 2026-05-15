import SwiftUI

enum CyberButtonVariant {
    case primary
    case secondary
    case destructive
    case ghost
}

struct CyberButtonStyle: ButtonStyle {
    let variant: CyberButtonVariant
    let accent: CyberAccent
    let minWidth: CGFloat?
    @Environment(\.isEnabled) private var isEnabled

    init(_ variant: CyberButtonVariant = .secondary, accent: CyberAccent = .blue, minWidth: CGFloat? = nil) {
        self.variant = variant
        self.accent = accent
        self.minWidth = minWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: minWidth)
            .foregroundStyle(foreground)
            .background {
                background(configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .hoverGlow(variant == .destructive ? .red : accent, enabled: isEnabled, scale: 1.018, cornerRadius: 16)
            .modifier(CursorIfEnabled(enabled: isEnabled))
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return .primary
        case .destructive:
            return Color(red: 1.0, green: 0.70, blue: 0.72)
        }
    }

    private var strokeColor: Color {
        switch variant {
        case .primary:
            return accent.secondary.opacity(0.24)
        case .secondary:
            return .white.opacity(0.10)
        case .destructive:
            return CyberAccent.red.color.opacity(0.24)
        case .ghost:
            return .clear
        }
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [accent.color, accent.secondary.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Color.white.opacity(configuration.isPressed ? 0.10 : 0.07)
        case .destructive:
            Color.red.opacity(configuration.isPressed ? 0.18 : 0.08)
        case .ghost:
            Color.white.opacity(configuration.isPressed ? 0.08 : 0.00)
        }
    }
}

private struct CursorIfEnabled: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.cyberCursor()
        } else {
            content
        }
    }
}
