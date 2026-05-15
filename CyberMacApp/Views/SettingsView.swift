import SwiftUI

struct SettingsView: View {
    let appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))
                settingsSection("Developer", accent: .purple) {
                    Toggle("Developer mode", isOn: developerBinding)
                        .toggleStyle(.switch)
                        .cyberCursor()
                    Toggle("Show raw hashes in UI", isOn: rawHashesBinding)
                        .toggleStyle(.switch)
                        .cyberCursor()
                }
                settingsSection("Storage", accent: .green) {
                    HStack {
                        Text("CyberMac folder")
                            .foregroundStyle(.secondary)
                        Spacer()
                        PrimaryButton(title: "Reveal", systemImage: "folder", disabled: false, variant: .secondary, accent: .green) {
                            appState.revealCyberMacFolder()
                        }
                        .help("Reveal CyberMac support folder")
                    }
                }
                settingsSection("Game", accent: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Game path", value: appState.doctor?.game.appPath ?? "not detected")
                        DetailRow(label: "Bundle target", value: appState.doctor?.game.bundleTarget ?? "not detected")
                        HStack {
                            PrimaryButton(title: "Reveal game app", systemImage: "gamecontroller", disabled: appState.doctor?.game.found != true, variant: .secondary, accent: .blue) {
                                appState.revealGameApp()
                            }
                            .help("Reveal game app in Finder")
                            PrimaryButton(title: "Refresh detection", systemImage: "arrow.clockwise", disabled: false, variant: .secondary, accent: .cyan) {
                                Task { await appState.refresh() }
                            }
                            .help("Refresh detected game state")
                        }
                    }
                }
                settingsSection("Maintenance", accent: .amber) {
                    PrimaryButton(title: "Clear temporary activation outputs", systemImage: "trash", disabled: false, variant: .secondary, accent: .amber) {
                        Task { await appState.clearTemporaryActivationOutputs() }
                    }
                    .help("Clear temporary activation outputs")
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var developerBinding: Binding<Bool> {
        Binding(
            get: { appState.developerMode },
            set: { appState.developerMode = $0 }
        )
    }

    private var rawHashesBinding: Binding<Bool> {
        Binding(
            get: { appState.showRawHashes },
            set: { appState.showRawHashes = $0 }
        )
    }

    private func settingsSection<Content: View>(_ title: String, accent: CyberAccent, @ViewBuilder content: () -> Content) -> some View {
        CyberPanel(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                content()
            }
        }
    }
}
