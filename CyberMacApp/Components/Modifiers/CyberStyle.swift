import SwiftUI

/// Shared proportions for the workspace, sheets and reusable controls.
enum CyberStyle {
    static let pagePadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 24
    static let panelPadding: CGFloat = 20
    static let panelRadius: CGFloat = 20
    static let rowRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let pageTitle = Font.system(size: 28, weight: .semibold)
}

struct CyberBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor),
                     colorScheme == .dark ? Color(red: 0.08, green: 0.10, blue: 0.12) : Color(red: 0.93, green: 0.95, blue: 0.96)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }
}

private struct CyberSurface: ViewModifier {
    let radius: CGFloat
    let selected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape.fill(Color(nsColor: .controlBackgroundColor))
                if !reduceTransparency {
                    shape.fill(LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.045 : 0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                if selected { shape.fill(CyberAccent.cyan.color.opacity(0.08)) }
            }
            .overlay {
                shape.strokeBorder(selected ? CyberAccent.cyan.color.opacity(0.5) : (colorScheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.09)), lineWidth: 1)
            }
    }
}

extension View {
    /// Cards share the glass palette without adding a blur pass to every row.
    func cyberSurface(radius: CGFloat = CyberStyle.panelRadius, selected: Bool = false) -> some View {
        modifier(CyberSurface(radius: radius, selected: selected))
    }

    func cyberSheet() -> some View {
        background(CyberBackground())
            .tint(CyberAccent.cyan.color)
            .buttonStyle(CyberButtonStyle())
    }
}
