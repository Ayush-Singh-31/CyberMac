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

    private var accent: CyberAccent { screen.sidebarAccent }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: screen.systemImage)
                    .font(.system(size: 18, weight: selected ? .semibold : .medium))
                    .frame(width: 22)
                    .foregroundStyle(selected || isHovering ? accent.color : .secondary)
                    .shadow(
                        color: accent.color.opacity(selected ? 0.68 : (isHovering ? 0.42 : 0)),
                        radius: selected ? 9 : 6
                    )
                Text(screen.rawValue)
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .opacity(selected ? 1.0 : (isHovering ? 0.95 : 0.72))
                Spacer()
            }
        }
        .buttonStyle(SidebarRowButtonStyle(accent: accent, selected: selected, isHovering: isHovering))
        .padding(.horizontal, 10)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverCursor(.pointingHand)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: selected)
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    let accent: CyberAccent
    let selected: Bool
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .frame(height: 46)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            }
            .overlay(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(accent.color)
                        .frame(width: 3, height: 24)
                        .shadow(color: accent.color.opacity(0.72), radius: 8)
                        .padding(.leading, 3)
                } else if isHovering {
                    Circle()
                        .fill(accent.color.opacity(0.86))
                        .frame(width: 5, height: 5)
                        .shadow(color: accent.color.opacity(0.54), radius: 6)
                        .padding(.leading, 5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.color.opacity(selected ? 0.22 : (isHovering ? 0.14 : 0)), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovering ? 1.008 : 1.0))
            .offset(x: isHovering && !selected ? 2 : 0)
            .shadow(
                color: accent.color.opacity(configuration.isPressed ? 0.08 : (selected ? 0.18 : (isHovering ? 0.12 : 0))),
                radius: selected || isHovering ? 12 : 0,
                y: selected || isHovering ? 5 : 0
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var background: LinearGradient {
        let primaryOpacity: Double
        let secondaryOpacity: Double
        if selected {
            primaryOpacity = isHovering ? 0.24 : 0.18
            secondaryOpacity = isHovering ? 0.12 : 0.08
        } else if isHovering {
            primaryOpacity = 0.12
            secondaryOpacity = 0.06
        } else {
            primaryOpacity = 0
            secondaryOpacity = 0
        }
        return LinearGradient(
            colors: [
                accent.color.opacity(primaryOpacity),
                accent.secondary.opacity(secondaryOpacity),
                Color.white.opacity(isHovering && !selected ? 0.035 : 0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private extension AppScreen {
    var sidebarAccent: CyberAccent {
        switch self {
        case .home:
            return .cyan
        case .mods:
            return .green
        case .activation:
            return .amber
        case .backups:
            return .blue
        case .diagnostics:
            return .red
        case .settings:
            return .purple
        }
    }
}
