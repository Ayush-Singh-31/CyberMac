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
    @Environment(\.controlSize) private var controlSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    init(_ variant: CyberButtonVariant = .secondary, accent: CyberAccent = .cyan, minWidth: CGFloat? = nil) {
        self.variant = variant
        self.accent = accent
        self.minWidth = minWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 9)
            .frame(minWidth: minWidth)
            .foregroundStyle(foreground)
            .background {
                background(pressed: configuration.isPressed)
                    .clipShape(RoundedRectangle(cornerRadius: CyberStyle.controlRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CyberStyle.controlRadius, style: .continuous)
                    .strokeBorder(strokeColor.opacity(isHovering && isEnabled ? 1 : 0.6), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .modifier(CursorIfEnabled(enabled: isEnabled))
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
    }

    private var compact: Bool { controlSize == .small || controlSize == .mini }

    private var foreground: Color {
        switch variant {
        case .primary: .white
        case .secondary: .primary
        case .ghost: colorScheme == .dark ? CyberAccent.cyan.color : CyberAccent.blue.color
        case .destructive: colorScheme == .dark ? Color(red: 1, green: 0.60, blue: 0.64) : CyberAccent.red.color
        }
    }

    private var strokeColor: Color {
        switch variant {
        case .primary: CyberAccent.cyan.color.opacity(0.45)
        case .secondary: Color.primary.opacity(0.18)
        case .destructive: CyberAccent.red.color.opacity(0.35)
        case .ghost: .clear
        }
    }

    @ViewBuilder private func background(pressed: Bool) -> some View {
        switch variant {
        case .primary:
            LinearGradient(colors: [CyberAccent.cyan.color, CyberAccent.blue.color], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .secondary:
            Color.primary.opacity(pressed ? 0.10 : (isHovering && isEnabled ? 0.075 : 0.045))
        case .destructive:
            CyberAccent.red.color.opacity(pressed ? 0.18 : 0.09)
        case .ghost:
            CyberAccent.cyan.color.opacity(pressed ? 0.10 : (isHovering && isEnabled ? 0.06 : 0))
        }
    }
}

private struct CursorIfEnabled: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled { content.cyberCursor() }
        else { content }
    }
}
