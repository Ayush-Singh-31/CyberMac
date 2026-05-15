import SwiftUI

enum AppScreen: String, CaseIterable, Identifiable {
    case home = "Home"
    case mods = "Mods"
    case activation = "Activation"
    case backups = "Backups"
    case diagnostics = "Diagnostics"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .mods:
            return "shippingbox"
        case .activation:
            return "bolt.circle"
        case .backups:
            return "clock.arrow.circlepath"
        case .diagnostics:
            return "waveform.path.ecg"
        case .settings:
            return "gearshape"
        }
    }
}

struct RootView: View {
    @State private var appState = CyberMacAppState()
    @State private var selection: AppScreen? = .home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            ZStack {
                background
                VStack(spacing: 12) {
                    if !appState.snapshotWarnings.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(appState.snapshotWarnings) { warning in
                                WarningBanner(
                                    message: warning.message,
                                    title: "Couldn't load \(warning.area)",
                                    kind: .warning,
                                    onDismiss: nil
                                )
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 28)
                    }
                    selectedView
                        .padding(28)
                        .id(selection ?? .home)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selection)
        }
        .alert(
            appState.lastError?.title ?? "",
            isPresented: Binding(
                get: { appState.lastError != nil },
                set: { if !$0 { appState.lastError = nil } }
            ),
            presenting: appState.lastError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.message)
        }
        .overlay {
            if let task = appState.currentTask {
                ProgressOverlay(title: task.title)
            }
        }
        .task {
            await appState.refresh()
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selection ?? .home {
        case .home:
            HomeView(appState: appState)
        case .mods:
            ModsView(appState: appState)
        case .activation:
            ActivationView(appState: appState)
        case .backups:
            BackupsView(appState: appState)
        case .diagnostics:
            DiagnosticsView(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.08, green: 0.10, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
