import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppScreen?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CyberMac")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(AppScreen.allCases) { screen in
                SidebarItemView(
                    screen: screen,
                    selected: selection == screen
                ) {
                    selection = screen
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .frame(minWidth: 220)
    }
}

private struct SidebarItemView: View {
    let screen: AppScreen
    let selected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: screen.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(selected || isHovering ? CyberAccent.blue.color : .secondary)
                Text(screen.rawValue)
                    .font(.callout.weight(selected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .cyberCursor()
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: selected)
    }

    private var rowBackground: Color {
        if selected {
            return CyberAccent.blue.color.opacity(isHovering ? 0.26 : 0.20)
        }
        return Color.white.opacity(isHovering ? 0.07 : 0.00)
    }
}
