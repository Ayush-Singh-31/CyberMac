import AppKit
import SwiftUI

enum AppScreen: String, CaseIterable, Identifiable {
    case home = "Install mods"
    case appearance = "Clothing"
    case mods = "Library"
    case outfits = "Outfits"
    case activation = "Activation"
    case archiveLab = "Archive Lab"
    case archiveIndex = "Archive Index"
    case backups = "Backups"
    case diagnostics = "Diagnostics"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .appearance:
            return "person.crop.rectangle"
        case .mods:
            return "shippingbox"
        case .outfits:
            return "tshirt"
        case .activation:
            return "bolt.circle"
        case .archiveLab:
            return "archivebox.circle"
        case .archiveIndex:
            return "photo.on.rectangle.angled"
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
    @State private var installer = ModInstallerModel()
    @State private var selection: AppScreen = .home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: Binding(
                get: { selection },
                set: { newValue in if let newValue { selection = newValue } }
            ))
            .disabled(installer.busy)
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
                        .disabled(selection != .home && installer.busy)
                        .padding(28)
                        .id(selection)
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
                ProgressOverlay(title: task.title, onCancel: task == .refreshing ? { appState.cancelRefresh() } : nil)
            }
        }
        .task {
            await installer.load()
            await appState.refresh()
        }
        .onChange(of: installer.busy) { _, busy in
            if !busy { Task { await appState.refresh() } }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) {
            appState.sessionLog.recordGameLifecycle($0)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) {
            appState.sessionLog.recordGameLifecycle($0)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            installer.stopPreviewRendering()
            appState.sessionLog.stopForTermination()
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selection {
        case .home:
            InstallModsView(installer: installer, appState: appState) { selection = .appearance }
        case .appearance:
            ClothingWardrobeView { url in
                selection = .home
                Task { await installer.enqueue([url]) }
            }
        case .mods:
            ModsView(appState: appState)
        case .outfits:
            OutfitsView(appState: appState)
        case .activation:
            ActivationView(appState: appState)
        case .archiveLab:
            ArchiveLabView()
        case .archiveIndex:
            ArchiveIndexView(appState: appState)
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
