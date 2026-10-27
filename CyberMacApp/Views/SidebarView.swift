import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppScreen?
    @State private var advancedExpanded = false
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private let advancedScreens: [AppScreen] = [.outfits, .activation, .archiveLab, .archiveIndex, .backups, .diagnostics]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                sidebarIcon
                    .resizable().scaledToFit().frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                Text("CyberMac").font(.title3.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([AppScreen.home, .appearance, .mods]) { screen in
                        navigationRow(screen)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                advancedExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Advanced").font(.caption.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .rotationEffect(.degrees(advancedExpanded ? 90 : 0))
                            }
                            .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(0.55))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Advanced navigation")
                        .accessibilityValue(advancedExpanded ? "Expanded" : "Collapsed")
                        if advancedExpanded {
                            ForEach(advancedScreens) { screen in navigationRow(screen) }
                        }
                    }.padding(.top, 18)
                }.padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)

            Divider().overlay(.white.opacity(0.06))
                .padding(.horizontal, 12).padding(.bottom, 10)
            navigationRow(.settings).padding(.horizontal, 4).padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(SidebarGlassSurface(reduceTransparency: reduceTransparency))
        .padding(12)
        .background {
            if !reduceTransparency {
                RadialGradient(colors: [CyberAccent.cyan.color.opacity(0.09), .clear], center: .topLeading, startRadius: 0, endRadius: 300)
            }
        }
        .frame(minWidth: 220)
        .onChange(of: selection, initial: true) { _, screen in
            if let screen, advancedScreens.contains(screen) { advancedExpanded = true }
        }
    }

    private var sidebarIcon: Image {
        if let url = Bundle.module.url(forResource: "CyberMacIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        return Image(systemName: "bolt.fill")
    }

    private func navigationRow(_ screen: AppScreen) -> some View {
        SidebarItemView(screen: screen, selected: selection == screen, selectionNamespace: selectionNamespace) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                selection = screen
            }
        }
    }
}

private struct SidebarGlassSurface: ViewModifier {
    let reduceTransparency: Bool
    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay { shape.stroke(.white.opacity(0.12), lineWidth: 1) }
        } else if #available(macOS 26.0, *) {
            content.background(Color(nsColor: .windowBackgroundColor).opacity(0.45), in: shape)
                .glassEffect(.regular, in: shape)
                .overlay { shape.stroke(.white.opacity(0.12), lineWidth: 1) }
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
    }
}

private struct SidebarItemView: View {
    let screen: AppScreen
    let selected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var labelColor: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: screen.systemImage)
                    .font(.system(size: 16, weight: selected ? .semibold : .regular))
                    .frame(width: 20)
                    .foregroundStyle(selected ? CyberAccent.cyan.color : labelColor.opacity(0.6))
                Text(screen.rawValue).font(.callout.weight(selected ? .semibold : .regular))
                    .foregroundStyle(labelColor.opacity(selected ? 1 : 0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [CyberAccent.cyan.color.opacity(reduceTransparency ? 0.24 : 0.18), CyberAccent.cyan.secondary.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.26), CyberAccent.cyan.color.opacity(0.22), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
                    .matchedGeometryEffect(id: "sidebar-selection", in: selectionNamespace)
            } else if isHovering && isEnabled {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05))
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .hoverCursor(.pointingHand)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
        .accessibilityLabel(screen.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
