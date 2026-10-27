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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CyberStyle.panelPadding)
            .cyberSurface()
            .hoverGlow(.cyan, enabled: interactive, cornerRadius: CyberStyle.panelRadius)
            .modifier(CursorIfNeeded(enabled: interactive))
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
