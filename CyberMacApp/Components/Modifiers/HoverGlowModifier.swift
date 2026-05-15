import SwiftUI

struct HoverGlowModifier: ViewModifier {
    let accent: CyberAccent
    let enabled: Bool
    let scale: CGFloat
    let cornerRadius: CGFloat

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && enabled ? scale : 1.0)
            .shadow(
                color: isHovering && enabled ? accent.color.opacity(0.28) : .clear,
                radius: isHovering && enabled ? 18 : 0,
                x: 0,
                y: isHovering && enabled ? 8 : 0
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.color.opacity(isHovering && enabled ? 0.42 : 0.00),
                                accent.secondary.opacity(isHovering && enabled ? 0.18 : 0.00)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovering && enabled ? 1.2 : 0
                    )
            }
            .animation(.easeOut(duration: 0.18), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverGlow(_ accent: CyberAccent, enabled: Bool = true, scale: CGFloat = 1.015, cornerRadius: CGFloat = 22) -> some View {
        modifier(HoverGlowModifier(accent: accent, enabled: enabled, scale: scale, cornerRadius: cornerRadius))
    }
}
