import SwiftUI

struct HoverGlowModifier: ViewModifier {
    let accent: CyberAccent
    let enabled: Bool
    let cornerRadius: CGFloat

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.color.opacity(isHovering && enabled ? 0.28 : 0.00),
                                accent.secondary.opacity(isHovering && enabled ? 0.10 : 0.00)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovering && enabled ? 1.2 : 0
                    )
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverGlow(_ accent: CyberAccent, enabled: Bool = true, cornerRadius: CGFloat = CyberStyle.panelRadius) -> some View {
        modifier(HoverGlowModifier(accent: accent, enabled: enabled, cornerRadius: cornerRadius))
    }
}
