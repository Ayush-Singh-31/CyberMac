import SwiftUI

struct CyberPanel<Content: View>: View {
    let accent: CyberAccent?
    let interactive: Bool
    let content: Content

    init(accent: CyberAccent? = nil, interactive: Bool = false, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(baseStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .hoverGlow(accent ?? .neutral, enabled: interactive, scale: 1.012, cornerRadius: 24)
            .modifier(CursorIfNeeded(enabled: interactive))
    }

    private var baseStroke: Color {
        accent?.color.opacity(interactive ? 0.12 : 0.08) ?? .white.opacity(0.08)
    }
}

private struct CursorIfNeeded: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.cyberCursor()
        } else {
            content
        }
    }
}
